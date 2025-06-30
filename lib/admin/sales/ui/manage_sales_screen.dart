// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/manage_sales_controller.dart';
import 'package:stove_transaction/admin/sales/ui/sale_details_screen.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class ManageSalesScreen extends StatelessWidget {
  const ManageSalesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ManageSalesController controller = Get.put(ManageSalesController());

    return Scaffold(
      appBar: BaseAppBar( title: "Manage Sales",
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else if (controller.sales.isEmpty) {
          return const Center(child: Text('No sales found.'));
        } else {
          return ListView.builder(
            itemCount: controller.sales.length,
            itemBuilder: (context, index) {
              final sale = controller.sales[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  title: Text(sale.product),
                  subtitle: Text('Amount: \$${sale.amount.toStringAsFixed(2)}'),
                  trailing: Text(sale.date.toLocal().toString().split(' ')[0]),
                  onTap: () {
                    Get.to(() => SaleDetailsScreen(sale: sale));
                  },
                ),
              );
            },
          );
        }
      }),
    );
  }
}
