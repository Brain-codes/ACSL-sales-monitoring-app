// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class CustomCheckbox extends StatelessWidget {
  final RxBool value;
  final String text;
  final String? linkText;
  final VoidCallback? onLinkTap;

  const CustomCheckbox({
    Key? key,
    required this.value,
    required this.text,
    this.linkText,
    this.onLinkTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Obx(
          () => Checkbox(
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color: AppColors.primaryColor,
              width: 0.5,
            ),
            value: value.value,
            onChanged: (newValue) {
              value.value = newValue!;
            },
            activeColor: AppColors.primaryColor,
          ),
        ),
        Text(
          text,
          style: TextThemes(context).getTextStyle(
            fontSize: 14,
            color: AppColors.secondaryTextColor,
          ),
        ),
        if (linkText != null)
          TextButton(
            onPressed: onLinkTap,
            child: Text(
              linkText!,
              style: TextThemes(context).getTextStyle(
                color: AppColors.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
