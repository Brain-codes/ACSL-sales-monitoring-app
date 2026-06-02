import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/widgets/update_prompt_sheet.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    checkAndShowUpdatePrompt();
    final session = Get.find<SessionManager>();
    if (session.isAuthenticated) {
      final role = session.role ?? '';
      if (role == 'acsl_agent' || role == 'admin') {
        Get.offAllNamed(AppRoutes.acslHome);
      } else if (role == 'partner_agent') {
        Get.offAllNamed(AppRoutes.partnerHome);
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/splash/splash-icon.png', height: 96,
                errorBuilder: (_, __, ___) => const Icon(Icons.business, color: AppColors.brandPrimary, size: 96)),
            const SizedBox(height: 24),
            const Text(
              'ACSL Sales',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.brandPrimary, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
