# ACSL Sales Monitoring App

Flutter mobile app for ACSL agents and partner agents to record and track clean-cookstove sales. It is the mobile companion to the `frontend-transactions` web app and talks to the same Supabase backend.

**Current version:** see `version:` in [pubspec.yaml](pubspec.yaml).

## Features

- **Create sale**: one dynamic form for every role. Labels, options and required fields come from the backend sale dictionary at runtime, so the form stays aligned with the web app.
- **Offline-first**: sales made without a connection are queued in SQLite and synced on reconnect.
- **Sales list, financial reports and dashboard**: KPIs and charts.
- **Stoves**: stove inventory and transfer history.
- **Partners and agents**: filtered by the user's assigned organizations and states.
- **Settings**: payment models and user management, for roles allowed to see them.
- **In-app updates**: prompts users when a new APK has been released.

## Roles and permissions

One screen serves every role. Widgets and routes are shown or hidden by permission checks; there are no per-role screen variants.

Roles: `super_admin`, `acsl_agent_manager`, `acsl_agent`, `partner`, `partner_agent`, `agent` (legacy aliases are mapped by `resolveRole()`).

The role→permissions map lives in [lib/core/auth/permissions.dart](lib/core/auth/permissions.dart) and is a port of the web app's `src/lib/permissions.ts`. **Keep the two in sync.**

```dart
final perms = ref.watch(permissionsProvider);
if (perms.can(FeatureKey.approveSales)) ApproveButton();
if (perms.canAccess(RouteKey.settings)) SettingsTile();
```

## Tech stack

| Concern | Choice |
|---|---|
| State | Riverpod (`Notifier` / `AsyncNotifier`). GetX is being removed, so don't add new GetX code |
| Routing | `go_router`, a single `ShellRoute` (drawer + bottom nav), auth/permission guard in `redirect` |
| Backend | Supabase edge functions via `callEdgeFunction()` |
| Offline | `sqflite` queue + `sync_service` + `connectivity_plus` |
| Maps / location | `google_maps_flutter`, `geolocator` |
| Models | Hand-written `fromJson` / `toJson` (no codegen) |

## Project structure

```
lib/
  core/
    auth/         permissions (RouteKey, FeatureKey, role map)
    config/       env_config.dart (reads .env)
    constants/    app_colors.dart (the only place colors are defined)
    providers/    Riverpod providers wrapping services
    router/       app_router.dart
    services/     supabase, session, offline queue, sync, cache, releases
    theme/        app_theme.dart
    widgets/      shared UI components
  shell/          app shell (drawer + bottom nav)
  features/       auth, dashboard, sales, stoves, partners, agents, profile, settings
test/             unit + widget tests
docs/             architecture, design system and project memory
```

## Getting started

### Prerequisites

- Flutter SDK with Dart `>=3.2.0 <4.0.0`
- Android Studio / Android SDK (compile SDK 36), and Xcode if you build for iOS
- Access to the ACSL Supabase project

### Setup

1. Clone and install dependencies:

   ```bash
   flutter pub get
   ```

2. Create your env file from the template and fill in the values:

   ```bash
   cp .env.example .env
   ```

   | Variable | Purpose |
   |---|---|
   | `SUPABASE_URL` | Supabase project URL |
   | `SUPABASE_ANON_KEY` | Supabase anon (public) key |
   | `GOOGLE_MAPS_API_KEY` | Google Maps |
   | `GOOGLE_PLACES_API_KEY` | Google Places lookups |

   `.env` is bundled as an asset and must never be committed with real secrets.

3. For Android maps, add the key to `android/local.properties`:

   ```properties
   GOOGLE_MAPS_API_KEY=your_key_here
   ```

4. Register the git merge driver (once per clone):

   ```bash
   ./scripts/setup-merge-drivers.sh
   ```

5. Optional: if this repo uses a different git/Vercel/Supabase account from your default, scope your shell to it:

   ```bash
   source scripts/project-env.sh
   ```

### Run

```bash
flutter run
```

Use a physical device for location, camera and offline testing.

## Quality checks

Run these before opening a PR:

```bash
flutter analyze
```

```bash
flutter test
```

Project rules are also checked by grep:

- No `Supabase.from(` in feature code. Backend access goes through `callEdgeFunction()`. The one allowed exception is assignment-based read filtering in [partner_access_service.dart](lib/features/partners/partner_access_service.dart).
- No hex color literals outside [app_colors.dart](lib/core/constants/app_colors.dart).

## Releasing

APK releases are automated with GitHub Actions (**Actions → Release APK → Run workflow**). The workflow bumps the version, builds and signs the APK, publishes it to the web app's download folder and updates the `app_releases` row that drives the in-app updater.

See [docs/ci-release.md](docs/ci-release.md) for the steps and the required repository secrets.

## Documentation

Read these before changing code:

| File | What it covers |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Hard rules for this codebase |
| [docs/flutter.md](docs/flutter.md) | Architecture, folder layout, how to add a screen |
| [docs/design.md](docs/design.md) | Design tokens: color, spacing, radius, type |
| [docs/memory.md](docs/memory.md) | Per-route status, decisions, open questions |
| [docs/backend/](docs/backend/) | Backend contracts the app relies on |

## Contributing rules (short version)

1. Access the backend through edge functions, not direct table queries.
2. Use color tokens and design-file values; never hardcode them.
3. Keep one view per screen and gate by permission.
4. Don't break the offline queue / sync path.
5. Write new state with Riverpod.
6. Update `docs/memory.md` after each unit of work.
