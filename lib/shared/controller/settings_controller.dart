// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/api_service.dart';
import 'package:stove_transaction/shared/services/settings_service.dart';

class SettingsController extends GetxController {
  final SettingsService _service = SettingsService(ApiService());
  final isLoading = false.obs;

  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController currentPasswordController = TextEditingController();
  //EDIT PROFILE
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController fullNameController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  TextEditingController genderController = TextEditingController();

  String formatDateString(String dateString) {
    List<String> dateComponents;

    if (dateString.contains('/')) {
      dateComponents = dateString.split('/');
      String formattedDate =
          "${dateComponents[0]}-${dateComponents[1]}-${dateComponents[2]}";
      return formattedDate;
    } else if (dateString.contains('-')) {
      dateComponents = dateString.split('-');
      String formattedDate =
          "${dateComponents[0]}-${dateComponents[1]}-${dateComponents[2]}";
      return formattedDate;
    } else {
      return dateString;
    }
  }

  Future<void> logout(BuildContext context) async {
    isLoading.value = true;
    // Navigate to the splash screen and remove all previous routes
    Get.offAllNamed(AppRoutes.LOGIN);
    isLoading.value = false;
  }
}
