#!/usr/bin/env bash
# Fixture for scripts/signoz-retention.sh — executed via
# checks.signoz-retention-selftest so no deploy is ever the script's first
# run. Stubs curl (the SigNoz settings/ttl API) and clickhouse-client
# (system.tables / system.columns reads + MODIFY TTL). The API stub models
# SigNoz's own ALTERs on the table list its API manages; the ClickHouse stub
# holds one engine_full per table and applies the script's ALTERs.
# Needs: bash, jq, coreutils on PATH.
# SIGNOZ_RETENTION_SCRIPT overrides the script under test (the rendered
# fixture check points it at the store writeShellApplication output).
set -uo pipefail

FAILURES=0
pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

SCRIPT="${SIGNOZ_RETENTION_SCRIPT:-$(dirname "$0")/signoz-retention.sh}"
BASE=$(mktemp -d)
trap 'rm -rf "$BASE"' EXIT
STUB_DIR="$BASE/stubs"
mkdir -p "$STUB_DIR/bin"

# ── shared fake-store helpers ─────────────────────────────────────────────
cat >"$STUB_DIR/lib.sh" <<'STUB_LIB'
# tables.tsv: db <TAB> table <TAB> engine_full   (the fake system.tables)
# columns.tsv: db <TAB> table <TAB> default_expression of _retention_days
stub_engine() { awk -F'\t' -v d="$1" -v t="$2" '$1 == d && $2 == t { print $3 }' "$STUB_STATE/tables.tsv"; }

stub_put_engine() {
  awk -F'\t' -v d="$1" -v t="$2" -v e="$3" -v OFS='\t' '
    $1 == d && $2 == t { print d, t, e; next } { print }' "$STUB_STATE/tables.tsv" >"$STUB_STATE/tables.tsv.tmp"
  mv "$STUB_STATE/tables.tsv.tmp" "$STUB_STATE/tables.tsv"
}

# stub_set_seconds DB TABLE SECONDS — what ClickHouse does with
# MODIFY TTL <time expr> + toIntervalSecond(N) DELETE: keeps the time
# expression, replaces the interval. A table named in $STUB_STATE/stub-stuck
# refuses (the read-only-leftover class).
stub_set_seconds() {
  local db=$1 table=$2 seconds=$3 engine replacement
  [ "$db.$table" = "$(cat "$STUB_STATE/stub-stuck" 2>/dev/null)" ] && return 0
  engine=$(stub_engine "$db" "$table") || return 1
  [ -n "$engine" ] || return 0
  replacement=$(printf '%s\n' "$engine" |
    sed -E "s/( TTL .+)[[:space:]]+[+]toInterval[A-Za-z]+[(][0-9]+[)]([[:space:]]+DELETE)?( SETTINGS .*)$/\1 + toIntervalSecond($seconds)\3/")
  [ "$replacement" != "$engine" ] || { echo "stub: no fixed TTL interval in $db.$table: $engine" >&2; return 1; }
  stub_put_engine "$db" "$table" "$replacement"
}

# stub_set_days DB TABLE DAYS — the day-granular form SigNoz writes on the
# logs key tables.
stub_set_days() {
  local db=$1 table=$2 days=$3 engine replacement
  engine=$(stub_engine "$db" "$table") || return 1
  [ -n "$engine" ] || return 0
  replacement=$(printf '%s\n' "$engine" |
    sed -E "s/( TTL .+)[[:space:]]+[+]toInterval[A-Za-z]+[(][0-9]+[)]([[:space:]]+DELETE)?( SETTINGS .*)$/\1 + toIntervalDay($days)\3/")
  [ "$replacement" != "$engine" ] || { echo "stub: no fixed TTL interval in $db.$table: $engine" >&2; return 1; }
  stub_put_engine "$db" "$table" "$replacement"
}

stub_retention_default() { awk -F'\t' -v d="$1" -v t="$2" '$1 == d && $2 == t { print $3 }' "$STUB_STATE/columns.tsv"; }

stub_set_retention_default() {
  awk -F'\t' -v d="$1" -v t="$2" -v v="$3" -v OFS='\t' '
    $1 == d && $2 == t { print d, t, v; next } { print }' "$STUB_STATE/columns.tsv" >"$STUB_STATE/columns.tsv.tmp"
  mv "$STUB_STATE/columns.tsv.tmp" "$STUB_STATE/columns.tsv"
}
STUB_LIB

# ── fake clickhouse-client ────────────────────────────────────────────────
cat >"$STUB_DIR/bin/clickhouse-client" <<'STUB_CH'
#!/usr/bin/env bash
# --format <f> --query "<sql>"
sql=""
while [ $# -gt 0 ]; do
  case "$1" in
    --format) shift 2 ;;
    --query) sql=$2; shift 2 ;;
    *) echo "stub clickhouse-client: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done
printf '%s\n' "$sql" >>"$STUB_STATE/queries.log"
if [ "$sql" = "SELECT 1" ]; then exit 0; fi
if [[ "$sql" =~ ^SELECT\ engine_full\ FROM\ system\.tables\ WHERE\ database\ =\ \'([^\']+)\'\ AND\ name\ =\ \'([^\']+)\'$ ]]; then
  stub_engine "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  exit 0
fi
if [[ "$sql" =~ ^SELECT\ default_expression\ FROM\ system\.columns\ WHERE\ database\ =\ \'([^\']+)\'\ AND\ table\ =\ \'([^\']+)\'\ AND\ name\ =\ \'_retention_days\'$ ]]; then
  stub_retention_default "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  exit 0
fi
if [[ "$sql" =~ ^ALTER\ TABLE\ ([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\ MODIFY\ TTL\ (.+)\ DELETE\ SETTINGS\ materialize_ttl_after_modify\ =\ 0$ ]]; then
  db=${BASH_REMATCH[1]} table=${BASH_REMATCH[2]} clause=${BASH_REMATCH[3]}
  [[ "$clause" =~ ^(.+)\ +toIntervalSecond\(([0-9]+)\)$ ]] || {
    echo "stub clickhouse-client: unexpected TTL clause '$clause'" >&2
    exit 1
  }
  stub_set_seconds "$db" "$table" "${BASH_REMATCH[2]}"
  exit $?
fi
echo "stub clickhouse-client: unhandled query: $sql" >&2
exit 1
STUB_CH

# ── fake curl: the SigNoz settings/ttl API ───────────────────────────────
cat >"$STUB_DIR/bin/curl" <<'STUB_CURL'
#!/usr/bin/env bash
# --silent --show-error --max-time N -o FILE -w FMT -X METHOD [--header H --data BODY] URL
method=GET url='' body='' out=/dev/null
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift 2 ;;
    --data) body=$2; shift 2 ;;
    -o) out=$2; shift 2 ;;
    -w|--max-time|--header) shift 2 ;;
    --silent|--show-error) shift ;;
    http*) url=$1; shift ;;
    *) echo "stub curl: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done
printf '%s %s%s\n' "$method" "${url#"$SIGNOZ_URL"}" "${body:+ BODY=$body}" >>"$STUB_STATE/curl.log"
respond() { printf '%s' "$2" >"$out"; printf '%s' "$1"; }

# The table lists SigNoz's own API ALTERs (reader.go setTTLMetrics /
# setTTLTraces / SetTTLV2 at the pinned rev).
METRIC_API_TABLES="samples_v4 samples_v4_agg_5m samples_v4_agg_30m exp_hist time_series_v4 time_series_v4_6hrs time_series_v4_1day time_series_v4_1week"
TRACE_API_TABLES="signoz_index_v3 traces_v3_resource signoz_error_index_v2 usage_explorer dependency_graph_minutes_v2 trace_summary span_attributes_keys"
LOGS_DEFAULT_TABLES="logs_v2 logs_v2_resource distributed_logs_v2 distributed_logs_v2_resource"

case "$method:${url#"$SIGNOZ_URL"}" in
  GET:/api/v1/settings/ttl?type=metrics)
    respond 200 "{\"metrics_ttl_duration_hrs\":$(cat "$STUB_STATE/api-metrics-hrs"),\"status\":\"success\"}" ;;
  GET:/api/v1/settings/ttl?type=traces)
    respond 200 "{\"traces_ttl_duration_hrs\":$(cat "$STUB_STATE/api-traces-hrs"),\"status\":\"success\"}" ;;
  GET:/api/v2/settings/ttl)
    respond 200 "{\"version\":\"v2\",\"status\":\"success\",\"default_ttl_days\":$(cat "$STUB_STATE/api-logs-days\"),\"ttl_conditions\":[]}" ;;
  POST:/api/v1/settings/ttl?type=metrics&duration=*h | POST:/api/v1/settings/ttl?type=traces&duration=*h)
    if [ -f "$STUB_STATE/post-fails" ]; then respond 500 '{"error":"boom"}'; exit 0; fi
    hours=${url##*duration=}; hours=${hours%h}
    if [ -f "$STUB_STATE/post-409-once" ]; then
      rm -f "$STUB_STATE/post-409-once"
      respond 409 '{"error":"TTL is already running"}'
    else
      echo "$hours" >"$STUB_STATE/api-${url#*/ttl?type=}"; echo "$hours" >"$STUB_STATE/api-${url#*type=}hour"
      for t in $(cat "$STUB_STATE/api-${url#*type=}" 2>/dev/null); do :; done
      respond 200 '{"message":"move ttl has been successfully set up"}'
    fi
    # The async goroutines: ALTER every table of the signal's list.
    case "$url" in
      *type=metrics*) tables=$METRIC_API_TABLES ;;
      *) tables=$TRACE_API_TABLES ;;
    esac
    for t in $tables; do stub_set_seconds "$1" "$t" "$((hours * 3600))"; done ;;
  POST:/api/v2/settings/ttl)
    if [ -f "$STUB_STATE/post-fails" ]; then respond 500 '{"error":"boom"}'; exit 0; fi
    days=$(printf '%s' "$body" | jq -r '.defaultTTLDays')
    echo "$days" >"$STUB_STATE/api-logs-days"
    respond 200 '{"message":"custom retention TTL has been successfully set up"}'
    for t in $LOGS_DEFAULT_TABLES; do stub_set_retention_default signoz_logs "$t" "$days"; done
    stub_set_days signoz_logs logs_attribute_keys "$days"
    stub_set_days signoz_logs logs_resource_keys "$days" ;;
  *) echo "stub curl: unhandled request: $method $url" >&2; respond 404 '{}' ;;
esac
STUB_CURL
chmod +x "$STUB_DIR/bin/clickhouse-client" "$STUB_DIR/bin/curl"

# ── fixture: the live store of 2026-11-28, before the change ─────────────
# engine_full strings as read from system.tables (tail from PARTITION BY).
seed_store() {
  local state=$1 m=signoz_metrics t=signoz_traces l=signoz_logs
  cat >"$state/tables.tsv" <<EOF
$m	samples_v4	MergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	samples_v4_agg_5m	AggregatingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	samples_v4_agg_30m	AggregatingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	exp_hist	MergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	time_series_v4	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	time_series_v4_6hrs	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	time_series_v4_1day	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	time_series_v4_1week	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(toUInt32(unix_milli / 1000), 'UTC') + toIntervalSecond(5184000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$m	samples_v4_reduced_last_60s	ReplacingMergeTree(computed_at) PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, reduced_fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	samples_v4_reduced_last_5m	ReplacingMergeTree(computed_at) PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, reduced_fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	samples_v4_reduced_last_30m	ReplacingMergeTree(computed_at) PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, reduced_fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	samples_v4_reduced_sum_60s	ReplacingMergeTree(computed_at) PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, reduced_fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	samples_v4_reduced_sum_5m	ReplacingMergeTree(computed_at) PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, reduced_fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	samples_v4_reduced_sum_30m	ReplacingMergeTree(computed_at) PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, reduced_fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	time_series_v4_reduced	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	time_series_v4_reduced_1day	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (env, temporality, metric_name, fingerprint, unix_milli) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 7200
$m	metadata	AggregatingMergeTree PARTITION BY toDate(last_reported_unix_milli / 1000) ORDER BY (temporality, metric_name, attr_name, attr_type, attr_datatype, attr_string_value) TTL toDateTime(last_reported_unix_milli / 1000) + toIntervalSecond(2592000) SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192
$t	signoz_index_v3	MergeTree PARTITION BY toDate(timestamp) ORDER BY (ts_bucket_start, resource_fingerprint, has_error, name, timestamp) TTL toDateTime(timestamp) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$t	traces_v3_resource	ReplacingMergeTree PARTITION BY (toDate(seen_at_ts_bucket_start), _retention_days, _retention_days_cold) ORDER BY (labels, fingerprint, seen_at_ts_bucket_start) TTL (toDateTime(seen_at_ts_bucket_start) + toIntervalSecond(1800)) + toIntervalSecond(1296000) SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192
$t	signoz_error_index_v2	MergeTree PARTITION BY toDate(timestamp) ORDER BY (ts_bucket_start, resource_fingerprint, has_error, name, timestamp) TTL toDateTime(timestamp) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$t	usage_explorer	SummingMergeTree PARTITION BY toDate(timestamp) ORDER BY (ts_bucket_start, resource_service_name, statistic_type, temporary_data_type, item_type) TTL toDateTime(timestamp) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$t	dependency_graph_minutes_v2	AggregatingMergeTree PARTITION BY toYYYYMMDD(timestamp) ORDER BY (client_service_name, server_service_name, ts_bucket_start) TTL toDateTime(timestamp) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192
$t	trace_summary	AggregatingMergeTree PARTITION BY toDate(end) ORDER BY (ts_bucket_start, resource_fingerprint, has_error, name, end) TTL toDateTime(end) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$t	span_attributes_keys	ReplacingMergeTree ORDER BY (tagKey, tagType, dataType) TTL timestamp + toIntervalDay(15) SETTINGS index_granularity = 8192
$t	tag_attributes_v2	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (tag_key, tag_type, tag_data_type, string_value, number_value) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, allow_nullable_key = 1
$t	top_level_operations	ReplacingMergeTree ORDER BY (serviceName, name) TTL time + toIntervalMonth(1) SETTINGS index_granularity = 8192
$t	durationSort	MergeTree PARTITION BY toDate(timestamp) ORDER BY (durationNano, timestamp) TTL toDateTime(timestamp) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$l	logs_v2	MergeTree PARTITION BY (toDate(timestamp / 1000000000), _retention_days, _retention_days_cold) ORDER BY (ts_bucket_start, resource_fingerprint, severity_text, timestamp, id) TTL toDateTime(timestamp / 1000000000) + toIntervalDay(_retention_days) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1
$l	logs_v2_resource	ReplacingMergeTree PARTITION BY (toDate(seen_at_ts_bucket_start), _retention_days, _retention_days_cold) ORDER BY (labels, fingerprint, seen_at_ts_bucket_start) TTL (toDateTime(seen_at_ts_bucket_start) + toIntervalDay(_retention_days)) + toIntervalSecond(1800) SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192
$l	distributed_logs_v2	Distributed('default', 'signoz_logs', 'logs_v2', cityHash64(id))
$l	distributed_logs_v2_resource	Distributed('default', 'signoz_logs', 'logs_v2_resource', cityHash64(fingerprint))
$l	logs_attribute_keys	ReplacingMergeTree ORDER BY (name, dataType, tagType) TTL timestamp + toIntervalDay(15) SETTINGS index_granularity = 8192
$l	logs_resource_keys	ReplacingMergeTree ORDER BY (name, dataType, tagType) TTL timestamp + toIntervalDay(15) SETTINGS index_granularity = 8192
$l	tag_attributes_v2	ReplacingMergeTree PARTITION BY toDate(unix_milli / 1000) ORDER BY (tag_key, tag_type, tag_data_type, string_value, number_value) TTL toDateTime(unix_milli / 1000) + toIntervalSecond(1296000) SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, allow_nullable_key = 1
EOF
  cat >"$state/columns.tsv" <<EOF
$l	logs_v2	15
$l	logs_v2_resource	15
$l	distributed_logs_v2	15
$l	distributed_logs_v2_resource	15
EOF
  echo 1440 >"$state/api-metrics-hrs"
  echo 360 >"$state/api-traces-hrs"
  echo 15 >"$state/api-logs-days"
}

# run_retention STATE [VAR=value ...] → script output; rc in RUN_RC
RUN_RC=0
run_retention() {
  local state=$1
  shift
  RUN_RC=0
  env STUB_STATE="$state" SIGNOZ_URL="http://signoz.test" DB_METRICS=signoz_metrics DB_TRACES=signoz_traces DB_LOGS=signoz_logs \
    RETENTION_DAYS_METRICS=90 RETENTION_DAYS_TRACES=90 RETENTION_DAYS_LOGS=90 \
    SIGNOZ_RETENTION_POLL_SECONDS=0 SIGNOZ_RETENTION_WAIT_SECONDS=0 \
    PATH="$STUB_DIR/bin:$PATH" "$@" bash "$SCRIPT" 2>&1 || RUN_RC=$?
}

new_state() {
  local state
  state=$(mktemp -d "$BASE/state.XXXXXX")
  seed_store "$state"
  echo "$state"
}

alter_count() { grep -c '^ALTER TABLE ' "$1/queries.log"; }
post_count() { grep -c '^POST ' "$1/curl.log"; }
ttl_of() { awk -F'\t' -v d="$2" -v t="$3" '$1 == d && $2 == t { print $3 }' "$1/tables.tsv" | sed -E 's/^(.* TTL .*) SETTINGS .*$/\1/'; }

# ── Leg 1: drift → API calls for the three signals, ALTERs on the 12
#    tables the API does not know, every table at 90 days afterwards ──────
S1=$(new_state)
OUT=$(run_retention "$S1")
[ "$RUN_RC" -eq 0 ] && pass "leg1 exit 0" || fail "leg1 exit $RUN_RC: $OUT"
echo "$OUT" | grep -q '^signoz-retention: converged — metrics 90d, traces 90d, logs 90d$' &&
  pass "leg1 converged line" || fail "leg1 converged line missing: $OUT"
grep -qx 'POST /api/v1/settings/ttl?type=metrics&duration=2160h' "$S1/curl.log" &&
  pass "leg1 POST metrics 2160h" || fail "leg1 metrics POST missing: $(grep '^POST' "$S1/curl.log")"
grep -qx 'POST /api/v1/settings/ttl?type=traces&duration=2160h' "$S1/curl.log" &&
  pass "leg1 POST traces 2160h" || fail "leg1 traces POST missing"
grep -qxF 'POST /api/v2/settings/ttl BODY={"type":"logs","defaultTTLDays":90,"ttl_conditions":[]}' "$S1/curl.log" ||
  grep -qF 'POST /api/v2/settings/ttl BODY={"type":"logs","defaultTTLDays":90,"ttlConditions":[]}' "$S1/curl.log" &&
  pass "leg1 POST logs v2 body" || fail "leg1 logs v2 POST missing: $(grep v2 "$S1/curl.log")"
[ "$(post_count "$S1")" -eq 3 ] && pass "leg1 exactly three POSTs" || fail "leg1 POST count $(post_count "$S1")"
[ "$(alter_count "$S1")" -eq 12 ] && pass "leg1 twelve ALTERs" || fail "leg1 ALTER count $(alter_count "$S1")"
if grep -qE '^ALTER TABLE (signoz_metrics\.(samples_v4|exp_hist|metadata)|signoz_traces\.(signoz_index_v3|top_level_operations)|signoz_logs\.(logs_v2|tag_attributes_v2)) ' "$S1/queries.log" &&
  ! grep -qE '^ALTER TABLE signoz_(metrics|traces|logs)\.(samples_v4|exp_hist|time_series_v4|signoz_index_v3|trace_summary|logs_v2|logs_attribute_keys) ' "$S1/queries.log"; then
  pass "leg1 ALTER set = exactly the API-unknown tables"
else
  fail "leg1 ALTER set wrong: $(grep '^ALTER' "$S1/queries.log")"
fi
grep -qx 'ALTER TABLE signoz_traces.top_level_operations MODIFY TTL time + toIntervalSecond(7776000) DELETE SETTINGS materialize_ttl_after_modify = 0' "$S1/queries.log" &&
  pass "leg1 keeps the time expression (top_level_operations)" || fail "leg1 time expression not kept"
for spec in \
  "signoz_metrics samples_v4" "signoz_metrics metadata" "signoz_metrics time_series_v4_reduced_1day" \
  "signoz_traces signoz_index_v3" "signoz_traces traces_v3_resource" "signoz_traces span_attributes_keys" \
  "signoz_traces top_level_operations" "signoz_traces tag_attributes_v2" "signoz_logs tag_attributes_v2"; do
  read -r db table <<<"$spec"
  if ttl_of "$S1" "$db" "$table" | grep -qF 'toIntervalSecond(7776000)'; then
    pass "leg1 $db.$table at 90 days"
  else
    fail "leg1 $db.$table not at 90 days: $(ttl_of "$S1" "$db" "$table")"
  fi
done
for table in logs_attribute_keys logs_resource_keys; do
  ttl_of "$S1" signoz_logs "$table" | grep -qF 'toIntervalDay(90)' &&
    pass "leg1 signoz_logs.$table at 90 days" || fail "leg1 signoz_logs.$table not at 90 days"
done
[ "$(cat "$S1/api-logs-days")" = 90 ] && pass "leg1 logs API state 90" || fail "leg1 logs API state wrong"
grep -qx 'signoz_logs	logs_v2	90' "$S1/columns.tsv" && pass "leg1 _retention_days default 90" || fail "leg1 _retention_days default wrong"
grep -q 'durationSort' "$S1/queries.log" && fail "leg1 touched legacy durationSort" || pass "leg1 legacy tables untouched"

# ── Leg 2: second run on the converged store is a pure verification ─────
S2="$S1"
: >"$S2/queries.log"
: >"$S2/curl.log"
OUT=$(run_retention "$S2")
[ "$RUN_RC" -eq 0 ] && pass "leg2 exit 0" || fail "leg2 exit $RUN_RC: $OUT"
[ "$(post_count "$S2")" -eq 0 ] && pass "leg2 no POST when in sync" || fail "leg2 POSTed while in sync: $(grep '^POST' "$S2/curl.log")"
[ "$(alter_count "$S2")" -eq 0 ] && pass "leg2 no ALTER when in sync" || fail "leg2 ALTERed while in sync"
echo "$OUT" | grep -q 'metrics: SigNoz already reports 90 days' &&
  pass "leg2 reports the in-sync signal" || fail "leg2 missing in-sync line: $OUT"

# ── Leg 3: the API reports the target but one of its tables is stale →
#    the repair pass re-issues the API calls and heals it ────────────────
S3=$(new_state)
run_retention "$S3" >/dev/null
# Rewind one API-managed table to its old TTL, as a half-applied change leaves it.
STUB_STATE="$S3" bash -c 'source "$1"; stub_set_seconds signoz_metrics time_series_v4_1week 5184000' _ "$STUB_DIR/lib.sh"
OUT=$(run_retention "$S3")
[ "$RUN_RC" -eq 0 ] && pass "leg3 exit 0 after repair" || fail "leg3 exit $RUN_RC: $OUT"
[ "$(post_count "$S3")" -eq 3 ] && pass "leg3 repair re-issued the three API calls" || fail "leg3 repair POST count $(post_count "$S3")"
ttl_of "$S3" signoz_metrics time_series_v4_1week | grep -qF 'toIntervalSecond(7776000)' &&
  pass "leg3 stale table healed" || fail "leg3 stale table still old: $(ttl_of "$S3" signoz_metrics time_series_v4_1week)"
echo "$OUT" | grep -q '1 API-managed table(s) off target — re-issuing' ||
  fail "leg3 repair line missing: $OUT"

# ── Leg 4: fail-closed — a POST that fails, a table that stays stale, a
#    table that refuses the ALTER, a bad day count ────────────────────────
S4=$(new_state)
touch "$S4/post-fails"
OUT=$(run_retention "$S4")
[ "$RUN_RC" -ne 0 ] && pass "leg4a non-zero on failing POST" || fail "leg4a exit 0 despite failing POST: $OUT"
echo "$OUT" | grep -q 'metrics: POST /api/v1/settings/ttl failed (HTTP 500)' ||
  fail "leg4a POST failure not named: $OUT"

S4B=$(new_state)
STUB_STATE="$S4B" bash -c 'source "$1"; stub_set_seconds signoz_metrics exp_hist 5184000; echo "signoz_metrics.exp_hist" >"$STUB_STATE/stub-stuck"' _ "$STUB_DIR/lib.sh"
OUT=$(run_retention "$S4B")
[ "$RUN_RC" -ne 0 ] && pass "leg4b non-zero when a table stays stale after repair" || fail "leg4b exit 0 with a stale table: $OUT"
echo "$OUT" | grep -q 'signoz_metrics.exp_hist: TTL is .*toIntervalSecond(5184000).*want 90 days' ||
  fail "leg4b stale table not named with its live TTL: $OUT"

S4C=$(new_state)
printf '%s\n' "signoz_metrics	metadata	MergeTree ORDER BY metric_name SETTINGS index_granularity = 8192" >"$S4C/tables.nottl"
awk -F'\t' 'FILENAME == ARGV[1] { print; next } !($1 == "signoz_metrics" && $2 == "metadata")' "$S4C/tables.nottl" "$S4C/tables.tsv" >"$S4C/tables.new" && mv "$S4C/tables.new" "$S4C/tables.tsv"
OUT=$(run_retention "$S4C")
[ "$RUN_RC" -ne 0 ] && pass "leg4c non-zero when a table lost its TTL clause" || fail "leg4c exit 0 with a TTL-less table: $OUT"
echo "$OUT" | grep -q 'signoz_metrics.metadata: cannot read a table-level TTL to move' ||
  fail "leg4c TTL-less table not named: $OUT"

S4D=$(new_state)
OUT=$(run_retention "$S4D" RETENTION_DAYS_LOGS=0)
[ "$RUN_RC" -ne 0 ] && pass "leg4d non-zero on a non-positive day count" || fail "leg4d exit 0 on 0 days: $OUT"
grep -q 'POST' "$S4D/curl.log" && fail "leg4d touched the API before validating" || pass "leg4d validates before any API call"

# ── Leg 5: HTTP 409 (another TTL change running) is waited out, not a
#    failure, when that change lands on the target ───────────────────────
S5=$(new_state)
touch "$S5/post-409-once"
OUT=$(run_retention "$S5")
[ "$RUN_RC" -eq 0 ] && pass "leg5 exit 0 after a 409" || fail "leg5 exit $RUN_RC: $OUT"
echo "$OUT" | grep -q 'another TTL change is running (HTTP 409) — waiting' ||
  fail "leg5 409 wait line missing: $OUT"

# ── Leg 6: an absent table is skipped, never a failure ──────────────────
S6=$(new_state)
awk -F'\t' '!($2 == "top_level_operations")' "$S6/tables.tsv" >"$S6/tables.new" && mv "$S6/tables.new" "$S6/tables.tsv"
OUT=$(run_retention "$S6")
[ "$RUN_RC" -eq 0 ] && pass "leg6 exit 0 with an absent table" || fail "leg6 exit $RUN_RC: $OUT"
echo "$OUT" | grep -q 'signoz_traces.top_level_operations: absent — skipped' ||
  fail "leg6 absent table not reported as skipped: $OUT"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "test-signoz-retention: all legs passed"
  exit 0
fi
echo "test-signoz-retention: $FAILURES assertion(s) failed"
exit 1
