// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_if_null_operators

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:get/get.dart';

class OptionBottomSheet extends StatelessWidget {
  final List<Widget> items;
  final String title;
  String subtitle;
  final BuildContext? context;
  final bool hasClose;
  final Widget? titleSuffixWidget;
  OptionBottomSheet({
    super.key,
    required this.items,
    required this.title,
    this.subtitle = '',
    this.context,
    this.hasClose = false,
    this.titleSuffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
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
              AppIcons.drawrer,
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
                                      Flex(
                                        direction: Axis.horizontal,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextThemes(context)
                                                  .getTextStyle(
                                                color:
                                                    AppColors.primaryTextColor,
                                                fontSize: 20,
                                                height: 1,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              SizedBox(
                                                child: hasClose
                                                    ? GestureDetector(
                                                        onTap: () {
                                                          Get.back();
                                                        },
                                                        child: SvgPicture.asset(
                                                            AppIcons.closeIcon),
                                                      )
                                                    : null,
                                              ),
                                              if (titleSuffixWidget != null)
                                                titleSuffixWidget!,
                                            ],
                                          )
                                        ],
                                      ),
                                      if (subtitle.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            subtitle,
                                            softWrap: true,
                                            style: TextThemes(context)
                                                .getTextStyle(
                                              color:
                                                  AppColors.secondaryTextColor,
                                              fontWeight: FontWeight.w400,
                                            ),
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
