// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/ui/admin_sales_screen.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/main_layout/controller/layout_controller.dart';
import 'package:stove_transaction/main_layout/ui/admin_bottom_nav.dart';
import 'package:stove_transaction/main_layout/ui/agent_bottom_nav.dart';
import 'package:stove_transaction/admin/dashboard/ui/dashboard_screen.dart';
import 'package:stove_transaction/admin/sales/sales_screen.dart';
import 'package:stove_transaction/admin/monitoring/monitoring_screen.dart';
import 'package:stove_transaction/agent/sales_form/ui/sales_form_screen.dart';
import 'package:stove_transaction/agent/history/history_screen.dart';
import 'package:stove_transaction/shared/ui/settings_screen.dart';

class MainLayout extends GetView<LayoutController> {
  final SessionManager _sessionManager = Get.find<SessionManager>();

  MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _sessionManager.isAdmin;
    final bool isAgent = _sessionManager.isAgent;

    return Scaffold(
      body: Obx(() {
        if (isAdmin) {
          return IndexedStack(
            index: controller.tabIndex.value,
            children: [
              DashboardScreen(),
              AdminSalesScreen(),
              MonitoringScreen(),
              SettingsScreen(),
            ],
          );
        } else if (isAgent) {
          return IndexedStack(
            index: controller.tabIndex.value,
            children: [
              SalesScreen(),
              HistoryScreen(),
              SettingsScreen(),
            ],
          );
        } else {
          return const Center(child: Text('Unknown Role'));
        }
      }),
      bottomNavigationBar: isAdmin
          ? const AdminBottomNav()
          : isAgent
              ? const AgentBottomNav()
              : const SizedBox.shrink(),
    );
  }
}
