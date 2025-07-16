// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class SalesController extends GetxController {
  final SessionManager _sessionManager = Get.find<SessionManager>();

  var isAdmin = false.obs;
  var isAgent = false.obs;

  // Mock data for sales agents

  @override
  void onInit() {
    super.onInit();
    isAdmin.value = _sessionManager.isAdmin;
    isAgent.value = _sessionManager.isAgent;
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
}
