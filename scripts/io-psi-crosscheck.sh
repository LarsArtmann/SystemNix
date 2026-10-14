#!/usr/bin/env bash
# io-psi-crosscheck.sh — device-truth evidence beside a deploy-gate PSI refusal.
#
# The 2026-10-13 21:5x deploy refusal showed io PSI some avg10 53-65% sustained
# 15+ min while iostat put every device at <=0.4% util, no userspace process
# exceeded 1 MB/s, and D-state was empty at every sample. The gate's own
# max-busy figure even misread that refusal as a REAL storm (29.8% busy at
# entry). PSI alone misleads the wait-vs-force decision
# (docs/status/2026-10-13_22-51_upstream-repair-wave-20261011-nixpkgs-bump.md
# §f.7). This helper prints the discriminating evidence: per-device %util from
# two /sys/block/<dev>/stat io_ticks snapshots, and the top stalled cgroups
# ranked by io.pressure some avg10 (the walk that located the ghostty monitor
# scopes as the stalled parties on both 2026-10-08 and 2026-10-13).
#
# Usage:
#   io-psi-crosscheck.sh            # gate mode: per-device %util + top-3
#                                   #   stalled cgroups (what deploy.sh calls)
#   io-psi-crosscheck.sh full       # divergence probe: adds PSI readings,
#                                   #   zram ops delta, io.cost state, D-state
#                                   #   scan, per-pid io deltas (§f.8 probe)
#   io-psi-crosscheck.sh selftest [path/to/deploy.sh]
#
# Read-only over /proc + /sys. Every section is timeout-bounded and
# best-effort (evidence first, never fatal to the caller). Exit 0 when
# evidence was produced; exit 1 only on bad usage or a failed selftest.
set -uo pipefail

MODE="${1:-gate}"

CROSSCHECK_SYS_BLOCK="${CROSSCHECK_SYS_BLOCK:-/sys/block}"
CROSSCHECK_CGROUP="${CROSSCHECK_CGROUP:-/sys/fs/cgroup}"
CROSSCHECK_PROC="${CROSSCHECK_PROC:-/proc}"
CROSSCHECK_WINDOW_S="${CROSSCHECK_WINDOW_S:-1}"

# Pure: per-device %util lines from two "name io_ticks" snapshot streams.
# io_ticks is field 10 of /sys/block/<dev>/stat, in ms; a W-second window
# makes delta_ms / (10 * W) the %util. Unmatched names (device vanished or
# appeared between snapshots) are dropped by the name equality guard.
crosscheck_util_lines() {
  local a="$1" b="$2" w="${3:-1}"
  paste <(sort <<<"$a") <(sort <<<"$b") |
    awk -v w="$w" 'NF == 4 && $1 == $3 { printf "%s %.1f%%\n", $1, ($4 - $2) / (10.0 * w) }'
}

# Pure: max %util number from "name <pct>%" lines (empty input -> 0.0).
crosscheck_max_util() {
  awk '{ gsub(/%/, "", $2); if (NR == 1 || ($2 + 0) > (m + 0)) m = $2 } END { printf "%.1f", m + 0 }'
}

# One "name io_ticks" line per matching block device. Same device-family glob
# as deploy.sh's pressure gate (sd*|nvme*n*|vd*; zram excluded, its io_ticks
# are RAM-backed and meaningless as %util).
crosscheck_snapshot_io_ticks() {
  local d base
  for d in "$CROSSCHECK_SYS_BLOCK"/sd* "$CROSSCHECK_SYS_BLOCK"/nvme*n* "$CROSSCHECK_SYS_BLOCK"/vd*; do
    if [ -e "$d/stat" ]; then
      base="${d##*/}"
      awk -v n="$base" '{ printf "%s %s\n", n, $10 }' "$d/stat" 2>/dev/null
    fi
  done
  return 0
}

# Stream "avg10 cgroup/relative/path" lines for every readable io.pressure
# under the cgroup root, EXCLUDING the root cgroup's own file (it aggregates
# the whole system, which the PSI line already carries). Malformed or vanished
# files are skipped. Caller pipes through sort -rn | head -N.
crosscheck_rank_cgroups_stream() {
  local f v
  timeout 15 find "$CROSSCHECK_CGROUP" -name io.pressure -print0 2>/dev/null |
    while IFS= read -r -d "" f; do
      if [ "$f" = "$CROSSCHECK_CGROUP/io.pressure" ]; then
        continue
      fi
      v="$(awk '/^some/ { split($2, a, "="); print a[2]; exit }' "$f" 2>/dev/null)"
      if [ -n "$v" ]; then
        local rel="${f#"$CROSSCHECK_CGROUP"/}"
        printf '%s %s\n' "$v" "${rel%/io.pressure}"
      fi
    done
  return 0
}

gate_mode() {
  local w="$CROSSCHECK_WINDOW_S"
  local snap_a snap_b util_lines cg_lines
  snap_a="$(crosscheck_snapshot_io_ticks)"
  sleep "$w"
  snap_b="$(crosscheck_snapshot_io_ticks)"
  util_lines="$(crosscheck_util_lines "$snap_a" "$snap_b" "$w")"
  cg_lines="$(crosscheck_rank_cgroups_stream | sort -rn | head -3)"

  echo "per-device %util (${w}s io_ticks window, max $(crosscheck_max_util <<<"$util_lines")%):"
  if [ -n "$util_lines" ]; then
    printf '%s\n' "$util_lines" | sed 's/^/  /'
  else
    echo "  (no block devices found under $CROSSCHECK_SYS_BLOCK)"
  fi
  echo "top-3 stalled cgroups (io.pressure some avg10):"
  if [ -n "$cg_lines" ]; then
    printf '%s\n' "$cg_lines" | awk '{ printf "  %6.1f%%  %s\n", $1, substr($0, index($0, " ") + 1) }'
  else
    echo "  (no readable io.pressure under $CROSSCHECK_CGROUP, cgroup v1?)"
  fi
}

# The PSI-vs-iostat divergence probe (source report §f.8): the full evidence
# set that classified the 2026-10-13 signature, one read-only pass. Bounded
# ~15s total; every section degrades to a note instead of failing.
full_mode() {
  echo "PSI now:"
  awk '/^some|^full/ { printf "  io %-5s\n", $0 }' /proc/pressure/io 2>/dev/null
  awk '/^some|^full/ { printf "  mem %-4s\n", $0 }' /proc/pressure/memory 2>/dev/null

  echo "zram ops (io_stat fields 1+5 delta over 5s):"
  if [ -e /sys/block/zram0/io_stat ]; then
    local zr_a zr_b
    zr_a="$(awk '{ print $1 + $5 }' /sys/block/zram0/io_stat 2>/dev/null)"
    sleep 5
    zr_b="$(awk '{ print $1 + $5 }' /sys/block/zram0/io_stat 2>/dev/null)"
    awk -v a="${zr_a:-0}" -v b="${zr_b:-0}" 'BEGIN { printf "  %.1f ops/s\n", (b - a) / 5.0 }'
  else
    echo "  (no /sys/block/zram0/io_stat)"
  fi

  echo "io.cost state (empty qos = throttling not configured):"
  local d qos
  for d in "$CROSSCHECK_SYS_BLOCK"/sd* "$CROSSCHECK_SYS_BLOCK"/nvme*n*; do
    if [ -e "$d/io.cost.qos" ]; then
      qos="$(cat "$d/io.cost.qos" 2>/dev/null)"
      echo "  ${d##*/}: qos=${qos:-<unreadable>}"
    fi
  done

  echo "D-state tasks (wchan; kernel threads included):"
  local dst
  dst="$(ps -eo pid,stat,wchan:32,comm --no-headers 2>/dev/null | awk '$2 ~ /^D/ { print }')"
  if [ -n "$dst" ]; then
    printf '%s\n' "$dst" | sed 's/^/  /'
  else
    echo "  (none at sample instant)"
  fi

  echo "top-8 stalled cgroups (io.pressure some avg10):"
  crosscheck_rank_cgroups_stream | sort -rn | head -8 |
    awk '{ printf "  %6.1f%%  %s\n", $1, substr($0, index($0, " ") + 1) }'

  echo "per-pid read+write deltas over 6s (writers above 1 MB/s matter):"
  local io_a io_b
  io_a="$(mktemp)"
  io_b="$(mktemp)"
  for f in "$CROSSCHECK_PROC"/[0-9]*/io; do
    pid="${f%/io}"; pid="${pid##*/}"
    bytes="$(awk '$1 ~ /^read_bytes:$/ || $1 ~ /^write_bytes:$/ { t += $2 } END { print t + 0 }' "$f" 2>/dev/null)"
    if [ -n "$bytes" ]; then
      echo "$bytes $pid"
    fi
  done >"$io_a"
  sleep 6
  for f in "$CROSSCHECK_PROC"/[0-9]*/io; do
    pid="${f%/io}"; pid="${pid##*/}"
    bytes="$(awk '$1 ~ /^read_bytes:$/ || $1 ~ /^write_bytes:$/ { t += $2 } END { print t + 0 }' "$f" 2>/dev/null)"
    if [ -n "$bytes" ]; then
      echo "$bytes $pid"
    fi
  done >"$io_b"
  join -j 2 <(sort -k2 "$io_a") <(sort -k2 "$io_b") 2>/dev/null |
    awk '{ d = $3 - $2; if (d / 6.0 > 1048576.0) printf "  %8.1f MB/s  pid %s\n", d / 6.0 / 1048576.0, $1 }' |
    sort -rn
  rm -f "$io_a" "$io_b"
}

selftest() {
  local deploy_sh="${1:-}"
  local tmp fails=0
  tmp="$(mktemp -d)"

  # 1. util math: known io_ticks deltas through the pure helper.
  local out
  out="$(crosscheck_util_lines "$(printf 'sda 1000\n')" "$(printf 'sda 1004\n')" 1)"
  if [ "$out" != "sda 0.4%" ]; then echo "FAIL util 4-tick delta: '$out'"; fails=$((fails + 1)); fi
  out="$(crosscheck_util_lines "$(printf 'nvme0n1 50000\n')" "$(printf 'nvme0n1 51000\n')" 1)"
  if [ "$out" != "nvme0n1 100.0%" ]; then echo "FAIL util saturated: '$out'"; fails=$((fails + 1)); fi
  out="$(crosscheck_util_lines "$(printf 'sda 7\n')" "$(printf 'sda 7\n')" 1)"
  if [ "$out" != "sda 0.0%" ]; then echo "FAIL util zero delta: '$out'"; fails=$((fails + 1)); fi
  out="$(crosscheck_util_lines "$(printf 'sda 0\n')" "$(printf 'sda 40\n')" 2)"
  if [ "$out" != "sda 2.0%" ]; then echo "FAIL util 2s window: '$out'"; fails=$((fails + 1)); fi
  out="$(crosscheck_util_lines "$(printf 'sda 0\nsdb 5\n')" "$(printf 'sda 4\n')" 1)"
  if [ "$out" != "sda 0.4%" ]; then echo "FAIL util vanished device dropped: '$out'"; fails=$((fails + 1)); fi

  # 2. max util.
  out="$(printf 'sda 0.4%%\nnvme0n1 12.5%%\n' | crosscheck_max_util)"
  if [ "$out" != "12.5" ]; then echo "FAIL max util: '$out'"; fails=$((fails + 1)); fi
  out="$(printf '' | crosscheck_max_util)"
  if [ "$out" != "0.0" ]; then echo "FAIL max util empty: '$out'"; fails=$((fails + 1)); fi

  # 3. fixture cgroup tree: ranking, root exclusion, decimal order, malformed skip.
  local cgt
  cgt="$tmp/cgroup"
  mkdir -p \
    "$cgt" \
    "$cgt/user.slice/user-1000.slice/user@1000.service/app.slice/app-niri-ghostty-5342.scope" \
    "$cgt/user.slice/user-1000.slice/user@1000.service/app.slice/app-niri-ghostty-5335.scope" \
    "$cgt/system.slice/low-stall.service" \
    "$cgt/system.slice/malformed.service" \
    "$cgt/system.slice/decimal-a.service" \
    "$cgt/system.slice/decimal-b.service"
  printf 'some avg10=99.99 avg60=0.00 avg300=0.00 total=0\nfull avg10=0.00\n' >"$cgt/io.pressure"
  printf 'some avg10=89.58 avg60=80.00 avg300=61.00 total=0\nfull avg10=0.00\n' >"$cgt/user.slice/user-1000.slice/user@1000.service/app.slice/app-niri-ghostty-5342.scope/io.pressure"
  printf 'some avg10=83.30 avg60=70.00 avg300=55.00 total=0\nfull avg10=0.00\n' >"$cgt/user.slice/user-1000.slice/user@1000.service/app.slice/app-niri-ghostty-5335.scope/io.pressure"
  printf 'some avg10=10.20 avg60=0.00 avg300=0.00 total=0\n' >"$cgt/system.slice/decimal-a.service/io.pressure"
  printf 'some avg10=9.80 avg60=0.00 avg300=0.00 total=0\n' >"$cgt/system.slice/decimal-b.service/io.pressure"
  printf 'some avg10=1.00 avg60=0.00 avg300=0.00 total=0\n' >"$cgt/system.slice/low-stall.service/io.pressure"
  printf 'garbage without a some line\n' >"$cgt/system.slice/malformed.service/io.pressure"
  local saved_cg="${CROSSCHECK_CGROUP}"
  CROSSCHECK_CGROUP="$cgt"
  out="$(crosscheck_rank_cgroups_stream | sort -rn | head -3)"
  CROSSCHECK_CGROUP="$saved_cg"
  local expected
  expected="$(printf '89.58 user.slice/user-1000.slice/user@1000.service/app.slice/app-niri-ghostty-5342.scope\n83.30 user.slice/user-1000.slice/user@1000.service/app.slice/app-niri-ghostty-5335.scope\n10.20 system.slice/decimal-a.service')"
  if [ "$out" != "$expected" ]; then
    echo "FAIL cgroup ranking: got '$out'"
    fails=$((fails + 1))
  fi

  # 4. empty fixtures: evidence mode degrades to placeholder lines, exit 0.
  mkdir -p "$tmp/empty/sys/block" "$tmp/empty/cg"
  out="$(
    CROSSCHECK_SYS_BLOCK="$tmp/empty/sys/block" \
      CROSSCHECK_CGROUP="$tmp/empty/cg" \
      CROSSCHECK_WINDOW_S=0 \
      bash "${BASH_SOURCE[0]}" gate
  )"
  if ! grep -q "no block devices found" <<<"$out"; then echo "FAIL empty devices note"; fails=$((fails + 1)); fi
  if ! grep -q "no readable io.pressure" <<<"$out"; then echo "FAIL empty cgroups note"; fails=$((fails + 1)); fi

  # 5. end-to-end gate mode against a mutating fixture stat: the background
  # mutator bumps sda's io_ticks mid-window so the snapshot pair yields 0.4%.
  mkdir -p "$tmp/sys/block/sda" "$tmp/endsys/cg"
  printf '1 2 3 4 5 6 7 8 9 1000 11\n' >"$tmp/sys/block/sda/stat"
  (
    sleep 0.3
    printf '1 2 3 4 5 6 7 8 9 1004 11\n' >"$tmp/sys/block/sda/stat"
  ) &
  out="$(
    CROSSCHECK_SYS_BLOCK="$tmp/sys/block" \
      CROSSCHECK_CGROUP="$tmp/endsys/cg" \
      CROSSCHECK_WINDOW_S=1 \
      bash "${BASH_SOURCE[0]}" gate
  )"
  if ! grep -q "sda 0.4%" <<<"$out"; then echo "FAIL e2e fixture delta: $out"; fails=$((fails + 1)); fi
  wait

  # 6. static tripwire: deploy.sh must still wire the crosscheck beside the
  # PSI refusal line (a deleted call would go phantom-green otherwise).
  if [ -n "$deploy_sh" ]; then
    if ! grep -q 'io-psi-crosscheck.sh' "$deploy_sh"; then
      echo "FAIL deploy.sh no longer wires the device-truth crosscheck"
      fails=$((fails + 1))
    fi
  fi

  if [ "$fails" -gt 0 ]; then
    rm -rf "$tmp"
    echo "io-psi-crosscheck selftest: $fails failure(s)"
    return 1
  fi
  rm -rf "$tmp"
  echo "io-psi-crosscheck selftest: OK"
  return 0
}

case "$MODE" in
  gate) gate_mode ;;
  full) full_mode ;;
  selftest) shift || true; selftest "${1:-}" ;;
  *)
    echo "usage: io-psi-crosscheck.sh [gate|full|selftest [deploy.sh]]" >&2
    exit 1
    ;;
esac
exit 0
