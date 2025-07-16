// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BaseBottomSheet extends StatelessWidget {
  final List<Widget> items;
  final String title;
  String subtitle;
  final BuildContext? context;
  final bool hasMode;
  final String modeValue;
  BaseBottomSheet({
    super.key,
    required this.items,
    required this.title,
    this.subtitle = '',
    this.context,
    this.hasMode = false,
    this.modeValue = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10.0),
          topRight: Radius.circular(10.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            alignment: Alignment.center,
            height: 20,
            child: SvgPicture.asset(
              AppIcons.topDash,
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 20,
            ),
            child: Column(
              children: [
                SizedBox(
                  child: title.isNotEmpty
                      ? Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            title,
                                            style: TextThemes(context)
                                                .getTextStyle(
                                                    color: AppColors
                                                        .primaryTextColor,
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w700),
                                          ),
                                          SizedBox(
                                            child: hasMode
                                                ? Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 10,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.orange
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        200,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      modeValue,
                                                      style: TextThemes(context)
                                                          .getTextStyle(
                                                        color: AppColors.orange,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          )
                                        ],
                                      ),
                                      if (subtitle.isNotEmpty)
                                        Text(
                                          subtitle,
                                          softWrap: true,
                                          style:
                                              TextThemes(context).getTextStyle(
                                            color: AppColors.secondaryTextColor,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 20,
                            ),
                          ],
                        )
                      : null,
                ),
                Column(
                  children: items,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
