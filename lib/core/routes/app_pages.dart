import 'package:get/get.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/features/auth/login/login_screen.dart';
import 'package:stove_transaction/features/auth/splash/splash_screen.dart';
import 'package:stove_transaction/features/sales/create/create_sale_screen.dart';
import 'package:stove_transaction/layout/acsl_agent_layout.dart';
import 'package:stove_transaction/layout/partner_agent_layout.dart';

class AppPages {
  static final routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.acslHome, page: () => const AcslAgentLayout()),
    GetPage(name: AppRoutes.partnerHome, page: () => const PartnerAgentLayout()),
    GetPage(name: AppRoutes.salesCreate, page: () => const CreateSaleScreen()),
  ];
}
