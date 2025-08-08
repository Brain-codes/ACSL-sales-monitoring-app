// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/admin/sales/ui/offline_sales_screen.dart';
import 'package:stove_transaction/agent/history/controller/agent_history_controller.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/dashboard_action_tile.dart';
import 'package:stove_transaction/shared/widgets/summary_box.dart';
import 'package:stove_transaction/core/services/session_manager.dart';

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SessionManager _sessionManager = Get.find<SessionManager>();
    final SalesController offlineController = Get.put(SalesController());
    final AgentHistoryController historyController =
        Get.put(AgentHistoryController());

    return Scaffold(
      // appBar: BaseAppBar(title: "Dashboard"),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${_sessionManager.userName ?? 'Agent'}',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to your dashboard',
                style: TextThemes(context).getTextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              // Agent Activity Statistics
              Obx(() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Activity Summary',
                      style: TextThemes(context).getTextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SummaryBox(
                            width: double.infinity,
                            icon: Icons.history,
                            backgroundColor: AppColors.primaryColor,
                            title: 'Total Activities',
                            value: historyController.totalActivities.value
                                .toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryBox(
                            width: double.infinity,
                            icon: Icons.today,
                            backgroundColor: Color.fromARGB(255, 76, 175, 80),
                            title: 'Today',
                            value: historyController.todayActivities.value
                                .toString(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SummaryBox(
                            width: double.infinity,
                            icon: Icons.add_circle,
                            backgroundColor: Color.fromARGB(255, 33, 150, 243),
                            title: 'Created',
                            value:
                                historyController.createdCount.value.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryBox(
                            width: double.infinity,
                            icon: Icons.edit,
                            backgroundColor: Color.fromARGB(255, 255, 152, 0),
                            title: 'Updated',
                            value:
                                historyController.updatedCount.value.toString(),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
              const SizedBox(height: 32),
              // Quick Actions
              Text(
                'Quick Actions',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              DashboardActionTile(
                icon: Icons.storage,
                title: 'View Offline Records',
                description: 'View and manage all your offline sales records.',
                onTap: () => Get.to(() => OfflineSalesScreen()),
              ),
              Obx(() {
                final stats = offlineController.statistics;
                final pendingCount = stats['pending'] ?? 0;
                if (pendingCount > 0) {
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      DashboardActionTile(
                        icon: Icons.sync,
                        title: 'Sync Offline Data',
                        description:
                            'Sync $pendingCount pending records to server.',
                        onTap: () async {
                          await offlineController.syncAllOfflineData();
                          await offlineController.refreshOfflineData();
                        },
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: 12),
              DashboardActionTile(
                icon: Icons.refresh,
                title: 'Refresh Data',
                description: 'Refresh activity history and offline records.',
                onTap: () {
                  historyController.refreshHistory();
                  offlineController.refreshOfflineData();
                },
              ),
              const SizedBox(height: 32),
              // Sync Status Card
              Obx(() {
                final syncSummary = offlineController.syncSummary;
                final isSyncing = syncSummary['isSyncing'] ?? false;
                final syncStatus = syncSummary['syncStatus'] ?? '';
                final totalUnsynced = syncSummary['totalUnsynced'] ?? 0;
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSyncing ? Icons.sync : Icons.cloud_done,
                              color: isSyncing
                                  ? AppColors.primaryColor
                                  : totalUnsynced > 0
                                      ? AppColors.errorColor
                                      : AppColors.successColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSyncing
                                    ? 'Syncing...'
                                    : totalUnsynced > 0
                                        ? 'Sync Required'
                                        : 'All Synced',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                            ),
                            if (totalUnsynced > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.errorColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalUnsynced',
                                  style: TextThemes(context).getTextStyle(
                                    fontSize: 12,
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (syncStatus.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            syncStatus,
                            style: TextThemes(context).getTextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ],
                        if (totalUnsynced > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'You have $totalUnsynced records waiting to be synchronized.',
                            style: TextThemes(context).getTextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ],
                        if (isSyncing) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: syncSummary['totalItemsToSync'] > 0
                                ? syncSummary['syncProgress'] /
                                    syncSummary['totalItemsToSync']
                                : null,
                            backgroundColor: AppColors.lightGrey,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primaryColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
