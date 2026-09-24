#!/usr/bin/env bash
# Fixture test for the pre-commit hook's shellcheck leg (.githooks/pre-commit).
#
# 2026-09-23 context: whether shellcheck actually ran when a new script was
# first staged was unverifiable — this proves the leg end-to-end so the
# question never has to be re-asked.
#
# Static asserts pin the REAL hook's load-bearing properties:
#   S1 the staged-file gate uses the `*.sh` pathspec (matches nested
#      scripts/ paths, not just repo-root *.sh)
#   S2 the run pipeline is NUL-delimited (-z + xargs -0 — space-safe paths)
#   S3 the bar is --severity=warning (CI's shellcheck job is error-level;
#      the hook is the stricter of the two)
#   S4 --diff-filter=ACM excludes deletions (never shellcheck a gone file)
#   S5 fail-closed: violations set all_passed=false (block the commit)
#
# Dynamic proof runs the leg VERBATIM (gate + pipeline, copied from the
# hook) against a scratch git repo:
#   D1 a staged scripts/dirty.sh with an SC2034 violation FAILS the leg and
#      the log names the file (nested-path coverage + detection)
#   D2 a staged clean modification PASSES
#   D3 a staged DELETION alone skips the leg cleanly (the empty-selection
#      guard — without it, xargs -0 on empty input invokes shellcheck with
#      no args and it blocks on stdin)
#
# Run: bash scripts/test-precommit-shellcheck.sh  (also a flake check;
# there SHELLCHECK_BIN is pinned because `nix shell` cannot run inside a
# build sandbox — on the host the default IS the hook's real invocation).
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Overridable so the flake check can negative-test a mutated hook.
HOOK="${PRECOMMIT_HOOK:-$REPO_ROOT/.githooks/pre-commit}"

if [ -n "${SHELLCHECK_BIN:-}" ]; then
  SC_CMD=("$SHELLCHECK_BIN")
else
  # The hook's exact invocation.
  SC_CMD=(nix shell nixpkgs#shellcheck --command shellcheck)
fi

FAILURES=0
die() {
  echo "  FAIL $1"
  FAILURES=$((FAILURES + 1))
}
ok() {
  echo "  ok   $1"
}

echo "=== Static asserts on $HOOK (the .sh leg's load-bearing text) ==="
grep -qF "STAGED_SH=\$(git diff --cached --name-only --diff-filter=ACM '*.sh')" "$HOOK" &&
  ok "S1 gate matches the *.sh pathspec (nested scripts/ paths covered)" ||
  die "S1 gate pathspec drifted — leg and test must be re-synced"
grep -qF -- "--diff-filter=ACM -z '*.sh' | xargs -0" "$HOOK" &&
  ok "S2 run pipeline is NUL-delimited (-z + xargs -0)" ||
  die "S2 pipeline delimiter drifted"
grep -qF -- "--severity=warning" "$HOOK" &&
  ok "S3 bar is severity=warning" ||
  die "S3 severity drifted"
grep -qF -- "--diff-filter=ACM" "$HOOK" &&
  ok "S4 deletions excluded (no shellcheck on gone files)" ||
  die "S4 diff-filter drifted"
sed -n '/Running shellcheck on staged/,/^fi$/p' "$HOOK" | grep -qF "all_passed=false" &&
  ok "S5 failure branch blocks the commit (all_passed=false)" ||
  die "S5 leg no longer fail-closed"

echo "=== Dynamic proof (scratch repo, leg verbatim) ==="
SCRATCH=$(mktemp -d)
LEG_LOG="$SCRATCH/leg.log"
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init -q
git -C "$SCRATCH" config user.name fixture
git -C "$SCRATCH" config user.email fixture@example.com

leg() {
  # The hook's .sh leg, verbatim (gate + pipeline). The subshell mirrors the
  # hook's cwd: git runs pre-commit from the worktree root, and the staged
  # paths the pipeline feeds shellcheck are repo-relative.
  local staged
  staged=$(git -C "$SCRATCH" diff --cached --name-only --diff-filter=ACM '*.sh')
  if [ -n "$staged" ]; then
    if (
      cd "$SCRATCH" &&
        git diff --cached --name-only --diff-filter=ACM -z '*.sh' |
        xargs -0 "${SC_CMD[@]}" --severity=warning
    ) >"$LEG_LOG" 2>&1; then
      return 0
    fi
    return 1
  fi
  echo "No staged .sh files — skipping shellcheck." >"$LEG_LOG"
  return 0
}

mkdir -p "$SCRATCH/scripts"
cat >"$SCRATCH/scripts/clean.sh" <<'EOF'
#!/usr/bin/env bash
echo "leg fixture: clean script"
EOF
git -C "$SCRATCH" add scripts/clean.sh
git -C "$SCRATCH" commit -qm baseline

# D1: staged violation at a NESTED scripts/ path must fail the leg.
cat >"$SCRATCH/scripts/dirty.sh" <<'EOF'
#!/usr/bin/env bash
DIRTY_LEG_PROOF="unused on purpose"
echo "leg fixture: dirty script"
EOF
git -C "$SCRATCH" add scripts/dirty.sh
if leg; then
  die "D1 staged SC2034 violation passed the leg — coverage is broken"
else
  if grep -q "scripts/dirty.sh" "$LEG_LOG" && grep -q "SC2034" "$LEG_LOG"; then
    ok "D1 staged violation rejected: SC2034 reported for scripts/dirty.sh (nested path + detection)"
  else
    die "D1 leg failed without naming scripts/dirty.sh + SC2034 (log: $(head -c 200 "$LEG_LOG"))"
  fi
fi

# D2: clean staged modification passes.
git -C "$SCRATCH" restore --staged scripts/dirty.sh
rm -f "$SCRATCH/scripts/dirty.sh"
echo "# touched" >>"$SCRATCH/scripts/clean.sh"
git -C "$SCRATCH" add scripts/clean.sh
if leg; then
  ok "D2 clean staged modification passes"
else
  die "D2 clean modification failed the leg (log: $(head -c 200 "$LEG_LOG"))"
fi

# D3: a staged deletion alone skips the leg (empty ACM selection guard).
git -C "$SCRATCH" commit -qm touch
git -C "$SCRATCH" rm -q scripts/clean.sh
if leg; then
  if grep -q "No staged .sh files" "$LEG_LOG"; then
    ok "D3 staged deletion skips the leg (empty-selection guard, no stdin hang)"
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
echo "SELFTEST OK: the pre-commit shellcheck leg covers staged scripts/*.sh (detect + pass + skip)"
