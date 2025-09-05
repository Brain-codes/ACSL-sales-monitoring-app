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
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/shared/controller/settings_controller.dart';
import 'package:stove_transaction/shared/ui/settings_screen.dart';

class MainLayout extends StatelessWidget {
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final SettingsController _settingsController = Get.put(SettingsController());

  MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _sessionManager.isAdmin;
    final bool isAgent = _sessionManager.isAgent;

    // Track if offline banner is dismissed (persisted)
    final GetStorage _storage = GetStorage();
    final String offlineBannerKey = 'offline_banner_dismissed';
    final RxBool isOfflineBannerDismissed = (() {
      final stored = GetStorage().read('offline_banner_dismissed');
      if (stored is bool) {
        return RxBool(stored);
      }
      return RxBool(false);
    })();

    // Helper for bottom border color in offline mode
    Color? getOfflineBorderColor() {
      if (_settingsController.isOfflineModeEnabled &&
          isOfflineBannerDismissed.value) {
        return AppColors.warningColor;
      }
      return null;
    }

    // Main navigation with offline banner above bottom nav
    Widget mainNav(
        {required List<Widget> pages, required List<NavItem> navItems}) {
      // Pass a callback to reset the banner
      void resetOfflineBanner() {
        isOfflineBannerDismissed.value = false;
        _storage.write(offlineBannerKey, false);
      }

      // Helper to inject the callback into SettingsScreen
      List<Widget> injectCallbackToSettings(List<Widget> pages) {
        return pages.map((page) {
          if (page is SettingsScreen) {
            return SettingsScreen(onOfflineModeEnabled: resetOfflineBanner);
          }
          return page;
        }).toList();
      }

      return Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Obx(() => BaseBottomNavigation(
                      pages: injectCallbackToSettings(pages),
                      navItems: navItems,
                      hasTopBorder: true,
                      topBorderColor: getOfflineBorderColor(),
                    )),
                Obx(
                  () => _settingsController.isOfflineModeEnabled &&
                          !isOfflineBannerDismissed.value
                      ? Positioned(
                          left: 0,
                          right: 0,
                          bottom:
                              56, // Height of BottomNavigationBar (default 56)
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0),
                            decoration: BoxDecoration(
                              color: AppColors.warningColor.withOpacity(0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off,
                                    color: AppColors.primaryTextColor,
                                    size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You are currently using Offline Mode',
                                    style: TextStyle(
                                      color: AppColors.primaryTextColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    isOfflineBannerDismissed.value = true;
                                    _storage.write(offlineBannerKey, true);
                                  },
                                  child: const Icon(Icons.close,
                                      color: AppColors.primaryTextColor,
                                      size: 18),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: isAdmin
          ? mainNav(
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
              ? mainNav(
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
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Role Not Recognized',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your account does not have a valid role assigned. Please log in again or contact support.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to login screen
                              Get.offAllNamed('/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Go to Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
