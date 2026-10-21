import 'package:flutter/material.dart';
import 'package:stove_transaction/core/widgets/update_prompt_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/router/route_meta.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/permission_service.dart';
import 'package:stove_transaction/core/widgets/sync_status_indicator.dart';

/// Persistent app shell. Owns ONLY the static bottom nav (4 primary tabs) and
/// hosts a [StatefulNavigationShell] so tab state is preserved. Each tab screen
/// keeps its own Scaffold/AppBar and adds the shared [AppDrawer] for the static
/// side navigation — so per-screen AppBar actions and FABs are untouched.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    // Ask for camera + location ONCE, right after the first screen paints, so
    // an agent grants everything up front instead of being interrupted by a
    // system dialog halfway through recording a sale. Deferred to a post-frame
    // callback because the platform needs a resumed Activity to show a prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestStartupPermissions());
    // Once per launch: agents learn of a new release without pull-to-refresh.
    // Shown only online, and respects the 12h snooze.
    showUpdatePromptIfNeeded();
  }

  Future<void> _requestStartupPermissions() async {
    final permissions = Get.find<PermissionService>();
    // Already handled on a previous launch, or nothing left to grant.
    if (permissions.hasAsked) return;
    if (await permissions.allGranted()) return;

    // Fire the OS prompts straight away — no in-app primer to tap through.
    await permissions.requestStartupPermissions();

    // "Don't allow" is sticky on Android — the app can never prompt again, and
    // the agent would just hit a dead camera/GPS later with no explanation.
    // Point them at the one place that can still fix it.
    if (!mounted) return;
    if (await permissions.anyPermanentlyDenied()) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permissions needed'),
          content: const Text(
            'Camera or location access was blocked. You can still record sales, '
            'but photos or GPS may not work until you enable them in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                permissions.openSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          // Global background-activity / connectivity status, floating above
          // every tab so the user always knows what's happening offline.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: SyncStatusIndicator()),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    // Only the tabs this role may reach — e.g. a partner never sees "Partners".
    // Branch index still comes from the tab's position in [tabRoutes], since
    // the shell's branches are declared in that fixed order.
    final perms = ref.watch(permissionsProvider);
    final all = tabRoutes;
    final visible = <(int, AppRoute)>[
      for (var i = 0; i < all.length; i++)
        if (perms.canAccess(all[i].key)) (i, all[i]),
    ];
    if (visible.length < 2) return const SizedBox.shrink();

    // Current branch may be hidden for this role (deep link / redirect race);
    // fall back to no selection rather than highlighting the wrong tab.
    var current = visible.indexWhere((e) => e.$1 == navigationShell.currentIndex);
    if (current < 0) current = 0;

    // TRANSITIONAL: pending count still read from the GetX offline queue.
    final queue = Get.find<OfflineQueueService>();
    return Obx(() {
      final pending = queue.pendingCount.value;
      return BottomNavigationBar(
        currentIndex: current,
        onTap: (i) {
          final branch = visible[i].$1;
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        items: [
          for (final (_, tab) in visible)
            BottomNavigationBarItem(
              icon: tab.key == RouteKey.sales && pending > 0
                  ? Badge(label: Text('$pending'), child: Icon(tab.icon))
                  : Icon(tab.icon),
              label: tab.label,
            ),
        ],
      );
    });
  }
}
