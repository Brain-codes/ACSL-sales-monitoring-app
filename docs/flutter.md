# flutter.md — Architecture Spec

How this app is built. Read alongside `CLAUDE.md` and `docs/design.md`.

## Stack

- **State:** Riverpod (`flutter_riverpod`). `Notifier` / `AsyncNotifier` for screen state; plain providers for services. GetX is being removed — no new GetX.
- **Routing:** `go_router` with one `ShellRoute` rendering the persistent shell (sidebar drawer + bottom nav). Auth + permission enforced in the router `redirect`.
- **Backend:** Supabase edge functions via `callEdgeFunction()` only (`supabaseServiceProvider`). Never `Supabase.from()`.
- **Offline:** SQLite queue (`offline_queue_service`), `sync_service`, `connectivity_service`, `local_cache_service` — reused logic, exposed as providers.

## Folder structure

```
lib/
  core/
    auth/         permissions.dart (RouteKey, FeatureKey, PERMISSIONS, helpers)
    constants/    app_colors.dart (SINGLE color token source)
    providers/    riverpod providers wrapping services
    router/       app_router.dart (go_router + ShellRoute + redirect guard)
    services/     supabase, session, offline queue, sync, connectivity, cache (logic)
    theme/        app_theme.dart (references app_colors only)
  shell/          app_shell.dart (sidebar + bottom nav)
  features/
    <feature>/    screen(s) + models + <feature>_provider.dart (AsyncNotifier)
```

## Service → provider boundary

Each service keeps its data/IO logic (SQLite, HTTP). The Riverpod provider owns lifecycle and reactive state. Example:
`supabaseServiceProvider` → `SupabaseService.callEdgeFunction(...)`.
`sessionProvider` (Notifier) → holds auth + resolved role; `permissionsProvider` derives routes/features from it.

## Permission gating

```dart
final perms = ref.watch(permissionsProvider);
if (perms.can(FeatureKey.approveSales)) ApproveButton(),   // in-screen widget
// sidebar item:  if (perms.canAccess(RouteKey.settings)) ...
```
Super admin returns true for everything, so its screens render every widget. Other roles hide widgets via the same checks — no separate screens.

## Adding a screen

1. Add a `RouteKey` in `permissions.dart` (and to `super_admin` ALL list).
2. Add a `GoRoute` child under the `ShellRoute` in `app_router.dart`.
3. Add a sidebar entry (gated by `canAccess`).
4. Build the screen as a `ConsumerWidget`; data via an `AsyncNotifier`; offline-aware reads via `local_cache_service`.
5. Update `docs/memory.md` status.

## Models

Manual `fromJson` / `toJson`. No codegen (`freezed`/`json_serializable`).
