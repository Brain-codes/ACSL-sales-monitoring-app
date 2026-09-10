# memory.md — Progress Log

## ⭐ DETOUR (2026-06-28): SALES-FIRST, monolith create-sale across all roles

User directive — pause the broad super-admin build, focus on **making sales work for every user type** (first-use consumer ready).
- **Sidebar HIDDEN** (not deleted): `AppDrawer` removed from the 4 tab screens; router + drawer + Phase-1 screens (Agents/Stoves/Settings/etc.) stay in code but are **unreachable** by UI. App is bottom-nav-only again: Dashboard / Sales / Partners / Profile(sync).
- **Scaffold background** → very faint green `AppColors.scaffoldBg #F6F8EE` (brand green was too thick). Keep green brand everywhere else.
- **Create-sale = ONE dynamic form** that adapts to the logged-in role:
  - acsl_agent: select partner → stove.
  - acsl_agent_manager: select partner → (self OR an agent under them tied to that partner) → stove.
  - super_admin: select partner → (an acsl_agent OR acsl_agent_manager tied to that partner) → stove. Sells for anybody.
- **Backend (docs only — do NOT edit frontend-transactions code):** SQL + docs delivered in `docs/backend/`:
  - `20260628_sales_platform_and_on_behalf.sql` — adds `sales.platform` (web|mobile) + `sales.sold_on_behalf_of` (profiles FK).
  - `sales-platform-and-on-behalf.md` — create-sale edge-fn changes (read platform, validate+insert on-behalf agent).
  - `payment-model-decoupling.md` — SUPERSEDED Jul 2026. Sales models are tied to a partner again, assigned by the external sync (not a super admin). See "Sales models tied to partners" below.
- **Schema facts:** `profiles.manager_id` (agent→manager), `acsl_agent_organizations` (agent↔partner), `payment_models.authenticated_read_active` already lets anyone read active models, `sales.created_by` stays the creator.
- Offline-first remains mandatory for the sales flow.

### Partner filtering — REVERTED to edge functions (direct-table RLS returned 0)
Direct Supabase table queries returned zero for everyone (custom login doesn't give the Supabase client a role-bearing session → RLS blocks). `PartnerAccessService` now uses edge fns: super_admin → `manage-organizations`; others → `super-admin-agents/{id}/organizations`. Both `PartnersController` + create-sale picker call it (unchanged signature).

### Logout = full wipe (was leaking previous user's data)
`AuthService.signOut` now: `_session.logout()` + `OfflineQueueService.clearAll()` (new) + `GetStorage().erase()` + Supabase `signOut()` + `goLogin()` + post-frame `Get.delete` of feature controllers (Dashboard/Sales/Partners/Profile/CreateSale) so the next user starts fresh. Fixes stale cached partners/data across logins.

### Partners empty state now has a Refresh button (calls fetchPartners).

### Partner card counts + direct-only assignment
- `PartnerModel._firstInt` maps counts from both endpoints: received ← `total_stove_ids`(super admin) / `total_sales`(agent); sold ← `sold_stove_ids` / `approved_sales`.
- `super-admin-agents/{id}/organizations` returns direct-assigned (`source:"direct"`) + whole assigned-state orgs (`source:"state"`). Mobile now FILTERS to non-"state" so agents see only their explicitly-assigned partners (matches user intent). Caveat: an agent assigned ONLY a state (no specific partners) will see none — assign specific partners.

### (superseded) Partner filtering — DIRECT TABLE QUERIES (authorized exception)
User authorized direct Supabase table access for assignment filtering (mirrors web `organizationsService`). New `lib/features/partners/partner_access_service.dart`:
- super_admin → all `organizations`.
- acsl_agent / manager → orgs in `acsl_agent_organizations` (agent_id=me) ∪ orgs whose `state` ∈ `acsl_agent_states` (agent_id=me).
- Used by both `PartnersController.fetchPartners` and `CreateSaleController` partner picker. RLS applies via the agent's Supabase session.
- TRADEOFF: org rows lack stove counts, so partner cards show 0 for allocated/sold until we enrich (follow-up). The OLD edge fns `getAllOrganizations`/`getAssignedPartners`/`super-admin-agents/{id}/organizations` are no longer used by these paths.
- CLAUDE.md rule #1 updated to allow this exception (dedicated service only).
- STILL TODO: sales-list page is also unfiltered by assignment — apply equivalent filtering (likely server-side in get-sales-advanced, or direct-table) next.

### Create-sale: Partner -> State -> Branch cascade (mirrors web CreateSalesForm)
A "partner" groups multiple org rows (branches across states). Picker now: pick partner by `partner_name` → State dropdown (states where partner has branches) → Branch dropdown (each branch is an org row; its `id` = organization_id). Auto-advances when a single state/branch. `selectedOrgId` is set only on branch pick → then loads that branch's stoves + on-behalf candidates. `assignedPartners` already holds all branch rows (no new fetch). Controller getters: `distinctPartners`, `statesForSelectedPartner`, `branchesForSelectedState`; handlers `onPartnerNameSelected`/`onBranchStateSelected`/`onBranchSelected`/`clearPartnerSelection`. validateAll() requires a branch for picker roles.

### Create-sale dynamic flow — DONE (super admin + manager paths)
- `create_sale_controller`: `isSuperAdmin`, `needsPartnerPicker` (acsl+super), `needsAgentPicker` (super+manager). Super admin loads ALL orgs (`manage-organizations`); partner pick → loads stoves + candidate agents (`get-organization-agents?organization_id=`). Payment models load globally via `payment-models` (one call, all active, cached) and are then FILTERED to the selected partner's `payment_model_ids` — never fetched per partner. Payload adds `platform:'mobile'` + `soldOnBehalfOf` (selected agent or self). Offline queue carries the same payload.
- `create_sale_screen`: partner picker shown for `needsPartnerPicker`; new "Sell on behalf of" dropdown (Myself + candidates) for `needsAgentPicker` after a partner is chosen.
- NEW edge fn (user deploys): `frontend-transactions/supabase/functions/get-organization-agents/index.ts`.
- NOT YET: server-side create-sale changes (platform/soldOnBehalfOf insert) — these are in `docs/backend/` for the web team to deploy. Until deployed, the live create-sale ignores the new fields. The org-payment-model gate is now DELIBERATELY BACK (see below) — it is no longer something to remove.

---


Living record of what's done / not done. Update after every unit of work. Status: `TODO` | `WIP` | `DONE`.

Branch: `rewrite/super-admin`. Built for **super admin first** (full surface), single-view screens gated by `canAccess`/`can`.

**2026-08-02 — role map restored (ends the "everyone is super admin" phase).** Bug: a partner logging in still saw the **Partners** bottom-nav tab. Two causes, both fixed:
- `getRolePermissions()` returned `RolePermissions.all` for everyone. It now looks up `rolePermissions` in `lib/core/auth/permissions.dart` — a direct port of the web `PERMISSIONS` map (`frontend-transactions/src/lib/permissions.ts`), plus `roleAliases`/`resolveRole` (`super_admin_agent`→`acsl_agent`, `admin`→`partner`, `agent_user`→`agent`). Unknown role ⇒ `RolePermissions.empty`. Web-only route keys with no mobile screen (sales-cancelled, end-user-records, performance-report, partner-agents-profiles) are omitted. **Keep the two maps in sync.**
- `AppShell._bottomNav()` rendered `tabRoutes` unfiltered. It now filters by `perms.canAccess`, and maps the visible index back to the fixed `StatefulShellRoute` branch index (branches are still declared dashboard/sales/partners/profile). Drawer and router `redirect` already gated correctly.

## Foundation (Phase 0)

| Item | Status | Notes |
|---|---|---|
| Governance files (CLAUDE/design/flutter/memory) | DONE | 2026-06-27 |
| Green brand swap in `app_colors.dart` (blue commented) | DONE | single token source enforced |
| 0c — `permissions.dart` (port of web permissions.ts) | DONE | RouteKey/FeatureKey/PERMISSIONS + helpers |
| deps: flutter_riverpod + go_router | DONE | get kept during transition |
| provider layer `core/providers/services.dart` | DONE | TRANSITIONAL: reads Get.find singletons; permissionsProvider live |
| 0b — go_router router + `StatefulShellRoute` + redirect guard | DONE (files) | `core/router/app_router.dart` + `route_meta.dart`; not yet wired into main |
| 0d — Navigation shell (sidebar drawer + bottom nav) | DONE (files) | `shell/app_shell.dart` + `app_drawer.dart`; permission-gated; placeholder + unauthorized screens |
| 0a — `main.dart` cutover to ProviderScope + MaterialApp.router | DONE | GetMaterialApp removed; GetX DI kept during transition |

### Cutover — DONE (Phase 0 foundation complete)
- `main.dart`: `ProviderScope` + `MaterialApp.router(routerProvider)`; `GetMaterialApp` gone. GetX DI (`Get.put`/`Get.find`) still used for services/controllers (transitional).
- Architecture refinement: shell owns ONLY the bottom nav; each tab screen keeps its Scaffold/AppBar and adds the shared `AppDrawer` (hamburger → static sidebar). No body-only rewrite needed → per-screen AppBar actions/FABs preserved.
- All breaking GetX nav migrated: create_sale_screen (dialogs→Navigator.pop(dialogCtx)), profile (dialogs), sales_list (→context.push), create_sale_controller (→rootNavigatorKey.pop), dashboard (→context.push), update_prompt_sheet (Get.context→rootNavigatorKey.currentContext), auth_service/supabase_service/login_controller/splash (→app_navigator goLogin/goHome; splash now pure loader, routing handled by router redirect).
- Deleted: `app_pages.dart`, `app_routes.dart`, `layout/acsl_agent_layout.dart`, `layout/partner_agent_layout.dart`.
- `flutter analyze`: 0 errors (only pre-existing info/warnings). Awaiting on-device test by user.

### Follow-up debt (not blocking)
- CLAUDE.md "no hardcoded colors" rule: existing screens still contain many raw `Color(0x..)` / `Colors.*` literals. Brand swap propagates via `AppColors`, but full token cleanup across legacy screens is a Phase 1+ pass.
- Finish GetX→Riverpod: services still GetxService + `Get.put`; providers currently read `Get.find`. Convert service-by-service as screens are rebuilt in Phase 1, then drop `get`.

## Phase 1 — Core operations screens (super admin)

| Route | Status | Source screen | Edge fns |
|---|---|---|---|
| dashboard | TODO (exists, extend) | dashboard_screen.dart | get-super-admin-dashboard, get-dashboard-stats |
| sales (list) | TODO (exists, extend) | sales_list_screen.dart | get-sales-advanced |
| sales-create | TODO (exists, extend) | create_sale_screen.dart | create-sale (offline queue) |
| sales detail | TODO | new | get-sale |
| sales-financial-reports | DONE | NEW: financial_reports_screen + sales_provider (Riverpod) | get-sales-advanced; client-side KPIs (count/value/collected/outstanding) + status breakdown, offline |
| sales detail | DONE (existing) | `_SaleDetailSheet` bottom sheet already in sales_list_screen | get-sale not needed for list view |
| sales approve/delete (gated) | TODO | actions | approve-sale, delete-sale |
| partners + profiles | TODO (exists, extend) | partners_screen.dart | manage-organizations, get-organizations-grouped |
| agents (acsl + partner) | DONE (list) | NEW: agents_screen + agents_provider (AsyncNotifier) + agent_model | super-admin-agents (GET). Create/edit form = follow-up. **Reference Riverpod template.** |
| stove-management | DONE (list) | NEW: stoves_screen + stoves_provider (reuses StoveModel) | get-stove-ids (POST). Status filter + search + stats header, offline-first |
| stove-manager (allocation) | TODO | placeholder | manage-stove-ids |
| stove-transfer-history | DONE | NEW: transfer_history_screen + provider + TransferRecordModel | get-transfer-history (GET), offline-first read |

## Settings / admin routes

| Route | Status | Notes |
|---|---|---|
| settings-payment-models + payment-models | DONE | NEW: payment_models_screen + provider (reuses PaymentModel). `payment-models` GET |
| settings-user-management + user-management | DONE | NEW: user_management_screen + users_provider + UserAccountModel. `manage-users` GET |
| settings-credentials | TODO | placeholder |
| settings-system-config | TODO | placeholder |
| settings-tools | TODO | placeholder |
| agreement-images, map, docs | TODO | placeholder |

## Phase 2+ (later)

Remaining placeholders above + create/edit forms. Then (post-super-admin phase) reintroduce role map in `permissions.dart` — no new screens.

## Roles (from web permissions.ts)

super_admin (ALL), acsl_agent_manager, acsl_agent, partner, partner_agent. Aliases: super_admin_agent→acsl_agent, admin→partner, agent→partner_agent.

## Open questions / decisions

- Routing chosen: go_router ShellRoute (idiomatic with Riverpod; persistent shell).
- KPI gradients/chart palette decoupled from brand — left as-is during green swap.

## Offline location resolution (Jul 2026 — replaces offline gazetteer)

Dropped the downloaded OSM gazetteer entirely (not broad enough; users' estates
missing vs Google). Offline sales revert to: **manual address text + GPS ping**
(create_sale offline section). Resolution happens at SYNC time:

- `LocationResolutionService` — Google Places Text Search (biased by captured
  GPS), scores each result vs typed address (token Dice + substring bonus,
  `_normalize` strips road/street/nigeria noise). autoAcceptThreshold=0.85.
- `SyncService.syncPendingSales()` gates each queued sale: if best match ≥0.85,
  attach Google location (`applyCandidateToPayload`: keeps typed as
  `enteredAddress`, adds googlePlaceId/googleFormattedAddress, overwrites
  lat/lng, sets `locationResolved:true`) and push. Else `markNeedsResolution`
  with candidates, skip.
- `OfflineQueueService` v2 (onUpgrade ALTER): +needs_resolution, +candidates.
  getPending() excludes needs_resolution=1. needsResolutionCount Rx.
- UI: `LocationResolutionBanner` (top of dashboard + sales list, Obx on
  needsResolutionCount) → `LocationResolutionScreen`: shows typed address + GPS,
  Google candidate radios (%match), edit+search-again, Confirm&Sync or "Keep
  mine". Confirm → applyResolution → syncPendingSales.
- Registered LocationResolutionService in main.dart. http 1.x still in use.
- Removed with this pivot: offline_places_service, offline_map_service/picker,
  nigeria_places asset, scripts/, PLACES_DB_URL/MAP_TILE_URL_TEMPLATE. No OSM or
  GeoNames data ships anymore, so no map-data attribution is required.

## Complete offline-first session + sync hardening (Jul 2026)

Field users were being ejected to login when reopening the app offline. Two
root causes fixed:

1. **main._restoreSession** caught ALL errors (incl. offline network failures)
   and called `session.logout()`, wiping the session on every offline cold
   start. Now only `AuthApiException` (server-rejected refresh token) logs out;
   network/transient errors keep the stored session.
2. **Routing gated on token freshness.** `SessionManager.isAuthenticated`
   requires an unexpired token; the router used it, so an expired token → login
   redirect. Added `SessionManager.isSignedIn` (stored userId + token +
   profile, ignores expiry) and switched the router redirect + AuthService
   .isLoggedIn to it. `isAuthenticated` now means "can hit the server right
   now" only.

Supporting changes:
- `AuthService.refreshSessionIfPossible()` — refreshes the access token on
  demand; only AuthApiException forces sign-out. Called by ConnectivityService
  `_onReconnected()` BEFORE sync/refresh so calls carry a fresh token. Also
  listens for `tokenRefreshed` auth events to keep stored token in lock-step
  with Supabase's background refresh.
- **Idempotency:** `OfflineQueueService.enqueue` stamps `clientRequestId`
  (uuid v4) into the payload once; preserved across `updateQueued` edits. Lets
  the backend dedupe a retry when an ack was lost (prevents dup sales at scale).
  NOTE: backend create-sale must honor clientRequestId for full protection.
- **Batch controls:** `deleteMany(ids)` + `clearPending()` on the queue.
- **Global status pill:** `core/widgets/sync_status_indicator.dart`, floated in
  `AppShell` Stack. Shows Syncing data / Uploading sales / Offline · N pending
  / N to sync. Idle+online+empty = hidden.
- Offline-created sales (`pendingSales` from queue) are a separate list from
  server `sales`, so a background download never overwrites them.

## Manual/auto sync mode + review-before-sync UI + PDF compression (Jul 2026)

**Sync mode toggle.** `SessionManager.autoSyncEnabled` (RxBool, key `autoSyncEnabled`,
default FALSE = manual/offline-first). Profile → `_AutoSyncCard` SwitchListTile.
ConnectivityService gates queued-sale UPLOAD on `_autoSyncOn` (both startup and
`_onReconnected`); reference-data DOWNLOAD + token refresh always run regardless.
Manual is the intended flow — user reviews sales then syncs; auto is opt-in.

**Selective sync.** `SyncService.syncPendingSales({List<int>? onlyIds})` filters
the pending set — powers individual sync and multi-select batch sync. null = all.

**Review-before-sync UI** (sales_list_screen `_PendingSalesSection`, now Stateful):
- Tap a pending sale → `_PendingSaleDetailSheet`: full read-only detail (all
  captured fields, mirrors `_SaleDetailSheet` layout) + actions Synchronize
  (this one, onlyIds:[queueId]) / Edit (reopen form via extra:queueId) / Delete.
- Long-press → multi-select mode: checkboxes, header shows "N selected" with
  Sync (selected) + Delete (selected, `OfflineQueueService.deleteMany`) + close.
- Header "Sync All" when not selecting. Hint: "Tap to review · long-press to select".
- `_loadPendingSales` in the controller now maps the FULL payload into the
  SaleModel (address/gps/contact/aka/payment/pots/cooking/terms + image presence
  flags) so the offline detail view is complete. Image ids set to 'offline'
  sentinel just to show Attached/Captured.

**PDF size fix.** `AgreementPDFGenerator` was embedding logos + signature as raw
RGBA at full source res (save80_logo 1292×624 = 3.2MB, atmosfair 1305×436 =
2.3MB) → ~6MB PDF. New `_decodeScaled(bytes, maxWidth)` uses
`instantiateImageCodec(targetWidth:)` — logos capped 380px, signature 400px.
Cuts embedded pixels by the square of the scale factor → PDF now a few hundred KB.

## "You're offline" browser page + typed-address 0,0 fallback (Jul 2026)

**"You're offline" screen was NOT ours.** It's the phone browser's own offline
page, launched by the update flow's `launchUrl(downloadUrl)` while offline (the
airplane tile is the app's web favicon). Fixed by guarding the APK-download
launch with a connectivity check in BOTH places — `update_prompt_sheet.dart`
`_openUpdatePage()` and profile `_UpdateBanner` onTap: if offline, show a
toastification "No internet connection" instead of opening a dead browser tab.

**Typed-address 0,0 fallback** (location_resolution_screen): when the agent
rejects every Google candidate and keeps their manually-typed address (empty
placeId → `_keepTyped`), coordinates are now forced to lat/lng = 0,0 — the sale
relies solely on the typed full address, no Google/stale-GPS point attached.
`_typedCandidate` carries lat:0,lng:0; `_coordRow` shows "Address only — no GPS
location" for 0,0; typed radio subtitle now "Your address (no GPS location)".
Google-picked suggestions (non-empty placeId) still keep their real coords.

## Dashboard offline-first + sync-wedge + scoped resolution sync (Jul 2026)

**Dashboard offline-first.** `LocalCacheService.saveDashboardStats(year,payload)`
/ `getDashboardStats(year)` / `dashboardStatsSavedAt(year)` (keyed per year).
`DashboardController.fetchStats`: offline → load cache + `isStale=true`; online
success → set + cache + `isStale=false` + `lastUpdated`; failure → fall back to
cache. `lastUpdatedLabel` getter. `dashboard_screen`: when `isStale`, show
`_OfflineStatsNotice` banner and wrap KPI grid in `_StaleWrapper` (greyscale
ColorFilter.matrix + Opacity 0.55 + IgnorePointer) so cached figures read as
inactive/disabled and aren't tappable.

**Sync could wedge forever (FIXED).** `SyncService.syncPendingSales` set
`isSyncing=true` but only reset at the end; any await outside the per-row try
throwing / network flapping left it true forever, and the `if(isSyncing) return`
guard then blocked ALL future syncs ("syncing forever"). Wrapped the run in
try/finally so isSyncing always resets. Same class of bug in
`DataRefreshService.refreshAll`: it awaits direct Supabase queries (no per-call
timeout) that can hang → added an overall `.timeout(60s)` around the fetch block
so isRefreshing (the "Syncing data…" pill) can't spin endlessly. Note: an
already-wedged in-memory flag clears on app restart; the fixes prevent recurrence.

**Resolution "Confirm all & Sync" synced everything (FIXED).**
`_confirmAllAndSync` called `syncPendingSales()` with no filter → pushed every
pending sale, not just the ones being resolved. Now passes
`onlyIds: _confirmed.keys.toList()`.

## Scale: partner cap fix + bounded concurrency + cache debug page (Jul 2026)

Scale: 900+ partners (growing daily), 17k+ stove IDs.

**Partner cap (REAL BUG, FIXED).** `manage-organizations` edge fn defaults
limit=50, max=100 (read-operations.ts:95). App called it once with no params →
only the first 50 partners cached → most partners missing offline. Fixed:
`PartnerAccessService._fetchAllOrganizations()` pages with limit=100 + offset
until `pagination.total` reached; passes `include_admin_users=false` (skips a
per-org admin lookup we never use). Stove IDs were already fine — `get-stove-ids`
reads body params and app pages 500/page via `pagination.total`.

**Bounded concurrency.** `DataRefreshService` used `Future.wait` over ALL orgs →
~1800 simultaneous requests at scale → rate-limit/partial cache. Added
`_runPooled(items, concurrency:6, task)` worker pool. Raised the refreshAll
safety `.timeout` 60s → 6min (a full 900-org sync is legitimately long).

**Cache debug page.** `features/profile/offline_cache_debug_screen.dart` — reached
by tapping the profile "Data Sync" title 5× (`_FiveTapDetector`, 2s burst).
Lists every cached partner with its cached stove-ID count + payment-model count,
totals, and an "empty partners" (0 stoves) count sorted first; "Re-download all"
button calls `DataRefreshService.refreshAll`. Read-only diagnostics to verify the
field device holds the complete dataset.

## Auto full-sync on launch + debug page gating (Jul 2026)

Follow-up to the partner-cap fix: a plain app RESTART (restored session, no
login) never triggered a full download, so the debug page kept showing the old
capped 50-partner cache. Fix: `DataRefreshService.onInit` now calls `refreshAll()`
on startup (self-guards on connectivity) so every online launch pulls the
COMPLETE dataset, not just login/reconnect/5-min-timer. Immediate validation
without rebuild = press "Re-download all" on the debug page.

Cache debug page (5-tap on profile "Data Sync") is now gated behind
`LocalCacheService.devAutofillEnabled` — inaccessible in release builds unless
the dev-tools flag is on.

## Sync speed: global payment models + concurrency (Jul 2026)

Sync was slow because `DataRefreshService` fetched payment models PER ORG
(~900 extra calls) on top of per-org stoves. Payment models are now GLOBAL
(decoupled from partner/sale — one active list applies to all). Fix:
- Dropped `_refreshPaymentModelsForOrg`; added `_refreshGlobalPaymentModels()`
  (hits `payment-models` GET once, caches via `LocalCacheService.savePaymentModels`).
  Called once in refreshAll alongside sales/google-keys; partner pool now fetches
  ONLY stoves. ~1800 calls → ~900. Pool concurrency 6 → 8.
- create-sale form already used the global cache (`getAllActivePaymentModels` →
  `savePaymentModels`/`getPaymentModels`), so offline installment sales still work.
- Debug page: dropped per-org model count; shows one global "Payment models" stat.
- Note: `get-stove-ids` REQUIRES organization_id (can't bulk stoves across orgs),
  so 900 per-org stove calls remain the floor; each also runs 3 server COUNT
  queries. Further speedup would need a backend bulk/stoves-by-orgs endpoint.

## Bulk stove fetch (format2) + reliable debug access (Jul 2026)

**get-stove-ids format2 (backend, backwards-compatible).** Added `format` param.
Default "format1" = original single-org behaviour (requires organization_id) —
untouched so the OTHER app calling this fn doesn't break. "format2" = bulk:
omit organization_id (or pass `organization_ids` to scope), returns stoves across
all orgs with organization_id on each row, one COUNT (not 3), paginated. Lets the
app cache all orgs in ~34 pages of 500 instead of ~900 per-org calls.
NEEDS DEPLOY (user deploys) — the app falls back gracefully until then.

**App bulk-first with fallback.** `DataRefreshService._refreshAllStovesBulk`
pages format2, groups by organization_id, caches per org (empty list for orgs
with no stock so nothing goes stale). Returns false if first page fails (old fn
400s on missing org_id) → falls back to the per-org `_runPooled`. So it's safe
to ship before the edge fn is deployed.

**Debug access fixed.** The 5-tap was unreliable (and the release build had died
on iOS signing, so it never installed). Added a direct "Offline cache debug"
ListTile inside `_DevToolsCard` on Profile (the existing dev-only card, TODO'd to
comment out before release). 5-tap remains as a secondary. Also fixed the
`activeColor`→`activeThumbColor` deprecation there.

## TODO (later): CI/CD pipeline for the app (build/deploy on push). User will drive.

## CI/CD release pipeline + dev-tools auto-hide (Jul 2026)

**Dev tools auto-hidden in release.** Profile `_DevToolsCard` (test autofill +
offline cache debug button) now wrapped in `if (kDebugMode)` — stripped from
release/profile APKs automatically. No more manual commenting.

**GitHub Actions release pipeline** (`.github/workflows/release.yml`, manual
workflow_dispatch with inputs version/release_notes/is_force_update). Replaces the
manual build→rename→copy→Supabase-edit flow:
- Stamps version into pubspec (auto versionCode = maj*10000+min*100+pat) + kAppVersion.
- Recreates .env from `ENV_FILE` secret; restores debug keystore from
  `ANDROID_DEBUG_KEYSTORE_BASE64` so signature matches existing installs
  (user isn't on Play Store — release APK is debug-signed by design; reusing
  their local ~/.android/debug.keystore = seamless in-place updates).
- `flutter build apk --release`, renames `sales-monitoring-app-vX-Y-Z.apk`.
- Cross-repo push into Brain-codes/frontend-transactions `public/downloads/`
  (secret `WEB_REPO_PAT`) → Vercel serves it.
- PATCHes Supabase app_releases row (fixed id ...0002) via REST + service role
  (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`): version, apk_path, release_notes,
  size, is_force_update. base_url untouched.
- Commits version bump back (permissions: contents: write).
Setup guide: docs/ci-release.md. Repos: mobile=Brain-codes/ACSL-sales-monitoring-app,
web=Brain-codes/frontend-transactions (Vercel). Flutter 3.41.9, Java 17.
Note: get-stove-ids format2 edge fn still deployed separately (not in pipeline).

## "You're offline" root cause CONFIRMED + field-user trap closed (Jul 2026)

Researched (subagent + web): the "You're offline" screen is the phone browser /
Samsung Internet **Custom Tab offline error page**, shown when the app hands a
URL to the system while offline. The green-airplane tile is the app's own web
favicon that the browser shows for the page it's trying to load. NOT an Android
bug and NOT in our Flutter code. Sole trigger: the APK-download `launchUrl`
(update flow). Samsung Galaxy A24 / recent One UI just renders that page.

Fixes (layered):
1. (prior) `_openUpdatePage` in update_prompt_sheet + profile _UpdateBanner
   guard connectivity → toast instead of launching browser offline.
2. (prior) AppReleaseService._fetchAndCheck skips when offline → hasUpdate stays
   false on cold offline launch → no sheet.
3. NEW: `showUpdatePromptIfNeeded` now returns early when offline. Critical
   because a FORCE-update sheet is non-dismissible — showing it offline trapped
   the field user on a blocking screen (couldn't make offline sales). Prompt
   reappears when back online.

NOTE: the tester's device runs an OLD build without these fixes — needs the new
build (CI pipeline) to take effect.

---

## 2026-07-19 — Camera crash, optional stove image, poor-network detection

Three field-reported issues fixed together:

1. **Camera crash after accepting stove photo** (older/newer devices). Cause:
   Android kills the low-RAM app while the camera activity is foregrounded;
   `pickImage`'s Future never completes and the capture is lost. Fixes in
   `create_sale_controller.dart`:
   - `pickImage` now downsizes at capture (`maxWidth/Height: 1600`,
     `requestFullMetadata: false`) to cut the memory spike, wrapped in try/catch
     so a PlatformException can't tear down the flow.
   - New `recoverLostImage()` calls `ImagePicker.retrieveLostData()`; controller
     is now a `WidgetsBindingObserver`, recovering on `onInit` and on
     `resumed`. `_pendingImageField` routes the recovered photo back to its slot.

2. **Stove image now OPTIONAL** (was required). `case 8` step-complete = just
   `hasSignature`; validation error removed; screen label "Stove Photo" (no *),
   subtitle updated. Backend: web repo `create-sale/index.ts` — removed the hard
   "Stove image is required" 400; added `safeStoveImageId` (empty→null) used in
   insert + status eval. Sale without stove image saves as pending/incomplete.
   **Needs redeploy of the create-sale edge function.**

3. **Poor-network not triggering offline mode** (Android). `connectivity_plus`
   only reports interface presence, not usable internet — dead-slow 2G stayed
   "online". `ConnectivityService` rewritten with an ACTIVE timed probe to
   `${supabaseUrl}/auth/v1/health`: NetworkQuality {online, poor, offline}.
   `poor` (slow >3s / timeout 6s / socket fail) and `offline` both set
   `isOnline=false`. Re-probes on connectivity change AND a 20s poll (catches
   silent slowdowns). New `isPoorConnection` drives OfflineBanner "Very poor
   internet — working offline" message vs plain offline.

## Sales models tied to partners, sourced from the external sync (Jul 2026)

Reverses the Jun 2026 decoupling. A sales model is again restricted to the
partners entitled to it — but the entitlement now comes from the **external
application**, not from a super admin screen. Full write-up:
`frontend-transactions/supabase/payment-model-decoupling.md`.

**Backend (web repo, needs deploy).**
- `external-csv-sync` / `external-sync`: parse `Partner Sales Models`
  (`"Hakimi Sales Model (6m); Amina Sales Model (12m)"`), match each entry to
  `payment_models` on normalized name + `duration_months`, then reconcile
  `organization_payment_models` for that partner (CSV is authoritative). An
  unmatched name CREATES A ZERO-PRICED STUB model so a partner is never blocked
  from selling; logged as `warn` for super admin review. Empty/absent column =
  "nothing said", never "revoke everything". Runs even for `manually_edited`
  partners; non-fatal so stove IDs still process.
- `manage-organizations`: every org row (list + single) now carries
  `payment_model_ids` — a bare ID array from one bulk query.
- `create-sale`: org↔model gate RESTORED (403 if the partner isn't assigned the
  model). Sale `amount` stays operator-entered — `fixed_price` is only a
  fallback, which is why zero-priced stubs are safe for now.
- Migration `20260721_sales_models_from_external_sync.sql`: `assigned_by` /
  `created_by` become nullable (the sync has no acting user), plus an index on
  `organization_payment_models.organization_id`.

**Mobile.** The point is that we NEVER call payment models per partner — there
are ~900+ partners and the flow must work offline. Unchanged: one global
`payment-models` fetch, cached. Added in `create_sale_controller`:
- `orgPaymentModelIds` (`Rxn<List<String>>`) + `visiblePaymentModels` getter =
  cached catalogue filtered by the partner's IDs. Pure in-memory lookup, so
  online and offline behave identically.
- `payment_model_ids` rides along on the cached partner rows
  (`cache_assigned_partners`) — no new cache key, no new request.
- **UNASSIGNED PARTNERS GET EVERYTHING** (user directive, 21 Jul 2026). A list =
  exactly those models; `[]` or `null` = **every active model**. Only an explicit
  list restricts. The sync covers only partners the external app has sent, so
  "no assignments" must not mean "no models" — that would block every unsynced
  partner. `create-sale` enforces the SAME rule; client and server must never
  diverge, or the picker offers models the server rejects.
- Still one real empty state: assigned models that don't resolve (inactive, or
  created after the catalogue was cached) → amber warning, NOT a fallback to
  everything, since that's a data fault worth surfacing. Both clients also
  refetch the catalogue once on meeting an unknown ID (mobile: only when online).
- **Mobile showed ALL models for a restricted partner — two causes (22 Jul 2026).**
  1. **Wrong endpoint.** Mobile reads partners via `PartnerAccessService`:
     super_admin → `manage-organizations`, but every OTHER role →
     `super-admin-agents/{id}/organizations`, which never returned
     `payment_model_ids`. Missing key = "unknown" = show everything. Fixed by
     adding the same bulk lookup to `getAgentOrganizations` in
     `super-admin-agents/readOptions.ts` (also fixes web's agent path, which
     calls the same endpoint). **Any new partner-listing endpoint must return
     this field** or it silently disables the restriction.
  2. **Stale-cache race.** `_fetchPartnersForRole` shows cached rows first, then
     pages ~900 partners. Picking a partner during that window used a pre-deploy
     row with no `payment_model_ids`. Now `_reapplyPaymentModelsForSelectedOrg()`
     re-resolves the selected org once fresh rows land.
- **`_loadPaymentModels` init race (fixed 22 Jul 2026).** It branched on
  `_connectivity.isOnline`, which is decided by an ACTIVE PROBE that usually
  hasn't resolved at `onInit` — so a genuinely online device took the offline
  branch, read an empty cache (fresh install, or post-logout `GetStorage().erase()`),
  and left the catalogue permanently empty with every failure swallowed. Now:
  seed from cache unconditionally first; never overwrite a good list with an
  empty/failed response; retry via the `ever(isOnline)` listener when we come
  online with an empty catalogue. An empty catalogue also gets its OWN message
  (`paymentCatalogueEmpty`) — the old one blamed the partner's models and sent
  debugging in the wrong direction entirely.
- Applied from `onBranchSelected` (picker roles), `_applyOwnOrganizationPaymentModels`
  (own-org roles, cache-only), and on draft restore. A selected model that the
  new partner isn't entitled to is dropped back to full payment.
- `create_sale_screen`: dropdown maps `visiblePaymentModels`; a note explains
  when a partner has no models.

**Web.** Same idea in `CreateSalesForm.jsx` — `orgPaymentModelIds` set from the
org row in `finalizeBranchPick`, `visiblePaymentModels` memo, no
`organization-payment-models/{orgId}` call.

**Coming:** the external app will start sending the sales model AMOUNT. Stubs
stop being zero-priced then; revisit whether the operator may still edit it.

## End-user phone: unique, offline (Jul 2026)

Every sale must carry a UNIQUE end-user phone, flagged AS THE SELLER TYPES —
not at submit.

**NO format validation on mobile** (user directive, 22 Jul 2026 — it was built,
then removed). Sellers enter numbers in whatever notation they have and the
"Use 08031234567, …" nag blocked real entries. Do not reinstate it. Format
never mattered to duplicate detection anyway, because of the normalization
below. Note the WEB still format-validates via upstream's `isValidNgPhone` —
the two clients differ here deliberately.

**The shared comparison key is the LAST 10 DIGITS.** All three formats collapse
to `8031234567`, so the same subscriber can't be entered twice in different
notations. Four places implement this and MUST stay identical:
`PhoneUtils.normalizePhone` (mobile), `get-end-user-phones`, `create-sale`, and
the web form's live check. A previous bug compared FULL digit strings in
`create-sale` + web, so `0803…` and `234803…` did NOT collide — fixed.

**Offline design (the point of the whole thing).** Caching full sale rows to
check uniqueness would be enormous at 20k+ sales, so we cache **phone keys
only** — a few hundred KB:
- `get-end-user-phones` (NEW edge fn) returns bare 10-digit keys for every sale,
  deduped, in one call. Deliberately NOT org-scoped: uniqueness is global, so a
  per-agent view would let two agents register the same customer. It reports
  `truncated` if it hits its row cap, and the client then KEEPS its existing
  cache rather than trusting a partial set (a partial set silently admits
  duplicates).
- `LocalCacheService.saveEndUserPhones/getEndUserPhones` — backed by an
  in-memory `Set` so a lookup per keystroke doesn't re-decode 20k entries.
- `DataRefreshService._refreshEndUserPhones()` runs in `refreshAll`.
- `OfflineQueueService.getPendingEndUserPhones()` — queued-but-unsynced sales
  aren't on the server, so without this two offline sales could share a phone
  and only fail later, at sync, with the sale already "made".
- After a successful online sale the phone is added to the cache immediately
  (`addEndUserPhone`) — waiting for the next sync leaves a window where the
  number still looks free.
- Editing a queued draft remembers `_editingOriginalPhoneKey` so the draft
  doesn't flag itself as a duplicate.

**UI.** `onEndUserPhoneChanged` debounces 300ms and shows exactly one message —
"A customer with this phone number already exists." (kept deliberately short;
an earlier longer version was trimmed). Re-checked in `validateAll`.
Debug page (`offline_cache_debug_screen`)
gained a **"Phone numbers"** stat — it is role-independent, so a count that
differs between logged-in users means the phone sync is being scoped somewhere
it shouldn't be. Stats are now 2 rows of 3 (5 tiles in one row overflowed).

Tests: `test/phone_utils_test.dart` (normalization collisions, partial input).

---

## Silent vs. loud data sync + sales pagination (Aug 2026)

**Two kinds of resync — manual (loud) and automatic (silent).**
`DataRefreshService.refreshAll({bool silent})`:
- `silent: false` (default) — LOUD: floating pill + staged progress labels
  ("Getting stoves… 40%"). Only from **Profile → Refresh Data**, the cache
  debug page, and post-login.
- `silent: true` — background run, no pill, no stage updates. Used by the
  hourly timer, app launch, and reconnect.
- A silent run is auto-upgraded to loud when nothing is cached yet
  (`_hasPersistedCache()`): the user's very first download must be visible.
- `_inFlight` guards both kinds, so loud and silent runs never overlap
  (`isRefreshing` is now the *loud-only* UI flag, not the concurrency guard).

**Timer** is 1 hour (was 5 min) and skips **00:00–05:00** (closing hours).

**Reconnect = resync.** `ConnectivityService._onReconnected()` fires a silent
`refreshAll` — "your last sync is as good as the last time you were online", so
the hourly tick rarely matters in practice.

**Same data → discard.** `LocalCacheService._writeIfChanged(key, atKey, json)`
compares the encoded payload to what's stored: unchanged → only the "last
updated" stamp moves, no rewrite. Used by saveSales / saveAssignedPartners /
saveStovesForOrg / savePaymentModels / saveEndUserPhones. Real changes bump
`mutationCount`; `refreshAll` diffs it before/after and returns whether
anything changed, which Profile uses to toast "Data synchronized" vs
"Data already up to date".

**Sales pagination (UI only).** Sales are still fetched in one shot (offline
requirement). `SalesListController` slices client-side: `pageSize = 25`,
`page`, `totalPages`, `pageSales`, `goToPage`. `_Paginator` at the bottom of
the list shows "Page X of Y · a–b of N sales". Filter/date changes reset to
page 1. No network call is involved in paging.

## Full payment = one amount field (Aug 2026)

A **full payment** means the customer settles the entire sale amount up front,
so "Sale Amount" and "Amount Received" are the same number. The create-sale
form therefore collapses them into **one input** — labelled *Sale Amount /
Amount Received (₦)* — and mirrors the value into `amountReceived` behind the
scenes. The payload shape is unchanged; both fields are still sent.

- Mobile: `isSingleAmountField` on `CreateSaleController` (`!isEditingSale &&
  !isInstallment`) drives both the label and whether the second field renders.
  Two `TextEditingController` listeners wired in `onInit` do the work —
  `_syncAmountReceivedForFullPayment` mirrors the amount, and
  `_dropInstallmentWhenPaidInFull` switches an installment back to full payment
  when the received figure reaches the sale amount (`selectPaymentType(null,
  keepAmount: true)` keeps the amount entered rather than wiping it).
- Web mirror: `CreateSalesForm.jsx` has the same `isSingleAmountField` flag,
  the mirroring inside `handleInputChange`, and the `keepAmount` option on
  `handlePaymentTypeChange`.
- **Edit mode keeps both fields.** A synced sale may legitimately carry a
  part-paid non-installment record; merging would silently rewrite it.
- Picking an installment model clears the received field on both platforms —
  under a plan that figure means the *initial payment*, not the full amount.
- **Server side (`create-sale`, `update-sale`).** Both coerce rather than
  reject: a non-installment sale gets `total_paid = amount` and
  `payment_status = 'fully_paid'`. Coercion (not a 400) so old app builds and
  offline sales queued before this change still sync. `update-sale` also now
  recomputes `payment_status` — previously an amount edit left it stale.
- **Legacy rows rectified (2026-08-15).** Three Silvex sales (`57WQUL`,
  `8RXIO3`, `KFDUJB`) predated the rule: non-installment, ₦38,100, part-paid
  ₦12,700 / ₦10,000 / ₦10,000. They were real deposits, so they were
  reclassified as installments on **Institutional Sales - Flexible Payment**
  rather than written up as fully paid. `amount` stayed at ₦38,100 —
  `create-sale` treats a model's `fixed_price` as a fallback only, so an
  installment sale may carry an operator-set amount. Each also had `total_paid`
  set with **no** `installment_payments` row, so the deposit was backfilled as
  a `cash` payment dated to the sale's own `sales_date`. Backup lives in
  `public.backup_partpaid_outright_20260815`. The user confirmed these were the
  only affected rows; no general backfill was written.

## Field alignment — sale dictionary (2026-09-09)

The sale form's wording, choices and required-ness are **no longer hardcoded**.
They come from `GET /functions/v1/sale-dictionary` at run time, via
`SaleDictionaryService` (ETag-revalidated, cached offline, seeded from
`assets/data/sale-dictionary.json`). Three rules follow, and they are the whole
contract with the web side:

1. Labels come from the dictionary's `label` — no field name is typed in the app.
2. Required follows `mandatoryFrom`, judged against **the sale's own date**, so a
   back-dated draft is never refused for a rule that came later. Two waves are
   already scheduled (2026-09-11 and 2027-01-05) and an administrator can move
   either without an app release.
3. Choices come from `options` — show `label`, send `value` (the values are
   slugs: `firewood`, `collect`, `semi_indoor`, not the words on screen).

Add a new sale field by adding it to the dictionary on the web side; the app
picks it up. Do not add a hardcoded label, validator or option list.

**The reference repo is `acsl-80/ACSL-Sales-Monitoring-Web-App`.** The local
`supabase/` folder in this repo is a months-old copy and is STALE — never read it
as truth. (`/Users/Efe/Projects/Web/sales-monitoring-web` is also a different,
unrelated repo: `shakarho/...`.)

Resolved: the old comment claiming the split name broke the backend was true
against the server of the day only. `create-sale` now composes the joined name
from the parts before its own checks, so the app sends `endUserName`,
`endUserFirstName` and `endUserSurname` together.

## Parity brief M1-M20 (2026-09-10)

ACSL's 3 Sept brief is worked through. Four rules came out of it that outlive
the individual fixes:

1. **Never sum rows to get a total.** Every list edge function caps ONE
   response (sales/stoves 500, transfers 200, agents/users/orgs 100) and
   production is well past those caps. Totals come from `get-sales-advanced`
   with `withSummary: true`, computed in SQL and scoped to the caller. Rows
   page with `pagination.total` / `has_more` — use `core/services/paged_fetch.dart`.
2. **Dates are West Africa Time.** `core/utils/app_date.dart` is the only place
   a date is formatted or a day boundary is decided. A fixed UTC+1 is exact
   because Nigeria has never observed daylight saving.
3. **`total_paid` is what was collected**, for cash sales as well as
   instalments, and is never substituted with `amount`. Payment badges,
   balances and reports all derive from it.
4. **`sales.status` is form completeness, not payment.** Never show it as a
   payment or verification state — `payment_status` is the payment one.

Also fixed, found while testing rather than in the brief: permissions resolved
once on the splash screen and never recomputed, so every role (super admin
included) was bounced to /unauthorized after login. `SessionManager.revision`
ticks on identity writes and Riverpod watches it — if you add another identity
write, bump it.

The permissions map and the web's `src/lib/permissions.ts` are ONE rule and
change together. Reference repo: acsl-80/ACSL-Sales-Monitoring-Web-App.
