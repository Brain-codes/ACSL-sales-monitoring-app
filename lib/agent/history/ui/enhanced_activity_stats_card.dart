import 'package:flutter/material.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class EnhancedActivityStatsCard extends StatelessWidget {
  final HistoryStatsModel stats;
  final bool showDetailedBreakdown;

  const EnhancedActivityStatsCard({
    Key? key,
    required this.stats,
    this.showDetailedBreakdown = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Overview',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your sales activity summary',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 14,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Total Activities (Prominent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Activities',
                        style: TextThemes(context).getTextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stats.total.toString(),
                        style: TextThemes(context).getTextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                if (showDetailedBreakdown) ...[
                  const SizedBox(height: 20),

                  // Activity Breakdown
                  Row(
                    children: [
                      Expanded(
                        child: _buildActivityTypeCard(
                          context,
                          'Created',
                          stats.created,
                          Icons.add_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActivityTypeCard(
                          context,
                          'Updated',
                          stats.updated,
                          Icons.edit,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildActivityTypeCard(
                          context,
                          'Completed',
                          stats.completed,
                          Icons.check_circle,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActivityTypeCard(
                          context,
                          'Other',
                          stats.total -
                              (stats.created + stats.updated + stats.completed),
                          Icons.more_horiz,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress Bar
                  _buildProgressBar(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeCard(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextThemes(context).getTextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextThemes(context).getTextStyle(
              fontSize: 12,
              color: AppColors.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    if (stats.total == 0) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final createdPercent = stats.created / stats.total;
    final updatedPercent = stats.updated / stats.total;
    final completedPercent = stats.completed / stats.total;
    final otherPercent =
        1 - (createdPercent + updatedPercent + completedPercent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Distribution',
          style: TextThemes(context).getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade200,
          ),
          child: Stack(
            children: [
              // Created
              if (createdPercent > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width *
                        0.8 *
                        createdPercent,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                        topRight:
                            updatedPercent + completedPercent + otherPercent ==
                                    0
                                ? Radius.circular(4)
                                : Radius.zero,
                        bottomRight:
                            updatedPercent + completedPercent + otherPercent ==
                                    0
                                ? Radius.circular(4)
                                : Radius.zero,
                      ),
                    ),
                  ),
                ),
              // Updated
              if (updatedPercent > 0)
                Positioned(
                  left:
                      MediaQuery.of(context).size.width * 0.8 * createdPercent,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width *
                        0.8 *
                        updatedPercent,
                    color: Colors.blue,
                  ),
                ),
              // Completed
              if (completedPercent > 0)
                Positioned(
                  left: MediaQuery.of(context).size.width *
                      0.8 *
                      (createdPercent + updatedPercent),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width *
                        0.8 *
                        completedPercent,
                    color: Colors.purple,
                  ),
                ),
              // Other
              if (otherPercent > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width:
                        MediaQuery.of(context).size.width * 0.8 * otherPercent,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem('Created', Colors.green),
            _buildLegendItem('Updated', Colors.blue),
            _buildLegendItem('Completed', Colors.purple),
            _buildLegendItem('Other', Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}
