import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/features/settings/models/user_account_model.dart';
import 'package:stove_transaction/features/settings/users_provider.dart';

/// User management. One screen for all roles; create/edit self-gates by the
/// `userManagement` feature (super admin has it).
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(usersProvider);
    final canManage = ref.watch(permissionsProvider).can(FeatureKey.userManagement);

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create user — coming next.')),
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('New User'),
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
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                message: '$e',
                icon: Icons.error_outline,
                actionLabel: 'Retry',
                onAction: () => ref.read(usersProvider.notifier).refresh(),
              ),
              data: (users) {
                final filtered = _filter(users);
                if (filtered.isEmpty) {
                  return EmptyState(
                    message: _query.isEmpty ? 'No users found.' : 'No users match "$_query".',
                    icon: Icons.manage_accounts_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(usersProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _UserTile(user: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<UserAccountModel> _filter(List<UserAccountModel> users) {
    if (_query.isEmpty) return users;
    return users.where((u) =>
        u.fullName.toLowerCase().contains(_query) ||
        u.email.toLowerCase().contains(_query) ||
        u.role.toLowerCase().contains(_query)).toList();
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final UserAccountModel user;

  String _prettyRole(String role) => role
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final color = user.isActive ? AppColors.success : AppColors.textMuted;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.brandLight,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(user.fullName.isEmpty ? 'Unnamed user' : user.fullName),
        subtitle: Text(
          [if (user.email.isNotEmpty) user.email, if (user.role.isNotEmpty) _prettyRole(user.role)].join(' · '),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.isActive ? 'Active' : 'Inactive',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
