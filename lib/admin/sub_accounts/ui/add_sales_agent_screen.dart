// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/add_sales_agent_controller.dart';
import 'package:stove_transaction/shared/widgets/custom_textfield.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
class AddSalesAgentScreen extends StatelessWidget {
  final AddSalesAgentController controller = Get.put(AddSalesAgentController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar( title: "Add New Sales Agent",),
        
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Agent Name',
                hintText: 'Enter agent name',
                controller: controller.nameController,
                inputType: TextInputType.text,
                validator: controller.validateName,
              ),
              const SizedBox(height: 16.0),
              CustomTextField(
                label: 'Location',
                hintText: 'Enter agent location',
                controller: controller.locationController,
                inputType: TextInputType.text,
                validator: controller.validateLocation,
              ),
              const SizedBox(height: 24.0),
              Obx(
                () => PrimaryButton(
                  text: 'Add Agent',
                  onPressed: () => controller.addAgent(),
                  isLoading: controller.isLoading.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
