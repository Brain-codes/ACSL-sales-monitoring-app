import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/controller/profile_controller.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';

class UpdateProfileBottomSheet {
  static void show(BuildContext context, ProfileController controller) {
    final updateableFields = controller.getUpdateableFields();

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
                  'Update Profile',
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

            // Info message
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can only update missing information. Once updated, these fields cannot be changed again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic form fields based on what can be updated
            ...updateableFields.map((field) {
              if (field == 'Full Name') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UpdateField(
                    controller: controller.fullNameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                  ),
                );
              } else if (field == 'Phone Number') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UpdateField(
                    controller: controller.phoneController,
                    label: 'Phone Number',
                    hint: 'Enter your phone number',
                  ),
                );
              }
              return const SizedBox.shrink();
            }).toList(),

            const SizedBox(height: 24),

            // Update Button
            Obx(() => PrimaryButton(
                  text: 'Update Profile',
                  onPressed: controller.isUpdatingProfile.value
                      ? null
                      : controller.updateProfile,
                  isLoading: controller.isUpdatingProfile.value,
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

class _UpdateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _UpdateField({
    required this.controller,
    required this.label,
    required this.hint,
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
          decoration: InputDecoration(
            hintText: hint,
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
          ),
        ),
      ],
    );
  }
}
