// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/core/services/offline_data_service.dart';
import 'package:stove_transaction/shared/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class SettingsController extends GetxController {
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();
  final OfflineDataService _offlineDataService = Get.put(OfflineDataService());
  final Logger _logger = Logger();

  final isLoading = false.obs;

  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController currentPasswordController = TextEditingController();
  //EDIT PROFILE
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController fullNameController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  TextEditingController genderController = TextEditingController();

  String formatDateString(String dateString) {
    List<String> dateComponents;

    if (dateString.contains('/')) {
      dateComponents = dateString.split('/');
      String formattedDate =
          "${dateComponents[0]}-${dateComponents[1]}-${dateComponents[2]}";
      return formattedDate;
    } else if (dateString.contains('-')) {
      dateComponents = dateString.split('-');
      String formattedDate =
          "${dateComponents[0]}-${dateComponents[1]}-${dateComponents[2]}";
      return formattedDate;
    } else {
      return dateString;
    }
  }

  /// Show logout confirmation with offline data warning
  Future<void> showLogoutConfirmation(BuildContext context) async {
    try {
      // Check if there's any offline data
      final unsyncedCount = _offlineStorage.getUnsyncedRecordsCount();
      final hasOfflineData = unsyncedCount > 0;

      _logger.d('Logout requested - Unsynced records: $unsyncedCount');

      // Show bottom sheet with warning
      Get.bottomSheet(
        LogoutConfirmationBottomSheet(
          hasOfflineData: hasOfflineData,
          offlineRecordsCount: unsyncedCount,
          onConfirmLogout: () => _performLogout(hasOfflineData),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } catch (e) {
      _logger.e('Error checking offline data: $e');
      // If there's an error checking offline data, proceed with simple logout
      _performLogout(false);
    }
  }

  /// Perform the actual logout
  Future<void> _performLogout(bool hasOfflineData) async {
    try {
      isLoading.value = true;

      if (hasOfflineData) {
        _logger.d('Logging out and clearing offline data');

        // Clear all offline data
        await _offlineStorage.clearAllOfflineData();

        // Clear session data
        _sessionManager.logout();

        showSuccessToast(
          title: 'Logout Successful',
          message: 'Offline data has been cleared from this device',
        );
      } else {
        _logger.d('Logging out without offline data');

        // Just clear session data
        _sessionManager.logout();

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
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout(BuildContext context) async {
    await showLogoutConfirmation(context);
  }

  /// Download data for offline use
  Future<void> downloadOfflineData() async {
    try {
      final success = await _offlineDataService.downloadOfflineData();
      if (success) {
        _logger.d('Offline data download completed successfully');
      }
    } catch (e) {
      _logger.e('Error downloading offline data: $e');
      showErrorToast(
        title: 'Download Failed',
        message: 'Failed to download offline data: $e',
      );
    }
  }

  /// Toggle offline mode
  Future<void> toggleOfflineMode() async {
    await _offlineDataService.toggleOfflineMode();
  }

  /// Clear offline data
  Future<void> clearOfflineData() async {
    await _offlineDataService.clearOfflineData();
  }

  /// Get offline mode status
  bool get isOfflineModeEnabled => _offlineDataService.isOfflineMode.value;

  /// Get offline data download status
  bool get isDownloadingOfflineData => _offlineDataService.isDownloading.value;

  /// Get offline data download progress
  int get offlineDataDownloadProgress =>
      _offlineDataService.downloadProgress.value;

  /// Get offline data download status text
  String get offlineDataDownloadStatus =>
      _offlineDataService.downloadStatus.value;

  /// Check if valid offline data exists
  bool get hasValidOfflineData => _offlineDataService.hasValidOfflineData();

  /// Get last download time formatted
  String get lastDownloadTimeFormatted =>
      _offlineDataService.getLastDownloadTimeFormatted();
}
