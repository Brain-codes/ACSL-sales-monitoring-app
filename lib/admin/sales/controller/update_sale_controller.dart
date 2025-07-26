import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/services/sale_api_service.dart';
import 'package:stove_transaction/admin/sales/controller/manage_sales_controller.dart';
import 'package:stove_transaction/admin/sales/controller/offline_sales_controller.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/image_compression_service.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/shared/services/googlesheetservices.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class UpdateSaleController extends GetxController {
  final GoogleSheetService googleSheetService = GoogleSheetService();
  final SaleApiService _apiService = SaleApiService(SupabaseService());
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();
  final isLoading = false.obs;
  final submissionStatus = ''.obs;
  final isOfflineMode = false.obs;
  final transactionIdController = TextEditingController();
  final salesDateController = TextEditingController();
  final contactPersonController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final endUserName = TextEditingController();
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

  // Store the original sale data and ID
  late SaleModel originalSale;
  String? saleId;

  @override
  void onInit() {
    super.onInit();
    fetchData();
    // Get sale data from arguments
    if (Get.arguments != null && Get.arguments['sale'] != null) {
      // Clear all previous data first
      clearFormData();

      originalSale = Get.arguments['sale'] as SaleModel;
      saleId = originalSale.id;
      populateFormWithSaleData();
    }
  }

  // Method to clear all form data before loading new sale data
  void clearFormData() {
    transactionIdController.clear();
    salesDateController.clear();
    contactPersonController.clear();
    contactPhoneController.clear();
    endUserName.clear();
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

    // Clear reactive variables
    selectedState.value = '';
    selectedLGA.value = '';

    // Clear address details
    street = null;
    city = null;
    state = null;
    country = null;
    latitude = null;
    longitude = null;

    // Reset loading states
    isLoading.value = false;
    submissionStatus.value = '';
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

  void populateFormWithSaleData() {
    transactionIdController.text = originalSale.transactionId ?? '';
    salesDateController.text =
        originalSale.salesDate?.toIso8601String().split('T').first ?? '';
    contactPersonController.text = originalSale.contactPerson ?? '';
    contactPhoneController.text = originalSale.contactPhone ?? '';
    endUserName.text = originalSale.endUserName ?? '';
    akaController.text = originalSale.aka ?? '';
    stateController.text = originalSale.stateBackup ?? '';
    lgaController.text = originalSale.lgaBackup ?? '';
    addressController.text = originalSale.address?.fullAddress ?? '';
    phoneController.text = originalSale.phone ?? '';
    otherPhoneController.text = originalSale.otherPhone ?? '';
    amountController.text = originalSale.amount.toString();
    stoveSerialController.text = originalSale.stoveSerialNo ?? '';

    // Set selected values
    selectedState.value = originalSale.stateBackup ?? '';
    selectedLGA.value = originalSale.lgaBackup ?? '';

    // Set address details
    street = originalSale.address?.street;
    city = originalSale.address?.city;
    state = originalSale.address?.state;
    country = originalSale.address?.country;
    latitude = originalSale.address?.latitude;
    longitude = originalSale.address?.longitude;
  }

  // Method to update with new sale data (called when navigating to update a different sale)
  void updateSaleData(SaleModel newSale) {
    // Clear previous data
    clearFormData();

    // Set new sale data
    originalSale = newSale;
    saleId = newSale.id;

    // Populate form with new data
    populateFormWithSaleData();
  }

  Future<void> handleSaleUpdate(
    File? stoveImage,
    File? agreedDocumentImage,
    String? signature,
  ) async {
    if (saleId == null) {
      showErrorToast(message: 'Sale ID not found');
      return;
    }

    isLoading.value = true;
    submissionStatus.value = 'Starting update...';
    logger.d("Sale update started - Offline-first approach.");

    try {
      // ALWAYS save offline edit first (offline-first approach)
      await _saveOfflineEdit(stoveImage, agreedDocumentImage, signature);

      // Then try to sync immediately if online (optional)
      final isOnline = await _checkConnectivity();
      if (isOnline && !isOfflineMode.value) {
        submissionStatus.value = 'Attempting immediate sync...';
        logger.d("Attempting immediate sync after offline save...");

        try {
          // Get the last saved offline edit and try to sync it
          final offlineEdits = _offlineStorage.getOfflineSaleEdits();
          if (offlineEdits.isNotEmpty) {
            final lastEdit = offlineEdits.last;
            final editId = lastEdit['edit_id'];

            // Try to sync this specific edit immediately
            await _submitOnlineEditFromOffline(lastEdit);
            await _offlineStorage.markSaleEditAsSynced(editId);

            submissionStatus.value = 'Updated and synced successfully!';
            showSuccessToast(
              title: 'Success',
              message: 'Sale updated and synced successfully!',
            );
          }
        } catch (e) {
          logger.w('Immediate sync failed, edit saved offline: $e');
          submissionStatus.value = 'Updated offline successfully!';
          showSuccessToast(
            title: 'Updated Offline',
            message: 'Changes saved locally and will sync when online',
          );
        }
      } else {
        submissionStatus.value = 'Updated offline successfully!';
        showSuccessToast(
          title: 'Updated Offline',
          message: 'Changes saved locally and will sync when online',
        );
      }

      // Refresh the sales list
      try {
        final ManageSalesController manageSalesController =
            Get.find<ManageSalesController>();
        manageSalesController.fetchSales(refresh: true);
      } catch (e) {
        logger.d("ManageSalesController not found, continuing without refresh");
      }

      Get.back(); // Go back to previous screen
    } catch (e) {
      logger.e('Sale update error: $e');
      submissionStatus.value = 'Update failed';
      showErrorToast(
        title: 'Update Failed',
        message: 'Failed to update sale: $e',
      );
    } finally {
      isLoading.value = false;
      submissionStatus.value = '';
    }
  }

  /// Save sale edit offline
  Future<void> _saveOfflineEdit(
    File? stoveImage,
    File? agreedDocumentImage,
    String? signature,
  ) async {
    submissionStatus.value = 'Saving changes offline...';
    logger.d("Saving sale edit offline...");

    String? stoveImagePath;
    String? agreementImagePath;

    // Save images locally if provided
    if (stoveImage != null) {
      stoveImagePath =
          await _offlineStorage.saveOfflineImage(stoveImage, 'stove');
    }

    if (agreedDocumentImage != null) {
      agreementImagePath = await _offlineStorage.saveOfflineImage(
          agreedDocumentImage, 'agreement');
    }

    // Prepare offline edit data
    final offlineEditData = {
      "transactionId": transactionIdController.text,
      "stoveSerialNo": stoveSerialController.text,
      "salesDate": salesDateController.text,
      "contactPerson": contactPersonController.text,
      "contactPhone": contactPhoneController.text,
      "endUserName": endUserName.text,
      "aka": akaController.text,
      "stateBackup": selectedState.value,
      "lgaBackup": selectedLGA.value,
      "phone": phoneController.text,
      "otherPhone": otherPhoneController.text,
      "partnerName": "Updated Partner",
      "amount": double.tryParse(amountController.text) ?? 0.0,
      "signature": signature ?? originalSale.signature,
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
      // Keep original image IDs if no new images provided
      "original_stove_image_id": originalSale.stoveImageId?.id,
      "original_agreement_image_id": originalSale.agreementImageId?.id,
    };

    final success =
        await _offlineStorage.saveOfflineSaleEdit(saleId!, offlineEditData);

    if (success) {
      submissionStatus.value = 'Changes saved offline successfully!';
      logger.d("Sale edit saved offline successfully.");

      // Get the offline sales controller and refresh data
      if (Get.isRegistered<OfflineSalesController>()) {
        final offlineController = Get.find<OfflineSalesController>();
        await offlineController.refreshOfflineData();
      }
    } else {
      throw Exception('Failed to save edit offline');
    }
  }

  /// Submit offline edit online (for immediate sync)
  Future<void> _submitOnlineEditFromOffline(
      Map<String, dynamic> offlineEditData) async {
    submissionStatus.value = 'Syncing offline edit...';
    logger.d("Syncing offline edit to server...");

    String? stoveImagePublicId;
    String? agreementImagePublicId;

    // Upload stove image if available
    if (offlineEditData['stove_image_path'] != null) {
      final stoveImageFile = File(offlineEditData['stove_image_path']);
      if (stoveImageFile.existsSync()) {
        submissionStatus.value = 'Uploading stove image...';

        final compressedStoveImage =
            await _compressImageOptimally(stoveImageFile, 'stove');

        if (compressedStoveImage != null) {
          final stoveImageResponse = await _apiService.uploadImage(
              file: compressedStoveImage, type: 'stove');
          if (stoveImageResponse.success) {
            stoveImagePublicId = stoveImageResponse.data['public_id'];
          }
        }
      }
    } else {
      // Use original image ID if no new image
      stoveImagePublicId = offlineEditData['original_stove_image_id'];
    }

    // Upload agreement image if available
    if (offlineEditData['agreement_image_path'] != null) {
      final agreementImageFile = File(offlineEditData['agreement_image_path']);
      if (agreementImageFile.existsSync()) {
        submissionStatus.value = 'Uploading agreement document...';

        final compressedAgreementImage =
            await _compressImageOptimally(agreementImageFile, 'agreement');

        if (compressedAgreementImage != null) {
          final agreementImageResponse = await _apiService.uploadImage(
              file: compressedAgreementImage, type: 'agreement');
          if (agreementImageResponse.success) {
            agreementImagePublicId = agreementImageResponse.data['public_id'];
          }
        }
      }
    } else {
      // Use original image ID if no new image
      agreementImagePublicId = offlineEditData['original_agreement_image_id'];
    }

    // Prepare transaction data from offline edit
    final transactionData = {
      "transactionId": offlineEditData["transactionId"],
      "stoveSerialNo": offlineEditData["stoveSerialNo"],
      "salesDate": offlineEditData["salesDate"],
      "contactPerson": offlineEditData["contactPerson"],
      "contactPhone": offlineEditData["contactPhone"],
      "endUserName": offlineEditData["endUserName"],
      "aka": offlineEditData["aka"],
      "stateBackup": offlineEditData["stateBackup"],
      "lgaBackup": offlineEditData["lgaBackup"],
      "phone": offlineEditData["phone"],
      "otherPhone": offlineEditData["otherPhone"],
      "partnerName": offlineEditData["partnerName"],
      "amount": offlineEditData["amount"],
      "signature": offlineEditData["signature"],
      if (stoveImagePublicId != null) "stoveImageId": stoveImagePublicId,
      if (agreementImagePublicId != null)
        "agreementImageId": agreementImagePublicId,
      "address": {
        "id": originalSale.address?.id ?? 10,
        "full_address": offlineEditData["addressData"]["fullAddress"],
        "street": offlineEditData["addressData"]["street"],
        "city": offlineEditData["addressData"]["city"],
        "state": offlineEditData["addressData"]["state"],
        "country": offlineEditData["addressData"]["country"],
        "latitude": offlineEditData["addressData"]["latitude"],
        "longitude": offlineEditData["addressData"]["longitude"],
      }
    };

    // Call the service to update the sale
    submissionStatus.value = 'Finalizing sync...';
    final response = await _apiService.updateSale(
      saleId: saleId!,
      saleData: transactionData,
    );

    if (response.success) {
      submissionStatus.value = 'Sync successful!';
      logger.d("Offline edit sync successful.");
    } else {
      throw Exception(
          response.message.isNotEmpty ? response.message : 'Sync failed');
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

  /// Toggle offline mode
  void toggleOfflineMode() {
    isOfflineMode.value = !isOfflineMode.value;
    logger.d('Offline mode: ${isOfflineMode.value}');
  }

  /// Compresses an image with optimal settings based on file size
  Future<File?> _compressImageOptimally(
      File imageFile, String imageType) async {
    try {
      return await ImageCompressionService.compressImage(
        imageFile,
        quality: 70,
        minWidth: 300,
        minHeight: 300,
      );
    } catch (e) {
      logger.e("Error compressing $imageType image: $e");
      return null;
    }
  }

  @override
  void onClose() {
    transactionIdController.dispose();
    salesDateController.dispose();
    contactPersonController.dispose();
    contactPhoneController.dispose();
    endUserName.dispose();
    nameController.dispose();
    akaController.dispose();
    stateController.dispose();
    lgaController.dispose();
    addressController.dispose();
    phoneController.dispose();
    otherPhoneController.dispose();
    amountController.dispose();
    stoveSerialController.dispose();
    signatureController.dispose();
    placesAddressController.dispose();
    super.onClose();
  }
}
