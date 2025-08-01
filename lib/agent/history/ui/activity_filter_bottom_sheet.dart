import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/controller/sales_history_controller.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class ActivityFilterBottomSheet extends StatelessWidget {
  final SalesHistoryController controller;

  const ActivityFilterBottomSheet({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Activities',
                style: TextThemes(context).getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMedium),
                onPressed: () => Get.back(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Type Filter
          Text(
            'Action Type',
            style: TextThemes(context).getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildActionTypeChip('All', null),
                  _buildActionTypeChip('Created', 'created'),
                  _buildActionTypeChip('Updated', 'updated'),
                  _buildActionTypeChip('Completed', 'completed'),
                  _buildActionTypeChip('Assigned', 'assigned'),
                ],
              )),
          const SizedBox(height: 24),

          // Date Range Filter
          Text(
            'Date Range',
            style: TextThemes(context).getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Row(
                    children: [
                      const Icon(Icons.date_range,
                          color: AppColors.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          controller.selectedDateRange.value != null
                              ? '${_formatDate(controller.selectedDateRange.value!.start)} - ${_formatDate(controller.selectedDateRange.value!.end)}'
                              : 'Select date range',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            color: controller.selectedDateRange.value != null
                                ? AppColors.primaryTextColor
                                : AppColors.secondaryTextColor,
                          ),
                        ),
                      ),
                      if (controller.selectedDateRange.value != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => controller.filterByDateRange(null),
                        ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    controller.clearFilters();
                    Get.back();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Clear All',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionTypeChip(String label, String? value) {
    final isSelected = controller.selectedActionType.value == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        controller.filterByActionType(selected ? value : null);
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primaryColor : const Color(0xFFE0E0E0),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: Get.context!,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: controller.selectedDateRange.value,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.filterByDateRange(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
