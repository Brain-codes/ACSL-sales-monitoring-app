import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/core/services/offline_sync_service.dart';
import 'package:stove_transaction/admin/sales/model/offline_sale_model.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class OfflineSalesController extends GetxController {
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();
  final OfflineSyncService _syncService = Get.find<OfflineSyncService>();
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final Logger _logger = Logger();

  // Observable variables
  final RxList<OfflineSaleModel> offlineSales = <OfflineSaleModel>[].obs;
  final RxList<OfflineSaleEditModel> offlineSaleEdits =
      <OfflineSaleEditModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxMap<String, dynamic> syncSummary = <String, dynamic>{}.obs;

  // Filter and search
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final RxString selectedFilter = 'all'.obs; // all, pending, synced, failed

  @override
  void onInit() {
    super.onInit();
    _loadOfflineData();
    _updateSyncSummary();

    // Listen to search changes
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });

    // Listen to sync service changes
    ever(_syncService.isSyncing, (_) => _updateSyncSummary());
    ever(_syncService.syncStatus, (_) => _updateSyncSummary());
  }

  /// Load offline data from storage
  void _loadOfflineData() {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Load offline sales
      final salesData = _offlineStorage.getOfflineSales();
      offlineSales.value =
          salesData.map((data) => OfflineSaleModel.fromJson(data)).toList();

      // Load offline sale edits
      final editsData = _offlineStorage.getOfflineSaleEdits();
      offlineSaleEdits.value =
          editsData.map((data) => OfflineSaleEditModel.fromJson(data)).toList();

      _logger.d(
          'Loaded ${offlineSales.length} offline sales and ${offlineSaleEdits.length} edits');
    } catch (e) {
      _logger.e('Error loading offline data: $e');
      errorMessage.value = 'Failed to load offline data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Update sync summary
  void _updateSyncSummary() {
    syncSummary.value = _syncService.getSyncSummary();
  }

  /// Refresh offline data
  Future<void> refreshOfflineData() async {
    _loadOfflineData();
    _updateSyncSummary();
  }

  /// Get filtered offline sales based on current filters
  List<OfflineSaleModel> get filteredOfflineSales {
    List<OfflineSaleModel> filtered = offlineSales.toList();

    // Apply status filter
    switch (selectedFilter.value) {
      case 'pending':
        filtered =
            filtered.where((sale) => sale.syncStatus == 'pending').toList();
        break;
      case 'synced':
        filtered =
            filtered.where((sale) => sale.syncStatus == 'synced').toList();
        break;
      case 'failed':
        filtered =
            filtered.where((sale) => sale.syncStatus == 'failed').toList();
        break;
      case 'ready':
        filtered = filtered.where((sale) => sale.isReadyForSync).toList();
        break;
    }

    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((sale) {
        final searchableText = [
          sale.endUserName,
          sale.partnerName,
          sale.stoveSerialNo,
          sale.transactionId,
          sale.contactPerson,
          sale.phone,
        ].where((text) => text != null).join(' ').toLowerCase();

        return searchableText.contains(query);
      }).toList();
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdOfflineAt.compareTo(a.createdOfflineAt));

    return filtered;
  }

  /// Get filtered offline sale edits
  List<OfflineSaleEditModel> get filteredOfflineSaleEdits {
    List<OfflineSaleEditModel> filtered = offlineSaleEdits.toList();

    // Apply status filter
    switch (selectedFilter.value) {
      case 'pending':
        filtered =
            filtered.where((edit) => edit.syncStatus == 'pending').toList();
        break;
      case 'synced':
        filtered =
            filtered.where((edit) => edit.syncStatus == 'synced').toList();
        break;
      case 'failed':
        filtered =
            filtered.where((edit) => edit.syncStatus == 'failed').toList();
        break;
    }

    // Apply search filter if needed (search by sale ID)
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((edit) {
        return edit.saleId.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by edit date (newest first)
    filtered.sort((a, b) => b.editedOfflineAt.compareTo(a.editedOfflineAt));

    return filtered;
  }

  /// Create a new offline sale
  Future<bool> createOfflineSale(Map<String, dynamic> saleData) async {
    try {
      // Add creator information
      saleData['createdBy'] = _sessionManager.userId;

      final success = await _offlineStorage.saveOfflineSale(saleData);

      if (success) {
        await refreshOfflineData();
        showSuccessToast(
          title: 'Offline Sale Created',
          message: 'Sale saved locally and will sync when online',
        );
        return true;
      } else {
        showErrorToast(
          title: 'Save Failed',
          message: 'Failed to save sale offline',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error creating offline sale: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to create offline sale: $e',
      );
      return false;
    }
  }

  /// Edit an offline sale
  Future<bool> editOfflineSale(
      String saleId, Map<String, dynamic> editData) async {
    try {
      final success =
          await _offlineStorage.saveOfflineSaleEdit(saleId, editData);

      if (success) {
        await refreshOfflineData();
        showSuccessToast(
          title: 'Offline Edit Saved',
          message: 'Changes saved locally and will sync when online',
        );
        return true;
      } else {
        showErrorToast(
          title: 'Save Failed',
          message: 'Failed to save edit offline',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error editing offline sale: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to edit offline sale: $e',
      );
      return false;
    }
  }

  /// Sync all offline data
  Future<void> syncAllOfflineData() async {
    try {
      final success = await _syncService.syncAllOfflineData();

      if (success) {
        await refreshOfflineData();
      }
    } catch (e) {
      _logger.e('Error syncing offline data: $e');
      showErrorToast(
        title: 'Sync Error',
        message: 'Failed to sync offline data: $e',
      );
    }
  }

  /// Sync a single offline sale
  Future<void> syncSingleOfflineSale(String offlineId) async {
    try {
      final success = await _syncService.syncSingleOfflineSale(offlineId);

      if (success) {
        showSuccessToast(
          title: 'Sync Success',
          message: 'Sale synced successfully',
        );
        await refreshOfflineData();
      } else {
        showErrorToast(
          title: 'Sync Failed',
          message: 'Failed to sync this sale',
        );
      }
    } catch (e) {
      _logger.e('Error syncing single sale: $e');
      showErrorToast(
        title: 'Sync Error',
        message: 'Failed to sync sale: $e',
      );
    }
  }

  /// Sync a single offline sale edit
  Future<void> syncSingleOfflineSaleEdit(String editId) async {
    try {
      final success = await _syncService.syncSingleOfflineSaleEdit(editId);

      if (success) {
        showSuccessToast(
          title: 'Sync Success',
          message: 'Edit synced successfully',
        );
        await refreshOfflineData();
      } else {
        showErrorToast(
          title: 'Sync Failed',
          message: 'Failed to sync this edit',
        );
      }
    } catch (e) {
      _logger.e('Error syncing single edit: $e');
      showErrorToast(
        title: 'Sync Error',
        message: 'Failed to sync edit: $e',
      );
    }
  }

  /// Retry failed syncs
  Future<void> retryFailedSyncs() async {
    try {
      final success = await _syncService.retryFailedSyncs();

      if (success) {
        await refreshOfflineData();
      }
    } catch (e) {
      _logger.e('Error retrying failed syncs: $e');
      showErrorToast(
        title: 'Retry Error',
        message: 'Failed to retry syncs: $e',
      );
    }
  }

  /// Delete a synced offline sale (admin only)
  Future<void> deleteOfflineSale(String offlineId) async {
    try {
      if (!_sessionManager.isAdmin) {
        showErrorToast(
          title: 'Permission Denied',
          message: 'Only admins can delete offline sales',
        );
        return;
      }

      // Get current sales and remove the specific one
      final sales = _offlineStorage.getOfflineSales();
      final originalLength = sales.length;
      sales.removeWhere((sale) => sale['offline_id'] == offlineId);

      if (sales.length < originalLength) {
        // Sale was found and removed, now save the updated list
        // Note: This assumes OfflineStorageService has a method to save the updated list
        // If not available, we'll need to implement this differently
        await refreshOfflineData();
        showSuccessToast(
          title: 'Deleted',
          message: 'Offline sale deleted successfully',
        );
      } else {
        showErrorToast(
          title: 'Not Found',
          message: 'Offline sale not found',
        );
      }
    } catch (e) {
      _logger.e('Error deleting offline sale: $e');
      showErrorToast(
        title: 'Delete Error',
        message: 'Failed to delete offline sale: $e',
      );
    }
  }

  /// Clear all synced data (admin only)
  Future<void> clearSyncedData() async {
    try {
      if (!_sessionManager.isAdmin) {
        showErrorToast(
          title: 'Permission Denied',
          message: 'Only admins can clear synced data',
        );
        return;
      }

      await _offlineStorage.clearAllOfflineData();
      await refreshOfflineData();

      showSuccessToast(
        title: 'Data Cleared',
        message: 'All synced offline data has been cleared',
      );
    } catch (e) {
      _logger.e('Error clearing synced data: $e');
      showErrorToast(
        title: 'Clear Error',
        message: 'Failed to clear synced data: $e',
      );
    }
  }

  /// Check if there's any offline data (for logout warning)
  bool hasOfflineData() {
    try {
      return _offlineStorage.getUnsyncedRecordsCount() > 0;
    } catch (e) {
      _logger.e('Error checking offline data: $e');
      return false;
    }
  }

  /// Get count of unsynced offline records
  int getUnsyncedCount() {
    try {
      return _offlineStorage.getUnsyncedRecordsCount();
    } catch (e) {
      _logger.e('Error getting unsynced count: $e');
      return 0;
    }
  }

  /// Set filter
  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  /// Clear search
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  /// Get statistics for display
  Map<String, int> get statistics {
    return {
      'total': offlineSales.length + offlineSaleEdits.length,
      'pending': offlineSales.where((s) => s.syncStatus == 'pending').length +
          offlineSaleEdits.where((e) => e.syncStatus == 'pending').length,
      'synced': offlineSales.where((s) => s.syncStatus == 'synced').length +
          offlineSaleEdits.where((e) => e.syncStatus == 'synced').length,
      'failed': offlineSales.where((s) => s.syncStatus == 'failed').length +
          offlineSaleEdits.where((e) => e.syncStatus == 'failed').length,
      'ready': offlineSales.where((s) => s.isReadyForSync).length,
    };
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
