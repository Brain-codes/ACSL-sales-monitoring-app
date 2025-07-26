import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/sales_form/widgets/custom_textfield.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/admin/sales/controller/update_sale_controller.dart';
import 'package:stove_transaction/form/ui/components/state_lga_dropdowns.dart';
import 'package:stove_transaction/shared/ui/number_input_formatter.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class UpdateFormFieldsSection extends StatelessWidget {
  final UpdateSaleController controller;
  final String transactionId;
  final Function() onAddressSearch;

  const UpdateFormFieldsSection({
    Key? key,
    required this.controller,
    required this.transactionId,
    required this.onAddressSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTextField(
          label: 'Transaction ID (Invoice Number)',
          controller: TextEditingController(text: transactionId),
          readOnly: true,
        ),
        CustomTextField(
          label: 'Sales Date',
          controller: controller.salesDateController,
          readOnly: true,
          onTap: () => _selectDate(context),
        ),
        CustomTextField(
          label: 'Contact Person / Buyer',
          controller: controller.contactPersonController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Contact Person is required.';
            }
            return null;
          },
        ),
        CustomTextField(
          label: 'Contact Person\'s Phone Number',
          controller: controller.contactPhoneController,
          inputType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Contact Person\'s Phone Number is required.';
            }
            return null;
          },
        ),
        CustomTextField(
          label: 'End User\'s Name (Surname / First name)',
          controller: controller.endUserName,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'End User\'s Name is required.';
            }
            return null;
          },
        ),
        CustomTextField(
          label: 'Also Known As (AKA)',
          controller: controller.akaController,
        ),
        SizedBox(height: 10),
        Obx(() => StateAndLGADropdowns(
              selectedState: controller.selectedState.value.isNotEmpty
                  ? controller.selectedState.value
                  : null,
              selectedLGA: controller.selectedLGA.value.isNotEmpty
                  ? controller.selectedLGA.value
                  : null,
              onStateChanged: (value) {
                controller.selectedState.value = value ?? '';
                controller.selectedLGA.value = '';
              },
              onLGAChanged: (value) {
                controller.selectedLGA.value = value ?? '';
              },
              stateValidator: (value) {
                if (value == null || value.isEmpty) {
                  return 'State is required.';
                }
                return null;
              },
              lgaValidator: (value) {
                if (value == null || value.isEmpty) {
                  return 'LGA is required.';
                }
                return null;
              },
            )),
        SizedBox(height: 10),
        CustomTextField(
          label: 'Residential Address',
          readOnly: true,
          onTap: onAddressSearch,
          controller: controller.addressController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Residential Address is required.';
            }
            return null;
          },
        ),
        _buildLocationFields(),
        CustomTextField(
          label: 'Phone Number',
          controller: controller.phoneController,
          inputType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone Number is required.';
            }
            return null;
          },
        ),
        CustomTextField(
          label: 'Other Number',
          controller: controller.otherPhoneController,
          inputType: TextInputType.phone,
        ),
        CustomTextField(
          label: 'Amount',
          controller: controller.amountController,
          inputType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            labelStyle: TextThemes(context).getTextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primaryColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            prefix: Text(
              'N',
              style: TextThemes(context).getTextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          inputFormatters: [NumberInputFormatter()],
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return GetBuilder<UpdateSaleController>(
      builder: (controller) => controller.latitude != null
          ? Opacity(
              opacity: 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'Latitude',
                    readOnly: true,
                    controller: TextEditingController(
                      text: controller.latitude.toString(),
                    ),
                  ),
                  CustomTextField(
                    label: 'Longitude',
                    readOnly: true,
                    controller: TextEditingController(
                      text: controller.longitude.toString(),
                    ),
                  ),
                ],
              ),
            )
          : SizedBox.shrink(),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final controller = Get.find<UpdateSaleController>();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.primaryColor,
            colorScheme: ColorScheme.light(primary: AppColors.primaryColor),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child ?? Container(),
        );
      },
    );
    if (pickedDate != null) {
      controller.salesDateController.text =
          "${pickedDate.toLocal()}".split(' ')[0];
    }
  }
}
