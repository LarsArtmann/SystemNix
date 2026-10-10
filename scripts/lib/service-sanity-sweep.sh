# shellcheck shell=bash
# Per-service sanity sweep for post-deploy-check.sh §18: catches services
# that are ALIVE but MISBEHAVING — the DiscordSync 2026-10-09 class burned
# 121% CPU and ~640 journal-lines/min (reconcileGCSURLs re-signing 100 URLs
# ~10x/sec) for HOURS after the a0db1e1 deploy while every liveness/HTTP
# gate stayed green.
#
# Two legs, both RATE-shaped (no restart blindness — a service this deploy
# just restarted still shows its true burn):
#   1. CPU%: cgroup v2 cpu.stat usage_usec delta over the sample window
#      (one directory read per service, no ps parsing).
#   2. Journal line-rate: one journalctl walk over the window, counted per
#      unit.
#
# Sourced (NEVER executed). The sourcer MUST define report_pass/report_warn/
# record_fail (FAIL integrates with the smoke fail-baseline: new fails exit
# 3, persistent ones go advisory). Parameter-overridable per call (same
# fixture pattern as memory-throttle-sweep.sh):
#   systemnix_service_sanity_sweep [slice_dir] [sample_seconds]
#                                [cpu_budget_pct] [journal_lines_per_min]
#                                [exempt_regex]
#
# Budgets are deliberately generous (a hotloop is 100%+ of a core SUSTAINED;
# legit bursts are short): CPU default 100% (one full core), journal default
# 300 lines/min sustained over the window (DiscordSync was 640). exempt_regex
# (ERE, matched against the unit name) excuses known-heavy units from the
# CPU leg only — a hotlooping exempt unit is still a journal-rate finding.
systemnix_service_sanity_sweep() {
  local slice_dir="${1:-/sys/fs/cgroup/system.slice}"
  local sample_seconds="${2:-10}"
  local cpu_budget_pct="${3:-100}"
  local journal_budget_per_min="${4:-300}"
  local exempt_regex="${5:-^(clickhouse|signoz-otel-collector)\.service$}"

  if [ ! -d "$slice_dir" ]; then
    report_skip "Service Sanity - $slice_dir missing (test env?)"
    return 0
  fi

  # ---- Leg 1: CPU% from cgroup cpu.stat deltas ----
  local unit cpu_a cpu_b delta_usec pct
  local -A usage_a=()
  for unit in "$slice_dir"/*.service; do
    [ -r "$unit/cpu.stat" ] || continue
    usage_a["$(basename "$unit")"]="$(awk '/^usage_usec / {print $2; exit}' "$unit/cpu.stat")"
  done
  sleep "$sample_seconds"
  local cpu_findings=""
  for unit in "$slice_dir"/*.service; do
    [ -r "$unit/cpu.stat" ] || continue
    local name
    name="$(basename "$unit")"
    cpu_b="$(awk '/^usage_usec / {print $2; exit}' "$unit/cpu.stat")"
    cpu_a="${usage_a[$name]:-}"
    [ -n "$cpu_a" ] || continue
    delta_usec=$((cpu_b - cpu_a))
    [ "$delta_usec" -le 0 ] && continue
    # pct of ONE core over the window, rounded to integer
    pct=$((delta_usec / (sample_seconds * 10000)))
    if [ "$pct" -gt "$cpu_budget_pct" ] && ! printf '%s' "$name" | grep -Eq "$exempt_regex"; then
      cpu_findings+="${cpu_findings:+ }${name}=${pct}%CPU"
    fi
  done
  if [ -n "$cpu_findings" ]; then
    record_fail "Service Sanity CPU - sustained >${cpu_budget_pct}% of one core over ${sample_seconds}s: $cpu_findings"
  else
    report_pass "Service Sanity CPU - no service above ${cpu_budget_pct}% of one core over ${sample_seconds}s"
  fi

  # ---- Leg 2: journal line-rate per unit over the last 10 minutes ----
  local window_minutes=10
  # One walk: json output, extract the unit identity (prefer _SYSTEMD_UNIT,
  # fall back to SYSLOG_IDENTIFIER), count. LC_ALL=C for stable sorting.
  # SANITY_JOURNAL_CMD overrides the journalctl invocation (fixture tests).
  local -A rate_findings=()
  local total_lines
  total_lines="$(eval "${SANITY_JOURNAL_CMD:-journalctl -q --since \"-${window_minutes} min\" -o json}" 2>/dev/null |
    jq -r '._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER // "unknown"' |
    LC_ALL=C sort | uniq -c || true)"
  if [ -z "$total_lines" ]; then
    report_warn "Service Sanity journal - journalctl walk returned nothing (journal offline or empty window)"
    return 0
  fi
  local budget_total=$((journal_budget_per_min * window_minutes))
  while read -r count identity; do
    case "$identity" in
    *.service) ;;
    *) continue ;; # only system.slice-shaped identities
    esac
    if [ "$count" -gt "$budget_total" ]; then
      rate_findings["$identity"]=$((count / window_minutes))
    fi
  done <<<"$total_lines"
  local rate_out=""
  for unit in "${!rate_findings[@]}"; do
    rate_out+="${rate_out:+ }${unit}=${rate_findings[$unit]}/min"
  done
  if [ -n "$rate_out" ]; then
    record_fail "Service Sanity journal - sustained >${journal_budget_per_min} lines/min over ${window_minutes}m: $rate_out"
  else
    report_pass "Service Sanity journal - no service above ${journal_budget_per_min} lines/min over ${window_minutes}m"
  fi
}
