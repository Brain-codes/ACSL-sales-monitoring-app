import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

/// Temporary screen for routes that exist in the permission model + sidebar but
/// whose UI is not built yet. Replaced per-route during Phase 1/2.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              '$title — coming soon',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
