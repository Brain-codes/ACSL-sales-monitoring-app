// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class SalesController extends GetxController {
  final SessionManager _sessionManager = Get.find<SessionManager>();

  var isAdmin = false.obs;
  var isAgent = false.obs;

  // Offline statistics
  var _statistics = {
    'total': 0,
    'pending': 0,
    'synced': 0,
    'failed': 0,
  }.obs;

  // Sync summary
  var _syncSummary = {
    'isSyncing': false,
    'syncStatus': '',
    'totalUnsynced': 0,
    'syncProgress': 0,
    'totalItemsToSync': 0,
  }.obs;

  // Getters for reactive access
  Map<String, dynamic> get statistics => _statistics;
  Map<String, dynamic> get syncSummary => _syncSummary;

  @override
  void onInit() {
    super.onInit();
    isAdmin.value = _sessionManager.isAdmin;
    isAgent.value = _sessionManager.isAgent;
    _initializeOfflineData();
  }

  // Mock data for sales
  final RxList<SaleModel> adminSales = <SaleModel>[].obs;
  final RxList<SaleModel> agentSales = <SaleModel>[].obs;

  // For Admin: Filter and sort sales
  void filterSales(String status) {
    // Implement filtering logic here
  }

  void sortSales(String sortBy) {
    // Implement sorting logic here
  }

  // For Agent: Mark sale as completed
  // void completeSale(String saleId) {
  //   // Implement logic to mark sale as completed
  //   final saleIndex = agentSales.indexWhere((sale) => sale.id == saleId);
  //   if (saleIndex != -1) {
  //     agentSales[saleIndex].status = 'Completed';
  //     agentSales.refresh();
  //     showSuccessToast(
  //       message: 'Sale with ID $saleId completed successfully.',
  //     );
  //   }
  // }

  void assignSale(String saleId, String agentName) {
    // final saleIndex = adminSales.indexWhere((sale) => sale.id == saleId);
    // if (saleIndex != -1) {
    //   final updatedSale = adminSales[saleIndex].copyWith(
    //     agentName: agentName,
    //     status: 'Assigned',
    //   );
    //   adminSales[saleIndex] = updatedSale;
    //   // In a real app, you would sync this change to Hive and/or API
    //   print(
    //       'Sale $saleId assigned to $agentName and status updated to Assigned');
    // } else {
    //   // Get.snackbar('Error', 'Sale with ID $saleId not found for assignment.');
    // }
  }

  // For Admin: Delete sale
  void deleteSale(String saleId) {
    // Implement logic to delete sale
    adminSales.removeWhere((sale) => sale.id == saleId);
    adminSales.refresh();
  }

  // For Admin: Create new sale
  void createNewSale() {
    // Implement logic to create a new sale
  }

  SaleModel? findSaleById(String saleId) {
    // Check adminSales first
    try {
      return adminSales.firstWhere((sale) => sale.id == saleId);
    } catch (e) {
      // If not found in adminSales, check agentSales
      try {
        return agentSales.firstWhere((sale) => sale.id == saleId);
      } catch (e) {
        return null; // Sale not found in either list
      }
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Assigned':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Incomplete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Offline functionality methods
  void _initializeOfflineData() {
    // Initialize with mock data
    _updateStatistics();
    _updateSyncSummary();
  }

  void _updateStatistics() {
    // Mock calculation - replace with real logic
    final totalSales = adminSales.length + agentSales.length;
    final pendingSales =
        adminSales.where((sale) => sale.status == 'Pending').length +
            agentSales.where((sale) => sale.status == 'Pending').length;
    final syncedSales =
        adminSales.where((sale) => sale.status == 'Completed').length +
            agentSales.where((sale) => sale.status == 'Completed').length;
    final failedSales =
        adminSales.where((sale) => sale.status == 'Incomplete').length +
            agentSales.where((sale) => sale.status == 'Incomplete').length;

    _statistics.value = {
      'total': totalSales,
      'pending': pendingSales,
      'synced': syncedSales,
      'failed': failedSales,
    };
  }

  void _updateSyncSummary() {
    final totalUnsynced = _statistics['pending'] ?? 0;

    _syncSummary.value = {
      'isSyncing': false,
      'syncStatus':
          totalUnsynced > 0 ? 'Sync pending' : 'All data synchronized',
      'totalUnsynced': totalUnsynced,
      'syncProgress': 0,
      'totalItemsToSync': totalUnsynced,
    };
  }

  Future<void> syncAllOfflineData() async {
    try {
      // Start syncing
      _syncSummary.value = {
        ..._syncSummary,
        'isSyncing': true,
        'syncStatus': 'Syncing offline data...',
      };

      // Simulate sync process
      for (int i = 0; i <= 100; i += 20) {
        await Future.delayed(Duration(milliseconds: 200));
        _syncSummary.value = {
          ..._syncSummary,
          'syncProgress': i,
        };
      }

      // Complete sync
      _syncSummary.value = {
        'isSyncing': false,
        'syncStatus': 'Sync completed successfully',
        'totalUnsynced': 0,
        'syncProgress': 100,
        'totalItemsToSync': 0,
      };

      // Update statistics
      _updateStatistics();

      showSuccessToast(
        title: 'Sync Complete',
        message: 'All offline data has been synchronized successfully.',
      );
    } catch (e) {
      _syncSummary.value = {
        ..._syncSummary,
        'isSyncing': false,
        'syncStatus': 'Sync failed: ${e.toString()}',
      };

      showErrorToast(
        title: 'Sync Failed',
        message: 'Failed to synchronize offline data. Please try again.',
      );
    }
  }

  Future<void> refreshOfflineData() async {
    try {
      // Simulate data refresh
      await Future.delayed(Duration(milliseconds: 500));

      _updateStatistics();
      _updateSyncSummary();

      showSuccessToast(
        title: 'Refreshed',
        message: 'Offline data has been refreshed.',
      );
    } catch (e) {
      showErrorToast(
        title: 'Refresh Failed',
        message: 'Failed to refresh offline data.',
      );
    }
  }
}
