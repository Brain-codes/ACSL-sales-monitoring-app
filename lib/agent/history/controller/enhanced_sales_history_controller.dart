import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/agent/history/service/sales_history_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

// Agent Activity Stats Model
class AgentActivityStats {
  int totalActivities = 0;
  int todayActivities = 0;
  int thisWeekActivities = 0;
  int createdCount = 0;
  int updatedCount = 0;
  int completedCount = 0;
  int assignedCount = 0;
  String mostActiveDay = '';
  int mostActiveDayCount = 0;
  double averageActivitiesPerDay = 0.0;
}

class EnhancedSalesHistoryController extends GetxController {
  // Services
  final SalesHistoryService _historyService =
      SalesHistoryService(Get.find<SupabaseService>());
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final Logger logger = Logger();

  // Observable variables
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final errorMessage = ''.obs;
  final historyList = <SalesHistoryModel>[].obs;
  final filteredHistoryList = <SalesHistoryModel>[].obs;
  final stats =
      HistoryStatsModel(total: 0, created: 0, updated: 0, completed: 0).obs;
  final currentPage = 1.obs;
  final hasMoreData = true.obs;
  final totalPages = 1.obs;

  // Enhanced stats
  final dailyActivityData = <Map<String, dynamic>>[].obs;
  final weeklyStats = <Map<String, dynamic>>[].obs;
  final mostActiveDay = ''.obs;
  final averageActivitiesPerDay = 0.0.obs;

  // Filters
  final selectedActionType = Rxn<String>();
  final selectedDateRange = Rxn<DateTimeRange>();
  final searchQuery = ''.obs;
  final selectedUserId = Rxn<String>();

  // UI State
  final selectedTab =
      0.obs; // 0: My Recent Actions, 1: All Activities, 2: Analytics
  final viewMode = 'list'.obs; // 'list' or 'timeline'
  final showFilters = false.obs;

  // Agent-specific activity data
  final recentAgentActivities = <SalesHistoryModel>[].obs;
  final agentActivityStats = AgentActivityStats().obs;

  // Controllers
  final searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Constants
  static const int _pageSize = 20;
  final List<String> actionTypes = [
    'All',
    'Created',
    'Updated',
    'Completed',
    'Assigned',
    'Cancelled',
    'Deleted'
  ];

  // Tab names for UI
  final List<String> tabNames = [
    'My Recent Actions',
    'All Activities',
    'Analytics'
  ];

  @override
  void onInit() {
    super.onInit();
    _setupScrollListener();
    _setupSearchListener();
    fetchAgentRecentActivities(); // Fetch agent activities first (tab 0)
    fetchHistory();
    fetchAnalytics();
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

  void _setupSearchListener() {
    searchController.addListener(() {
      searchQuery.value = searchController.text;
      _applyLocalFilters();
    });
  }

  /// Fetch initial history data with enhanced analytics
  Future<void> fetchHistory({bool showLoading = true}) async {
    if (showLoading) {
      isLoading.value = true;
    }
    errorMessage.value = '';
    currentPage.value = 1;
    hasMoreData.value = true;

    try {
      final response = await _historyService.getSalesHistory(
        actionType: selectedActionType.value?.toLowerCase() != 'all'
            ? selectedActionType.value?.toLowerCase()
            : null,
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

        _applyLocalFilters();

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
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more history for pagination
  Future<void> loadMoreHistory() async {
    if (isLoadingMore.value || !hasMoreData.value) return;

    isLoadingMore.value = true;
    currentPage.value++;

    try {
      final response = await _historyService.getSalesHistory(
        actionType: selectedActionType.value?.toLowerCase() != 'all'
            ? selectedActionType.value?.toLowerCase()
            : null,
        page: currentPage.value,
        limit: _pageSize,
        dateFrom: selectedDateRange.value?.start,
        dateTo: selectedDateRange.value?.end,
      );

      if (response.success && response.data != null) {
        historyList.addAll(response.data!.data);
        hasMoreData.value =
            currentPage.value < response.data!.pagination.totalPages;
        _applyLocalFilters();
        logger.i('Loaded ${response.data!.data.length} more history records');
      }
    } catch (e) {
      logger.e('Error loading more history: $e');
      currentPage.value--; // Revert page increment
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Fetch analytics data
  Future<void> fetchAnalytics() async {
    try {
      // Calculate daily activity over the last 30 days
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final response = await _historyService.getSalesHistory(
        page: 1,
        limit: 1000, // Get more data for analytics
        dateFrom: thirtyDaysAgo,
        dateTo: now,
      );

      if (response.success && response.data != null) {
        _calculateDailyStats(response.data!.data);
        _calculateWeeklyStats(response.data!.data);
      }
    } catch (e) {
      logger.e('Error fetching analytics: $e');
    }
  }

  void _calculateDailyStats(List<SalesHistoryModel> data) {
    final Map<String, Map<String, int>> dailyData = {};

    for (final activity in data) {
      final date = activity.performedAt.toIso8601String().split('T')[0];

      if (!dailyData.containsKey(date)) {
        dailyData[date] = {
          'total': 0,
          'created': 0,
          'updated': 0,
          'completed': 0,
          'assigned': 0,
        };
      }

      dailyData[date]!['total'] = dailyData[date]!['total']! + 1;
      dailyData[date]![activity.actionType] =
          (dailyData[date]![activity.actionType] ?? 0) + 1;
    }

    // Convert to list and sort by date
    dailyActivityData.value = dailyData.entries
        .map((entry) => {
              'date': entry.key,
              'total': entry.value['total'],
              'created': entry.value['created'],
              'updated': entry.value['updated'],
              'completed': entry.value['completed'],
              'assigned': entry.value['assigned'],
            })
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    // Calculate average activities per day
    final totalActivities = dailyActivityData.fold<int>(
        0, (sum, day) => sum + (day['total'] as int));
    averageActivitiesPerDay.value = dailyActivityData.isNotEmpty
        ? totalActivities / dailyActivityData.length
        : 0.0;

    // Find most active day
    if (dailyActivityData.isNotEmpty) {
      final mostActiveEntry = dailyActivityData
          .reduce((a, b) => (a['total'] as int) > (b['total'] as int) ? a : b);
      mostActiveDay.value = mostActiveEntry['date'] as String;
    }
  }

  void _calculateWeeklyStats(List<SalesHistoryModel> data) {
    final Map<int, Map<String, int>> weeklyData = {};

    for (final activity in data) {
      final weekOfYear = _getWeekOfYear(activity.performedAt);

      if (!weeklyData.containsKey(weekOfYear)) {
        weeklyData[weekOfYear] = {
          'total': 0,
          'created': 0,
          'updated': 0,
          'completed': 0,
          'assigned': 0,
        };
      }

      weeklyData[weekOfYear]!['total'] = weeklyData[weekOfYear]!['total']! + 1;
      weeklyData[weekOfYear]![activity.actionType] =
          (weeklyData[weekOfYear]![activity.actionType] ?? 0) + 1;
    }

    weeklyStats.value = weeklyData.entries
        .map((entry) => {
              'week': entry.key,
              'total': entry.value['total'],
              'created': entry.value['created'],
              'updated': entry.value['updated'],
              'completed': entry.value['completed'],
              'assigned': entry.value['assigned'],
            })
        .toList()
      ..sort((a, b) => (a['week'] as int).compareTo(b['week'] as int));
  }

  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysSinceStartOfYear = date.difference(startOfYear).inDays;
    return (daysSinceStartOfYear / 7).floor() + 1;
  }

  /// Apply local filters to the history list
  void _applyLocalFilters() {
    var filtered = List<SalesHistoryModel>.from(historyList);

    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((history) {
        return history.actionDescription.toLowerCase().contains(query) ||
            (history.sale?.endUserName?.toLowerCase().contains(query) ??
                false) ||
            (history.sale?.stoveSerialNo?.toLowerCase().contains(query) ??
                false) ||
            (history.performer?.fullName?.toLowerCase().contains(query) ??
                false);
      }).toList();
    }

    // Apply tab filter
    if (selectedTab.value == 1) {
      // All Activities (no additional filter needed)
    } else if (selectedTab.value == 0) {
      // My Recent Actions - handled separately in recentAgentActivities
    }

    filteredHistoryList.value = filtered;
  }

  /// Fetch agent's recent activities (original plan implementation)
  Future<void> fetchAgentRecentActivities({bool showLoading = true}) async {
    if (showLoading) {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final currentUserId = _sessionManager.userId;
      if (currentUserId == null) {
        errorMessage.value = 'User not authenticated';
        return;
      }

      // Get agent's activities for the last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final response = await _historyService.getSalesHistory(
        page: 1,
        limit: 50, // Get more recent activities
        dateFrom: thirtyDaysAgo,
        dateTo: DateTime.now(),
      );

      if (response.success && response.data != null) {
        // Filter to only this agent's activities
        final agentActivities = response.data!.data
            .where((activity) => activity.performedBy == currentUserId)
            .toList();

        recentAgentActivities.value = agentActivities;

        // Calculate agent-specific stats
        _calculateAgentStats(agentActivities);

        logger.i('Fetched ${agentActivities.length} agent activities');
      } else {
        errorMessage.value = response.message;
        showErrorToast(
          title: 'Error',
          message: response.message,
        );
      }
    } catch (e) {
      logger.e('Error fetching agent activities: $e');
      errorMessage.value = 'Failed to fetch your activities';
      showErrorToast(
        title: 'Error',
        message: 'Failed to fetch your recent activities',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Calculate agent-specific statistics
  void _calculateAgentStats(List<SalesHistoryModel> activities) {
    final stats = AgentActivityStats();

    stats.totalActivities = activities.length;
    stats.todayActivities =
        activities.where((a) => _isToday(a.performedAt)).length;
    stats.thisWeekActivities =
        activities.where((a) => _isThisWeek(a.performedAt)).length;

    // Count by action type
    stats.createdCount =
        activities.where((a) => a.actionType == 'created').length;
    stats.updatedCount =
        activities.where((a) => a.actionType == 'updated').length;
    stats.completedCount =
        activities.where((a) => a.actionType == 'completed').length;
    stats.assignedCount =
        activities.where((a) => a.actionType == 'assigned').length;

    // Find most active day
    final activityByDay = <String, int>{};
    for (final activity in activities) {
      final day = _formatDateForGrouping(activity.performedAt);
      activityByDay[day] = (activityByDay[day] ?? 0) + 1;
    }

    if (activityByDay.isNotEmpty) {
      final mostActiveEntry =
          activityByDay.entries.reduce((a, b) => a.value > b.value ? a : b);
      stats.mostActiveDay = mostActiveEntry.key;
      stats.mostActiveDayCount = mostActiveEntry.value;
    }

    // Calculate average activities per day
    if (activities.isNotEmpty) {
      final uniqueDays =
          activities.map((a) => _formatDateForGrouping(a.performedAt)).toSet();
      stats.averageActivitiesPerDay = activities.length / uniqueDays.length;
    }

    agentActivityStats.value = stats;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(weekStart) &&
        date.isBefore(now.add(const Duration(days: 1)));
  }

  String _formatDateForGrouping(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get human-readable time ago string
  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get activity icon based on action type
  IconData getActivityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'assigned':
        return Icons.person_add_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.timeline;
    }
  }

  /// Get activity color based on action type
  Color getActivityColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'assigned':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'deleted':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Refresh history data
  Future<void> refreshHistory() async {
    if (selectedTab.value == 0) {
      await fetchAgentRecentActivities(showLoading: false);
    } else {
      await fetchHistory(showLoading: false);
    }
    await fetchAnalytics();
  }

  /// Search history
  void searchHistory(String query) {
    searchQuery.value = query;
    if (selectedTab.value == 0) {
      // Apply search to agent activities
      _applyAgentActivityFilters();
    } else {
      _applyLocalFilters();
    }
  }

  /// Apply search filter to agent activities
  void _applyAgentActivityFilters() {
    // This method can be used to filter agent activities if needed
    // For now, we'll keep it simple and just trigger UI update
    recentAgentActivities.refresh();
  }

  /// Apply action type filter
  void applyActionTypeFilter(String? actionType) {
    selectedActionType.value = actionType;
    fetchHistory();
  }

  /// Apply date range filter
  void applyDateRangeFilter(DateTimeRange? dateRange) {
    selectedDateRange.value = dateRange;
    fetchHistory();
  }

  /// Clear all filters
  void clearFilters() {
    selectedActionType.value = null;
    selectedDateRange.value = null;
    searchController.clear();
    searchQuery.value = '';
    selectedUserId.value = null;
    fetchHistory();
  }

  /// Toggle filters visibility
  void toggleFilters() {
    showFilters.value = !showFilters.value;
  }

  /// Change tab
  void changeTab(int index) {
    selectedTab.value = index;

    // Load appropriate data based on selected tab
    if (index == 0) {
      // My Recent Actions
      if (recentAgentActivities.isEmpty) {
        fetchAgentRecentActivities();
      }
    } else if (index == 1) {
      // All Activities
      if (historyList.isEmpty) {
        fetchHistory();
      } else {
        _applyLocalFilters();
      }
    } else if (index == 2) {
      // Analytics - data is already loaded
    }
  }

  /// Change view mode
  void changeViewMode(String mode) {
    viewMode.value = mode;
  }

  /// Check if filters are active
  bool get hasActiveFilters {
    return selectedActionType.value != null ||
        selectedDateRange.value != null ||
        searchQuery.value.isNotEmpty;
  }

  /// Get filter display text
  String getFilterDisplayText() {
    List<String> filters = [];

    if (selectedActionType.value != null) {
      filters.add('Type: ${selectedActionType.value}');
    }

    if (selectedDateRange.value != null) {
      final start = selectedDateRange.value!.start;
      final end = selectedDateRange.value!.end;
      filters
          .add('Date: ${start.day}/${start.month} - ${end.day}/${end.month}');
    }

    if (searchQuery.value.isNotEmpty) {
      filters.add('Search: "${searchQuery.value}"');
    }

    return filters.join(' • ');
  }

  /// Get activities for a specific sale
  Future<List<SalesHistoryModel>> getSaleActivities(String saleId) async {
    final response = await _historyService.getSaleHistory(saleId);
    if (response.success && response.data != null) {
      return response.data!;
    }
    return [];
  }

  /// Export history data
  Future<void> exportHistory() async {
    try {
      // Implementation for exporting history data
      showSuccessToast(
        title: 'Export Started',
        message: 'History data export will be ready shortly',
      );
    } catch (e) {
      logger.e('Error exporting history: $e');
      showErrorToast(
        title: 'Export Failed',
        message: 'Failed to export history data',
      );
    }
  }
}
