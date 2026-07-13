import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/router/route_meta.dart';

/// Shown when the current role lacks permission for a route.
class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('Access denied', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                "You don't have permission to view this page.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(tabRoutes.first.path),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
