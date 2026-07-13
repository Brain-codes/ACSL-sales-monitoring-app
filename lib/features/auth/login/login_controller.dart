import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/model/login_response_model.dart';
import 'package:stove_transaction/core/router/app_navigator.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
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

      // Different user than last time → wipe the previous user's cached/offline
      // data and storage. Same user → keep it (reused offline, refetched
      // online). First-ever login has no lastUserId, so nothing to wipe.
      final lastUserId = _session.lastUserId;
      final isDifferentUser =
          lastUserId != null && lastUserId != loginResp.userId;
      if (isDifferentUser) {
        await Get.find<AuthService>().wipeAllData();
      }

      _session.saveCompleteUserData(
        userId: loginResp.userId,
        role: loginResp.profile.role ?? '',
        token: loginResp.accessToken,
        userName: loginResp.profile.fullName ?? loginResp.profile.username ?? emailController.text.trim(),
        timeLoggedIn: DateTime.now().toIso8601String(),
        profile: loginResp.profile.toJson(),
      );
      _session.setLastUserId(loginResp.userId);

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
      _goHomeAfterLogin();
    } catch (e) {
      _logger.e('Login error: $e');
      _showError('An unexpected error occurred.');
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  void _goHomeAfterLogin() {
    // SUPER-ADMIN-ONLY build: any authenticated user gets the full surface.
    goHome();
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
