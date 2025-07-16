// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, must_be_immutable, unused_import

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/agent/sales_form/widgets/primary_button.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class ResponseBottomSheet extends StatelessWidget {
  final String message;
  final String title;
  String subtitle;
  final String type;
  final VoidCallback? onTaps;
  final String buttonTitle;
  String icon;
  bool isIconImage;

  ResponseBottomSheet({
    super.key,
    required this.message,
    required this.title,
    this.type = 'info',
    this.subtitle = '',
    required this.onTaps,
    this.buttonTitle = 'Done',
    this.icon = AppIcons.infoBottomSheet,
    this.isIconImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border(
          top: BorderSide(color: AppColors.primaryColor, width: 0.5),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.0),
          topRight: Radius.circular(30.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 10,
            ),
            child: SvgPicture.asset(
              AppIcons.drawrer,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 40,
              bottom: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  child:
                      isIconImage ? Image.asset(icon) : SvgPicture.asset(icon),
                ),
                SizedBox(
                  height: 20,
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextThemes(context).getTextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: 15,
                ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextThemes(context).getTextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(
                  height: 30,
                ),
                PrimaryButton(
                  onPressed: () {
                    onTaps;
                  },
                  text: buttonTitle,
                ),
                SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
