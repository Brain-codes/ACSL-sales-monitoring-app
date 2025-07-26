import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Mixin for handling camera functionality
mixin CameraHandlerMixin<T extends StatefulWidget> on State<T> {
  late CameraController cameraController;
  late List<CameraDescription> _cameras;
  bool hasPermission = false;
  bool isCameraPreviewVisible = false;

  Future<void> checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      hasPermission = true;
      await initializeCamera(false); // Use the rear camera by default
    } else {
      hasPermission = false;
      print('Camera permissions are denied');
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  void resetCameraState() async {
    setState(() {
      isCameraPreviewVisible = false;
      hasPermission = false;
    });
    if (cameraController.value.isInitialized) {
      await cameraController.dispose();
    }
  }

  Future<void> initializeCamera(bool useFrontCamera) async {
    try {
      _cameras = await availableCameras();
      cameraController = CameraController(
        useFrontCamera
            ? _cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.front)
            : _cameras.firstWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back),
        ResolutionPreset.max,
      );

      await cameraController.initialize();
      cameraController.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> captureImage({
    required Function(File imageFile) onImageCaptured,
  }) async {
    try {
      final image = await cameraController.takePicture();
      final imageFile = File(image.path);
      onImageCaptured(imageFile);
      resetCameraState(); // Reset camera state after capturing
    } catch (e) {
      print("Error capturing image: $e");
    }
  }

  Future<void> initiateCameraCapture({
    required Function(File imageFile) onImageCaptured,
  }) async {
    await checkCameraPermission();
    if (hasPermission) {
      await initializeCamera(false);
      setState(() {
        isCameraPreviewVisible = true;
      });
    }
  }

  @override
  void dispose() {
    if (cameraController.value.isInitialized) {
      cameraController.dispose();
    }
    super.dispose();
  }
}
