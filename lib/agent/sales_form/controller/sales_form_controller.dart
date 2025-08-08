import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/admin/sales/controller/offline_sales_controller.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:logger/logger.dart';

class SalesFormController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();
  final Logger _logger = Logger();

  // End-User Info
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // Stove Selection
  final RxString selectedStoveId = ''.obs;
  final List<String> mockStoveIds = [
    'STV001',
    'STV002',
    'STV003',
    'STV004',
    'STV005'
  ];

  // Geo-location Capture
  final RxString currentLatitude = 'N/A'.obs;
  final RxString currentLongitude = 'N/A'.obs;
  final RxString geoSource = 'Auto'.obs; // Auto, Mapped, Landmark

  // Photo Uploads
  final RxString stoveImagePath = ''.obs;
  final RxString agreementImagePath = ''.obs;

  // Digital Signature
  final RxBool hasSigned = false.obs;

  // Loading and Offline State
  final RxBool isLoading = false.obs;
  final RxBool isOffline = false.obs; // Mock for now
  final RxBool isOfflineMode = true.obs; // Default to offline-first
  var isEditMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Simulate initial geo-location fetch
    _fetchCurrentLocation();
    if (Get.arguments != null && Get.arguments['isEditMode'] == true) {
      isEditMode.value = true;
      _loadSaleDataForEdit(Get.arguments['saleId']);
    }
  }

  void _fetchCurrentLocation() {
    // Mock fetching current location
    currentLatitude.value = '12.3456';
    currentLongitude.value = '78.9101';
  }

  void setGeoSource(String source) {
    geoSource.value = source;
  }

  void pickStoveImage() {
    // Logic to pick stove image (camera/gallery) - to be implemented later
    // For now, just simulate a path
    stoveImagePath.value = 'path/to/stove_image.jpg';
  }

  void pickAgreementImage() {
    // Logic to pick agreement image (camera/gallery) - to be implemented later
    // For now, just simulate a path
    agreementImagePath.value = 'path/to/agreement_image.jpg';
  }

  void clearSignature() {
    hasSigned.value = false;
    // Logic to clear signature pad - to be implemented in widget
  }

  void saveSignature() {
    hasSigned.value = true;
    // Logic to save signature - to be implemented in widget
  }

  bool validateForm() {
    return formKey.currentState?.validate() ?? false;
  }

  void submitForm() {
    if (validateForm() && hasSigned.value) {
      isLoading.value = true;
      _handleSaleSubmission(); // Check connectivity and submit accordingly
    } else if (!hasSigned.value) {
      showErrorToast(message: 'Please provide a digital signature.');
    } else {
      showErrorToast(message: 'Please fill all required fields.');
    }
  }

  void updateSale() {
    if (validateForm() && hasSigned.value) {
      isLoading.value = true;
      _handleSaleUpdate(); // Check connectivity and update accordingly
    } else if (!hasSigned.value) {
      showErrorToast(message: 'Please provide a digital signature.');
    } else {
      showErrorToast(message: 'Please fill all required fields.');
    }
  }

  /// Handle sale submission with connectivity-aware logic
  Future<void> _handleSaleSubmission() async {
    try {
      _logger.d('Starting sale submission...');

      // Check internet connectivity first
      final isOnline = await _checkConnectivity();

      if (isOnline && !isOfflineMode.value) {
        // Device has internet - try to submit online first
        _logger.d("Device is online, attempting direct submission...");

        try {
          // Try to submit directly online (implement actual online submission)
          await _submitOnline(); // This would need to be implemented

          showSuccessToast(
            title: 'Success',
            message: 'Sale submitted successfully!',
          );

          _clearForm();
          Get.back(); // Navigate back
        } catch (e) {
          // Online submission failed even with internet - save offline for later sync
          _logger.w('Online submission failed despite internet connection: $e');

          await _saveOfflineSale();

          showInfoToast(
            title: 'Saved Offline',
            message:
                'Submission failed but saved locally. Will sync when possible.',
          );
        }
      } else {
        // No internet connection - save offline
        _logger.d("No internet connection detected, saving offline...");

        await _saveOfflineSale();

        showSuccessToast(
          title: 'Saved Offline',
          message:
              'No internet connection. Sale saved locally and will sync when online.',
        );
      }
    } catch (e) {
      _logger.e('Sale submission error: $e');
      showErrorToast(message: 'Failed to save sale: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Handle sale update with connectivity-aware logic
  Future<void> _handleSaleUpdate() async {
    try {
      _logger.d('Starting sale update...');

      // Check internet connectivity first
      final isOnline = await _checkConnectivity();

      if (isOnline && !isOfflineMode.value) {
        // Device has internet - try to update online first
        _logger.d("Device is online, attempting direct update...");

        try {
          // Try to update directly online (implement actual online update)
          await _updateOnline(); // This would need to be implemented

          showSuccessToast(
            title: 'Success',
            message: 'Sale updated successfully!',
          );

          Get.back(); // Navigate back
        } catch (e) {
          // Online update failed even with internet - save edit offline for later sync
          _logger.w('Online update failed despite internet connection: $e');

          await _saveOfflineSaleEdit();

          showInfoToast(
            title: 'Saved Offline',
            message:
                'Update failed but saved locally. Will sync when possible.',
          );
        }
      } else {
        // No internet connection - save edit offline
        _logger.d("No internet connection detected, saving edit offline...");

        await _saveOfflineSaleEdit();

        showSuccessToast(
          title: 'Saved Offline',
          message:
              'No internet connection. Changes saved locally and will sync when online.',
        );
      }
    } catch (e) {
      _logger.e('Sale update error: $e');
      showErrorToast(message: 'Failed to save changes: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Save sale offline
  Future<void> _saveOfflineSale() async {
    try {
      _logger.d('Saving sale offline...');

      // Save images locally if they exist
      String? stoveImageLocalPath;
      String? agreementImageLocalPath;

      if (stoveImagePath.value.isNotEmpty) {
        final stoveImageFile = File(stoveImagePath.value);
        if (stoveImageFile.existsSync()) {
          stoveImageLocalPath =
              await _offlineStorage.saveOfflineImage(stoveImageFile, 'stove');
        }
      }

      if (agreementImagePath.value.isNotEmpty) {
        final agreementImageFile = File(agreementImagePath.value);
        if (agreementImageFile.existsSync()) {
          agreementImageLocalPath = await _offlineStorage.saveOfflineImage(
              agreementImageFile, 'agreement');
        }
      }

      // Prepare offline sale data
      final offlineSaleData = {
        "transactionId": DateTime.now().millisecondsSinceEpoch.toString(),
        "stoveSerialNo": selectedStoveId.value,
        "salesDate": DateTime.now().toIso8601String(),
        "contactPerson": fullNameController.text,
        "contactPhone": phoneNumberController.text,
        "endUserName": fullNameController.text,
        "phone": phoneNumberController.text,
        "partnerName": "Agent Sale",
        "amount": 0.0, // Default amount for agent sales
        "signature": hasSigned.value
            ? "agent_signature_${DateTime.now().millisecondsSinceEpoch}"
            : null,
        "addressData": {
          "fullAddress": addressController.text,
          "latitude": double.tryParse(currentLatitude.value),
          "longitude": double.tryParse(currentLongitude.value),
        },
        "stove_image_path": stoveImageLocalPath,
        "agreement_image_path": agreementImageLocalPath,
        "geoSource": geoSource.value,
      };

      final success = await _offlineStorage.saveOfflineSale(offlineSaleData);

      if (success) {
        _logger.d('Sale saved offline successfully');

        // Get the offline sales controller and refresh data
        if (Get.isRegistered<OfflineSalesController>()) {
          final offlineController = Get.find<OfflineSalesController>();
          await offlineController.refreshOfflineData();
        }

        _clearForm();
        Get.back(); // Navigate back
      } else {
        throw Exception('Failed to save sale offline');
      }
    } catch (e) {
      _logger.e('Error saving sale offline: $e');
      throw e; // Re-throw to let calling method handle
    }
  }

  /// Save sale edit offline
  Future<void> _saveOfflineSaleEdit() async {
    try {
      _logger.d('Saving sale edit offline...');

      if (!isEditMode.value) {
        throw Exception('Not in edit mode');
      }

      // Save images locally if they exist
      String? stoveImageLocalPath;
      String? agreementImageLocalPath;

      if (stoveImagePath.value.isNotEmpty) {
        final stoveImageFile = File(stoveImagePath.value);
        if (stoveImageFile.existsSync()) {
          stoveImageLocalPath =
              await _offlineStorage.saveOfflineImage(stoveImageFile, 'stove');
        }
      }

      if (agreementImagePath.value.isNotEmpty) {
        final agreementImageFile = File(agreementImagePath.value);
        if (agreementImageFile.existsSync()) {
          agreementImageLocalPath = await _offlineStorage.saveOfflineImage(
              agreementImageFile, 'agreement');
        }
      }

      // Prepare offline edit data
      final offlineEditData = {
        "stoveSerialNo": selectedStoveId.value,
        "contactPerson": fullNameController.text,
        "contactPhone": phoneNumberController.text,
        "endUserName": fullNameController.text,
        "phone": phoneNumberController.text,
        "partnerName": "Agent Sale (Updated)",
        "signature": hasSigned.value
            ? "agent_signature_${DateTime.now().millisecondsSinceEpoch}"
            : null,
        "addressData": {
          "fullAddress": addressController.text,
          "latitude": double.tryParse(currentLatitude.value),
          "longitude": double.tryParse(currentLongitude.value),
        },
        "stove_image_path": stoveImageLocalPath,
        "agreement_image_path": agreementImageLocalPath,
        "geoSource": geoSource.value,
      };

      // Get sale ID from arguments or existing data
      final saleId = Get.arguments?['saleId'] ?? 'unknown_sale_id';

      final success =
          await _offlineStorage.saveOfflineSaleEdit(saleId, offlineEditData);

      if (success) {
        _logger.d('Sale edit saved offline successfully');

        // Get the offline sales controller and refresh data
        if (Get.isRegistered<OfflineSalesController>()) {
          final offlineController = Get.find<OfflineSalesController>();
          await offlineController.refreshOfflineData();
        }

        Get.back(); // Navigate back
      } else {
        throw Exception('Failed to save changes offline');
      }
    } catch (e) {
      _logger.e('Error saving edit offline: $e');
      throw e; // Re-throw to let calling method handle
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

  /// Submit sale online directly (placeholder - implement actual online submission)
  Future<void> _submitOnline() async {
    _logger.d('Direct online submission not yet implemented');
    // TODO: Implement direct online submission for agent sales
    // This would involve calling the appropriate API service to submit the sale directly
    throw Exception(
        'Direct online submission not yet implemented for agent sales');
  }

  /// Update sale online directly (placeholder - implement actual online update)
  Future<void> _updateOnline() async {
    _logger.d('Direct online update not yet implemented');
    // TODO: Implement direct online update for agent sales
    // This would involve calling the appropriate API service to update the sale directly
    throw Exception('Direct online update not yet implemented for agent sales');
  }

  /// Toggle offline mode
  void toggleOfflineMode() {
    isOfflineMode.value = !isOfflineMode.value;
    _logger.d('Agent offline mode: ${isOfflineMode.value}');
  }

  void _clearForm() {
    fullNameController.clear();
    phoneNumberController.clear();
    addressController.clear();
    selectedStoveId.value = '';
    stoveImagePath.value = '';
    agreementImagePath.value = '';
    hasSigned.value = false;
    _fetchCurrentLocation(); // Re-fetch location for new form
  }

  void _loadSaleDataForEdit(String saleId) {
    // This is a placeholder. In a real app, you would fetch the sale data
    // from your API service using the saleId.
    final SalesController salesController = Get.find<SalesController>();
    final sale = salesController.findSaleById(saleId);

    if (sale != null) {
      // fullNameController.text = sale.userId; // Assuming userId is end-user name
      phoneNumberController.text = 'N/A'; // No phone in Sale model
      addressController.text = 'N/A'; // No address in Sale model
      // selectedStoveId.value = sale.product; // Assuming product is stove ID
      // For geo-location, photo, signature, you'd load from sale object if available
      // currentLatitude.value = sale.latitude;
      // currentLongitude.value = sale.longitude;
      // stoveImagePath.value = sale.stoveImagePath;
      // agreementImagePath.value = sale.agreementImagePath;
      void _loadSaleDataForEdit(String saleId) {
        // This is a placeholder. In a real app, you would fetch the sale data
        // from your API service using the saleId.
        final SalesController salesController = Get.find<SalesController>();
        final sale = salesController.findSaleById(saleId);

        if (sale != null) {
          // Load sale data into form fields
          fullNameController.text = sale.endUserName ?? '';
          phoneNumberController.text = sale.phone ?? '';
          addressController.text = sale.address?.fullAddress ?? '';
          selectedStoveId.value = sale.stoveSerialNo ?? '';
          // Load other fields as needed
        } else {
          Get.snackbar('Error', 'Sale not found for editing.');
        }
      }

      @override
      void onClose() {
        fullNameController.dispose();
        phoneNumberController.dispose();
        addressController.dispose();
        super.onClose();
      }
    }
  }
}
