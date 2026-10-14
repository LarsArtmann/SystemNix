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
# Durability (freeze-13/18 class, 2026-10): the capture runs SECONDS before a
# possible power cut — a bundle left in page cache ("bundle written" logged,
# rename done) still VANISHES when the box dies. The capture therefore lands
# in a staging dir, is fsynced file-by-file + dir-fsynced, THEN atomically
# renamed into place, THEN the parent dir is fsynced, and only THEN does the
# script log "bundle written" — so the log line implies the bytes survived.
#
# Retention: bundles are pruned to the KEEP-newest window after each capture
# (before 2026-10 the dir grew unbounded — 1,716 bundles since 09-14).
#
# Usage:
#   io-psi-forensics                  # manual run
#   io-psi-forensics "zone6-trip"     # labeled trigger (guard wiring)
#   io-psi-forensics selftest         # fixture selftest (no /var/tmp writes)
#
# Env overrides (selftest harness only; defaults are the live paths):
#   IO_PSI_FORENSICS_DIR   bundle root          (default /var/tmp)
#   IO_PSI_FORENSICS_KEEP  bundles to retain    (default ${KEEP_DEFAULT})
#
# Exit codes: 0 if the bundle was written, 1 only if even the output dir
# could not be created (nothing else is allowed to be fatal).
set -uo pipefail

KEEP_DEFAULT=50

if [ "${1:-}" = "selftest" ]; then
  SELFTEST=1
  TRIGGER="selftest"
else
  SELFTEST=0
  TRIGGER="${1:-manual}"
fi

BUNDLE_DIR="${IO_PSI_FORENSICS_DIR:-/var/tmp}"
KEEP="${IO_PSI_FORENSICS_KEEP:-$KEEP_DEFAULT}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
if [ "$SELFTEST" -eq 1 ]; then
  # the top-level capture path also runs in selftest mode — redirect it out
  # of /var/tmp into a throwaway dir the selftest cleans up
  BUNDLE_DIR="${TMPDIR:-/tmp}/io-psi-forensics-selftest-main.$$"
  mkdir -p "$BUNDLE_DIR"
fi
OUT="${BUNDLE_DIR}/io-psi-forensics-${STAMP}"
STAGING="${OUT}.staging.$$"

if ! mkdir -p "$STAGING" 2>/dev/null; then
  echo "io-psi-forensics: cannot create bundle staging dir $STAGING — skipping capture" >&2
  exit 1
fi
chmod 755 "$STAGING" 2>/dev/null || true

{
  echo "trigger: ${TRIGGER}"
  echo "captured_utc: ${STAMP}"
  echo "uptime: $(cat /proc/uptime 2>/dev/null || echo unreadable)"
  echo "loadavg: $(cat /proc/loadavg 2>/dev/null || echo unreadable)"
  echo "meminfo_head:"
  head -5 /proc/meminfo 2>/dev/null || true
} >"${STAGING}/meta.txt" 2>&1

# Pressure stall information at capture instant.
timeout 5 cat /proc/pressure/io /proc/pressure/memory /proc/pressure/cpu \
  >"${STAGING}/psi.txt" 2>&1 || true

timeout 5 cat /proc/diskstats >"${STAGING}/diskstats.txt" 2>&1 || true

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
} >"${STAGING}/cgroup-io.txt" 2>&1

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
} >"${STAGING}/top-io-procs.txt" 2>&1

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
} >"${STAGING}/dstate.txt" 2>&1

# Journal tail for trip context — BOUNDED (-n) and timeout-wrapped; journal
# walks are an IO trap and this runs DURING a storm. Under heavy stalls
# journalctl can be killed before its first byte (live 2026-09-15: 0-byte
# captures on the 17:02/17:12Z trips, clean 22 KB on the 17:47Z one) — an
# empty file is a REAL finding, so mark it explicitly instead of leaving
# silent evidence gaps.
JRC=0
timeout 30 journalctl -n 100 --no-pager --output short-iso >"${STAGING}/journal-tail.txt" 2>&1 || JRC=$?
if [ ! -s "${STAGING}/journal-tail.txt" ]; then
  echo "journal tail EMPTY: journalctl rc=${JRC} (rc 124 = timeout stall under the storm that triggered this capture)" >"${STAGING}/journal-tail.txt"
fi

# Durability barrier (freeze-13/18 vanish class): fsync every captured file,
# then fsync the staging dir itself, THEN atomic-rename into place, then
# fsync the parent dir. After the rename returns, the bundle's NAME is
# durable; after the parent fsync, its CONTENT is too. Only then does the
# "bundle written" line hit the journal — the line implies the bytes.
rc=0
for f in "$STAGING"/*; do
  sync -f "$f" 2>/dev/null || true
done
sync -d "$STAGING" 2>/dev/null || sync -f "$STAGING" 2>/dev/null || true
if mv "$STAGING" "$OUT" 2>/dev/null; then
  sync -d "$BUNDLE_DIR" 2>/dev/null || sync -f "$BUNDLE_DIR" 2>/dev/null || true
  echo "io-psi-forensics: bundle written (fsynced) to ${OUT}"
else
  echo "io-psi-forensics: rename ${STAGING} -> ${OUT} failed — staging dir left in place (evidence over tidiness)" >&2
  rc=1
fi

# Retention: keep the KEEP newest bundles, prune the rest. oldest-first so a
# kill mid-loop loses the least-relevant evidence. Never fatal.
if [ "$rc" -eq 0 ] && [ "$KEEP" -ge 1 ] 2>/dev/null; then
  # shellcheck disable=SC2012 # ls -t is fine for the fixed bundle-name shape
  ls -1dt "${BUNDLE_DIR}"/io-psi-forensics-* 2>/dev/null |
    tail -n +$((KEEP + 1)) |
    while IFS= read -r old; do
      rm -rf --one-file-system "$old" 2>/dev/null || true
    done
fi

# ---------------------------------------------------------------------------
# Fixture selftest: exercises durability + retention against a temp bundle
# dir — never touches /var/tmp. Asserts: (1) a capture produces EXACTLY the
# final bundle (no .staging residue), (2) the "bundle written" line is the
# fsynced form and appears only after the rename (source-order tripwire),
# (3) retention prunes to KEEP newest with oldest-first ordering, (4) the
# fsync barrier precedes the written-line in the source (the freeze-13
# property: the log line must imply durability).
if [ "$SELFTEST" -eq 1 ]; then
  selftest() {
    local tmp fails=0
    tmp="$(mktemp -d)"

    # (3) retention: seed 7 aged bundles, capture with KEEP=3, expect the 3
    # newest (the fresh one + the 2 newest seeds) and nothing else.
    local i name
    for i in 1 2 3 4 5 6 7; do
      name="${tmp}/io-psi-forensics-2026010${i}T000000Z"
      mkdir -p "$name"
      echo seed >"$name/meta.txt"
    done
    IO_PSI_FORENSICS_DIR="$tmp" IO_PSI_FORENSICS_KEEP=3 \
      bash "$0" "selftest-seed" >/dev/null 2>&1
    local got
    got="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d -name 'io-psi-forensics-*' | wc -l)"
    if [ "$got" -ne 3 ]; then
      echo "FAIL: retention kept $got bundles, expected 3" >&2
      fails=$((fails + 1))
    fi
    if ls -1d "${tmp}"/io-psi-forensics-2026010{1,2,3,4}T000000Z >/dev/null 2>&1; then
      echo "FAIL: retention pruned the WRONG (newest) bundles" >&2
      fails=$((fails + 1))
    fi

    # (1) no staging residue; bundle content present.
    if [ -n "$(find "$tmp" -maxdepth 1 -name '*.staging.*' -print -quit 2>/dev/null)" ]; then
      echo "FAIL: staging dir left behind after successful rename" >&2
      fails=$((fails + 1))
    fi
    local fresh
    fresh="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d -name 'io-psi-forensics-*' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)"
    if [ ! -s "$fresh/meta.txt" ]; then
      echo "FAIL: captured bundle has no meta.txt" >&2
      fails=$((fails + 1))
    fi

    # (2)+(4) source tripwires: fsync barrier before the rename, rename
    # before the "written" log, and the log carries the fsynced marker.
    local src sync_l mv_l log_l
    src="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    # shellcheck disable=SC2016
    sync_l="$(grep -n 'sync -f "$f"' "$src" | head -1 | cut -d: -f1)"
    # shellcheck disable=SC2016
    mv_l="$(grep -n 'if mv "$STAGING" "$OUT"' "$src" | head -1 | cut -d: -f1)"
    log_l="$(grep -n 'bundle written (fsynced)' "$src" | head -1 | cut -d: -f1)"
    if [ -z "$sync_l" ] || [ -z "$mv_l" ] || [ -z "$log_l" ]; then
      echo "FAIL: durability tripwire anchors missing (sync@$sync_l mv@$mv_l log@$log_l)" >&2
      fails=$((fails + 1))
    elif [ "$sync_l" -ge "$mv_l" ] || [ "$mv_l" -ge "$log_l" ]; then
      echo "FAIL: durability order broken (sync@$sync_l must precede mv@$mv_l must precede log@$log_l)" >&2
      fails=$((fails + 1))
    fi
    if ! grep -q 'echo "io-psi-forensics: bundle written (fsynced)' "$src"; then
      echo "FAIL: written-line lost its fsynced marker" >&2
      fails=$((fails + 1))
    fi

    rm -rf "$tmp"
    if [ "$fails" -gt 0 ]; then
      echo "io-psi-forensics selftest: $fails failure(s)" >&2
      exit 1
    fi
    echo "io-psi-forensics selftest: OK (durability order, staging residue, retention)"
  }
  selftest
  st_rc=$?
  rm -rf "${TMPDIR:-/tmp}/io-psi-forensics-selftest-main.$$" "$BUNDLE_DIR" 2>/dev/null
  exit "$st_rc"
fi

exit "$rc"
