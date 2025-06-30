import 'package:get/get.dart';
import 'package:flutter/material.dart';

class AddSalesAgentController extends GetxController {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  var isLoading = false.obs;

  @override
  void onClose() {
    nameController.dispose();
    locationController.dispose();
    super.onClose();
  }

  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Agent Name cannot be empty';
    }
    return null;
  }

  String? validateLocation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Location cannot be empty';
    }
    return null;
  }

  void addAgent() async {
    if (formKey.currentState?.validate() ?? false) {
      isLoading.value = true;
      // Simulate API call or data submission
      await Future.delayed(Duration(seconds: 2));
      Get.snackbar(
        'Success',
        'Agent ${nameController.text} from ${locationController.text} added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      isLoading.value = false;
      Get.back(); // Go back to previous screen after adding
    }
  }
}
