// ignore_for_file: unnecessary_null_comparison

import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/services/googlesheetservices.dart';
import 'package:stove_transaction/form/services/form_services.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class FormController extends GetxController {
  final GoogleSheetService googleSheetService = GoogleSheetService();
  final FormService _apiService = FormService(SupabaseService());
  final SessionManager _sessionManager = Get.find<SessionManager>();
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
  Logger logger = Logger();
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
      logger.d('Partner Names: $partnerNames');
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
    logger.d("Sale submission started.");

    String? stoveImagePublicId;
    String? agreementImagePublicId;

    // Upload stove image
    if (stoveImage != null) {
      logger.d("Uploading stove image...");
      final stoveImageResponse =
          await _apiService.uploadImage(stoveImage, 'stoveImage');
      if (stoveImageResponse != null &&
          stoveImageResponse.success &&
          stoveImageResponse.data?.id != null) {
        stoveImagePublicId = stoveImageResponse.data?.id;
        logger.d("Stove image uploaded successfully. ID: $stoveImagePublicId");
      } else {
        logger.e("Failed to upload stove image.");
      }
    } else {
      logger.d("No stove image provided.");
    }

    // Upload agreement image
    if (agreedDocumentImage != null) {
      logger.d("Uploading agreement image...");
      final agreementImageResponse =
          await _apiService.uploadImage(agreedDocumentImage, 'agreementImage');
      if (agreementImageResponse != null &&
          agreementImageResponse.success &&
          agreementImageResponse.data?.id != null) {
        agreementImagePublicId = agreementImageResponse.data?.id;
        logger.d(
            "Agreement image uploaded successfully. ID: $agreementImagePublicId");
      } else {
        logger.e("Failed to upload agreement image.");
      }
    } else {
      logger.d("No agreement image provided.");
    }

    // Prepare transaction data
    logger.d("Preparing transaction data...");
    final transactionData = {
      "transactionId": transactionIdController.text,
      "stoveSerialNo": stoveSerialController.text,
      "salesDate": salesDateController.text,
      "contactPerson": contactPersonController.text,
      "contactPhone": contactPhoneController.text,
      "endUserName": surnameController.text,
      "aka": akaController.text,
      "stateBackup": stateController.text,
      "lgaBackup": lgaController.text,
      "phone": phoneController.text,
      "otherPhone": otherPhoneController.text,
      "partnerName": "Partner Corp",
      "amount":
          double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0,
      "signature": signature,
      "addressData": {
        "fullAddress": addressController.text,
        "street": street,
        "city": city,
        "state": state,
        "country": country,
        "latitude": latitude,
        "longitude": longitude,
      },
      "stoveImageId": stoveImagePublicId,
      "agreementImageId": agreementImagePublicId,
    };
    logger.d("Transaction data prepared: $transactionData");

    // Call the service to create the sale
    logger.d("Sending transaction data to the server...");
    final response = await _apiService.createSales(transactionData);
    if (response.code == 200) {
      logger.d("Sale submission successful.");
      showSuccessToast(
        title: 'Success',
        message: 'Form submitted successfully!',
      );
    } else {
      logger.e(
          "Sale submission failed. Error: ${response.message ?? 'Unknown error'}");
      showInfoToast(
        title: 'Sales Transaction Failed',
        message: response.message ?? 'Failed to submit the form.',
      );
    }
    isLoading.value = false;
    logger.d("Sale submission process completed.");
  }

  // Future<String?> _getSignature() async {
  //   if (signatureController.isNotEmpty) {
  //     final data = await signatureController.toPngBytes();
  //     return base64Encode(data!);
  //   }
  //   return null;
  // }
}
