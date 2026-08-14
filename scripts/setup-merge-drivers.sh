#!/usr/bin/env bash
# Registers the "ours" merge driver so .gitattributes merge=ours entries work.
# Run once per clone, and once in CI (git config lives in .git/config, which
# isn't committed).
#
# Upstream for this repo is Brain-codes/ACSL-sales-monitoring-app. Without this
# driver, `git merge upstream/main` silently ignores every merge=ours entry.
# GitHub's web "Sync fork" button can never run it, which is why upstream
# syncing must happen locally or in CI, not through the web UI.
set -euo pipefail
git config merge.ours.driver true
echo "Registered 'ours' merge driver. .gitattributes merge=ours entries are now active."
