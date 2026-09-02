#!/usr/bin/env bash
# Fixture tests for the pre-deploy §10 metric-absence classifier
# (scripts/lib/metrics-gate.sh). The gate's WARN-vs-FAIL decision decides
# whether a deploy is BLOCKED — twice on 2026-09-02 the gate logic itself
# had no tests and blocked the deploy carrying its own fix (the
# node_textfile_scrape_error and forgejo scan-failure downgrade branches).
#
# Fixtures prove each branch classifies correctly:
#   A  TEXTFILE_SCRAPE_ERROR  → WARN (never block while infra is down)
#   B  FORGEJO_SCAN_FAILED    → WARN
#   B2 POCKET_ID_SCAN_FAILED  → WARN
#   D  KNOWN_NEW_METRICS      → WARN (absent until the switch lands)
#   C  present metric         → PASS
#   E  absent + no flags      → FAIL (the phantom-metric hard block — must
#                                never silently pass: no phantom green)
# Run: bash scripts/test-pre-deploy-metrics.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/metrics-gate.sh
source "$REPO_ROOT/scripts/lib/metrics-gate.sh"

PASS=0
FAIL=0
WARN=0
LAST_CLASS=""
pass() {
  LAST_CLASS="pass"
  PASS=$((PASS + 1))
}
warn() {
  LAST_CLASS="warn"
  WARN=$((WARN + 1))
}
fail() {
  LAST_CLASS="fail"
  FAIL=$((FAIL + 1))
}

METRICS_FILE=$(mktemp)
trap 'rm -f "$METRICS_FILE"' EXIT

# Default environment replicating a healthy pre-deploy run.
reset_env() {
  KNOWN_NEW_METRICS=""
  MONITOR365_METRICS="collector_events_collected cloud_sync_consecutive_failures"
  MONITOR365_UP=false
  DISCORDSYNC_METRICS="discordsync_turso_local_only_mode"
  DISCORDSYNC_API_UP=false
  FORGEJO_SCAN_FAILED=false
  POCKET_ID_SCAN_FAILED=false
  TEXTFILE_SCRAPE_ERROR=false
}

TEST_FAILURES=0
expect() {
  local want="$1"
  local desc="$2"
  if [ "$LAST_CLASS" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: $LAST_CLASS)"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}

echo "=== Fixture C: clean body — present metric passes, absent unknown metric hard-fails ==="
reset_env
cat >"$METRICS_FILE" <<'EOF'
# HELP system_zram_swap_fill_percent zram swap fill
# TYPE system_zram_swap_fill_percent gauge
system_zram_swap_fill_percent 97.5
node_textfile_scrape_error 0
EOF
metrics_gate_classify_absence "system_zram_swap_fill_percent"
expect "pass" "present metric (value line) → pass"
metrics_gate_classify_absence "node_textfile_scrape_error"
expect "pass" "present metric (no HELP match needed) → pass"
metrics_gate_classify_absence "system_totally_phantom_metric"
expect "fail" "absent metric on a CLEAN body → hard FAIL (phantom-metric block, no downgrade)"

echo "=== Fixture A: node_textfile_scrape_error=1 — absence is an infra signal, never a block ==="
reset_env
TEXTFILE_SCRAPE_ERROR=true
cat >"$METRICS_FILE" <<'EOF'
node_textfile_scrape_error 1
# HELP system_health_some_metric
EOF
metrics_gate_classify_absence "system_health_some_metric"
expect "warn" "absent metric while textfile collector broken → WARN (deploy the fix, don't block it)"

echo "=== Fixture B: forgejo mirror scan failed — fail-closed absence downgrades ==="
reset_env
FORGEJO_SCAN_FAILED=true
cat >"$METRICS_FILE" <<'EOF'
node_textfile_scrape_error 0
system_forgejo_mirror_scrape_errors 1
EOF
metrics_gate_classify_absence "system_forgejo_mirror_erroring"
expect "warn" "absent mirror pair while scan failed → WARN"

echo "=== Fixture B2: pocket-id SQLITE_BUSY scan failed — fail-closed absence downgrades ==="
reset_env
POCKET_ID_SCAN_FAILED=true
cat >"$METRICS_FILE" <<'EOF'
node_textfile_scrape_error 0
system_pocket_id_busy_scrape_errors 1
EOF
metrics_gate_classify_absence "system_pocket_id_busy_over_threshold"
expect "warn" "absent busy pair while scan failed → WARN"

echo "=== Fixture D: known-new metric absent pre-switch ==="
reset_env
KNOWN_NEW_METRICS="system_pocket_id_busy_scrape_errors system_pocket_id_busy_over_threshold"
cat >"$METRICS_FILE" <<'EOF'
node_textfile_scrape_error 0
EOF
metrics_gate_classify_absence "system_pocket_id_busy_scrape_errors"
expect "warn" "same-deploy metric absent from running scrape → WARN (appears post-switch)"

echo "=== Precedence: known-new wins over scan-failed downgrades (order matters) ==="
reset_env
KNOWN_NEW_METRICS="system_pocket_id_busy_over_threshold"
POCKET_ID_SCAN_FAILED=true
cat >"$METRICS_FILE" <<'EOF'
system_pocket_id_busy_scrape_errors 1
EOF
metrics_gate_classify_absence "system_pocket_id_busy_over_threshold"
expect "warn" "known-new classification still WARN under scan-failed (any warn is acceptable)"

if [ "$TEST_FAILURES" -gt 0 ]; then
  echo ""
  echo "SELFTEST FAILED: $TEST_FAILURES assertion(s) broken"
  exit 1
fi
echo ""
echo "SELFTEST OK: all §10 classifier branches behave (pass/warn/fail)"
