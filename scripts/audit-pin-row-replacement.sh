#!/usr/bin/env bash
# audit-pin-row-replacement.sh — WARN when a pin-audit allowlist row is
# replaced within 24h of its previous edit.
#
# Failure class (2026-11-14/15, the cv allowlist row): concurrent sessions
# pinning/adjusting the SAME input silently overwrite each other's row, each
# without seeing the other's evidence — the cv row was swapped twice between
# sessions hours apart while both believed they held the current state. The
# eval-time audit cannot see edit timing (sandboxed, no git), so this guard
# lives in git: when `lib/flake-input-pin-audit.nix` is staged, extract the
# allowlist rows the staged diff touches and pickaxe (`git log -G`) each row's
# input name for prior commits inside a 24h window.
#
# WARN-only by design: both sessions may be legitimately progressing the same
# pin (fix upstream → lift → re-float), so this must never block — it makes
# the "someone else edited this row <24h ago" fact loud at the moment of
# overwrite, the only time the second session can still look before clobbering.
#
# Scope: ONLY allowlist-row lines (`  <input> = "reason + LIFT …";`) touched
# by the staged diff (added, removed, or reason-rewritten — any rewrite of the
# single-line row matches `-G`). Comment-only edits to the file stay silent.
#
# Usage:
#   bash scripts/audit-pin-row-replacement.sh            # live (staged diff)
#   bash scripts/audit-pin-row-replacement.sh --selftest # prove both paths
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN_AUDIT_FILE="lib/flake-input-pin-audit.nix"
WINDOW_HOURS=24

# audit_rows <repo> <file> — core check, parameterized for the selftest.
# Emits WARN lines to stdout; returns 0 always (WARN-only).
audit_rows() {
  local repo="$1" file="$2"
  local touched_names prior
  touched_names=$(git -C "$repo" diff --cached -- "$file" 2>/dev/null |
    grep -E '^[+-][^+-]' |
    grep -oE '[A-Za-z0-9_.-]+ = "' |
    sed -E 's/ = "$//' || true)
  if [ -z "$touched_names" ]; then
    return 0
  fi
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    prior=$(git -C "$repo" log -G"${name} = " --since="${WINDOW_HOURS} hours ago" --format='%h|%cI' -- "$file" 2>/dev/null || true)
    if [ -n "$prior" ]; then
      local entry
      while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        local short ts
        short=${entry%%|*}
        ts=${entry#*|}
        echo "⚠ pin-row-replacement: allowlist row '${name}' is being replaced within ${WINDOW_HOURS}h of commit ${short} (${ts}) — concurrent sessions may be overwriting each other's pin evidence (the 2026-11-14 cv-row class). Verify the prior session's evidence before overwriting. (WARN-only, informational)"
      done <<<"$prior"
    fi
  done <<<"$touched_names"
  return 0
}

if [ "${1:-}" = "--selftest" ]; then
  # Hooks run with GIT_DIR/GIT_INDEX_FILE/GIT_WORK_TREE exported by the
  # invoking git — `git -C <tmpdir>` does NOT override an inherited GIT_DIR,
  # so an unscrubbed selftest would build its fixture IN THE REAL REPO.
  # Unset before any fixture git call.
  unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true
  # Throwaway repo (ephemeral per-run, mktemp is fine here):
  #   commit 1 (backdated 2 days): rows alpha + beta
  #   commit 2 (now): alpha's reason rewritten      -> the "prior edit" fixture
  #   staged:   alpha rewritten again  -> MUST WARN (within 24h of commit 2)
  #   staged:   beta rewritten         -> MUST NOT WARN (last touched 2 days ago)
  selft=$(mktemp -d)
  trap 'rm -rf "$selft"' EXIT
  git -C "$selft" init -q
  git -C "$selft" config user.name selftest
  git -C "$selft" config user.email selftest@invalid
  printf '  alpha = "old reason";\n  beta = "old reason";\n' >"$selft/pins.nix"
  git -C "$selft" add pins.nix
  # GIT_AUTHOR_DATE rejects approxidate strings ("2 days ago" = fatal 128) —
  # strict ISO only, else the fixture silently collapses and the assertions
  # below would run against a broken repo.
  two_days=$(date -u -d "2 days ago" +%Y-%m-%dT%H:%M:%S%z)
  GIT_AUTHOR_DATE="$two_days" GIT_COMMITTER_DATE="$two_days" git -C "$selft" commit -qm init
  git -C "$selft" rev-parse -q --verify HEAD >/dev/null || {
    echo "selftest BROKEN: fixture commit 1 failed to land (date format?)" >&2
    exit 1
  }
  printf '  alpha = "new reason";\n  beta = "old reason";\n' >"$selft/pins.nix"
  git -C "$selft" add pins.nix
  git -C "$selft" commit -qm "alpha reason rewrite"
  [ "$(git -C "$selft" rev-list --count HEAD)" -ge 2 ] || {
    echo "selftest BROKEN: fixture commit 2 failed to land" >&2
    exit 1
  }
  printf '  alpha = "newest reason";\n  beta = "old reason";\n' >"$selft/pins.nix"
  git -C "$selft" add pins.nix
  got_pos=$(audit_rows "$selft" pins.nix | grep -c "alpha" || true)
  got_neg=$(audit_rows "$selft" pins.nix | grep -c "beta" || true)
  if [ "${got_pos:-0}" -ge 1 ] && [ "${got_neg:-0}" -eq 0 ]; then
    echo "selftest OK: staged alpha rewrite WARNs (prior edit <24h), untouched beta stays silent"
    exit 0
  fi
  echo "selftest FAILED: alpha-WARN count=${got_pos:-0} (want >=1), beta-WARN count=${got_neg:-0} (want 0)" >&2
  exit 1
fi

# Live: silent no-op unless the pin-audit file is staged.
staged=$(git -C "$REPO_ROOT" diff --cached --name-only -- "$PIN_AUDIT_FILE" 2>/dev/null || true)
if [ -z "$staged" ]; then
  exit 0
fi
audit_rows "$REPO_ROOT" "$PIN_AUDIT_FILE"
exit 0
