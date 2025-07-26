import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/admin/sales/controller/update_sale_controller.dart';
import 'package:stove_transaction/admin/sales/ui/components/update_form_fields_section.dart';
import 'package:stove_transaction/form/ui/components/image_upload_widget.dart';
import 'package:stove_transaction/form/ui/components/signature_section.dart';
import 'package:stove_transaction/form/ui/components/stove_serial_autocomplete.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';

/// Widget that builds all form sections for updating sales
class UpdateSaleSections extends StatelessWidget {
  final UpdateSaleController controller;
  final SignatureController signatureController;
  final File? stoveImage;
  final File? agreedDocumentImage;
  final String? existingStoveImageUrl;
  final String? existingAgreementImageUrl;
  final String? existingSignature;
  final VoidCallback onAddressSearch;
  final VoidCallback onStoveImageCapture;
  final VoidCallback onAgreementImageCapture;
  final VoidCallback onStoveImageDelete;
  final VoidCallback onAgreementImageDelete;
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;

  const UpdateSaleSections({
    Key? key,
    required this.controller,
    required this.signatureController,
    this.stoveImage,
    this.agreedDocumentImage,
    this.existingStoveImageUrl,
    this.existingAgreementImageUrl,
    this.existingSignature,
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
              title: 'Update Sale',
              subtitle:
                  'Update sales details for sale ID: ${controller.saleId}',
            ),
            const SizedBox(height: 25),
            _buildStoveSerialSection(),
            const SizedBox(height: 5),
            UpdateFormFieldsSection(
              controller: controller,
              transactionId: controller.transactionIdController.text,
              onAddressSearch: onAddressSearch,
            ),
            const SizedBox(height: 16),
            SignatureSection(
              signatureController: signatureController,
              existingSignature: existingSignature,
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImageUploadWidget(
          imageFile: stoveImage,
          existingImageUrl: existingStoveImageUrl,
          title: 'Picture of stove',
          subtitle: stoveImage != null
              ? 'New image selected'
              : controller.originalSale.stoveImageId != null
                  ? 'Current: ${controller.originalSale.stoveImageId!.type} image'
                  : 'JPG, JPEG, PNG',
          onTap: onStoveImageCapture,
          onRetake: onStoveImageCapture,
          onDelete: onStoveImageDelete,
        ),
        // if (stoveImage == null && controller.originalSale.stoveImageId != null)
        //   Padding(
        //     padding: const EdgeInsets.only(top: 8.0),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           'Current Stove Image:',
        //           style: TextStyle(
        //             fontSize: 12,
        //             fontWeight: FontWeight.w500,
        //             color: Colors.grey[700],
        //           ),
        //         ),
        //         const SizedBox(height: 4),
        //         if (existingStoveImageUrl != null)
        //           Container(
        //             width: 120,
        //             height: 120,
        //             decoration: BoxDecoration(
        //               border: Border.all(color: Colors.grey[300]!),
        //               borderRadius: BorderRadius.circular(8),
        //             ),
        //             child: ClipRRect(
        //               borderRadius: BorderRadius.circular(8),
        //               child: Image.network(
        //                 existingStoveImageUrl!,
        //                 fit: BoxFit.cover,
        //                 loadingBuilder: (context, child, loadingProgress) {
        //                   if (loadingProgress == null) return child;
        //                   return Center(
        //                     child: CircularProgressIndicator(
        //                       value: loadingProgress.expectedTotalBytes != null
        //                           ? loadingProgress.cumulativeBytesLoaded /
        //                               loadingProgress.expectedTotalBytes!
        //                           : null,
        //                     ),
        //                   );
        //                 },
        //                 errorBuilder: (context, error, stackTrace) {
        //                   return Container(
        //                     color: Colors.grey[200],
        //                     child: Center(
        //                       child: Column(
        //                         mainAxisAlignment: MainAxisAlignment.center,
        //                         children: [
        //                           Icon(Icons.error, color: Colors.grey[600]),
        //                           Text(
        //                             'Image not available',
        //                             style: TextStyle(
        //                               fontSize: 10,
        //                               color: Colors.grey[600],
        //                             ),
        //                           ),
        //                         ],
        //                       ),
        //                     ),
        //                   );
        //                 },
        //               ),
        //             ),
        //           ),
        //         const SizedBox(height: 4),
        //         Text(
        //           'Existing image will be kept if no new image is selected',
        //           style: TextStyle(
        //             fontSize: 12,
        //             color: Colors.grey[600],
        //             fontStyle: FontStyle.italic,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
      ],
    );
  }

  Widget _buildAgreementImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImageUploadWidget(
          imageFile: agreedDocumentImage,
          existingImageUrl: existingAgreementImageUrl,
          title: 'Picture of hard copy signed agreement',
          subtitle: agreedDocumentImage != null
              ? 'New image selected'
              : controller.originalSale.agreementImageId != null
                  ? 'Current: ${controller.originalSale.agreementImageId!.type} image'
                  : 'JPG, JPEG, PNG',
          onTap: onAgreementImageCapture,
          onRetake: onAgreementImageCapture,
          onDelete: onAgreementImageDelete,
        ),
        // if (agreedDocumentImage == null &&
        //     controller.originalSale.agreementImageId != null)
        //   Padding(
        //   padding: const EdgeInsets.only(top: 8.0),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Text(
        //         'Current Agreement Image:',
        //         style: TextStyle(
        //           fontSize: 12,
        //           fontWeight: FontWeight.w500,
        //           color: Colors.grey[700],
        //         ),
        //       ),
        //       const SizedBox(height: 4),
        //       if (existingAgreementImageUrl != null)
        //         Container(
        //           width: 120,
        //           height: 120,
        //           decoration: BoxDecoration(
        //             border: Border.all(color: Colors.grey[300]!),
        //             borderRadius: BorderRadius.circular(8),
        //           ),
        //           child: ClipRRect(
        //             borderRadius: BorderRadius.circular(8),
        //             child: Image.network(
        //               existingAgreementImageUrl!,
        //               fit: BoxFit.cover,
        //               loadingBuilder: (context, child, loadingProgress) {
        //                 if (loadingProgress == null) return child;
        //                 return Center(
        //                   child: CircularProgressIndicator(
        //                     value: loadingProgress.expectedTotalBytes != null
        //                         ? loadingProgress.cumulativeBytesLoaded /
        //                             loadingProgress.expectedTotalBytes!
        //                         : null,
        //                   ),
        //                 );
        //               },
        //               errorBuilder: (context, error, stackTrace) {
        //                 return Container(
        //                   color: Colors.grey[200],
        //                   child: Center(
        //                     child: Column(
        //                       mainAxisAlignment: MainAxisAlignment.center,
        //                       children: [
        //                         Icon(Icons.error, color: Colors.grey[600]),
        //                         Text(
        //                           'Image not available',
        //                           style: TextStyle(
        //                             fontSize: 10,
        //                             color: Colors.grey[600],
        //                           ),
        //                         ),
        //                       ],
        //                     ),
        //                   ),
        //                 );
        //               },
        //             ),
        //           ),
        //         ),
        //       const SizedBox(height: 4),
        //       Text(
        //         'Existing image will be kept if no new image is selected',
        //         style: TextStyle(
        //           fontSize: 12,
        //           color: Colors.grey[600],
        //           fontStyle: FontStyle.italic,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        onPressed: controller.isLoading.value ? () {} : onSubmit,
        isLoading: controller.isLoading.value,
        text: "Update Sale",
      ),
    );
  }
}
