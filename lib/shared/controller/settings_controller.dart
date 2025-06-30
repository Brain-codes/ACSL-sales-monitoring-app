// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    // isLoading.value = true;
    // final response = await _service.logout();
    // if (response.code == 200) {
    // await LocalDatabaseService().delete(DbKeyStrings.userDetailsKey);
    // await LocalDatabaseService().delete(DbKeyStrings.signupDevice);
    // await LocalDatabaseService().delete(DbKeyStrings.loginTimeCreated);
    // await LocalDatabaseService().delete(DbKeyStrings.loginToken);
    // await LocalDatabaseService().delete(DbKeyStrings.refreshToken);
    // await LocalDatabaseService().delete(DbKeyStrings.tokenExpiration);
    // await LocalDatabaseService().delete(
    //   DbKeyStrings.decideLaterActive,
    // );
    // UserStatusPosition.isDecideLater = false;
    // Navigator.pushNamedAndRemoveUntil(
    //     context, ScreenConstant.loginScreen, (Route<dynamic> route) => false);
  }
  // isLoading.value = false;
  // }
  // isLoading.value = false;

  // Future<void> getUser(BuildContext context) async {
  //   final response = await _authService.getUser();
  //   if (response.code == 200) {
  //     // await LocalDatabaseService()
  //     //     .add(DbKeyStrings.userDetailsKey, response.body);
  //   }
  // }
}
