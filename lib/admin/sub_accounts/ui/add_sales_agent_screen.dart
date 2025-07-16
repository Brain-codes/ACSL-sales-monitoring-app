// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/add_sales_agent_controller.dart';
import 'package:stove_transaction/shared/services/helpers.dart';
import 'package:stove_transaction/shared/widgets/custom_textfield.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class AddSalesAgentScreen extends StatelessWidget {
  final AddSalesAgentController controller = Get.put(AddSalesAgentController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(
        title: "Add New Sales Agent",
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Full Name',
                hintText: 'Enter your full name',
                controller: controller.nameController,
                inputType: TextInputType.text,
                validator: Helpers().validateName,
              ),
              CustomTextField(
                label: 'Email',
                hintText: 'Enter your email',
                controller: controller.emailController,
                inputType: TextInputType.emailAddress,
                validator: Helpers().validateEmail,
              ),
              Obx(
                () => CustomTextField(
                  label: 'Password',
                  hintText: 'Enter your password',
                  controller: controller.passwordController,
                  inputType: TextInputType.visiblePassword,
                  obscureText: controller.isPasswordObscured.value,
                  validator: Helpers().validatePassword,
                  suffixIcon: Icon(
                    controller.isPasswordObscured.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.secondaryTextColor.withOpacity(0.5),
                  ),
                  onSuffixIconTap: () {
                    controller.togglePasswordVisibility();
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () =>
                        controller.showGeneratePasswordBottomSheet(context),
                    child: Text(
                      'Generate password',
                      style: TextThemes(context).getTextStyle(
                        fontSize: 11,
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Obx(
                () => CustomTextField(
                  label: 'Confirm Password',
                  hintText: 'Confirm your password',
                  controller: controller.confirmPasswordController,
                  inputType: TextInputType.visiblePassword,
                  obscureText: controller.isPasswordObscured.value,
                  validator: (value) => Helpers().validateConfirmPassword(
                      value, controller.passwordController.text),
                  suffixIcon: Icon(
                    controller.isPasswordObscured.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.secondaryTextColor.withOpacity(0.5),
                  ),
                  onSuffixIconTap: () {
                    controller.isLoading.value = false;
                    controller.togglePasswordVisibility();
                  },
                ),
              ),
              const SizedBox(height: 24.0),
              Obx(
                () => PrimaryButton(
                  text: 'Add Agent',
                  onPressed: () => controller.addAgent(),
                  isLoading: controller.isLoading.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
