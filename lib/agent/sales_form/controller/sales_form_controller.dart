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
      _saveOfflineSale(); // Always save offline first
    } else if (!hasSigned.value) {
      showErrorToast(message: 'Please provide a digital signature.');
    } else {
      showErrorToast(message: 'Please fill all required fields.');
    }
  }

  void updateSale() {
    if (validateForm() && hasSigned.value) {
      isLoading.value = true;
      _saveOfflineSaleEdit(); // Always save offline first for edits too
    } else if (!hasSigned.value) {
      showErrorToast(message: 'Please provide a digital signature.');
    } else {
      showErrorToast(message: 'Please fill all required fields.');
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

        // Try immediate sync if online
        final isOnline = await _checkConnectivity();
        if (isOnline && !isOfflineMode.value) {
          try {
            _logger.d('Attempting immediate sync...');
            // Here you could implement immediate sync logic
            // For now, just show success message
            showSuccessToast(
              title: 'Sale Saved',
              message:
                  'Sale saved offline successfully! Will sync when possible.',
            );
          } catch (e) {
            _logger.w('Immediate sync failed: $e');
            showSuccessToast(
              title: 'Sale Saved',
              message: 'Sale saved locally and will sync when online',
            );
          }
        } else {
          showSuccessToast(
            title: 'Sale Saved',
            message: 'Sale saved locally and will sync when online',
          );
        }

        // Get the offline sales controller and refresh data
        if (Get.isRegistered<OfflineSalesController>()) {
          final offlineController = Get.find<OfflineSalesController>();
          await offlineController.refreshOfflineData();
        }

        _clearForm();
        Get.back(); // Navigate back
      } else {
        showErrorToast(message: 'Failed to save sale offline');
      }
    } catch (e) {
      _logger.e('Error saving sale offline: $e');
      showErrorToast(message: 'Failed to save sale: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Save sale edit offline
  Future<void> _saveOfflineSaleEdit() async {
    try {
      _logger.d('Saving sale edit offline...');

      if (!isEditMode.value) {
        showErrorToast(message: 'Not in edit mode');
        return;
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

        // Try immediate sync if online
        final isOnline = await _checkConnectivity();
        if (isOnline && !isOfflineMode.value) {
          try {
            _logger.d('Attempting immediate edit sync...');
            // Here you could implement immediate sync logic for edits
            showSuccessToast(
              title: 'Changes Saved',
              message:
                  'Changes saved offline successfully! Will sync when possible.',
            );
          } catch (e) {
            _logger.w('Immediate sync failed: $e');
            showSuccessToast(
              title: 'Changes Saved',
              message: 'Changes saved locally and will sync when online',
            );
          }
        } else {
          showSuccessToast(
            title: 'Changes Saved',
            message: 'Changes saved locally and will sync when online',
          );
        }

        // Get the offline sales controller and refresh data
        if (Get.isRegistered<OfflineSalesController>()) {
          final offlineController = Get.find<OfflineSalesController>();
          await offlineController.refreshOfflineData();
        }

        Get.back(); // Navigate back
      } else {
        showErrorToast(message: 'Failed to save changes offline');
      }
    } catch (e) {
      _logger.e('Error saving edit offline: $e');
      showErrorToast(message: 'Failed to save changes: $e');
    } finally {
      isLoading.value = false;
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
