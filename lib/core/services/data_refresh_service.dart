import 'dart:async';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
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
      if (session.isAcslAgent) {
        await _refreshAcslAgentData(session);
      } else {
        await Future.wait([
          _refreshStoves(),
          _refreshPaymentModels(),
        ]);
      }
      await Future.wait([
        _refreshSales(),
        _refreshGoogleKeys(),
      ]);
      lastRefreshedAt.value = DateTime.now();
    } catch (e) {
      _logger.e('DataRefreshService.refreshAll error: $e');
    } finally {
      isRefreshing.value = false;
    }
  }

  // ── ACSL agent: fetch partners, then stoves + models for every partner org ──

  Future<void> _refreshAcslAgentData(SessionManager session) async {
    final agentId = session.userId;
    if (agentId == null || agentId.isEmpty) return;

    final supabase = Get.find<SupabaseService>();
    final cache = Get.find<LocalCacheService>();

    // 1. Fetch assigned partners
    final partnerResp = await supabase.callEdgeFunction(
      'super-admin-agents/$agentId/organizations',
      body: {},
      method: 'GET',
    );
    if (!partnerResp.success || partnerResp.data == null) {
      _logger.w('ACSL partner refresh failed');
      return;
    }

    final raw = partnerResp.data is List
        ? partnerResp.data as List
        : ((partnerResp.data as Map?))?['data'] as List? ?? [];
    final partners = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    cache.saveAssignedPartners(partners);
    _logger.d('Cached ${partners.length} assigned partners');

    // 2. For each partner org, fetch stoves + payment models in parallel
    await Future.wait(
      partners.map((p) {
        final orgId = p['id']?.toString() ?? '';
        if (orgId.isEmpty) return Future.value();
        return Future.wait([
          _refreshStovesForOrg(orgId, supabase, cache),
          _refreshPaymentModelsForOrg(orgId, supabase, cache),
        ]);
      }),
    );
  }

  Future<void> _refreshStovesForOrg(
    String orgId,
    SupabaseService supabase,
    LocalCacheService cache,
  ) async {
    try {
      final resp = await supabase.callEdgeFunction(
        'get-stove-ids',
        body: {'status': 'available', 'organization_id': orgId},
      );
      if (resp.success && resp.data != null) {
        final list = resp.data is List
            ? resp.data as List
            : ((resp.data as Map?))?['data'] as List? ?? [];
        final stoves = list
            .map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty)
            .toList();
        cache.saveStovesForOrg(orgId, stoves);
        _logger.d('Cached ${stoves.length} stoves for org $orgId');
      }
    } catch (e) {
      _logger.w('Stove refresh failed for org $orgId: $e');
    }
  }

  Future<void> _refreshPaymentModelsForOrg(
    String orgId,
    SupabaseService supabase,
    LocalCacheService cache,
  ) async {
    try {
      final resp = await supabase.callEdgeFunction(
        'organization-payment-models/$orgId',
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
        cache.savePaymentModelsForOrg(orgId, models);
        _logger.d('Cached ${models.length} payment models for org $orgId');
      }
    } catch (e) {
      _logger.w('Payment models refresh failed for org $orgId: $e');
    }
  }

  // ── Regular (non-ACSL) agents ─────────────────────────────────────────────

  Future<void> _refreshStoves() async {
    try {
      final supabase = Get.find<SupabaseService>();
      final session = Get.find<SessionManager>();
      final orgId = session.organizationId;
      final resp = await supabase.callEdgeFunction(
        'get-stove-ids',
        body: {'status': 'available', if (orgId != null) 'organization_id': orgId},
      );
      if (resp.success && resp.data != null) {
        final list = resp.data is List ? resp.data as List : ((resp.data as Map?))?['data'] as List? ?? [];
        final stoves = list
            .map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty)
            .toList();
        Get.find<LocalCacheService>().saveStoves(stoves);
      }
    } catch (e) {
      _logger.w('Stove refresh failed: $e');
    }
  }

  Future<void> _refreshPaymentModels() async {
    try {
      final supabase = Get.find<SupabaseService>();
      final orgId = Get.find<SessionManager>().organizationId;
      if (orgId == null) return;
      final resp = await supabase.callEdgeFunction(
        'organization-payment-models/$orgId',
        body: {},
        method: 'GET',
      );
      if (resp.success && resp.data != null) {
        final raw = resp.data is List ? resp.data as List : ((resp.data as Map?))?['data'] as List? ?? [];
        final list = raw.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return map.containsKey('payment_model') && map['payment_model'] is Map
              ? Map<String, dynamic>.from(map['payment_model'] as Map)
              : map;
        }).where((m) => m['id'] != null).toList();
        final models = list.map((e) => PaymentModel.fromJson(e)).toList();
        Get.find<LocalCacheService>().savePaymentModels(models);
      }
    } catch (e) {
      _logger.w('Payment models refresh failed: $e');
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
