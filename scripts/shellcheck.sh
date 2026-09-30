#!/usr/bin/env bash
# Lint target scripts with the repo's shellcheck expectations — one command
# that works anywhere.
#
# Why: shellcheck is not on the interactive PATH, the pre-commit leg only
# covers STAGED .sh files, so a mid-task `shellcheck scripts/foo.sh` fails
# with command-not-found — both the heal-breadcrumb authoring session
# (2026-09-28) and its review fix needed an ad-hoc `nix run nixpkgs#shellcheck`.
# This wrapper is the sanctioned resolution: shellcheck comes from THIS
# flake's LOCKED nixpkgs via --inputs-from (the floating `nix shell
# nixpkgs#shellcheck` form the hook uses is a pre-existing special case, not
# the pattern to copy — the lock is the reproducibility contract).
#
# Usage: scripts/shellcheck.sh <script-or-dir> [...]   (paths pass through)
#        an explicit --severity=... disables the default warning bar
#        (the pre-commit hook's bar; CI's shellcheck job arbitrates at error).
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

severity_default=true
for arg in "$@"; do
  case "$arg" in
  --severity=*) severity_default=false ;;
  esac
done
if [ "$severity_default" = true ]; then
  set -- --severity=warning "$@"
fi

exec nix run --inputs-from "$REPO_ROOT" nixpkgs#shellcheck -- "$@"
