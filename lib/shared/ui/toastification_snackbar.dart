import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

void showErrorToast({

  required String message,
  String? title,
}) {
  toastification.show(
    type: ToastificationType.error,
    style: ToastificationStyle.flatColored,
    title: Text(title ?? 'Error'),
    description: Text(message),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 4),
    showProgressBar: false,
    applyBlurEffect: true,
  );
}

void showSuccessToast({
  required String message,
  String? title,
}) {
  toastification.show(
    type: ToastificationType.success,
    style: ToastificationStyle.flatColored,
    title: Text(title ?? 'Success'),
    description: Text(message),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 4),
    showProgressBar: false,
    applyBlurEffect: true,
  );
}

void showInfoToast({
  required String message,
  String? title,
}) {
  toastification.show(
    icon: const Icon(Icons.info),
    type: ToastificationType.info,
    style: ToastificationStyle.flat,
    title: Text(title ?? 'Info'),
    description: Text(message),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 4),
    showProgressBar: false,
    applyBlurEffect: true,
  );
}
