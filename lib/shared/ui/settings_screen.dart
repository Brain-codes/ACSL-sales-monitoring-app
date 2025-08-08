// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_print, unnecessary_new, import_of_legacy_library_into_null_safe

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/shared/controller/settings_controller.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/settings_tile.dart';
import 'package:stove_transaction/shared/widgets/offline_data_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsController _settingsController = Get.put(SettingsController());
  var count = 1;

  _logout() {
    _settingsController.logout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraint) {
                return SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 15,
                        right: 15,
                        bottom: 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 30,
                          ),
                          Text(
                            'Settings',
                            style: TextThemes(context).getTextStyle(
                              color: AppColors.primaryTextColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(
                            height: 30,
                          ),

                          Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Get.toNamed(AppRoutes.PROFILE);
                                },
                                child: SettingsTiles(
                                  buttonValue: 'Profile',
                                  iconValue: AppIcons.profile,
                                  descripionValue: 'Manage your account',
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  // Navigator.pushNamed(context,
                                  //     ScreenConstant.changePasswordScreen);
                                },
                                child: SettingsTiles(
                                  buttonValue: 'Security',
                                  iconValue: AppIcons.security,
                                  descripionValue:
                                      'Manage your password and login details',
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  // Navigator.pushNamed(
                                  //   context,
                                  //   ScreenConstant.faqScreen,
                                  // );
                                },
                                child: SettingsTiles(
                                  buttonValue: 'FAQ\'s',
                                  iconValue: AppIcons.faq,
                                  descripionValue: 'Get to know about us',
                                ),
                              ),
                            ],
                          ),
                          // InkWell(
                          //   onTap: () {
                          //     // Navigator.pushNamed(
                          //     //   context,
                          //     //   ScreenConstant.privacyPolicyScreen,
                          //     // );
                          //   },
                          //   child: SettingsTiles(
                          //     buttonValue: AppStrings.privacyPolicy,
                          //     iconValue: AppIcons.security,
                          //     descripionValue: AppStrings.privacyPolicyBody,
                          //   ),
                          // ),
                          InkWell(
                            onTap: () {
                              // Navigator.of(context).push(
                              //   createPageRoute(
                              //     const ChatSupport(),
                              //     RouteAnimation.slide,
                              //   ),
                              // );
                            },
                            child: SettingsTiles(
                              buttonValue: 'Chat Support',
                              iconValue: AppIcons.chatIcon,
                              descripionValue: 'Report any issue or complaint',
                            ),
                          ),

                          SizedBox(height: 20),

                          // Offline Data Widget
                          OfflineDataWidget(controller: _settingsController),

                          //LOGOUT
                          InkWell(
                            onTap: () {
                              _logout();
                              // openBaseModal(
                              //   context,
                              //   'You are about to logout',
                              //   showIrreversible: false,
                              //   onProceed: () {
                              //     Get.back();
                              //     _logout();
                              //   },
                              //   title: 'Log out',
                              // );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 18.0,
                                bottom: 18,
                                left: 10,
                                right: 10,
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset(AppIcons.logoutIcon),
                                  SizedBox(
                                    width: 15,
                                  ),
                                  Text(
                                    "Logout",
                                    style: TextThemes(context).getTextStyle(
                                      color: AppColors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_settingsController.isLoading.value) SizedBox(),
          ],
        ),
      ),
    );
  }
}
