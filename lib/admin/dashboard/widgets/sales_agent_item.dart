// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/components/avatar/avatar_image_initials.dart';
import 'package:stove_transaction/shared/services/helpers.dart';

class SalesAgentItem extends StatefulWidget {
  String profileImage;
  String name;
  String position;
  String? email;
  bool? active;
  SalesAgentItem({
    super.key,
    required this.name,
    required this.position,
    required this.profileImage,
    this.email,
    this.active = true,
  });

  @override
  State<SalesAgentItem> createState() => _SalesAgentItemState();
}

class _SalesAgentItemState extends State<SalesAgentItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: AppColors.inactiveTextFormFieldColor,
          width: 1.5,
        ),
      ),
      child: Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: Row(
              children: [
                SizedBox(
                  child: widget.profileImage == 'null'
                      ? widget.active == false
                          ? Stack(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.faintPrimaryColor,
                                      width: 1,
                                    ),
                                    color: AppColors.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      Helpers().generateAvatarName(widget.name),
                                      style: TextThemes(context).getTextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        letterSpacing: -2,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0.0,
                                  right: 0.0,
                                  child: Container(
                                      padding: EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 3.0,
                                            spreadRadius: 1.0,
                                          ),
                                        ],
                                      ),
                                      child: SvgPicture.asset(
                                        AppIcons.pending,
                                        height: 12,
                                        width: 12,
                                      )),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.faintPrimaryColor,
                                      width: 1,
                                    ),
                                    color: AppColors.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      Helpers().generateAvatarName(widget.name),
                                      style: TextThemes(context).getTextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        letterSpacing: -2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                      : widget.active == true
                          ? AvatarCircularImageInitials(
                              profileImage: widget.profileImage,
                              name: widget.name,
                            )
                          : Stack(
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    height: 47,
                                    width: 47,
                                    child: Image.network(
                                      widget.profileImage ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (BuildContext context,
                                          Object exception,
                                          StackTrace? stackTrace) {
                                        return Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color:
                                                  AppColors.faintPrimaryColor,
                                              width: 1,
                                            ),
                                            color: AppColors.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              Helpers().generateAvatarName(
                                                  widget.name),
                                              style: TextThemes(context)
                                                  .getTextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                letterSpacing: -2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0.0,
                                  right: 0.0,
                                  child: Container(
                                    padding: EdgeInsets.all(4.0),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 3.0,
                                          spreadRadius: 1.0,
                                        ),
                                      ],
                                    ),
                                    child: SvgPicture.asset(
                                      AppIcons.pending,
                                      height: 12,
                                      width: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
                SizedBox(
                  width: 10,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextThemes(context).getTextStyle(
                        color: AppColors.primaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(
                      height: 2,
                    ),
                    Text(
                      widget.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextThemes(context).getTextStyle(
                        color: AppColors.secondaryTextColor,
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
          Flexible(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.17),
                borderRadius: BorderRadius.circular(
                  100,
                ),
              ),
              child: widget.email == null || widget.email!.isEmpty
                  ? SvgPicture.asset(
                      AppIcons.emailIcon,
                      color: AppColors.primaryColor,
                    )
                  : SizedBox(
                      child: Text(
                        '${widget.position}',
                        overflow: TextOverflow.ellipsis,
                        style: TextThemes(context)
                            .getTextStyle(color: AppColors.primaryColor),
                      ),
                    ),
            ),
          )
        ],
      ),
    );
  }
}
