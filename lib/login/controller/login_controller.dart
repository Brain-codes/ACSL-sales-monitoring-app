import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';

class LoginController extends GetxController {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool rememberMe = false.obs;
  final RxBool isPasswordObscured = true.obs;

  void login() async {
    isLoading.value = true;
    final AuthService _authService = Get.find<AuthService>();
    final SessionManager _sessionManager = Get.find<SessionManager>();

    final String email = emailController.text;
    final String password = passwordController.text;

    final bool success = await _authService.login(email, password);
    isLoading.value = false;

    if (success) {
      // Simulate role assignment based on email for now
      if (email == 'admin@example.com') {
        _sessionManager.setToken('admin_token');
        _sessionManager.setRole('admin');
        Get.offAllNamed(AppRoutes.ADMIN_HOME);
      } else if (email == 'agent@example.com') {
        _sessionManager.setToken('agent_token');
        _sessionManager.setRole('agent');
        Get.offAllNamed(AppRoutes.AGENT_HOME);
      } else {
        // Default to agent for other successful logins
        _sessionManager.setToken('user_token');
        _sessionManager.setRole('agent');
        Get.offAllNamed(AppRoutes.AGENT_HOME);
      }
      Get.snackbar('Success', 'Login successful!');
    } else {
      Get.snackbar('Error', 'Invalid email or password',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void togglePasswordVisibility() {
    isPasswordObscured.value = !isPasswordObscured.value;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email cannot be empty';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }
}
