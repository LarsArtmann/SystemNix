#!/usr/bin/env bash
# Chronic-red SQL semantics regression fixture for the gatus meta collector
# (the GATUS_CHRONIC_RED query in modules/nixos/services/system-health.nix).
#
# WHY: the 2026-11-09 landing of `system_gatus_chronic_red_checks` fixture-
# verified its 3 states in an EPHEMERAL ~/.cache run against bare
# "YYYY-MM-DD HH:MM:SS" timestamps — never the format gatus actually writes.
# Source-verified 2026-11-23: gatus v5.38.0 opens modernc.org/sqlite with
# the config path verbatim (no `_time_format` DSN), so the driver's DEFAULT
# write path applies — `conn.formatTime` → `t.String()` — and gatus binds
# `result.Timestamp.UTC()`, i.e. every stored timestamp reads
# "2026-11-09 06:27:31.123456789 +0000 UTC". This script re-runs the 3-state
# fixture (chronic counted / resolution clears / silent-not-counted) in
# THAT format against a REAL sqlite db built from the v5.38.0 schema, so a
# gatus version bump that changes the written format, the schema, or the
# driver fails here instead of phantom-zeroing the metric with
# scrape_errors still 0 (the exact failure the collector cannot self-detect).
#
# The production SQL is EXTRACTED from the staged module copy (the same
# file the system builds from, never a hand-copied twin).
#
# MUTATIONS prove both window legs are load-bearing (flip the resolving
# success to a failure — the endpoint keeps REPORTING but loses its fresh
# success; make the silent endpoint report again), and boundary legs pin the
# 30-minute reporting window from both sides (29 min counts, 31 min does
# not) plus the 24-hour success window (23 h clears, 25 h does not).
#
# Static legs pin the query SHAPE (both datetime windows + the success
# literal) and — the version-bump tripwire — the time.Time.String() layout
# constant inside the deployed gatus binary: if a bump swaps the sqlite
# driver or its default write format, that string disappears and this
# fixture must be consciously re-verified against the new wire format.
#
# Usage: test-gatus-chronic-red-sql.sh <system-health.nix> <gatus-store-path>
set -uo pipefail

MODULE="${1:?usage: test-gatus-chronic-red-sql.sh <path/to/system-health.nix> <gatus-store-path>}"
GATUS_PKG="${2:?usage: test-gatus-chronic-red-sql.sh <path/to/system-health.nix> <gatus-store-path>}"

PASS_CNT=0
FAIL_CNT=0
ok() { PASS_CNT=$((PASS_CNT + 1)); }
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}
expect_count() { # expect_count <desc> <db> <expected>
  local got
  got="$(sqlite3 -readonly "$2" "$SQL" 2>/dev/null)"
  if [ "$got" = "$3" ]; then ok; else bad "$1: SQL returned /$got/, expected $3"; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Static legs: the query is extracted, shaped, and the wire format pinned
# shellcheck disable=SC2016 # the \$ in the grep pattern matches the literal $( in the module source
SQL="$(grep 'GATUS_CHRONIC_RED=\$(sqlite3' "$MODULE" | sed -n 's/^.*cfg\.gatus\.dbPath}" "\([^"]*\)".*$/\1/p' | head -1)"
if [ -n "$SQL" ]; then ok; else bad "could not extract GATUS_CHRONIC_RED SQL from $MODULE"; fi
for frag in "datetime('now', '-30 minutes')" "datetime('now', '-24 hours')" "success = 1" "r.timestamp >"; do
  if printf '%s' "$SQL" | grep -qF "$frag"; then ok; else bad "extracted SQL missing fragment: $frag"; fi
done
if grep -aqF '2006-01-02 15:04:05.999999999 -0700 MST' "$GATUS_PKG/bin/gatus"; then
  ok
else
  bad "gatus binary no longer carries the time.Time.String() layout — the sqlite driver or its default write format changed; re-verify the fixture timestamp format below"
fi

# ── Fixture db built from the gatus v5.38.0 sqlite schema (verbatim DDL,
#    storage/store/sql/specific_sqlite.go @ v5.38.0; suite_result_id's
#    suite_results FK left out — the CLI runs with foreign_keys off, as does
#    the -readonly production read path).
build_db() { # build_db <path>
  rm -f "$1"
  sqlite3 "$1" 'CREATE TABLE IF NOT EXISTS endpoints (endpoint_id INTEGER PRIMARY KEY, endpoint_key TEXT UNIQUE, endpoint_name TEXT NOT NULL, endpoint_group TEXT NOT NULL, UNIQUE(endpoint_name, endpoint_group));'
  sqlite3 "$1" 'CREATE TABLE IF NOT EXISTS endpoint_results (endpoint_result_id INTEGER PRIMARY KEY, endpoint_id INTEGER NOT NULL REFERENCES endpoints(endpoint_id) ON DELETE CASCADE, success INTEGER NOT NULL, errors TEXT NOT NULL, connected INTEGER NOT NULL, status INTEGER NOT NULL, dns_rcode TEXT NOT NULL, certificate_expiration INTEGER NOT NULL, domain_expiration INTEGER NOT NULL, hostname TEXT NOT NULL, ip TEXT NOT NULL, duration INTEGER NOT NULL, timestamp TIMESTAMP NOT NULL);'
}
add_endpoint() { # add_endpoint <db> <id> <key> <name>
  sqlite3 "$1" "INSERT INTO endpoints (endpoint_id, endpoint_key, endpoint_name, endpoint_group) VALUES ($2, '$3', '$4', 'Monitoring');"
}
res() { # res <db> <endpoint_id> <success> <age-spec> — one result in the REAL write format
  sqlite3 "$1" "INSERT INTO endpoint_results (endpoint_id, success, errors, connected, status, dns_rcode, certificate_expiration, domain_expiration, hostname, ip, duration, timestamp) VALUES ($2, $3, '', 0, 0, '', 0, 0, '', '', 0, datetime('now', '$4') || '.123456789 +0000 UTC');"
}

DB="$WORK/gatus-fixture.db"

# ── Phase 1: the 3-state fixture (the ephemeral run's contract) ──────────
build_db "$DB"
add_endpoint "$DB" 1 k1 chronic-check
add_endpoint "$DB" 2 k2 resolved-check
add_endpoint "$DB" 3 k3 silent-check
res "$DB" 1 0 '-5 minutes' # chronic: failing AND reporting now
res "$DB" 1 1 '-25 hours'  # chronic: last success OUTSIDE the 24h window
res "$DB" 2 1 '-5 minutes' # resolved: fresh success clears it
res "$DB" 2 0 '-2 hours'   # resolved: older failure is noise
res "$DB" 3 0 '-2 hours'   # silent: failing but NOT reporting (gatus was down) — NOT chronic
expect_count "3-state fixture counts ONLY the chronic endpoint" "$DB" 1

# ── Phase 2 mutations: both window legs must be load-bearing ─────────────
sqlite3 "$DB" "UPDATE endpoint_results SET success = 0 WHERE endpoint_id = 2 AND success = 1;"
expect_count "mutation: resolving success flips to failure (still reporting) → chronic" "$DB" 2
res "$DB" 2 1 '-5 minutes' # restore the resolution
res "$DB" 3 0 '-5 minutes' # the silent endpoint starts reporting (still failing)
expect_count "mutation: a silent endpoint that reports again (still failing) turns chronic" "$DB" 2

# ── Phase 3 boundaries: the two datetime windows from both sides ─────────
build_db "$DB"
add_endpoint "$DB" 1 k1 fresh31-check
add_endpoint "$DB" 2 k2 fresh29-check
add_endpoint "$DB" 3 k3 success23-check
res "$DB" 1 0 '-31 minutes' # 31 min since the last report → outside the 30-min window
res "$DB" 2 0 '-29 minutes' # 29 min → inside
res "$DB" 3 0 '-5 minutes'
res "$DB" 3 1 '-23 hours'   # success 23h ago → INSIDE the 24h window → clears
expect_count "boundaries: 31-min-silent excluded, 29-min counted, 23h-success clears (only fresh29)" "$DB" 1

echo "gatus-chronic-red-sql: $PASS_CNT passed, $FAIL_CNT failed"
[ "$FAIL_CNT" -eq 0 ]
