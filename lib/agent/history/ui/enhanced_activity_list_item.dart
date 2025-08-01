import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/services/helpers.dart';

class EnhancedActivityListItem extends StatelessWidget {
  final SalesHistoryModel history;
  final VoidCallback? onTap;
  final bool showSaleInfo;

  const EnhancedActivityListItem({
    Key? key,
    required this.history,
    this.onTap,
    this.showSaleInfo = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getActionTypeColor(history.actionType).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Action Type Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _getActionTypeColor(history.actionType)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getActionIcon(history.actionType),
                      color: _getActionTypeColor(history.actionType),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getActionTypeColor(history.actionType),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatActionType(history.actionType),
                                style: TextThemes(context).getTextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Helpers.formatDateTime(history.performedAt,
                                  showFullDate: false),
                              style: TextThemes(context).getTextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          history.actionDescription,
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Sale Information (if available and showSaleInfo is true)
              if (showSaleInfo && history.sale != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.point_of_sale,
                            size: 16,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sale Information',
                            style: TextThemes(context).getTextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSaleDetailItem(
                              'Customer',
                              history.sale!.endUserName ?? 'N/A',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSaleDetailItem(
                              'Amount',
                              'GHS ${history.sale!.amount}',
                            ),
                          ),
                        ],
                      ),
                      if (history.sale!.stoveSerialNo != null) ...[
                        const SizedBox(height: 8),
                        _buildSaleDetailItem(
                          'Stove Serial',
                          history.sale!.stoveSerialNo!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Performer Information
              if (history.performer != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'By ${history.performer!.fullName ?? "Unknown User"}',
                      style: TextThemes(context).getTextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                    if (history.performer!.role != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryTextColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          history.performer!.role!.toUpperCase(),
                          style: TextThemes(context).getTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Field Changes Indicator
              if (history.fieldChanges != null &&
                  history.fieldChanges!.isNotEmpty &&
                  history.actionType == 'updated') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${history.fieldChanges!.length} field${history.fieldChanges!.length == 1 ? '' : 's'} changed',
                      style: TextThemes(context).getTextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextThemes(Get.context!).getTextStyle(
            fontSize: 10,
            color: AppColors.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextThemes(Get.context!).getTextStyle(
            fontSize: 12,
            color: AppColors.primaryTextColor,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getActionTypeColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'assigned':
        return Colors.orange;
      case 'deleted':
        return Colors.red;
      default:
        return AppColors.primaryColor;
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Icons.add_circle;
      case 'updated':
        return Icons.edit;
      case 'completed':
        return Icons.check_circle;
      case 'assigned':
        return Icons.person_add;
      case 'deleted':
        return Icons.delete;
      default:
        return Icons.history;
    }
  }

  String _formatActionType(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return 'CREATED';
      case 'updated':
        return 'UPDATED';
      case 'completed':
        return 'COMPLETED';
      case 'assigned':
        return 'ASSIGNED';
      case 'deleted':
        return 'DELETED';
      default:
        return actionType.toUpperCase();
    }
  }
}
