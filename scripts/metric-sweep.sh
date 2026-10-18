#!/usr/bin/env bash
# metric-sweep.sh — repo-native store-truth sweep over EVERY dashboard + alert query.
#
# Extracts every metric-name reference from modules/nixos/services/dashboards/*.json
# and _signoz-alerts.nix (all three nix quote forms), probes them against the live
# ClickHouse time-series table in ONE batched query, and FAILS on any zero-series
# name that is not on the expected-absent allowlist. This is the mechanical version
# of the doctrine "probe the store before writing any query name" (the 2026-10-17
# dotted-query regression shipped because the answer was inferred, not probed; the
# 2026-10-18 manual sweep that caught it is promoted here — see
# docs/agents/monitoring.md "Exporter names vs store names").
#
# Usage:
#   scripts/metric-sweep.sh              # full sweep (needs clickhouse-client + LAN store)
#   scripts/metric-sweep.sh --list       # print the extracted name set, no probe
#   SWEEP_INJECT=<name> scripts/metric-sweep.sh   # self-test: force one name through
#                                                 # the whole probe->classify->fail path
#                                                 # (it must NOT be allowlisted)
# Exit: 0 = green (all zero-series names expected) · 1 = unallowlisted phantoms ·
#       2 = tool/store error.
#
# Allowlist: scripts/metric-sweep-expected-absent.txt — every entry needs a
# store-truth justification; fixing a queued phantom = DELETE its line, after which
# the sweep guards the fix. Opt-in harness leg: CASES=metricnames (never runs in
# CI — the nightly workflow sets no CASES and this group requires explicit
# selection because CI has no store access).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARDS_GLOB="$REPO_ROOT/modules/nixos/services/dashboards/*.json"
ALERTS_FILE="$REPO_ROOT/modules/nixos/services/_signoz-alerts.nix"
ALLOWLIST="$REPO_ROOT/scripts/metric-sweep-expected-absent.txt"

# ── extraction ──────────────────────────────────────────────────────────────
# Alerts (nix): query = ''…'' (multi- or single-line), "…", and '…'. The python
# predecessor missed the double-quote form (system_tmpfs_tmp_usage_percent was
# never probed) — fixed here at the scanner.
extract_alert_queries() {
  gawk '
    BEGIN { inq = 0; q = "" }
    {
      if (inq) {
        if (index($0, "\x27\x27") > 0) {  # closing xx quote pair
          q = q " " substr($0, 1, index($0, "\x27\x27") - 1)
          print q; q = ""; inq = 0
        } else { q = q " " $0 }
        next
      }
      if (match($0, /query[ \t]*=[ \t]*\x27\x27/) > 0) {
        rest = substr($0, RSTART + RLENGTH)
        p = index(rest, "\x27\x27")
        if (p > 0) { print substr(rest, 1, p - 1) }
        else { q = rest; inq = 1 }
        next
      }
      if (match($0, /query[ \t]*=[ \t]*"[^"]*"/) > 0) {
        s = substr($0, RSTART, RLENGTH)
        sub(/^[^"]*"/, "", s); sub(/"$/, "", s)
        print s
        next
      }
      if (match($0, /query[ \t]*=[ \t]*\x27[^\x27]*\x27/) > 0) {
        s = substr($0, RSTART, RLENGTH)
        sub(/^[^\x27]*\x27/, "", s); sub(/\x27$/, "", s)
        print s
      }
    }' "$ALERTS_FILE"
}

# Dashboards (json): every panel query string.
extract_dashboard_queries() {
  jq -r '.spec.panels[]?.spec.queries[]?.spec.plugin.spec.query? // empty' $DASHBOARDS_GLOB
}

# Tokenizer: query text -> candidate metric names.
#   1. {__name__=~"P(a|b)"} regex matchers are EXPANDED to Pa/Pb (the split-artifact
#      class: bare `log_records`/`metric_points` were tokenizer ghosts of live
#      otelcol_exporter_send_failed_* names);
#   2. by/without/on/ignoring/group_left/group_right ( … ) label lists are dropped
#      (bare `service_name` is a label, not a metric);
#   3. remaining double-quoted strings are dropped (label VALUES — the auth_error/
#      bucket_name ghosts);
#   4. identifiers surviving with . _ or : that are not PromQL functions are names.
extract_names() {
  gawk '
    BEGIN {
      n = split("rate irate increase sum avg min max count avg_over_time sum_over_time count_over_time max_over_time min_over_time quantile histogram_quantile clamp_min clamp_max by without absent absent_over_time label_replace label_join vector time now epoch group stddev stdvar topk bottomk changes resets delta idelta predict_linear holt_winters round scalar sort sort_desc sort_limit ceil floor exp ln log2 log10 sqrt abs sgn month year day_of_month day_of_week days_in_month hour minute timestamp offset", arr, " ")
      for (i = 1; i <= n; i++) FUNC[arr[i]]
    }
    function add(t) { if (t ~ /^[a-zA-Z_:][a-zA-Z0-9_.:]*$/ && t ~ /[._:]/) names[t] = 1 }
    function harvest(content,   k, j, alts, t, m2) {
      if (content ~ /[()]/ && content !~ /\.\*|\[|\+|\?|\|.*\|.*\(/) {
        if (match(content, /^([^()]*)\(([^()]*)\)([^()]*)$/, m2) > 0) {
          k = split(m2[2], alts, "|")
          for (j = 1; j <= k; j++) {
            t = m2[1] alts[j] m2[3]
            gsub(/[$^]/, "", t)
            add(t)
          }
          return
        }
      }
      tokenize(content)
    }
    function tokenize(s,   m) {
      while (match(s, /[a-zA-Z_:][a-zA-Z0-9_.:]*/, m) > 0) {
        if (!(m[0] in FUNC)) add(m[0])
        s = substr(s, RSTART + RLENGTH)
      }
    }
    {
      line = $0
      while (match(line, /__name__=~?"([^"]*)"/, m) > 0) {
        rs = RSTART; rl = RLENGTH  # harvest->tokenize calls match() and CLOBBERS
                                   # the globals — snapshot before the call (the
                                   # 2026-10-19 infinite-loop bug: line never shrank)
        harvest(m[1])
        line = substr(line, 1, rs - 1) substr(line, rs + rl)
      }
      gsub(/(by|without|on|ignoring|group_left|group_right)[ \t]*\([^()]*\)/, " ", line)
      gsub(/\{[^}]*\}/, " ", line)  # remaining selectors are pure label matchers
                                    # ({service_name="x"} — bare label NAMES are
                                    # not metric tokens; __name__ refs were
                                    # harvested above)
      gsub(/"[^"]*"/, " ", line)
      tokenize(line)
    }
    END { for (t in names) print t }
  '
}

# ── allowlist ────────────────────────────────────────────────────────────────
# Exact names or *-globs; comment lines give the store-truth justification.
is_expected_absent() {
  local name=$1 entry
  while IFS= read -r entry; do
    # Glob match is the point: allowlist entries are *-patterns (e.g.
    # *_googleapis_*), matched against the metric name.
    # shellcheck disable=SC2254
    case "$name" in
    $entry) return 0 ;;
    esac
  done < <(grep -v '^[[:space:]]*#' "$ALLOWLIST" | grep -v '^[[:space:]]*$')
  return 1
}

main() {
  # NOTE: names_file/live_file stay SCRIPT-scoped (no `local`) — the EXIT trap
  # fires after main returns and `set -u` would trip on a vanished local.
  local live missing name
  names_file=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/metric-sweep.names.XXXXXX")
  live_file=""
  trap 'rm -f "$names_file" ${live_file:++"$live_file"}' EXIT

  {
    extract_dashboard_queries
    extract_alert_queries
  } | extract_names | sort -u >"$names_file"

  if [ -n "${SWEEP_INJECT:-}" ]; then
    case "$SWEEP_INJECT" in
    *[!a-zA-Z0-9_.:]*)
      echo "SWEEP_INJECT charset violation (a-zA-Z0-9_.: only): $SWEEP_INJECT" >&2
      exit 2
      ;;
    esac
    printf '%s\n' "$SWEEP_INJECT" >>"$names_file"
    sort -u -o "$names_file" "$names_file"
  fi

  local total
  total=$(wc -l <"$names_file")
  echo "extracted $total distinct metric-name references"

  if [ "${1:-}" = "--list" ]; then
    cat "$names_file"
    return 0
  fi

  command -v clickhouse-client >/dev/null 2>&1 || {
    echo "clickhouse-client not on PATH — the sweep needs LAN store access (CASES=metricnames is local-only by design)" >&2
    exit 2
  }

  local in_list
  in_list=$(sed "s/\([^']*\)/'\1'/" "$names_file" | paste -sd, -)
  live=$(clickhouse-client --query "SELECT DISTINCT metric_name FROM signoz_metrics.distributed_time_series_v4 WHERE metric_name IN ($in_list)") || {
    echo "CH query failed — store unreachable?" >&2
    exit 2
  }

  live_file=$(mktemp "${XDG_CACHE_HOME:-$HOME/.cache}/metric-sweep.live.XXXXXX")
  printf '%s\n' "$live" | sort -u >"$live_file"

  missing=$(comm -23 "$names_file" "$live_file")
  local live_count phantom_count expected_count fail_count
  live_count=$(comm -12 "$names_file" "$live_file" | wc -l)
  phantom_count=$(printf '%s' "$missing" | grep -c . || true)
  expected_count=0
  fail_count=0

  if [ -n "$missing" ]; then
    echo "-- zero-series names: $phantom_count --"
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      if is_expected_absent "$name"; then
        echo "EXPECTED-ABSENT  $name"
        expected_count=$((expected_count + 1))
      else
        echo "PHANTOM          $name  <- queried by a dashboard/alert, ZERO series in the store"
        fail_count=$((fail_count + 1))
      fi
    done <<<"$missing"
  fi

  echo "sweep verdict: $live_count live, $expected_count expected-absent, $fail_count PHANTOM(S)"
  if [ "$fail_count" -gt 0 ]; then
    echo "FAIL: probe each with scripts/metric-exists.sh, fix the query (or justify + allowlist), per docs/agents/monitoring.md" >&2
    exit 1
  fi
}

main "$@"
