// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart'; // Add shimmer package
import 'package:stove_transaction/admin/dashboard/widgets/sales_agent_item.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/manage_sales_agents_controller.dart';
import 'package:stove_transaction/admin/sub_accounts/ui/sales_agent_details_screen.dart';
import 'package:stove_transaction/admin/sub_accounts/ui/add_sales_agent_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class ManageSalesAgentsScreen extends StatefulWidget {
  const ManageSalesAgentsScreen({super.key});

  @override
  State<ManageSalesAgentsScreen> createState() =>
      _ManageSalesAgentsScreenState();
}

class _ManageSalesAgentsScreenState extends State<ManageSalesAgentsScreen> {
  final ManageSalesAgentsController controller =
      Get.put(ManageSalesAgentsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(title: "Manage Sales Agents"),
      body: Obx(() {
        if (controller.isLoading.value) {
          // Shimmer loading state
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: ListView.builder(
              itemCount: 5, // Mock shimmer items
              itemBuilder: (context, index) {
                return Shimmer.fromColors(
                  baseColor: AppColors.lightGrey,
                  highlightColor: AppColors.borderGrey,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.lightGrey,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 15,
                                width: double.infinity,
                                color: AppColors.lightGrey,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 15,
                                width: 100,
                                color: AppColors.lightGrey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        } else if (controller.salesAgents.isEmpty) {
          return const Center(child: Text('No sales agents found.'));
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            child: ListView.builder(
              itemCount: controller.salesAgents.length,
              itemBuilder: (context, index) {
                final salesAgent = controller.salesAgents[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Get.to(() => SalesAgentDetailsScreen(
                            salesAgent: salesAgent,
                          ));
                    },
                    child: SalesAgentItem(
                      profileImage: salesAgent.fullName ?? '',
                      name: salesAgent.fullName ?? '',
                      email: salesAgent.email ?? '',
                      position: salesAgent.role ?? '',
                    ),
                  ),
                );
              },
            ),
          );
        }
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => AddSalesAgentScreen());
        },
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        shape: CircleBorder(
          side: BorderSide(color: Colors.grey, width: 1),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
