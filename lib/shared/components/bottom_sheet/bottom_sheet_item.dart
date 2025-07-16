// ignore_for_file: prefer_typing_uninitialized_variables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';


class BottomSheetItem extends StatelessWidget {
  final icon;
  final title;
  final subtitle;
  Color color = AppColors.secondaryTextColor;
  final void Function() onTap;

  BottomSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.secondaryTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Flex(
          direction: Axis.horizontal,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(
                  color: AppColors.inactiveTextFormFieldColor,
                ),
                borderRadius: BorderRadius.circular(1000),
              ),
              child: SvgPicture.asset(
                icon,
                fit: BoxFit.scaleDown,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextThemes(context).getTextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.primaryTextColor,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextThemes(context).getTextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: AppColors.secondaryTextColor,
                      height: 1,
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
}
