import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/dashboard/ui/dashboard_screen.dart';
import 'package:stove_transaction/admin/monitoring/monitoring_screen.dart';
import 'package:stove_transaction/admin/sales/sales_screen.dart';
import 'package:stove_transaction/admin/sales/ui/admin_sales_screen.dart';
import 'package:stove_transaction/agent/dashboard/agent_dashboard_screen.dart';
import 'package:stove_transaction/agent/history/agent_history_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/services/session_manager.dart';

import 'package:stove_transaction/main_layout/ui/base_bottom_navigation.dart';
import 'package:stove_transaction/shared/ui/settings_screen.dart';

class MainLayout extends StatelessWidget {
  final SessionManager _sessionManager = Get.find<SessionManager>();

  MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _sessionManager.isAdmin;
    final bool isAgent = _sessionManager.isAgent;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: isAdmin
          ? BaseBottomNavigation(
              pages: [
                DashboardScreen(),
                AdminSalesScreen(),
                MonitoringScreen(),
                SettingsScreen(),
              ],
              navItems: [
                NavItem(iconPath: AppIcons.dashboardIcon, label: "Dashboard"),
                NavItem(iconPath: AppIcons.salesIcon, label: "Sales"),
                NavItem(iconPath: AppIcons.monitoringIcon, label: "Monitoring"),
                NavItem(iconPath: AppIcons.settingsIcon, label: "Settings"),
              ],
            )
          : isAgent
              ? BaseBottomNavigation(
                  pages: [
                    AgentDashboardScreen(),
                    AgentHistoryScreen(),
                    SalesScreen(showBackArrow: false),
                    SettingsScreen(),
                  ],
                  navItems: [
                    NavItem(
                        iconPath: AppIcons.dashboardIcon, label: "Dashboard"),
                    NavItem(iconPath: AppIcons.historyIcon, label: "History"),
                    NavItem(iconPath: AppIcons.salesIcon, label: "Sales"),
                    NavItem(iconPath: AppIcons.settingsIcon, label: "Settings"),
                  ],
                )
              : const Center(child: Text('Unknown Role')),
    );
  }
}
