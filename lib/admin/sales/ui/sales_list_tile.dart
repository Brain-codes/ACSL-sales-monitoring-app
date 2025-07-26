// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/services/helpers.dart';

class SalesListTile extends StatelessWidget {
  final SaleModel sale;
  final VoidCallback onTap;

  const SalesListTile({
    Key? key,
    required this.sale,
    required this.onTap,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.successColor;
      case 'assigned':
        return AppColors.primaryColor;
      case 'pending':
        return Color(0xFFC59400);
      case 'incomplete':
        return AppColors.errorColor;
      default:
        return AppColors.primaryTextColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale.partnerName ?? '',
                style: TextThemes(context).getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'ID: ${sale.id}',
                style: TextThemes(context).getTextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              // if (sale.agentName != null)
              //   Padding(
              //     padding: const EdgeInsets.only(top: 4.0),
              //     child: Text(
              //       'Agent: ${sale.agentName}',
              //       style: TextThemes(context).getTextStyle(
              //         fontSize: 14,
              //         color: AppColors.secondaryTextColor,
              //       ),
              //     ),
              //   ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Helpers.formatDate(sale.createdAt ?? DateTime.now()),
                    style: TextThemes(context).getTextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sale.status ?? 'incomplete')
                          .withOpacity(0.2),
                      border: Border.all(
                        color: _getStatusColor(sale.status ?? 'incomplete'),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      (sale.status ?? 'incomplete').toUpperCase(),
                      style: TextThemes(context).getTextStyle(
                        fontSize: 12,
                        color: _getStatusColor(sale.status ?? 'incomplete'),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
