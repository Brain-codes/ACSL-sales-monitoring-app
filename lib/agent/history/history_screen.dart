// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/offline_sales_controller.dart';
import 'package:stove_transaction/admin/sales/ui/offline_sales_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/dashboard_action_tile.dart';
import 'package:stove_transaction/shared/widgets/summary_box.dart';

class HistoryScreen extends StatelessWidget {
  final OfflineSalesController offlineController =
      Get.put(OfflineSalesController());
  final SessionManager _sessionManager = Get.find<SessionManager>();

  HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(title: "Agent History"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
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
              'Here\'s your sales activity and offline records',
              style: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),

            // Offline Statistics Summary
            Obx(() {
              final stats = offlineController.statistics;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Records Summary',
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
                          icon: Icons.storage,
                          backgroundColor: AppColors.primaryColor,
                          title: 'Total Records',
                          value: stats['total'].toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryBox(
                          width: double.infinity,
                          icon: Icons.schedule,
                          backgroundColor: Color.fromARGB(255, 255, 152, 0),
                          title: 'Pending Sync',
                          value: stats['pending'].toString(),
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
                          icon: Icons.check_circle,
                          backgroundColor: Color.fromARGB(255, 76, 175, 80),
                          title: 'Synced',
                          value: stats['synced'].toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SummaryBox(
                          width: double.infinity,
                          icon: Icons.error,
                          backgroundColor: Color.fromARGB(255, 244, 67, 54),
                          title: 'Failed',
                          value: stats['failed'].toString(),
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
              description: 'Refresh offline records and sync status.',
              onTap: () => offlineController.refreshOfflineData(),
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
    );
  }
}
