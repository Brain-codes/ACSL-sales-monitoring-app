import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/form/controller/form_controller.dart';
import 'package:stove_transaction/form/ui/components/form_fields_section.dart';
import 'package:stove_transaction/form/ui/components/image_upload_widget.dart';
import 'package:stove_transaction/form/ui/components/signature_section.dart';
import 'package:stove_transaction/form/ui/components/stove_serial_autocomplete.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';
import 'package:stove_transaction/agent/sales_form/widgets/primary_button.dart';

/// Widget that builds all form sections
class UserFormSections extends StatelessWidget {
  final FormController controller;
  final String transactionId;
  final SignatureController signatureController;
  final File? stoveImage;
  final File? agreedDocumentImage;
  final VoidCallback onAddressSearch;
  final VoidCallback onStoveImageCapture;
  final VoidCallback onAgreementImageCapture;
  final VoidCallback onStoveImageDelete;
  final VoidCallback onAgreementImageDelete;
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;

  const UserFormSections({
    Key? key,
    required this.controller,
    required this.transactionId,
    required this.signatureController,
    this.stoveImage,
    this.agreedDocumentImage,
    required this.onAddressSearch,
    required this.onStoveImageCapture,
    required this.onAgreementImageCapture,
    required this.onStoveImageDelete,
    required this.onAgreementImageDelete,
    required this.onSubmit,
    required this.formKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16, bottom: 16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeaderTile(
              title: 'New Sales',
              subtitle: 'Capture sales details for your stove',
            ),
            const SizedBox(height: 25),
            _buildStoveSerialSection(),
            const SizedBox(height: 5),
            FormFieldsSection(
              controller: controller,
              transactionId: transactionId,
              onAddressSearch: onAddressSearch,
            ),
            const SizedBox(height: 16),
            SignatureSection(signatureController: signatureController),
            const SizedBox(height: 16),
            _buildStoveImageSection(),
            const SizedBox(height: 20),
            _buildAgreementImageSection(),
            const SizedBox(height: 16),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStoveSerialSection() {
    return StoveSerialAutocomplete(
      stoveIds: controller.stoveIds,
      controller: controller.stoveSerialController,
      onSelected: (String selection) {
        controller.stoveSerialController.text = selection;
      },
      validator: (value) {
        if (value!.isNotEmpty &&
            !controller.stoveIds.any((id) => id == value)) {
          return 'Invalid Stove Serial No.';
        }
        return null;
      },
    );
  }

  Widget _buildStoveImageSection() {
    return ImageUploadWidget(
      imageFile: stoveImage,
      title: 'Picture of stove',
      subtitle: 'JPG, JPEG, PNG',
      onTap: onStoveImageCapture,
      onRetake: onStoveImageCapture,
      onDelete: onStoveImageDelete,
    );
  }

  Widget _buildAgreementImageSection() {
    return ImageUploadWidget(
      imageFile: agreedDocumentImage,
      title: 'Picture of hard copy signed agreement',
      subtitle: 'JPG, JPEG, PNG',
      onTap: onAgreementImageCapture,
      onRetake: onAgreementImageCapture,
      onDelete: onAgreementImageDelete,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        onPressed: controller.isLoading.value ? () {} : onSubmit,
        isLoading: controller.isLoading.value,
        text: "Submit",
      ),
    );
  }
}
