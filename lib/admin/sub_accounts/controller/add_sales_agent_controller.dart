// ignore_for_file: prefer_const_constructors

import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/manage_sales_agents_controller.dart';
import 'package:stove_transaction/admin/sub_accounts/services/sales_agent_api_service.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/base_bottom_sheet.dart';
import 'dart:math'; // Import for Random
import 'package:stove_transaction/shared/ui/custom_input_field.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddSalesAgentController extends GetxController {
  final AgentService _agentService = AgentService(SupabaseService());
  final formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  TextEditingController generatedPassword =
      TextEditingController(text: 'loading...');
  final RxBool isLoading = false.obs;
  final RxBool isPasswordObscured = true.obs;
  Logger logger = Logger();
  final ManageSalesAgentsController _manageSalesAgentController =
      Get.put(ManageSalesAgentsController());
  void togglePasswordVisibility() {
    isPasswordObscured.value = !isPasswordObscured.value;
  }

  String generateRandomPassword() {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        12, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void updatePasswordFields(String password) {
    passwordController.text = password;
    Clipboard.setData(ClipboardData(text: password));
  }

  void addAgent() async {
    try {
      if (formKey.currentState!.validate()) {
        isLoading.value = true;

        final response = await _agentService.createAgent(
          fullName: nameController.text,
          email: emailController.text,
          password: passwordController.text,
        );

        logger.e(response.data);
        if (response.code == 200) {
          showSuccessToast(
            title: 'Agent Added',
            message: 'Sales agent added successfully!',
          );
          _manageSalesAgentController.fetchSalesAgents();
          Get.back();
        } else {
          showInfoToast(
            title: 'Add Agent Failed',
            message: response.message,
          );
        }
        isLoading.value = false;
      }
    } on AuthException catch (e) {
      Get.snackbar(
        'Error',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      showErrorToast(
        title: 'Error',
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void showGeneratePasswordBottomSheet(
    BuildContext context,
  ) {
    generatedPassword.text = generateRandomPassword();
    // isLoading.value = false;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        builder: (BuildContext context) {
          return BaseBottomSheet(
            title: 'Generate Password',
            subtitle: 'Generate a secure password for your sales agent',
            hasMode: false,
            items: [
              SizedBox(
                height: 10,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: CustomInputField(
                  label: '',
                  controller: generatedPassword,
                  inputType: TextInputType.emailAddress,
                  focusNode: null,
                  readOnly: true,
                  numberOfLines: 1,
                  actionKeyboard: TextInputAction.next,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SvgPicture.asset(AppIcons.copyBtn),
                  ),
                  onSuffixIconTap: () {
                    updatePasswordFields(generatedPassword.text);
                    Get.back(); // Close the bottom sheet
                    Clipboard.setData(
                      ClipboardData(text: generatedPassword.text),
                    );
                    showInfoToast(
                      title: 'Password copied!',
                      message:
                          'The generated password has been copied to the password fields.',
                    );
                  },
                ),
              ),
              SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 20,
              ),
            ],
          );
        });
  }
}
