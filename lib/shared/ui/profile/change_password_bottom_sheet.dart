import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/controller/profile_controller.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';

class ChangePasswordBottomSheet {
  static void show(BuildContext context, ProfileController controller) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMedium),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current Password Field
            Obx(() => _PasswordField(
                  controller: controller.currentPasswordController,
                  label: 'Current Password',
                  isObscured: controller.isCurrentPasswordObscured.value,
                  onToggleVisibility:
                      controller.toggleCurrentPasswordVisibility,
                )),
            const SizedBox(height: 16),

            // New Password Field
            Obx(() => _PasswordField(
                  controller: controller.newPasswordController,
                  label: 'New Password',
                  isObscured: controller.isNewPasswordObscured.value,
                  onToggleVisibility: controller.toggleNewPasswordVisibility,
                )),
            const SizedBox(height: 16),

            // Confirm Password Field
            Obx(() => _PasswordField(
                  controller: controller.confirmPasswordController,
                  label: 'Confirm New Password',
                  isObscured: controller.isConfirmPasswordObscured.value,
                  onToggleVisibility:
                      controller.toggleConfirmPasswordVisibility,
                )),
            const SizedBox(height: 24),

            // Change Password Button
            Obx(() => PrimaryButton(
                  text: 'Change Password',
                  onPressed: controller.isChangingPassword.value
                      ? null
                      : controller.changePassword,
                  isLoading: controller.isChangingPassword.value,
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isObscured;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.isObscured,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isObscured,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMedium,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }
}
