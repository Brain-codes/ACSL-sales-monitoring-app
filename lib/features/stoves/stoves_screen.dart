import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';
import 'package:stove_transaction/features/stoves/stoves_provider.dart';

/// Stove inventory (stove-management). Single screen for all roles; super admin
/// sees the full inventory. Status + search filtering is client-side.
class StovesScreen extends ConsumerStatefulWidget {
  const StovesScreen({super.key});

  @override
  ConsumerState<StovesScreen> createState() => _StovesScreenState();
}

class _StovesScreenState extends ConsumerState<StovesScreen> {
  String _query = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final stovesAsync = ref.watch(stovesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stove Management')),
      body: stovesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          message: '$e',
          icon: Icons.error_outline,
          actionLabel: 'Retry',
          onAction: () => ref.read(stovesProvider.notifier).refresh(),
        ),
        data: (stoves) => _content(stoves),
      ),
    );
  }

  Widget _content(List<StoveModel> stoves) {
    final statuses = <String>{
      for (final s in stoves) (s.status ?? '').toLowerCase().trim()
    }..removeWhere((s) => s.isEmpty);

    final filtered = stoves.where((s) {
      final status = (s.status ?? '').toLowerCase().trim();
      if (_status != 'all' && status != _status) return false;
      if (_query.isEmpty) return true;
      final serial = (s.serialNo ?? '').toLowerCase();
      return serial.contains(_query) || s.stoveId.toLowerCase().contains(_query);
    }).toList();

    return Column(
      children: [
        _StatsHeader(total: stoves.length, statuses: statuses, stoves: stoves),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by serial or ID',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('all', 'All'),
              for (final s in statuses) _filterChip(s, _pretty(s)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  message: _query.isEmpty ? 'No stoves found.' : 'No stoves match "$_query".',
                  icon: Icons.inventory_2_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(stovesProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _StoveTile(stove: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }

  String _pretty(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.total, required this.statuses, required this.stoves});

  final int total;
  final Set<String> statuses;
  final List<StoveModel> stoves;

  int _count(String status) =>
      stoves.where((s) => (s.status ?? '').toLowerCase().trim() == status).length;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _stat('Total', total, AppColors.brandPrimary),
          if (statuses.contains('available')) _stat('Available', _count('available'), AppColors.success),
          if (statuses.contains('sold')) _stat('Sold', _count('sold'), AppColors.warning),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StoveTile extends StatelessWidget {
  const _StoveTile({required this.stove});
  final StoveModel stove;

  @override
  Widget build(BuildContext context) {
    final status = (stove.status ?? 'unknown').toLowerCase().trim();
    final color = switch (status) {
      'available' => AppColors.success,
      'sold' => AppColors.warning,
      _ => AppColors.textMuted,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.brandLight,
          child: const Icon(Icons.local_fire_department_outlined, color: AppColors.brandPrimary),
        ),
        title: Text(stove.serialNo?.isNotEmpty == true ? stove.serialNo! : stove.stoveId),
        subtitle: stove.organizationId != null ? Text('Org: ${stove.organizationId}') : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.isEmpty ? 'Unknown' : '${status[0].toUpperCase()}${status.substring(1)}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
