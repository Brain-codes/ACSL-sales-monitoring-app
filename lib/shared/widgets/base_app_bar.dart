// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';

class BaseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showSkipButton;
  final Color? backgroundColor;
  final Color? themeColor;
  final VoidCallback? onActionButtonPressed;
  final VoidCallback? onTaps;
  final bool? searching;
  final String icon;
  final String? title;
  final Widget? otherWidgets;

  const BaseAppBar({
    super.key,
    this.showSkipButton = false,
    this.onActionButtonPressed,
    this.backgroundColor,
    this.themeColor,
    this.onTaps,
    this.searching,
    this.icon = AppIcons.leftArrow,
    this.otherWidgets,
    this.title,
    // this.skipText = AppStrings.skip,
  });
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showSkipButton == true
          ? SizedBox()
          : InkWell(
              onTap: searching == null || searching == false
                  ? () => Navigator.pop(context)
                  : onTaps,
              customBorder: const CircleBorder(),
              child: SvgPicture.asset(
                icon,
                height: 20,
                width: 20,
                fit: BoxFit.scaleDown,
                color: themeColor ?? AppColors.primaryTextColor,
              ),
            ),
      centerTitle: true,
      title: title == null
          ? null
          : Text(
              title ?? '',
              textAlign: TextAlign.center,
              style: TextThemes(context).getTextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: themeColor ?? AppColors.primaryTextColor,
              ),
            ),
      actions: [
        if (showSkipButton)
          IconButton(
            icon: SvgPicture.asset(
              AppIcons.closeIcon,
              fit: BoxFit.scaleDown,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        if (otherWidgets != null)
          SizedBox(
            child: otherWidgets,
          ),
      ],
      backgroundColor: backgroundColor ?? AppColors.white,
      elevation: 0,
    );
  }

  // @override
  // Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
