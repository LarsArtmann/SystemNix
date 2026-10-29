#!/usr/bin/env bash
# Fixture for scripts/monitor365-heal-schema.sh — executed via
# checks.monitor365-heal-schema-selftest so the ExecStartPre is never first
# exercised on boot. Builds throwaway DuckDB files with the LEGACY `users`
# shape (no version column) and asserts the heal both adds the column and
# makes the production projection bind again.
# MONITOR365_HEAL_SCHEMA_SCRIPT overrides the script under test.
set -uo pipefail

FAILURES=0
pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

SCRIPT="${MONITOR365_HEAL_SCHEMA_SCRIPT:-$(dirname "$0")/monitor365-heal-schema.sh}"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

USER_SELECT="SELECT id, tenant_id, email, name, role, status, created_at, last_login, COALESCE(users.version, 0) AS version FROM users LIMIT 0"

# Legacy shape: exactly what a pre-version-column DB looks like, plus one
# row so the read path can be proven to SELECT it after the heal.
make_legacy_db() {
  local db="$1"
  duckdb "$db" -c "
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      email TEXT NOT NULL,
      name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user',
      status TEXT NOT NULL DEFAULT 'invited',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_login TEXT,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(tenant_id, email)
    );
    CREATE TABLE tenants (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      api_key TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    INSERT INTO users (id, tenant_id, email, name, role, status)
      VALUES ('u-1', 't-1', 'lars@example.test', 'Admin', 'super_admin', 'active');
    INSERT INTO tenants (id, name, api_key) VALUES ('t-1', 'Lars', 'k');
  " >/dev/null 2>&1 || fail "fixture could not be created at $db"
}

# ── Leg 0: the legacy fixture reproduces the live failure ──
DB="$SCRATCH/legacy.duckdb"
make_legacy_db "$DB"
if duckdb "$DB" -c "$USER_SELECT" >/dev/null 2>&1; then
  fail "leg0 legacy fixture unexpectedly binds the projection (fixture is not legacy)"
else
  pass "leg0 legacy fixture reproduces the binder failure"
fi

# ── Leg 1: heal repairs it, exit 0, post-condition green ──
rc=0
OUT=$(bash "$SCRIPT" "$DB" 2>&1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg1 exit 0" || fail "leg1 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "user-row projection binds" &&
  pass "leg1 reports binding projection" || fail "leg1 wrong output: ${OUT}"
if duckdb "$DB" -c "$USER_SELECT" >/dev/null 2>&1; then
  pass "leg1 projection binds after heal"
else
  fail "leg1 projection still broken after heal"
fi

# ── Leg 2: the existing row is still readable (no data loss) ──
ROWS=$(duckdb "$DB" -csv -noheader -c "SELECT count(*) FROM users WHERE email = 'lars@example.test'" 2>/dev/null | tr -d '[:space:]')
case "$ROWS" in
1) pass "leg2 row preserved" ;;
*) fail "leg2 row count '${ROWS}' after heal" ;;
esac

# ── Leg 3: idempotent second run (every start re-runs this) ──
rc=0
OUT=$(bash "$SCRIPT" "$DB" 2>&1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg3 second run exit 0" || fail "leg3 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "user-row projection binds" &&
  pass "leg3 second run binds" || fail "leg3 second run: ${OUT}"

# ── Leg 4: missing database is a WARN, not a failure (fresh deploy) ──
rc=0
OUT=$(bash "$SCRIPT" "$SCRATCH/absent.duckdb" 2>&1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg4 exit 0 on absent DB" || fail "leg4 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "does not exist yet" &&
  pass "leg4 warns on absent DB" || fail "leg4 wrong output: ${OUT}"

# ── Leg 5: missing path argument is a real error ──
rc=0
OUT=$(MONITOR365_DATABASE_URL="" bash "$SCRIPT" 2>&1) || rc=$?
[ "$rc" -eq 2 ] && pass "leg5 exit 2 without a path" || fail "leg5 exit ${rc}: ${OUT}"

# ── Leg 6: a failing duckdb is fail-OPEN (never gates the unit) ──
STUB_DIR="$SCRATCH/stub"
mkdir -p "$STUB_DIR"
cat >"$STUB_DIR/duckdb" <<STUB
#!${BASH}
echo "Error: Conflicting lock is held"
exit 1
STUB
chmod +x "$STUB_DIR/duckdb"
rc=0
OUT=$(MONITOR365_DUCKDB="$STUB_DIR/duckdb" bash "$SCRIPT" "$DB" 2>&1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg6 fail-open exit 0" || fail "leg6 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "WARNING" &&
  pass "leg6 warns loudly" || fail "leg6 missing warning: ${OUT}"

if [ "$FAILURES" -eq 0 ]; then
  echo "monitor365-heal-schema fixture: ALL LEGS GREEN"
  exit 0
fi
echo "monitor365-heal-schema fixture: $FAILURES FAILURE(S)"
exit 1
