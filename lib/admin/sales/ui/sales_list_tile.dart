import 'package:flutter/material.dart';

import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class SalesListTile extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const SalesListTile({
    Key? key,
    required this.sale,
    required this.onTap,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.successColor;
      case 'Assigned':
        return AppColors.primaryColor;
      case 'Pending':
        return AppColors.warningColor;
      case 'Incomplete':
        return AppColors.errorColor;
      default:
        return AppColors.primaryTextColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale.product,
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
              if (sale.agentName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Agent: ${sale.agentName}',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${sale.date.toLocal().toString().split(' ')[0]}',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sale.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      sale.status,
                      style: TextThemes(context).getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(sale.status),
                      ),
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
