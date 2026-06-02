import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';

class LocalCacheService extends GetxService {
  final _box = GetStorage();

  static const _keyStoves = 'cache_stoves';
  static const _keyStovesAt = 'cache_stoves_at';
  static const _keyPaymentModels = 'cache_payment_models';
  static const _keyPaymentModelsAt = 'cache_payment_models_at';
  static const _keySales = 'cache_sales';
  static const _keySalesAt = 'cache_sales_at';
  static const _keyGoogleKeys = 'cache_google_keys';
  static const _keyGoogleKeysAt = 'cache_google_keys_at';

  bool isStale(String timestampKey, {Duration ttl = const Duration(minutes: 5)}) {
    final raw = _box.read<String>(timestampKey);
    if (raw == null) return true;
    final saved = DateTime.tryParse(raw);
    if (saved == null) return true;
    return DateTime.now().difference(saved) > ttl;
  }

  // ── Stoves ────────────────────────────────────────────────────────────────

  void saveStoves(List<StoveModel> stoves) {
    _box.write(_keyStoves, jsonEncode(stoves.map((s) => s.toJson()).toList()));
    _box.write(_keyStovesAt, DateTime.now().toIso8601String());
  }

  List<StoveModel> getStoves() {
    final raw = _box.read<String>(_keyStoves);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  bool get hasStoves => _box.read<String>(_keyStoves) != null;

  // ── Payment Models ────────────────────────────────────────────────────────

  void savePaymentModels(List<PaymentModel> models) {
    _box.write(_keyPaymentModels, jsonEncode(models.map((m) => m.toJson()).toList()));
    _box.write(_keyPaymentModelsAt, DateTime.now().toIso8601String());
  }

  List<PaymentModel> getPaymentModels() {
    final raw = _box.read<String>(_keyPaymentModels);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  bool get hasPaymentModels => _box.read<String>(_keyPaymentModels) != null;

  // ── Per-org stoves (ACSL agents) ──────────────────────────────────────────

  void saveStovesForOrg(String orgId, List<StoveModel> stoves) {
    _box.write('cache_stoves_$orgId', jsonEncode(stoves.map((s) => s.toJson()).toList()));
    _box.write('cache_stoves_${orgId}_at', DateTime.now().toIso8601String());
  }

  List<StoveModel> getStovesForOrg(String orgId) {
    final raw = _box.read<String>('cache_stoves_$orgId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Per-org payment models (ACSL agents) ──────────────────────────────────

  void savePaymentModelsForOrg(String orgId, List<PaymentModel> models) {
    _box.write('cache_payment_models_$orgId', jsonEncode(models.map((m) => m.toJson()).toList()));
    _box.write('cache_payment_models_${orgId}_at', DateTime.now().toIso8601String());
  }

  List<PaymentModel> getPaymentModelsForOrg(String orgId) {
    final raw = _box.read<String>('cache_payment_models_$orgId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Assigned partners (ACSL agents) ───────────────────────────────────────

  void saveAssignedPartners(List<Map<String, dynamic>> partners) {
    _box.write('cache_assigned_partners', jsonEncode(partners));
    _box.write('cache_assigned_partners_at', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>> getAssignedPartners() {
    final raw = _box.read<String>('cache_assigned_partners');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Sales ─────────────────────────────────────────────────────────────────

  void saveSales(List<SaleModel> sales) {
    _box.write(_keySales, jsonEncode(sales.map((s) => s.toJson()).toList()));
    _box.write(_keySalesAt, DateTime.now().toIso8601String());
  }

  List<SaleModel> getSales() {
    final raw = _box.read<String>(_keySales);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Google Keys ───────────────────────────────────────────────────────────

  void saveGoogleKeys(String placesKey, String mapsKey) {
    _box.write(_keyGoogleKeys, jsonEncode({'placesKey': placesKey, 'mapsKey': mapsKey}));
    _box.write(_keyGoogleKeysAt, DateTime.now().toIso8601String());
  }

  Map<String, String>? getGoogleKeys() {
    final raw = _box.read<String>(_keyGoogleKeys);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map;
      return {'placesKey': map['placesKey'] as String? ?? '', 'mapsKey': map['mapsKey'] as String? ?? ''};
    } catch (_) {
      return null;
    }
  }

  // ── Last sync time (most recent of all timestamps) ────────────────────────

  DateTime? get lastSyncedAt {
    final keys = [_keyStovesAt, _keyPaymentModelsAt, _keySalesAt, _keyGoogleKeysAt];
    DateTime? latest;
    for (final k in keys) {
      final raw = _box.read<String>(k);
      if (raw == null) continue;
      final dt = DateTime.tryParse(raw);
      if (dt != null && (latest == null || dt.isAfter(latest))) {
        latest = dt;
      }
    }
    return latest;
  }
}
