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
#   pre  P  tripwire + marker + env + IO + type + key → 6× PASS
#   pre  F  empty wiring                             → 6× FAIL
#   pre  F  tripwire missing from ExecStartPre       → FAIL
#   pre  F  key pre-flight missing from ExecStartPre → FAIL
#   pre  F  .last_success marker missing             → FAIL
#   pre  F  borg-env EnvironmentFile missing         → FAIL
#   pre  F  IO tier not best-effort/6                → FAIL
#   pre  F  Type absent (nixpkgs' implicit simple)   → FAIL
#   cls D  real disabled-shape eval stderr          → "disabled"
#   cls A  nix daemon gone stderr                   → "anomaly"
#   cls A  real config eval stderr                  → "anomaly"
#   cls A  empty stderr                             → "anomaly"
#   post S  unit file absent (enable = false)        → SKIP
#   post P  tripwire + marker + env + IO + type + key + prom → 7× PASS
#   post F  tripwire pattern missing (wrong script)  → FAIL
#   post F  tripwire binary present but not -x       → FAIL
#   post F  key pre-flight line missing              → FAIL
#   post F  key pre-flight present but not -x        → FAIL
#   post F  marker wiring missing                    → FAIL
#   post F  EnvironmentFile missing                  → FAIL
#   post F  IO tier not best-effort/6 in unit        → FAIL
#   post F  Type=simple in the unit                  → FAIL
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

ob_pass() {
  EVENTS+=("PASS")
  PASS=$((PASS + 1))
}
ob_fail() {
  EVENTS+=("FAIL")
  FAIL=$((FAIL + 1))
}
ob_warn() {
  EVENTS+=("WARN")
  WARN=$((WARN + 1))
}
ob_skip() {
  EVENTS+=("SKIP")
  SKIP=$((SKIP + 1))
}
# shellcheck disable=SC2034 # OB_* are read inside the sourced lib via indirection
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
reset() {
  EVENTS=()
  PASS=0
  FAIL=0
  WARN=0
  SKIP=0
}
classify_expect() {
  local want="$1" errfile="$2" desc="$3" got
  got=$(ob_classify_eval_error "$errfile")
  if [ "$got" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: $got)"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

echo "=== Pre-deploy §13 (ob_pre_deploy) ==="

# The fully-wired shape: both pre-flights ride ExecStartPre as a list, as the
# evo-x2 render emits it. Each later fixture drops exactly one leg.
PRE_TYPE='"Type":"oneshot"'
PRE_BOTH='"ExecStartPre":["/nix/store/xxx-borg-offsite-golive-check","/nix/store/xxx-borg-offsite-key-check"]'
PRE_MARK='"ExecStartPost":"/nix/store/xxx-touch /var/lib/borg-offsite/.last_success"'
PRE_ENV='"EnvironmentFile":"/run/secrets/rendered/borg-env"'
PRE_IO='"IOSchedulingClass":"best-effort","IOSchedulingPriority":6'

reset
ob_pre_deploy ""
expect "SKIP" "disabled config → skip (not a fail — enable-gated by design)"

reset
ob_pre_deploy "{$PRE_TYPE,$PRE_BOTH,$PRE_MARK,$PRE_ENV,$PRE_IO}"
expect "PASS PASS PASS PASS PASS PASS" "fully-wired serviceConfig → all six PASS"

reset
ob_pre_deploy '{"ExecStartPre":"/bin/false"}'
expect "FAIL FAIL FAIL FAIL FAIL FAIL" "empty wiring → all six FAIL (the gate that blocks a broken go-live)"

reset
ob_pre_deploy "{$PRE_TYPE,\"ExecStartPre\":[\"/nix/store/xxx-borg-offsite-key-check\"],$PRE_MARK,$PRE_ENV,$PRE_IO}"
expect "FAIL PASS PASS PASS PASS PASS" "tripwire missing (key pre-flight kept) → exactly that branch FAILs"

reset
ob_pre_deploy "{$PRE_TYPE,\"ExecStartPre\":[\"/nix/store/xxx-borg-offsite-golive-check\"],$PRE_MARK,$PRE_ENV,$PRE_IO}"
expect "PASS PASS PASS PASS PASS FAIL" "key pre-flight missing (tripwire kept) → exactly that branch FAILs"

reset
ob_pre_deploy "{$PRE_TYPE,$PRE_BOTH,\"ExecStartPost\":\"/bin/true\",$PRE_ENV,$PRE_IO}"
expect "PASS FAIL PASS PASS PASS PASS" "marker missing → exactly that branch FAILs"

reset
ob_pre_deploy "{$PRE_TYPE,$PRE_BOTH,$PRE_MARK,\"EnvironmentFile\":\"\",$PRE_IO}"
expect "PASS PASS FAIL PASS PASS PASS" "env override missing → exactly that branch FAILs"

reset
ob_pre_deploy "{$PRE_TYPE,$PRE_BOTH,$PRE_MARK,$PRE_ENV}"
expect "PASS PASS PASS FAIL PASS PASS" "IO tier absent (nixpkgs idle default, mkForce dropped) → that branch FAILs"

reset
ob_pre_deploy "{$PRE_TYPE,$PRE_BOTH,$PRE_MARK,$PRE_ENV,\"IOSchedulingClass\":\"idle\",\"IOSchedulingPriority\":6}"
expect "PASS PASS PASS FAIL PASS PASS" "IO tier at nixpkgs' idle class → that branch FAILs"

reset
ob_pre_deploy "{$PRE_BOTH,$PRE_MARK,$PRE_ENV,$PRE_IO}"
expect "PASS PASS PASS PASS FAIL PASS" "Type absent (nixpkgs' implicit simple — the 2026-11-25 live shape) → that branch FAILs"

reset
ob_pre_deploy "{\"Type\":\"simple\",$PRE_BOTH,$PRE_MARK,$PRE_ENV,$PRE_IO}"
expect "PASS PASS PASS PASS FAIL PASS" "Type=simple → that branch FAILs"

echo "=== Eval-error classifier (ob_classify_eval_error) ==="

# Real stderr shapes: the disabled case captured live (mkIf cfg.enable hides
# the job from systemd.services, so nix reports the flake as not providing
# the attribute), plus the transient/real-error classes that the old
# `|| echo ""` silent-skip treated as "disabled".
cat >"$SCRATCH/err-disabled.txt" <<'EOF'
error: flake 'git+file:///home/lars/projects/SystemNix' does not provide attribute 'packages.x86_64-linux.nixosConfigurations.evo-x2.config.systemd.services.borgbackup-job-hetzner.serviceConfig', 'legacyPackages.x86_64-linux.nixosConfigurations.evo-x2.config.systemd.services.borgbackup-job-hetzner.serviceConfig' or 'nixosConfigurations.evo-x2.config.systemd.services.borgbackup-job-hetzner.serviceConfig'
EOF
cat >"$SCRATCH/err-daemon.txt" <<'EOF'
error: Nix daemon disconnected unexpectedly (maybe it crashed?)
EOF
cat >"$SCRATCH/err-config.txt" <<'EOF'
error: sops key 'borg_password' declared in sopsFiles but missing from encrypted file 'platforms/nixos/secrets/borg.yaml'
EOF
cat >"$SCRATCH/err-other-attr.txt" <<'EOF'
error: flake 'git+file:///home/lars/projects/SystemNix' does not provide attribute 'packages.x86_64-linux.nixosConfigurations.evo-x2.config.systemd.services.bank-sync.serviceConfig', 'legacyPackages.x86_64-linux.nixosConfigurations.evo-x2.config.systemd.services.bank-sync.serviceConfig' or 'nixosConfigurations.evo-x2.config.systemd.services.bank-sync.serviceConfig'
EOF
: >"$SCRATCH/err-empty.txt"

classify_expect disabled "$SCRATCH/err-disabled.txt" "borgbackup-job attribute-missing = the legit disabled shape"
classify_expect anomaly "$SCRATCH/err-daemon.txt" "nix daemon disconnected = transient, must fail loud"
classify_expect anomaly "$SCRATCH/err-config.txt" "real config eval error = must fail loud"
classify_expect anomaly "$SCRATCH/err-other-attr.txt" "attribute-missing for a DIFFERENT unit = must fail loud (discriminator is path-specific)"
classify_expect anomaly "$SCRATCH/err-empty.txt" "eval failed with no message = must fail loud"

echo "=== Post-deploy §16 (ob_post_deploy) ==="

PROM="$SCRATCH/backups.prom"
UNIT="$SCRATCH/borgbackup-job-hetzner.service"
TRIPWIRE="$SCRATCH/borg-offsite-golive-check"
KEYCHECK="$SCRATCH/borg-offsite-key-check"
ALL_PASS="PASS PASS PASS PASS PASS PASS"

reset
ob_post_deploy "$SCRATCH/no-such-unit.service" "$PROM"
expect "SKIP" "unit absent → skip (dormant until go-live)"

# Happy path unit: executable tripwire and key pre-flight, oneshot type,
# marker line, env line.
printf '#!/bin/sh\nexit 0\n' >"$TRIPWIRE"
printf '#!/bin/sh\nexit 0\n' >"$KEYCHECK"
chmod +x "$TRIPWIRE" "$KEYCHECK"
cat >"$UNIT" <<EOF
[Service]
Type=oneshot
ExecStartPre=$TRIPWIRE
ExecStartPre=$KEYCHECK
ExecStartPost=/nix/store/xxx-touch /var/lib/borg-offsite/.last_success
EnvironmentFile=/run/secrets/rendered/borg-env
IOSchedulingClass=best-effort
IOSchedulingPriority=6
EOF
printf 'backup_ever_succeeded{backup="offsite-borg"} 1\n' >"$PROM"

reset
ob_post_deploy "$UNIT" "$PROM"
expect "$ALL_PASS PASS" "fully-deployed wiring + prom row → 7× PASS"

reset
sed "s#^ExecStartPre=$TRIPWIRE\$#ExecStartPre=/bin/false#" "$UNIT" >"$SCRATCH/wrong-tripwire.service"
ob_post_deploy "$SCRATCH/wrong-tripwire.service" "$PROM"
expect "FAIL PASS PASS PASS PASS PASS PASS" "wrong tripwire script (key pre-flight kept) → pattern branch FAILs"

reset
mkdir -p "$SCRATCH/nonexec"
: >"$SCRATCH/nonexec/borg-offsite-golive-check"
sed "s#^ExecStartPre=$TRIPWIRE\$#ExecStartPre=$SCRATCH/nonexec/borg-offsite-golive-check#" "$UNIT" >"$SCRATCH/nonexec.service"
ob_post_deploy "$SCRATCH/nonexec.service" "$PROM"
expect "FAIL PASS PASS PASS PASS PASS PASS" "present-but-non-executable tripwire → FAIL"

reset
grep -v "^ExecStartPre=$KEYCHECK\$" "$UNIT" >"$SCRATCH/no-keycheck.service"
ob_post_deploy "$SCRATCH/no-keycheck.service" "$PROM"
expect "PASS PASS PASS PASS PASS FAIL PASS" "key pre-flight line missing → that branch FAILs"

reset
: >"$SCRATCH/nonexec/borg-offsite-key-check"
sed "s#^ExecStartPre=$KEYCHECK\$#ExecStartPre=$SCRATCH/nonexec/borg-offsite-key-check#" "$UNIT" >"$SCRATCH/nonexec-key.service"
ob_post_deploy "$SCRATCH/nonexec-key.service" "$PROM"
expect "PASS PASS PASS PASS PASS FAIL PASS" "present-but-non-executable key pre-flight → FAIL"

reset
grep -v '^ExecStartPost=' "$UNIT" >"$SCRATCH/no-marker.service"
ob_post_deploy "$SCRATCH/no-marker.service" "$PROM"
expect "PASS FAIL PASS PASS PASS PASS PASS" "marker line missing → that branch FAILs"

reset
grep -v '^EnvironmentFile=' "$UNIT" >"$SCRATCH/no-env.service"
ob_post_deploy "$SCRATCH/no-env.service" "$PROM"
expect "PASS PASS FAIL PASS PASS PASS PASS" "env line missing → that branch FAILs"

reset
grep -v '^IOScheduling' "$UNIT" >"$SCRATCH/no-io.service"
ob_post_deploy "$SCRATCH/no-io.service" "$PROM"
expect "PASS PASS PASS FAIL PASS PASS PASS" "IO tier lines missing (mkForce dropped / unit drifted) → that branch FAILs"

reset
sed 's/^Type=oneshot$/Type=simple/' "$UNIT" >"$SCRATCH/simple.service"
ob_post_deploy "$SCRATCH/simple.service" "$PROM"
expect "PASS PASS PASS PASS FAIL PASS PASS" "Type=simple in the deployed unit → that branch FAILs (the 2026-11-25 live shape)"

reset
printf '# other backups only\nbackup_healthy{backup="cv"} 1\n' >"$PROM"
reset
ob_post_deploy "$UNIT" "$PROM"
expect "$ALL_PASS WARN" "prom present without the row → WARN (5-min tick pending)"

reset
ob_post_deploy "$UNIT" "$SCRATCH/no-such.prom"
expect "$ALL_PASS FAIL" "prom missing → FAIL (backup-health-metrics unit failing)"

echo ""
if [ "$TEST_FAILURES" -gt 0 ]; then
  echo "❌ offsite-borg smoke fixtures FAILED: $TEST_FAILURES assertion(s)"
  exit 1
fi
echo "✅ offsite-borg smoke fixtures passed (26 fixtures)"
