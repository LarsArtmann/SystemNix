#!/usr/bin/env bash
# bench-samsung-livefs.sh — quiet-window-gated, file-based Samsung 970 EVO Plus
# re-bench against the 2026-08-31 raw-device baseline (scripts/bench-disk.sh).
#
# Why file-based: bench-disk.sh REFUSES mounted devices (correctly) and the
# Samsung now hosts /nix — raw-device benching is impossible on the live disk.
# Raw-equivalence: NOCOW (+C) scratch file on btrfs = no CoW, no compression,
# no checksums; seq-write prefilled (fallocate leaves holes -> reads hit holes
# -> fake IOPS; 2026-10-16 lesson).
#
# Gate discipline: refuses to run unless io PSI some<5 AND full<3 for 6
# consecutive 5s samples (30s sustained TRUE quiet). NEVER "times out and runs
# anyway" — the 2026-10-16 storm-contaminated run produced numbers 2.5-9x under
# baseline (QD32 inversion = host-side queueing signature), which is worse than
# no numbers. The original some<20/full<15 gate fired on a load-wave tail
# (2026-10-17 19:25, some=19.82) and STILL contaminated rr1 (122.9µs vs 27.8µs
# baseline, 4.4x); live probes showed rr1 clusters 8-13k IOPS across PSI 20-72,
# so only TRUE quiet settles floor-vs-contamination. The 2026-10-16 session
# burned three gate windows (55m/120m/180m) under a 5.5h+ concurrent-session
# Go-build storm; default patience is now 24h.
#
# Method caveats vs the raw baseline (printed with results too):
#   - fsync test measures btrfs+device via the file (raw baseline bypassed fs)
#   - 3G working set: QD32 randread cycles it ~8x per 20s test -> DRAM/SLC
#     cache serving inflates QD32 vs the full-disk raw run
#
# Contamination proxies: per-test io_ticks delta of the OTHER internal NVMe
# (the QLC — historic storm target), temp sampling every 2s (heatsink verdict),
# rr1-latency post-hoc sanity (2.5x baseline = contaminated).
#
# Usage:   scripts/bench-samsung-livefs.sh           # waits up to 24h
#          MAX_WAIT_MIN=5 scripts/bench-samsung-livefs.sh
# Output:  /home/lars/.cache/nix/bench-v3/ (run.log, *.json, temps.log,
#          COMPLETE-stamp on success — other sessions can poll that stamp)
set -euo pipefail

RUNTIME="${RUNTIME:-20}"
SCRATCH_SIZE="${SCRATCH_SIZE:-3G}"
MAX_WAIT_MIN="${MAX_WAIT_MIN:-1440}"
BASE=/home/lars/.cache/nix/bench-v3
LOG="$BASE/run.log"

mkdir -p "$BASE"
exec > >(tee -a "$LOG") 2>&1
echo "=== Samsung live-FS re-bench — $(date -Is) ==="

# --- fio resolution: env -> known store paths -> PATH -> flake-locked build.
# The store paths are GC-able (bit us 2026-10-16 AND overnight into 2026-10-17);
# the flake-locked fallback is cache-substituted in seconds.
FIO="${FIO:-}"
if [ -z "$FIO" ]; then
  for cand in /nix/store/c0crr6i6gl1amh50d2xkb9ip69g0k0z8-fio-3.42/bin/fio \
    /nix/store/gpvq80c0ai5df2b8gaqbb4bfmbq8n4nk-fio-3.42/bin/fio; do
    [ -x "$cand" ] && FIO="$cand" && break
  done
fi
[ -n "$FIO" ] && [ -x "$FIO" ] || FIO="$(command -v fio || true)"
if [ -z "$FIO" ] || [ ! -x "$FIO" ]; then
  echo "--- rebuilding fio from flake-locked nixpkgs (store paths GC'd again) ---"
  FIO="$(NIX_HEAVY_GATE_FORCE=1 nix build --no-link --print-out-paths --impure \
    --expr 'let f = builtins.getFlake "git+file:///home/lars/projects/SystemNix"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.fio' 2>/dev/null)/bin/fio"
fi
[ -n "$FIO" ] && [ -x "$FIO" ] || {
  echo "FAIL: fio unresolvable"
  exit 1
}
command -v jq >/dev/null || {
  echo "FAIL: jq missing"
  exit 1
}
echo "fio: $FIO"

# --- resolve Samsung hwmon + the other internal NVMe (QLC) by model ---
# (nvme0/nvme1 enumeration FLIPS across boots on this box — never hardcode)
HWMON=""
QLC_DISK=""
for d in /sys/class/nvme/nvme[0-9]*; do
  if grep -q "970 EVO Plus" "$(readlink -f "$d")/model" 2>/dev/null; then
    for h in /sys/class/hwmon/hwmon*; do
      [ "$(readlink -f "$h/device" 2>/dev/null)" = "$(readlink -f "$d")" ] && HWMON="$h"
    done
  else
    QLC_DISK="$(basename "$d")"
  fi
done
[ -n "$HWMON" ] && [ -n "$QLC_DISK" ] || {
  echo "FAIL: device resolution (hwmon=$HWMON qlc=$QLC_DISK)"
  exit 1
}
temp_read() { cat "$HWMON/temp1_input"; }
qlc_ticks() { awk -v d="$QLC_DISK" '$3==d{print $13}' /proc/diskstats; }
echo "Samsung hwmon=$HWMON temp=$(temp_read)mC | other-NVMe proxy=$QLC_DISK"

# --- scratch: NOCOW dir+file, seq-write prefilled ---
chattr +C "$BASE" 2>/dev/null || true
FILE="$BASE/fio.bin"
touch "$FILE"
chattr +C "$FILE" 2>/dev/null || true
lsattr "$FILE" | grep -q 'C' || {
  echo "FAIL: +C not set on scratch ($(lsattr "$FILE"))"
  exit 1
}
echo "--- prefill $SCRATCH_SIZE (seq write, direct — also a datapoint: seq-write BW) ---"
"$FIO" --name=prefill --filename="$FILE" --direct=1 --ioengine=io_uring \
  --rw=write --bs=1m --size="$SCRATCH_SIZE" --group_reporting 2>&1 | grep -E '^  write:|^  WRITE:' | head -2
sync

psi_some() { awk '$1=="some"{gsub("avg10=","",$2); print $2}' /proc/pressure/io; }
psi_full() { awk '$1=="full"{gsub("avg10=","",$2); print $2}' /proc/pressure/io; }

# --- PSI gate: some<5 AND full<3 (TRUE quiet), 6 consecutive 5s samples; heartbeat 60s ---
gate=0
waited=0
beats=0
deadline=$(($(date +%s) + MAX_WAIT_MIN * 60))
echo "--- gate: up to ${MAX_WAIT_MIN}min for some<5 full<3 (6x5s); now some=$(psi_some) full=$(psi_full) ---"
while [ "$(date +%s)" -lt "$deadline" ]; do
  s=$(psi_some)
  f=$(psi_full)
  if awk -v s="$s" -v f="$f" 'BEGIN{exit !(s<5 && f<3)}'; then gate=$((gate + 1)); else gate=0; fi
  [ "$gate" -ge 6 ] && break
  waited=$((waited + 5))
  beats=$((beats + 5))
  if [ "$beats" -ge 60 ]; then
    beats=0
    echo "[heartbeat +$((waited / 60))min] some=$s full=$f go_procs=$(pgrep -c go 2>/dev/null || echo 0)"
  fi
  sleep 5
done
if [ "$gate" -lt 3 ]; then
  echo "ABORT: no quiet window in ${MAX_WAIT_MIN}min (last some=$(psi_some) full=$(psi_full)) — refusing contaminated run"
  exit 2
fi
echo "--- QUIET WINDOW at $(date -Is): some=$(psi_some) full=$(psi_full) — starting suite ---"

# --- temp sampler + QLC busy baseline ---
TLOG="$BASE/temps.log"
: >"$TLOG"
(while :; do
  echo "$(date +%s) $(temp_read)"
  sleep 2
done) &
SAMPLER=$!
# shellcheck source=scripts/lib/process.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/process.sh"
trap 'kill_pid "$SAMPLER"' EXIT
idle_temp=$(temp_read)
t0=$(date +%s%3N)
qlc0=$(qlc_ticks)

run_test() { # <name> <rw> <extra fio args...>
  local name="$1" rw="$2" q0 q1
  shift 2
  q0=$(qlc_ticks)
  echo "  [$name] start $(date +%T)"
  "$FIO" --name="$name" --filename="$FILE" --direct=1 --ioengine=io_uring \
    --rw="$rw" --time_based --runtime="$RUNTIME" --group_reporting \
    --output-format=json --output="$BASE/$name.json" "$@" >/dev/null 2>&1
  q1=$(qlc_ticks)
  echo "    other-NVMe($QLC_DISK) io_ticks during test: $((q1 - q0))ms / ${RUNTIME}s"
}

run_test rr1 randread --bs=4k --iodepth=1
run_test rw1 randwrite --bs=4k --iodepth=1
run_test rr32 randread --bs=4k --iodepth=32
run_test fs1 randwrite --bs=4k --iodepth=1 --fsync=1
run_test sr read --bs=1m --iodepth=1
run_test sw write --bs=1m --iodepth=1

t1=$(date +%s%3N)
qlc1=$(qlc_ticks)
post_temp=$(temp_read)
max_temp=$(awk '{print $2}' "$TLOG" | sort -n | tail -1)
elapsed_ms=$((t1 - t0))
[ "$elapsed_ms" -gt 0 ] || elapsed_ms=1
qlc_busy_pct=$(((qlc1 - qlc0) * 100 / elapsed_ms))

metric() { # <file-stem> <iops|lat_us|bw_mibs>
  local f="$BASE/$1.json" m="$2"
  case "$m" in
  iops) jq -r '[.jobs[0].read.iops, .jobs[0].write.iops] | map(select(. != null and . > 0)) | .[0] // 0' "$f" ;;
  lat_us) jq -r '[.jobs[0].read.lat_ns.mean, .jobs[0].write.lat_ns.mean] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1000' "$f" ;;
  bw_mibs) jq -r '[.jobs[0].read.bw_bytes, .jobs[0].write.bw_bytes] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1048576' "$f" ;;
  esac
}
fsync_lat_us() { jq -r '.jobs[0].sync.lat_ns.mean // 0 | . / 1000' "$BASE/fs1.json"; }

{
  echo
  echo "=== RESULTS ($(date -Is)) ==="
  printf '%-28s %14s %14s %14s\n' "TEST" "IOPS" "avg lat" "BW"
  printf '%-28s %14.0f %12.1fµs %12.0fMiB/s\n' "4K randread QD1" "$(metric rr1 iops)" "$(metric rr1 lat_us)" "$(metric rr1 bw_mibs)"
  printf '%-28s %14.0f %12.1fµs %12.0fMiB/s\n' "4K randwrite QD1" "$(metric rw1 iops)" "$(metric rw1 lat_us)" "$(metric rw1 bw_mibs)"
  printf '%-28s %14.0f %12.1fµs %12.0fMiB/s\n' "4K randread QD32" "$(metric rr32 iops)" "$(metric rr32 lat_us)" "$(metric rr32 bw_mibs)"
  printf '%-28s %14.0f %12.1fµs %12.0fMiB/s\n' "4K randw+fsync QD1" "$(metric fs1 iops)" "$(metric fs1 lat_us)" "$(metric fs1 bw_mibs)"
  printf '%-28s %14s %12.1fµs %14s\n' "  fsync (sync) latency" "" "$(fsync_lat_us)" ""
  printf '%-28s %14s %14s %12.0fMiB/s\n' "1M seq read" "" "" "$(metric sr bw_mibs)"
  printf '%-28s %14s %14s %12.0fMiB/s\n' "1M seq write" "" "" "$(metric sw bw_mibs)"
  echo
  echo "Baseline 2026-08-31 (raw device): rr1 35.3k/27.8µs  rw1 79.2k/12.2µs  rr32 304k/1.19GB/s  fsync 0.78ms  seq 2.4/2.7 GB/s"
  echo "Storm run 2026-10-16 (40-88% PSI): rr1 11.3k/87.8µs  rr32 inverted 11.7k@2.8ms"
  echo "Prefill datapoints 2026-10-16 (mid-storm seq write): 1775 / 2114 / 2213 MiB/s"
  echo
  echo "Caveats vs raw baseline: fs1 fsync goes through btrfs (raw bypassed fs);"
  echo "  $SCRATCH_SIZE working set lets QD32 cycle DRAM/SLC-cached LBAs (inflates QD32)."
  echo "Temps (heatsink verdict): idle=${idle_temp}mC max_during=${max_temp}mC post=${post_temp}mC crit=84850mC"
  echo "Other-NVMe ($QLC_DISK) busy during suite: ${qlc_busy_pct}% (<10% = clean window held)"
  rr1_lat=$(metric rr1 lat_us)
  if awk -v l="$rr1_lat" 'BEGIN{exit !(l>70)}'; then
    echo "WARNING: rr1 lat ${rr1_lat}µs >> 27.8µs baseline — likely contaminated, do NOT record as parity"
  else
    echo "rr1 lat sanity: ${rr1_lat}µs vs 27.8µs baseline — within ~2.5x, clean"
  fi
  echo "DONE $(date -Is)"
} | tee "$BASE/COMPLETE-stamp"

echo "JSON+log kept in $BASE"
