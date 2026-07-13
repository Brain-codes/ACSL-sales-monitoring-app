import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';

const _cacheKey = 'cache_payment_models_global';

/// Global payment models (settings-payment-models / payment-models). Offline-first
/// read via the `payment-models` edge function.
class PaymentModelsNotifier extends AsyncNotifier<List<PaymentModel>> {
  @override
  Future<List<PaymentModel>> build() => _load();

  Future<List<PaymentModel>> _load() async {
    final cache = ref.read(localCacheProvider);
    final connectivity = ref.read(connectivityProvider);

    final cached = cache
        .getJsonList(_cacheKey)
        .map((e) => PaymentModel.fromJson(e))
        .toList();

    if (!connectivity.isOnline.value) {
      if (cached.isEmpty) {
        throw 'No internet connection. Connect to load payment models.';
      }
      return cached;
    }

    final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
          'payment-models',
          body: {},
          method: 'GET',
        );

    if (!resp.success || resp.data == null) {
      if (cached.isNotEmpty) return cached;
      throw resp.message;
    }

    final rows = _extractRows(resp.data);
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => PaymentModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? data['payment_models'] as List? ?? []) : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final paymentModelsProvider =
    AsyncNotifierProvider<PaymentModelsNotifier, List<PaymentModel>>(
        PaymentModelsNotifier.new);
