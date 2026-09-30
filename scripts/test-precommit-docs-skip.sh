#!/usr/bin/env bash
# Fixture test for the pre-commit hook's docs-only flake-check skip guard
# (.githooks/pre-commit, landed 2026-09-28).
#
# Why this is pinned: the guard's classification (`grep -qvE
# '\.(md|html|txt)$'` over ALL staged paths) is the only thing standing
# between docs commits and the flake-eval leg's environmental flap (GC-evicted
# input sources, /run/binfmt host probes — four docs-only hook aborts in the
# 2026-09-26/27 window). A lossy "simplification" of the pattern silently
# changes which commits skip, which is exactly the failure the throwaway
# /tmp verification could not guard against.
#
# Static asserts pin the REAL hook's load-bearing properties:
#   T1 the classification greps ALL staged paths (no --diff-filter) against
#      '\.(md|html|txt)$' — DELETED .nix paths must still force the leg
#   T2 the empty-staged branch skips independently
#   T3 the skip is logged (visible in hook output, not silent)
#
# Dynamic proof runs the classification VERBATIM (copied from the hook)
# against a scratch git repo:
#   G1 docs-only staged diff (.md/.html/.txt) → SKIP branch
#   G2 .nix mixed into the diff → RUN branch
#   G3 a DELETED .nix alone → RUN branch (deletions affect eval)
#   G4 an extension-less staged file → RUN branch (conservative force)
#
# Run: bash scripts/test-precommit-docs-skip.sh  (also a flake check).
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Overridable so the flake check can negative-test a mutated hook.
HOOK="${PRECOMMIT_HOOK:-$REPO_ROOT/.githooks/pre-commit}"

FAILURES=0
die() {
  echo "  FAIL $1"
  FAILURES=$((FAILURES + 1))
}
ok() {
  echo "  ok   $1"
}

echo "=== Static asserts on $HOOK (the docs-only skip guard's load-bearing text) ==="
grep -qF "git diff --cached --name-only | grep -qvE '\\\\.(md|html|txt)\\$'" "$HOOK" &&
  ok "T1 classification covers ALL staged paths (no --diff-filter; deletions counted)" ||
  die "T1 classification line drifted — guard and test must be re-synced"
grep -qF 'elif [ -z "$STAGED_ALL" ]' "$HOOK" &&
  ok "T2 empty-staged branch skips independently" ||
  die "T2 empty branch drifted"
grep -qF "Docs-only staged diff" "$HOOK" &&
  ok "T3 the skip is logged" ||
  die "T3 skip log line drifted"

echo "=== Dynamic proof (scratch repo, classification verbatim) ==="
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init -q
git -C "$SCRATCH" config user.name fixture
git -C "$SCRATCH" config user.email fixture@example.com

guard() {
  # The hook's classification, verbatim (STAGED_ALL + docs-only branch).
  local STAGED_ALL
  STAGED_ALL=$(git -C "$SCRATCH" diff --cached --name-only)
  if [ -n "$STAGED_ALL" ] && ! git -C "$SCRATCH" diff --cached --name-only | grep -qvE '\.(md|html|txt)$'; then
    echo "docs-only-skip"
  elif [ -z "$STAGED_ALL" ]; then
    echo "empty-skip"
  else
    echo "run"
  fi
}

# G1: docs-only diff takes the skip branch.
echo note >"$SCRATCH/a.md"
echo page >"$SCRATCH/b.html"
echo txt >"$SCRATCH/c.txt"
git -C "$SCRATCH" add a.md b.html c.txt
[ "$(guard)" = "docs-only-skip" ] &&
  ok "G1 docs-only diff (.md/.html/.txt) skips the flake-check leg" ||
  die "G1 docs-only diff did NOT take the skip branch"

# G2: a .nix mixed in forces the run branch.
printf '{ }: { }\n' >"$SCRATCH/d.nix"
git -C "$SCRATCH" add d.nix
[ "$(guard)" = "run" ] &&
  ok "G2 .nix in the diff forces the leg" ||
  die "G2 mixed diff wrongly skipped the leg"

# G3: a DELETED .nix alone forces the run branch (no --diff-filter).
git -C "$SCRATCH" commit -qm baseline
git -C "$SCRATCH" restore --staged a.md b.html c.txt
git -C "$SCRATCH" commit -qm drop-md >/dev/null 2>&1 || true
git -C "$SCRATCH" rm -q d.nix
[ "$(guard)" = "run" ] &&
  ok "G3 deleted .nix alone forces the leg (deletions counted)" ||
  die "G3 deletion-only diff wrongly skipped the leg"

# G4: an extension-less staged file forces the run branch (conservative).
git -C "$SCRATCH" commit -qm rm >/dev/null 2>&1 || true
echo make >"$SCRATCH/Makefile"
git -C "$SCRATCH" add Makefile
[ "$(guard)" = "run" ] &&
  ok "G4 extension-less staged file forces the leg" ||
  die "G4 extension-less file wrongly skipped the leg"

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "SELFTEST FAILED: $FAILURES assertion(s) broken"
  exit 1
fi
echo ""
echo "SELFTEST OK: the docs-only skip guard classifies correctly (skip docs-only, run mixed/deleted/extension-less)"
