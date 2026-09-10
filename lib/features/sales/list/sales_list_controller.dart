import 'dart:convert';
import 'package:get/get.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';

enum SalesFilter { all, today, week, month, custom }

/// One page of sales, plus the server's own count and totals.
class _SalesPage {
  final List<SaleModel> rows;

  /// `pagination.total` — how many rows MATCH, not how many were sent.
  final int? total;

  /// `summary` — totals computed in SQL for the same filter.
  final Map<String, dynamic>? summary;

  const _SalesPage({required this.rows, required this.total, required this.summary});
}

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

  /// Rows per page, and the page currently shown.
  ///
  /// M9: paging used to be client-side over a single fetch of 100 rows (500 for
  /// a custom range). Production holds 2,145 sales, so everything past the
  /// first fetch was simply unreachable, and "a to b of N" reported the number
  /// of rows fetched rather than the number that exist. The server pages now.
  static const pageSize = 25;
  final page = 1.obs;

  /// The server's own count of matching rows, from `pagination.total`.
  ///
  /// Null while offline, where the device holds the whole cached set and pages
  /// it locally instead.
  final totalCount = Rxn<int>();

  /// True when [sales] holds ONE page from the server, false when it holds the
  /// whole cached set and this class slices it.
  final _serverPaged = false.obs;

  /// Server-computed totals for the active filter, from `withSummary: true`.
  ///
  /// M8: the reports and drill-downs used to add up whatever rows happened to
  /// be fetched, which is wrong the moment the real count passes the cap — as
  /// it long since has. Null until the first successful fetch.
  final summary = Rxn<Map<String, dynamic>>();

  int get totalPages {
    final total = totalCount.value;
    if (total != null) return total <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    return sales.isEmpty ? 1 : (sales.length + pageSize - 1) ~/ pageSize;
  }

  /// The rows to show for the current page.
  List<SaleModel> get pageSales {
    if (_serverPaged.value) return sales;
    final start = (page.value - 1) * pageSize;
    if (start >= sales.length) return const [];
    return sales.sublist(start, (start + pageSize).clamp(0, sales.length));
  }

  /// 1-based index of the first row on this page, for "a to b of N".
  int get rangeStart => sales.isEmpty ? 0 : (page.value - 1) * pageSize + 1;

  /// 1-based index of the last row on this page.
  int get rangeEnd => _serverPaged.value
      ? (page.value - 1) * pageSize + sales.length
      : ((page.value - 1) * pageSize + pageSize).clamp(0, sales.length);

  /// The real number of matching sales — the server's when it gave one.
  int get rangeTotal => totalCount.value ?? sales.length;

  void goToPage(int p) {
    final target = p.clamp(1, totalPages);
    if (target == page.value) return;
    page.value = target;
    // Server paging means a new page is a new request. Offline, the whole set
    // is already here and the getter above just slices it.
    if (_serverPaged.value) fetchSales(keepPage: true);
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

  /// Loads the current page.
  ///
  /// [keepPage] is set when the user moved to another page, so the page number
  /// survives; every other caller (a filter change, a pull-to-refresh) resets
  /// to the first page.
  Future<void> fetchSales({bool keepPage = false}) async {
    if (!keepPage) page.value = 1;
    isLoading.value = true;
    error.value = '';

    try {
      if (_connectivity.isOnline.value) {
        final result = await _fetchViaEdgeFunction();
        _serverPaged.value = true;
        sales.assignAll(result.rows);
        totalCount.value = result.total;
        summary.value = result.summary;

        // Cache the first page of the unfiltered list so there is something to
        // show offline. This is a page, not the whole set — the cache is a
        // convenience, never the source of a total.
        if (filter.value == SalesFilter.all &&
            page.value == 1 &&
            result.rows.isNotEmpty) {
          Get.find<LocalCacheService>().saveSales(result.rows);
        }

        // Nothing came back for "All" — fall back to whatever is cached, and
        // page it locally, since a cached set carries no server total.
        if (result.rows.isEmpty && filter.value == SalesFilter.all) {
          final cached = Get.find<LocalCacheService>().getSales();
          if (cached.isNotEmpty) {
            _serverPaged.value = false;
            totalCount.value = null;
            sales.assignAll(cached);
          }
        }
      } else {
        _serverPaged.value = false;
        totalCount.value = null;
        summary.value = null;
        sales.assignAll(Get.find<LocalCacheService>().getSales());
      }
    } catch (e) {
      error.value = 'Failed to load sales.';
      if (filter.value == SalesFilter.all) {
        final cached = Get.find<LocalCacheService>().getSales();
        if (cached.isNotEmpty) {
          _serverPaged.value = false;
          totalCount.value = null;
          sales.assignAll(cached);
        }
      }
    } finally {
      await _loadPendingSales();
      // Clamp without re-fetching: a filter change can leave the page number
      // past the end of the new result set.
      page.value = page.value.clamp(1, totalPages);
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

  Future<_SalesPage> _fetchViaEdgeFunction() async {
    final body = _buildRequestBody();
    final resp = await _supabase.callEdgeFunction(
      'get-sales-advanced',
      body: body,
    );

    if (!resp.success || resp.data == null) {
      error.value = resp.message;
      return const _SalesPage(rows: [], total: null, summary: null);
    }

    List raw = [];
    Map? asMap;
    if (resp.data is List) {
      raw = resp.data as List;
    } else if (resp.data is Map) {
      asMap = resp.data as Map;
      raw = asMap['data'] as List? ?? asMap['sales'] as List? ?? [];
    }

    // The server's own count of matching rows, not the number it just sent.
    int? total;
    if (asMap != null) {
      final pagination = asMap['pagination'];
      if (pagination is Map) total = int.tryParse('${pagination['total']}');
      total ??= int.tryParse('${asMap['total']}');
    }

    // Totals computed in SQL and scoped to the caller, filtered exactly as the
    // rows are. Never derived from the rows themselves.
    Map<String, dynamic>? summary;
    final rawSummary = asMap?['summary'];
    if (rawSummary is Map) summary = Map<String, dynamic>.from(rawSummary);

    return _SalesPage(
      rows: raw
          .map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: total,
      summary: summary,
    );
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
    return {
      // One page at a time, and the server says how many there are. This used
      // to ask for 100 rows (500 for a custom range) once and page on the
      // phone, which put everything past the first fetch out of reach.
      'page': page.value,
      'limit': pageSize,
      'responseFormat': 'format2',
      'includeCreator': true,
      // Totals computed in SQL, scoped and filtered exactly as these rows.
      'withSummary': true,
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
