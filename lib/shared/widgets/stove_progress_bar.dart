import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class StoveProgressBar extends StatelessWidget {
  final int totalReceived;
  final int totalSold;
  final int totalAvailable;

  const StoveProgressBar({
    Key? key,
    required this.totalReceived,
    required this.totalSold,
    required this.totalAvailable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int total =
        totalReceived > 0 ? totalReceived : 1; // Prevent division by zero
    final double soldPercent = totalSold / total;
    final double availablePercent = totalAvailable / total;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stove Inventory Progress',
              style: TextThemes(context).getTextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegend('Received', Colors.blue, totalReceived),
                _buildLegend('Sold', Colors.green, totalSold),
                _buildLegend('Available', Colors.orange, totalAvailable),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: (soldPercent * 100).round(),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius:
                              BorderRadius.horizontal(left: Radius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      flex: (availablePercent * 100).round(),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text('Total: $totalReceived'),
            //     Text('Sold: $totalSold'),
            //     Text('Available: $totalAvailable'),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            // shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${label.toUpperCase()}:',
          style: TextThemes(Get.context!).getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.secondaryTextColor,
            // decoration: TextDecoration.uppercase,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '$value',
          style: TextThemes(Get.context!).getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
            // decoration: TextDecoration.uppercase,
          ),
        ),
      ],
    );
  }
}
