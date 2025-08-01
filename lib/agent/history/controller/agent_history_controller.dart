import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/agent/history/service/sales_history_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class AgentHistoryController extends GetxController {
  final SalesHistoryService _historyService =
      SalesHistoryService(SupabaseService());
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final Logger logger = Logger();

  // Observable variables
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final agentActivities = <SalesHistoryModel>[].obs;

  // Agent stats
  final totalActivities = 0.obs;
  final todayActivities = 0.obs;
  final thisWeekActivities = 0.obs;
  final createdCount = 0.obs;
  final updatedCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAgentHistory();
  }

  /// Fetch all activities performed by the current agent
  void fetchAgentHistory() async {
    if (_sessionManager.userId == null) {
      errorMessage.value = 'User not authenticated';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Get history for current agent only
      final response = await _historyService.getSalesHistory(
        page: 1,
        limit: 100, // Get more records for agent's personal history
      );

      if (response.success && response.data != null) {
        final allActivities = response.data!.data;

        // Filter to show only activities performed by current agent
        final currentUserId = _sessionManager.userId!;
        final myActivities = allActivities
            .where((activity) => activity.performedBy == currentUserId)
            .toList();

        agentActivities.value = myActivities;
        _calculateStats(myActivities);

        logger.i('Agent history loaded: ${myActivities.length} activities');
      } else {
        errorMessage.value = response.message;
        showErrorToast(
          title: 'Error',
          message: response.message,
        );
      }
    } catch (e) {
      logger.e('Error fetching agent history: $e');
      errorMessage.value = 'Failed to load your history';
      showErrorToast(
        title: 'Error',
        message: 'Failed to load your sales history',
      );
    }

    isLoading.value = false;
  }

  /// Calculate statistics for the agent
  void _calculateStats(List<SalesHistoryModel> activities) {
    totalActivities.value = activities.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    // Count today's activities
    todayActivities.value = activities.where((activity) {
      final activityDate = DateTime(
        activity.performedAt.year,
        activity.performedAt.month,
        activity.performedAt.day,
      );
      return activityDate.isAtSameMomentAs(today);
    }).length;

    // Count this week's activities
    thisWeekActivities.value = activities
        .where((activity) => activity.performedAt.isAfter(weekStart))
        .length;

    // Count by action type
    createdCount.value = activities
        .where((activity) => activity.actionType.toLowerCase() == 'created')
        .length;

    updatedCount.value = activities
        .where((activity) => activity.actionType.toLowerCase() == 'updated')
        .length;
  }

  /// Refresh agent history
  void refreshHistory() {
    fetchAgentHistory();
  }

  /// Get human-readable time format
  String getTimeAgo(DateTime date) {
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
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Get icon for activity type
  IconData getActivityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'assigned':
        return Icons.assignment_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  /// Get color for activity type
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
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
