import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    // For now, we'll simulate fetching data.
    print('Loading sale data for edit: $saleId');
    // Example: Populate controllers with mock data for editing
    fullNameController.text = 'John Doe';
    phoneNumberController.text = '123-456-7890';
    addressController.text = '123 Edit Street, Edit City';
    selectedStoveId.value = 'STV001';
    currentLatitude.value = '34.0522';
    currentLongitude.value = '-118.2437';
    geoSource.value = 'GPS';
    // stoveImagePath.value = 'path/to/existing/stove_image.jpg';
    // agreementImagePath.value = 'path/to/existing/agreement_image.jpg';
    hasSigned.value =
        true; // Assuming a signed document exists for an existing sale
  }

  void updateSale() {
    if (validateForm() && hasSigned.value) {
      isLoading.value = true;
      // Simulate API call for updating sale
      Future.delayed(const Duration(seconds: 2), () {
        isLoading.value = false;
        Get.snackbar('Success', 'Sale updated successfully!');
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
