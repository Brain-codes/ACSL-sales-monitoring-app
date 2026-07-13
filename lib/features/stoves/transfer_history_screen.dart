import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/features/stoves/models/transfer_record_model.dart';
import 'package:stove_transaction/features/stoves/transfer_history_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');

/// Stove transfer history (read-only). Super admin sees all transfers.
class TransferHistoryScreen extends ConsumerWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transferHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer History')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          message: '$e',
          icon: Icons.error_outline,
          actionLabel: 'Retry',
          onAction: () => ref.read(transferHistoryProvider.notifier).refresh(),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const EmptyState(message: 'No transfers recorded.', icon: Icons.history);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(transferHistoryProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TransferCard(record: records[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.record});
  final TransferRecordModel record;

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : _dateFmt.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final location = [record.branch, record.state].where((e) => e != null && e.isNotEmpty).join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.partnerName.isEmpty ? 'Unknown partner' : record.partnerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${record.stoveCount} stoves',
                    style: const TextStyle(color: AppColors.brandPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (location.isNotEmpty)
              _row(Icons.location_on_outlined, location),
            _row(Icons.calendar_today_outlined, 'Transferred ${_fmtDate(record.transferDate)}'),
            if (record.transactionId.isNotEmpty)
              _row(Icons.tag, record.transactionId),
            if (record.source.isNotEmpty)
              _row(Icons.sync_alt, record.source.replaceAll('-', ' ')),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
