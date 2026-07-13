import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/router/route_meta.dart';

/// The static side navigation. Lists the full route set (mirroring the web
/// sidebar), filtered by the current role's permissions. Super admin sees all.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final location = GoRouterState.of(context).matchedLocation;

    // Visible routes for this role, preserving sidebar order + grouping.
    final visible = appRoutes.where((r) => perms.canAccess(r.key)).toList();

    final children = <Widget>[];
    String? lastGroup;
    for (final route in visible) {
      if (route.group != null && route.group != lastGroup) {
        children.add(_groupHeader(route.group!));
      }
      lastGroup = route.group;
      children.add(_item(context, route, active: location == route.path));
    }

    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(child: ListView(padding: const EdgeInsets.all(8), children: children)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.settings, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            'CONTROL PANEL',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.brandPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _item(BuildContext context, AppRoute route, {required bool active}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? AppColors.navActiveBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).pop(); // close drawer
            if (active) return;
            // Tabs switch the persistent shell branch; everything else opens as
            // a full-screen push with a back button.
            if (route.isTab) {
              context.go(route.path);
            } else {
              context.push(route.path);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(route.icon, size: 18, color: active ? AppColors.navActiveText : AppColors.textPrimary),
                const SizedBox(width: 12),
                Text(
                  route.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppColors.navActiveText : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
