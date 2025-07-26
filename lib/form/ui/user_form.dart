// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/form/controller/form_controller.dart';
import 'package:stove_transaction/form/ui/address_input_screen.dart';
import 'package:stove_transaction/form/ui/components/camera_preview_widget.dart';
import 'package:stove_transaction/form/ui/components/camera_handler_mixin.dart';
import 'package:stove_transaction/form/ui/components/submission_handler.dart';
import 'package:stove_transaction/form/ui/components/user_form_sections.dart';
import 'package:stove_transaction/form/ui/helpers/user_form_helper.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'dart:io';

class UserForm extends StatefulWidget {
  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> with CameraHandlerMixin {
  final FormController controller = Get.put(FormController());
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late String transactionId;
  bool isSearchingAddress = false;
  File? stoveImage;
  File? agreedDocumentImage;
  bool isStoveCapturing = false;
  late SignatureController signatureController;

  @override
  void initState() {
    super.initState();
    transactionId = UserFormHelper.generateTransactionId();
    signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
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
    UserFormHelper.submitForm(
      controller: controller,
      formKey: formKey,
      transactionId: transactionId,
      stoveImage: stoveImage,
      agreedDocumentImage: agreedDocumentImage,
      signatureController: signatureController,
      onClearForm: _clearForm,
    );
  }

  void _clearForm() {
    UserFormHelper.clearForm(
      controller: controller,
      formKey: formKey,
      signatureController: signatureController,
      onTransactionIdGenerated: (newId) {
        setState(() {
          transactionId = newId;
        });
      },
      onImagesCleared: () {
        setState(() {
          stoveImage = null;
          agreedDocumentImage = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(
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
          child: UserFormSections(
            controller: controller,
            transactionId: transactionId,
            signatureController: signatureController,
            stoveImage: stoveImage,
            agreedDocumentImage: agreedDocumentImage,
            onAddressSearch: () => setState(() => isSearchingAddress = true),
            onStoveImageCapture: _handleStoveImageCapture,
            onAgreementImageCapture: _handleAgreementImageCapture,
            onStoveImageDelete: _handleStoveImageDelete,
            onAgreementImageDelete: _handleAgreementImageDelete,
            onSubmit: _handleSubmit,
            formKey: formKey,
          ),
        ),
        SubmissionHandler(
          controller: controller,
          stoveImage: stoveImage,
          agreedDocumentImage: agreedDocumentImage,
          signature: null, // This will be handled internally
          onSubmissionComplete: _clearForm,
        ),
      ],
    );
  }
}
