import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/services/paged_fetch.dart';
import 'package:stove_transaction/features/stoves/models/transfer_record_model.dart';

const _cacheKey = 'cache_transfer_history';

/// Stove transfer history (stove-transfer-history). Offline-first read via
/// `get-transfer-history`.
class TransferHistoryNotifier extends AsyncNotifier<List<TransferRecordModel>> {
  @override
  Future<List<TransferRecordModel>> build() => _load();

  Future<List<TransferRecordModel>> _load() async {
    final cache = ref.read(localCacheProvider);
    final connectivity = ref.read(connectivityProvider);

    final cached = cache
        .getJsonList(_cacheKey)
        .map((e) => TransferRecordModel.fromJson(e))
        .toList();

    if (!connectivity.isOnline.value) {
      if (cached.isEmpty) {
        throw 'No internet connection. Connect to load transfer history.';
      }
      return cached;
    }

    // M10: asked for 50 rows once, ignored has_more, and showed that as the
    // whole history. The function caps a response at 200; page to the end.
    List<Map<String, dynamic>> rows;
    try {
      rows = await fetchAllPages(
        ref.read(supabaseServiceProvider),
        'get-transfer-history',
        pageSize: 200,
        queryParams: const {'sort_order': 'desc'},
        errorMessage: 'Could not load transfer history',
      );
    } catch (e) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => TransferRecordModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

}

final transferHistoryProvider =
    AsyncNotifierProvider<TransferHistoryNotifier, List<TransferRecordModel>>(
        TransferHistoryNotifier.new);
