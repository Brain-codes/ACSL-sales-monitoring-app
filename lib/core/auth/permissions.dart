/// Permission model.
///
/// SUPER-ADMIN-ONLY BUILD (current phase): we are intentionally ignoring every
/// other role. Any authenticated user is treated as super admin and gets the
/// full surface — every route, every feature, open at a go.
///
/// The gating *infrastructure* (RouteKey / FeatureKey / canAccess / can) is kept
/// so screens stay single-view and other roles can be reintroduced later by
/// restoring a role -> permissions map. For now [getRolePermissions] always
/// returns [RolePermissions.all].
library;

/// Every route the app can show. Mirror of the web `RouteKey`.
enum RouteKey {
  dashboard,
  sales,
  salesCreate,
  salesFinancialReports,
  partners,
  partnersProfiles,
  agents,
  agentsProfiles,
  stoveManagement,
  stoveManager,
  stoveTransferHistory,
  agreementImages,
  map,
  settings,
  settingsPaymentModels,
  settingsCredentials,
  settingsSystemConfig,
  settingsUserManagement,
  settingsTools,
  userManagement,
  userManagementUsers,
  userManagementGroups,
  paymentModels,
  profile,
  docs,
  salesMonitoringApp,
}

/// Feature flags gating individual actions/widgets. Mirror of web `FeatureKey`.
enum FeatureKey {
  globalFilters,
  manageAllPartners,
  manageAcslAgents,
  managePartnerAgents,
  paymentModels,
  userManagement,
  credentials,
  systemConfig,
  stoveAllocation,
  createSale,
  myPartnersFilter,
  manageAgents,
  orgSalesView,
  manageAcslAgentsScoped,
  impersonate,
  overrideAssignments,
  approveSales,
  resetAnyPassword,
  editAnyPartner,
  editAnyAgent,
  viewAllRecords,
  tools,
}

/// The set of routes + features available. Drives sidebar visibility and
/// in-screen widget gating.
class RolePermissions {
  const RolePermissions({required this.routes, required this.features});

  final List<RouteKey> routes;
  final List<FeatureKey> features;

  bool canAccess(RouteKey route) => routes.contains(route);
  bool can(FeatureKey feature) => features.contains(feature);

  /// Super admin: every route + every feature.
  static const all = RolePermissions(
    routes: RouteKey.values,
    features: FeatureKey.values,
  );

  static const empty = RolePermissions(routes: [], features: []);
}

/// SUPER-ADMIN-ONLY: every authenticated user gets full access for now.
/// Reintroduce the role -> permissions map here when other roles come back.
RolePermissions getRolePermissions(String? role) => RolePermissions.all;

/// Super-admin-only build: treat everyone as super admin.
bool isSuperAdminRole(String? role) => true;
