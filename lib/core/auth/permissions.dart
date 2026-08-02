/// Permission model.
///
/// Screens stay single-view: widgets and nav entries are shown/hidden through
/// `canAccess` / `can`, never by forking a screen per role. The role ->
/// permissions map below is a direct port of the web app's `PERMISSIONS`
/// (`frontend-transactions/src/lib/permissions.ts`) — keep the two in sync.
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

/// Legacy role values mapped to their canonical equivalent. Mirror of the web
/// `ROLE_ALIASES`.
const Map<String, String> roleAliases = {
  'super_admin_agent': 'acsl_agent',
  'admin': 'partner',
  'agent_user': 'agent',
};

/// Canonical role for a raw role string, or null when logged out.
String? resolveRole(String? role) {
  if (role == null || role.isEmpty) return null;
  return roleAliases[role] ?? role;
}

/// Role -> permissions. Ported from the web app's `PERMISSIONS`
/// (`frontend-transactions/src/lib/permissions.ts`) so mobile and web agree on
/// what each role can see. Web-only route keys with no mobile screen yet
/// (sales-cancelled, end-user-records, performance-report, …) are omitted.
const Map<String, RolePermissions> rolePermissions = {
  // Super admin: every route, every feature.
  'super_admin': RolePermissions.all,

  'acsl_agent_manager': RolePermissions(
    routes: [
      RouteKey.dashboard,
      RouteKey.sales,
      RouteKey.salesCreate,
      RouteKey.salesFinancialReports,
      RouteKey.partners,
      RouteKey.partnersProfiles,
      RouteKey.agents,
      RouteKey.agentsProfiles,
      RouteKey.stoveManagement,
      RouteKey.stoveManager,
      RouteKey.stoveTransferHistory,
      RouteKey.agreementImages,
      RouteKey.userManagement,
      RouteKey.userManagementUsers,
      RouteKey.settingsUserManagement,
      RouteKey.profile,
      RouteKey.salesMonitoringApp,
    ],
    features: [
      FeatureKey.myPartnersFilter,
      FeatureKey.stoveAllocation,
      FeatureKey.createSale,
      FeatureKey.manageAcslAgentsScoped,
      FeatureKey.managePartnerAgents,
      FeatureKey.userManagement,
      FeatureKey.orgSalesView,
    ],
  ),

  'acsl_agent': RolePermissions(
    routes: [
      RouteKey.dashboard,
      RouteKey.sales,
      RouteKey.salesCreate,
      RouteKey.salesFinancialReports,
      RouteKey.partners,
      RouteKey.partnersProfiles,
      RouteKey.agents,
      RouteKey.stoveManagement,
      RouteKey.stoveManager,
      RouteKey.stoveTransferHistory,
      RouteKey.agreementImages,
      RouteKey.profile,
      RouteKey.salesMonitoringApp,
    ],
    features: [
      FeatureKey.myPartnersFilter,
      FeatureKey.stoveAllocation,
      FeatureKey.createSale,
      FeatureKey.orgSalesView,
    ],
  ),

  // Partners: no partner management (they ARE a partner), no ACSL agent
  // profiles, no map, no settings.
  'partner': RolePermissions(
    routes: [
      RouteKey.dashboard,
      RouteKey.sales,
      RouteKey.salesCreate,
      RouteKey.salesFinancialReports,
      RouteKey.agents,
      RouteKey.stoveManagement,
      RouteKey.stoveManager,
      RouteKey.stoveTransferHistory,
      RouteKey.agreementImages,
      RouteKey.userManagement,
      RouteKey.userManagementUsers,
      RouteKey.settingsUserManagement,
      RouteKey.profile,
      RouteKey.salesMonitoringApp,
    ],
    features: [
      FeatureKey.manageAgents,
      FeatureKey.managePartnerAgents,
      FeatureKey.orgSalesView,
      FeatureKey.createSale,
      FeatureKey.userManagement,
    ],
  ),

  'partner_agent': RolePermissions(
    routes: [
      RouteKey.dashboard,
      RouteKey.sales,
      RouteKey.salesCreate,
      RouteKey.stoveManagement,
      RouteKey.stoveManager,
      RouteKey.profile,
      RouteKey.salesMonitoringApp,
    ],
    features: [FeatureKey.createSale],
  ),

  'agent': RolePermissions(
    routes: [
      RouteKey.dashboard,
      RouteKey.sales,
      RouteKey.salesCreate,
      RouteKey.stoveManagement,
      RouteKey.stoveManager,
      RouteKey.profile,
      RouteKey.salesMonitoringApp,
    ],
    features: [FeatureKey.createSale],
  ),
};

/// Permissions for the current role. Unknown/absent role => nothing.
RolePermissions getRolePermissions(String? role) =>
    rolePermissions[resolveRole(role) ?? ''] ?? RolePermissions.empty;

bool isSuperAdminRole(String? role) => resolveRole(role) == 'super_admin';
