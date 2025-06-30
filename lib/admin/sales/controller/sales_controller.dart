// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';

class SalesController extends GetxController {
  final SessionManager _sessionManager = Get.find<SessionManager>();

  var isAdmin = false.obs;
  var isAgent = false.obs;

  // Mock data for sales agents
  final RxList<SalesAgent> salesAgents = <SalesAgent>[
    SalesAgent(id: 'AG001', name: 'Agent Alpha', location: 'New York'),
    SalesAgent(id: 'AG002', name: 'Agent Beta', location: 'Los Angeles'),
    SalesAgent(id: 'AG003', name: 'Agent Gamma', location: 'Chicago'),
    SalesAgent(id: 'AG004', name: 'Agent Delta', location: 'Houston'),
  ].obs;

  @override
  void onInit() {
    super.onInit();
    isAdmin.value = _sessionManager.isAdmin;
    isAgent.value = _sessionManager.isAgent;
  }

  // Mock data for sales
  final RxList<Sale> adminSales = <Sale>[
    Sale(
        id: 'S001',
        product: 'Stove Model A',
        amount: 120.00,
        date: DateTime.now().subtract(Duration(days: 5)),
        status: 'Completed',
        agentName: 'Agent Alpha',
        userId: 'U001'),
    Sale(
        id: 'S002',
        product: 'Stove Model B',
        amount: 150.00,
        date: DateTime.now().subtract(Duration(days: 3)),
        status: 'Assigned',
        agentName: 'Agent Beta',
        userId: 'U002'),
    Sale(
        id: 'S003',
        product: 'Stove Model C',
        amount: 100.00,
        date: DateTime.now().subtract(Duration(days: 1)),
        status: 'Incomplete',
        agentName: null,
        userId: 'U003'),
    Sale(
        id: 'S004',
        product: 'Stove Model A',
        amount: 120.00,
        date: DateTime.now().subtract(Duration(days: 7)),
        status: 'Completed',
        agentName: 'Agent Alpha',
        userId: 'U004'),
    Sale(
        id: 'S005',
        product: 'Stove Model D',
        amount: 200.00,
        date: DateTime.now().subtract(Duration(days: 2)),
        status: 'Assigned',
        agentName: 'Agent Gamma',
        userId: 'U005'),
  ].obs;

  final RxList<Sale> agentSales = <Sale>[
    Sale(
        id: 'A001',
        product: 'Stove Model X',
        amount: 110.00,
        date: DateTime.now().subtract(Duration(days: 4)),
        status: 'Assigned',
        agentName: 'Current Agent',
        userId: 'U006'),
    Sale(
        id: 'A002',
        product: 'Stove Model Y',
        amount: 130.00,
        date: DateTime.now().subtract(Duration(days: 2)),
        status: 'Pending',
        agentName: 'Current Agent',
        userId: 'U007'),
    Sale(
        id: 'A003',
        product: 'Stove Model Z',
        amount: 90.00,
        date: DateTime.now().subtract(Duration(days: 1)),
        status: 'Completed',
        agentName: 'Current Agent',
        userId: 'U008'),
  ].obs;

  // For Admin: Filter and sort sales
  void filterSales(String status) {
    // Implement filtering logic here
  }

  void sortSales(String sortBy) {
    // Implement sorting logic here
  }

  // For Agent: Mark sale as completed
  void completeSale(String saleId) {
    // Implement logic to mark sale as completed
    final saleIndex = agentSales.indexWhere((sale) => sale.id == saleId);
    if (saleIndex != -1) {
      agentSales[saleIndex].status = 'Completed';
      agentSales.refresh();
      Get.snackbar('Success', 'Sale with ID $saleId completed successfully.');
    }
  }

  void assignSale(String saleId, String agentName) {
    final saleIndex = adminSales.indexWhere((sale) => sale.id == saleId);
    if (saleIndex != -1) {
      final updatedSale = adminSales[saleIndex].copyWith(
        agentName: agentName,
        status: 'Assigned',
      );
      adminSales[saleIndex] = updatedSale;
      // In a real app, you would sync this change to Hive and/or API
      print(
          'Sale $saleId assigned to $agentName and status updated to Assigned');
    } else {
      // Get.snackbar('Error', 'Sale with ID $saleId not found for assignment.');
    }
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

  Sale? findSaleById(String saleId) {
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
