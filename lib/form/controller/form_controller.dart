// ignore_for_file: unnecessary_null_comparison

import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/image_compression_service.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/admin/sales/controller/offline_sales_controller.dart';
import 'package:stove_transaction/shared/services/googlesheetservices.dart';
import 'package:stove_transaction/form/services/form_services.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class FormController extends GetxController {
  final GoogleSheetService googleSheetService = GoogleSheetService();
  final FormService _apiService = FormService(SupabaseService());
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();
  final isLoading = false.obs;
  final submissionStatus = ''.obs;
  final isOfflineMode = false.obs;
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
    submissionStatus.value = 'Starting submission...';
    logger.d("Sale submission started.");

    try {
      // ALWAYS save offline first (offline-first approach)
      await _saveOffline(stoveImage, agreedDocumentImage, signature);

      // Then try to sync immediately if online (optional)
      final isOnline = await _checkConnectivity();
      if (isOnline && !isOfflineMode.value) {
        submissionStatus.value = 'Attempting immediate sync...';
        logger.d("Attempting immediate sync after offline save...");

        try {
          // Get the last saved offline sale and try to sync it
          final offlineSales = _offlineStorage.getOfflineSales();
          if (offlineSales.isNotEmpty) {
            final lastSale = offlineSales.last;
            final offlineId = lastSale['offline_id'];

            // Try to sync this specific sale immediately
            await _submitOnlineFromOffline(lastSale);
            await _offlineStorage.markSaleAsSynced(offlineId, null);

            submissionStatus.value = 'Saved and synced successfully!';
            showSuccessToast(
              title: 'Success',
              message: 'Sale saved and synced successfully!',
            );
          }
        } catch (e) {
          logger.w('Immediate sync failed, sale saved offline: $e');
          submissionStatus.value = 'Saved offline successfully!';
          showSuccessToast(
            title: 'Saved Offline',
            message: 'Sale saved locally and will sync when online',
          );
        }
      } else {
        submissionStatus.value = 'Saved offline successfully!';
        showSuccessToast(
          title: 'Saved Offline',
          message: 'Sale saved locally and will sync when online',
        );
      }
    } catch (e) {
      logger.e('Sale submission error: $e');
      submissionStatus.value = 'Submission failed';
      showErrorToast(
        title: 'Submission Failed',
        message: 'Failed to save sale: $e',
      );
    } finally {
      isLoading.value = false;
      submissionStatus.value = '';
    }
  }

  /// Check internet connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Save sale offline
  Future<void> _saveOffline(
    File? stoveImage,
    File? agreedDocumentImage,
    String? signature,
  ) async {
    submissionStatus.value = 'Saving offline...';
    logger.d("Saving sale offline...");

    String? stoveImagePath;
    String? agreementImagePath;

    // Save images locally
    if (stoveImage != null) {
      stoveImagePath =
          await _offlineStorage.saveOfflineImage(stoveImage, 'stove');
    }

    if (agreedDocumentImage != null) {
      agreementImagePath = await _offlineStorage.saveOfflineImage(
          agreedDocumentImage, 'agreement');
    }

    // Prepare offline sale data
    final offlineSaleData = {
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
      "partnerName": Get.find<SessionManager>().organizationName,
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
      "stove_image_path": stoveImagePath,
      "agreement_image_path": agreementImagePath,
    };

    final success = await _offlineStorage.saveOfflineSale(offlineSaleData);

    if (success) {
      submissionStatus.value = 'Saved offline successfully!';
      logger.d("Sale saved offline successfully.");
      showSuccessToast(
        title: 'Saved Offline',
        message: 'Sale saved locally and will sync when online',
      );

      // Get the offline sales controller and refresh data
      if (Get.isRegistered<OfflineSalesController>()) {
        final offlineController = Get.find<OfflineSalesController>();
        await offlineController.refreshOfflineData();
      }

      _clearForm();
    } else {
      throw Exception('Failed to save offline');
    }
  }

  /// Submit sale online
  Future<void> _submitOnline(
    File? stoveImage,
    File? agreedDocumentImage,
    String? signature,
  ) async {
    submissionStatus.value = 'Submitting online...';
    logger.d("Submitting sale online...");

    String? stoveImagePublicId;
    String? agreementImagePublicId;

    // Upload stove image
    if (stoveImage != null) {
      submissionStatus.value = 'Compressing stove image...';
      logger.d("Compressing and uploading stove image...");

      // Compress the image with optimal settings
      final compressedStoveImage =
          await _compressImageOptimally(stoveImage, 'stove');

      if (compressedStoveImage != null) {
        submissionStatus.value = 'Uploading stove image...';
        final stoveImageResponse =
            await _apiService.uploadImage(compressedStoveImage, 'stoveImage');
        if (stoveImageResponse != null &&
            stoveImageResponse.success &&
            stoveImageResponse.data?.id != null) {
          stoveImagePublicId = stoveImageResponse.data?.id;
          logger
              .d("Stove image uploaded successfully. ID: $stoveImagePublicId");
        } else {
          logger.e("Failed to upload stove image.");
          logger.e("Response: ${stoveImageResponse.message}");
        }
      } else {
        logger.e("Failed to compress stove image.");
      }
    } else {
      logger.d("No stove image provided.");
    }

    // Upload agreement image
    if (agreedDocumentImage != null) {
      submissionStatus.value = 'Compressing agreement document...';
      logger.d("Compressing and uploading agreement image...");

      // Compress the image with optimal settings
      final compressedAgreementImage =
          await _compressImageOptimally(agreedDocumentImage, 'agreement');

      if (compressedAgreementImage != null) {
        submissionStatus.value = 'Uploading agreement document...';
        final agreementImageResponse = await _apiService.uploadImage(
            compressedAgreementImage, 'agreementImage');
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
        logger.e("Failed to compress agreement image.");
      }
    } else {
      logger.d("No agreement image provided.");
    }

    // Prepare transaction data
    submissionStatus.value = 'Preparing transaction data...';
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
      "partnerName": Get.find<SessionManager>().organizationName,
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
    submissionStatus.value = 'Finalizing submission...';
    logger.d("Sending transaction data to the server...");
    final response = await _apiService.createSales(transactionData);
    if (response.code == 200) {
      submissionStatus.value = 'Submission successful!';
      logger.d("Sale submission successful.");
      showSuccessToast(
        title: 'Success',
        message: 'Form submitted successfully!',
      );
      _clearForm();
    } else {
      submissionStatus.value = 'Submission failed';
      logger.e("Sale submission failed. Error: ${response.message}");
      throw Exception(response.message ?? 'Online submission failed');
    }
  }

  /// Submit offline sale online (for immediate sync)
  Future<void> _submitOnlineFromOffline(
      Map<String, dynamic> offlineSaleData) async {
    submissionStatus.value = 'Syncing offline sale...';
    logger.d("Syncing offline sale to server...");

    String? stoveImagePublicId;
    String? agreementImagePublicId;

    // Upload stove image if available
    if (offlineSaleData['stove_image_path'] != null) {
      final stoveImageFile = File(offlineSaleData['stove_image_path']);
      if (stoveImageFile.existsSync()) {
        submissionStatus.value = 'Uploading stove image...';

        final compressedStoveImage =
            await _compressImageOptimally(stoveImageFile, 'stove');

        if (compressedStoveImage != null) {
          final stoveImageResponse =
              await _apiService.uploadImage(compressedStoveImage, 'stoveImage');
          if (stoveImageResponse != null &&
              stoveImageResponse.success &&
              stoveImageResponse.data?.id != null) {
            stoveImagePublicId = stoveImageResponse.data?.id;
          }
        }
      }
    }

    // Upload agreement image if available
    if (offlineSaleData['agreement_image_path'] != null) {
      final agreementImageFile = File(offlineSaleData['agreement_image_path']);
      if (agreementImageFile.existsSync()) {
        submissionStatus.value = 'Uploading agreement document...';

        final compressedAgreementImage =
            await _compressImageOptimally(agreementImageFile, 'agreement');

        if (compressedAgreementImage != null) {
          final agreementImageResponse = await _apiService.uploadImage(
              compressedAgreementImage, 'agreementImage');
          if (agreementImageResponse != null &&
              agreementImageResponse.success &&
              agreementImageResponse.data?.id != null) {
            agreementImagePublicId = agreementImageResponse.data?.id;
          }
        }
      }
    }

    // Prepare transaction data from offline sale
    final transactionData = {
      "transactionId": offlineSaleData["transactionId"],
      "stoveSerialNo": offlineSaleData["stoveSerialNo"],
      "salesDate": offlineSaleData["salesDate"],
      "contactPerson": offlineSaleData["contactPerson"],
      "contactPhone": offlineSaleData["contactPhone"],
      "endUserName": offlineSaleData["endUserName"],
      "aka": offlineSaleData["aka"],
      "stateBackup": offlineSaleData["stateBackup"],
      "lgaBackup": offlineSaleData["lgaBackup"],
      "phone": offlineSaleData["phone"],
      "otherPhone": offlineSaleData["otherPhone"],
      "partnerName": offlineSaleData["partnerName"],
      "amount": offlineSaleData["amount"],
      "signature": offlineSaleData["signature"],
      "addressData": offlineSaleData["addressData"],
      "stoveImageId": stoveImagePublicId,
      "agreementImageId": agreementImagePublicId,
    };

    // Call the service to create the sale
    submissionStatus.value = 'Finalizing sync...';
    final response = await _apiService.createSales(transactionData);
    if (response.code == 200) {
      submissionStatus.value = 'Sync successful!';
      logger.d("Offline sale sync successful.");
    } else {
      throw Exception(
          response.message.isNotEmpty ? response.message : 'Sync failed');
    }
  }

  /// Clear form after successful submission
  void _clearForm() {
    transactionIdController.clear();
    salesDateController.clear();
    contactPersonController.clear();
    contactPhoneController.clear();
    surnameController.clear();
    nameController.clear();
    akaController.clear();
    stateController.clear();
    lgaController.clear();
    addressController.clear();
    phoneController.clear();
    otherPhoneController.clear();
    amountController.clear();
    stoveSerialController.clear();
    signatureController.clear();
    placesAddressController.clear();

    // Reset address details
    street = null;
    city = null;
    state = null;
    country = null;
    latitude = null;
    longitude = null;
  }

  /// Toggle offline mode
  void toggleOfflineMode() {
    isOfflineMode.value = !isOfflineMode.value;
    logger.d('Offline mode: ${isOfflineMode.value}');
  }

  /// Compresses an image with optimal settings based on file size
  Future<File?> _compressImageOptimally(
      File imageFile, String imageType) async {
    try {
      final fileSize = await imageFile.length();
      final optimalSettings =
          ImageCompressionService.getOptimalSettings(fileSize);

      logger.d(
          "Compressing $imageType image (${(fileSize / 1024).toStringAsFixed(2)} KB) with optimal settings: $optimalSettings");

      return await ImageCompressionService.compressImage(
        imageFile,
        quality: optimalSettings['quality']!,
        minWidth: optimalSettings['minWidth']!,
        minHeight: optimalSettings['minHeight']!,
      );
    } catch (e) {
      logger.e("Error during optimal compression for $imageType: $e");
      return imageFile; // Return original if compression fails
    }
  }

  // Future<String?> _getSignature() async {
  //   if (signatureController.isNotEmpty) {
  //     final data = await signatureController.toPngBytes();
  //     return base64Encode(data!);
  //   }
  //   return null;
  // }
}
