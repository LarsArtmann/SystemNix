#!/usr/bin/env bash
# Fixture test for the pre-commit hook's nix-parse leg (.githooks/pre-commit).
#
# 2026-09-30 context: the auto-commit daemon has swept broken *.nix
# intermediates into history 4× (the race between a session's check and its
# add); this leg catches syntax breakage at commit time for sub-second cost
# (parse-only — no imports, no eval).
#
# Static asserts pin the REAL hook's load-bearing properties:
#   P1 the leg parses with `nix-instantiate --parse "$f"` (parse-only, per
#      file — the full flake check stays with CI/pre-deploy)
#   P2 the staged-file selection is NUL-delimited (--diff-filter=ACM -z
#      '*.nix' — space-safe paths, deletions excluded)
#   P3 fail-closed: a parse failure exits 1 (broken syntax must not ride a
#      green-looking commit into the daemon's sweep window)
#
# Dynamic proof runs the leg VERBATIM (gate + NUL loop, copied from the
# hook) against a scratch git repo:
#   D1 a staged broken .nix FAILS the leg
#   D2 a staged valid .nix at a nested path PASSES
#   D3 a staged DELETION alone skips cleanly (empty ACM selection — no
#      parser invocation on a gone file)
#
# Run: bash scripts/test-precommit-nix-parse.sh  (also a flake check; there
# bare `nix-instantiate` resolves from the pinned pkgs.nix in PATH — on the
# host that IS the hook's real invocation).
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

echo "=== Static asserts on $HOOK (the nix-parse leg's load-bearing text) ==="
grep -qF 'nix-instantiate --parse "$f"' "$HOOK" &&
  ok "P1 leg parses per-file with nix-instantiate --parse (no imports, no eval)" ||
  die "P1 parse command drifted — leg and test must be re-synced"
sed -n '/Fast guard: staged .nix files must PARSE/,/^fi$/p' "$HOOK" | grep -qF -- "--diff-filter=ACM -z '*.nix'" &&
  ok "P2 selection is NUL-delimited with deletions excluded" ||
  die "P2 selection pipeline drifted"
sed -n '/parse_failed=false/,/^fi$/p' "$HOOK" | grep -qF "exit 1" &&
  ok "P3 parse failure is fail-closed (exit 1)" ||
  die "P3 leg no longer fail-closed"

echo "=== Dynamic proof (scratch repo, leg verbatim) ==="
SCRATCH=$(mktemp -d)
LEG_LOG="$SCRATCH/leg.log"
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init -q
git -C "$SCRATCH" config user.name fixture
git -C "$SCRATCH" config user.email fixture@example.com

leg() {
  # The hook's nix-parse leg, verbatim (gate + NUL loop). The subshell
  # mirrors the hook's cwd: git runs pre-commit from the worktree root.
  local staged parse_failed
  staged=$(git -C "$SCRATCH" diff --cached --name-only --diff-filter=ACM '*.nix')
  if [ -n "$staged" ]; then
    (
      cd "$SCRATCH" || exit 1
      parse_failed=false
      while IFS= read -r -d '' f; do
        if ! nix-instantiate --parse "$f" > /dev/null 2> "$SCRATCH/parse-err.log"; then
          parse_failed=true
        fi
      done < <(git diff --cached --name-only --diff-filter=ACM -z '*.nix')
      [ "$parse_failed" = false ]
    ) >"$LEG_LOG" 2>&1
    return $?
  fi
  echo "No staged .nix files — skipping." >"$LEG_LOG"
  return 0
}

mkdir -p "$SCRATCH/modules"
cat >"$SCRATCH/modules/valid.nix" <<'EOF'
{ lib, ... }: {
  options.services.fixture.enable = lib.mkEnableOption "fixture";
}
EOF
git -C "$SCRATCH" add modules/valid.nix
git -C "$SCRATCH" commit -qm baseline

# D1: staged broken .nix must fail the leg.
cat >"$SCRATCH/modules/broken.nix" <<'EOF'
config = { services.fixture.enable = ;
EOF
git -C "$SCRATCH" add modules/broken.nix
if leg; then
  die "D1 staged parse-broken .nix passed the leg — coverage is broken"
else
  ok "D1 staged broken .nix rejected by the parse leg"
fi

# D2: staged valid .nix at a nested path passes.
git -C "$SCRATCH" restore --staged modules/broken.nix
rm -f "$SCRATCH/modules/broken.nix"
mkdir -p "$SCRATCH/modules/nested"
cat >"$SCRATCH/modules/nested/deep.nix" <<'EOF'
{ ... }: { imports = [ ../valid.nix ]; }
EOF
git -C "$SCRATCH" add modules/nested/deep.nix
if leg; then
  ok "D2 staged valid .nix (nested path) parses and passes"
else
  die "D2 valid nested .nix failed the leg (log: $(head -c 200 "$LEG_LOG"; head -c 200 "$SCRATCH/parse-err.log" 2>/dev/null))"
fi

# D3: a staged deletion alone skips the leg (empty ACM selection guard).
git -C "$SCRATCH" commit -qm touch
git -C "$SCRATCH" rm -q modules/nested/deep.nix
if leg; then
  if grep -q "No staged .nix files" "$LEG_LOG"; then
    ok "D3 staged deletion skips the leg (empty-selection guard)"
  else
    die "D3 leg passed but not via the skip branch"
  fi
else
  die "D3 deletion-only staging failed the leg (log: $(head -c 200 "$LEG_LOG"))"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo ""
  echo "SELFTEST FAILED: $FAILURES assertion(s) broken"
  exit 1
fi
echo ""
echo "SELFTEST OK: the pre-commit nix-parse leg covers staged *.nix (detect + pass + skip)"
