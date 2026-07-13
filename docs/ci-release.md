# Automated APK release (GitHub Actions)

Replaces the manual "build APK → rename → copy into frontend-transactions →
update Supabase" dance. Workflow: [`.github/workflows/release.yml`](../.github/workflows/release.yml).

## How to cut a release

1. GitHub → this repo → **Actions** tab → **Release APK** → **Run workflow**.
2. Fill in:
   - **version** — e.g. `1.0.9` (no leading `v`).
   - **release notes** — shown in the in-app update sheet.
   - **force update** — tick to make users update before continuing.
3. Run. In a few minutes the APK is live on the download site and the in-app
   updater points to it. No manual copying, renaming, or Supabase editing.

## What it does

- Sets `version:` in `pubspec.yaml` (with an auto Android `versionCode`) and
  `kAppVersion` in `app_release_service.dart` — one source of truth.
- Builds `flutter build apk --release`. Dev tools (test autofill + offline cache
  debug) are stripped automatically because they're behind `kDebugMode`.
- Signs with **your** debug keystore (restored from a secret) so the signature
  matches existing installs — users update in place, no reinstall.
- Renames to `sales-monitoring-app-vX-Y-Z.apk` and commits it into
  `frontend-transactions/public/downloads/`. Vercel auto-deploys it.
- Updates the single `app_releases` row in Supabase (`version`, `apk_path`,
  `release_notes`, `size`, `is_force_update`) via the service-role key.
- Commits the version bump back to this repo.

## One-time setup — GitHub Secrets

Add these under **this repo → Settings → Secrets and variables → Actions → New
repository secret**:

| Secret | What it is | How to get it |
|--------|-----------|---------------|
| `ENV_FILE` | Full contents of your local `.env` | `pbcopy < .env` then paste |
| `ANDROID_DEBUG_KEYSTORE_BASE64` | Base64 of the keystore that signs your current APKs | `base64 -i ~/.android/debug.keystore \| pbcopy` then paste |
| `WEB_REPO_PAT` | GitHub token that can push to `Brain-codes/frontend-transactions` | Create a fine-grained PAT with **Contents: Read/Write** on that repo |
| `SUPABASE_URL` | Your Supabase project URL | Supabase → Project Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role key (updates the release row) | Supabase → Project Settings → API → `service_role` |

> If `~/.android/debug.keystore` doesn't exist yet, run any `flutter build apk`
> once locally to generate it, then export it. This is the exact key your past
> APKs were signed with — using it in CI is what keeps in-place updates working.

## Notes / gotchas

- The `get-stove-ids` **format2** edge-function change still needs to be deployed
  separately (Supabase functions aren't part of this pipeline).
- If `main` has branch protection that blocks the bot, the version-bump commit
  (step 9) will fail — either allow the Actions bot or relax protection.
- `base_url` in `app_releases` is left untouched; the workflow only swaps
  `apk_path` to the new versioned filename.
