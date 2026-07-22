import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/constants/nigeria_data.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

/// Centralized Nigeria states + LGA data for the mobile app.
///
/// Priority: local cache → `geo-data` edge function → bundled [NigeriaData].
/// The bundled constant is the ultimate offline / error fallback so the
/// create-sale form always has data even with no cache and no network.
///
/// Reads are offline-first: [states] / [lgaByState] are populated from cache
/// (or bundled) synchronously in [onInit]; [refresh] then updates them from the
/// backend when online. Callers observe the reactive fields or call [getLgas].
class GeoDataService extends GetxService {
  final _logger = Logger();

  final RxList<String> states = <String>[].obs;
  final RxMap<String, List<String>> lgaByState =
      <String, List<String>>{}.obs;

  static const _cacheKey = 'cache_geo_data';

  /// Below this, a payload is treated as junk and never allowed to replace the
  /// bundled/cached data (Nigeria has 37 states).
  static const _minStates = 30;

  /// States/LGAs change at most once in years, and the backend only refreshes
  /// weekly, so re-fetching on every 5-minute sync cycle is pure waste on a
  /// field agent's mobile data. Matches the backend cron cadence.
  static const _ttl = Duration(days: 7);

  @override
  void onInit() {
    super.onInit();
    _loadFromCacheOrBundled();
  }

  void _loadFromCacheOrBundled() {
    final cached = Get.find<LocalCacheService>().getJsonMap(_cacheKey);
    if (cached != null && (cached['states'] as List?)?.isNotEmpty == true) {
      _apply(cached);
    } else {
      _applyBundled();
    }
  }

  void _applyBundled() {
    states.assignAll(NigeriaData.states);
    lgaByState.assignAll(
      NigeriaData.lgaByState
          .map((k, v) => MapEntry(k, List<String>.from(v))),
    );
  }

  /// Apply a `{ states: [...], lgas: { state: [...] } }` payload; falls back to
  /// bundled data if the payload has no states.
  void _apply(Map<String, dynamic> data) {
    final s = (data['states'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    if (s.isEmpty) {
      _applyBundled();
      return;
    }
    final lgasRaw = (data['lgas'] as Map?) ?? const {};
    final m = <String, List<String>>{};
    lgasRaw.forEach((k, v) {
      m[k.toString()] =
          (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    });
    states.assignAll(s);
    lgaByState.assignAll(m);
  }

  /// LGAs for [state]; falls back to bundled data if the loaded set lacks it.
  List<String> getLgas(String state) {
    final l = lgaByState[state];
    if (l != null && l.isNotEmpty) return l;
    return NigeriaData.getLgas(state);
  }

  /// Refresh from the `geo-data` edge function. Non-destructive: a failed call
  /// or a below-threshold payload leaves the current data untouched.
  ///
  /// Skips the network entirely while the cached copy is younger than [_ttl];
  /// pass [force] to bypass that (e.g. a manual pull-to-refresh).
  Future<void> refresh({bool force = false}) async {
    final cache = Get.find<LocalCacheService>();
    if (!force && !cache.isStale('${_cacheKey}_at', ttl: _ttl)) return;

    try {
      final resp = await Get.find<SupabaseService>().callEdgeFunction(
        'geo-data',
        body: const {},
        method: 'GET',
      );
      if (!resp.success || resp.data == null) return;
      final data = Map<String, dynamic>.from(resp.data as Map);
      if (data['success'] != true) return;

      final s =
          (data['states'] as List?)?.map((e) => e.toString()).toList() ??
              <String>[];
      if (s.length < _minStates) {
        _logger.w('geo-data payload below threshold (${s.length}); ignored');
        return;
      }

      _apply(data);
      cache.saveJsonMap(_cacheKey, {
        'states': s,
        'lgas': data['lgas'] ?? {},
      });
      _logger.i('geo-data refreshed: ${s.length} states');
    } catch (e) {
      _logger.w('geo-data refresh failed: $e');
    }
  }
}
