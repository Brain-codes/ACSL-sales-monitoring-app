import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/model/login_response_model.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final obscurePassword = true.obs;

  final _supabase = Get.find<SupabaseService>();
  final _session = Get.find<SessionManager>();
  final _logger = Logger();

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;

    try {
      final resp = await _supabase.callEdgeFunction(
        'login-with-credentials',
        body: {
          'identifier': emailController.text.trim(),
          'password': passwordController.text,
        },
        requireAuth: false,
      );

      if (!resp.success || resp.data == null) {
        _showError(resp.message);
        return;
      }

      final loginResp = LoginResponse.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
      _logger.w('LOGIN RESPOSE: ${loginResp.toJson()}');

      if (loginResp.accessToken.isEmpty) {
        _showError('Login failed. Please try again.');
        return;
      }

      _session.saveCompleteUserData(
        userId: loginResp.userId,
        role: loginResp.profile.role ?? '',
        token: loginResp.accessToken,
        userName: loginResp.profile.fullName ?? loginResp.profile.username ?? emailController.text.trim(),
        timeLoggedIn: DateTime.now().toIso8601String(),
        profile: loginResp.profile.toJson(),
      );

      // Hydrate Supabase client with the returned tokens
      if (loginResp.refreshToken.isNotEmpty) {
        try {
          final result = await Supabase.instance.client.auth.setSession(loginResp.refreshToken);
          if (result.session != null) {
            _session.saveSupabaseSession(result.session);
          }
        } catch (e) {
          _logger.w('Could not hydrate supabase session: $e');
        }
      }

      FocusManager.instance.primaryFocus?.unfocus();
      _navigateByRole(loginResp.profile.role ?? '');
    } catch (e) {
      _logger.e('Login error: $e');
      _showError('An unexpected error occurred.');
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  void _navigateByRole(String role) {
    if (role == 'acsl_agent' || role == 'admin' || role == 'acsl_agent_manager') {
      Get.offAllNamed(AppRoutes.acslHome);
    } else if (role == 'partner_agent') {
      Get.offAllNamed(AppRoutes.partnerHome);
    } else {
      _showError('Your account does not have access to this app.');
      return;
    }
    try {
      Get.find<DataRefreshService>().refreshAll();
    } catch (_) {}
  }

  void _showError(String msg) {
    toastification.show(
      title: Text(msg),
      type: ToastificationType.error,
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
