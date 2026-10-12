#!/usr/bin/env bash
# Fixture tests for the storage-history §14/§19 smoke blocks (the
# restic-storage-history deploy gates). The history tier ships ENABLED, so
# unlike offsite-borg these DO fire on every deploy — but each verdict
# branch (stale vs never-worked vs wiring-missing) only occurs for real at
# the worst moment without fixtures: the first 04:20 window, a detached
# pool, a config regression. The lib is SOURCED, not re-implemented: these
# fixtures run the same sh_pre_deploy / sh_post_deploy /
# sh_classify_eval_error code pre-deploy-check §14 and post-deploy-check
# §19 execute (the metrics-gate lesson — never trust a fixture that greps
# its own copy of the messages).
#
# Fixtures prove each verdict branch:
#   pre  P  full-green wiring                          → 9× PASS
#   pre  F  pruneOpts non-empty (retention regression)  → exactly that FAIL
#   pre  F  repo off the pool                           → exactly that FAIL
#   pre  F  paths[0] not the private/ real dir          → exactly that FAIL
#   pre  F  timer shape drifted                         → exactly that FAIL
#   pre  F  .last_success marker missing                → exactly that FAIL
#   pre  F  IO tier at nixpkgs' idle class              → exactly that FAIL
#   pre  F  MemoryMax absent                            → exactly that FAIL
#   pre  F  RequiresMountsFor missing                   → exactly that FAIL
#   pre  F  setup unit not the password bootstrap       → exactly that FAIL
#   cls D  real disabled-shape eval stderr              → "disabled"
#   cls A  unrelated eval error stderr                  → "anomaly"
#   cls A  empty stderr                                 → "anomaly"
#   post F  unit/timer files missing                    → 1 FAIL
#   post P  full-green unit+timer+stubctl+prom (fresh)  → 7× PASS
#   post F  marker / mount / IO / timer-shape mutations → exactly that FAIL
#   post F  timer not enabled (stubctl)                 → exactly that FAIL
#   post F  password bootstrap inactive (stubctl)       → exactly that FAIL
#   post W  ever_succeeded=0 (first window pending)     → 6 PASS + WARN
#   post F  ever=1 but healthy=0 (stale >25h)           → 6 PASS + FAIL
#   post W  prom row absent (tick pending)              → 6 PASS + WARN
#   post F  backups.prom missing                        → 6 PASS + FAIL
# Run: bash scripts/test-storage-history-smoke.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/storage-history-smoke.sh disable=SC1091
source "$REPO_ROOT/scripts/lib/storage-history-smoke.sh"

PASS=0
FAIL=0
WARN=0
EVENTS=()

sth_pass() {
  EVENTS+=("PASS")
  PASS=$((PASS + 1))
}
sth_fail() {
  EVENTS+=("FAIL")
  FAIL=$((FAIL + 1))
}
sth_warn() {
  EVENTS+=("WARN")
  WARN=$((WARN + 1))
}
# shellcheck disable=SC2034 # STH_* are read inside the sourced lib via indirection
STH_PASS=sth_pass STH_FAIL=sth_fail STH_WARN=sth_warn

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
}
classify_expect() {
  local want="$1" errfile="$2" desc="$3" got
  got=$(sh_classify_eval_error "$errfile")
  if [ "$got" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: $got)"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# --- JSON fixtures: the REAL shapes captured from the live eval
# (nix eval .#nixosConfigurations.evo-x2.config...) on 2026-10-12, keys the
# lib reads kept verbatim — casing drift is exactly what fixtures must catch.
GOOD_OPTS='{"pruneOpts":[],"repository":"/mnt/pool/backups/restic-storage-history","paths":["/var/lib/private/storage-collector"],"timerConfig":{"OnCalendar":"*-*-* 04:20:00","Persistent":true,"RandomizedDelaySec":"10m"}}'
GOOD_SVC='{"ExecStartPost":"/nix/store/xxx-coreutils/bin/touch /mnt/pool/backups/restic-storage-history/.last_success","IOSchedulingClass":"best-effort","IOSchedulingPriority":6,"MemoryMax":"1G"}'
GOOD_UNIT='{"RequiresMountsFor":["/mnt/pool"]}'
GOOD_SETUP='{"ExecStart":"/nix/store/xxx-restic-storage-history-password-setup/bin/restic-storage-history-password-setup","StateDirectory":"restic-storage-history"}'

ALL_PASS9="PASS PASS PASS PASS PASS PASS PASS PASS PASS"

echo "=== Pre-deploy §14 (sh_pre_deploy) ==="

reset
sh_pre_deploy "$GOOD_OPTS" "$GOOD_SVC" "$GOOD_UNIT" "$GOOD_SETUP"
expect "$ALL_PASS9" "fully-wired config → all nine PASS"

reset
sh_pre_deploy "$(jq -c '.pruneOpts = ["--keep-within 10y"]' <<<"$GOOD_OPTS")" "$GOOD_SVC" "$GOOD_UNIT" "$GOOD_SETUP"
expect "FAIL PASS PASS PASS PASS PASS PASS PASS PASS" "pruneOpts non-empty → retention regression FAILs first"

reset
sh_pre_deploy "$(jq -c '.repository = "/var/lib/restic-oops"' <<<"$GOOD_OPTS")" "$GOOD_SVC" "$GOOD_UNIT" "$GOOD_SETUP"
expect "PASS FAIL PASS PASS PASS PASS PASS PASS PASS" "repo off the pool → exactly that FAIL"

reset
sh_pre_deploy "$(jq -c '.paths[0] = "/var/lib/storage-collector"' <<<"$GOOD_OPTS")" "$GOOD_SVC" "$GOOD_UNIT" "$GOOD_SETUP"
expect "PASS PASS FAIL PASS PASS PASS PASS PASS PASS" "paths[0] not the private/ real dir → exactly that FAIL"

reset
sh_pre_deploy "$(jq -c '.timerConfig.OnCalendar = "*-*-* 05:15:00"' <<<"$GOOD_OPTS")" "$GOOD_SVC" "$GOOD_UNIT" "$GOOD_SETUP"
expect "PASS PASS PASS FAIL PASS PASS PASS PASS PASS" "timer shape drifted → exactly that FAIL"

reset
sh_pre_deploy "$GOOD_OPTS" "$(jq -c 'del(.ExecStartPost)' <<<"$GOOD_SVC")" "$GOOD_UNIT" "$GOOD_SETUP"
expect "PASS PASS PASS PASS FAIL PASS PASS PASS PASS" ".last_success marker missing → exactly that FAIL"

reset
sh_pre_deploy "$GOOD_OPTS" "$(jq -c '.IOSchedulingClass = "idle"' <<<"$GOOD_SVC")" "$GOOD_UNIT" "$GOOD_SETUP"
expect "PASS PASS PASS PASS PASS FAIL PASS PASS PASS" "IO tier at nixpkgs' idle class → exactly that FAIL"

reset
sh_pre_deploy "$GOOD_OPTS" "$(jq -c 'del(.MemoryMax)' <<<"$GOOD_SVC")" "$GOOD_UNIT" "$GOOD_SETUP"
expect "PASS PASS PASS PASS PASS PASS FAIL PASS PASS" "MemoryMax absent → exactly that FAIL"

reset
sh_pre_deploy "$GOOD_OPTS" "$GOOD_SVC" "$(jq -c '.RequiresMountsFor = []' <<<"$GOOD_UNIT")" "$GOOD_SETUP"
expect "PASS PASS PASS PASS PASS PASS PASS FAIL PASS" "RequiresMountsFor missing → exactly that FAIL"

reset
sh_pre_deploy "$GOOD_OPTS" "$GOOD_SVC" "$GOOD_UNIT" "$(jq -c '.ExecStart = "/nix/store/xxx-something-else/bin/other"' <<<"$GOOD_SETUP")"
expect "PASS PASS PASS PASS PASS PASS PASS PASS FAIL" "setup unit not the password bootstrap → exactly that FAIL"

echo "=== Eval-error classifier (sh_classify_eval_error) ==="

printf '%s\n' "error: flake 'git+file:///home/lars/projects/SystemNix' does not provide attribute 'packages.x86_64-linux.nixosConfigurations.evo-x2.config.systemd.services.restic-backups-storage-history.serviceConfig', 'legacyPackages.x86_64-linux.nixosConfigurations.evo-x2.config.systemd.services.restic-backups-storage-history.serviceConfig' or 'nixosConfigurations.evo-x2.config.systemd.services.restic-backups-storage-history.serviceConfig'" >"$SCRATCH/disabled.err"
classify_expect "disabled" "$SCRATCH/disabled.err" "real disabled-shape eval stderr → disabled"

printf '%s\n' "error: cannot build '...restic-storage-history...' because: 'bash-5.3' is not supported on 'x86_64-linux'" >"$SCRATCH/anomaly.err"
classify_expect "anomaly" "$SCRATCH/anomaly.err" "unrelated eval error → anomaly (FAIL LOUD at the caller)"

: >"$SCRATCH/empty.err"
classify_expect "anomaly" "$SCRATCH/empty.err" "empty stderr → anomaly"

echo "=== Post-deploy §19 (sh_post_deploy) ==="

# systemctl stub: answers the two live queries from env, fails anything else.
# Shebang is the ambient bash — a literal /usr/bin/env does not exist in the
# nix build sandbox (the selftest flake check runs there).
STUB_BASH="$(command -v bash)"
mkdir -p "$SCRATCH/bin"
cat >"$SCRATCH/bin/systemctl" <<STUB
#!$STUB_BASH
case "\$1 \$2" in
"is-enabled restic-backups-storage-history.timer") echo "\${FIX_TIMER_STATE:-enabled}"; exit 0 ;;
"is-active restic-storage-history-setup.service") echo "\${FIX_SETUP_STATE:-active}"; exit 0 ;;
esac
exit 1
STUB
chmod +x "$SCRATCH/bin/systemctl"
STH_SYSTEMCTL="$SCRATCH/bin/systemctl"
export STH_SYSTEMCTL

GOOD_UNIT_FILE="$SCRATCH/restic-backups-storage-history.service"
GOOD_TIMER_FILE="$SCRATCH/restic-backups-storage-history.timer"
cat >"$GOOD_UNIT_FILE" <<'UNIT'
[Unit]
RequiresMountsFor=/mnt/pool

[Service]
ExecStartPost=/nix/store/xxx-touch /mnt/pool/backups/restic-storage-history/.last_success
IOSchedulingClass=best-effort
IOSchedulingPriority=6
MemoryMax=1G
UNIT
cat >"$GOOD_TIMER_FILE" <<'TIMER'
[Timer]
OnCalendar=*-*-* 04:20:00
Persistent=true
RandomizedDelaySec=10m
TIMER

prom_write() {
  local path="$1" body="$2"
  printf '%s\n' "$body" >"$path"
}

PROM_FRESH='backup_healthy{backup="storage-history"} 1
backup_age_hours{backup="storage-history"} 5
backup_last_success_timestamp{backup="storage-history"} 1760000000
backup_ever_succeeded{backup="storage-history"} 1
backup_all_healthy 1'
PROM_NEVER='backup_healthy{backup="storage-history"} 0
backup_age_hours{backup="storage-history"} 999
backup_last_success_timestamp{backup="storage-history"} 0
backup_ever_succeeded{backup="storage-history"} 0
backup_all_healthy 0'
PROM_STALE='backup_healthy{backup="storage-history"} 0
backup_age_hours{backup="storage-history"} 40
backup_last_success_timestamp{backup="storage-history"} 1759900000
backup_ever_succeeded{backup="storage-history"} 1
backup_all_healthy 0'
PROM_NO_ROW='backup_healthy{backup="offsite-borg"} 0
backup_all_healthy 0'

ALL_PASS7="PASS PASS PASS PASS PASS PASS PASS"
FIRST_SIX="PASS PASS PASS PASS PASS PASS"

reset
sh_post_deploy "$SCRATCH/no-such.service" "$SCRATCH/no-such.timer" "$SCRATCH/backups.prom"
expect "FAIL" "deployed unit/timer missing → single FAIL (enabled+absent, not a skip)"

prom_write "$SCRATCH/backups.prom" "$PROM_FRESH"
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "$ALL_PASS7" "full-green deploy → all seven PASS"

reset
grep -v 'restic-storage-history/.last_success' "$GOOD_UNIT_FILE" >"$SCRATCH/mut-marker.service"
sh_post_deploy "$SCRATCH/mut-marker.service" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "FAIL $FIRST_SIX" "marker wiring missing → exactly that FAIL"

reset
grep -v '^RequiresMountsFor=' "$GOOD_UNIT_FILE" >"$SCRATCH/mut-mount.service"
sh_post_deploy "$SCRATCH/mut-mount.service" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "PASS FAIL PASS PASS PASS PASS PASS" "mount gate missing → exactly that FAIL"

reset
sed s/best-effort/idle/ "$GOOD_UNIT_FILE" >"$SCRATCH/mut-io.service"
sh_post_deploy "$SCRATCH/mut-io.service" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "PASS PASS FAIL PASS PASS PASS PASS" "IO tier wrong in deployed unit → exactly that FAIL"

reset
sed s/04:20:00/05:15:00/ "$GOOD_TIMER_FILE" >"$SCRATCH/mut.timer"
sh_post_deploy "$GOOD_UNIT_FILE" "$SCRATCH/mut.timer" "$SCRATCH/backups.prom"
expect "PASS PASS PASS FAIL PASS PASS PASS" "timer shape wrong in deployed .timer → exactly that FAIL"

prom_write "$SCRATCH/backups.prom" "$PROM_FRESH"
FIX_TIMER_STATE=disabled
export FIX_TIMER_STATE
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "PASS PASS PASS PASS FAIL PASS PASS" "timer not enabled → exactly that FAIL"
unset FIX_TIMER_STATE

FIX_SETUP_STATE=failed
export FIX_SETUP_STATE
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "PASS PASS PASS PASS PASS FAIL PASS" "password bootstrap inactive → exactly that FAIL"
unset FIX_SETUP_STATE

prom_write "$SCRATCH/backups.prom" "$PROM_NEVER"
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "$FIRST_SIX WARN" "first 04:20 window pending (ever=0) → WARN, not FAIL"

prom_write "$SCRATCH/backups.prom" "$PROM_STALE"
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "$FIRST_SIX FAIL" "backup stale (ever=1, healthy=0) → FAIL"

prom_write "$SCRATCH/backups.prom" "$PROM_NO_ROW"
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "$FIRST_SIX WARN" "prom row absent (tick pending) → WARN"

rm -f "$SCRATCH/backups.prom"
reset
sh_post_deploy "$GOOD_UNIT_FILE" "$GOOD_TIMER_FILE" "$SCRATCH/backups.prom"
expect "$FIRST_SIX FAIL" "backups.prom missing → FAIL (all backup freshness unmonitored)"

echo ""
if [ "$TEST_FAILURES" -eq 0 ]; then
  echo "ALL storage-history smoke fixtures green"
  exit 0
else
  echo "$TEST_FAILURES storage-history smoke fixture case(s) FAILED"
  exit 1
fi
