#!/usr/bin/env bash
# vm-top-metrics.sh — top-N processes by total-vm (VmSize) textfile metric.
#
# 2026-11-07 (monitoring row, from the b0d70d73 reservation-cascade
# postmortem): reservation-pressure cascades (chromium VmSize balloons into
# the swap-exhausted kill pass) announce nothing until the kill. A top-5
# VmSize gauge family makes the balencers visible on the node dashboard
# BEFORE the OOM, and the metric history answers "what was ballooning" in
# the postmortem without journal archaeology.
#
# Output family (node_exporter textfile dir, atomic rename):
#   node_vm_top_vmsize_bytes{pid="N",comm="..."} <bytes>
#   node_vm_top_vmsize_hwm_bytes                  <max of the top set>  # convenience
#
# Testability: VM_TOP_PROC_DIR (default /proc) lets the selftest feed a
# fixture tree; `selftest` runs the fixture assertions (flake check:
# checks.x86_64-linux.vm-top-metrics-selftest).
#
# Usage:
#   vm-top-metrics.sh <out.prom> [selftest]
set -euo pipefail

PROC_DIR="${VM_TOP_PROC_DIR:-/proc}"
TOP_N="${VM_TOP_N:-5}"

# Emit "vmsize_bytes pid comm" lines for every readable /proc/<pid>/status.
# VmSize is the CURRENT total-vm (kB in status → bytes here); unreadable
# pids (kernel threads have no VmSize line) are skipped by construction.
vm_top_scan() {
  local status pid vmsize_kb comm
  for status in "$PROC_DIR"/[0-9]*/status; do
    [ -r "$status" ] || continue
    pid="${status%/status}"
    pid="${pid##*/}"
    vmsize_kb="$(awk '/^VmSize:/ { print $2; exit }' "$status" 2>/dev/null || true)"
    [ -n "$vmsize_kb" ] || continue
    comm="$(awk '/^Name:/ { sub(/^Name:[[:space:]]*/, ""); print; exit }' "$status" 2>/dev/null || true)"
    [ -n "$comm" ] || comm="unknown"
    # comm may contain characters Prometheus labels dislike; strip quotes
    # and backslashes (octal escapes: "/\), cap length.
    comm="$(printf '%s' "$comm" | tr -d '\042\134' | cut -c1-64)"
    printf '%s %s %s\n' "$((vmsize_kb * 1024))" "$pid" "$comm"
  done
}

# Render the .prom content from sorted scan lines.
vm_top_render() {
  local max=0 line bytes pid comm
  echo "# HELP node_vm_top_vmsize_bytes Top-${TOP_N} processes by total-vm (VmSize) in bytes."
  echo "# TYPE node_vm_top_vmsize_bytes gauge"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    bytes="${line%% *}"
    line="${line#* }"
    pid="${line%% *}"
    comm="${line#* }"
    echo "node_vm_top_vmsize_bytes{pid=\"${pid}\",comm=\"${comm}\"} ${bytes}"
    [ "$bytes" -gt "$max" ] && max="$bytes"
  done
  echo "# HELP node_vm_top_vmsize_hwm_bytes High-water mark of the top set (max single VmSize)."
  echo "# TYPE node_vm_top_vmsize_hwm_bytes gauge"
  echo "node_vm_top_vmsize_hwm_bytes ${max}"
}

vm_top_collect() { # <out.prom>
  local out="$1" tmp
  tmp="$(mktemp "${out}.tmp.XXXXXX")"
  vm_top_scan | sort -rn | head -"$TOP_N" | vm_top_render >"$tmp"
  # Atomic rename: node_exporter never reads a half-written file (the
  # sticky-textfile-dir doctrine every collector here follows).
  chmod 0644 "$tmp"
  mv "$tmp" "$out"
}

selftest() {
  local failures=0 tmp out
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' EXIT

  # Fixture proc tree: three pids with known VmSize + one kernel-thread
  # shape (no VmSize line) that must be skipped.
  mkdir -p "$tmp/proc/100/status" "$tmp/proc/2/status" "$tmp/proc/300/status" "$tmp/proc/4/status"
  printf 'Name:\tchrome\nVmSize:\t 2000000 kB\n' >"$tmp/proc/100/status/status" 2>/dev/null || true
  # (directories are wrong: status is a FILE — build files, not dirs)
  rm -rf "$tmp/proc"
  mkdir -p "$tmp/proc/100" "$tmp/proc/2" "$tmp/proc/300" "$tmp/proc/4"
  printf 'Name:\tchrome\nVmSize:\t 2000000 kB\n' >"$tmp/proc/100/status"
  printf 'Name:\tkthreadd\n' >"$tmp/proc/2/status"
  printf 'Name:\tchromium\nVmSize:\t 9000000 kB\n' >"$tmp/proc/300/status"
  printf 'Name:\tweird"comm\nVmSize:\t 1000 kB\n' >"$tmp/proc/4/status"

  out="$tmp/out.prom"
  # NOTE: PROC_DIR/TOP_N are bound at script start from the environment, so
  # a call-site env prefix would NOT rebind them — assign the fixture values
  # directly (function env-prefix ≠ variable rebinding).
  PROC_DIR="$tmp/proc"
  TOP_N=2
  vm_top_collect "$out"

  local want_top1='node_vm_top_vmsize_bytes{pid="300",comm="chromium"} 9216000000'
  grep -qxF "$want_top1" "$out" || {
    echo "FAIL top-1 line: wanted '$want_top1'"
    failures=$((failures + 1))
  }
  grep -q 'pid="100".*2048000000' "$out" || {
    echo "FAIL top-2 line (pid 100) missing"
    failures=$((failures + 1))
  }
  # TOP_N=2: the 1kB weird-comm pid must NOT appear; kthreadd never appears.
  if grep -q 'pid="4"' "$out"; then
    echo "FAIL TOP_N bound exceeded (pid 4 present)"
    failures=$((failures + 1))
  fi
  if grep -q 'kthreadd' "$out"; then
    echo "FAIL kernel thread (no VmSize) leaked into the top set"
    failures=$((failures + 1))
  fi
  grep -qxF 'node_vm_top_vmsize_hwm_bytes 9216000000' "$out" || {
    echo "FAIL hwm line"
    failures=$((failures + 1))
  }

  # Quote-stripping in comm labels: rerun with TOP_N=3 so the weird-comm
  # pid enters the set, then assert its label has no embedded quote.
  TOP_N=3
  vm_top_collect "$out"
  grep -q 'comm="weirdcomm"}' "$out" || {
    echo "FAIL comm quote-stripping (label not sanitized)"
    failures=$((failures + 1))
  }

  if [ "$failures" -gt 0 ]; then
    echo "vm-top-metrics selftest: $failures failure(s)"
    return 1
  fi
  echo "vm-top-metrics selftest: OK"
  return 0
}

case "${1:-}" in
selftest)
  selftest
  ;;
*)
  if [ "$#" -lt 1 ]; then
    echo "usage: vm-top-metrics.sh <out.prom> | selftest" >&2
    exit 1
  fi
  vm_top_collect "$1"
  ;;
esac
