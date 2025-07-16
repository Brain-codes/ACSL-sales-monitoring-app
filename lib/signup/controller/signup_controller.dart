import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupController extends GetxController {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool agreeToTerms = false.obs;
  final RxBool isPasswordObscured = true.obs;
  final _supabaseAuth = Supabase.instance.client.auth;
  final _supabaseFunction = Supabase.instance.client.functions;
  final _supabaseClient = Supabase.instance.client;

  void register() async {
    isLoading.value = true;

    try {
      // 1. Check if organization exists and get its ID
      final org = await _supabaseClient
          .from('organizations')
          .select('id')
          .eq('partner_email', emailController.text)
          .maybeSingle();

      if (org == null) {
        showInfoToast(
          title: 'Organization Check',
          message: 'No organization with such email exists!',
        );
        isLoading.value = false;
        return;
      }

      final organizationId = org['id'];

      // 2. Check if user already exists
      final response =
          await _supabaseFunction.invoke('check-user-exists', body: {
        'email': emailController.text,
      });

      final exists = response.data['exists'];
      if (exists == true) {
        showInfoToast(
          title: 'User Registration',
          message: 'User already exists!',
        );
        isLoading.value = false;
        return;
      }

      // 3. Register new user in Supabase Auth with organization_id
      final signupResponse = await _supabaseAuth.signUp(
        password: confirmPasswordController.text,
        email: emailController.text,
        data: {
          'full_name': nameController.text,
          'display_name': nameController.text,
          'role': 'admin',
          'organization_id': organizationId, // ✅ Included here
        },
      );

      if (signupResponse.user != null) {
        showSuccessToast(
          title: 'Register',
          message: 'User created successfully! Check Email for confirmation.',
        );
        Get.back();
      }
    } on AuthException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      showErrorToast(title: 'Error', message: e.toString());
    }

    isLoading.value = false;
  }

  void togglePasswordVisibility() {
    isPasswordObscured.value = !isPasswordObscured.value;
  }

  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name cannot be empty';
    }
    return null;
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

  String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Confirm Password cannot be empty';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
