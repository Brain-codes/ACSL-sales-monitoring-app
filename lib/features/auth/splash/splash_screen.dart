import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

/// Transient loading screen. Routing decisions (authed -> home, else -> login)
/// are handled by the router `redirect` in app_router.dart, so this screen just
/// shows branding while the redirect resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
