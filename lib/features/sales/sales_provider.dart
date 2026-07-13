import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';

/// Sales list for analytics/reporting (Riverpod). Reuses the existing sales
/// cache for offline reads. Reads through `get-sales-advanced` only.
class SalesNotifier extends AsyncNotifier<List<SaleModel>> {
  @override
  Future<List<SaleModel>> build() => _load();

  Future<List<SaleModel>> _load() async {
    final cache = ref.read(localCacheProvider);
    final connectivity = ref.read(connectivityProvider);

    final cached = cache.getSales();

    if (!connectivity.isOnline.value) {
      if (cached.isEmpty) {
        throw 'No internet connection. Connect to load sales.';
      }
      return cached;
    }

    final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
          'get-sales-advanced',
          body: {'page': 1, 'limit': 500, 'responseFormat': 'format2'},
        );

    if (!resp.success || resp.data == null) {
      if (cached.isNotEmpty) return cached;
      throw resp.message;
    }

    final rows = _extractRows(resp.data);
    final sales = rows.map((e) => SaleModel.fromJson(e)).toList();
    cache.saveSales(sales);
    return sales;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? data['sales'] as List? ?? []) : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final salesProvider =
    AsyncNotifierProvider<SalesNotifier, List<SaleModel>>(SalesNotifier.new);
