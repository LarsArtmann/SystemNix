#!/usr/bin/env bash
# validate-gomemlimit.sh — runtime validation of GOMEMLIMIT settings.
#
# GOMEMLIMIT values in SystemNix follow the 75%-of-MemoryMax heuristic.
# This script validates at runtime whether those values are sane:
#   1. cgroup level: MemoryCurrent vs MemoryMax (OOM proximity)
#   2. Go heap level: go_memstats_heap_inuse_bytes vs GOMEMLIMIT (GC pressure)
#
# Heap > 90% of GOMEMLIMIT sustained = GC running hot (limit too tight or
# live-set genuinely large). MemoryCurrent > 90% of MemoryMax = OOM risk.
#
# Usage: sudo bash scripts/validate-gomemlimit.sh   (sudo for cgroup reads)
set -euo pipefail

# service:metrics-port pairs (0 = no known /metrics endpoint).
# MARKER: when you add GOMEMLIMIT to a service module, add it here too —
# the list is hardcoded because there is no cheap systemd query for
# "units carrying GOMEMLIMIT in Environment".
SERVICES=(
  "dnsblockd:9090"
  "discordsync:8085"
  "pocket-id:0"
  "papdashboard:0"
  "signoz:0"
  "signoz-collector:8888"
  "browser-history:8087"
  "file-and-image-renamer:0"
  "crush-daily:0"
  "projects-management-automation:0"
)

PASS=0
WARN=0

to_bytes() {
  # Convert systemd/Go memory units to bytes (KiB/MiB/GiB/TiB or plain).
  # Handles decimals (Go accepts e.g. 1.5GiB) via awk — bash arithmetic
  # is integer-only and cannot parse them.
  local value="$1"
  local number="${value%*[KMGTP]iB}"
  local unit="${value#"$number"}"
  case "$unit" in
  KiB) awk "BEGIN {printf \"%d\", $number * 1024}" ;;
  MiB) awk "BEGIN {printf \"%d\", $number * 1024 * 1024}" ;;
  GiB) awk "BEGIN {printf \"%d\", $number * 1024 * 1024 * 1024}" ;;
  TiB) awk "BEGIN {printf \"%d\", $number * 1024 * 1024 * 1024 * 1024}" ;;
  "") echo "$number" ;;
  *) echo "0" ;;
  esac
}

for entry in "${SERVICES[@]}"; do
  service="${entry%%:*}"
  metrics_port="${entry##*:}"

  echo "── $service ──"

  # Read unit properties
  env=$(systemctl show "$service" -p Environment --value 2>/dev/null || true)
  memlimit_raw=$(echo "$env" | grep -o 'GOMEMLIMIT=[0-9]*[KMGTP]\?i\?B\?' | cut -d= -f2 || true)
  memcurrent=$(systemctl show "$service" -p MemoryCurrent --value 2>/dev/null || echo "0")
  memmax=$(systemctl show "$service" -p MemoryMax --value 2>/dev/null || echo "infinity")

  if [ -z "$memlimit_raw" ]; then
    echo "  SKIP: no GOMEMLIMIT set (or service not found)"
    continue
  fi

  memlimit=$(to_bytes "$memlimit_raw")

  # cgroup-level check
  if [ "$memmax" != "infinity" ] && [ "$memmax" -gt 0 ] && [ "$memcurrent" -gt 0 ]; then
    pct=$((memcurrent * 100 / memmax))
    if [ "$pct" -ge 90 ]; then
      echo "  WARN: MemoryCurrent at ${pct}% of MemoryMax ($((memcurrent / 1024 / 1024))MiB / $((memmax / 1024 / 1024))MiB) — OOM risk"
      WARN=$((WARN + 1))
    else
      echo "  OK: MemoryCurrent at ${pct}% of MemoryMax"
      PASS=$((PASS + 1))
    fi
  fi

  # Go heap-level check (requires /metrics with go runtime stats)
  if [ "$metrics_port" != "0" ]; then
    heap=$(curl -sf --max-time 3 "http://127.0.0.1:${metrics_port}/metrics" 2>/dev/null |
      awk '/^go_memstats_heap_inuse_bytes/ {printf "%.0f", $2; exit}' || true)
    # Prometheus renders large counters in scientific notation (6.97e+08);
    # %.0f in the awk above normalizes them — bash arithmetic is integer-only.
    if [ -n "$heap" ] && [ "$memlimit" -gt 0 ]; then
      heap_pct=$((heap * 100 / memlimit))
      if [ "$heap_pct" -ge 90 ]; then
        echo "  WARN: heap at ${heap_pct}% of GOMEMLIMIT ($((heap / 1024 / 1024))MiB / ${memlimit_raw}) — GC pressure high"
        WARN=$((WARN + 1))
      elif [ "$heap_pct" -le 10 ]; then
        echo "  NOTE: heap at ${heap_pct}% of GOMEMLIMIT ($((heap / 1024 / 1024))MiB / ${memlimit_raw}) — limit may be oversized"
        PASS=$((PASS + 1))
      else
        echo "  OK: heap at ${heap_pct}% of GOMEMLIMIT ($((heap / 1024 / 1024))MiB / ${memlimit_raw})"
        PASS=$((PASS + 1))
      fi
    else
      echo "  NOTE: no go_memstats on :${metrics_port}/metrics (metrics endpoint unreachable or lacks Go runtime stats)"
    fi
  fi
done

echo ""
echo "Summary: $PASS OK, $WARN warnings"
[ "$WARN" -eq 0 ]
