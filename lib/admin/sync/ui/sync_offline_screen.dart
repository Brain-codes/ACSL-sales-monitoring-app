// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';
import 'package:stove_transaction/admin/sales/controller/offline_sales_controller.dart';
import 'package:stove_transaction/core/services/offline_sync_service.dart';
import 'package:stove_transaction/admin/sales/ui/offline_sales_screen.dart';

class SyncOfflineScreen extends StatelessWidget {
  final OfflineSalesController offlineController =
      Get.put(OfflineSalesController());
  final OfflineSyncService syncService = Get.find<OfflineSyncService>();

  SyncOfflineScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(title: "Sync Offline Data"),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sync Status Card
            Obx(() {
              final syncSummary = offlineController.syncSummary;
              final totalUnsynced = syncSummary['totalUnsynced'] ?? 0;
              final isSyncing = syncSummary['isSyncing'] ?? false;
              final syncStatus = syncSummary['syncStatus'] ?? '';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        (isSyncing == true) ? Icons.sync : Icons.cloud_upload,
                        size: 60,
                        color: (isSyncing == true)
                            ? AppColors.primaryColor
                            : AppColors.secondaryTextColor,
                      ),
                      const SizedBox(height: 10.0),
                      Text(
                        (isSyncing == true)
                            ? 'Syncing Data...'
                            : 'Offline Data Status',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        totalUnsynced > 0
                            ? 'You have $totalUnsynced unsynced record${totalUnsynced == 1 ? '' : 's'}.'
                            : 'All data is synchronized.',
                        textAlign: TextAlign.center,
                        style: TextThemes(context).getTextStyle(
                          fontSize: 12,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      if (syncStatus.isNotEmpty) ...[
                        const SizedBox(height: 8.0),
                        Text(
                          syncStatus,
                          textAlign: TextAlign.center,
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                      if (isSyncing == true) ...[
                        const SizedBox(height: 16.0),
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

            const SizedBox(height: 24.0),

            // Statistics Cards
            Obx(() {
              final stats = offlineController.statistics;
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total Records',
                      stats['total']!,
                      Icons.storage,
                      AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Pending Sync',
                      stats['pending']!,
                      Icons.schedule,
                      AppColors.warningColor,
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 16.0),

            Obx(() {
              final stats = offlineController.statistics;
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Synced',
                      stats['synced']!,
                      Icons.check_circle,
                      AppColors.successColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Failed',
                      stats['failed']!,
                      Icons.error,
                      AppColors.errorColor,
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 32.0),

            // Action Buttons
            Obx(() {
              final syncSummary = offlineController.syncSummary;
              final totalUnsynced = syncSummary['totalUnsynced'] ?? 0;
              final isSyncing = syncSummary['isSyncing'] ?? false;

              return Column(
                children: [
                  if (totalUnsynced > 0) ...[
                    PrimaryButton(
                      text:
                          (isSyncing == true) ? 'Syncing...' : 'Sync All Data',
                      onPressed: () {
                        if (isSyncing != true) {
                          offlineController.syncAllOfflineData();
                        }
                      },
                      isLoading: isSyncing == true,
                    ),
                    const SizedBox(height: 16.0),
                  ],

                  InkWell(
                    onTap: () => Get.to(
                      () => OfflineSalesScreen(),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 15,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1000),
                        border: Border.all(color: AppColors.white),
                        color: AppColors.primaryColor,
                      ),
                      child: Text(
                        'View Offline Records',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 12,
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Retry Failed Syncs Button
                  Obx(() {
                    final stats = offlineController.statistics;
                    final failedCount = stats['failed']!;

                    if (failedCount > 0) {
                      return OutlinedButton(
                        onPressed: (isSyncing == true)
                            ? null
                            : () {
                                offlineController.retryFailedSyncs();
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.errorColor),
                        ),
                        child: Text(
                          'Retry Failed Syncs ($failedCount)',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 16,
                            color: AppColors.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }),
                ],
              );
            }),

            Spacer(),

            // Last Sync Info
            Obx(() {
              final syncSummary = offlineController.syncSummary;
              final lastSync = syncSummary['lastSync'];

              if (lastSync != null) {
                final lastSyncDate = DateTime.tryParse(lastSync);
                if (lastSyncDate != null) {
                  return Text(
                    'Last sync: ${_formatLastSync(lastSyncDate)}',
                    textAlign: TextAlign.center,
                    style: TextThemes(context).getTextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryTextColor,
                    ),
                  );
                }
              }
              return Text(
                'No previous sync',
                textAlign: TextAlign.center,
                style: TextThemes(context).getTextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextColor,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextThemes(context).getTextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextThemes(context).getTextStyle(
                fontSize: 12,
                color: AppColors.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }
}
