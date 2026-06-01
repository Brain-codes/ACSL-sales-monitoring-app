import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/widgets/primary_button.dart';
import 'login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(LoginController());
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.brandPrimary,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/splash/splash-icon.png', height: 72,
                        errorBuilder: (_, __, ___) => const Icon(Icons.business, color: Colors.white, size: 72)),
                    const SizedBox(height: 24),
                    const Text('Welcome back',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Sign in to continue',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
                  ],
                ),
              ),
              // Form card
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: c.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          const Text('Sign In', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: c.emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email or Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Obx(() => TextFormField(
                            controller: c.passwordController,
                            obscureText: c.obscurePassword.value,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(c.obscurePassword.value ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => c.obscurePassword.toggle(),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          )),
                          const SizedBox(height: 32),
                          Obx(() => PrimaryButton(
                            label: 'Sign In',
                            loading: c.isLoading.value,
                            onPressed: c.login,
                          )),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'atmosfair.site',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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
