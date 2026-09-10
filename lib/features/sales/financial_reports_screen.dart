import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/utils/formatters.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/kpi_card.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'package:stove_transaction/features/sales/sales_provider.dart';

/// Financial reports — summary metrics computed client-side from the sales list
/// (works offline from cache). Super admin sees org-wide totals.
class FinancialReportsScreen extends ConsumerWidget {
  const FinancialReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          message: '$e',
          icon: Icons.error_outline,
          actionLabel: 'Retry',
          onAction: () => ref.read(salesProvider.notifier).refresh(),
        ),
        data: (sales) {
          if (sales.isEmpty) {
            return const EmptyState(message: 'No sales to report on yet.', icon: Icons.assessment_outlined);
          }
          final r = _Report.from(sales);
          return RefreshIndicator(
            onRefresh: () => ref.read(salesProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    KpiCard(title: 'Total Sales', value: '${r.count}', icon: Icons.receipt_long, gradient: AppColors.gradientNavy),
                    KpiCard(title: 'Total Value', value: formatNaira(r.totalValue), icon: Icons.sell, gradient: AppColors.gradientTeal),
                    KpiCard(title: 'Collected', value: formatNaira(r.collected), icon: Icons.account_balance_wallet, gradient: AppColors.gradientGreen),
                    KpiCard(title: 'Outstanding', value: formatNaira(r.outstanding), icon: Icons.pending_actions, gradient: AppColors.gradientGold),
                  ],
                ),
                const SizedBox(height: 20),
                Text('By payment status',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...r.byStatus.entries.map((e) => _StatusRow(label: e.key, count: e.value, total: r.count)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Report {
  _Report({
    required this.count,
    required this.totalValue,
    required this.collected,
    required this.byStatus,
  });

  final int count;
  final double totalValue;
  final double collected;
  final Map<String, int> byStatus;

  double get outstanding => (totalValue - collected).clamp(0, double.infinity);

  factory _Report.from(List<SaleModel> sales) {
    double value = 0;
    double collected = 0;
    final byStatus = <String, int>{};
    for (final s in sales) {
      value += s.amount ?? s.paymentModelFixedPrice ?? 0;
      collected += s.paidAmount;
      // M5: this used to group by `sales.status`, which is the FORM's
      // completeness state ("incomplete", "pending", "assigned") — not payment.
      // On a financial report that read as a money figure, and today every live
      // sale says "Incomplete", so the whole chart said nothing. Group by
      // payment state instead, which is what a financial report is about.
      final status = _paymentBucket(s);
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }
    return _Report(count: sales.length, totalValue: value, collected: collected, byStatus: byStatus);
  }
}

/// Which payment bucket a sale falls in, for the report's chart.
///
/// Prefers the server's `payment_status`; falls back to the money when it says
/// nothing usable. `total_paid` is the collected figure for both sale types and
/// is never substituted with `amount`.
String _paymentBucket(SaleModel s) {
  switch ((s.paymentStatus ?? '').toLowerCase()) {
    case 'fully_paid':
    case 'paid':
      return 'Paid in full';
    case 'partially_paid':
      return 'Partly paid';
    case 'unpaid':
      return 'Unpaid';
  }
  final total = s.amount ?? s.paymentModelFixedPrice;
  final paid = s.paidAmount;
  if (total == null || total <= 0 || paid <= 0) return 'Unpaid';
  if (paid + 0.005 < total) return 'Partly paid';
  return 'Paid in full';
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.count, required this.total});
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.isEmpty ? 'Unknown' : '${label[0].toUpperCase()}${label.substring(1)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.borderColor,
              valueColor: const AlwaysStoppedAnimation(AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
