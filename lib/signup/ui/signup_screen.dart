import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/signup/controller/signup_controller.dart';
import 'package:stove_transaction/shared/widgets/custom_textfield.dart';
import 'package:stove_transaction/shared/widgets/custom_checkbox.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';

class SignupScreen extends StatelessWidget {
  final SignupController signupController = Get.put(SignupController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  SignupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              Text(
                'Welcome',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppColors.primaryTextColor,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create your account or',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.back(); // Navigate back to login
                    },
                    child: Text(
                      'Login',
                      style: TextThemes(context).getTextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              CustomTextField(
                label: 'Username',
                hintText: 'Enter your username',
                controller: signupController.nameController,
                inputType: TextInputType.text,
                validator: signupController.validateName,
              ),
              CustomTextField(
                label: 'Email',
                hintText: 'Enter your email',
                controller: signupController.emailController,
                inputType: TextInputType.emailAddress,
                validator: signupController.validateEmail,
              ),
              Obx(
                () => CustomTextField(
                  label: 'Password',
                  hintText: 'Enter your password',
                  controller: _passwordController,
                  inputType: TextInputType.visiblePassword,
                  obscureText: signupController.isPasswordObscured.value,
                  validator: signupController.validatePassword,
                  suffixIcon: Icon(
                    signupController.isPasswordObscured.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.secondaryTextColor.withOpacity(0.5),
                  ),
                  onSuffixIconTap: () {
                    signupController.togglePasswordVisibility();
                  },
                ),
              ),
              Obx(
                () => CustomTextField(
                  label: 'Confirm Password',
                  hintText: 'Confirm your password',
                  controller: signupController.confirmPasswordController,
                  inputType: TextInputType.visiblePassword,
                  obscureText: signupController.isPasswordObscured.value,
                  validator: (value) => signupController
                      .validateConfirmPassword(value, _passwordController.text),
                  suffixIcon: Icon(
                    signupController.isPasswordObscured.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.secondaryTextColor.withOpacity(0.5),
                  ),
                  onSuffixIconTap: () {
                    signupController.togglePasswordVisibility();
                  },
                ),
              ),
              CustomCheckbox(
                value: signupController.agreeToTerms,
                text: 'I agree to the',
                linkText: 'terms and conditions',
                onLinkTap: () {
                  // Handle terms and conditions navigation
                },
              ),
              const SizedBox(height: 100), // spacing before bottom button
            ],
          ),
        ),
      ),

      // ✅ Button pinned at bottom
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() => PrimaryButton(
              text: 'Register',
              onPressed: () {
                if (_formKey.currentState!.validate() &&
                    signupController.agreeToTerms.value) {
                  signupController.register();
                } else if (!signupController.agreeToTerms.value) {
                  Get.snackbar(
                      'Error', 'Please agree to the terms and conditions');
                }
              },
              isLoading: signupController.isLoading.value,
            )),
      ),
    );
  }
}
