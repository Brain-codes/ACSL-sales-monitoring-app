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

    // M1: this used to send an empty body, which the function answers with a
    // 400 "Missing organization_id" — so Stove Management was broken for every
    // role and silently fell back to whatever was cached. `format2` asks for
    // every organisation's stoves at once; the offline sync has always called
    // it this way (data_refresh_service._refreshAllStovesBulk).
    //
    // The function also caps one response at 500 rows and production holds
    // 22,032 stoves, so a single fetch is short by a factor of forty. Page with
    // an offset loop until the server's own total is reached.
    final supabase = ref.read(supabaseServiceProvider);
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final resp = await supabase.callEdgeFunction('get-stove-ids', body: {
        'format': 'format2',
        'limit': pageSize,
        'offset': offset,
      });

      if (!resp.success || resp.data == null) {
        // The first page failing means the call itself is broken — surface it
        // rather than pretending the cache is current. A later page failing
        // means we already have something worth showing, so keep it.
        if (offset == 0) {
          if (cached.isNotEmpty) return cached;
          throw resp.message;
        }
        break;
      }

      final page = _extractRows(resp.data);
      rows.addAll(page);

      final total = _totalFrom(resp.data);
      offset += pageSize;
      if (page.length < pageSize) break;
      if (total != null && offset >= total) break;
    }

    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => StoveModel.fromJson(e)).toList();
  }

  /// The server's own row count, when it reports one.
  int? _totalFrom(dynamic data) {
    if (data is! Map) return null;
    final pagination = data['pagination'];
    if (pagination is Map) {
      final t = int.tryParse('${pagination['total']}');
      if (t != null) return t;
    }
    return int.tryParse('${data['total']}');
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
