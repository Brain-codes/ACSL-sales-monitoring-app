// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class SalesAgentDetailsScreen extends StatelessWidget {
  final SalesAgentModel salesAgent;

  const SalesAgentDetailsScreen({Key? key, required this.salesAgent})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar( title : "Sales Agent Details",
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${salesAgent.fullName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Location: ${salesAgent.email}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'ID: ${salesAgent.id}',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            // Add more details as needed
          ],
        ),
      ),
    );
  }
}
