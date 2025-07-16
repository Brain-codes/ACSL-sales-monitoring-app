// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/form/ui/user_form.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/admin/sales/ui/sales_list_tile.dart';
import 'package:stove_transaction/agent/sales_form/ui/sales_form_screen.dart';
import 'package:stove_transaction/admin/sales/ui/sale_details_screen.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';

class SalesScreen extends StatelessWidget {
  final bool showBackArrow;
  const SalesScreen({
    Key? key,
    this.showBackArrow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SalesController controller = Get.put(SalesController());
    final SessionManager _sessionManager = Get.find<SessionManager>();

    return Scaffold(
      appBar: !controller.isAdmin.value
          ? null
          : BaseAppBar(
              showBackButton: showBackArrow,
              title: controller.isAdmin.value ? "All Sales" : "My Sales",
            ),
      body: Obx(() {
        if (controller.isAdmin.value) {
          return ListView.builder(
            itemCount: controller.adminSales.length,
            itemBuilder: (context, index) {
              final sale = controller.adminSales[index];
              return SalesListTile(
                sale: sale,
                onTap: () {
                  Get.to(() => SaleDetailsScreen(sale: sale));
                },
              );
            },
          );
        } else if (controller.isAgent.value) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hi, ${_sessionManager.userName ?? 'Ahmed'}',
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 25,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 156, 55, 0),
                          borderRadius: BorderRadius.circular(1000),
                          border: Border.all(
                            color: AppColors.white,
                            width: 0.2,
                          ),
                        ),
                        child: Text(
                          'AU',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Text(
                    'Sales Data',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 15,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  Expanded(
                    // Added Expanded widget here
                    child: ListView.builder(
                      itemCount: controller.agentSales.length,
                      itemBuilder: (context, index) {
                        final sale = controller.agentSales[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 15,
                          ),
                          child: SalesListTile(
                            sale: sale,
                            onTap: () {
                              // if (sale.status == 'Assigned') {
                              //   Get.to(() =>
                              //       SalesFormScreen()); // Navigate to SalesFormScreen for completion
                              // } else {
                              //   showInfoToast(
                              //     message: 'This sale is ${sale.status}',
                              //     title: 'Info',
                              //   );
                              // }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const Center(child: Text('Unknown Role'));
        }
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(
            () =>
                // SalesFormScreen()
                UserForm(),
          ); // Navigate to SalesFormScreen for new sale
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
