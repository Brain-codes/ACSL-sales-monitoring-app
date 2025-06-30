// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/agent/sales_form/ui/sales_form_screen.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';

class SaleDetailsScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailsScreen({Key? key, required this.sale}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SalesController salesController = Get.find<SalesController>();

    return Scaffold(
      appBar: BaseAppBar(
        title: "Sale Details",
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'End-User: ${sale.userId}', // Assuming userId is end-user name for now
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: salesController.getStatusColor(sale.status),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    sale.status,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${sale.date.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Bonus: Status Banners
            if (sale.status == 'Assigned')
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This sale has not been completed by the agent yet.',
                        style: TextStyle(color: Colors.orange, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (sale.agentName == null || sale.agentName!.isEmpty)
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No agent has been assigned yet. Please assign one.',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            // Details Section
            _buildDetailsCard(
              context,
              title: 'End-User Information',
              children: [
                _buildDetailRow('Full Name:', sale.userId), // Placeholder
                _buildDetailRow(
                    'Address:', '123 Main St, Anytown'), // Placeholder
                _buildDetailRow('Phone:', '555-123-4567'), // Placeholder
              ],
            ),
            _buildDetailsCard(
              context,
              title: 'Stove Details',
              children: [
                _buildDetailRow(
                    'Stove ID:', sale.product), // Assuming product is stove ID
              ],
            ),
            _buildDetailsCard(
              context,
              title: 'Geo-location',
              children: [
                _buildDetailRow('Coordinates:',
                    'Lat: 34.0522, Lon: -118.2437'), // Placeholder
                _buildDetailRow('Origin Method:', 'GPS'), // Placeholder
              ],
            ),
            _buildDetailsCard(
              context,
              title: 'Assigned Agent',
              children: [
                _buildDetailRow('Agent Name:', sale.agentName ?? 'N/A'),
              ],
            ),
            _buildDetailsCard(
              context,
              title: 'Attached Media',
              children: [
                // Placeholder for images and signature
                Text('Images: (Preview not implemented)'),
                Text('Signature: (Preview not implemented)'),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(context, salesController, sale),
    );
  }

  Widget _buildDetailsCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextThemes(context).getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, SalesController salesController, Sale sale) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            text: 'Edit Sale',
            onPressed: () {
              Get.to(() => SalesFormScreen(), arguments: {
                'isEditMode': true,
                'saleId': sale.id,
              });
            },
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            text: 'Assign to Agent',
            onPressed: () {
              _showAssignAgentBottomSheet(context, salesController, sale);
            },
          ),
        ],
      ),
    );
  }

  void _showAssignAgentBottomSheet(
      BuildContext context, SalesController salesController, Sale sale) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Assign Sale to Agent',
                style: TextThemes(context).getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (salesController.salesAgents.isEmpty) {
                  return Center(
                    child: Text('No agents available to assign at this time.'),
                  );
                }
                return ListView.builder(
                  itemCount: salesController.salesAgents.length,
                  itemBuilder: (context, index) {
                    final agent = salesController.salesAgents[index];
                    return ListTile(
                      title: Text(agent.name),
                      subtitle: Text(agent.location),
                      trailing: ElevatedButton(
                        onPressed: () {
                          salesController.assignSale(sale.id, agent.name);
                          Get.back(); // Close bottom sheet
                          Get.snackbar(
                            'Success',
                            'Sale assigned to ${agent.name} successfully.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColors.primaryColor,
                            colorText: Colors.white,
                          );
                        },
                        child: Text('Assign'),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
