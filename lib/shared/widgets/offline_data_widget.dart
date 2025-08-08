// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/controller/settings_controller.dart';

class OfflineDataWidget extends StatelessWidget {
  final SettingsController controller;

  const OfflineDataWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.inactiveTextFormFieldColor,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      color: AppColors.primaryColor,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Data',
                            style: TextThemes(context).getTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Download data for offline use',
                            style: TextThemes(context).getTextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Offline Mode Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offline Mode',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                controller.isOfflineModeEnabled
                                    ? 'Using offline data'
                                    : 'Using live data',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: controller.isOfflineModeEnabled,
                          onChanged: controller.hasValidOfflineData
                              ? (value) => controller.toggleOfflineMode()
                              : null,
                          activeColor: AppColors.primaryColor,
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Data Status
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.inactiveTextFormFieldColor,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Data Status',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: controller.hasValidOfflineData
                                      ? AppColors.successColor.withOpacity(0.1)
                                      : AppColors.warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  controller.hasValidOfflineData
                                      ? 'Available'
                                      : 'Not Available',
                                  style: TextThemes(context).getTextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: controller.hasValidOfflineData
                                        ? AppColors.successColor
                                        : AppColors.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Last Download: ${controller.lastDownloadTimeFormatted}',
                            style: TextThemes(context).getTextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Download Progress (if downloading)
                    if (controller.isDownloadingOfflineData) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Downloading...',
                                    style: TextThemes(context).getTextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${controller.offlineDataDownloadProgress}%',
                                  style: TextThemes(context).getTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            LinearProgressIndicator(
                              value:
                                  controller.offlineDataDownloadProgress / 100,
                              backgroundColor:
                                  AppColors.inactiveTextFormFieldColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              controller.offlineDataDownloadStatus,
                              style: TextThemes(context).getTextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: controller.isDownloadingOfflineData
                                ? null
                                : () => controller.downloadOfflineData(),
                            icon: Icon(
                              Icons.download_outlined,
                              color: AppColors.white,
                              size: 18,
                            ),
                            label: Text(
                              controller.hasValidOfflineData
                                  ? 'Refresh Data'
                                  : 'Download Data',
                              style: TextThemes(context).getTextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  controller.isDownloadingOfflineData
                                      ? AppColors.primaryColor.withOpacity(0.2)
                                      : AppColors.primaryColor,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (controller.hasValidOfflineData) ...[
                          SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: controller.isDownloadingOfflineData
                                ? null
                                : () => _showClearDataConfirmation(context),
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppColors.white,
                              size: 18,
                            ),
                            label: Text(
                              'Clear',
                              style: TextThemes(context).getTextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  controller.isDownloadingOfflineData
                                      ? AppColors.errorColor.withOpacity(0.2)
                                      : AppColors.errorColor,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Offline Mode Help Text
                    if (!controller.hasValidOfflineData) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warningColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.warningColor,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Download data first to enable offline mode. This includes Google Sheets data, sales records, and other necessary information.',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 11,
                                  color: AppColors.warningColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  void _showClearDataConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Clear Offline Data',
          style: TextThemes(context).getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all offline data? This will disable offline mode and you\'ll need to download data again.',
          style: TextThemes(context).getTextStyle(
            fontSize: 14,
            color: AppColors.secondaryTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.clearOfflineData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: AppColors.white,
            ),
            child: Text(
              'Clear Data',
              style: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
