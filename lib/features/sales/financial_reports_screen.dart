import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/utils/formatters.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/kpi_card.dart';
import 'package:stove_transaction/features/sales/sales_summary_provider.dart';

/// Financial reports.
///
/// M8: every figure here used to be added up on the phone from a single
/// 500-row fetch. One response caps at 500 and production holds 2,145 sales,
/// so the whole report was short — and got shorter every day. The totals now
/// come from the server, computed in SQL and scoped to the caller.
class FinancialReportsScreen extends ConsumerWidget {
  const FinancialReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          message: '$e',
          icon: Icons.error_outline,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(salesSummaryProvider),
        ),
        data: (r) {
          if (r.total == 0) {
            return const EmptyState(message: 'No sales to report on yet.', icon: Icons.assessment_outlined);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(salesSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (r.isLocalEstimate) const _EstimateNotice(),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    KpiCard(title: 'Total Sales', value: '${r.total}', icon: Icons.receipt_long, gradient: AppColors.gradientNavy),
                    KpiCard(title: 'Total Value', value: formatNaira(r.receivable), icon: Icons.sell, gradient: AppColors.gradientTeal),
                    KpiCard(title: 'Collected', value: formatNaira(r.collected), icon: Icons.account_balance_wallet, gradient: AppColors.gradientGreen),
                    KpiCard(title: 'Outstanding', value: formatNaira(r.outstanding), icon: Icons.pending_actions, gradient: AppColors.gradientGold),
                  ],
                ),
                const SizedBox(height: 20),
                Text('By payment status',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // M5: was grouped by sales.status — the FORM's completeness
                // state, not payment — so every live sale read "Incomplete" on
                // a financial report. These counts are payment states, and the
                // server counts them.
                _StatusRow(label: 'Paid in full', count: r.fullyPaid, total: r.total),
                _StatusRow(label: 'Partly paid', count: r.partiallyPaid, total: r.total),
                _StatusRow(label: 'Unpaid', count: r.unpaid, total: r.total),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown when the figures were added up on the device because the server could
/// not be reached. The device holds a fraction of the sales, so these are a
/// floor rather than a total, and saying so is the whole point of this banner.
class _EstimateNotice extends StatelessWidget {
  const _EstimateNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Offline — these totals cover only the sales stored on this '
              'device, so the real figures are higher. Reconnect for the full '
              'report.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
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
