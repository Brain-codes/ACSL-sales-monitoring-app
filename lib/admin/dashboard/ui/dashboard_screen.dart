// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/dashboard/controller/dashboard_controller.dart';
import 'package:stove_transaction/admin/sales/ui/manage_sales_screen.dart';
import 'package:stove_transaction/admin/sales/ui/offline_sales_screen.dart';
import 'package:stove_transaction/admin/sync/ui/sync_offline_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/form/ui/user_form.dart';
import 'package:stove_transaction/shared/widgets/dashboard_action_tile.dart';
import 'package:stove_transaction/shared/widgets/summary_box.dart';

class DashboardScreen extends GetView<DashboardController> {
  DashboardScreen({Key? key}) : super(key: key);

  final SessionManager _sessionManager = Get.find<SessionManager>();

  @override
  Widget build(BuildContext context) {
    Get.put(DashboardController()); // Initialize the controller

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
              // gradient: LinearGradient(
              //   begin: Alignment.topCenter,
              //   end: Alignment.bottomCenter,
              //   colors: [
              //     Color.fromARGB(255, 226, 224, 250), // Example light blue
              //     Color.fromARGB(255, 6, 9, 93), // Example teal
              //   ],
              // ),
              ),
          child: RefreshIndicator(
            onRefresh: () => controller.refreshDashboardData(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Welcome, ${_sessionManager.userName ?? 'Lapo MFB'}',
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigator.push(
                          //   context,
                          //   createPageRoute(
                          //     NotificationScreen(),
                          //     RouteAnimation.fade,
                          //   ),
                          // );
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.inactiveTextFormFieldColor
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              AppIcons.notificationIcon,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),

                  // Optional Alert Banner (Reactive)
                  Obx(() {
                    if (controller.stovesWithLandmark.value < 300) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                'You have ${300 - controller.stovesWithLandmark.value} stoves with pending GPS updates.',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 14,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Get.toNamed(AppRoutes.UPDATE_STOVE_GEO),
                              child: Text(
                                '[Fix Now]',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  const SizedBox(height: 24.0),

                  // Metrics Summary (Reactive)
                  Text(
                    'Summary',
                    style: TextThemes(context).getTextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  Obx(
                    () => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SummaryBox(
                            width: MediaQuery.of(context).size.width / 1.8 - 24,
                            icon: Icons.receipt_long,
                            backgroundColor: Color.fromARGB(255, 0, 121, 24),
                            title: 'Total Sales',
                            value: '\$${controller.totalSales.value}',
                          ),
                          const SizedBox(width: 16.0),
                          SummaryBox(
                            width: MediaQuery.of(context).size.width / 1.8 - 24,
                            icon: Icons.sync,
                            backgroundColor: Color.fromARGB(255, 121, 0, 0),
                            title: 'Offline Records',
                            value: controller.pendingSync.value.toString(),
                          ),
                          const SizedBox(width: 16.0),
                          SummaryBox(
                            width: MediaQuery.of(context).size.width / 1.8 - 24,
                            icon: Icons.people,
                            backgroundColor: Color.fromARGB(255, 164, 148, 0),
                            title: 'Sales Agents',
                            value: controller.salesAgents.value.toString(),
                          ),
                          const SizedBox(width: 16.0),
                          SummaryBox(
                            width: MediaQuery.of(context).size.width / 1.8 - 24,
                            icon: Icons.location_on,
                            backgroundColor: Color.fromARGB(255, 0, 52, 121),
                            title: 'Stoves with Landmark',
                            value:
                                controller.stovesWithLandmark.value.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // Quick Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Quick action',
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          // Navigator.push(
                          //   context,
                          //   createPageRoute(
                          //     AllTransactionsScreen(),
                          //     RouteAnimation.fade,
                          //   ),
                          // );
                        },
                        child: Text(
                          'See all',
                          style: TextThemes(context).getTextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color:
                                AppColors.secondaryTextColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  Column(
                    children: [
                      DashboardActionTile(
                          icon: Icons.add_shopping_cart,
                          title: 'Start New Sale',
                          description: 'Initiate a new stove sale transaction.',
                          onTap: () => {
                                Get.to(
                                  () => UserForm(),
                                )
                              }),
                      DashboardActionTile(
                          icon: Icons.group,
                          title: 'Manage Sales Agents',
                          description: 'View and manage sales agent accounts.',
                          onTap: () =>
                              Get.toNamed(AppRoutes.MANAGE_SALES_AGENTS)),
                      DashboardActionTile(
                        icon: Icons.view_list,
                        title: 'View All Sales',
                        description: 'View and manage all partner sales',
                        onTap: () => {
                          //  Get.put(ManageSalesAgentsController()),
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ManageSalesScreen(
                                showBackButton: true,
                              ),
                            ),
                          )
                        },
                      ),
                      DashboardActionTile(
                        icon: Icons.cloud_upload,
                        title: 'Sync Offline Data',
                        description:
                            'Synchronize local offline data with the server.',
                        onTap: () => Get.to(() => SyncOfflineScreen()),
                      ),
                      DashboardActionTile(
                        icon: Icons.storage,
                        title: 'Offline Records',
                        description:
                            'View and manage all offline sales records.',
                        onTap: () => Get.to(() => OfflineSalesScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
