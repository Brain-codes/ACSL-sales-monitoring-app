import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final VoidCallback onCapture;

  const CameraPreviewWidget({
    Key? key,
    required this.cameraController,
    required this.onCapture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: cameraController.value.isInitialized
                ? CameraPreview(cameraController)
                : Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: ElevatedButton(
              onPressed: onCapture,
              child: Icon(Icons.camera_alt, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
