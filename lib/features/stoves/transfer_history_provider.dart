import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
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

    final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
          'get-transfer-history',
          body: {},
          method: 'GET',
          queryParams: {'limit': '50', 'offset': '0', 'sort_order': 'desc'},
        );

    if (!resp.success || resp.data == null) {
      if (cached.isNotEmpty) return cached;
      throw resp.message;
    }

    final rows = _extractRows(resp.data);
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => TransferRecordModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? []) : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final transferHistoryProvider =
    AsyncNotifierProvider<TransferHistoryNotifier, List<TransferRecordModel>>(
        TransferHistoryNotifier.new);
