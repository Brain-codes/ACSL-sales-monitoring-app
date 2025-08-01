import 'package:flutter/material.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class ActivityStatsCard extends StatelessWidget {
  final HistoryStatsModel stats;

  const ActivityStatsCard({
    Key? key,
    required this.stats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            'Activity Summary',
            style: TextThemes(context).getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total',
                  stats.total.toString(),
                  Colors.blue,
                  Icons.bar_chart,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Created',
                  stats.created.toString(),
                  Colors.green,
                  Icons.add_circle_outline,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Updated',
                  stats.updated.toString(),
                  Colors.orange,
                  Icons.edit_outlined,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Completed',
                  stats.completed.toString(),
                  Colors.purple,
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextThemes(context).getTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextThemes(context).getTextStyle(
            fontSize: 12,
            color: AppColors.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
