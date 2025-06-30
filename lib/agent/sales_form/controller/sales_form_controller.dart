import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';

class SalesFormController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

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
      // Simulate form submission
      Future.delayed(const Duration(seconds: 2), () {
        isLoading.value = false;
        Get.snackbar('Success', 'Sale recorded successfully!');
        // Clear form or navigate
        _clearForm();
      });
    } else if (!hasSigned.value) {
      Get.snackbar('Error', 'Please provide a digital signature.');
    } else {
      Get.snackbar('Error', 'Please fill all required fields.');
    }
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
      fullNameController.text = sale.userId; // Assuming userId is end-user name
      phoneNumberController.text = 'N/A'; // No phone in Sale model
      addressController.text = 'N/A'; // No address in Sale model
      selectedStoveId.value = sale.product; // Assuming product is stove ID
      // For geo-location, photo, signature, you'd load from sale object if available
      // currentLatitude.value = sale.latitude;
      // currentLongitude.value = sale.longitude;
      // stoveImagePath.value = sale.stoveImagePath;
      // agreementImagePath.value = sale.agreementImagePath;
      // hasSigned.value = sale.hasSigned;
    } else {
      Get.snackbar('Error', 'Sale not found for editing.');
    }
  }

  void updateSale() {
    if (validateForm() && hasSigned.value) {
      isLoading.value = true;
      // Simulate API call for updating sale
      Future.delayed(const Duration(seconds: 2), () {
        isLoading.value = false;
        final SalesController salesController = Get.find<SalesController>();
        salesController.completeSale(Get.arguments['saleId']);
        Get.snackbar('Success', 'Sale updated successfully!');
        Get.back();
      });
    } else if (!hasSigned.value) {
      Get.snackbar('Error', 'Please provide a digital signature.');
    } else {
      Get.snackbar('Error', 'Please fill all required fields.');
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
