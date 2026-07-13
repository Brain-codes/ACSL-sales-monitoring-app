import 'dart:async';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/features/partners/partner_access_service.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';

class DataRefreshService extends GetxService {
  final _logger = Logger();
  final RxBool isRefreshing = false.obs;
  final Rxn<DateTime> lastRefreshedAt = Rxn();

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    // Pull a COMPLETE dataset on every launch when online — not just on login.
    // Restored-session cold starts otherwise kept whatever was cached before
    // (e.g. a stale, previously-capped partner list) until a reconnect or the
    // 5-min timer. refreshAll self-guards on connectivity, so this is a no-op
    // offline.
    refreshAll();
    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      final connectivity = Get.find<ConnectivityService>();
      if (connectivity.isOnline.value) {
        refreshAll();
      }
    });
  }

  Future<void> refreshAll() async {
    if (isRefreshing.value) return;
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.isOnline.value) return;

    isRefreshing.value = true;
    try {
      final session = Get.find<SessionManager>();
      // Offline-first: download stove IDs + payment models for EVERY partner org
      // the user can access (super admin = all orgs, ACSL agent = assigned),
      // regardless of role, so any partner picked while offline has its stoves.
      //
      // Hard overall timeout: some steps hit Supabase tables directly (no
      // per-call timeout), so a connection that drops mid-fetch could otherwise
      // hang this future forever — leaving isRefreshing stuck true and the
      // "Syncing data…" indicator spinning endlessly. Cap the whole run.
      await () async {
        await Future.wait([
          _refreshAllPartnersData(session),
          _refreshSales(),
          _refreshGoogleKeys(),
          // Payment models are GLOBAL now (not tied to a partner) — fetch the
          // whole active list ONCE here instead of once per org. That removes
          // ~900 redundant calls from the sync, the biggest single speed-up.
          _refreshGlobalPaymentModels(),
        ]);
      }()
          // Generous cap: a full sync of 900+ orgs is legitimately long, so this
          // only trips on a true hang — never truncates a valid large refresh.
          .timeout(const Duration(minutes: 6));
      lastRefreshedAt.value = DateTime.now();
    } catch (e) {
      _logger.e('DataRefreshService.refreshAll error: $e');
    } finally {
      isRefreshing.value = false;
    }
  }

  // ── Fetch accessible partners, then stoves + models for every partner org ──

  Future<void> _refreshAllPartnersData(SessionManager session) async {
    final userId = session.userId;
    if (userId == null || userId.isEmpty) return;

    final cache = Get.find<LocalCacheService>();
    final supabase = Get.find<SupabaseService>();

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
    final bulkOk = await _refreshAllStovesBulk(orgIds, supabase, cache);
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
    LocalCacheService cache,
  ) async {
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
