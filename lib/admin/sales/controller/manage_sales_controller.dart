import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/model/filter_model.dart';
import 'package:stove_transaction/admin/sales/services/sale_api_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class ManageSalesController extends GetxController {
  final SaleApiService _apiService = SaleApiService(SupabaseService());
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final TextEditingController searchText = TextEditingController();
  var isAdmin = false.obs;
  var isAgent = false.obs;

  var sales = <SaleModel>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasMoreData = true.obs;
  var errorMessage = ''.obs;

  var endUserNameFilter = ''.obs;
  var selectedState = ''.obs;
  var selectedLGA = ''.obs;
  Rx<DateRange?> dateRangeFilter = Rx<DateRange?>(null);

  int page = 1;
  final int limit = 20;
  int totalItems = 0;

  @override
  void onInit() {
    super.onInit();
    isAdmin.value = _sessionManager.isAdmin;
    isAgent.value = _sessionManager.isAgent;
    fetchSales();
    debounce(endUserNameFilter, (_) => applyFilters(),
        time: const Duration(milliseconds: 500));
  }

  Future<void> fetchSales({bool refresh = false}) async {
    if (refresh) {
      page = 1;
      hasMoreData.value = true;
      sales.clear();
    }

    if (!hasMoreData.value) return;

    if (refresh) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    errorMessage.value = '';

    try {
      final response = await _apiService.fetchSales(
        page: page,
        limit: limit,
        endUserName: endUserNameFilter.value,
        from: dateRangeFilter.value?.start.toIso8601String(),
        to: dateRangeFilter.value?.end.toIso8601String(),
        state: selectedState.value.isNotEmpty ? selectedState.value : null,
        lga: selectedLGA.value.isNotEmpty ? selectedLGA.value : null,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        if (refresh) {
          sales.assignAll(data.sales);
        } else {
          sales.addAll(data.sales);
        }

        totalItems = data.pagination.total;

        if (data.sales.length < limit) {
          hasMoreData.value = false;
        } else {
          page++;
        }
      } else {
        errorMessage.value = response.message ?? 'Failed to load sales';
      }
    } catch (e) {
      errorMessage.value = 'Something went wrong';
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void loadMore() {
    if (!isLoadingMore.value && hasMoreData.value) {
      fetchSales();
    }
  }

  void clearFilter(String filterType) {
    switch (filterType) {
      case 'date':
        dateRangeFilter.value = null;
        break;
      case 'state':
        selectedState.value = '';
        break;
      case 'lga':
        selectedLGA.value = '';
        break;
    }
    fetchSales(refresh: true);
  }

  void applyFilters({
    DateRange? dateRange,
    String? state,
    String? lga,
  }) {
    dateRangeFilter.value = dateRange;
    selectedState.value = state ?? '';
    selectedLGA.value = lga ?? '';
    fetchSales(refresh: true);
  }
}
