// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, must_be_immutable

import 'package:stove_transaction/core/constants/app_icons.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsTiles extends StatelessWidget {
  String buttonValue;
  String iconValue;
  String descripionValue;

  SettingsTiles(
      {super.key,
      required this.buttonValue,
      required this.iconValue,
      required this.descripionValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.inactiveTextFormFieldColor, width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 15.0,
          bottom: 15,
          left: 10,
          right: 10,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  iconValue,
                ),
                SizedBox(
                  width: 15,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buttonValue,
                      style: TextThemes(context).getTextStyle(
                        color: AppColors.primaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    Text(
                      descripionValue,
                      style: TextThemes(context).getTextStyle(
                        color: AppColors.secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SvgPicture.asset(
              AppIcons.rightArrow,
              color: AppColors.secondaryTextColor,
            )
          ],
        ),
      ),
    );
  }
}
