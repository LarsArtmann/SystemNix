#!/usr/bin/env bash
# Fixture test for the pre-commit hook's eval-relevance flake-check skip
# (.githooks/pre-commit; docs-only form landed 2026-09-28, widened 2026-11-03
# to the shared eval-relevant tree definition — S-048 / the TODO_LIST
# "OOM-kill risk + ~4-min daemon-race window" row — after the 2026-11-03
# 22GB full-check run was forced by a .githooks+pipeline.md commit that
# could not change eval outcome).
#
# Why this is pinned: the classification decides whether a commit pays the
# ~20GB RSS / ~4-7min `nix flake check --no-build --all-systems` walk
# (docs/agents/nix-flakes.md "flake-check memory profile"). A lossy
# "simplification" — inlining a drifted path list instead of sourcing
# scripts/lib/eval-relevant-paths.sh, dropping the --diff-filter=DR
# structural leg, or narrowing the docs carve-out — silently changes which
# commits skip, which is exactly the failure a throwaway verification
# cannot guard against.
#
# Static asserts pin the REAL hook's load-bearing properties:
#   T1 the classification sources the SHARED path definition (no inline drift)
#   T2 the pathspec walks "${EVAL_RELEVANT_PATHS[@]}"
#   T3 deletions/renames of ANY tracked path force the leg (--diff-filter=DR)
#   T4 the docs carve-out grep '\.(md|html|txt)$'
#   T5 the skip is logged (visible in hook output, not silent)
#   T6 the empty-staged branch skips independently
#
# Dynamic proof runs the classification VERBATIM (copied from the hook)
# against a scratch git repo:
#   G0  nothing staged (the --allow-empty shape) → SKIP_EMPTY branch
#   G1  docs-only staged diff (.md/.html/.txt outside eval roots) → SKIP
#   G2  the 2026-11-03 case: .githooks/pre-commit + docs/todo/pipeline.md → SKIP
#   G3  scripts/deploy.sh + .github/workflows/*.yml content edits → SKIP
#   G4  docs-type under an eval root (modules/readme.md) → SKIP (carve-out)
#   G5  modules/**.nix → RUN
#   G6  lib/*.nix → RUN
#   G7  flake.lock → RUN
#   G8  pkgs/ nested root → RUN
#   G9  scripts/lib/buildcache-reap-names.sh CONTENT edit → RUN (eval-parsed)
#   G10 DELETED non-eval-root file (scripts/deploy.sh) → RUN (readFile absence)
#   G11 RENAMED .github file → RUN (delete side of R)
#
# Run: bash scripts/test-precommit-eval-skip.sh  (also a flake check).
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Overridable so the flake check can negative-test a mutated hook.
HOOK="${PRECOMMIT_HOOK:-$REPO_ROOT/.githooks/pre-commit}"
EVAL_PATHS_LIB="${PRECOMMIT_EVAL_PATHS_LIB:-$REPO_ROOT/scripts/lib/eval-relevant-paths.sh}"

FAILURES=0
die() {
  echo "  FAIL $1"
  FAILURES=$((FAILURES + 1))
}
ok() {
  echo "  ok   $1"
}

echo "=== Static asserts on $HOOK (the eval-relevance skip guard's load-bearing text) ==="
grep -qF 'source scripts/lib/eval-relevant-paths.sh' "$HOOK" &&
  ok "T1 classification sources the shared eval-relevant path definition" ||
  die "T1 shared-definition source line drifted — guard and test must be re-synced"
grep -qF -- '-- "${EVAL_RELEVANT_PATHS[@]}"' "$HOOK" &&
  ok "T2 pathspec walks the shared array (no inline path list)" ||
  die "T2 EVAL_RELEVANT_PATHS pathspec drifted"
grep -qF -- '--diff-filter=DR' "$HOOK" &&
  ok "T3 deletions/renames of ANY path force the leg (readFile-absence class)" ||
  die "T3 structural (--diff-filter=DR) leg drifted"
grep -qF "grep -vE '\\.(md|html|txt)\$'" "$HOOK" &&
  ok "T4 docs carve-out present" ||
  die "T4 docs carve-out drifted"
grep -qF "Eval-irrelevant staged diff" "$HOOK" &&
  ok "T5 the skip is logged" ||
  die "T5 skip log line drifted"
grep -qF 'elif [ -z "$STAGED_ALL" ]' "$HOOK" &&
  ok "T6 empty-staged branch skips independently" ||
  die "T6 empty branch drifted"

echo "=== Dynamic proof (scratch repo, classification verbatim) ==="
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init -q
git -C "$SCRATCH" config user.name fixture
git -C "$SCRATCH" config user.email fixture@example.com
# The G2 fixture stages a literal .githooks/pre-commit path; with a global
# core.hooksPath that makes scratch commits try (and hint-ignore) it. Point
# the scratch repo at an empty hooks dir so no hook ever runs here.
mkdir -p "$SCRATCH/.no-hooks"
git -C "$SCRATCH" config core.hooksPath "$SCRATCH/.no-hooks"

# shellcheck source=scripts/lib/eval-relevant-paths.sh
source "$EVAL_PATHS_LIB"

guard() {
  # The hook's classification, verbatim.
  local STAGED_ALL STAGED_EVAL_RELEVANT STAGED_STRUCTURAL
  STAGED_ALL=$(git -C "$SCRATCH" diff --cached --name-only)
  STAGED_EVAL_RELEVANT=$(git -C "$SCRATCH" diff --cached --name-only -- "${EVAL_RELEVANT_PATHS[@]}")
  STAGED_EVAL_RELEVANT=$(printf '%s\n' "$STAGED_EVAL_RELEVANT" | grep -vE '\.(md|html|txt)$' || true)
  STAGED_STRUCTURAL=$(git -C "$SCRATCH" diff --cached --name-only --diff-filter=DR)
  if [ -n "$STAGED_ALL" ] && [ -z "$STAGED_EVAL_RELEVANT" ] && [ -z "$STAGED_STRUCTURAL" ]; then
    echo "eval-irrelevant-skip"
  elif [ -z "$STAGED_ALL" ]; then
    echo "empty-skip"
  else
    echo "run"
  fi
}

fixture() {
  mkdir -p "$SCRATCH/$(dirname "$1")"
  printf '%s\n' "$2" >"$SCRATCH/$1"
}
expect() {
  if [ "$(guard)" = "$1" ]; then
    ok "$2"
  else
    die "$3"
  fi
}

# G0: nothing staged — the `git commit --allow-empty` shape (SKIP_EMPTY).
expect empty-skip "G0 empty staged set takes the SKIP_EMPTY branch" "G0 empty staged set did NOT take the SKIP_EMPTY branch"

# G1: docs-only diff takes the skip branch.
fixture a.md note
fixture b.html page
fixture c.txt txt
git -C "$SCRATCH" add a.md b.html c.txt
expect eval-irrelevant-skip "G1 docs-only diff (.md/.html/.txt) skips the flake-check leg" "G1 docs-only diff did NOT take the skip branch"

# G2: the 2026-11-03 regression case — the hook itself + a pipeline doc.
fixture .githooks/pre-commit '# hook'
fixture docs/todo/pipeline.md row
git -C "$SCRATCH" add .githooks/pre-commit docs/todo/pipeline.md
expect eval-irrelevant-skip "G2 .githooks + docs/todo staged (the 2026-11-03 22GB case) skips" "G2 hook+doc diff wrongly forced the leg"

# G3: non-eval-root content edits skip (drvPath-only, never realized by --no-build).
fixture scripts/deploy.sh 'exit 0'
fixture .github/workflows/ci.yml 'on: push'
git -C "$SCRATCH" add scripts/deploy.sh .github/workflows/ci.yml
expect eval-irrelevant-skip "G3 scripts/*.sh + .github/*.yml content edits skip" "G3 non-eval-root edits wrongly forced the leg"

# The eval-parsed exception ships with the baseline (its EDIT is the G9 case).
fixture scripts/lib/buildcache-reap-names.sh 'BUILDCACHE_REAP_CACHE_DIRS="go-build"'
git -C "$SCRATCH" add scripts/lib/buildcache-reap-names.sh

git -C "$SCRATCH" commit -qm baseline

# G4: docs-type under an eval root skips (carve-out; BUILD-time asserts only).
fixture modules/readme.md doc
git -C "$SCRATCH" add modules/readme.md
expect eval-irrelevant-skip "G4 .md under modules/ skips (docs carve-out)" "G4 eval-root docs-type wrongly forced the leg"
git -C "$SCRATCH" commit -qm doc >/dev/null 2>&1 || true

# G5-G8: eval-relevant paths run the leg.
fixture modules/nixos/services/foo.nix '{ }: { }'
git -C "$SCRATCH" add modules/nixos/services/foo.nix
expect run "G5 modules/**.nix forces the leg" "G5 module diff wrongly skipped the leg"
fixture lib/ports.nix '{ }'
git -C "$SCRATCH" add lib/ports.nix
expect run "G6 lib/*.nix forces the leg" "G6 lib diff wrongly skipped the leg"
fixture flake.lock '{}'
git -C "$SCRATCH" add flake.lock
expect run "G7 flake.lock forces the leg" "G7 lock diff wrongly skipped the leg"
fixture pkgs/dms-plugins/x.nix '{ }'
git -C "$SCRATCH" add pkgs/dms-plugins/x.nix
expect run "G8 pkgs/ nested root forces the leg" "G8 pkgs diff wrongly skipped the leg"

# G9: the eval-PARSED file outside the directory roots — CONTENT edit runs.
printf 'BUILDCACHE_REAP_CACHE_DIRS="go-build rust-target"\n' >"$SCRATCH/scripts/lib/buildcache-reap-names.sh"
git -C "$SCRATCH" add scripts/lib/buildcache-reap-names.sh
expect run "G9 buildcache-reap-names.sh content edit forces the leg (eval-parsed)" "G9 eval-parsed .sh edit wrongly skipped the leg"

git -C "$SCRATCH" commit -qm evalroots >/dev/null 2>&1 || true

# G10: DELETED non-eval-root file forces the leg (eval readFile absence throws).
git -C "$SCRATCH" rm -q scripts/deploy.sh
expect run "G10 deleted scripts/deploy.sh forces the leg (readFile absence class)" "G10 deletion-only diff wrongly skipped the leg"
git -C "$SCRATCH" commit -qm rm >/dev/null 2>&1 || true

# G11: RENAME of a non-eval-root file forces the leg (delete side of R).
git -C "$SCRATCH" mv .github/workflows/ci.yml .github/workflows/ci2.yml
expect run "G11 renamed .github file forces the leg" "G11 rename wrongly skipped the leg"

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "SELFTEST FAILED: $FAILURES assertion(s) broken"
  exit 1
fi
echo ""
echo "SELFTEST OK: the eval-relevance skip guard classifies correctly (skip non-eval-root content + docs-typefiles + empty; run eval-root paths, the eval-parsed .sh, deletions, renames)"
