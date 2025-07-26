import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/form/controller/form_controller.dart';
import 'package:stove_transaction/shared/components/loading/loading_positioned_full_screen.dart';

/// Handles form submission with dynamic status updates
class SubmissionHandler extends StatelessWidget {
  final FormController controller;
  final File? stoveImage;
  final File? agreedDocumentImage;
  final String? signature;
  final VoidCallback onSubmissionComplete;

  const SubmissionHandler({
    Key? key,
    required this.controller,
    this.stoveImage,
    this.agreedDocumentImage,
    this.signature,
    required this.onSubmissionComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isLoading.value) {
        return const SizedBox.shrink();
      }

      return LoadingPositionedFullScreen(
        title: _getCurrentLoadingMessage(),
      );
    });
  }

  String _getCurrentLoadingMessage() {
    // Get the current submission status from the controller
    return controller.submissionStatus.value.isNotEmpty
        ? controller.submissionStatus.value
        : 'Preparing submission...';
  }
}
