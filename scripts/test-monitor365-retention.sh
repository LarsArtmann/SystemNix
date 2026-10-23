#!/usr/bin/env bash
# Fixture for scripts/monitor365-retention.sh — executed via
# checks.monitor365-retention-selftest so the 03:00 window is never the
# script's first run. Needs duckdb + coreutils on PATH.
# MONITOR365_RETENTION_SCRIPT overrides the script under test: the
# rendered-fixture check points it at the store writeShellApplication
# output the 03:00 call site actually invokes.
set -uo pipefail

FAILURES=0
pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

SCRIPT="${MONITOR365_RETENTION_SCRIPT:-$(dirname "$0")/monitor365-retention.sh}"

make_db() {
  # $1 = db path, $2 = timestamp column type
  duckdb "$1" <<SQL
CREATE TABLE events (id VARCHAR, event_type VARCHAR, timestamp $2, tenant_id VARCHAR, payload VARCHAR);
INSERT INTO events VALUES
  ('1','old','2026-05-01 10:00:00','x','p'),
  ('2','old2','2026-06-15 12:00:00','x','p'),
  ('3','recent','2026-10-20 09:00:00','x','p');
SQL
}

run_retention() {
  # $1 = state dir; remaining args = env overrides
  local dir=$1
  shift
  env STATE_DIR="$dir" "$@" bash "$SCRIPT" 2>&1
}

# ── Leg 1: fresh run deletes old rows, vacuums, writes the stamp ──
D1=$(mktemp -d)
make_db "$D1/monitor365.duckdb" TIMESTAMP
OUT=$(run_retention "$D1")
echo "$OUT" | grep -q "deleted events older than" &&
  pass "leg1 delete line" || fail "leg1 delete line missing: $OUT"
echo "$OUT" | grep -q "boundary count: 2" &&
  pass "leg1 boundary count" || fail "leg1 boundary count wrong: $OUT"
echo "$OUT" | grep -q "rows remaining: 1" &&
  pass "leg1 rows remaining" || fail "leg1 rows remaining wrong: $OUT"
echo "$OUT" | grep -q "VACUUM done" &&
  pass "leg1 vacuum ran" || fail "leg1 vacuum missing: $OUT"
[ -f "$D1/.retention-vacuum-stamp" ] &&
  pass "leg1 stamp written" || fail "leg1 stamp missing"
ROWS=$(duckdb "$D1/monitor365.duckdb" -noheader -list -c "SELECT COUNT(*) FROM events WHERE id IN ('1','2');" 2>/dev/null)
[ "$ROWS" = "0" ] && pass "leg1 old rows gone" || fail "leg1 old rows still present: $ROWS"

# ── Leg 2: fresh stamp suppresses the VACUUM leg ──
date +%s >"$D1/.retention-vacuum-stamp"
OUT=$(run_retention "$D1")
echo "$OUT" | grep -q "VACUUM done" &&
  fail "leg2 vacuum ran despite fresh stamp: $OUT" || pass "leg2 vacuum suppressed"

# ── Leg 3: missing/empty DB is a clean no-op ──
D3=$(mktemp -d)
OUT=$(run_retention "$D3")
echo "$OUT" | grep -q "nothing to do" &&
  pass "leg3 no-op on empty" || fail "leg3 expected no-op: $OUT"

# ── Leg 4: VARCHAR timestamps + malformed rows survive try_cast ──
D4=$(mktemp -d)
make_db "$D4/monitor365.duckdb" VARCHAR
duckdb "$D4/monitor365.duckdb" -c "INSERT INTO events VALUES ('4','malformed','not-a-date','x','p');" >/dev/null
OUT=$(run_retention "$D4")
echo "$OUT" | grep -q "rows remaining: 2" &&
  pass "leg4 varchar delete + malformed kept" || fail "leg4 rows wrong: $OUT"

# ── Leg 5: RETENTION_DAYS env override widens the window to keep old rows ──
D5=$(mktemp -d)
make_db "$D5/monitor365.duckdb" TIMESTAMP
OUT=$(run_retention "$D5" RETENTION_DAYS=600)
echo "$OUT" | grep -q "rows remaining: 3" &&
  pass "leg5 window override keeps all" || fail "leg5 rows wrong: $OUT"

# ── Leg 6: impossible headroom skips the VACUUM and writes no stamp ──
D6=$(mktemp -d)
make_db "$D6/monitor365.duckdb" TIMESTAMP
OUT=$(run_retention "$D6" VACUUM_HEADROOM_B=99999999999999)
echo "$OUT" | grep -q "VACUUM skipped, headroom" &&
  pass "leg6 headroom skip" || fail "leg6 expected skip: $OUT"
[ ! -f "$D6/.retention-vacuum-stamp" ] &&
  pass "leg6 no stamp on skip" || fail "leg6 stamp written on skip"

if [ "$FAILURES" -eq 0 ]; then
  echo "monitor365-retention fixture: ALL LEGS GREEN"
  exit 0
fi
echo "monitor365-retention fixture: $FAILURES FAILURE(S)"
exit 1
