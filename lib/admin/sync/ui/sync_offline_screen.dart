// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
class SyncOfflineScreen extends StatelessWidget {
  SyncOfflineScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar( title : "Sync Offline Data",),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload,
              size: 80,
              color: AppColors.primaryColor,
            ),
            const SizedBox(height: 24.0),
            Text(
              'You have 5 unsynced records.', // Placeholder message
              textAlign: TextAlign.center,
              style: TextThemes(context).getTextStyle(
                fontSize: 18,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: () {
                Get.snackbar(
                  'Sync Status',
                  'Syncing data now... (dummy action)',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.primaryColor,
                  colorText: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.primaryColor, // Button background color
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
              ),
              child: Text(
                'Sync Now',
                style: TextThemes(context).getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Button text color
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
