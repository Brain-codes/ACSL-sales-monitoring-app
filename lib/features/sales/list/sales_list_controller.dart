import 'dart:convert';
import 'package:get/get.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';

enum SalesFilter { all, today, week, month, custom }

class SalesListController extends GetxController {
  final _supabase = Get.find<SupabaseService>();
  final _connectivity = Get.find<ConnectivityService>();

  final isLoading = false.obs;
  final RxList<SaleModel> sales = <SaleModel>[].obs;
  final RxList<SaleModel> pendingSales = <SaleModel>[].obs;
  final filter = SalesFilter.all.obs;
  final error = ''.obs;
  final isTableView = false.obs;
  final customStart = Rxn<DateTime>();
  final customEnd = Rxn<DateTime>();

  /// Client-side paging only. The full result set is already on the device
  /// (fetched in one go so the list works offline); this just slices it so the
  /// user gets pages instead of an endless scroll.
  static const pageSize = 25;
  final page = 1.obs;

  int get totalPages => sales.isEmpty ? 1 : (sales.length + pageSize - 1) ~/ pageSize;

  List<SaleModel> get pageSales {
    final start = (page.value - 1) * pageSize;
    if (start >= sales.length) return const [];
    return sales.sublist(start, (start + pageSize).clamp(0, sales.length));
  }

  void goToPage(int p) {
    page.value = p.clamp(1, totalPages);
  }

  void toggleView() => isTableView.value = !isTableView.value;

  @override
  void onInit() {
    super.onInit();
    fetchSales();
  }

  String get filterLabel {
    switch (filter.value) {
      case SalesFilter.all: return 'All';
      case SalesFilter.today: return 'Today';
      case SalesFilter.week: return 'This Week';
      case SalesFilter.month: return 'This Month';
      case SalesFilter.custom:
        final s = customStart.value;
        final e = customEnd.value;
        if (s == null) return 'Custom';
        String fmtD(DateTime d) => '${d.day}/${d.month}/${d.year}';
        return e != null ? '${fmtD(s)} – ${fmtD(e)}' : 'From ${fmtD(s)}';
    }
  }

  Future<void> fetchSales() async {
    isLoading.value = true;
    error.value = '';

    try {
      if (_connectivity.isOnline.value) {
        final result = await _fetchViaEdgeFunction();
        // Always reflect exactly what the API returned for the active filter
        sales.assignAll(result);
        // Only persist the unfiltered full list to cache
        if (filter.value == SalesFilter.all && result.isNotEmpty) {
          Get.find<LocalCacheService>().saveSales(result);
        }
        // For "All" filter only: fall back to cache if API gave nothing
        if (result.isEmpty && filter.value == SalesFilter.all) {
          sales.assignAll(Get.find<LocalCacheService>().getSales());
        }
      } else {
        sales.assignAll(Get.find<LocalCacheService>().getSales());
      }
    } catch (e) {
      error.value = 'Failed to load sales.';
      if (filter.value == SalesFilter.all) {
        final cached = Get.find<LocalCacheService>().getSales();
        if (cached.isNotEmpty) sales.assignAll(cached);
      }
    } finally {
      await _loadPendingSales();
      goToPage(page.value);
      isLoading.value = false;
    }
  }

  Future<void> _loadPendingSales() async {
    try {
      final queue = Get.find<OfflineQueueService>();
      final pending = await queue.getPending();
      final pendingModels = pending.map((row) {
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        // Which images were captured (stored separately from the payload) —
        // used to show "Attached / Captured" in the offline detail view.
        Map<String, dynamic> images = const {};
        final imagesRaw = row['images'];
        if (imagesRaw is String && imagesRaw.isNotEmpty) {
          try {
            images = jsonDecode(imagesRaw) as Map<String, dynamic>;
          } catch (_) {}
        }
        final addr = payload['addressData'] is Map
            ? Map<String, dynamic>.from(payload['addressData'] as Map)
            : const <String, dynamic>{};
        final model = SaleModel(
          id: 'offline_${row['id']}',
          transactionId: payload['transactionId']?.toString() ?? '',
          endUserName: payload['endUserName']?.toString(),
          aka: payload['aka']?.toString(),
          contactPerson: payload['contactPerson']?.toString(),
          contactPhone: payload['contactPhone']?.toString(),
          phone: payload['phone']?.toString(),
          otherPhone: payload['otherPhone']?.toString(),
          partnerName: payload['partnerName']?.toString(),
          retailerBranch: payload['retailerBranch']?.toString(),
          stoveSerialNo: payload['stoveSerialNo']?.toString(),
          stoveId: payload['stoveId']?.toString(),
          state: payload['stateBackup']?.toString(),
          lga: payload['lgaBackup']?.toString(),
          address: addr['fullAddress']?.toString(),
          latitude: (addr['latitude'] as num?)?.toDouble(),
          longitude: (addr['longitude'] as num?)?.toDouble(),
          salesDate: DateTime.tryParse(payload['salesDate']?.toString() ?? ''),
          amount: (payload['amount'] as num?)?.toDouble(),
          // The pending card shows what the customer actually paid, not the
          // full sale price — mirror amount_received (fallback initial payment).
          amountReceived: (payload['amountReceived'] as num?)?.toDouble()
              ?? (payload['initialPaymentAmount'] as num?)?.toDouble(),
          initialPaymentAmount: (payload['initialPaymentAmount'] as num?)?.toDouble(),
          initialPaymentMethod: payload['initialPaymentMethod']?.toString(),
          isInstallment: payload['isInstallment'] == true,
          paymentModelId: payload['paymentModelId']?.toString(),
          potQuantity: (payload['potQuantity'] as num?)?.toInt(),
          heatRetentionDevice: payload['heatRetentionDevice'] == true,
          previousStoveType: (payload['previousStoveType']?.toString().isEmpty ?? true)
              ? null : payload['previousStoveType']?.toString(),
          previousStoveOther: payload['previousStoveOther']?.toString(),
          mealsPerDay: (payload['mealsPerDay']?.toString().isEmpty ?? true)
              ? null : payload['mealsPerDay']?.toString(),
          cookingFuelSource: (payload['cookingFuelSource']?.toString().isEmpty ?? true)
              ? null : payload['cookingFuelSource']?.toString(),
          cookingLocation: (payload['cookingLocation']?.toString().isEmpty ?? true)
              ? null : payload['cookingLocation']?.toString(),
          termsAccepted: payload['termsAccepted'] is Map
              ? Map<String, dynamic>.from(payload['termsAccepted'] as Map)
                  .map((k, v) => MapEntry(k, v == true))
              : null,
          // Presence flags only (real ids assigned server-side on sync).
          stoveImageId: images.containsKey('stove_image') ? 'offline' : null,
          agreementImageId: images.containsKey('agreement_image') ? 'offline' : null,
          signatureId: images.containsKey('signature') ? 'offline' : null,
          status: 'pending_sync',
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
        model.queueId = row['id'] as int?;
        model.syncError = (row['error'] as String?)?.trim().isEmpty ?? true
            ? null
            : (row['error'] as String).trim();
        return model;
      }).toList();
      pendingSales.assignAll(pendingModels);
    } catch (_) {}
  }

  Future<List<SaleModel>> _fetchViaEdgeFunction() async {
    final body = _buildRequestBody();
    final resp = await _supabase.callEdgeFunction(
      'get-sales-advanced',
      body: body,
    );

    if (!resp.success || resp.data == null) {
      error.value = resp.message;
      return [];
    }

    List raw = [];
    if (resp.data is List) {
      raw = resp.data as List;
    } else if (resp.data is Map) {
      raw = (resp.data as Map)['data'] as List? ?? (resp.data as Map)['sales'] as List? ?? [];
    }
    return raw
        .map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  (String, String?)? _dateRange() {
    switch (filter.value) {
      case SalesFilter.today:
        final today = DateTime.now().toIso8601String().substring(0, 10);
        return (today, today);
      case SalesFilter.week:
        final now = DateTime.now();
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (monday.toIso8601String().substring(0, 10), null);
      case SalesFilter.month:
        final now = DateTime.now();
        return ('${now.year}-${now.month.toString().padLeft(2, '0')}-01', null);
      case SalesFilter.custom:
        final s = customStart.value;
        if (s == null) return null;
        return (s.toIso8601String().substring(0, 10), customEnd.value?.toIso8601String().substring(0, 10));
      default:
        return null;
    }
  }

  void setCustomDateRange(DateTime start, DateTime? end) {
    customStart.value = start;
    customEnd.value = end;
    filter.value = SalesFilter.custom;
    page.value = 1;
    fetchSales();
  }

  Map<String, dynamic> _buildRequestBody() {
    final range = _dateRange();
    final isCustom = filter.value == SalesFilter.custom;
    return {
      'page': 1,
      'limit': isCustom ? 500 : 100,
      'responseFormat': 'format2',
      'includeCreator': true,
      if (range != null) 'dateFrom': range.$1,
      if (range != null && range.$2 != null) 'dateTo': range.$2!,
    };
  }

  void setFilter(SalesFilter f) {
    filter.value = f;
    page.value = 1;
    fetchSales();
  }
}
