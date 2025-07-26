import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/admin/sales/controller/update_sale_controller.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/ui/components/update_sale_sections.dart';
import 'package:stove_transaction/form/ui/address_input_screen.dart';
import 'package:stove_transaction/form/ui/components/camera_preview_widget.dart';
import 'package:stove_transaction/form/ui/components/camera_handler_mixin.dart';
import 'package:stove_transaction/form/ui/components/update_sale_submission_handler.dart';
import 'package:stove_transaction/form/ui/helpers/update_sale_helper.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'dart:io';

class UpdateSaleScreen extends StatefulWidget {
  @override
  State<UpdateSaleScreen> createState() => _UpdateSaleScreenState();
}

class _UpdateSaleScreenState extends State<UpdateSaleScreen>
    with CameraHandlerMixin {
  late UpdateSaleController controller;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool isSearchingAddress = false;
  File? stoveImage;
  File? agreedDocumentImage;
  bool isStoveCapturing = false;
  late SignatureController signatureController;

  @override
  void initState() {
    super.initState();

    // Get or create controller
    if (Get.isRegistered<UpdateSaleController>()) {
      controller = Get.find<UpdateSaleController>();
      // Update with new sale data if controller already exists
      if (Get.arguments != null && Get.arguments['sale'] != null) {
        final newSale = Get.arguments['sale'] as SaleModel;
        controller.updateSaleData(newSale);
      }
    } else {
      controller = Get.put(UpdateSaleController());
    }

    signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );

    // Signature will be displayed in the SignatureSection component
    if (controller.originalSale.signature != null &&
        controller.originalSale.signature!.isNotEmpty) {
      print('Existing signature found for sale: ${controller.saleId}');
    }
  }

  @override
  void dispose() {
    // Clear the signature controller
    signatureController.dispose();

    // Clear form data when leaving the screen
    if (Get.isRegistered<UpdateSaleController>()) {
      controller.clearFormData();
    }

    super.dispose();
  }

  void _closeSearchingAddress() {
    setState(() {
      isSearchingAddress = false;
    });
  }

  void _handleStoveImageCapture() {
    isStoveCapturing = true;
    initiateCameraCapture(
      onImageCaptured: (file) {
        setState(() {
          stoveImage = file;
        });
      },
    );
  }

  void _handleAgreementImageCapture() {
    isStoveCapturing = false;
    initiateCameraCapture(
      onImageCaptured: (file) {
        setState(() {
          agreedDocumentImage = file;
        });
      },
    );
  }

  void _handleStoveImageDelete() {
    setState(() {
      stoveImage = null;
    });
  }

  void _handleAgreementImageDelete() {
    setState(() {
      agreedDocumentImage = null;
    });
  }

  void _handleSubmit() {
    UpdateSaleHelper.submitForm(
      controller: controller,
      formKey: formKey,
      stoveImage: stoveImage,
      agreedDocumentImage: agreedDocumentImage,
      signatureController: signatureController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(
        title: 'Update Sale',
        showBottomBorder: false,
        onTaps: !isSearchingAddress
            ? () => Navigator.pop(context)
            : () => setState(() => isSearchingAddress = !isSearchingAddress),
      ),
      body: Obx(() {
        return controller.partnerNames.isEmpty
            ? Center(child: CircularProgressIndicator())
            : _buildBodyContent();
      }),
    );
  }

  Widget _buildBodyContent() {
    if (isCameraPreviewVisible &&
        hasPermission &&
        cameraController.value.isInitialized) {
      return CameraPreviewWidget(
        cameraController: cameraController,
        onCapture: () => captureImage(
          onImageCaptured: (file) {
            setState(() {
              if (isStoveCapturing) {
                stoveImage = file;
              } else {
                agreedDocumentImage = file;
              }
            });
          },
        ),
      );
    }

    if (isSearchingAddress) {
      return AddressInputScreen(closeSearchingAddress: _closeSearchingAddress);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: UpdateSaleSections(
            controller: controller,
            signatureController: signatureController,
            stoveImage: stoveImage,
            agreedDocumentImage: agreedDocumentImage,
            existingStoveImageUrl: controller.originalSale.stoveImageId?.url,
            existingAgreementImageUrl:
                controller.originalSale.agreementImageId?.url,
            existingSignature: controller.originalSale.signature,
            onAddressSearch: () => setState(() => isSearchingAddress = true),
            onStoveImageCapture: _handleStoveImageCapture,
            onAgreementImageCapture: _handleAgreementImageCapture,
            onStoveImageDelete: _handleStoveImageDelete,
            onAgreementImageDelete: _handleAgreementImageDelete,
            onSubmit: _handleSubmit,
            formKey: formKey,
          ),
        ),
        UpdateSaleSubmissionHandler(
          controller: controller,
          stoveImage: stoveImage,
          agreedDocumentImage: agreedDocumentImage,
        ),
      ],
    );
  }
}
