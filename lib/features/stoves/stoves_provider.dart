import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';

const _cacheKey = 'cache_all_stoves';

/// Full stove inventory for super admin (stove-management). Offline-first:
/// serves cache, refreshes from `get-stove-ids`. Status/search filtering is
/// done client-side in the screen.
class StovesNotifier extends AsyncNotifier<List<StoveModel>> {
  @override
  Future<List<StoveModel>> build() => _load();

  Future<List<StoveModel>> _load() async {
    final cache = ref.read(localCacheProvider);
    final connectivity = ref.read(connectivityProvider);

    final cached = cache
        .getJsonList(_cacheKey)
        .map((e) => StoveModel.fromJson(e))
        .toList();

    if (!connectivity.isOnline.value) {
      if (cached.isEmpty) {
        throw 'No internet connection. Connect to load stove inventory.';
      }
      return cached;
    }

    final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
          'get-stove-ids',
          body: {},
        );

    if (!resp.success || resp.data == null) {
      if (cached.isNotEmpty) return cached;
      throw resp.message;
    }

    final rows = _extractRows(resp.data);
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => StoveModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? data['stoves'] as List? ?? []) : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final stovesProvider =
    AsyncNotifierProvider<StovesNotifier, List<StoveModel>>(StovesNotifier.new);
