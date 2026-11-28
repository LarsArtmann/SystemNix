#!/usr/bin/env bash
# signoz-retention — converge SigNoz telemetry retention (metrics, traces,
# logs) to the days declared by services.signoz.retentionDays.
#
# Retention lives in ClickHouse table TTLs, but the supported way to move it
# is SigNoz's own settings API, never a raw ALTER on the primary tables: the
# query service records every change in its ttl_setting table (signoz.db) and
# the UI, the GET endpoint and the EE meter collector read THAT, so a raw
# ALTER leaves SigNoz believing the old value.
#
#   metrics / traces : POST /api/v1/settings/ttl?type=<signal>&duration=<N>h
#                      (async: goroutines ALTER a fixed table list)
#   logs             : POST /api/v2/settings/ttl — v1 refuses logs once the
#                      table carries the _retention_days column. v2 moves the
#                      COLUMN DEFAULT; rows already stored keep their day count
#                      (it is part of the partition key, so it cannot be
#                      rewritten) and age out on their original schedule.
#
# The API's table list predates several tables the query service reads over
# the same time ranges (reduced metric rollups, the metric attribute catalog,
# trace and log filter suggestions, the service-to-operation map). Those keep
# the migrator default when the API runs, so a query 30..90 days back would
# see raw series but not their rollups, or traces but not their operation
# names. This script moves their TTL interval too, keeping each time
# expression as the migrator wrote it.
#
# Every ALTER goes out with materialize_ttl_after_modify=0 (SigNoz's form):
# parts written under the old TTL keep their old TTL info and age out on the
# old schedule (probe 2026-11-28, docs/agents/monitoring.md "retention"), so
# retention RAMPS to the new value instead of rewriting the store.
#
# Fail-closed: the run ends with an independent read of every table's TTL
# (ClickHouse system tables, not the API) and exits non-zero naming each
# mismatch. An absent table is skipped: a future schema may drop it.
#
# Env (required, rendered by signoz.nix):
#   SIGNOZ_URL             query service base URL
#   DB_METRICS DB_TRACES DB_LOGS   ClickHouse database names
#   RETENTION_DAYS_METRICS RETENTION_DAYS_TRACES RETENTION_DAYS_LOGS
# Optional: SIGNOZ_RETENTION_POLL_SECONDS (API poll interval, default 2)
# Needs: curl, jq, clickhouse-client on PATH (writeShellApplication
# runtimeInputs in production; the fixture provides stubs).
#
# Fixture: scripts/test-signoz-retention.sh via checks.signoz-retention-selftest.
set -euo pipefail

SIGNOZ_URL=${SIGNOZ_URL:?SIGNOZ_URL is required}
DB_METRICS=${DB_METRICS:?DB_METRICS is required}
DB_TRACES=${DB_TRACES:?DB_TRACES is required}
DB_LOGS=${DB_LOGS:?DB_LOGS is required}
DAYS_METRICS=${RETENTION_DAYS_METRICS:?RETENTION_DAYS_METRICS is required}
DAYS_TRACES=${RETENTION_DAYS_TRACES:?RETENTION_DAYS_TRACES is required}
DAYS_LOGS=${RETENTION_DAYS_LOGS:?RETENTION_DAYS_LOGS is required}
POLL_SECONDS=${SIGNOZ_RETENTION_POLL_SECONDS:-2}

for days in "$DAYS_METRICS" "$DAYS_TRACES" "$DAYS_LOGS"; do
  if ! [[ "$days" =~ ^[1-9][0-9]*$ ]]; then
    echo "signoz-retention: FAIL: retention days must be a positive integer, got '$days'" >&2
    exit 1
  fi
done
if ! [[ "$POLL_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "signoz-retention: FAIL: SIGNOZ_RETENTION_POLL_SECONDS must be an integer, got '$POLL_SECONDS'" >&2
  exit 1
fi

RESP=$(mktemp)
trap 'rm -f "$RESP"' EXIT

die() {
  echo "signoz-retention: FAIL: $*" >&2
  exit 1
}

# ── SigNoz query-service API ─────────────────────────────────────────────
HTTP_STATUS=000

http() {
  # http METHOD PATH [JSON_BODY] → status in HTTP_STATUS, body in $RESP
  local method=$1 path=$2 body=${3:-}
  local args=(--silent --show-error --max-time 60 -o "$RESP" -w '%{http_code}' -X "$method")
  if [ -n "$body" ]; then
    args+=(--header 'Content-Type: application/json' --data "$body")
  fi
  HTTP_STATUS=$(curl "${args[@]}" "$SIGNOZ_URL$path") || HTTP_STATUS=000
}

http_ok() { [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; }

body_head() { head -c 300 "$RESP" | tr '\n' ' '; }

# converge_v1 SIGNAL DAYS FORCE(0|1) — metrics and traces through SigNoz's
# settings/ttl API. FORCE re-issues the POST even when the API already
# reports the target: the API ALTERs several tables asynchronously, so a
# half-applied change needs a second full pass.
converge_v1() {
  local signal=$1 days=$2 force=$3
  local want_h=$((days * 24)) have_h=""
  local field="${signal}_ttl_duration_hrs"
  local path="/api/v1/settings/ttl?type=$signal"
  local deadline
  if [ "$force" -ne 1 ]; then
    http GET "$path"
    http_ok || die "$signal: GET $path failed (HTTP $HTTP_STATUS): $(body_head)"
    have_h=$(jq -r --arg f "$field" '.[$f] // empty' "$RESP") ||
      die "$signal: unreadable JSON from $path: $(body_head)"
    if [ "$have_h" = "$want_h" ]; then
      echo "signoz-retention: $signal: SigNoz already reports $days days"
      return 0
    fi
    echo "signoz-retention: $signal: SigNoz reports '${have_h:-?}' h, want $want_h h — POST settings/ttl"
  else
    echo "signoz-retention: $signal: re-issuing settings/ttl for $days days (repair)"
  fi
  # HTTP 409 = "TTL is already running": a ttl_setting row is still pending.
  http POST "$path&duration=${want_h}h"
  http_ok || die "$signal: POST $path failed (HTTP $HTTP_STATUS): $(body_head)"
  deadline=$((SECONDS + 120))
  while :; do
    sleep "$POLL_SECONDS"
    http GET "$path"
    if http_ok; then
      have_h=$(jq -r --arg f "$field" '.[$f] // empty' "$RESP") || have_h=""
      if [ "$have_h" = "$want_h" ]; then
        echo "signoz-retention: $signal: $days days applied"
        return 0
      fi
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      break
    fi
  done
  die "$signal: SigNoz still reports '${have_h:-?}' h 120s after POST settings/ttl"
}

# converge_logs DAYS FORCE(0|1) — logs through the v2 API: moves the
# _retention_days column default on logs_v2, its resource table and both
# distributed copies, and the TTL of the attribute and resource key tables.
# Synchronous: the ALTERs run inside the request.
converge_logs() {
  local days=$1 force=$2 have_days=""
  local path=/api/v2/settings/ttl
  if [ "$force" -ne 1 ]; then
    http GET "$path"
    http_ok || die "logs: GET $path failed (HTTP $HTTP_STATUS): $(body_head)"
    have_days=$(jq -r '.default_ttl_days // empty' "$RESP") ||
      die "logs: unreadable JSON from $path: $(body_head)"
    if [ "$have_days" = "$days" ]; then
      echo "signoz-retention: logs: SigNoz already reports $days days"
      return 0
    fi
    echo "signoz-retention: logs: SigNoz reports '${have_days:-?}' days, want $days — POST settings/ttl (v2)"
  else
    echo "signoz-retention: logs: re-issuing settings/ttl for $days days (repair)"
  fi
  http POST "$path" "$(jq -n --argjson days "$days" '{type: "logs", defaultTTLDays: $days, ttlConditions: []}')"
  http_ok || die "logs: POST $path failed (HTTP $HTTP_STATUS): $(body_head)"
  echo "signoz-retention: logs: $days days applied"
}

# ── ClickHouse: the tables the API does not know, and the final read ─────
ch() { clickhouse-client --format TSVRaw "$@"; }

# clickhouse.service is "active" before its listener answers (boot race).
ready=false
for _ in $(seq 1 30); do
  if ch --query 'SELECT 1' >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
[ "$ready" = true ] || die "ClickHouse did not answer SELECT 1 within 60s"

# table_engine DB TABLE → engine_full. rc 1 = table absent, rc 2 = query failed.
table_engine() {
  local engine_full
  engine_full=$(ch --query "SELECT engine_full FROM system.tables WHERE database = '$1' AND name = '$2'") || return 2
  [ -n "$engine_full" ] || return 1
  printf '%s' "$engine_full"
}

TTL_CLAUSE_RE='.* TTL (.*) SETTINGS '

# ttl_clause DB TABLE → the table-level TTL clause (text between TTL and
# SETTINGS). rc 1 = table absent, rc 3 = present without a table-level TTL.
ttl_clause() {
  local engine_full
  engine_full=$(table_engine "$1" "$2") || return $?
  if ! [[ "$engine_full" =~ $TTL_CLAUSE_RE ]]; then
    return 3
  fi
  printf '%s' "${BASH_REMATCH[1]}"
}

at_seconds() { [[ "$1" == *"toIntervalSecond($2)"* ]]; }
at_days() { [[ "$1" == *"toIntervalDay($2)"* ]]; }

INTERVAL_RE='^(.+)[[:space:]]+[+]toInterval[A-Za-z]+[(][0-9]+[)]([[:space:]]+DELETE)?$'

# set_ttl_seconds DB TABLE SECONDS — moves only the interval of the existing
# table-level TTL; the time expression is read from the live table.
set_ttl_seconds() {
  local db=$1 table=$2 seconds=$3 clause time_expr rc
  if clause=$(ttl_clause "$db" "$table"); then
    :
  else
    rc=$?
    if [ "$rc" -eq 1 ]; then
      echo "signoz-retention:   $db.$table: absent — skipped"
      return 0
    fi
    die "$db.$table: cannot read a table-level TTL to move (rc $rc)"
  fi
  if at_seconds "$clause" "$seconds"; then
    echo "signoz-retention:   $db.$table: already at $((seconds / 86400)) days"
    return 0
  fi
  if ! [[ "$clause" =~ $INTERVAL_RE ]]; then
    die "$db.$table: TTL clause '$clause' is not a fixed interval — move it by hand"
  fi
  time_expr=${BASH_REMATCH[1]}
  echo "signoz-retention:   $db.$table: '$clause' → $((seconds / 86400)) days"
  ch --query "ALTER TABLE $db.$table MODIFY TTL $time_expr + toIntervalSecond($seconds) DELETE SETTINGS materialize_ttl_after_modify = 0" ||
    die "$db.$table: ALTER TABLE ... MODIFY TTL failed"
  clause=$(ttl_clause "$db" "$table") || die "$db.$table: unreadable after ALTER"
  at_seconds "$clause" "$seconds" || die "$db.$table: TTL is '$clause' after ALTER"
}

FAILURES=0

note_fail() {
  echo "signoz-retention: FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

# expect_seconds DB TABLE SECONDS — a table-level TTL interval equal to SECONDS.
expect_seconds() {
  local db=$1 table=$2 seconds=$3 clause rc
  if ! clause=$(ttl_clause "$db" "$table"); then
    rc=$?
    if [ "$rc" -ne 1 ]; then
      note_fail "$db.$table: cannot read its TTL (rc $rc)"
    fi
    return 0
  fi
  if ! at_seconds "$clause" "$seconds"; then
    note_fail "$db.$table: TTL is '$clause', want $((seconds / 86400)) days"
  fi
  return 0
}

# expect_days DB TABLE DAYS — the same, for the day-granular key tables.
expect_days() {
  local db=$1 table=$2 days=$3 clause rc
  if ! clause=$(ttl_clause "$db" "$table"); then
    rc=$?
    if [ "$rc" -ne 1 ]; then
      note_fail "$db.$table: cannot read its TTL (rc $rc)"
    fi
    return 0
  fi
  if ! at_days "$clause" "$days"; then
    note_fail "$db.$table: TTL is '$clause', want $days days"
  fi
  return 0
}

# expect_retention_default DB TABLE DAYS — the _retention_days column default.
expect_retention_default() {
  local db=$1 table=$2 days=$3 have
  if ! have=$(ch --query "SELECT default_expression FROM system.columns WHERE database = '$db' AND table = '$table' AND name = '_retention_days'"); then
    note_fail "$db.$table: cannot read the _retention_days default"
    return 0
  fi
  if [ -z "$have" ]; then
    echo "signoz-retention:   $db.$table: no _retention_days column — skipped"
    return 0
  fi
  if [ "$have" != "$days" ]; then
    note_fail "$db.$table: _retention_days default is '$have', want $days"
  fi
  return 0
}

# Tables SigNoz's TTL API moves itself — verified here, never ALTERed here.
METRIC_API_TABLES=(
  samples_v4 samples_v4_agg_5m samples_v4_agg_30m exp_hist
  time_series_v4 time_series_v4_6hrs time_series_v4_1day time_series_v4_1week
)
TRACE_API_TABLES=(
  signoz_index_v3 traces_v3_resource signoz_error_index_v2 usage_explorer
  dependency_graph_minutes_v2 trace_summary span_attributes_keys
)
LOGS_DEFAULT_TABLES=(logs_v2 logs_v2_resource distributed_logs_v2 distributed_logs_v2_resource)
LOGS_KEY_TABLES=(logs_attribute_keys logs_resource_keys)

# Tables the API does not know — moved here. Deliberately NOT listed: the
# *_buffer tables (about a day of ingest buffer, not retention), the usage
# tables (SigNoz's own bookkeeping), span_attributes (a two-day join helper)
# and the zero-row legacy tables (signoz_index_v2, signoz_spans, durationSort,
# samples_v2, time_series_v2).
METRIC_EXTRA_TABLES=(
  samples_v4_reduced_last_60s samples_v4_reduced_last_5m samples_v4_reduced_last_30m
  samples_v4_reduced_sum_60s samples_v4_reduced_sum_5m samples_v4_reduced_sum_30m
  time_series_v4_reduced time_series_v4_reduced_1day metadata
)
TRACE_EXTRA_TABLES=(tag_attributes_v2 top_level_operations)
LOGS_EXTRA_TABLES=(tag_attributes_v2)

verify_api_tables() {
  local table
  for table in "${METRIC_API_TABLES[@]}"; do
    expect_seconds "$DB_METRICS" "$table" $((DAYS_METRICS * 86400))
  done
  for table in "${TRACE_API_TABLES[@]}"; do
    expect_seconds "$DB_TRACES" "$table" $((DAYS_TRACES * 86400))
  done
  for table in "${LOGS_DEFAULT_TABLES[@]}"; do
    expect_retention_default "$DB_LOGS" "$table" "$DAYS_LOGS"
  done
  for table in "${LOGS_KEY_TABLES[@]}"; do
    expect_days "$DB_LOGS" "$table" "$DAYS_LOGS"
  done
}

echo "signoz-retention: target — metrics ${DAYS_METRICS}d, traces ${DAYS_TRACES}d, logs ${DAYS_LOGS}d"

for table in "${METRIC_EXTRA_TABLES[@]}"; do
  set_ttl_seconds "$DB_METRICS" "$table" $((DAYS_METRICS * 86400))
done
for table in "${TRACE_EXTRA_TABLES[@]}"; do
  set_ttl_seconds "$DB_TRACES" "$table" $((DAYS_TRACES * 86400))
done
for table in "${LOGS_EXTRA_TABLES[@]}"; do
  set_ttl_seconds "$DB_LOGS" "$table" $((DAYS_LOGS * 86400))
done

converge_v1 metrics "$DAYS_METRICS" 0
converge_v1 traces "$DAYS_TRACES" 0
converge_logs "$DAYS_LOGS" 0

verify_api_tables
if [ "$FAILURES" -gt 0 ]; then
  echo "signoz-retention: $FAILURES API-managed table(s) off target — re-issuing the API calls (repair)"
  FAILURES=0
  converge_v1 metrics "$DAYS_METRICS" 1
  converge_v1 traces "$DAYS_TRACES" 1
  converge_logs "$DAYS_LOGS" 1
  verify_api_tables
fi
if [ "$FAILURES" -gt 0 ]; then
  die "$FAILURES table(s) still off target after the repair pass (FAIL lines above)"
fi

echo "signoz-retention: converged — metrics ${DAYS_METRICS}d, traces ${DAYS_TRACES}d, logs ${DAYS_LOGS}d"
