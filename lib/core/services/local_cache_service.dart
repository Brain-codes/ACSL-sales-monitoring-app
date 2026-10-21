import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static const _keyEndUserPhones = 'cache_end_user_phones';
  static const _keyEndUserPhonesAt = 'cache_end_user_phones_at';

  static const _keyDevAutofill = 'dev_autofill_enabled';

  /// Whether the create-sale test-autofill backdoor is enabled. Defaults to
  /// [kDebugMode]: ON in debug/dev builds, OFF in release builds (e.g.
  /// `flutter build apk`) so the backdoor never ships. Can still be toggled
  /// from the profile page when that card is enabled.
  bool get devAutofillEnabled => _box.read<bool>(_keyDevAutofill) ?? kDebugMode;
  set devAutofillEnabled(bool v) => _box.write(_keyDevAutofill, v);

  /// Writes [encoded] under [key] only when it differs from what's already
  /// cached; the "last updated" stamp is refreshed either way.
  ///
  /// Background refreshes re-fetch the same rows most of the time. Rewriting
  /// an identical multi-megabyte payload churns storage for nothing, so an
  /// unchanged fetch just updates the timestamp and is otherwise discarded.
  /// Returns true when the cached data actually changed.
  bool _writeIfChanged(String key, String atKey, String encoded) {
    final changed = _box.read<String>(key) != encoded;
    if (changed) {
      _box.write(key, encoded);
      mutationCount++;
    }
    _box.write(atKey, DateTime.now().toIso8601String());
    return changed;
  }

  /// Bumped every time a cached dataset actually changes. A refresh can
  /// compare this before/after to tell "new data arrived" from "same data".
  int mutationCount = 0;

  bool isStale(String timestampKey, {Duration ttl = const Duration(minutes: 5)}) {
    final raw = _box.read<String>(timestampKey);
    if (raw == null) return true;
    final saved = DateTime.tryParse(raw);
    if (saved == null) return true;
    return DateTime.now().difference(saved) > ttl;
  }

  // ── Generic JSON-list cache (offline-first reads for new features) ──────────

  /// Cache a list of JSON maps under [key] (e.g. 'cache_agents').
  void saveJsonList(String key, List<Map<String, dynamic>> rows) {
    _box.write(key, jsonEncode(rows));
    _box.write('${key}_at', DateTime.now().toIso8601String());
  }

  /// Read a cached list of JSON maps for [key]; empty if absent/corrupt.
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _box.read<String>(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Cache a single JSON map under [key].
  void saveJsonMap(String key, Map<String, dynamic> value) {
    _box.write(key, jsonEncode(value));
    _box.write('${key}_at', DateTime.now().toIso8601String());
  }

  /// Read a cached single JSON map for [key]; null if absent/corrupt.
  Map<String, dynamic>? getJsonMap(String key) {
    final raw = _box.read<String>(key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  // ── Dashboard stats (offline-first, per year) ───────────────────────────────

  /// Persist the raw dashboard stats payload for [year] so the dashboard can
  /// render from cache while offline.
  void saveDashboardStats(int year, Map<String, dynamic> payload) {
    _box.write('cache_dashboard_$year', jsonEncode(payload));
    _box.write('cache_dashboard_${year}_at', DateTime.now().toIso8601String());
  }

  /// Read the cached dashboard stats payload for [year], or null if none.
  Map<String, dynamic>? getDashboardStats(int year) {
    final raw = _box.read<String>('cache_dashboard_$year');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// When the cached dashboard stats for [year] were last saved (null if never).
  DateTime? dashboardStatsSavedAt(int year) {
    final raw = _box.read<String>('cache_dashboard_${year}_at');
    return raw == null ? null : DateTime.tryParse(raw);
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
    _writeIfChanged(_keyPaymentModels, _keyPaymentModelsAt,
        jsonEncode(models.map((m) => m.toJson()).toList()));
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

  // ── End-user phones (global uniqueness, offline) ──────────────────────────
  //
  // Every sale must have a unique end-user phone, and that has to be enforced
  // while offline. We cache ONLY the normalized 10-digit keys — never the sale
  // rows — so 20k+ sales costs a few hundred KB instead of tens of MB. The set
  // is global and role-independent: a number taken by any partner is taken for
  // everyone, so the same cache serves every logged-in user.

  /// In-memory mirror so lookups don't re-decode a 20k-entry list per keystroke.
  /// Invalidated on write; rebuilt lazily on first read.
  Set<String>? _phoneSetCache;

  void saveEndUserPhones(Iterable<String> normalizedPhones) {
    final unique = normalizedPhones.where((p) => p.isNotEmpty).toSet();
    _writeIfChanged(_keyEndUserPhones, _keyEndUserPhonesAt, jsonEncode(unique.toList()));
    _phoneSetCache = unique;
  }

  /// The cached set of normalized end-user phones. Keys only — see above.
  Set<String> getEndUserPhones() {
    final cached = _phoneSetCache;
    if (cached != null) return cached;
    final raw = _box.read<String>(_keyEndUserPhones);
    if (raw == null) return _phoneSetCache = <String>{};
    try {
      final list = jsonDecode(raw) as List;
      return _phoneSetCache = list.map((e) => e.toString()).toSet();
    } catch (_) {
      return _phoneSetCache = <String>{};
    }
  }

  /// Adds one number without a full re-download — used after a sale is created
  /// (including an offline one) so the very next sale sees it as taken.
  void addEndUserPhone(String normalizedPhone) {
    if (normalizedPhone.isEmpty) return;
    final set = {...getEndUserPhones(), normalizedPhone};
    saveEndUserPhones(set);
  }

  int get endUserPhoneCount => getEndUserPhones().length;

  DateTime? get endUserPhonesCachedAt {
    final raw = _box.read<String>(_keyEndUserPhonesAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // ── Buyer keys (same customer, same phone) ────────────────────────────────
  //
  // 16-char keys from get-end-user-phones, scoped to what the signed-in
  // account can see — so they MUST be cleared when another user signs in
  // ([clear]). The title rules ride with them; the two are saved together.

  static const _keyBuyerKeys = 'cache_buyer_keys';
  static const _keyBuyerKeyRules = 'cache_buyer_key_rules';
  static const _keyEndUserPhonesEtag = 'cache_end_user_phones_etag';

  Set<String>? _buyerKeySetCache;

  void saveBuyerKeys(Iterable<String> keys, Map<String, dynamic> rules) {
    final unique = keys.where((k) => k.isNotEmpty).toSet();
    _box.write(_keyBuyerKeys, jsonEncode(unique.toList()));
    _box.write(_keyBuyerKeyRules, jsonEncode(rules));
    _buyerKeySetCache = unique;
  }

  Set<String> getBuyerKeys() {
    final cached = _buyerKeySetCache;
    if (cached != null) return cached;
    final raw = _box.read<String>(_keyBuyerKeys);
    try {
      return _buyerKeySetCache = raw == null
          ? <String>{}
          : (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return _buyerKeySetCache = <String>{};
    }
  }

  bool get hasBuyerKeys => _box.read<String>(_keyBuyerKeys) != null;
  bool get hasEndUserPhones => _box.read<String>(_keyEndUserPhones) != null;

  void addBuyerKey(String key) {
    if (key.isEmpty) return;
    final set = {...getBuyerKeys(), key};
    _box.write(_keyBuyerKeys, jsonEncode(set.toList()));
    _buyerKeySetCache = set;
  }

  Map<String, dynamic> get _buyerKeyRules {
    final raw = _box.read<String>(_keyBuyerKeyRules);
    if (raw == null) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  /// Titles the key drops. Empty before the first successful fetch.
  List<String> getBuyerKeyTitles() =>
      ((_buyerKeyRules['titles'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  String? get buyerKeyRulesVersion => _buyerKeyRules['version']?.toString();

  /// The ETag exactly as received (it may be weak, `W/"…"`).
  String? get endUserPhonesEtag => _box.read<String>(_keyEndUserPhonesEtag);
  set endUserPhonesEtag(String? v) => v == null
      ? _box.remove(_keyEndUserPhonesEtag)
      : _box.write(_keyEndUserPhonesEtag, v);

  /// Empties every in-memory set. Call after the storage is erased, or the
  /// previous user's phones and keys outlive the wipe.
  void clear() {
    _phoneSetCache = null;
    _buyerKeySetCache = null;
  }

  // ── Per-org stoves (ACSL agents) ──────────────────────────────────────────

  void saveStovesForOrg(String orgId, List<StoveModel> stoves) {
    _writeIfChanged('cache_stoves_$orgId', 'cache_stoves_${orgId}_at',
        jsonEncode(stoves.map((s) => s.toJson()).toList()));
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
    _writeIfChanged('cache_assigned_partners', 'cache_assigned_partners_at',
        jsonEncode(partners));
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
    _writeIfChanged(_keySales, _keySalesAt,
        jsonEncode(sales.map((s) => s.toJson()).toList()));
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
