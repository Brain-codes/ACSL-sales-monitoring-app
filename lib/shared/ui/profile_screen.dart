import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/controller/profile_controller.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/ui/profile/profile_header.dart';
import 'package:stove_transaction/shared/ui/profile/profile_info_card.dart';
import 'package:stove_transaction/shared/ui/profile/profile_detail_rows.dart';
import 'package:stove_transaction/shared/ui/profile/change_password_bottom_sheet.dart';
import 'package:stove_transaction/shared/ui/profile/update_profile_bottom_sheet.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final ProfileController controller = Get.put(ProfileController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: BaseAppBar(
        otherWidgets: Row(
          children: [
            // Update Profile Button (only show if there are updateable fields)
            Obx(() {
              if (controller.canUpdateProfile()) {
                return GestureDetector(
                  onTap: () =>
                      UpdateProfileBottomSheet.show(context, controller),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.edit_outlined,
                      color: AppColors.primaryColor,
                      size: 24,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            // Change Password Button
            GestureDetector(
              onTap: () => ChangePasswordBottomSheet.show(context, controller),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.lock_outline,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
          );
        }

        final profile = controller.userProfile.value;
        if (profile == null) {
          return const Center(
            child: Text(
              'No profile data available',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header with Avatar
              ProfileHeader(
                profile: profile,
                getUserInitials: controller.getUserInitials,
              ),

              const SizedBox(height: 20),

              // Personal Information
              ProfileInfoCard(
                title: 'Personal Information',
                icon: Icons.person_outline,
                children: [
                  ProfileDetailRowWithEditability(
                    label: 'Full Name',
                    value: profile.fullName,
                    canEdit: profile.fullName == null,
                  ),
                  ProfileDetailRow(
                    label: 'Email Address',
                    value: profile.email ?? 'N/A',
                  ),
                  ProfileDetailRowWithEditability(
                    label: 'Phone Number',
                    value: profile.phone,
                    canEdit: profile.phone == null,
                  ),
                  ProfileDetailRow(
                    label: 'Role',
                    value: profile.role ?? 'N/A',
                  ),
                  ProfileDetailRow(
                    label: 'Member Since',
                    value: controller.formatDate(profile.createdAt),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Organization Information
              if (profile.organization != null)
                ProfileInfoCard(
                  title: 'Organization',
                  icon: Icons.business_outlined,
                  children: [
                    ProfileDetailRow(
                      label: 'Organization Name',
                      value: profile.organization!.name,
                    ),
                    ProfileDetailRow(
                      label: 'Partner Email',
                      value: profile.organization!.partnerEmail ?? 'N/A',
                    ),
                    ProfileDetailRow(
                      label: 'Organization Created',
                      value: controller
                          .formatDate(profile.organization!.createdAt),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Account Status
              ProfileInfoCard(
                title: 'Account Status',
                icon: Icons.security_outlined,
                children: [
                  ProfileStatusRow(
                    label: 'Password Changed',
                    value: profile.hasChangedPassword == true ? 'Yes' : 'No',
                    isPositive: profile.hasChangedPassword == true,
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }
}
