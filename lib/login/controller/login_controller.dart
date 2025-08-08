// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/profile_service.dart';
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
  final ProfileService _profileService = ProfileService();
  final Logger logger = Logger();
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

        // Fetch complete user profile with organization data
        try {
          final profileResult =
              await _profileService.fetchUserProfileWithOrganization(
            response.user!.id,
          );

          if (profileResult.success && profileResult.data != null) {
            final profile = profileResult.data!;

            // Save complete user data including profile and organization
            _sessionManager.saveCompleteUserData(
              userId: response.user!.id,
              role: userData.value.role ?? 'agent',
              token: response.session?.accessToken ?? '',
              userName: profile.fullName ?? userData.value.fullName ?? '',
              timeLoggedIn: DateTime.now().toIso8601String(),
              profile: profile.toJson(),
            );

            logger.d(
                'User profile with organization saved: ${profile.organization?.name}');
          } else {
            // Fallback to basic user data if profile fetch fails
            logger.w('Failed to fetch user profile: ${profileResult.message}');
            _sessionManager.saveUser(
              userId: response.user!.id,
              role: userData.value.role ?? 'agent',
              token: response.session?.accessToken ?? '',
              userName: userData.value.fullName ?? '',
              timeLoggedIn: DateTime.now().toIso8601String(),
            );
          }
        } catch (e) {
          logger.e('Error fetching user profile: $e');
          // Fallback to basic user data
          _sessionManager.saveUser(
            userId: response.user!.id,
            role: userData.value.role ?? 'agent',
            token: response.session?.accessToken ?? '',
            userName: userData.value.fullName ?? '',
            timeLoggedIn: DateTime.now().toIso8601String(),
          );
        }

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
    if (isLoading.value) {
      logger.d('Refresh already in progress, skipping...');
      return false;
    }

    isLoading.value = true;

    try {
      // Get the current saved session
      final savedSession = _sessionManager.getSupabaseSession();

      if (savedSession?.refreshToken == null ||
          savedSession!.refreshToken!.isEmpty) {
        logger.e('No valid refresh token available in session');
        isLoading.value = false;
        _handleRefreshFailure();
        return false;
      }

      logger.d('Attempting to refresh session...');
      final response =
          await _supabaseAuth.refreshSession(savedSession.refreshToken!);

      if (response.user != null &&
          response.session != null &&
          response.session!.accessToken.isNotEmpty) {
        // Update user metadata
        var result =
            RawUserMetaData.fromJson(response.user?.userMetadata ?? {});
        userData.value = result;

        // Fetch complete user profile with organization data on token refresh
        try {
          final profileResult =
              await _profileService.fetchUserProfileWithOrganization(
            response.user!.id,
          );

          if (profileResult.success && profileResult.data != null) {
            final profile = profileResult.data!;

            // Save complete user data including profile and organization
            _sessionManager.saveCompleteUserData(
              userId: response.user!.id,
              role: userData.value.role ?? 'agent',
              token: response.session!.accessToken,
              userName: profile.fullName ?? userData.value.fullName ?? '',
              timeLoggedIn: DateTime.now().toIso8601String(),
              profile: profile.toJson(),
            );

            logger.d(
                'User profile with organization refreshed: ${profile.organization?.name}');
          } else {
            // Fallback to basic user data if profile fetch fails
            logger.w(
                'Failed to fetch user profile on refresh: ${profileResult.message}');
            _sessionManager.saveUser(
              userId: response.user!.id,
              role: userData.value.role ?? 'agent',
              token: response.session!.accessToken,
              userName: userData.value.fullName ?? '',
              timeLoggedIn: DateTime.now().toIso8601String(),
            );
          }
        } catch (e) {
          logger.e('Error fetching user profile on refresh: $e');
          // Fallback to basic user data
          _sessionManager.saveUser(
            userId: response.user!.id,
            role: userData.value.role ?? 'agent',
            token: response.session!.accessToken,
            userName: userData.value.fullName ?? '',
            timeLoggedIn: DateTime.now().toIso8601String(),
          );
        }

        // Save updated Supabase session
        _sessionManager.saveSupabaseSession(response.session);

        logger.d('Token refresh successful');
        isLoading.value = false;
        return true;
      } else {
        logger.e('Token refresh failed: No user or session returned');
        isLoading.value = false;
        _handleRefreshFailure();
        return false;
      }
    } catch (e) {
      logger.e('Token refresh error: $e');
      isLoading.value = false;

      // Handle specific refresh token errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('refresh_token_not_found') ||
          errorString.contains('invalid refresh token') ||
          errorString.contains('refresh token not found') ||
          errorString.contains('session_not_found')) {
        logger.e('Invalid refresh token detected, forcing re-authentication');
      }

      _handleRefreshFailure();
      return false;
    }
  }

  /// Handle refresh token failure
  void _handleRefreshFailure() {
    _sessionManager.logout();
    Get.offAllNamed(AppRoutes.LOGIN);
  }
}
