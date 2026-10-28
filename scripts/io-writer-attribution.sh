#!/usr/bin/env bash
# io-writer-attribution.sh — name WHO is driving I/O pressure, live.
#
# Born 2026-10-28 (stability plan M9/F36-F37) from three live failures of
# ad-hoc attribution during the watchdog storm nights:
#   1. A /proc/<pid>/io pass as uid 1000 is BLIND to root writers
#      (nix-daemon workers, tq-agent-pool) — the guard's own io.stat
#      attribution named tq-agent-pool +162 GB/10 min while the user-side
#      pass showed "nothing big".  cgroup io.stat is world-readable and
#      covers root: it is the PRIMARY source here.
#   2. Byte attribution can show ~0 while io PSI sits at 60 % — a wedged
#      device or a metadata storm stalls WAITERS, not bytes.  The per-
#      cgroup io.pressure view (who is stalled) is printed alongside the
#      byte view so a "quiet writer, loud waiter" state is legible.
#   3. rg has no lookbehind and head-truncation corrupts census readings
#      (the F35 trap): parsing here is awk field-based and nothing is
#      truncated before ranking.
#
# Output contract: comm/cgroup names ONLY — never argv (secrets ride argv;
# scripts/redact-argv.sh compliance by construction).  Exit 0 unless the
# cgroup tree is unreadable (exit 1).
#
# Usage:
#   scripts/io-writer-attribution.sh [--window SECONDS] [--top N]
#                                    [--mb-threshold MB] [--no-pressure]
#   scripts/io-writer-attribution.sh --from-snapshots S1 S2 [...flags]
#     (replay mode — the selftest seam: S1/S2 are pre-captured cgroup
#      snapshots, one "rel rbytes wbytes" line each)
set -euo pipefail

WINDOW=5
TOP=15
MB_THRESHOLD=10
SHOW_PRESSURE=1
CGROUP_ROOT="${CGROUP_ROOT:-/sys/fs/cgroup}"
PROC_ROOT="${PROC_ROOT:-/proc}"
TMP_DIR="${IOATTR_TMP:-${XDG_CACHE_HOME:-$HOME/.cache}/ioattr}"
REPLAY=()

usage() { sed -n '2,30p' "$0" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --window) WINDOW="$2"; shift 2 ;;
    --top) TOP="$2"; shift 2 ;;
    --mb-threshold) MB_THRESHOLD="$2"; shift 2 ;;
    --no-pressure) SHOW_PRESSURE=0; shift ;;
    --from-snapshots) REPLAY=("$2" "$3"); shift 3 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "io-writer-attribution: unknown flag: $1" >&2; usage; exit 2 ;;
  esac
done

# One cgroup snapshot: "rel-path rbytes wbytes" for every readable io.stat
# under CGROUP_ROOT (bounded depth — the guard's forensics lesson: an
# unbounded find during an IO storm wedges the tool itself).  Transient
# cgroups dying mid-walk are skipped silently (a vanished io.stat must
# never abort the pass — the 2026-10-28 live trap).
snapshot() {
  find "$CGROUP_ROOT" -maxdepth 4 -name io.stat -readable -print0 2>/dev/null |
    while IFS= read -r -d "" f; do
      rel="${f#"$CGROUP_ROOT"/}"
      rel="${rel%/io.stat}"
      # the root cgroup aggregates the whole system — it would rank #1
      # forever and name no culprit (same call the guard makes)
      [ "$rel" = "io.stat" ] && continue
      bytes=$(awk '{ for (i = 2; i <= NF; i++) { split($i, kv, "="); if (kv[1] == "rbytes") r += kv[2]; if (kv[1] == "wbytes") w += kv[2] } } END { printf "%.0f %.0f", r + 0, w + 0 }' "$f" 2>/dev/null) || continue
      printf '%s %s\n' "$rel" "$bytes"
    done
}

if [ ${#REPLAY[@]} -gt 0 ]; then
  SNAP1="${REPLAY[0]}"
  SNAP2="${REPLAY[1]}"
else
  # Live-capture only: replay mode must not need a writable HOME (the nix
  # sandbox has none — the selftest runs this exact path).
  mkdir -p "$TMP_DIR"
  SNAP1="$TMP_DIR/cg-snap1"
  SNAP2="$TMP_DIR/cg-snap2"
  [ -r "$CGROUP_ROOT/io.stat" ] || [ -d "$CGROUP_ROOT" ] || {
    echo "io-writer-attribution: cgroup root unreadable: $CGROUP_ROOT" >&2
    exit 1
  }
  snapshot > "$SNAP1"
  sleep "$WINDOW"
  snapshot > "$SNAP2"
fi

echo "# io attribution: window=${WINDOW}s top=$TOP threshold=${MB_THRESHOLD}MB (rbytes/wbytes deltas per cgroup)"
# Sanity count line — the 2026-10-28 lesson: a silently broken pass printed
# "no movers" at PSI 61%. Sampled counts make "broken pass" distinguishable
# from "quiet writers" before any conclusion is drawn.
s1n=$(wc -l < "$SNAP1")
s2n=$(wc -l < "$SNAP2")
echo "# sanity: ${s1n} cgroups sampled at t0, ${s2n} at t1 — 0/0 = broken pass (do NOT read as calm); nonzero with no ranked lines = writers quiet, check the stalled-scopes view"
awk -v thr="$((MB_THRESHOLD * 1048576))" '
  NR == FNR { r1[$1] = $2; w1[$1] = $3; next }
  ($1 in r1) {
    dr = $2 - r1[$1]; dw = $3 - w1[$1]
    if (dr > thr || dw > thr) printf "%.1f %.1f %s\n", dr / 1048576, dw / 1048576, $1
  }' "$SNAP1" "$SNAP2" | sort -nr | head -n "$TOP" |
  awk '{ printf "%10.1fMB-rd %10.1fMB-wr %s\n", $1, $2, $3 }'

# Waiter view: per-cgroup io.pressure for the noisiest scopes.  Bytes say
# WHO MOVED DATA; io.pressure says WHO IS STALLED — the rm/wedge class
# (2026-10-28 02:xx: ~0 MB/s system-wide, io PSI 60, session-197 at 35 %
# behind a D-state rm on a USB SSD) is only legible here.
if [ "$SHOW_PRESSURE" = "1" ] && [ ${#REPLAY[@]} -eq 0 ]; then
  echo "# stalled scopes (per-cgroup io.pressure some avg10 >= 10%)"
  find "$CGROUP_ROOT" -maxdepth 3 -name io.pressure -readable -print0 2>/dev/null |
    while IFS= read -r -d "" f; do
      rel="${f#"$CGROUP_ROOT"/}"
      rel="${rel%/io.pressure}"
      [ "$rel" = "io.pressure" ] && continue
      line=$(awk '/^some avg10/ { print $2; exit }' "$f" 2>/dev/null) || continue
      val="${line#avg10=}"
      case "$val" in '' | *[!0-9.]*) continue ;; esac
      awk -v v="$val" 'BEGIN { exit !(v >= 10) }' || continue
      printf '%s %s\n' "$val" "$rel"
    done | sort -nr | head -n 8 | awk '{ printf "%8s%% %s\n", $1, $2 }'
fi

# User-side detail pass: /proc/<pid>/io deltas (uid-readable processes
# only — root writers are already covered by the cgroup view above; this
# adds process-level names for agent sessions/batteries).
if [ ${#REPLAY[@]} -eq 0 ] && [ -d "$PROC_ROOT" ]; then
  : > "$TMP_DIR/proc-snap1"
  for p in "$PROC_ROOT"/[0-9]*; do
    [ -r "$p/io" ] || continue
    pid="${p##*/}"
    wb=$(awk '/^write_bytes:/ { print $2 }' "$p/io" 2>/dev/null) || continue
    rb=$(awk '/^read_bytes:/ { print $2 }' "$p/io" 2>/dev/null) || continue
    printf '%s %s %s\n' "$pid" "${rb:-0}" "${wb:-0}" >> "$TMP_DIR/proc-snap1"
  done
  sleep 2
  : > "$TMP_DIR/proc-snap2"
  for p in "$PROC_ROOT"/[0-9]*; do
    [ -r "$p/io" ] || continue
    pid="${p##*/}"
    wb=$(awk '/^write_bytes:/ { print $2 }' "$p/io" 2>/dev/null) || continue
    rb=$(awk '/^read_bytes:/ { print $2 }' "$p/io" 2>/dev/null) || continue
    printf '%s %s %s\n' "$pid" "${rb:-0}" "${wb:-0}" >> "$TMP_DIR/proc-snap2"
  done
  echo "# user-visible process detail (>= ${MB_THRESHOLD}MB moved in 2s; comm only, root hidden by /proc perms)"
  awk -v thr="$((MB_THRESHOLD * 1048576))" '
    NR == FNR { r1[$1] = $2; w1[$1] = $3; next }
    ($1 in r1) {
      dr = $2 - r1[$1]; dw = $3 - w1[$1]
      if (dr > thr || dw > thr) print dr + dw, $1
    }' "$TMP_DIR/proc-snap1" "$TMP_DIR/proc-snap2" | sort -nr | head -n "$TOP" |
    while read -r total pid; do
      comm=$(cat "$PROC_ROOT/$pid/comm" 2>/dev/null || echo '?')
      cg=$(tail -1 "$PROC_ROOT/$pid/cgroup" 2>/dev/null | sed 's|.*/||') || cg='?'
      printf '%10.1fMB pid=%s %s [%s]\n' "$(awk -v t="$total" 'BEGIN { print t / 1048576 }')" "$pid" "$comm" "$cg"
    done
fi
