#!/usr/bin/env bash
# metric-exists.sh — store-truth probe for a SigNoz metric name.
#
# Answers "does this series exist, and as WHAT type/temporality?" — the gate
# every dashboard-query/alert-query naming decision must pass BEFORE the name
# is written (the 2026-10-17 dotted-query regression shipped because the
# answer was inferred from a lint lesson instead of probed; see
# docs/agents/monitoring.md "Exporter names vs store names").
#
# Usage:
#   scripts/metric-exists.sh ai_meter_ttft_seconds_sum     # exact name
#   scripts/metric-exists.sh 'ai_meter%'                    # LIKE pattern
# Exit: 0 = series exist (rows printed), 1 = zero series, 2 = usage/CH error.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <metric-name-or-LIKE-pattern>" >&2; exit 2; }
pattern=$1
case "$pattern" in
*%*) where_clause="metric_name LIKE '$pattern'" ;;
*) where_clause="metric_name = '$pattern'" ;;
esac

rows=$(clickhouse-client --query "SELECT metric_name, type, temporality, count() AS series
  FROM signoz_metrics.distributed_time_series_v4
  WHERE $where_clause
  GROUP BY metric_name, type, temporality
  ORDER BY metric_name" 2>&1) || { echo "CH query failed: $rows" >&2; exit 2; }

if [ -z "$rows" ]; then
  echo "ZERO-SERIES: $pattern (phantom — no dashboard/alert may query it)"
  exit 1
fi
printf '%s\n' "$rows"
