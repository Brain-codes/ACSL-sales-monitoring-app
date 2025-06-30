// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class DashboardActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback onTap;
  final Color? backgroundColor;

  const DashboardActionTile({
    Key? key,
    required this.icon,
    required this.title,
    this.description,
    required this.onTap,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.all(16.0),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppColors.primaryColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.white,
                  width: 0.2,
                ),
              ),
              child: Icon(
                icon,
                color: AppColors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  if (description != null && description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description!,
                        overflow: TextOverflow.ellipsis,
                        style: TextThemes(context).getTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: backgroundColor ?? AppColors.primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
