import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/utils/formatters.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/settings/payment_models_provider.dart';

/// Global payment models. Single screen for all roles; create/edit self-gates
/// by the `paymentModels` feature (super admin has it).
class PaymentModelsScreen extends ConsumerWidget {
  const PaymentModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentModelsProvider);
    final canManage = ref.watch(permissionsProvider).can(FeatureKey.paymentModels);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Models')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create payment model — coming next.')),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Model'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          message: '$e',
          icon: Icons.error_outline,
          actionLabel: 'Retry',
          onAction: () => ref.read(paymentModelsProvider.notifier).refresh(),
        ),
        data: (models) {
          if (models.isEmpty) {
            return const EmptyState(message: 'No payment models found.', icon: Icons.payments_outlined);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(paymentModelsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: models.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ModelCard(model: models[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});
  final PaymentModel model;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.name, style: Theme.of(context).textTheme.titleMedium),
            if (model.description != null && model.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(model.description!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(icon: Icons.sell_outlined, label: formatNaira(model.fixedPrice)),
                _Tag(icon: Icons.schedule_outlined, label: '${model.durationMonths} months'),
                _Tag(icon: Icons.account_balance_wallet_outlined, label: 'Down ${formatNaira(model.minDownPayment)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
