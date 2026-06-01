import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outline = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
        : Text(label);

    if (outline) {
      return SizedBox(
        width: width ?? double.infinity,
        child: OutlinedButton(onPressed: loading ? null : onPressed, child: child),
      );
    }
    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(onPressed: loading ? null : onPressed, child: child),
    );
  }
}
