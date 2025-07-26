import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'dart:io';

class ImageUploadWidget extends StatelessWidget {
  final File? imageFile;
  final String? existingImageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onRetake;
  final VoidCallback? onDelete;

  const ImageUploadWidget({
    Key? key,
    required this.imageFile,
    this.existingImageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onRetake,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return imageFile != null
        ? _buildImagePreview(context)
        : existingImageUrl != null
            ? _buildExistingImagePreview(context)
            : _buildUploadContainer(context);
  }

  Widget _buildImagePreview(BuildContext context) {
    return Flex(
      direction: Axis.horizontal,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              width: 130,
              height: 130,
              child: Image.file(
                imageFile!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        SizedBox(width: 15),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Flex(
              direction: Axis.horizontal,
              children: [
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                      SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (onRetake != null)
                            GestureDetector(
                              onTap: onRetake,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'Retake',
                                  style: TextThemes(context).getTextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ),
                          if (onDelete != null)
                            GestureDetector(
                              onTap: onDelete,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'Delete',
                                  style: TextThemes(context).getTextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                    color: AppColors.red,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadContainer(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Flex(
          direction: Axis.horizontal,
          children: [
            SvgPicture.asset(AppIcons.imageIcon),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextThemes(context).getTextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextThemes(context).getTextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingImagePreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border.all(color: AppColors.inactiveTextFormFieldColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                existingImageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.error, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextThemes(context).getTextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                Text(
                  'Current image - Tap to change',
                  overflow: TextOverflow.ellipsis,
                  style: TextThemes(context).getTextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 10,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.camera_alt,
                color: AppColors.primaryColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
