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
  - `payment-model-decoupling.md` — every partner gets every active payment model; remove the `organization_payment_models` gate in create-sale; pick any active model at point of sale.
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
- `create_sale_controller`: `isSuperAdmin`, `needsPartnerPicker` (acsl+super), `needsAgentPicker` (super+manager). Super admin loads ALL orgs (`manage-organizations`); partner pick → loads stoves + candidate agents (`get-organization-agents?organization_id=`). Payment models now load globally via `payment-models` (decoupled, all active) for every role. Payload adds `platform:'mobile'` + `soldOnBehalfOf` (selected agent or self). Offline queue carries the same payload.
- `create_sale_screen`: partner picker shown for `needsPartnerPicker`; new "Sell on behalf of" dropdown (Myself + candidates) for `needsAgentPicker` after a partner is chosen.
- NEW edge fn (user deploys): `frontend-transactions/supabase/functions/get-organization-agents/index.ts`.
- NOT YET: server-side create-sale changes (platform/soldOnBehalfOf insert + remove org-payment-model gate) — these are in `docs/backend/` for the web team to deploy. Until deployed, the live create-sale ignores the new fields / may reject non-assigned payment models.

---


Living record of what's done / not done. Update after every unit of work. Status: `TODO` | `WIP` | `DONE`.

Branch: `rewrite/super-admin`. Building for **super admin ONLY** (full surface). Per user directive (2026-06-27): ignore every other role — do not build/gate/branch for them. `getRolePermissions()` returns `RolePermissions.all` for any authenticated user; every route + feature open. Role map reintroduced later, no new screens needed.

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
