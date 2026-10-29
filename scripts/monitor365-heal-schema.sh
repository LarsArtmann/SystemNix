#!/usr/bin/env bash
# monitor365-heal-schema — additive schema heal for the DuckDB the server
# reads. Runs as an ExecStartPre of monitor365-server.service, BEFORE the
# SSO identity heal (that heal's `create-admin` uses the same user-row
# read path this script repairs).
#
# WHY THIS EXISTS
# Upstream keeps its DuckDB DDL in `crates/db/src/schema.sql`, executed
# with `CREATE TABLE IF NOT EXISTS` on every start. That is a no-op on a
# table that already exists: any column added to schema.sql AFTER a given
# database file was created never reaches that file. The best-effort
# migration set (`crates/db/migrations/duckdb/`, embedded at build time via
# `crates/db/build.rs`) stops at 028 and contains no ALTER for the
# `version` columns, which exist only in schema.sql's CREATE TABLE bodies.
# A DB restored from a backup taken before those columns were introduced
# therefore stays permanently version-less.
#
# The failure is silent and vicious: `get_user_by_email` selects
# `COALESCE(users.version, 0) AS version`, DuckDB refuses to bind the
# statement ("Referenced column version not found"), and the callers map
# ANY error to "user not found" — SSO login dies with "Unauthorized: SSO
# user not found" while a `create-admin` insert still succeeds/fails on the
# unique index (so the row demonstrably exists). Live 2026-10-29: the SSO
# callback logged tenant t-cccf… + email lars@larsartmann.cloud and still
# reported the user missing, while `create-admin` hit "Duplicate key
# tenant_id… email… violates unique constraint" for the same pair.
#
# The fix is the migration upstream never wrote: `ADD COLUMN IF NOT EXISTS`
# for the two version columns, which is idempotent on every start and a
# no-op on current databases. Then the exact production query shape is
# re-bound (LIMIT 0) as the post-condition, so the journal states plainly
# whether SSO's read path works instead of leaving it to a failed login.
#
# FAIL-OPEN by construction (same reasoning as the identity heal): a heal
# that fails closed takes the whole control plane down to protect one read
# path. Nothing here exits non-zero once the database path is known.
#
# Usage: monitor365-heal-schema.sh <duckdb-file>
# Needs: duckdb on PATH.

set -uo pipefail

db="${1:-${MONITOR365_DATABASE_URL:-}}"
if [ -z "$db" ]; then
  echo "monitor365-heal-schema: ERROR: no database path given (argv[1] or MONITOR365_DATABASE_URL)" >&2
  exit 2
fi

# Overridable so the fixture can inject a failing binary; the unit relies
# on runtimeInputs putting `duckdb` on PATH.
duckdb_bin="${MONITOR365_DUCKDB:-duckdb}"

if [ ! -f "$db" ]; then
  echo "monitor365-heal-schema: database ${db} does not exist yet (fresh deploy) — server creates it" >&2
  exit 0
fi

# The exact projection crates/db/src/user/mod.rs selects. Keeping it in
# sync with upstream is the point: this is the statement whose binder
# failure surfaces as "SSO user not found".
USER_SELECT="SELECT id, tenant_id, email, name, role, status, created_at, last_login, COALESCE(users.version, 0) AS version FROM users LIMIT 0"

# No NOT NULL on the ALTER: DuckDB rejects constraints on added columns
# ("Parser Error: Adding columns with constraints not yet supported") —
# caught by this script's own fixture on the first run. Existing rows get
# the DEFAULT (0) and COALESCE covers anything NULL from older inserts.
if ! out="$($duckdb_bin "$db" -c "SET memory_limit='1GB'; SET threads=2; ALTER TABLE users ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 0; ALTER TABLE tenants ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 0;" 2>&1)"; then
  echo "monitor365-heal-schema: WARNING: add-column step failed; continuing so the control plane can start. SSO logins may keep failing. Output was: ${out}" >&2
fi

if probe="$($duckdb_bin "$db" -c "$USER_SELECT" 2>&1)"; then
  echo "monitor365-heal-schema: user-row projection binds (version columns present)"
  exit 0
fi

columns="$($duckdb_bin "$db" -csv -noheader -c "SELECT column_name FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position" 2>&1 || true)"
echo "monitor365-heal-schema: WARNING: the user-row projection STILL does not bind — SSO logins will report 'SSO user not found'. Schema drift is wider than the version columns; inspect the users table. Users columns: ${columns:-<unreadable>}. Probe output was: ${probe}" >&2
exit 0
