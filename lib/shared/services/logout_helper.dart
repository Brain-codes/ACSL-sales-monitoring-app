import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/shared/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class LogoutHelper {
  static final Logger _logger = Logger();

  /// Show logout confirmation with offline data warning
  /// This can be called from anywhere in the app
  static Future<void> showLogoutConfirmation() async {
    try {
      final offlineStorage = Get.find<OfflineStorageService>();
      final sessionManager = Get.find<SessionManager>();

      // Check if there's any offline data
      final unsyncedCount = offlineStorage.getUnsyncedRecordsCount();
      final hasOfflineData = unsyncedCount > 0;

      _logger.d('Logout requested - Unsynced records: $unsyncedCount');

      // Show bottom sheet with warning
      Get.bottomSheet(
        LogoutConfirmationBottomSheet(
          hasOfflineData: hasOfflineData,
          offlineRecordsCount: unsyncedCount,
          onConfirmLogout: () =>
              _performLogout(hasOfflineData, offlineStorage, sessionManager),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } catch (e) {
      _logger.e('Error checking offline data: $e');
      // If there's an error checking offline data, proceed with simple logout
      _performLogout(false, null, null);
    }
  }

  /// Perform the actual logout
  static Future<void> _performLogout(
    bool hasOfflineData,
    OfflineStorageService? offlineStorage,
    SessionManager? sessionManager,
  ) async {
    try {
      if (hasOfflineData && offlineStorage != null) {
        _logger.d('Logging out and clearing offline data');

        // Clear all offline data
        await offlineStorage.clearAllOfflineData();

        // Clear session data
        if (sessionManager != null) {
          sessionManager.logout();
        }

        showSuccessToast(
          title: 'Logout Successful',
          message: 'Offline data has been cleared from this device',
        );
      } else {
        _logger.d('Logging out without offline data');

        // Just clear session data
        if (sessionManager != null) {
          sessionManager.logout();
        }

        showSuccessToast(
          title: 'Logout Successful',
          message: 'You have been logged out successfully',
        );
      }

      // Navigate to login screen and clear navigation stack
      Get.offAllNamed(AppRoutes.LOGIN);
    } catch (e) {
      _logger.e('Error during logout: $e');

      showErrorToast(
        title: 'Logout Error',
        message: 'Failed to logout properly. Please try again.',
      );
    }
  }

  /// Quick logout without confirmation (for emergency/automatic logouts)
  static Future<void> forceLogout({bool clearOfflineData = true}) async {
    try {
      final offlineStorage = Get.find<OfflineStorageService>();
      final sessionManager = Get.find<SessionManager>();

      if (clearOfflineData) {
        await offlineStorage.clearAllOfflineData();
      }

      sessionManager.logout();
      Get.offAllNamed(AppRoutes.LOGIN);
    } catch (e) {
      _logger.e('Error during force logout: $e');
      Get.offAllNamed(AppRoutes.LOGIN);
    }
  }
}
