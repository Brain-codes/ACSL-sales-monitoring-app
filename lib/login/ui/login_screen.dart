import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/routes/app_pages.dart';
import 'package:stove_transaction/login/controller/login_controller.dart';
import 'package:stove_transaction/shared/widgets/custom_textfield.dart';
import 'package:stove_transaction/shared/widgets/custom_checkbox.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';

class LoginScreen extends StatelessWidget {
  final LoginController loginController = Get.put(LoginController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Welcome Back',
                      style: TextThemes(context).getTextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Get.toNamed(AppRoutes.SIGNUP);
                          },
                          child: Text(
                            'Sign Up',
                            style: TextThemes(context).getTextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              CustomTextField(
                label: 'Username or Email',
                hintText: 'Enter Your Username or Email',
                controller: loginController.identifierController,
                inputType: TextInputType.text,
                validator: loginController.validateIdentifier,
              ),
              Obx(
                () => CustomTextField(
                  label: 'Password',
                  hintText: 'Password',
                  controller: loginController.passwordController,
                  inputType: TextInputType.visiblePassword,
                  obscureText: loginController.isPasswordObscured.value,
                  validator: loginController.validatePassword,
                  suffixIcon: Icon(
                    loginController.isPasswordObscured.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.secondaryTextColor.withOpacity(0.5),
                  ),
                  onSuffixIconTap: () {
                    loginController.togglePasswordVisibility();
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  loginController.isLoading.value = false;
                },
                child: CustomCheckbox(
                  value: loginController.rememberMe,
                  text: 'Remember Me',
                ),
              ),
            ],
          ),
        ),
      ),

      // ✅ Button fixed at the bottom
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Obx(
          () => PrimaryButton(
            text: 'Login',
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                loginController.login(context);
              }
            },
            isLoading: loginController.isLoading.value,
          ),
        ),
      ),
    );
  }
}
