import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/material.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class SyncService extends GetxService {
  final _logger = Logger();
  final RxBool isSyncing = false.obs;
  final RxInt successCount = 0.obs;
  final RxInt failCount = 0.obs;

  Future<void> syncPendingSales() async {
    if (isSyncing.value) return;

    final queue = Get.find<OfflineQueueService>();
    final supabase = Get.find<SupabaseService>();
    final pending = await queue.getPending();

    if (pending.isEmpty) return;

    isSyncing.value = true;
    successCount.value = 0;
    failCount.value = 0;

    _showSyncStartToast(pending.length);

    for (final row in pending) {
      try {
        final id = row['id'] as int;
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        final imagesJson = row['images'] as String?;

        // Upload images first if any
        if (imagesJson != null) {
          final images = jsonDecode(imagesJson) as Map<String, dynamic>;
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
            final bytes = base64Decode(entry.value as String);
            final tmpFile = File('${Directory.systemTemp.path}/sync_${entry.key}.jpg');
            await tmpFile.writeAsBytes(bytes);
            try {
              final uploadResp = await supabase.callEdgeFunction(
                'upload-image',
                body: {'file': tmpFile, 'type': entry.key},
                isFormData: true,
              );
              if (uploadResp.success && uploadResp.data != null) {
                final data = Map<String, dynamic>.from(uploadResp.data as Map);
                final uploadMap = data['upload'] is Map
                    ? Map<String, dynamic>.from(data['upload'] as Map)
                    : data;
                final imageId = uploadMap['id']?.toString();
                final payloadField = fieldMap[entry.key];
                if (imageId != null && payloadField != null) {
                  payload[payloadField] = imageId;
                }
              }
            } finally {
              if (await tmpFile.exists()) await tmpFile.delete();
            }
          }
        }

        final resp = await supabase.callEdgeFunction('create-sale', body: payload);
        if (resp.success) {
          await queue.markSynced(id);
          successCount.value++;
        } else {
          await queue.markError(id, resp.message);
          failCount.value++;
        }
      } catch (e) {
        _logger.e('Sync error for row ${row['id']}: $e');
        failCount.value++;
      }
    }

    isSyncing.value = false;
    _showSyncResultToast();
  }

  void _showSyncStartToast(int count) {
    toastification.show(
      title: Text('Syncing $count pending sale${count > 1 ? 's' : ''}…'),
      type: ToastificationType.info,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showSyncResultToast() {
    if (successCount.value > 0 && failCount.value == 0) {
      toastification.show(
        title: Text('${successCount.value} sale${successCount.value > 1 ? 's' : ''} synced successfully'),
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 4),
      );
    } else if (failCount.value > 0) {
      toastification.show(
        title: Text('${successCount.value} synced, ${failCount.value} failed — will retry'),
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 5),
      );
    }
  }
}
