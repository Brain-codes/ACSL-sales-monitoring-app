import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class HistoryDetailScreen extends StatelessWidget {
  final SalesHistoryModel history;

  const HistoryDetailScreen({
    Key? key,
    required this.history,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: BaseAppBar(title: 'Activity Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Summary Card
            _buildActionSummaryCard(),
            const SizedBox(height: 16),

            // Sale Information Card
            if (history.sale != null) ...[
              _buildSaleInfoCard(),
              const SizedBox(height: 16),
            ],

            // Performer Information Card
            if (history.performer != null) ...[
              _buildPerformerInfoCard(),
              const SizedBox(height: 16),
            ],

            // Field Changes Card
            if (history.fieldChanges != null &&
                history.fieldChanges!.isNotEmpty) ...[
              _buildFieldChangesCard(),
              const SizedBox(height: 16),
            ],

            // Timestamp Card
            _buildTimestampCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      _getActionTypeColor(history.actionType).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActionTypeIcon(history.actionType),
                  color: _getActionTypeColor(history.actionType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getActionTypeDisplayName(history.actionType),
                      style: TextThemes(Get.context!).getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.actionDescription,
                      style: TextThemes(Get.context!).getTextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sale Information',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
              'Transaction ID', history.sale!.transactionId ?? 'N/A'),
          _buildDetailRow('Stove Serial', history.sale!.stoveSerialNo ?? 'N/A'),
          _buildDetailRow(
              'Contact Person', history.sale!.contactPerson ?? 'N/A'),
          _buildDetailRow('End User', history.sale!.endUserName ?? 'N/A'),
          _buildDetailRow('Amount', 'GHS ${history.sale!.amount}'),
          _buildDetailRow('Status', history.sale!.status ?? 'N/A',
              isLast: true),
        ],
      ),
    );
  }

  Widget _buildPerformerInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performed By',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Name', history.performer!.fullName ?? 'N/A'),
          _buildDetailRow('Email', history.performer!.email ?? 'N/A'),
          _buildDetailRow(
              'Role', (history.performer!.role ?? 'N/A').toUpperCase(),
              isLast: true),
        ],
      ),
    );
  }

  Widget _buildFieldChangesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Field Changes',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          ...history.fieldChanges!.entries.map((entry) {
            final change = entry.value as Map<String, dynamic>;
            return _buildChangeRow(
              _formatFieldName(entry.key),
              change['from']?.toString() ?? 'N/A',
              change['to']?.toString() ?? 'N/A',
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimestampCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timestamp',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Date & Time', _formatFullDate(history.performedAt)),
          _buildDetailRow(
              'Relative Time', _formatRelativeTime(history.performedAt),
              isLast: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextThemes(Get.context!).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextThemes(Get.context!).getTextStyle(
                fontSize: 14,
                color: AppColors.primaryTextColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeRow(String field, String from, String to) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'From: $from',
                    style: TextThemes(Get.context!).getTextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward,
                  size: 16, color: AppColors.secondaryTextColor),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'To: $to',
                    style: TextThemes(Get.context!).getTextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatFullDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return 'More than a week ago';
    }
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
        return 'Sale Created';
      case 'updated':
        return 'Sale Updated';
      case 'completed':
        return 'Sale Completed';
      case 'assigned':
        return 'Sale Assigned';
      case 'deleted':
        return 'Sale Deleted';
      default:
        return actionType.toUpperCase();
    }
  }
}
