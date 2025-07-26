import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/profile_service.dart';
import 'package:stove_transaction/core/model/profile_model.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileController extends GetxController {
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final ProfileService _profileService = ProfileService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _logger = Logger();

  // Loading states
  final isLoading = false.obs;
  final isChangingPassword = false.obs;

  // Profile data
  final Rxn<ProfileModel> userProfile = Rxn<ProfileModel>();

  // Password change form controllers
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Profile update form controllers
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();

  // Form validation
  final isCurrentPasswordObscured = true.obs;
  final isNewPasswordObscured = true.obs;
  final isConfirmPasswordObscured = true.obs;

  // Profile update state
  final isUpdatingProfile = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserProfileFromSession();
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  /// Load user profile from session (no API call needed)
  void loadUserProfileFromSession() async {
    try {
      isLoading.value = true;

      // Debug: Log session data
      _logger.d('=== Profile Controller Debug ===');
      _logger.d('User ID: ${_sessionManager.userId}');
      _logger.d('User Email: ${_sessionManager.userEmail}');
      _logger.d('User Full Name: ${_sessionManager.userFullName}');
      _logger.d('User Phone: ${_sessionManager.userPhone}');
      _logger.d('User Role: ${_sessionManager.role}');
      _logger.d('Has Changed Password: ${_sessionManager.hasChangedPassword}');

      // Check raw profile data
      final rawProfile = _sessionManager.getUserProfile();
      _logger.d('Raw Profile Data: $rawProfile');

      // Get profile from session
      final sessionProfile = _sessionManager.getUserProfileModel();
      _logger.d('Session Profile Model: $sessionProfile');

      if (sessionProfile != null) {
        _logger.d('Using session profile model');
        userProfile.value = sessionProfile;
      } else {
        _logger.d('Creating profile from basic session data');
        // Fallback: try to construct from basic session data
        final userId = _sessionManager.userId;
        final email = _sessionManager.userEmail;
        final fullName = _sessionManager.userFullName;
        final phone = _sessionManager.userPhone;
        final role = _sessionManager.role;
        final hasChangedPassword = _sessionManager.hasChangedPassword;

        if (userId != null) {
          // Create a basic profile from session data
          userProfile.value = ProfileModel(
            id: userId,
            email: email,
            fullName: fullName,
            phone: phone,
            role: role,
            hasChangedPassword: hasChangedPassword,
            createdAt: DateTime
                .now(), // We don't have this in session, use current time
          );
          _logger.d('Created profile: ${userProfile.value}');
        }
      }
      _logger.d('=== End Profile Debug ===');
    } catch (e) {
      _logger.e('Error loading profile from session: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to load profile data',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh profile data from server (optional - only if needed)
  void refreshProfileFromServer() async {
    try {
      isLoading.value = true;

      final userId = _sessionManager.userId;
      if (userId != null) {
        final result =
            await _profileService.fetchUserProfileWithOrganization(userId);
        if (result.success && result.data != null) {
          userProfile.value = result.data;
          // Update session with fresh data
          _sessionManager.saveUserProfile(result.data!.toJson());
        }
      }
    } catch (e) {
      _logger.e('Error refreshing profile: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to refresh profile data',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Change user password
  void changePassword() async {
    if (!_validatePasswordForm()) return;

    try {
      isChangingPassword.value = true;

      // Update password using Supabase Auth
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPasswordController.text,
        ),
      );

      // Update the has_changed_password flag in profile
      final userId = _sessionManager.userId;
      if (userId != null) {
        await _profileService.updateUserProfile(
          userId: userId,
          hasChangedPassword: true,
        );
      }

      // Clear form
      _clearPasswordForm();

      showSuccessToast(
        title: 'Success',
        message: 'Password changed successfully',
      );

      // Close the password change bottomsheet
      Get.back();
    } on AuthException catch (e) {
      showErrorToast(
        title: 'Password Change Failed',
        message: e.message,
      );
    } catch (e) {
      _logger.e('Error changing password: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to change password. Please try again.',
      );
    } finally {
      isChangingPassword.value = false;
    }
  }

  /// Update user profile (only for null fields)
  void updateProfile() async {
    if (!_validateProfileForm()) return;

    try {
      isUpdatingProfile.value = true;

      final userId = _sessionManager.userId;
      if (userId == null) {
        showErrorToast(title: 'Error', message: 'User ID not found');
        return;
      }

      // Prepare update data (only for fields that are currently null)
      Map<String, dynamic> updateData = {};

      final currentProfile = userProfile.value;
      if (currentProfile != null) {
        // Only add fullName if it's currently null and user provided a value
        if (currentProfile.fullName == null &&
            fullNameController.text.isNotEmpty) {
          updateData['full_name'] = fullNameController.text.trim();
        }

        // Only add phone if it's currently null and user provided a value
        if (currentProfile.phone == null && phoneController.text.isNotEmpty) {
          updateData['phone'] = phoneController.text.trim();
        }
      }

      if (updateData.isEmpty) {
        showInfoToast(
          title: 'No Updates',
          message: 'No valid fields to update',
        );
        return;
      }

      // Call the API to update profile
      final result = await _profileService.updateUserProfile(
        userId: userId,
        fullName: updateData['full_name'],
        phone: updateData['phone'],
      );

      if (result.success) {
        // Update local profile
        if (currentProfile != null) {
          final updatedProfile = currentProfile.copyWith(
            fullName: updateData['full_name'] ?? currentProfile.fullName,
            phone: updateData['phone'] ?? currentProfile.phone,
          );

          userProfile.value = updatedProfile;

          // Update session
          _sessionManager.saveUserProfile(updatedProfile.toJson());
        }

        // Clear form
        _clearProfileForm();

        showSuccessToast(
          title: 'Success',
          message: 'Profile updated successfully',
        );

        // Close the update bottomsheet
        Get.back();
      } else {
        showErrorToast(
          title: 'Update Failed',
          message: result.message,
        );
      }
    } catch (e) {
      _logger.e('Error updating profile: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to update profile. Please try again.',
      );
    } finally {
      isUpdatingProfile.value = false;
    }
  }

  /// Validate profile update form
  bool _validateProfileForm() {
    final currentProfile = userProfile.value;
    if (currentProfile == null) return false;

    bool hasValidUpdate = false;

    // Check if fullName can be updated (is null) and has valid input
    if (currentProfile.fullName == null && fullNameController.text.isNotEmpty) {
      if (fullNameController.text.trim().length < 2) {
        showInfoToast(
          title: 'Validation Error',
          message: 'Full name must be at least 2 characters',
        );
        return false;
      }
      hasValidUpdate = true;
    }

    // Check if phone can be updated (is null) and has valid input
    if (currentProfile.phone == null && phoneController.text.isNotEmpty) {
      if (phoneController.text.trim().length < 10) {
        showInfoToast(
          title: 'Validation Error',
          message: 'Phone number must be at least 10 characters',
        );
        return false;
      }
      hasValidUpdate = true;
    }

    if (!hasValidUpdate) {
      showInfoToast(
        title: 'No Updates',
        message: 'Please fill in at least one missing field',
      );
      return false;
    }

    return true;
  }

  /// Clear profile form
  void _clearProfileForm() {
    fullNameController.clear();
    phoneController.clear();
  }

  /// Check if user can update any profile fields
  bool canUpdateProfile() {
    final profile = userProfile.value;
    if (profile == null) return false;

    // User can update if any personal info field is null
    return profile.fullName == null || profile.phone == null;
  }

  /// Get list of updateable fields (null fields)
  List<String> getUpdateableFields() {
    final profile = userProfile.value;
    if (profile == null) return [];

    List<String> fields = [];
    if (profile.fullName == null) fields.add('Full Name');
    if (profile.phone == null) fields.add('Phone Number');

    return fields;
  }

  bool _validatePasswordForm() {
    if (currentPasswordController.text.isEmpty) {
      showInfoToast(
        title: 'Validation Error',
        message: 'Current password is required',
      );
      return false;
    }

    if (newPasswordController.text.isEmpty) {
      showInfoToast(
        title: 'Validation Error',
        message: 'New password is required',
      );
      return false;
    }

    if (newPasswordController.text.length < 6) {
      showInfoToast(
        title: 'Validation Error',
        message: 'New password must be at least 6 characters',
      );
      return false;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      showInfoToast(
        title: 'Validation Error',
        message: 'Passwords do not match',
      );
      return false;
    }

    if (currentPasswordController.text == newPasswordController.text) {
      showInfoToast(
        title: 'Validation Error',
        message: 'New password must be different from current password',
      );
      return false;
    }

    return true;
  }

  /// Clear password form
  void _clearPasswordForm() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
  }

  /// Toggle password visibility
  void toggleCurrentPasswordVisibility() {
    isCurrentPasswordObscured.value = !isCurrentPasswordObscured.value;
  }

  void toggleNewPasswordVisibility() {
    isNewPasswordObscured.value = !isNewPasswordObscured.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordObscured.value = !isConfirmPasswordObscured.value;
  }

  /// Get user initials for avatar
  String getUserInitials() {
    final fullName = userProfile.value?.fullName;
    if (fullName == null || fullName.isEmpty) {
      return userProfile.value?.email?.substring(0, 1).toUpperCase() ?? 'U';
    }

    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else {
      return names[0].substring(0, 1).toUpperCase();
    }
  }

  /// Format date
  String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
