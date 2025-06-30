// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/manage_sales_agents_controller.dart';
import 'package:stove_transaction/admin/sub_accounts/ui/sales_agent_details_screen.dart';
import 'package:stove_transaction/admin/sub_accounts/ui/add_sales_agent_screen.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
class ManageSalesAgentsScreen extends StatelessWidget {
  const ManageSalesAgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ManageSalesAgentsController controller =
        Get.put(ManageSalesAgentsController());

    return Scaffold(
      appBar: BaseAppBar( title : 
      "Manage Sales Agents"
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else if (controller.salesAgents.isEmpty) {
          return const Center(child: Text('No sales agents found.'));
        } else {
          return ListView.builder(
            itemCount: controller.salesAgents.length,
            itemBuilder: (context, index) {
              final salesAgent = controller.salesAgents[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  title: Text(salesAgent.name),
                  subtitle: Text(salesAgent.location),
                  trailing: Text('ID: ${salesAgent.id}'),
                  onTap: () {
                    Get.to(
                        () => SalesAgentDetailsScreen(salesAgent: salesAgent));
                  },
                ),
              );
            },
          );
        }
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => AddSalesAgentScreen());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
