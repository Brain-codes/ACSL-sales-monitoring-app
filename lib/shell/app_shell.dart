import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/router/route_meta.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/widgets/sync_status_indicator.dart';

/// Persistent app shell. Owns ONLY the static bottom nav (4 primary tabs) and
/// hosts a [StatefulNavigationShell] so tab state is preserved. Each tab screen
/// keeps its own Scaffold/AppBar and adds the shared [AppDrawer] for the static
/// side navigation — so per-screen AppBar actions and FABs are untouched.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final tabs = tabRoutes;
    // TRANSITIONAL: pending count still read from the GetX offline queue.
    final queue = Get.find<OfflineQueueService>();
    return Obx(() {
      final pending = queue.pendingCount.value;
      return BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: [
          for (final tab in tabs)
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
