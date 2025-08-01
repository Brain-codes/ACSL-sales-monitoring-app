import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/ui/profile/profile_info_card.dart';
import 'package:stove_transaction/shared/ui/profile/profile_detail_rows.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/services/helpers.dart';

class EnhancedHistoryDetailScreen extends StatelessWidget {
  final SalesHistoryModel history;

  const EnhancedHistoryDetailScreen({
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
            // Activity Header
            _buildActivityHeader(),
            const SizedBox(height: 16),

            // Action Details
            ProfileInfoCard(
              title: 'Action Details',
              icon: _getActionIcon(history.actionType),
              children: [
                ProfileDetailRow(
                  label: 'Action Type',
                  value: _formatActionType(history.actionType),
                ),
                ProfileDetailRow(
                  label: 'Description',
                  value: history.actionDescription,
                ),
                ProfileDetailRow(
                  label: 'Performed At',
                  value: Helpers.formatDateTime(history.performedAt),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sale Information
            if (history.sale != null) ...[
              ProfileInfoCard(
                title: 'Sale Information',
                icon: Icons.point_of_sale,
                children: [
                  ProfileDetailRow(
                    label: 'Transaction ID',
                    value: history.sale!.transactionId ?? 'N/A',
                  ),
                  ProfileDetailRow(
                    label: 'Stove Serial No',
                    value: history.sale!.stoveSerialNo ?? 'N/A',
                  ),
                  ProfileDetailRow(
                    label: 'Customer',
                    value: history.sale!.endUserName ?? 'N/A',
                  ),
                  ProfileDetailRow(
                    label: 'Contact Person',
                    value: history.sale!.contactPerson ?? 'N/A',
                  ),
                  ProfileDetailRow(
                    label: 'Amount',
                    value: 'GHS ${history.sale!.amount}',
                  ),
                  ProfileStatusRow(
                    label: 'Status',
                    value: history.sale!.status?.toUpperCase() ?? 'UNKNOWN',
                    isPositive: history.sale!.status == 'completed',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Performer Information
            if (history.performer != null) ...[
              ProfileInfoCard(
                title: 'Performed By',
                icon: Icons.person,
                children: [
                  ProfileDetailRow(
                    label: 'Name',
                    value: history.performer!.fullName ?? 'Unknown User',
                  ),
                  ProfileDetailRow(
                    label: 'Email',
                    value: history.performer!.email ?? 'N/A',
                  ),
                  ProfileDetailRow(
                    label: 'Role',
                    value: history.performer!.role?.toUpperCase() ?? 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Field Changes
            if (history.fieldChanges != null &&
                history.fieldChanges!.isNotEmpty) ...[
              ProfileInfoCard(
                title: 'Field Changes',
                icon: Icons.edit_note,
                children: _buildFieldChangesList(),
              ),
              const SizedBox(height: 16),
            ],

            // Additional Metadata
            ProfileInfoCard(
              title: 'Activity Metadata',
              icon: Icons.info_outline,
              children: [
                ProfileDetailRow(
                  label: 'Activity ID',
                  value: history.id,
                ),
                ProfileDetailRow(
                  label: 'Sale ID',
                  value: history.saleId,
                ),
                ProfileDetailRow(
                  label: 'Timestamp',
                  value: history.performedAt.toIso8601String(),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getActionTypeColor(history.actionType).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getActionTypeColor(history.actionType).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getActionTypeColor(history.actionType),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getActionIcon(history.actionType),
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatActionType(history.actionType),
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getActionTypeColor(history.actionType),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Helpers.formatDateTime(history.performedAt),
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFieldChangesList() {
    List<Widget> changeWidgets = [];

    history.fieldChanges!.forEach((field, change) {
      if (change is Map<String, dynamic> &&
          change.containsKey('from') &&
          change.containsKey('to')) {
        changeWidgets.add(
          _buildFieldChangeItem(
            field: _formatFieldName(field),
            fromValue: change['from']?.toString() ?? 'null',
            toValue: change['to']?.toString() ?? 'null',
          ),
        );
      }
    });

    if (changeWidgets.isEmpty) {
      changeWidgets.add(
        ProfileDetailRow(
          label: 'Changes',
          value: 'No specific field changes recorded',
        ),
      );
    }

    return changeWidgets;
  }

  Widget _buildFieldChangeItem({
    required String field,
    required String fromValue,
    required String toValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.remove, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fromValue,
                    style: TextThemes(Get.context!).getTextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.add, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    toValue,
                    style: TextThemes(Get.context!).getTextStyle(
                      fontSize: 13,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return actionType
        .split('_')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .split('_')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }
}
