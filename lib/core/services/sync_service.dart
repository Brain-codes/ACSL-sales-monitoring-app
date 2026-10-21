import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/material.dart';
import 'package:stove_transaction/core/services/location_resolution_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:crypto/crypto.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/utils/phone_utils.dart';
import 'package:stove_transaction/features/sales/create/buyer_rule_messages.dart';

class SyncService extends GetxService {
  final _logger = Logger();
  final RxBool isSyncing = false.obs;
  final RxInt successCount = 0.obs;
  final RxInt failCount = 0.obs;
  final RxInt heldForResolutionCount = 0.obs;

  /// Rows the server refused this run (same customer).
  final RxInt refusedCount = 0.obs;

  static const _saleTimeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(seconds: 45);

  /// Pushes queued sales to the server.
  ///
  /// [onlyIds] restricts the run to specific queue rows (individual sync or a
  /// multi-select batch). When null, every cleared-to-sync sale is pushed
  /// ("sync all"). Rows held for manual location resolution are always skipped.
  Future<void> syncPendingSales({List<int>? onlyIds}) async {
    if (isSyncing.value) return;

    final queue = Get.find<OfflineQueueService>();
    final supabase = Get.find<SupabaseService>();
    var pending = await queue.getPending();
    if (onlyIds != null) {
      final wanted = onlyIds.toSet();
      pending = pending.where((r) => wanted.contains(r['id'] as int)).toList();
    } else {
      // "Sync all" skips sales the server already refused; they wait for an
      // edit. Syncing one on purpose (onlyIds) still sends it.
      pending = pending.where((r) => (r['refused'] as int? ?? 0) == 0).toList();
    }

    if (pending.isEmpty) return;

    isSyncing.value = true;
    successCount.value = 0;
    failCount.value = 0;
    heldForResolutionCount.value = 0;
    refusedCount.value = 0;

    _showSyncStartToast(pending.length);

    // Wrap the whole run so `isSyncing` ALWAYS resets — even if an await outside
    // the per-row try throws or the network flaps mid-sync. Without this, one
    // wedged run left isSyncing=true forever and the guard above silently
    // blocked every future sync (the "syncing data… forever" symptom).
    try {
    for (final row in pending) {
      try {
        final id = row['id'] as int;
        var payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        // Gate: verify the typed offline address against Google before pushing.
        // Strong match → attach Google location & continue. Weak/no match →
        // hold this sale for manual resolution and skip it this run.
        if (!_alreadyResolved(payload)) {
          final resolved = await _resolveLocation(queue, id, payload);
          if (resolved == null) {
            heldForResolutionCount.value++;
            continue;
          }
          payload = resolved;
        }

        final imagesJson = row['images'] as String?;

        // Upload images first if any
        if (imagesJson != null) {
          final images = jsonDecode(imagesJson) as Map<String, dynamic>;
          // Photos uploaded by an earlier attempt: {key: {id, sig}}. Reused
          // while the photo is unchanged, so a retry uploads nothing again.
          final uploaded = Map<String, dynamic>.from(
              payload[OfflineQueueService.uploadedImagesKey] as Map? ?? {});
          // Maps image key → payload field name
          const fieldMap = {
            'stove_image': 'stoveImageId',
            'agreement_image': 'agreementImageId',
            'payment_proof': 'initialPaymentProofImageId',
          };
          for (final entry in images.entries) {
            // Signature stays as base64 in payload — no upload needed
            if (entry.key == 'signature') {
              payload['signature'] = entry.value;
              continue;
            }
            final payloadField = fieldMap[entry.key];
            final sig = imageSignature(entry.value as String);
            final prior = uploaded[entry.key];
            if (prior is Map && prior['sig'] == sig && prior['id'] != null) {
              if (payloadField != null) payload[payloadField] = prior['id'];
              continue;
            }
            final bytes = base64Decode(entry.value as String);
            final tmpFile = File('${Directory.systemTemp.path}/sync_${entry.key}.jpg');
            await tmpFile.writeAsBytes(bytes);
            try {
              final uploadResp = await supabase
                  .callEdgeFunction(
                    'upload-image',
                    body: {'file': tmpFile, 'type': entry.key},
                    isFormData: true,
                  )
                  .timeout(_uploadTimeout);
              // M13: a failed upload used to fall straight through, and the
              // sale then synced WITHOUT its photo — permanently, and with
              // nobody told. The agreement photo is evidence of the sale, so
              // losing it silently is worse than not syncing yet.
              //
              // Throwing hands this row to the catch below, which records the
              // error and leaves it queued: the pending card shows what went
              // wrong and the next sync retries the upload. Nothing is lost,
              // and the failure is visible.
              if (!uploadResp.success || uploadResp.data == null) {
                throw 'Could not upload the ${_imageLabel(entry.key)} — the '
                    'sale stays queued so the photo is not lost. '
                    '${uploadResp.message}'.trim();
              }

              final data = Map<String, dynamic>.from(uploadResp.data as Map);
              final uploadMap = data['upload'] is Map
                  ? Map<String, dynamic>.from(data['upload'] as Map)
                  : data;
              final imageId = uploadMap['id']?.toString();
              if (imageId == null || imageId.isEmpty) {
                throw 'The ${_imageLabel(entry.key)} uploaded but the server '
                    'returned no id — the sale stays queued.';
              }
              if (payloadField != null) {
                payload[payloadField] = imageId;
              }
              uploaded[entry.key] = {'id': imageId, 'sig': sig};
              payload[OfflineQueueService.uploadedImagesKey] = uploaded;
              await queue.savePayload(id, payload);
            } finally {
              if (await tmpFile.exists()) await tmpFile.delete();
            }
          }
        }

        final body = Map<String, dynamic>.from(payload)
          ..remove(OfflineQueueService.uploadedImagesKey);
        final resp = await supabase
            .callEdgeFunction('create-sale', body: body)
            .timeout(_saleTimeout);
        if (resp.success || alreadyCreated(resp)) {
          // `alreadyCreated`: a prior attempt for THIS transaction id actually
          // saved on the server but the ack was lost before we could mark it
          // synced. The backend's duplicate-transaction guard returns 409, which
          // means the sale IS there — treat it as a success, not a failure, so
          // it clears the queue instead of looking failed forever. This is our
          // idempotency guarantee: the same sale can never double-create.
          await queue.markSynced(id);
          // Its number and customer are on the server now; don't wait for the
          // next full refresh to see them.
          final cache = Get.find<LocalCacheService>();
          cache.addEndUserPhone(PhoneUtils.normalizePhone(payload['phone']?.toString()));
          cache.addBuyerKey(BuyerKey.ofPayload(payload, cache.getBuyerKeyTitles()));
          successCount.value++;
        } else if (resp.code == 409 &&
            resp.errorCode == BuyerRuleMessages.sameBuyerCode) {
          // A definite refusal: stop retrying it until it is edited.
          await queue.markRefused(id, resp.message);
          refusedCount.value++;
        } else {
          await queue.markError(id, resp.message);
          failCount.value++;
        }
      } catch (e) {
        _logger.e('Sync error for row ${row['id']}: $e');
        // Record the failure so the pending card can surface it and offer edit.
        final rowId = row['id'] as int?;
        if (rowId != null) await queue.markError(rowId, e.toString());
        failCount.value++;
      }
    }
    } finally {
      isSyncing.value = false;
    }
    _showSyncResultToast();
  }

  /// A photo's name as the user knows it, for a failure message.
  String _imageLabel(String key) {
    switch (key) {
      case 'stove_image':
        return 'stove photo';
      case 'agreement_image':
        return 'agreement photo';
      case 'payment_proof':
        return 'payment proof';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  /// True when the create-sale call failed only because a sale with this exact
  /// transaction id already exists on the server (backend 409 duplicate guard).
  /// That means a previous sync attempt succeeded but its ack was lost, so the
  /// sale is safely on the server and the queued row can be marked synced.
  ///
  /// Matched narrowly on the transaction-id duplicate message so it never
  /// swallows the other 409 ("stove already sold"), which is a real failure.
  static bool alreadyCreated(SupabaseApiResponse resp) {
    if (resp.errorCode == BuyerRuleMessages.sameBuyerCode) return false;
    if (resp.code != 409) return false;
    final msg = resp.message.toLowerCase();
    return msg.contains('transaction id') && msg.contains('already exists');
  }

  /// Fingerprint of a queued photo, to tell an unchanged photo from a
  /// replaced one.
  static String imageSignature(String base64) =>
      sha256.convert(utf8.encode(base64)).toString();

  /// True once a sale's location has been resolved (auto-matched or user-picked).
  bool _alreadyResolved(Map<String, dynamic> payload) {
    final addr = payload['addressData'];
    return addr is Map && addr['locationResolved'] == true;
  }

  /// Resolves the typed address against Google. Returns a payload with the
  /// Google location attached when the match is confident enough to auto-sync;
  /// returns null (and flags the sale for manual resolution) otherwise.
  Future<Map<String, dynamic>?> _resolveLocation(
      OfflineQueueService queue, int id, Map<String, dynamic> payload) async {
    final resolver = Get.find<LocationResolutionService>();
    final addr = payload['addressData'] is Map
        ? Map<String, dynamic>.from(payload['addressData'] as Map)
        : <String, dynamic>{};
    final typed = (addr['fullAddress'] ?? '').toString();
    final lat = (addr['latitude'] as num?)?.toDouble();
    final lng = (addr['longitude'] as num?)?.toDouble();

    final result = await resolver.resolve(
        typedAddress: typed, lat: lat, lng: lng);

    if (result.best != null &&
        result.bestScore >= LocationResolutionService.autoAcceptThreshold) {
      return resolver.applyCandidateToPayload(payload, result.best!);
    }

    // Not confident — hold for manual review with the suggestions we found.
    await queue.markNeedsResolution(
        id, result.candidates.map((c) => c.toJson()).toList());
    return null;
  }

  void _showSyncStartToast(int count) {
    toastification.show(
      title: Text('Syncing $count pending sale${count > 1 ? 's' : ''}…'),
      type: ToastificationType.info,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showSyncResultToast() {
    final held = heldForResolutionCount.value;
    final heldSuffix = held > 0
        ? ' · $held need${held > 1 ? '' : 's'} location review'
        : '';
    final refused = refusedCount.value;
    if (refused > 0) {
      final retry = failCount.value > 0
          ? ', ${failCount.value} failed — will retry'
          : '';
      toastification.show(
        title: Text('${successCount.value} synced, '
            '${BuyerRuleMessages.t1(refused)}$retry$heldSuffix'),
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 6),
      );
    } else if (failCount.value > 0) {
      toastification.show(
        title: Text('${successCount.value} synced, ${failCount.value} failed — will retry$heldSuffix'),
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 5),
      );
    } else if (held > 0) {
      toastification.show(
        title: Text('${successCount.value} synced · $held need${held > 1 ? '' : 's'} location review'),
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 5),
      );
    } else if (successCount.value > 0) {
      toastification.show(
        title: Text('${successCount.value} sale${successCount.value > 1 ? 's' : ''} synced successfully'),
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 4),
      );
    }
  }
}
