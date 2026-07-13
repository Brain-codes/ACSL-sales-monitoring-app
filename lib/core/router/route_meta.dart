import 'package:flutter/material.dart';
import 'package:stove_transaction/core/auth/permissions.dart';

/// Metadata for every navigable route — the single place that maps a [RouteKey]
/// to its URL path, sidebar label, icon, and whether it is a bottom-nav tab.
/// Both the router and the sidebar drawer read from here so they never drift.
class AppRoute {
  const AppRoute({
    required this.key,
    required this.path,
    required this.label,
    required this.icon,
    this.isTab = false,
    this.group,
  });

  final RouteKey key;
  final String path;
  final String label;
  final IconData icon;

  /// True for the 4 primary destinations shown in the static bottom nav.
  final bool isTab;

  /// Optional sidebar grouping header (e.g. "Stoves", "Settings").
  final String? group;
}

/// Auth routes live outside the shell.
const String splashPath = '/splash';
const String loginPath = '/login';
const String unauthorizedPath = '/unauthorized';

/// Ordered list driving the sidebar. Tabs also appear in the bottom nav.
const List<AppRoute> appRoutes = [
  AppRoute(key: RouteKey.dashboard, path: '/dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined, isTab: true),
  AppRoute(key: RouteKey.sales, path: '/sales', label: 'Sales', icon: Icons.receipt_long_outlined, isTab: true),
  AppRoute(key: RouteKey.salesCreate, path: '/sales/create', label: 'Create Sale', icon: Icons.add_circle_outline, group: 'Sales'),
  AppRoute(key: RouteKey.salesFinancialReports, path: '/sales/financial-reports', label: 'Financial Reports', icon: Icons.assessment_outlined, group: 'Sales'),
  AppRoute(key: RouteKey.partners, path: '/partners', label: 'Partners', icon: Icons.people_outline, isTab: true),
  AppRoute(key: RouteKey.partnersProfiles, path: '/partners/profiles', label: 'Partner Profiles', icon: Icons.badge_outlined, group: 'Partners'),
  AppRoute(key: RouteKey.agents, path: '/agents', label: 'Agents', icon: Icons.support_agent_outlined, group: 'Agents'),
  AppRoute(key: RouteKey.agentsProfiles, path: '/agents/profiles', label: 'Agent Profiles', icon: Icons.badge_outlined, group: 'Agents'),
  AppRoute(key: RouteKey.stoveManagement, path: '/stove-management', label: 'Stove Management', icon: Icons.inventory_2_outlined, group: 'Stoves'),
  AppRoute(key: RouteKey.stoveManager, path: '/stove-manager', label: 'Stove Allocation', icon: Icons.assignment_outlined, group: 'Stoves'),
  AppRoute(key: RouteKey.stoveTransferHistory, path: '/stove-transfer-history', label: 'Transfer History', icon: Icons.history, group: 'Stoves'),
  AppRoute(key: RouteKey.agreementImages, path: '/agreement-images', label: 'Agreement Images', icon: Icons.image_outlined),
  AppRoute(key: RouteKey.map, path: '/map', label: 'Map', icon: Icons.map_outlined),
  AppRoute(key: RouteKey.settingsPaymentModels, path: '/settings/payment-models', label: 'Payment Models', icon: Icons.payments_outlined, group: 'Settings'),
  AppRoute(key: RouteKey.settingsCredentials, path: '/settings/credentials', label: 'Credentials', icon: Icons.key_outlined, group: 'Settings'),
  AppRoute(key: RouteKey.settingsSystemConfig, path: '/settings/system-config', label: 'System Config', icon: Icons.tune_outlined, group: 'Settings'),
  AppRoute(key: RouteKey.settingsUserManagement, path: '/settings/user-management', label: 'User Management', icon: Icons.manage_accounts_outlined, group: 'Settings'),
  AppRoute(key: RouteKey.settingsTools, path: '/settings/tools', label: 'Tools', icon: Icons.build_outlined, group: 'Settings'),
  AppRoute(key: RouteKey.docs, path: '/docs', label: 'Docs', icon: Icons.menu_book_outlined),
  AppRoute(key: RouteKey.profile, path: '/profile', label: 'Profile', icon: Icons.person_outline, isTab: true),
];

/// The 4 bottom-nav tabs, in order.
List<AppRoute> get tabRoutes => appRoutes.where((r) => r.isTab).toList();
