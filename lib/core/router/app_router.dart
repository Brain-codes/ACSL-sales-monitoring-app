import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/router/app_navigator.dart';
import 'package:stove_transaction/core/router/route_meta.dart';
import 'package:stove_transaction/features/agents/agents_screen.dart';
import 'package:stove_transaction/features/auth/login/login_screen.dart';
import 'package:stove_transaction/features/auth/splash/splash_screen.dart';
import 'package:stove_transaction/features/dashboard/dashboard_screen.dart';
import 'package:stove_transaction/features/partners/partners_screen.dart';
import 'package:stove_transaction/features/profile/profile_screen.dart';
import 'package:stove_transaction/features/sales/create/create_sale_screen.dart';
import 'package:stove_transaction/features/sales/financial_reports_screen.dart';
import 'package:stove_transaction/features/sales/list/sales_list_screen.dart';
import 'package:stove_transaction/features/settings/payment_models_screen.dart';
import 'package:stove_transaction/features/settings/user_management_screen.dart';
import 'package:stove_transaction/features/stoves/stoves_screen.dart';
import 'package:stove_transaction/features/stoves/transfer_history_screen.dart';
import 'package:stove_transaction/shell/app_shell.dart';
import 'package:stove_transaction/shell/placeholder_screen.dart';
import 'package:stove_transaction/shell/unauthorized_screen.dart';

/// The app router. Auth + per-route permission enforced in [redirect].
/// One [StatefulShellRoute] holds the 4 bottom-nav tabs; every other route is a
/// full-screen push reachable from the side drawer.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: splashPath,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final perms = ref.read(permissionsProvider);
      final loc = state.matchedLocation;
      // OFFLINE-FIRST: route on stored identity, not token freshness, so an
      // expired token never ejects a field user with no connectivity.
      final authed = session.isSignedIn;

      final atAuth = loc == loginPath || loc == splashPath;
      // Splash is transient: unauthenticated users fall through to login. Only
      // the login screen itself is a valid resting place when signed out.
      if (!authed) return loc == loginPath ? null : loginPath;
      // Signed in but sitting on splash/login -> go to first tab.
      if (atAuth) return tabRoutes.first.path;

      // Permission gate: if this path maps to a known route the role can't
      // access, bounce to /unauthorized.
      final match = appRoutes.where((r) => r.path == loc);
      if (match.isNotEmpty && !perms.canAccess(match.first.key)) {
        return unauthorizedPath;
      }
      return null;
    },
    routes: [
      GoRoute(path: splashPath, builder: (_, __) => const SplashScreen()),
      GoRoute(path: loginPath, builder: (_, __) => const LoginScreen()),
      GoRoute(path: unauthorizedPath, builder: (_, __) => const UnauthorizedScreen()),

      // Persistent shell: 4 bottom-nav tabs with preserved state.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/sales', builder: (_, __) => const SalesListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/partners', builder: (_, __) => const PartnersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // Drawer-only routes (full-screen pushes). Real screens land here in
      // Phase 1/2; unbuilt ones use a placeholder for now.
      GoRoute(
        path: '/sales/create',
        builder: (_, state) => CreateSaleScreen(
          editQueueId: state.extra is int ? state.extra as int : null,
        ),
      ),
      GoRoute(path: '/sales/financial-reports', builder: (_, __) => const FinancialReportsScreen()),
      GoRoute(path: '/agents', builder: (_, __) => const AgentsScreen()),
      GoRoute(path: '/stove-management', builder: (_, __) => const StovesScreen()),
      GoRoute(path: '/stove-transfer-history', builder: (_, __) => const TransferHistoryScreen()),
      GoRoute(path: '/payment-models', builder: (_, __) => const PaymentModelsScreen()),
      GoRoute(path: '/settings/payment-models', builder: (_, __) => const PaymentModelsScreen()),
      GoRoute(path: '/settings/user-management', builder: (_, __) => const UserManagementScreen()),
      GoRoute(path: '/user-management', builder: (_, __) => const UserManagementScreen()),
      ..._placeholderRoutes(),
    ],
  );
});

/// Build placeholder routes for every drawer route that isn't a tab and isn't
/// wired to a real screen yet.
List<GoRoute> _placeholderRoutes() {
  const wired = {
    RouteKey.salesCreate,
    RouteKey.salesFinancialReports,
    RouteKey.agents,
    RouteKey.stoveManagement,
    RouteKey.stoveTransferHistory,
    RouteKey.paymentModels,
    RouteKey.settingsPaymentModels,
    RouteKey.settingsUserManagement,
    RouteKey.userManagement,
  };
  return appRoutes
      .where((r) => !r.isTab && !wired.contains(r.key))
      .map((r) => GoRoute(
            path: r.path,
            builder: (_, __) => PlaceholderScreen(title: r.label),
          ))
      .toList();
}
