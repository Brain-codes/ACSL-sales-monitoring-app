import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/services/helpers.dart';

class ActivityListItem extends StatelessWidget {
  final SalesHistoryModel history;
  final VoidCallback? onTap;

  const ActivityListItem({
    Key? key,
    required this.history,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action type indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _getActionTypeColor(history.actionType).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActionTypeIcon(history.actionType),
                  color: _getActionTypeColor(history.actionType),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action description
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
                    const SizedBox(height: 4),

                    // Sale info
                    if (history.sale != null) ...[
                      Text(
                        'Transaction: ${history.sale!.transactionId ?? 'N/A'}',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                      if (history.sale!.contactPerson != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Contact: ${history.sale!.contactPerson}',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                      if (history.sale!.amount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Amount: ₦${Helpers.formatAmount(history.sale!.amount)}',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 8),

                    // Bottom row with performer and time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Performer info
                        if (history.performer != null)
                          Expanded(
                            child: Text(
                              'By ${history.performer!.fullName ?? history.performer!.email ?? 'Unknown'}',
                              style: TextThemes(context).getTextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Time
                        Text(
                          _formatTime(history.performedAt),
                          style: TextThemes(context).getTextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _getActionTypeColor(history.actionType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getActionTypeColor(history.actionType)
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _getActionTypeDisplayName(history.actionType),
                  style: TextThemes(context).getTextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getActionTypeColor(history.actionType),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        return Colors.grey;
    }
  }

  IconData _getActionTypeIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'assigned':
        return Icons.assignment_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _getActionTypeDisplayName(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'created':
        return 'Created';
      case 'updated':
        return 'Updated';
      case 'completed':
        return 'Completed';
      case 'assigned':
        return 'Assigned';
      case 'deleted':
        return 'Deleted';
      default:
        return actionType.toUpperCase();
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
