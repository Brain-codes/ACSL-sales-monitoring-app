import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/admin/sales/controller/update_sale_controller.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

/// Helper class for update sale form operations
class UpdateSaleHelper {
  static Future<String?> getSignature(
      SignatureController signatureController) async {
    if (signatureController.isNotEmpty) {
      final data = await signatureController.toPngBytes();
      return base64Encode(data!);
    }
    return null;
  }

  static Future<void> submitForm({
    required UpdateSaleController controller,
    required GlobalKey<FormState> formKey,
    File? stoveImage,
    File? agreedDocumentImage,
    required SignatureController signatureController,
  }) async {
    // Set required fields
    controller.stateController.text = controller.selectedState.value;
    controller.lgaController.text = controller.selectedLGA.value;

    String? signature = await getSignature(signatureController);

    if (formKey.currentState!.validate()) {
      showInfoToast(
        title: 'Updating',
        message: 'Updating sale data...',
      );

      await controller.handleSaleUpdate(
          stoveImage, agreedDocumentImage, signature);
    } else {
      showInfoToast(
        title: 'Validation Error',
        message: 'Please ensure all fields are valid.',
      );
    }
  }
}
