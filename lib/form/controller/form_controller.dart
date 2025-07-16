import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:stove_transaction/shared/services/googlesheetservices.dart';
import 'package:stove_transaction/form/services/form_services.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

class FormController extends GetxController {
  final GoogleSheetService googleSheetService = GoogleSheetService();
  final FormService formService = FormService();
  final isLoading = false.obs;
  final transactionIdController = TextEditingController();
  final salesDateController = TextEditingController();
  final contactPersonController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final surnameController = TextEditingController();
  final nameController = TextEditingController();
  final akaController = TextEditingController();
  final stateController = TextEditingController();
  final lgaController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final otherPhoneController = TextEditingController();
  final amountController = TextEditingController();
  final stoveSerialController = TextEditingController();
  final signatureController = TextEditingController();

  final placesAddressController = TextEditingController();

  RxList<String> partnerNames = <String>[].obs;
  RxList<String> stoveIds = <String>[].obs;

  final selectedState = ''.obs;
  final selectedLGA = ''.obs;
  // Add these variables to store address details
  String? street;
  String? city;
  String? state;
  String? country;
  double? latitude;
  double? longitude;

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  void fetchData() async {
    try {
      final data = await googleSheetService.fetchAllData();
      partnerNames
          .addAll(data.map((item) => item['partnerName']).whereType<String>());
      stoveIds.addAll(data.map((item) => item['stoveId']).whereType<String>());
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch data: $e');
    }
  }

  Future<void> handleSaleSubmit(
    File? stoveImage,
    File? agreedDocumentImage,
    String? signature,
  ) async {
    isLoading.value = true;
    String? stoveImagePublicId;
    String? stoveImageUrl;
    String? agreementImagePublicId;
    String? agreementImageUrl;

    if (stoveImage != null) {
      final stoveImageResponse =
          await formService.uploadImage(stoveImage, 'stoveImage');
      if (stoveImageResponse != null) {
        stoveImagePublicId = stoveImageResponse['public_id'];
        stoveImageUrl = stoveImageResponse['url'];
      }
    }

    if (agreedDocumentImage != null) {
      final agreementImageResponse =
          await formService.uploadImage(agreedDocumentImage, 'agreementImage');
      if (agreementImageResponse != null) {
        agreementImagePublicId = agreementImageResponse['public_id'];
        agreementImageUrl = agreementImageResponse['url'];
      }
    }

    final transactionData = {
      "transactionId": transactionIdController.text,
      "stoveSerialNo": stoveSerialController.text,
      "salesDate": salesDateController.text,
      "contactPerson": contactPersonController.text,
      "contactPhone": contactPhoneController.text,
      "endUserName": surnameController.text,
      "aka": akaController.text,
      "addressData": {
        "fullAddress": addressController.text,
        "street": street,
        "city": city,
        "state": state,
        "country": country,
        "latitude": latitude,
        "longitude": longitude
      },
      "stateBackup": lgaController.text,
      "lgaBackup": stateController.text,
      "phone": phoneController.text,
      "otherPhone": otherPhoneController.text,
      "partnerName": "Partner Corp",
      "amount":
          double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0,
      "signature": signature,
      "stoveImage": {
        "public_id": stoveImagePublicId,
        "url": stoveImageUrl,
      },
      "agreementImage": {
        "public_id": agreementImagePublicId,
        "url": agreementImageUrl,
      }
    };

    final response = await formService.submitTransaction(transactionData);
    if (response != null && [200, 201, 202].contains(response['code'])) {
      Get.snackbar(
        'Success',
        'Form submitted successfully!',
        colorText: AppColors.white,
        backgroundColor: Color.fromARGB(149, 35, 203, 1),
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to submit the form.',
        colorText: AppColors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    isLoading.value = false;
  }

  // Future<String?> _getSignature() async {
  //   if (signatureController.isNotEmpty) {
  //     final data = await signatureController.toPngBytes();
  //     return base64Encode(data!);
  //   }
  //   return null;
  // }
}
