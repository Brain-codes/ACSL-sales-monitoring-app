# CLAUDE.md — ACSL Sales Monitoring App

Operating rules for this codebase. **Read `docs/memory.md`, `docs/design.md`, and `docs/flutter.md` before starting any task.** These three files + this one are the source of truth; follow them religiously.

## Project intent

Rebuilding the app as a **single-view, monolith UI** that mirrors the `frontend-transactions` web app. One screen serves all roles; widgets/buttons are shown or hidden by permission checks — never fork a screen per role.

**SUPER-ADMIN-ONLY (current phase):** Build only for super admin. Ignore every other role — do not build, gate, or branch for them. Any authenticated user is treated as super admin and gets the **full surface: every route and feature open at a go**. `getRolePermissions()` in `permissions.dart` returns `RolePermissions.all` for everyone. The gating infrastructure (`canAccess`/`can`) stays in place so screens remain single-view; other roles are reintroduced **later** by restoring a role→permissions map — **not** by writing new screens.

## Hard rules

1. **No direct table queries** (default). Prefer `callEdgeFunction()` for backend access. **Authorized exception:** assignment-based read filtering may query Supabase tables directly via the user's session (RLS applies) — see `lib/features/partners/partner_access_service.dart` (partners filtered by `acsl_agent_organizations` / `acsl_agent_states`). Mirrors the web app's `organizationsService`. Keep such direct queries in a dedicated service, not scattered in widgets.
2. **No hardcoded colors.** Every color references a named token in `lib/core/constants/app_colors.dart` — the single source of truth. Changing the brand there must propagate everywhere. Old blue brand values stay commented out for rollback; do not delete them. No raw `Color(0x...)` or hex outside that one file.
3. **No hardcoded design values.** Spacing, radius, and type follow `docs/design.md`. Update the design file first, then code follows it.
4. **Single view + permission gating.** Use `canAccess(RouteKey.x)` / `can(FeatureKey.x)` to show/hide widgets. Do not create role-specific screen variants.
5. **Offline-first.** Reads go through the local cache where one exists; writes (e.g. create sale) queue via the offline engine and sync on reconnect. Never break the SQLite queue / sync path.
6. **State = Riverpod.** New code uses Riverpod (`Notifier`/`AsyncNotifier`, providers). GetX is being removed; do not add new GetX usage.

## Conventions

- Models use manual `fromJson` / `toJson` (no codegen).
- Routing is go_router with a single `ShellRoute` (sidebar + bottom nav). Add a screen by adding a route + a `RouteKey` + a sidebar entry.
- After each unit of work, update `docs/memory.md` (per-route status, decisions, open questions).

## Verification

I do **not** run the app — the user runs it on a physical device. My checks are code-level: `flutter analyze` clean, and grep that no `Supabase.from(` exists in feature code and no hex literals live outside `app_colors.dart`. Hand off on-device testing to the user.
