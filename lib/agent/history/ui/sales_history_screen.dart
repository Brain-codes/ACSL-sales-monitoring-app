import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/controller/sales_history_controller.dart';
import 'package:stove_transaction/agent/history/ui/activity_filter_bottom_sheet.dart';
import 'package:stove_transaction/agent/history/ui/activity_list_item.dart';
import 'package:stove_transaction/agent/history/ui/activity_stats_card.dart';
import 'package:stove_transaction/agent/history/ui/history_detail_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/admin/sales/ui/shimmer_sale_card.dart';

class SalesHistoryScreen extends StatelessWidget {
  SalesHistoryScreen({Key? key}) : super(key: key);

  final SalesHistoryController controller = Get.put(SalesHistoryController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: BaseAppBar(
        title: 'Activity History',
        otherWidgets: Row(
          children: [
            // Search
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.primaryColor),
              onPressed: _showSearchBottomSheet,
            ),
            // Filter
            IconButton(
              icon:
                  const Icon(Icons.filter_list, color: AppColors.primaryColor),
              onPressed: () => _showFilterBottomSheet(context),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshHistory,
        color: AppColors.primaryColor,
        child: Obx(() {
          if (controller.isLoading.value && controller.historyList.isEmpty) {
            return _buildLoadingState();
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.historyList.isEmpty) {
            return _buildErrorState();
          }

          if (controller.historyList.isEmpty) {
            return _buildEmptyState();
          }

          return _buildHistoryList();
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const ShimmerSaleCard(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load history',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.errorMessage.value,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: controller.fetchHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No activity history found',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your sales activities will appear here',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (controller.hasActiveFilters) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: controller.clearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      controller: controller.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _getItemCount(),
      itemBuilder: (context, index) {
        // Stats card at the top
        if (index == 0) {
          return Obx(() => ActivityStatsCard(stats: controller.stats.value));
        }

        // Filter info
        if (index == 1) {
          return _buildFilterInfo();
        }

        // History items
        final historyIndex = index - 2;
        if (historyIndex < controller.historyList.length) {
          final history = controller.historyList[historyIndex];
          return ActivityListItem(
            history: history,
            onTap: () => _showHistoryDetails(history),
          );
        }

        // Loading more indicator
        if (controller.isLoadingMore.value) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFilterInfo() {
    return Obx(() {
      if (!controller.hasActiveFilters) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              color: AppColors.primaryColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.getFilterDisplayText(),
                style: TextThemes(Get.context!).getTextStyle(
                  fontSize: 12,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            TextButton(
              onPressed: controller.clearFilters,
              child: Text(
                'Clear',
                style: TextThemes(Get.context!).getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  int _getItemCount() {
    int count = 2; // Stats card + filter info
    count += controller.historyList.length;
    if (controller.isLoadingMore.value) count++;
    return count;
  }

  void _showFilterBottomSheet(BuildContext context) {
    Get.bottomSheet(
      ActivityFilterBottomSheet(controller: controller),
      isScrollControlled: true,
    );
  }

  void _showSearchBottomSheet() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.searchController,
                    decoration: InputDecoration(
                      hintText: 'Search activities...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length > 2 || value.isEmpty) {
                        controller.searchHistory(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showHistoryDetails(history) {
    Get.to(() => HistoryDetailScreen(history: history));
  }
}
