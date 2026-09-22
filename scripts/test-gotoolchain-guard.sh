#!/usr/bin/env bash
# test-gotoolchain-guard.sh — negative-test for the .githooks/pre-commit
# GOTOOLCHAIN=auto guard.
#
# House doctrine: hook guards get negative-tested like flake checks
# (same rationale as scripts/negative-test-lints.sh). Two incidents hit this
# guard in one day (2026-09-22): the FP fix narrowed the predicate and the
# narrowing SILENTLY dropped the unquoted/spaced nix shape `GOTOOLCHAIN =
# auto` — a shape change with nothing to catch it.
#
# This selftest extracts the LIVE predicate and off-exclusion from the hook
# itself (never a copied pattern — second-source-of-truth drift class; a
# renamed/moved guard fails the extraction loudly) and pins the boundary:
#
#   guard MUST fire:  GOTOOLCHAIN = "auto";   (quoted nix value)
#                     GOTOOLCHAIN = auto;     (unquoted nix value — the shape
#                                              the first narrowing dropped)
#                     GOTOOLCHAIN=auto        (bare env form)
#   guard MUST pass:  set -gx GOTOOLCHAIN auto  (home.nix fish session
#                                                override — the original FP)
#                     GOTOOLCHAIN = "local";      (the sanctioned purity pin)
#                     auto line carrying an off marker (off-exclusion)
#
# Usage:
#   bash scripts/test-gotoolchain-guard.sh   # exit 0 = pinned shapes hold
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/.githooks/pre-commit"

# Extract the guard's two patterns from the hook source (both are single-
# quoted EREs with no embedded single quotes).
PREDICATE=$(grep -oE "grep -E 'GOTOOLCHAIN[^']*'" "$HOOK" 2>/dev/null | head -1 | sed "s/^grep -E '//; s/'\$//")
EXCLUDE=$(grep -oE "grep -qvE 'GOTOOLCHAIN[^']*'" "$HOOK" 2>/dev/null | head -1 | sed "s/^grep -qvE '//; s/'\$//")

rc=0
if [ -z "$PREDICATE" ]; then
  echo "SELFTEST FAIL: could not extract the guard predicate from .githooks/pre-commit (guard renamed or moved?)"
  exit 1
fi
if [ -z "$EXCLUDE" ]; then
  echo "SELFTEST FAIL: could not extract the guard off-exclusion from .githooks/pre-commit"
  exit 1
fi

# Mirrors the hook's exact per-file pipeline.
violates() {
  grep -E "$PREDICATE" "$1" 2>/dev/null | grep -qvE "$EXCLUDE"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ── must be CAUGHT ──
while IFS='|' read -r name line; do
  printf '%s\n' "$line" >"$tmp/$name"
  if ! violates "$tmp/$name"; then
    echo "SELFTEST FAIL: guard missed a violation shape: $line"
    rc=1
  fi
done <<'SHAPES'
evil-quoted-nix.nix|GOTOOLCHAIN = "auto";
evil-unquoted-nix.nix|GOTOOLCHAIN = auto;
evil-bare-env.nix|GOTOOLCHAIN=auto
SHAPES

# ── must PASS ──
while IFS='|' read -r name line; do
  printf '%s\n' "$line" >"$tmp/$name"
  if violates "$tmp/$name"; then
    echo "SELFTEST FAIL: guard flagged a sanctioned shape: $line"
    rc=1
  fi
done <<'SHAPES'
good-fish.nix|set -gx GOTOOLCHAIN auto
good-local.nix|GOTOOLCHAIN = "local";
good-off.nix|GOTOOLCHAIN = auto; # off
SHAPES

if [ "$rc" -eq 0 ]; then
  echo "SELFTEST OK: GOTOOLCHAIN guard catches quoted/unquoted nix + bare env auto; passes fish override, local pin, off-exclusion"
fi
exit "$rc"
