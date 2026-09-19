#!/usr/bin/env bash
# IO-PSI forensics bundle — attribution capture at trap time (docs/todo/stability.md).
#
# A guard Zone 6 trip (or the deploy pressure gate) proves "I/O is stalled";
# it does NOT name the culprit. This script snapshots the evidence the moment
# it fires: per-cgroup io.stat totals, top processes by cumulative bytes,
# D-state tasks with stacks, PSI readings, diskstats, and the last journal
# lines — one timestamped bundle under /var/tmp. Read-only over /proc +
# /sys/fs/cgroup; every section is timeout-bounded and best-effort (evidence
# first, never fatal to the caller).
#
# Usage:
#   io-psi-forensics                  # manual run
#   io-psi-forensics "zone6-trip"     # labeled trigger (guard wiring)
#
# Exit codes: 0 if the bundle was written, 1 only if even the output dir
# could not be created (nothing else is allowed to be fatal).
set -uo pipefail

TRIGGER="${1:-manual}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="/var/tmp/io-psi-forensics-${STAMP}"

if ! mkdir -p "$OUT" 2>/dev/null; then
  echo "io-psi-forensics: cannot create bundle dir $OUT — skipping capture" >&2
  exit 1
fi
chmod 755 "$OUT" 2>/dev/null || true

{
  echo "trigger: ${TRIGGER}"
  echo "captured_utc: ${STAMP}"
  echo "uptime: $(cat /proc/uptime 2>/dev/null || echo unreadable)"
  echo "loadavg: $(cat /proc/loadavg 2>/dev/null || echo unreadable)"
  echo "meminfo_head:"
  head -5 /proc/meminfo 2>/dev/null || true
} >"${OUT}/meta.txt" 2>&1

# Pressure stall information at capture instant.
timeout 5 cat /proc/pressure/io /proc/pressure/memory /proc/pressure/cpu \
  >"${OUT}/psi.txt" 2>&1 || true

timeout 5 cat /proc/diskstats >"${OUT}/diskstats.txt" 2>&1 || true

# Per-cgroup io.stat: rbytes+wbytes totals, top 40 (who is HOLDING the I/O).
{
  echo "# cgroup io.stat totals (rbytes+wbytes bytes, desc) — top 40"
  # timeout: this script runs DURING IO storms — an unbounded find over
  # /sys/fs/cgroup (thousands of cgroup dirs, page-cache-starved) can wedge the
  # forensics tool itself.
  timeout 30 find /sys/fs/cgroup -name io.stat -print0 2>/dev/null |
    while IFS= read -r -d "" f; do
      case "$f" in
      # the root cgroup aggregates the whole system — it would be the
      # permanent #1 and tell us nothing about WHO holds the I/O
      "/sys/fs/cgroup/io.stat") continue ;;
      esac
      total="$(awk '{for (i = 2; i <= NF; i++) {split($i, kv, "="); if (kv[1] == "rbytes" || kv[1] == "wbytes") t += kv[2]}} END {print t + 0}' "$f" 2>/dev/null)" || total=0
      printf '%s %s\n' "${total:-0}" "$f"
    done |
    sort -rn | head -40 || true
} >"${OUT}/cgroup-io.txt" 2>&1

# Top processes by cumulative read+write bytes (/proc/PID/io). Glob over
# /proc churns: every per-pid read is guarded, vanished pids are skipped —
# the section always emits (the awk-vanished-input lesson, per-file form).
{
  echo "# top processes by read_bytes+write_bytes (/proc/PID/io, cumulative)"
  for f in /proc/[0-9]*/io; do
    pid="${f#/proc/}"
    pid="${pid%/io}"
    comm="$(cat "/proc/${pid}/comm" 2>/dev/null)" || continue
    bytes="$(awk '$1 ~ /^read_bytes:$/ || $1 ~ /^write_bytes:$/ {t += $2} END {print t + 0}' "$f" 2>/dev/null)" || continue
    printf '%s %s %s\n' "$bytes" "$pid" "$comm"
  done |
    sort -rn | head -20 || true
} >"${OUT}/top-io-procs.txt" 2>&1

# D-state tasks: wchan + stacks (stacks are root-only; as non-root the file
# read fails and the note says so — never silently empty).
{
  echo "# D-state tasks (uninterruptible — the unkillable wedge class)"
  ps -eo pid,ppid,stat,wchan:32,etimes,comm --no-headers 2>/dev/null |
    awk '$3 ~ /^D/ {print}' || true
  echo "--- stacks (best effort, root-only) ---"
  ps -eo pid,stat --no-headers 2>/dev/null |
    awk '$2 ~ /^D/ {print $1}' |
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      echo "== pid ${p} $(cat "/proc/${p}/comm" 2>/dev/null) =="
      cat "/proc/${p}/stack" 2>/dev/null || echo "unreadable (need root)"
      tr '\0' ' ' <"/proc/${p}/cmdline" 2>/dev/null
      echo
    done
} >"${OUT}/dstate.txt" 2>&1

# Journal tail for trip context — BOUNDED (-n) and timeout-wrapped; journal
# walks are an IO trap and this runs DURING a storm. Under heavy stalls
# journalctl can be killed before its first byte (live 2026-09-15: 0-byte
# captures on the 17:02/17:12Z trips, clean 22 KB on the 17:47Z one) — an
# empty file is a REAL finding, so mark it explicitly instead of leaving
# silent evidence gaps.
JRC=0
timeout 30 journalctl -n 100 --no-pager --output short-iso >"${OUT}/journal-tail.txt" 2>&1 || JRC=$?
if [ ! -s "${OUT}/journal-tail.txt" ]; then
  echo "journal tail EMPTY: journalctl rc=${JRC} (rc 124 = timeout stall under the storm that triggered this capture)" >"${OUT}/journal-tail.txt"
fi

echo "io-psi-forensics: bundle written to ${OUT}"
