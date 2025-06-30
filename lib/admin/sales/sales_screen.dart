import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/admin/sales/ui/sales_list_tile.dart';
import 'package:stove_transaction/agent/sales_form/ui/sales_form_screen.dart';
import 'package:stove_transaction/admin/sales/ui/sale_details_screen.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SalesController controller = Get.put(SalesController());

    return Scaffold(
      appBar: BaseAppBar(
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
          return ListView.builder(
            itemCount: controller.agentSales.length,
            itemBuilder: (context, index) {
              final sale = controller.agentSales[index];
              return SalesListTile(
                sale: sale,
                onTap: () {
                  if (sale.status == 'Assigned') {
                    Get.to(() =>
                        SalesFormScreen()); // Navigate to SalesFormScreen for completion
                  } else {
                    Get.snackbar('Info', 'This sale is ${sale.status}');
                  }
                },
              );
            },
          );
        } else {
          return const Center(child: Text('Unknown Role'));
        }
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() =>
              SalesFormScreen()); // Navigate to SalesFormScreen for new sale
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
