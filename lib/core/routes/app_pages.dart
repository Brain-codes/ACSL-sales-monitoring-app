import 'package:get/get.dart';
import 'package:stove_transaction/admin/dashboard/controller/dashboard_controller.dart';
import 'package:stove_transaction/admin/monitoring/monitoring_screen.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/agent/sales_form/controller/sales_form_controller.dart';
import 'package:stove_transaction/form/ui/user_form.dart';
import 'package:stove_transaction/splash/ui/splash_screen.dart';
import 'package:stove_transaction/onboarding/ui/onboarding_screen.dart';
import 'package:stove_transaction/login/ui/login_screen.dart';
import 'package:stove_transaction/signup/ui/signup_screen.dart';
import 'package:stove_transaction/main_layout/ui/main_layout.dart';
import 'package:stove_transaction/main_layout/controller/layout_controller.dart';
import 'package:stove_transaction/admin/dashboard/ui/dashboard_screen.dart';
import 'package:stove_transaction/admin/sales/ui/admin_sales_screen.dart';
import 'package:stove_transaction/admin/monitoring/ui/update_geo_screen.dart';
import 'package:stove_transaction/admin/sub_accounts/ui/manage_sales_agents_screen.dart';
import 'package:stove_transaction/admin/sync/ui/sync_offline_screen.dart';
import 'package:stove_transaction/admin/sales/ui/manage_sales_screen.dart';
import 'package:stove_transaction/agent/sales_form/ui/sales_form_screen.dart';
import 'package:stove_transaction/agent/history/history_screen.dart';
import 'package:stove_transaction/shared/ui/settings_screen.dart';

import 'package:stove_transaction/core/routes/app_routes.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.SPLASH,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.ONBOARDING,
      page: () => const OnboardingScreen(),
    ),
    GetPage(
      name: AppRoutes.LOGIN,
      page: () => LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.SIGNUP,
      page: () => SignupScreen(),
    ),
    GetPage(
      name: AppRoutes.ADMIN_HOME,
      page: () => MainLayout(),
      binding: BindingsBuilder(() {
        Get.put(LayoutController());
        Get.put(DashboardController());
      }),
    ),
    GetPage(
      name: AppRoutes.AGENT_HOME,
      page: () => MainLayout(),
      binding: BindingsBuilder(() {
        Get.put(LayoutController());
        Get.put(SalesController());
      }),
    ),
    GetPage(
      name: AppRoutes.ADMIN_DASHBOARD,
      page: () => DashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.ADMIN_SALES,
      page: () => AdminSalesScreen(),
    ),
    GetPage(
      name: AppRoutes.ADMIN_MONITORING,
      page: () => MonitoringScreen(),
    ),
    GetPage(
      name: AppRoutes.MANAGE_SALES_AGENTS,
      page: () => ManageSalesAgentsScreen(),
    ),
    GetPage(
      name: AppRoutes.UPDATE_STOVE_GEO,
      page: () => UpdateGeoScreen(),
    ),
    GetPage(
      name: AppRoutes.SYNC_OFFLINE_DATA,
      page: () => SyncOfflineScreen(),
    ),
    GetPage(
      name: AppRoutes.MANAGE_SALES,
      page: () => const ManageSalesScreen(),
    ),
    GetPage(
      name: AppRoutes.AGENT_SALES_FORM,
      page: () => const SalesFormScreen(),
      binding: BindingsBuilder(() {
        Get.put(SalesFormController());
      }),
    ),
    GetPage(
      name: AppRoutes.SALES_FORM,
      page: () => const SalesFormScreen(),
      binding: BindingsBuilder(() {
        Get.put(SalesFormController());
      }),
    ),
    GetPage(
      name: AppRoutes.USER_FORM,
      page: () => UserForm(),
    ),
    GetPage(
      name: AppRoutes.AGENT_HISTORY,
      page: () => const HistoryScreen(),
    ),
    GetPage(
      name: AppRoutes.SETTINGS,
      page: () => const SettingsScreen(),
    ),
  ];
}
