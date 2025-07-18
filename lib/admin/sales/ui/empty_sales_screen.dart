import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';


class EmptySalesScreen extends StatelessWidget {
  const EmptySalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: SvgPicture.asset(
              AppIcons.emptySales,
              fit: BoxFit.scaleDown,
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'No sales found',
            style: TextThemes(context).getTextStyle(
              fontSize: 13,
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(
            height: 30,
          ),
        ],
      ),
    );
    
  }
}