import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const ProfileDetailRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextThemes(context).getTextStyle(
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
}

class ProfileDetailRowWithEditability extends StatelessWidget {
  final String label;
  final String? value;
  final bool canEdit;

  const ProfileDetailRowWithEditability({
    Key? key,
    required this.label,
    required this.value,
    required this.canEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? 'Not provided',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      color: value != null
                          ? AppColors.primaryTextColor
                          : AppColors.secondaryTextColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Can Edit',
                      style: TextThemes(context).getTextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;

  const ProfileStatusRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isPositive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextThemes(context).getTextStyle(
                    fontSize: 14,
                    color: isPositive ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
