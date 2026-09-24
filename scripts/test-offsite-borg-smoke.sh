#!/usr/bin/env bash
# Fixture tests for the offsite-borg §13/§16 smoke blocks (the go-live deploy
# BLOCKS on these verdicts; services.offsite-borg ships disabled, so both
# blocks only fire for real on the go-live deploy itself — without fixtures
# the "fixture-tested" claim had no committed artifact and the wiring sat
# unexercised until go-live, the worst possible moment to find a typo).
#
# The lib is SOURCED, not re-implemented: these fixtures run the same
# ob_pre_deploy / ob_post_deploy code pre-deploy-check §13 and
# post-deploy-check §16 execute (the metrics-gate lesson — never trust a
# fixture that greps its own copy of the messages).
#
# Fixtures prove each verdict branch:
#   pre  S  disabled (empty serviceConfig JSON)      → SKIP
#   pre  P  tripwire + marker + env all wired        → 3× PASS
#   pre  F  tripwire missing from ExecStartPre       → FAIL
#   pre  F  .last_success marker missing             → FAIL
#   pre  F  borg-env EnvironmentFile missing         → FAIL
#   post S  unit file absent (enable = false)        → SKIP
#   post P  tripwire exec + marker + env + prom row  → 4× PASS
#   post F  tripwire pattern missing (wrong script)  → FAIL
#   post F  tripwire binary present but not -x       → FAIL
#   post F  marker wiring missing                    → FAIL
#   post F  EnvironmentFile missing                  → FAIL
#   post W  prom exists, no row yet (tick pending)   → WARN
#   post F  prom missing (backup-health-metrics)     → FAIL
# Run: bash scripts/test-offsite-borg-smoke.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/offsite-borg-smoke.sh disable=SC1091
source "$REPO_ROOT/scripts/lib/offsite-borg-smoke.sh"

PASS=0
FAIL=0
WARN=0
SKIP=0
EVENTS=()

ob_pass() { EVENTS+=("PASS"); PASS=$((PASS + 1)); }
ob_fail() { EVENTS+=("FAIL"); FAIL=$((FAIL + 1)); }
ob_warn() { EVENTS+=("WARN"); WARN=$((WARN + 1)); }
ob_skip() { EVENTS+=("SKIP"); SKIP=$((SKIP + 1)); }
OB_PASS=ob_pass OB_FAIL=ob_fail OB_WARN=ob_warn OB_SKIP=ob_skip

TEST_FAILURES=0
expect() {
  local want="$1" desc="$2"
  if [ "${EVENTS[*]}" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: ${EVENTS[*]:-none})"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}
reset() { EVENTS=(); PASS=0; FAIL=0; WARN=0; SKIP=0; }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

echo "=== Pre-deploy §13 (ob_pre_deploy) ==="

reset
ob_pre_deploy ""
expect "SKIP" "disabled config → skip (not a fail — enable-gated by design)"

reset
ob_pre_deploy '{"ExecStartPre":"/nix/store/xxx-borg-offsite-golive-check/bin/borg-offsite-golive-check","ExecStartPost":"/nix/store/xxx-touch /var/lib/borg-offsite/.last_success","EnvironmentFile":"/run/secrets/rendered/borg-env"}'
expect "PASS PASS PASS" "fully-wired serviceConfig → all three PASS"

reset
ob_pre_deploy '{"ExecStartPre":"/bin/false"}'
expect "FAIL FAIL FAIL" "empty wiring → all three FAIL (the gate that blocks a broken go-live)"

reset
ob_pre_deploy '{"ExecStartPre":"/bin/false","ExecStartPost":"/nix/store/xxx-touch /var/lib/borg-offsite/.last_success","EnvironmentFile":"/run/secrets/rendered/borg-env"}'
expect "FAIL PASS PASS" "tripwire missing → exactly that branch FAILs"

reset
ob_pre_deploy '{"ExecStartPre":"/nix/store/xxx-borg-offsite-golive-check/bin/borg-offsite-golive-check","ExecStartPost":"/bin/true","EnvironmentFile":"/run/secrets/rendered/borg-env"}'
expect "PASS FAIL PASS" "marker missing → exactly that branch FAILs"

reset
ob_pre_deploy '{"ExecStartPre":"/nix/store/xxx-borg-offsite-golive-check/bin/borg-offsite-golive-check","ExecStartPost":"/nix/store/xxx-touch /var/lib/borg-offsite/.last_success","EnvironmentFile":""}'
expect "PASS PASS FAIL" "env override missing → exactly that branch FAILs"

echo "=== Post-deploy §16 (ob_post_deploy) ==="

PROM="$SCRATCH/backups.prom"
UNIT="$SCRATCH/borgbackup-job-hetzner.service"
TRIPWIRE="$SCRATCH/borg-offsite-golive-check"

reset
ob_post_deploy "$SCRATCH/no-such-unit.service" "$PROM"
expect "SKIP" "unit absent → skip (dormant until go-live)"

# Happy path unit: executable tripwire, marker line, env line.
printf '#!/bin/sh\nexit 0\n' >"$TRIPWIRE"
chmod +x "$TRIPWIRE"
cat >"$UNIT" <<EOF
[Service]
ExecStartPre=$TRIPWIRE
ExecStartPost=/nix/store/xxx-touch /var/lib/borg-offsite/.last_success
EnvironmentFile=/run/secrets/rendered/borg-env
EOF
printf 'backup_ever_succeeded{backup="offsite-borg"} 1\n' >"$PROM"

reset
ob_post_deploy "$UNIT" "$PROM"
expect "PASS PASS PASS PASS" "fully-deployed wiring + prom row → 4× PASS"

reset
sed 's|ExecStartPre=.*|ExecStartPre=/bin/false|' "$UNIT" >"$SCRATCH/wrong-tripwire.service"
ob_post_deploy "$SCRATCH/wrong-tripwire.service" "$PROM"
expect "FAIL PASS PASS PASS" "wrong tripwire script → pattern branch FAILs"

reset
sed 's|ExecStartPre=.*|ExecStartPre='$SCRATCH'/not-executable|' "$UNIT" >"$SCRATCH/nonexec.service"
: >"$SCRATCH/not-executable"
ob_post_deploy "$SCRATCH/nonexec.service" "$PROM"
expect "FAIL PASS PASS PASS" "present-but-non-executable tripwire → FAIL"

reset
grep -v '^ExecStartPost=' "$UNIT" >"$SCRATCH/no-marker.service"
ob_post_deploy "$SCRATCH/no-marker.service" "$PROM"
expect "PASS FAIL PASS PASS" "marker line missing → that branch FAILs"

reset
grep -v '^EnvironmentFile=' "$UNIT" >"$SCRATCH/no-env.service"
ob_post_deploy "$SCRATCH/no-env.service" "$PROM"
expect "PASS PASS FAIL PASS" "env line missing → that branch FAILs"

reset
printf '# other backups only\nbackup_healthy{backup="cv"} 1\n' >"$PROM"
ob_post_deploy "$UNIT" "$PROM"
expect "PASS PASS PASS WARN" "prom present without the row → WARN (5-min tick pending)"

reset
ob_post_deploy "$UNIT" "$SCRATCH/no-such.prom"
expect "PASS PASS PASS FAIL" "prom missing → FAIL (backup-health-metrics unit failing)"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ offsite-borg smoke fixtures FAILED: $TEST_FAILURES assertion(s)"
  exit 1
fi
echo "✅ offsite-borg smoke fixtures passed (13 branches)"
