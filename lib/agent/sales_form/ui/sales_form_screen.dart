// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/sales_form/controller/sales_form_controller.dart';
import 'package:stove_transaction/agent/sales_form/widgets/custom_textfield.dart';
import 'package:stove_transaction/agent/sales_form/widgets/image_input_widget.dart';
import 'package:stove_transaction/agent/sales_form/widgets/primary_button.dart';
import 'package:stove_transaction/agent/sales_form/widgets/signature_input_widget.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';

class SalesFormScreen extends StatelessWidget {
  const SalesFormScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SalesFormController controller = Get.put(SalesFormController());


    return Scaffold(
      appBar: BaseAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PageHeaderTile(
              //   title: 'New Sales',
              //   subtitle: 'Capture sales details for your stove',
              // ),
         
              // End-User Info Section
              SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End-User Information',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Full Name',
                        controller: controller.fullNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Full Name is required.';
                          }
                          return null;
                        },
                      ),
                      CustomTextField(
                        label: 'Phone Number',
                        controller: controller.phoneNumberController,
                        inputType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone Number is required.';
                          }
                          return null;
                        },
                      ),
                      CustomTextField(
                        label: 'Address',
                        controller: controller.addressController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Address is required.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Stove Selection
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stove Selection',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => DropdownButtonFormField<String>(
                          value: controller.selectedStoveId.value.isEmpty ||
                                  !controller.mockStoveIds.contains(
                                      controller.selectedStoveId.value)
                              ? null
                              : controller.selectedStoveId.value,
                          decoration: InputDecoration(
                            labelText: 'Select Stove ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: controller.mockStoveIds
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              controller.selectedStoveId.value = newValue;
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Stove ID is required.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Geo-location Capture
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Geo-location Capture',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Obx(
                              () => Text(
                                'Lat: ${controller.currentLatitude.value}, Lon: ${controller.currentLongitude.value}',
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 14,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                            ),
                          ),
                          Tooltip(
                            message: 'Current GPS coordinates',
                            child: Icon(
                              Icons.info_outline,
                              color: AppColors.secondaryTextColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Geo Source:',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => Row(
                          children: [
                            _buildGeoSourceChip('Auto', controller, context),
                            const SizedBox(width: 8),
                            _buildGeoSourceChip('Mapped', controller, context),
                            const SizedBox(width: 8),
                            _buildGeoSourceChip(
                                'Landmark', controller, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Photo Uploads
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Uploads',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => ImageInputWidget(
                          label: 'Stove Image',
                          imagePath: controller.stoveImagePath.value,
                          onImagePicked: (path) =>
                              controller.stoveImagePath.value = path,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => ImageInputWidget(
                          label: 'Signed Agreement Image',
                          imagePath: controller.agreementImagePath.value,
                          onImagePicked: (path) =>
                              controller.agreementImagePath.value = path,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Digital Signature
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SignatureInputWidget(
                        onSigned: (isSigned) =>
                            controller.hasSigned.value = isSigned,
                      ),
                    ],
                  ),
                ),
              ),

              // Submit Button + Offline Note
              Obx(
                () => PrimaryButton(
                  text: controller.isEditMode.value
                      ? 'Update Sale'
                      : 'Submit Sale',
                  onPressed: () => controller.isEditMode.value
                      ? controller.updateSale()
                      : controller.submitForm(),
                  isLoading: controller.isLoading.value,
                ),
              ),
              Obx(
                () => controller.isOffline.value
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          "You're offline. This sale will be saved locally and synced later.",
                          textAlign: TextAlign.center,
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeoSourceChip(
      String source, SalesFormController controller, BuildContext context) {
    return ChoiceChip(
      label: Text(source),
      selected: controller.geoSource.value == source,
      onSelected: (selected) {
        if (selected) {
          controller.setGeoSource(source);
        }
      },
      selectedColor: AppColors.primaryColor,
      labelStyle: TextThemes(context).getTextStyle(
        color: controller.geoSource.value == source
            ? AppColors.white
            : AppColors.primaryTextColor,
      ),
      backgroundColor: AppColors.lightGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: controller.geoSource.value == source
              ? AppColors.primaryColor
              : AppColors.borderColor,
        ),
      ),
    );
  }
}
