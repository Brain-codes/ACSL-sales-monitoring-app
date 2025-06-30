import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class PageHeaderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final CrossAxisAlignment crossAxisAlignment;
  final double titleFontSize;
  const PageHeaderTile({
    super.key,
    required this.title,
    this.subtitle = '',
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.titleFontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: crossAxisAlignment == CrossAxisAlignment.start
              ? TextAlign.left
              : TextAlign.center,
          style: TextThemes(context).getTextStyle(
            height: 1.2,
            fontWeight: FontWeight.w700,
            fontSize: titleFontSize,
            color: AppColors.primaryTextColor,
          ),
        ),
        SizedBox(
          child: subtitle.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    subtitle,
                    textAlign: crossAxisAlignment == CrossAxisAlignment.start
                        ? TextAlign.left
                        : TextAlign.center,
                    style: TextThemes(context).getTextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
