import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/controller/enhanced_sales_history_controller.dart';
import 'package:stove_transaction/agent/history/ui/enhanced_activity_list_item.dart';
import 'package:stove_transaction/agent/history/ui/enhanced_activity_stats_card.dart';
import 'package:stove_transaction/agent/history/ui/enhanced_history_detail_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/admin/sales/ui/shimmer_sale_card.dart';

class EnhancedSalesHistoryScreen extends StatelessWidget {
  EnhancedSalesHistoryScreen({Key? key}) : super(key: key);

  final EnhancedSalesHistoryController controller =
      Get.put(EnhancedSalesHistoryController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: BaseAppBar(
        title: 'Sales Activity',
        otherWidgets: Row(
          children: [
            // View Mode Toggle
            Obx(() => IconButton(
                  icon: Icon(
                    controller.viewMode.value == 'list'
                        ? Icons.timeline
                        : Icons.list,
                    color: AppColors.primaryColor,
                  ),
                  onPressed: () => controller.changeViewMode(
                      controller.viewMode.value == 'list'
                          ? 'timeline'
                          : 'list'),
                )),

            // Search
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.primaryColor),
              onPressed: _showSearchBottomSheet,
            ),

            // Filter
            Obx(() => IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: controller.hasActiveFilters
                        ? AppColors.primaryColor
                        : AppColors.secondaryTextColor,
                  ),
                  onPressed: () => _showFilterBottomSheet(context),
                )),

            // More Options
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.primaryColor),
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 8),
                      Text('Export'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'analytics',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, size: 20),
                      SizedBox(width: 8),
                      Text('Analytics'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          _buildTabBar(),

          // Filters (if visible)
          Obx(() {
            if (controller.showFilters.value) {
              return _buildQuickFilters();
            }
            return const SizedBox.shrink();
          }),

          // Content
          Expanded(
            child: Obx(() => _buildContent()),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Obx(() => Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  'All Activities',
                  0,
                  controller.selectedTab.value == 0,
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  'My Activities',
                  1,
                  controller.selectedTab.value == 1,
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  'Analytics',
                  2,
                  controller.selectedTab.value == 2,
                ),
              ),
            ],
          )),
    );
  }

  Widget _buildTabButton(String title, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => controller.changeTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextThemes(Get.context!).getTextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'Quick Filters',
                style: TextThemes(Get.context!).getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: controller.toggleFilters,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: controller.actionTypes.map((type) {
              final isSelected = controller.selectedActionType.value == type;
              return GestureDetector(
                onTap: () => controller
                    .applyActionTypeFilter(type == 'All' ? null : type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    type,
                    style: TextThemes(Get.context!).getTextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : AppColors.secondaryTextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (controller.selectedTab.value == 2) {
      return _buildAnalyticsView();
    }

    if (controller.isLoading.value && controller.filteredHistoryList.isEmpty) {
      return _buildLoadingState();
    }

    if (controller.errorMessage.value.isNotEmpty &&
        controller.filteredHistoryList.isEmpty) {
      return _buildErrorState();
    }

    if (controller.filteredHistoryList.isEmpty) {
      return _buildEmptyState();
    }

    return _buildHistoryList();
  }

  Widget _buildAnalyticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Enhanced Stats Card
          Obx(() => EnhancedActivityStatsCard(
                stats: controller.stats.value,
                showDetailedBreakdown: true,
              )),

          const SizedBox(height: 16),

          // Daily Activity Chart placeholder
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Trends',
                  style: TextThemes(Get.context!).getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Chart visualization\nwould go here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Analytics Summary
          Obx(() => _buildAnalyticsSummary()),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Insights',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInsightItem(
                  'Avg/Day',
                  controller.averageActivitiesPerDay.value.toStringAsFixed(1),
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildInsightItem(
                  'Most Active',
                  controller.mostActiveDay.value.isNotEmpty
                      ? controller.mostActiveDay.value.split('-').last
                      : 'N/A',
                  Icons.star,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 12,
              color: AppColors.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: ShimmerSaleCard(),
      ),
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
            'Failed to load activities',
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
            'No activities found',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Your sales activities will appear here',
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
    return RefreshIndicator(
      onRefresh: controller.refreshHistory,
      color: AppColors.primaryColor,
      child: ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _getItemCount(),
        itemBuilder: (context, index) {
          // Stats card at the top (only for All Activities tab)
          if (index == 0 && controller.selectedTab.value == 0) {
            return Obx(() => EnhancedActivityStatsCard(
                  stats: controller.stats.value,
                  showDetailedBreakdown: false, // Simplified version for list
                ));
          }

          // Filter info
          if (index == 1 && controller.selectedTab.value == 0) {
            return _buildFilterInfo();
          }

          // History items
          final historyIndex =
              controller.selectedTab.value == 0 ? index - 2 : index;

          if (historyIndex < controller.filteredHistoryList.length) {
            final history = controller.filteredHistoryList[historyIndex];
            return EnhancedActivityListItem(
              history: history,
              onTap: () => _showHistoryDetails(history),
              showSaleInfo: true,
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
      ),
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
    int count = controller.filteredHistoryList.length;

    // Add stats card and filter info for All Activities tab
    if (controller.selectedTab.value == 0) {
      count += 2;
    }

    // Add loading indicator if loading more
    if (controller.isLoadingMore.value) {
      count++;
    }

    return count;
  }

  void _showFilterBottomSheet(BuildContext context) {
    // TODO: Create enhanced filter bottom sheet
    Get.snackbar(
      'Filters',
      'Advanced filters coming soon!',
      backgroundColor: AppColors.primaryColor,
      colorText: Colors.white,
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
                      suffixIcon:
                          Obx(() => controller.searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      controller.searchController.clear(),
                                )
                              : const SizedBox.shrink()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (value) => Get.back(),
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
    Get.to(() => EnhancedHistoryDetailScreen(history: history));
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        controller.refreshHistory();
        break;
      case 'export':
        controller.exportHistory();
        break;
      case 'analytics':
        controller.changeTab(2);
        break;
    }
  }
}
