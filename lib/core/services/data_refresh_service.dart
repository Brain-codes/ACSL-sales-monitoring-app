import 'dart:async';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/geo_data_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/features/partners/partner_access_service.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';

class DataRefreshService extends GetxService {
  final _logger = Logger();

  /// Drives the floating pill / Profile "Refreshing…" state. Only ever set
  /// true for a LOUD refresh (first-ever sync, or a manual tap on "Refresh
  /// Data" in Profile). Silent background refreshes never touch this, so
  /// they run with no visible indication anywhere in the app.
  final RxBool isRefreshing = false.obs;
  final Rxn<DateTime> lastRefreshedAt = Rxn();

  /// Internal concurrency guard covering BOTH loud and silent runs, so a
  /// silent hourly tick can never overlap a manual refresh (or vice versa).
  bool _inFlight = false;

  /// Live progress for the floating sync indicator. [syncStage] is a short
  /// human label ("Getting stoves…") and [syncProgress] is 0‥1. They let the
  /// pill show real, moving progress instead of a static spinner so the user
  /// can see the sync is genuinely working. Only updated during loud runs.
  final RxString syncStage = ''.obs;
  final RxDouble syncProgress = 0.0.obs;

  void _stage(String label, double progress) {
    syncStage.value = label;
    syncProgress.value = progress.clamp(0.0, 1.0);
  }

  Timer? _timer;

  /// True once we have persisted, on-device data from a previous sync (this
  /// session or an earlier one) — i.e. this is NOT the user's first ever
  /// fetch. Used to decide whether a refresh needs to be loud.
  bool _hasPersistedCache() {
    try {
      final cache = Get.find<LocalCacheService>();
      return cache.getAssignedPartners().isNotEmpty || cache.getSales().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Pull a COMPLETE dataset on every launch when online — not just on login.
    // Loud only the very first time ever (nothing cached yet); otherwise the
    // user already has last-session's data on screen, so this happens quietly
    // in the background — "last sync is as good as the last time you were
    // online". refreshAll self-guards on connectivity, so this is a no-op
    // offline.
    refreshAll(silent: true);
    _startPeriodicTimer();
  }

  /// Hourly background refresh. Skipped during closing hours (12am–5am) —
  /// nobody is working then, so there's nothing worth silently fetching for.
  /// Always silent: the user only ever sees refresh activity by opening
  /// Profile and tapping "Refresh Data" (or on the very first sync).
  void _startPeriodicTimer() {
    _timer = Timer.periodic(const Duration(hours: 1), (_) {
      final hour = DateTime.now().hour;
      if (hour >= 0 && hour < 5) return; // closing hours — skip
      final connectivity = Get.find<ConnectivityService>();
      if (connectivity.isOnline.value) {
        refreshAll(silent: true);
      }
    });
  }

  /// Refreshes every offline-cached dataset.
  ///
  /// [silent] requests a background run with no visible UI (no floating
  /// pill, no progress stage) — used for the hourly tick and reconnect
  /// fetches. It's automatically upgraded to a LOUD run when there's no
  /// persisted cache yet, since the user genuinely needs to see that their
  /// first download is in progress. A manual "Refresh Data" tap always
  /// passes `silent: false` and is always loud.
  /// Returns true when the refresh brought down data that differed from what
  /// was already on the device.
  Future<bool> refreshAll({bool silent = false}) async {
    if (_inFlight) return false;
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.isOnline.value) return false;

    final loud = !silent || !_hasPersistedCache();
    final cache = Get.find<LocalCacheService>();
    final mutationsBefore = cache.mutationCount;

    _inFlight = true;
    if (loud) {
      isRefreshing.value = true;
      _stage('Preparing sync…', 0.02);
    }
    try {
      final session = Get.find<SessionManager>();
      // Offline-first: download stove IDs + payment models for EVERY partner org
      // the user can access (super admin = all orgs, ACSL agent = assigned),
      // regardless of role, so any partner picked while offline has its stoves.
      //
      // Run STAGED (not one big Future.wait) so the floating indicator can
      // report a real, moving label + percentage. The stove step dominates the
      // time, so it owns the widest progress band (10 → 70%).
      //
      // Hard overall timeout: some steps hit Supabase tables directly (no
      // per-call timeout), so a connection that drops mid-fetch could otherwise
      // hang this future forever — leaving isRefreshing stuck true and the
      // indicator spinning endlessly. Cap the whole run.
      await () async {
        // Cheap (one small call, TTL-gated to ~weekly) and the create-sale form
        // is unusable without it, so it runs FIRST — behind the 900-org partner
        // sync it would be the first casualty of the overall timeout below.
        if (loud) _stage('Getting states & LGAs…', 0.03);
        await Get.find<GeoDataService>().refresh();
        await _refreshAllPartnersData(session, loud: loud);
        if (loud) _stage('Getting payment models…', 0.72);
        await _refreshGlobalPaymentModels();
        if (loud) _stage('Getting sales…', 0.82);
        await _refreshSales();
        if (loud) _stage('Getting customer phone numbers…', 0.90);
        await _refreshEndUserPhones();
        if (loud) _stage('Getting location keys…', 0.94);
        await _refreshGoogleKeys();
        if (loud) _stage('Finishing up…', 1.0);
      }()
          // Generous cap: a full sync of 900+ orgs is legitimately long, so this
          // only trips on a true hang — never truncates a valid large refresh.
          .timeout(const Duration(minutes: 6));
      lastRefreshedAt.value = DateTime.now();
    } catch (e) {
      _logger.e('DataRefreshService.refreshAll error: $e');
    } finally {
      _inFlight = false;
      if (loud) {
        isRefreshing.value = false;
        syncStage.value = '';
        syncProgress.value = 0.0;
      }
    }
    return cache.mutationCount != mutationsBefore;
  }

  // ── Fetch accessible partners, then stoves + models for every partner org ──

  Future<void> _refreshAllPartnersData(SessionManager session,
      {required bool loud}) async {
    final userId = session.userId;
    if (userId == null || userId.isEmpty) return;

    final cache = Get.find<LocalCacheService>();
    final supabase = Get.find<SupabaseService>();

    if (loud) _stage('Getting partners…', 0.05);

    // 1. Fetch every partner the user can access (super admin = all orgs,
    //    ACSL agent = assigned partners), via the same source the sale picker uses.
    List<Map<String, dynamic>> partners;
    try {
      partners = await PartnerAccessService().partnersForUser(
        userId: userId,
        role: session.role,
      );
    } catch (e) {
      _logger.w('Partner refresh failed: $e');
      return;
    }
    cache.saveAssignedPartners(partners);
    _logger.d('Cached ${partners.length} accessible partners');
    if (loud) _stage('Getting stoves…', 0.10);

    // 2. For each partner org, download its stove IDs so they're available
    //    offline when that partner is picked in create-sale. (Payment models are
    //    global — fetched once elsewhere, NOT per org.)
    //    BOUNDED CONCURRENCY: with 900+ orgs, firing every fetch at once would
    //    open hundreds of simultaneous requests → rate-limits / dropped
    //    connections / partial caches. Process in small pools instead.
    final orgIds = partners
        .map((p) => p['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    // Fast path: pull every org's available stoves in ~34 bulk pages (format2)
    // instead of ~900 per-org calls. Falls back to the per-org pool if the
    // deployed edge function doesn't support format2 yet, so this ships safely
    // before the backend is deployed.
    final bulkOk = await _refreshAllStovesBulk(orgIds, supabase, cache, loud: loud);
    if (!bulkOk) {
      _logger.w('Bulk stove fetch unsupported — falling back to per-org.');
      await _runPooled(
        orgIds,
        concurrency: 8,
        task: (orgId) => _refreshStovesForOrg(orgId, supabase, cache),
      );
    }
  }

  /// Downloads available stoves for ALL orgs via `get-stove-ids` format2 (bulk),
  /// paging through and grouping by organization_id client-side, then caching
  /// per org. Returns false if format2 isn't supported by the deployed function
  /// (caller then falls back to per-org fetching).
  Future<bool> _refreshAllStovesBulk(
    List<String> orgIds,
    SupabaseService supabase,
    LocalCacheService cache, {
    required bool loud,
  }) async {
    const pageSize = 500;
    final byOrg = <String, List<StoveModel>>{};
    var offset = 0;
    var gotAnyPage = false;

    while (true) {
      final resp = await supabase.callEdgeFunction('get-stove-ids', body: {
        'status': 'available',
        'format': 'format2',
        'limit': pageSize,
        'offset': offset,
      });
      if (!resp.success || resp.data == null) {
        // First page failed → format2 not supported (old function 400s on the
        // missing organization_id) → signal fallback. Later page failed → stop
        // and keep what we have.
        if (!gotAnyPage) return false;
        break;
      }
      gotAnyPage = true;

      final data = resp.data;
      final list = data is List
          ? data
          : ((data as Map?))?['data'] as List? ?? [];
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final orgId = map['organization_id']?.toString() ?? '';
        if (orgId.isEmpty) continue;
        final stove = StoveModel.fromJson(map);
        if (stove.stoveId.isEmpty) continue;
        (byOrg[orgId] ??= []).add(stove);
      }

      final total = data is Map
          ? int.tryParse('${(data['pagination'] as Map?)?['total']}')
          : null;
      offset += pageSize;
      // Map paging progress into the stove band (10 → 70%).
      if (loud && total != null && total > 0) {
        final frac = (offset / total).clamp(0.0, 1.0);
        _stage('Getting stoves… ${(frac * 100).round()}%', 0.10 + 0.60 * frac);
      }
      if (list.length < pageSize) break;
      if (total != null && offset >= total) break;
    }

    // Cache grouped stoves. Every known partner gets an entry — an empty list
    // for orgs with no available stock — so the offline picker and debug page
    // reflect the truth instead of falling back to a stale cache.
    for (final orgId in orgIds) {
      cache.saveStovesForOrg(orgId, byOrg[orgId] ?? const []);
    }
    for (final entry in byOrg.entries) {
      if (!orgIds.contains(entry.key)) {
        cache.saveStovesForOrg(entry.key, entry.value);
      }
    }
    _logger.d('Bulk-cached stoves for ${byOrg.length}/${orgIds.length} partners');
    return true;
  }

  /// Runs [task] over [items] with at most [concurrency] in flight at once.
  Future<void> _runPooled<T>(
    List<T> items, {
    required int concurrency,
    required Future<void> Function(T) task,
  }) async {
    var index = 0;
    Future<void> worker() async {
      while (index < items.length) {
        final item = items[index++];
        try {
          await task(item);
        } catch (_) {
          // Per-item failures are swallowed inside the task; keep the pool going.
        }
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, items.isEmpty ? 1 : items.length),
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  Future<void> _refreshStovesForOrg(
    String orgId,
    SupabaseService supabase,
    LocalCacheService cache,
  ) async {
    try {
      // get-stove-ids caps `limit` at 500 per call, so page through every
      // available stove (some orgs hold hundreds of thousands) and cache them
      // all — otherwise the offline picker silently sees only the first page.
      const pageSize = 500;
      final stoves = <StoveModel>[];
      var offset = 0;
      while (true) {
        final resp = await supabase.callEdgeFunction(
          'get-stove-ids',
          body: {
            'status': 'available',
            'organization_id': orgId,
            'limit': pageSize,
            'offset': offset,
          },
        );
        if (!resp.success || resp.data == null) break;

        final data = resp.data;
        final list = data is List
            ? data
            : ((data as Map?))?['data'] as List? ?? [];
        stoves.addAll(list
            .map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty));

        // Stop when we've pulled the last page. Prefer the server's reported
        // total; fall back to "short page" detection if it's absent.
        final total = data is Map
            ? int.tryParse(
                (data['pagination'] as Map?)?['total']?.toString() ?? '')
            : null;
        offset += pageSize;
        if (list.length < pageSize) break;
        if (total != null && offset >= total) break;
      }

      cache.saveStovesForOrg(orgId, stoves);
      _logger.d('Cached ${stoves.length} stoves for org $orgId');
    } catch (e) {
      _logger.w('Stove refresh failed for org $orgId: $e');
    }
  }

  /// Payment models are GLOBAL (decoupled from partners) — one active list
  /// applies to every sale. Fetch it once and cache it globally; the create-sale
  /// form already reads this global cache via `getPaymentModels()`.
  Future<void> _refreshGlobalPaymentModels() async {
    try {
      final supabase = Get.find<SupabaseService>();
      final resp = await supabase.callEdgeFunction(
        'payment-models',
        body: {},
        method: 'GET',
      );
      if (resp.success && resp.data != null) {
        final raw = resp.data is List
            ? resp.data as List
            : ((resp.data as Map?))?['data'] as List? ?? [];
        final list = raw.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return map.containsKey('payment_model') && map['payment_model'] is Map
              ? Map<String, dynamic>.from(map['payment_model'] as Map)
              : map;
        }).where((m) => m['id'] != null).toList();
        final models = list.map((e) => PaymentModel.fromJson(e)).toList();
        Get.find<LocalCacheService>().savePaymentModels(models);
        _logger.d('Cached ${models.length} global payment models');
      }
    } catch (e) {
      _logger.w('Global payment models refresh failed: $e');
    }
  }

  Future<void> _refreshSales() async {
    try {
      final supabase = Get.find<SupabaseService>();
      final resp = await supabase.callEdgeFunction(
        'get-sales-advanced',
        body: {'page': 1, 'limit': 100, 'responseFormat': 'format2', 'includeCreator': true},
      );
      if (resp.success && resp.data != null) {
        List raw = [];
        if (resp.data is List) {
          raw = resp.data as List;
        } else if (resp.data is Map) {
          raw = (resp.data as Map)['data'] as List? ?? (resp.data as Map)['sales'] as List? ?? [];
        }
        final sales = raw.map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        Get.find<LocalCacheService>().saveSales(sales);
      }
    } catch (e) {
      _logger.w('Sales refresh failed: $e');
    }
  }

  /// Caches the normalized end-user phone of EVERY sale, so the create-sale
  /// form can reject a duplicate while offline.
  ///
  /// Phones only — deliberately not the sale rows. `get-end-user-phones`
  /// returns bare 10-digit keys for the whole table in one call, which stays
  /// small enough to hold on device at 20k+ sales. It is also global rather
  /// than org-scoped: uniqueness spans every partner, so the cache is identical
  /// no matter who is logged in.
  Future<void> _refreshEndUserPhones() async {
    try {
      final supabase = Get.find<SupabaseService>();
      final resp = await supabase.callEdgeFunction(
        'get-end-user-phones',
        body: {},
        method: 'GET',
      );
      if (!resp.success || resp.data == null) {
        _logger.w('End-user phone refresh returned no data');
        return;
      }
      final data = resp.data;
      final List raw = data is List
          ? data
          : (data is Map ? (data['data'] as List? ?? []) : []);
      // A truncated set would silently let duplicates through offline, so keep
      // the previous (complete) cache rather than replacing it with a partial one.
      final truncated = data is Map && data['truncated'] == true;
      if (truncated) {
        _logger.w('End-user phone list truncated by the server — keeping cache');
        return;
      }
      final phones = raw.map((e) => e.toString()).where((e) => e.isNotEmpty);
      Get.find<LocalCacheService>().saveEndUserPhones(phones);
    } catch (e) {
      _logger.w('End-user phone refresh failed: $e');
    }
  }

  Future<void> _refreshGoogleKeys() async {
    try {
      final supabase = Get.find<SupabaseService>();
      final resp = await supabase.callEdgeFunction('get-google-keys', body: {}, method: 'GET');
      if (resp.success && resp.data != null) {
        final data = Map<String, dynamic>.from(resp.data as Map);
        final placesKey = data['placesKey'] as String? ?? '';
        final mapsKey = data['mapsKey'] as String? ?? '';
        Get.find<LocalCacheService>().saveGoogleKeys(placesKey, mapsKey);
      }
    } catch (e) {
      _logger.w('Google keys refresh failed: $e');
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
