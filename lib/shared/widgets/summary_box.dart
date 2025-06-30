// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class SummaryBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? backgroundColor;
  final double? width;

  const SummaryBox({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.backgroundColor,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor?.withOpacity(0.1) ??
            AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: backgroundColor?.withOpacity(0.2) ??
              AppColors.primaryColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor?.withOpacity(0.7) ??
                  AppColors.primaryColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(1000),
              border: Border.all(
                color: AppColors.white,
                width: 0.2,
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            title,
            style: TextThemes(context).getTextStyle(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextThemes(context).getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
