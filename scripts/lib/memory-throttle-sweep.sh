# shellcheck shell=bash
# Runtime memory-throttle sweep for post-deploy-check.sh §17: reads the
# kernel's per-cgroup `high` counter (every reclaim pass under MemoryHigh)
# for every system-slice service and surfaces throttled units.
#
# Why: the llama-chat 2026-10-08 trap throttled 46k times over days while
# the unit stayed `active (running)`, logged nothing, and every liveness
# check stayed green — a pure performance failure is invisible to every
# existing gate. The eval-time memory-watermark-audit.nix kills the
# High<<Max CONFIG shape for new units; this sweep is the RUNTIME net over
# the units already deployed.
#
# Sourced (NEVER executed). The sourcer MUST define report_pass/report_warn/
# report_skip. Parameter-overridable per call (same fixture pattern as
# pressure-report.sh):
#   systemnix_memory_throttle_sweep [slice_dir] [warn_threshold]
#
# Semantics (advisory WARN, decided 2026-10-09 — revisit on
# docs/todo/monitoring.md): counters RESET on unit restart, so a unit this
# deploy just restarted reads 0 by construction, and a pre-existing throttle
# is not this deploy's regression — a hard FAIL would blind the gate to
# exactly the changed units. Throttle-only units (MemoryHigh without
# MemoryMax, e.g. btrbk) count here BY DESIGN — the watermark firing is
# their intended behavior. Count >= threshold (default 1000,
# env-overridable via SYSTEMNIX_THROTTLE_WARN_THRESHOLD — llama-chat was
# 46k, a startup blip is tens) warns per-unit; sub-threshold counts land on
# one compact advisory line; zero throttle anywhere is a PASS.
systemnix_memory_throttle_sweep() {
  local slice_dir="${1:-/sys/fs/cgroup/system.slice}"
  local warn_threshold="${2:-${SYSTEMNIX_THROTTLE_WARN_THRESHOLD:-1000}}"
  if [ ! -d "$slice_dir" ]; then
    report_skip "Memory throttle sweep — $slice_dir not available"
    return 0
  fi
  local events_file unit count warned=0 throttled_small=""
  for events_file in "$slice_dir"/*.service/memory.events; do
    [ -e "$events_file" ] || continue
    unit="$(basename "$(dirname "$events_file")")"
    count="$(awk '/^high / { print $2 }' "$events_file" 2>/dev/null)"
    count="${count:-0}"
    [ "$count" -gt 0 ] 2>/dev/null || continue
    if [ "$count" -ge "$warn_threshold" ]; then
      report_warn "Memory throttle — $unit hit its MemoryHigh watermark $count times since start (kernel reclaim-thrash; probe: cat $events_file — counters reset on restart; llama-chat 2026-10-08 was 46k)"
      warned=$((warned + 1))
    else
      throttled_small="$throttled_small $unit=$count"
    fi
  done
  if [ -n "$throttled_small" ]; then
    report_warn "Memory throttle — sub-threshold (advisory, below $warn_threshold):$throttled_small"
  fi
  if [ "$warned" -eq 0 ] && [ -z "$throttled_small" ]; then
    report_pass "Memory throttle sweep — no service hit its MemoryHigh watermark since start"
  fi
}
