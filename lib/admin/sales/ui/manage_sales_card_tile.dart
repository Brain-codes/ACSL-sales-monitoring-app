// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/controller/update_sale_controller.dart';
import 'package:stove_transaction/admin/sales/ui/update_sale_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/bottom_sheet_item.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/option_bottom_sheet.dart';
import 'package:stove_transaction/shared/services/helpers.dart';

class ManageSalesCardTile extends StatelessWidget {
  final SaleModel saleData;
  const ManageSalesCardTile({super.key, required this.saleData});

  _salesMoreOption(SaleModel saleData) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return OptionBottomSheet(
          title: saleData.stoveSerialNo ?? 'Options',
          subtitle: 'Select an action you\'d like to perform',
          hasClose: true,
          items: [
            BottomSheetItem(
              icon: AppIcons.profile,
              title: 'Assign Agent',
              subtitle: 'Assign this sales to one of your agents',
              onTap: () {},
            ),
            BottomSheetItem(
              icon: AppIcons.editPenIcon,
              title: 'Update Sales Data',
              subtitle: 'Update details of your this sale',
              onTap: () {
                Get.back(); // Close bottom sheet

                // Remove existing controller if it exists to ensure fresh state
                if (Get.isRegistered<UpdateSaleController>()) {
                  Get.delete<UpdateSaleController>();
                }

                Get.to(() => UpdateSaleScreen(), arguments: {'sale': saleData});
              },
            ),
            BottomSheetItem(
              icon: AppIcons.trashIconFilled,
              title: 'Delete Sale',
              subtitle: 'What happens after this prompt?',
              onTap: () async {},
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                child: Flex(
                  direction: Axis.horizontal,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(1000),
                        border: Border.all(
                          color: AppColors.white,
                          width: 0.2,
                        ),
                      ),
                      child: SvgPicture.asset(
                        AppIcons.salesIcon,
                        colorFilter: ColorFilter.mode(
                          AppColors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            saleData.stoveSerialNo ?? 'N/A',
                            style: TextThemes(context).getTextStyle(
                              fontSize: 14,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (saleData.status?.toLowerCase() ==
                                      'completed')
                                  ? AppColors.green.withOpacity(0.1)
                                  : AppColors.red.withOpacity(0.1),
                              border: Border.all(
                                color: AppColors.white,
                                width: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${saleData.status}',
                              style: TextThemes(context).getTextStyle(
                                fontSize: 10,
                                color: (saleData.status?.toLowerCase() ==
                                        'completed')
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  _salesMoreOption(saleData);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.white,
                      width: 0.2,
                    ),
                  ),
                  child: Transform.rotate(
                    angle: 90 * 3.14 / 180, // Rotate the icon 90 degrees
                    child: SvgPicture.asset(
                      AppIcons.moreIcon,
                      colorFilter: ColorFilter.mode(
                        AppColors.primaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 10),
            padding: EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.primaryColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
          ),
          Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  saleData.id,
                  overflow: TextOverflow.ellipsis,
                  style: TextThemes(context).getTextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  Helpers.formatDate(saleData.createdAt ?? DateTime.now()),
                  style: TextThemes(context).getTextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
