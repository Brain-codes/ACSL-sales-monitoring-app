import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/admin/sales/controller/offline_sales_controller.dart';
import 'package:stove_transaction/admin/sales/model/offline_sale_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';
import 'package:stove_transaction/agent/sales_form/widgets/custom_textfield.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';

class OfflineSalesScreen extends StatelessWidget {
  final OfflineSalesController controller = Get.put(OfflineSalesController());

  OfflineSalesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(
        title: "Offline Sales",
        otherWidgets: Obx(() {
          final stats = controller.statistics;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${stats['pending']} pending',
              style: TextThemes(context).getTextStyle(
                fontSize: 12,
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ),
      body: Column(
        children: [
          // Sync Summary Card
          _buildSyncSummaryCard(context),

          // Filter and Search
          _buildFilterAndSearch(context),

          // Statistics Row
          _buildStatisticsRow(context),

          // Offline Sales List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (controller.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.errorColor),
                      SizedBox(height: 16),
                      Text(
                        'Error',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.errorColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        controller.errorMessage.value,
                        style: TextThemes(context).getTextStyle(
                          fontSize: 14,
                          color: AppColors.secondaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => controller.refreshOfflineData(),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final filteredSales = controller.filteredOfflineSales;
              final filteredEdits = controller.filteredOfflineSaleEdits;

              if (filteredSales.isEmpty && filteredEdits.isEmpty) {
                return _buildEmptyState(context);
              }

              return RefreshIndicator(
                onRefresh: controller.refreshOfflineData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredSales.length + filteredEdits.length,
                  itemBuilder: (context, index) {
                    if (index < filteredSales.length) {
                      // Show offline sales
                      final sale = filteredSales[index];
                      return _buildOfflineSaleCard(context, sale);
                    } else {
                      // Show offline edits
                      final edit = filteredEdits[index - filteredSales.length];
                      return _buildOfflineSaleEditCard(context, edit);
                    }
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: _buildSyncFAB(context),
    );
  }

  Widget _buildSyncSummaryCard(BuildContext context) {
    return Obx(() {
      final syncSummary = controller.syncSummary;
      final isSyncing = syncSummary['isSyncing'] ?? false;
      final syncStatus = syncSummary['syncStatus'] ?? '';
      final totalUnsynced = syncSummary['totalUnsynced'] ?? 0;

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGrey, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSyncing ? Icons.sync : Icons.cloud_upload,
                  color: isSyncing
                      ? AppColors.primaryColor
                      : AppColors.secondaryTextColor,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSyncing ? 'Syncing...' : 'Sync Status',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ),
                if (totalUnsynced > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalUnsynced',
                      style: TextThemes(context).getTextStyle(
                        fontSize: 12,
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (syncStatus.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                syncStatus,
                style: TextThemes(context).getTextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            ],
            if (isSyncing) ...[
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: syncSummary['totalItemsToSync'] > 0
                    ? syncSummary['syncProgress'] /
                        syncSummary['totalItemsToSync']
                    : null,
                backgroundColor: AppColors.lightGrey,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryColor),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildFilterAndSearch(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search Field
          CustomTextField(
            controller: controller.searchController,
            label: 'Search sales...',
            hintText: 'Search by name, phone, stove serial, etc.',
            prefixIcon: SizedBox(
              width: 20,
              height: 20,
              child: SvgPicture.asset(
                AppIcons.searchIcon,
                fit: BoxFit.scaleDown,
              ),
            ),
            suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: controller.clearSearch,
                  )
                : SizedBox.shrink()),
          ),
          SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'All', 'all'),
                SizedBox(width: 8),
                _buildFilterChip(context, 'Ready to Sync', 'ready'),
                SizedBox(width: 8),
                _buildFilterChip(context, 'Pending', 'pending'),
                SizedBox(width: 8),
                _buildFilterChip(context, 'Synced', 'synced'),
                SizedBox(width: 8),
                _buildFilterChip(context, 'Failed', 'failed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value) {
    return Obx(() {
      final isSelected = controller.selectedFilter.value == value;
      return FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => controller.setFilter(value),
        backgroundColor: AppColors.lightGrey,
        selectedColor: AppColors.primaryColor.withOpacity(0.2),
        checkmarkColor: AppColors.primaryColor,
        labelStyle: TextThemes(context).getTextStyle(
          fontSize: 12,
          color: isSelected
              ? AppColors.primaryColor
              : AppColors.secondaryTextColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    });
  }

  Widget _buildStatisticsRow(BuildContext context) {
    return Obx(() {
      final stats = controller.statistics;
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStatCard(
                context, 'Total', stats['total']!, AppColors.primaryColor),
            SizedBox(width: 12),
            _buildStatCard(
                context, 'Pending', stats['pending']!, AppColors.warningColor),
            SizedBox(width: 12),
            _buildStatCard(
                context, 'Synced', stats['synced']!, AppColors.successColor),
            SizedBox(width: 12),
            _buildStatCard(
                context, 'Failed', stats['failed']!, AppColors.errorColor),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(
      BuildContext context, String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextThemes(context).getTextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextThemes(context).getTextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSaleCard(BuildContext context, OfflineSaleModel sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: AppColors.primaryColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sale.endUserName ?? 'Unknown Customer',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ),
                _buildStatusChip(context, sale.displayStatus,
                    _getStatusColor(sale.syncStatus)),
              ],
            ),
            SizedBox(height: 8),
            if (sale.stoveSerialNo != null) ...[
              _buildDetailRow(context, 'Stove Serial', sale.stoveSerialNo!),
            ],
            if (sale.phone != null) ...[
              _buildDetailRow(context, 'Phone', sale.phone!),
            ],
            _buildDetailRow(
                context, 'Created', _formatDateTime(sale.createdOfflineAt)),
            if (sale.syncError != null) ...[
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: AppColors.errorColor, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sale.syncError!,
                        style: TextThemes(context).getTextStyle(
                          fontSize: 12,
                          color: AppColors.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                if (sale.syncStatus == 'pending' && sale.isReadyForSync) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          controller.syncSingleOfflineSale(sale.offlineId),
                      icon: Icon(Icons.sync, size: 16),
                      label: Text('Sync Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                PopupMenuButton<String>(
                  onSelected: (value) => _handleSaleAction(sale, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 16),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (sale.syncStatus == 'failed') ...[
                      PopupMenuItem(
                        value: 'retry',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 8),
                            Text('Retry Sync'),
                          ],
                        ),
                      ),
                    ],
                    if (sale.syncStatus == 'synced') ...[
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                size: 16, color: AppColors.errorColor),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: AppColors.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ],
                  child: Icon(Icons.more_vert),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSaleEditCard(
      BuildContext context, OfflineSaleEditModel edit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: AppColors.warningColor, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sale Edit',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ),
                _buildStatusChip(
                    context, edit.syncStatus, _getStatusColor(edit.syncStatus)),
              ],
            ),
            SizedBox(height: 8),
            _buildDetailRow(context, 'Sale ID', edit.saleId),
            _buildDetailRow(
                context, 'Edited', _formatDateTime(edit.editedOfflineAt)),
            if (edit.syncError != null) ...[
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: AppColors.errorColor, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        edit.syncError!,
                        style: TextThemes(context).getTextStyle(
                          fontSize: 12,
                          color: AppColors.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                if (edit.syncStatus == 'pending') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          controller.syncSingleOfflineSaleEdit(edit.editId),
                      icon: Icon(Icons.sync, size: 16),
                      label: Text('Sync Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningColor,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextThemes(context).getTextStyle(
                fontSize: 12,
                color: AppColors.secondaryTextColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextThemes(context).getTextStyle(
                fontSize: 12,
                color: AppColors.primaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextThemes(context).getTextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: AppColors.secondaryTextColor,
          ),
          SizedBox(height: 16),
          Text(
            'No Offline Sales',
            style: TextThemes(context).getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create sales offline and they will appear here',
            style: TextThemes(context).getTextStyle(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncFAB(BuildContext context) {
    return Obx(() {
      final syncSummary = controller.syncSummary;
      final isSyncing = syncSummary['isSyncing'] ?? false;
      final totalUnsynced = syncSummary['totalUnsynced'] ?? 0;

      if (totalUnsynced == 0) return SizedBox.shrink();

      return FloatingActionButton.extended(
        onPressed: isSyncing ? null : controller.syncAllOfflineData,
        backgroundColor:
            isSyncing ? AppColors.lightGrey : AppColors.primaryColor,
        icon: isSyncing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.white),
              )
            : Icon(Icons.sync, color: AppColors.white),
        label: Text(
          isSyncing ? 'Syncing...' : 'Sync All ($totalUnsynced)',
          style: TextStyle(color: AppColors.white),
        ),
      );
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'synced':
        return AppColors.successColor;
      case 'pending':
        return AppColors.warningColor;
      case 'failed':
        return AppColors.errorColor;
      default:
        return AppColors.secondaryTextColor;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  void _handleSaleAction(OfflineSaleModel sale, String action) {
    switch (action) {
      case 'view':
        // TODO: Implement view details
        Get.snackbar('Info', 'View details not implemented yet');
        break;
      case 'retry':
        controller.syncSingleOfflineSale(sale.offlineId);
        break;
      case 'delete':
        _showDeleteConfirmation(sale);
        break;
    }
  }

  void _showDeleteConfirmation(OfflineSaleModel sale) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Offline Sale'),
        content: Text(
            'Are you sure you want to delete this offline sale? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteOfflineSale(sale.offlineId);
            },
            child:
                Text('Delete', style: TextStyle(color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }
}
