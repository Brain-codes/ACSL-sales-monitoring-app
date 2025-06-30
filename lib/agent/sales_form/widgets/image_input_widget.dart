import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class ImageInputWidget extends StatelessWidget {
  final String label;
  final String? imagePath;
  final ValueChanged<String> onImagePicked;

  const ImageInputWidget({
    Key? key,
    required this.label,
    this.imagePath,
    required this.onImagePicked,
  }) : super(key: key);

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      onImagePicked(image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextThemes(context).getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(context),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: imagePath != null && imagePath!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    ),
                  )
                : Icon(
                    Icons.camera_alt,
                    color: AppColors.secondaryTextColor,
                    size: 40,
                  ),
          ),
        ),
      ],
    );
  }
}
