import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/form/controller/form_controller.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

/// Helper class for form-related operations
class UserFormHelper {
  static String generateTransactionId() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  static Future<String?> getSignature(
      SignatureController signatureController) async {
    if (signatureController.isNotEmpty) {
      final data = await signatureController.toPngBytes();
      return base64Encode(data!);
    }
    return null;
  }

  static Future<void> submitForm({
    required FormController controller,
    required GlobalKey<FormState> formKey,
    required String transactionId,
    File? stoveImage,
    File? agreedDocumentImage,
    required SignatureController signatureController,
    required VoidCallback onClearForm,
  }) async {
    // Set required fields
    controller.transactionIdController.text = transactionId;
    controller.stateController.text = controller.selectedState.value;
    controller.lgaController.text = controller.selectedLGA.value;

    String? signature = await getSignature(signatureController);

    if (formKey.currentState!.validate()) {
      showInfoToast(
        title: 'Loading',
        message: 'Submitting your form...',
      );

      await controller.handleSaleSubmit(
          stoveImage, agreedDocumentImage, signature);
      onClearForm();
    } else {
      showInfoToast(
        title: 'Sales Submition',
        message: 'Please ensure all fields are valid.',
      );
    }
  }

  static void clearForm({
    required FormController controller,
    required GlobalKey<FormState> formKey,
    required SignatureController signatureController,
    required Function(String) onTransactionIdGenerated,
    required Function() onImagesCleared,
  }) {
    formKey.currentState!.reset();
    onTransactionIdGenerated(generateTransactionId());
    controller.selectedState.value = '';
    controller.selectedLGA.value = '';
    onImagesCleared();
    controller.street = null;
    controller.city = null;
    controller.state = null;
    controller.country = null;
    controller.latitude = null;
    controller.longitude = null;
    controller.transactionIdController.clear();
    controller.stateController.clear();
    controller.lgaController.clear();
    controller.salesDateController.clear();
    controller.contactPersonController.clear();
    controller.contactPhoneController.clear();
    controller.surnameController.clear();
    controller.akaController.clear();
    controller.addressController.clear();
    controller.phoneController.clear();
    controller.otherPhoneController.clear();
    controller.amountController.clear();
    controller.stoveSerialController.clear();
    signatureController.clear();
  }
}
