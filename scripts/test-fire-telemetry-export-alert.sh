#!/usr/bin/env bash
# Test-fire the "Telemetry Export Failures" SigNoz rule END-TO-END, without
# stopping ClickHouse or the collector (agent-safe: no sudo, no systemd).
#
# The rule (modules/nixos/services/_signoz-alerts.nix) fires when
#   sum(increase({__name__=~"otelcol_exporter_send_failed_(log_records|spans|
#   metric_points)"}[10m])) >= 1
# and pages Discord via its route policy. This probe proves BOTH halves of
# that chain synthetically:
#
#   1. METRIC PATH: POST two cumulative samples of
#      otelcol_exporter_send_failed_log_records (0, then +5, 65s apart) to the
#      collector's OTLP/HTTP receiver (127.0.0.1:4318). The synthetic series
#      lands in signoz_metrics exactly like a scraped self-metric would, so
#      the rule's next 1m eval must flip the rule to FIRING. The series is
#      labeled service.name=test-fire (identifiable, +1 series cardinality)
#      and leaves the [10m] window on its own (~11 min) — the rule then
#      auto-resolves and Discord receives the resolved post (send_resolved).
#   2. DELIVERY PATH: successful Discord notifies are journal-SILENT (only
#      warnings log), so positive delivery evidence needs the documented
#      >256-rune alertname trick: a throwaway rule whose name exceeds the
#      Discord title limit makes the notifier log a "Truncated title" WARN
#      carrying receiver + ruleId. The throwaway reuses the SAME synthetic
#      query so it fires in the same window; rule + route policy are deleted
#      on exit (the provisioner's systemnix-tagged orphan pass is the
#      backstop if cleanup fails).
#
# Run: bash scripts/test-fire-telemetry-export-alert.sh
# Exit 0 = both halves proven. Any leg failure = exit 1 with the failing leg
# named — the synthetic series self-resolves, no manual rollback needed.
set -euo pipefail

API="http://localhost:8080"
OTLP_URL="http://127.0.0.1:4318/v1/metrics"
METRIC="otelcol_exporter_send_failed_log_records"
RULE_NAME="Telemetry Export Failures"
TEST_SERVICE="test-fire"
JOURNAL_UNIT="signoz.service"
FAILED=0

http() {
	# http METHOD PATH [BODY] -> sets HTTP_STATUS + HTTP_BODY
	local method="$1" path="$2" body="${3:-}"
	local args=(--silent --max-time 15)
	if [ -n "$body" ]; then
		args+=(-H "Content-Type: application/json" -d "$body")
	fi
	HTTP_BODY=$(curl "${args[@]}" -w $'\n%{http_code}' -X "$method" "$API$path") || HTTP_STATUS=000
	HTTP_STATUS=$(printf '%s' "$HTTP_BODY" | tail -1)
	HTTP_BODY=$(printf '%s' "$HTTP_BODY" | sed '$d')
}

die() {
	echo "FAIL: $*" >&2
	exit 1
}

leg() {
	if [ "$1" = 0 ]; then
		echo "  OK: $2"
	else
		echo "  FAIL: $2" >&2
		FAILED=1
	fi
}

echo "== Preflight: rule + route policy + channel =="

http GET "/api/v1/rules"
[ "$HTTP_STATUS" = 200 ] || die "SigNoz rules API unreachable (HTTP $HTTP_STATUS) — is signoz.service up?"
RULE_ID=$(jq -r --arg n "$RULE_NAME" '.data.rules[]? | select(.alert == $n) | .id' <<<"$HTTP_BODY" | head -1)
[ -n "$RULE_ID" ] || die "rule '$RULE_NAME' not provisioned — run the signoz provisioner first"
RULE_STATE=$(jq -r --arg n "$RULE_NAME" '.data.rules[]? | select(.alert == $n) | .state' <<<"$HTTP_BODY" | head -1)
echo "  rule id: $RULE_ID (state: $RULE_STATE)"

http GET "/api/v1/route_policies"
[ "$HTTP_STATUS" = 200 ] || die "route policies API failed (HTTP $HTTP_STATUS)"
POLICY_OK=$(jq -r --arg id "$RULE_ID" '[.data[]? | select(.name == $id and ((.channels // []) | index("Discord Alerts")))] | length' <<<"$HTTP_BODY")
[ "$POLICY_OK" -ge 1 ] || die "no route policy routes rule $RULE_ID to 'Discord Alerts' — alerts would be silently dropped (the 2026-08-16 class); run the provisioner"
echo "  route policy: $RULE_ID -> Discord Alerts"

http GET "/api/v1/channels"
[ "$HTTP_STATUS" = 200 ] || die "channels API failed (HTTP $HTTP_STATUS)"
jq -r '.data[]?.name' <<<"$HTTP_BODY" | grep -qx "Discord Alerts" || die "channel 'Discord Alerts' missing"

echo "== Leg 1: synthetic export-failure counter -> rule FIRING =="

post_counter() {
	# post_counter VALUE -> one OTLP/JSON metrics POST (cumulative Sum)
	local value="$1" ts
	ts="$(date +%s%3N)000000"
	local payload
	payload=$(jq -n \
		--arg metric "$METRIC" \
		--arg svc "$TEST_SERVICE" \
		--arg ts "$ts" \
		--arg value "$value" \
		'{
    resourceMetrics: [{
      resource: {attributes: [{key: "service.name", value: {stringValue: $svc}}]},
      scopeMetrics: [{
        scope: {name: "systemnix-test-fire", version: "1"},
        metrics: [{
          name: $metric,
          sum: {
            dataPoints: [{asInt: $value, timeUnixNano: $ts}],
            aggregationTemporality: "AGGREGATION_TEMPORALITY_CUMULATIVE",
            isMonotonic: true
          }
        }]
      }]
    }]
  }')
	curl --silent --max-time 10 -o /dev/null -w "%{http_code}" \
		-H "Content-Type: application/json" -X POST \
		--data "$payload" "$OTLP_URL"
}

STATUS=$(post_counter 0)
[ "$STATUS" = 200 ] || die "OTLP POST of baseline sample failed (HTTP $STATUS) — is the collector's :4318 receiver up?"
echo "  baseline sample (0) accepted"
sleep 65
STATUS=$(post_counter 5)
[ "$STATUS" = 200 ] || die "OTLP POST of failure sample failed (HTTP $STATUS)"
echo "  failure sample (+5) accepted — waiting for the 1m rule eval"

FIRED=""
for _ in $(seq 1 20); do
	sleep 15
	http GET "/api/v1/rules"
	STATE=$(jq -r --arg n "$RULE_NAME" '.data.rules[]? | select(.alert == $n) | .state' <<<"$HTTP_BODY" | head -1)
	if [ "$STATE" = "firing" ]; then
		FIRED=1
		break
	fi
	echo "  ... rule state: $STATE"
done
leg "${FIRED:-1}" "rule '$RULE_NAME' reached state=firing on the synthetic series (metric path end-to-end: OTLP ingest -> ClickHouse -> rule eval)"

echo "== Leg 2: >256-rune throwaway -> 'Truncated title' delivery proof =="

THROWAWAY_NAME="SystemNix test-fire delivery probe (auto-deleted) — this alert name deliberately exceeds the 256-rune Discord title limit so the alertmanager notifier logs a Truncated title WARN carrying receiver and ruleId, which is the only journal-visible positive-delivery evidence on this stack because successful Discord notifies are journal-silent"
QUERY="sum(increase({__name__=~\"otelcol_exporter_send_failed_(log_records|spans|metric_points)\"}[10m]))"
THROWAWAY_JSON=$(jq -n \
	--arg name "$THROWAWAY_NAME" \
	--arg query "$QUERY" \
	--arg desc "Synthetic test-fire delivery probe; auto-deleted by scripts/test-fire-telemetry-export-alert.sh" \
	'{
    alert: $name,
    alertType: "METRIC_BASED_ALERT",
    ruleType: "promql_rule",
    version: "v5",
    description: $desc,
    annotations: {description: ($desc + " (current: {{$value}})")},
    evalWindow: "1m",
    frequency: "1m",
    disabled: false,
    source: "RULE",
    condition: {
      compositeQuery: {
        queryType: "promql",
        panelType: "graph",
        queries: [{type: "promql", spec: {name: "A", query: $query, step: 60}}]
      },
      selectedQueryName: "A",
      op: "above_or_equal",
      target: 1,
      matchType: "last"
    },
    labels: {severity: "warning"},
    preferredChannels: ["Discord Alerts"]
  }')

# shellcheck disable=SC2329
# Invoked via the EXIT trap below.
cleanup() {
	local rc=$?
	if [ -n "${THROWAWAY_ID:-}" ]; then
		http DELETE "/api/v1/rules/$THROWAWAY_ID"
		[ "$HTTP_STATUS" = 200 ] || echo "  WARN: throwaway rule delete returned HTTP $HTTP_STATUS (the provisioner's orphan pass will remove it)" >&2
	fi
	if [ -n "${THROWAWAY_POLICY_ID:-}" ]; then
		http DELETE "/api/v1/route_policies/$THROWAWAY_POLICY_ID"
		[ "$HTTP_STATUS" = 200 ] || echo "  WARN: throwaway policy delete returned HTTP $HTTP_STATUS (systemnix-tagged orphan pass will remove it)" >&2
	fi
	exit "$rc"
}
trap cleanup EXIT

http POST "/api/v1/rules" "$THROWAWAY_JSON"
[ "$HTTP_STATUS" = 200 ] || die "throwaway rule create failed (HTTP $HTTP_STATUS): $(head -c 300 <<<"$HTTP_BODY")"
THROWAWAY_ID=$(jq -r '.data.id // empty' <<<"$HTTP_BODY")
[ -n "$THROWAWAY_ID" ] || die "throwaway rule created but no id returned"
echo "  throwaway rule created: $THROWAWAY_ID"

POLICY_JSON=$(jq -n \
	--arg id "$THROWAWAY_ID" \
	--arg desc "SystemNix test-fire probe: route throwaway rule to Discord Alerts" \
	'{expression: ("ruleId == \"" + $id + "\""), kind: "policy", channels: ["Discord Alerts"], name: $id, description: $desc, tags: ["systemnix", "test-fire"]}')
http POST "/api/v1/route_policies" "$POLICY_JSON"
[ "$HTTP_STATUS" = 200 ] || die "throwaway route policy create failed (HTTP $HTTP_STATUS): $(head -c 300 <<<"$HTTP_BODY")"
THROWAWAY_POLICY_ID=$(jq -r '.data.id // empty' <<<"$HTTP_BODY")
echo "  throwaway route policy created — waiting one eval cycle for the notify"

sleep 80
# The WARN carries the receiver name; grep the unit journal for the window.
if journalctl -u "$JOURNAL_UNIT" --since "-6 min" --output cat 2>/dev/null | grep -q "Truncated title"; then
	leg 0 "notifier logged 'Truncated title' for the >256-rune alert — Discord delivery path PROVEN (receiver reached the webhook stage)"
else
	leg 1 "no 'Truncated title' WARN in $JOURNAL_UNIT journal within 6 min — the notify may not have reached the Discord receiver (check route policies + channel webhook)"
fi

echo "== Result =="
if [ "$FAILED" = 0 ]; then
	echo "PASS: Telemetry Export Failures -> Discord proven end-to-end."
	echo "  The synthetic series (service.name=$TEST_SERVICE) leaves the [10m] window in ~10 min;"
	echo "  the rule auto-resolves and Discord receives the resolved post."
	echo "  Real-fire caveat: stopping clickhouse for 60s in a maintenance window remains the"
	echo "  full-fidelity fire (real exporter errors); this probe proves the identical rule/query/delivery chain synthetically."
	exit 0
else
	echo "FAIL: one or more legs above failed — see the FAIL lines." >&2
	exit 1
fi
