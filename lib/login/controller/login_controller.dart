// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/login/model/user_model.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class LoginController extends GetxController {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool rememberMe = false.obs;
  final RxBool isPasswordObscured = true.obs;
  final _supabaseAuth = Supabase.instance.client.auth;
  final AuthService _authService = Get.find<AuthService>();
  Logger logger = Logger();
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final userData = RawUserMetaData().obs;
  void login(
    BuildContext context,
  ) async {
    isLoading.value = true;
    try {
      final response = await _supabaseAuth.signInWithPassword(
        password: passwordController.text,
        email: emailController.text,
      );
      if (response.user != null) {
        logger.d(response.session?.user);
        var result =
            RawUserMetaData.fromJson(response.user?.userMetadata ?? {});
        userData.value = result;

        // Save all user details using the saveUser method
        _sessionManager.saveUser(
          userId: response.user!.id,
          role: userData.value.role ??
              'agent', // Default to 'agent' if role is null
          token: response.session?.accessToken ?? '',
          userName: userData.value.fullName ??
              '', // Assuming fullName is available in userMetadata
          timeLoggedIn: DateTime.now().toIso8601String(),
        );
        logger.d(response.session?.accessToken);
        //SAVE USER SESSION FROM SUPABASE
        if (response.session != null) {
          _sessionManager.saveSupabaseSession(response.session);
        }
        if (userData.value.role == 'admin') {
          Get.offAllNamed(AppRoutes.ADMIN_HOME);
        } else {
          Get.offAllNamed(AppRoutes.AGENT_HOME);
        }
        showSuccessToast(
          // context: context,
          message: 'Login successful!',
          title: 'Success',
        );
      } else {
        // This else block might not be reached if an exception is thrown directly
        // by signInWithPassword for invalid credentials.
        // The try-catch block below will handle the AuthException.
        showInfoToast(
          message: 'An unexpected error occurred during login.',
          title: 'Login Status',
        );
      }
    } on AuthException catch (e) {
      showInfoToast(
        message: e.message,
        title: 'Login Status',
      );
    } catch (e) {
      showInfoToast(
        message: 'An unexpected error occurred: ${e.toString()}',
        title: 'Login Status',
      );
    }
    isLoading.value = false;
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

  Future<bool> refreshToken(BuildContext context) async {
    isLoading.value = true;
    final SessionManager _sessionManager = Get.find<SessionManager>();
    final response = await _supabaseAuth.refreshSession(
      _sessionManager.getSupabaseSession()?.refreshToken,
    );

    if (response.user != null) {
      // Save all user details using the saveUser method
      _sessionManager.saveUser(
        userId: response.user!.id,
        role: userData.value.role ??
            'agent', // Default to 'agent' if role is null
        token: response.session?.accessToken ?? '',
        userName: userData.value.fullName ??
            '', // Assuming fullName is available in userMetadata
        timeLoggedIn: DateTime.now().toIso8601String(),
      );
      //SAVE USER SESSION FROM SUPABASE
      if (response.session != null) {
        _sessionManager.saveSupabaseSession(response.session);
      }
      if (userData.value.role == 'admin') {
        Get.offAllNamed(AppRoutes.ADMIN_HOME);
      } else {
        Get.offAllNamed(AppRoutes.AGENT_HOME);
      }
      isLoading.value = false;
      return true;
    } else {
      logger.d('${response}');
      isLoading.value = false;

      print('refresh not done');
      // await localDatabaseService.delete(DbKeyStrings.userDetailsKey);
      Get.offAllNamed(AppRoutes.LOGIN);
      return false;
    }
  }
}
