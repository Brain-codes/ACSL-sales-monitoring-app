import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/features/agents/agents_provider.dart';
import 'package:stove_transaction/features/agents/models/agent_model.dart';

/// Agents management. One screen for every role — actions self-gate by
/// permission. Super admin sees all agents and every action.
class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(agentsProvider);
    final perms = ref.watch(permissionsProvider);
    final canManage = perms.can(FeatureKey.manageAcslAgents) ||
        perms.can(FeatureKey.manageAgents);

    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
              onPressed: () => _notImplemented(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Agent'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, email or role',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: agentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                message: '$e',
                icon: Icons.error_outline,
                actionLabel: 'Retry',
                onAction: () => ref.read(agentsProvider.notifier).refresh(),
              ),
              data: (agents) {
                final filtered = _filter(agents);
                if (filtered.isEmpty) {
                  return EmptyState(
                    message: _query.isEmpty
                        ? 'No agents found.'
                        : 'No agents match "$_query".',
                    icon: Icons.people_outline,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(agentsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AgentCard(agent: filtered[i], canManage: canManage),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AgentModel> _filter(List<AgentModel> agents) {
    if (_query.isEmpty) return agents;
    return agents.where((a) {
      return a.fullName.toLowerCase().contains(_query) ||
          a.email.toLowerCase().contains(_query) ||
          a.role.toLowerCase().contains(_query);
    }).toList();
  }

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create agent form — coming next.')),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.canManage});

  final AgentModel agent;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.brandLight,
                  child: Text(
                    agent.fullName.isNotEmpty ? agent.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.fullName.isEmpty ? 'Unnamed agent' : agent.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (agent.email.isNotEmpty)
                        Text(agent.email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(active: agent.isActive),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (agent.role.isNotEmpty) _Tag(icon: Icons.badge_outlined, label: _prettyRole(agent.role)),
                if (agent.phone.isNotEmpty) _Tag(icon: Icons.phone_outlined, label: agent.phone),
                _Tag(icon: Icons.store_outlined, label: '${agent.assignedOrganizationsCount} partners'),
                _Tag(icon: Icons.map_outlined, label: '${agent.assignedStatesCount} states'),
                _Tag(icon: Icons.receipt_long_outlined, label: '${agent.totalSales} sales'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _prettyRole(String role) => role
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
