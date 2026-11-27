# shellcheck shell=bash
# Dashboard drift check for post-deploy-check.sh: is every dashboard the SigNoz
# API serves the one its file renders?
#
# This is the provisioner's own test (modules/nixos/services/
# _signoz-scripts.nix skips a dashboard when `jq -S` of the stored spec equals
# its file), read here instead of being inferred from the unit's Result:
# Result=success only says that the last run exited 0. A run that predates its
# files, or a dashboard edited by hand after it (a PUT outside a deploy; the
# ai-meter dashboard on 2026-11-26), leaves an older dashboard in place behind
# a green unit.
#
# Sourced (NEVER executed). The sourcer MUST define report_pass/report_fail/
# report_skip and, for the default fetcher, PORT_SIGNOZ.
#   systemnix_signoz_dashboards_drift [dashboards_dir] [fetch_command]
#
# fetch_command takes an API path and prints the answer body. The default is
# the SigNoz API on loopback; the selftest passes a fixture reader.
#
# An API that does not answer is a SKIP (the liveness checks own that); a file
# the API does not serve, or serves differently, is a FAIL.

# systemnix_signoz_api_get <path>: the SigNoz v2 dashboard API on loopback.
systemnix_signoz_api_get() {
  curl -s --compressed --max-time 5 "http://localhost:${PORT_SIGNOZ}$1"
}

systemnix_signoz_dashboards_drift() {
  local dashboards_dir="${1:-/etc/signoz/dashboards}"
  local fetch="${2:-systemnix_signoz_api_get}"
  local dash_list dash_count
  if ! compgen -G "${dashboards_dir}/*.json" > /dev/null; then
    report_skip "SigNoz dashboards - no dashboard files in ${dashboards_dir}"
    return 0
  fi
  dash_list="$("$fetch" "/api/v2/dashboards?limit=100&offset=0" 2>/dev/null)"
  dash_count="$(jq -r '.data.dashboards | length' <<<"${dash_list:-null}" 2>/dev/null || true)"
  if [ -z "$dash_count" ]; then
    report_skip "SigNoz dashboards - the API did not answer, live dashboards not readable"
    return 0
  fi

  local dash_file dash_slug dash_id dash_live dash_want
  local total=0 same=0
  local drift=""
  for dash_file in "${dashboards_dir}"/*.json; do
    dash_slug="$(jq -r '.name // empty' "$dash_file" 2>/dev/null)"
    total=$((total + 1))
    if [ -z "$dash_slug" ]; then
      drift="${drift} $(basename "$dash_file")(no slug)"
      continue
    fi
    dash_id="$(jq -r --arg slug "$dash_slug" '.data.dashboards[]? | select(.name == $slug) | .id' <<<"$dash_list" 2>/dev/null | head -n 1)"
    if [ -z "$dash_id" ]; then
      drift="${drift} ${dash_slug}(not provisioned)"
      continue
    fi
    dash_live="$("$fetch" "/api/v2/dashboards/${dash_id}" 2>/dev/null | jq -S '.data.spec' 2>/dev/null)"
    dash_want="$(jq -S '.spec' "$dash_file" 2>/dev/null)"
    # `jq -S` sorts object keys on both sides, so key order is not a difference.
    if [ -n "$dash_live" ] && [ "$dash_live" = "$dash_want" ]; then
      same=$((same + 1))
    else
      drift="${drift} ${dash_slug}"
    fi
  done

  if [ "$same" -eq "$total" ]; then
    report_pass "SigNoz dashboards - ${same} of ${total} live dashboards equal their files (a provisioner re-run would skip every one)"
  else
    report_fail "SigNoz dashboards - live differs from the files for:${drift} - the provisioner ran before its files changed, or a dashboard was edited by hand (journalctl -u signoz-provision -n 50)"
  fi
}
