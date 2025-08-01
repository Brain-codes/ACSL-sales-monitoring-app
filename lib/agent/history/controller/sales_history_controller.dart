import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/agent/history/service/sales_history_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class SalesHistoryController extends GetxController {
  // Services
  final SalesHistoryService _historyService =
      SalesHistoryService(Get.find<SupabaseService>());
  final Logger logger = Logger();

  // Observable variables
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final errorMessage = ''.obs;
  final historyList = <SalesHistoryModel>[].obs;
  final stats =
      HistoryStatsModel(total: 0, created: 0, updated: 0, completed: 0).obs;
  final currentPage = 1.obs;
  final hasMoreData = true.obs;
  final totalPages = 1.obs;

  // Filters
  final selectedActionType = Rxn<String>();
  final selectedDateRange = Rxn<DateTimeRange>();
  final searchQuery = ''.obs;

  // Controllers
  final searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Constants
  static const int _pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    _setupScrollListener();
    fetchHistory();
    fetchActivityStats();
  }

  @override
  void onClose() {
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoadingMore.value && hasMoreData.value) {
          loadMoreHistory();
        }
      }
    });
  }

  /// Fetch initial history data
  Future<void> fetchHistory({bool showLoading = true}) async {
    if (showLoading) {
      isLoading.value = true;
    }
    errorMessage.value = '';
    currentPage.value = 1;
    hasMoreData.value = true;

    try {
      final response = await _historyService.getSalesHistory(
        actionType: selectedActionType.value,
        page: currentPage.value,
        limit: _pageSize,
        dateFrom: selectedDateRange.value?.start,
        dateTo: selectedDateRange.value?.end,
      );

      if (response.success && response.data != null) {
        historyList.value = response.data!.data;
        stats.value = response.data!.stats;
        totalPages.value = response.data!.pagination.totalPages;
        hasMoreData.value = currentPage.value < totalPages.value;

        logger.i('Fetched ${historyList.length} history records');
      } else {
        errorMessage.value = response.message;
        showErrorToast(
          title: 'Error',
          message: response.message,
        );
      }
    } catch (e) {
      logger.e('Error fetching history: $e');
      errorMessage.value = 'Failed to fetch history';
      showErrorToast(
        title: 'Error',
        message: 'Failed to fetch history',
      );
    }

    if (showLoading) {
      isLoading.value = false;
    }
  }

  /// Load more history data for pagination
  Future<void> loadMoreHistory() async {
    if (isLoadingMore.value || !hasMoreData.value) return;

    isLoadingMore.value = true;

    try {
      final nextPage = currentPage.value + 1;

      final response = await _historyService.getSalesHistory(
        actionType: selectedActionType.value,
        page: nextPage,
        limit: _pageSize,
        dateFrom: selectedDateRange.value?.start,
        dateTo: selectedDateRange.value?.end,
      );

      if (response.success && response.data != null) {
        historyList.addAll(response.data!.data);
        currentPage.value = nextPage;
        hasMoreData.value = nextPage < response.data!.pagination.totalPages;

        logger.i('Loaded ${response.data!.data.length} more history records');
      } else {
        showErrorToast(
          title: 'Error',
          message: 'Failed to load more history',
        );
      }
    } catch (e) {
      logger.e('Error loading more history: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to load more history',
      );
    }

    isLoadingMore.value = false;
  }

  /// Fetch activity statistics
  Future<void> fetchActivityStats() async {
    try {
      final response = await _historyService.getActivityStats(
        dateFrom: selectedDateRange.value?.start,
        dateTo: selectedDateRange.value?.end,
      );

      if (response.success && response.data != null) {
        stats.value = response.data!;
      }
    } catch (e) {
      logger.e('Error fetching activity stats: $e');
    }
  }

  /// Filter by action type
  void filterByActionType(String? actionType) {
    selectedActionType.value = actionType;
    fetchHistory();
  }

  /// Filter by date range
  void filterByDateRange(DateTimeRange? dateRange) {
    selectedDateRange.value = dateRange;
    fetchHistory();
    fetchActivityStats();
  }

  /// Clear all filters
  void clearFilters() {
    selectedActionType.value = null;
    selectedDateRange.value = null;
    searchController.clear();
    searchQuery.value = '';
    fetchHistory();
    fetchActivityStats();
  }

  /// Search history
  void searchHistory(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      fetchHistory();
    } else {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    isLoading.value = true;

    try {
      final response = await _historyService.searchHistory(
        query: query,
        actionType: selectedActionType.value,
        page: 1,
        limit: 100, // Larger limit for search
      );

      if (response.success && response.data != null) {
        historyList.value = response.data!;
        hasMoreData.value = false; // No pagination for search results
      } else {
        errorMessage.value = response.message;
        showErrorToast(
          title: 'Error',
          message: response.message,
        );
      }
    } catch (e) {
      logger.e('Error searching history: $e');
      errorMessage.value = 'Failed to search history';
      showErrorToast(
        title: 'Error',
        message: 'Failed to search history',
      );
    }

    isLoading.value = false;
  }

  /// Refresh history data
  Future<void> refreshHistory() async {
    await fetchHistory(showLoading: false);
    await fetchActivityStats();
  }

  /// Get formatted date for display
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Get history for a specific sale
  Future<List<SalesHistoryModel>> getSaleHistory(String saleId) async {
    try {
      final response = await _historyService.getSaleHistory(saleId);

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        showErrorToast(
          title: 'Error',
          message: 'Failed to fetch sale history',
        );
        return [];
      }
    } catch (e) {
      logger.e('Error getting sale history: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to fetch sale history',
      );
      return [];
    }
  }

  /// Get action type display name
  String getActionTypeDisplayName(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return 'Created';
      case 'updated':
        return 'Updated';
      case 'completed':
        return 'Completed';
      case 'assigned':
        return 'Assigned';
      case 'deleted':
        return 'Deleted';
      default:
        return actionType.toUpperCase();
    }
  }

  /// Get action type color
  Color getActionTypeColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'assigned':
        return Colors.orange;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get filter display text
  String getFilterDisplayText() {
    final filters = <String>[];

    if (selectedActionType.value != null) {
      filters.add(getActionTypeDisplayName(selectedActionType.value!));
    }

    if (selectedDateRange.value != null) {
      final range = selectedDateRange.value!;
      filters.add(
          '${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}');
    }

    if (searchQuery.value.isNotEmpty) {
      filters.add('Search: "${searchQuery.value}"');
    }

    return filters.isEmpty ? 'All Activities' : filters.join(' • ');
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return selectedActionType.value != null ||
        selectedDateRange.value != null ||
        searchQuery.value.isNotEmpty;
  }
}
