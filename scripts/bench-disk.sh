#!/usr/bin/env bash
# bench-disk.sh — fio benchmark suite for a raw, unmounted block device.
#
# Purpose: characterize a disk BEFORE assigning it a role (the 2026-08-31
# Samsung 970 EVO Plus layout decision: hot-DB XFS partition vs BTRFS nix
# store partition). Measures the three things that matter for role choice:
#   1. 4K random read/write latency at QD1 (nix store cold reads, cache hits)
#   2. 4K random read at QD32 (parallel build / scrub headroom)
#   3. fsync-per-write latency (SQLite/PG WAL commits — the dominant pain
#      on the QLC root fs, measured 2026-08-31 at ~200ms/fsync under load)
#   4. 1M sequential read/write (bulk: nix store rsync, snapshot sends)
#
# Usage:
#   scripts/bench-disk.sh [device]        # default /dev/nvme0n1
#   RUNTIME=30 scripts/bench-disk.sh ...  # longer runs
#
# Re-execs itself via `sudo -n` (non-interactive) when not root — raw-device
# fio needs root. If sudo requires a password, run: sudo scripts/bench-disk.sh
#
# Safety: REFUSES to run against any device (or partition of it) that is
# mounted, and warns about zram/loop devices. Writes ARE destructive to the
# raw device content — only point it at blank/scratch disks.
set -euo pipefail

DEVICE="${1:-/dev/nvme0n1}"
RUNTIME="${RUNTIME:-15}"
FIO="${FIO:-/nix/store/gpvq80c0ai5df2b8gaqbb4bfmbq8n4nk-fio-3.42/bin/fio}"
[ -x "$FIO" ] || FIO="$(command -v fio || true)"
[ -n "$FIO" ] || {
  echo "FAIL: fio not found (set FIO=/path/to/fio)"
  exit 1
}
command -v jq >/dev/null || {
  echo "FAIL: jq required for result parsing"
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  echo "(not root — re-execing via sudo -n)"
  exec sudo -n bash "$0" "$DEVICE"
fi

[ -b "$DEVICE" ] || {
  echo "FAIL: $DEVICE is not a block device"
  exit 1
}
case "$DEVICE" in
/dev/zram* | /dev/loop*)
  echo "REFUSING: $DEVICE is zram/loop"
  exit 1
  ;;
esac
if lsblk -nr -o MOUNTPOINTS "$DEVICE" 2>/dev/null | grep -q '[^[:space:]]'; then
  echo "REFUSING: $DEVICE (or a partition of it) is mounted — destructive test"
  exit 1
fi
SIZE=$(lsblk -nrno SIZE "$DEVICE")
echo "### Benchmarking $DEVICE ($SIZE) with $FIO, ${RUNTIME}s per test"
echo

TMPDIR_BENCH="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BENCH"' EXIT

run_test() { # <name> <rw> <extra fio args...>
  local name="$1" rw="$2"
  shift 2
  "$FIO" --name="$name" --filename="$DEVICE" --direct=1 --ioengine=io_uring \
    --rw="$rw" --time_based --runtime="$RUNTIME" --group_reporting \
    --output-format=json --output="$TMPDIR_BENCH/$name.json" "$@" \
    >/dev/null 2>&1
}

run_test rr1 randread --bs=4k --iodepth=1
run_test rw1 randwrite --bs=4k --iodepth=1
run_test rr32 randread --bs=4k --iodepth=32
run_test fs1 randwrite --bs=4k --iodepth=1 --fsync=1
run_test sr read --bs=1m --iodepth=1
run_test sw write --bs=1m --iodepth=1

# jq: pick read or write side by which has iops>0; lat_ns.mean is in ns
metric() { # <file> <iops|lat_us|bw_mibs>
  local f="$TMPDIR_BENCH/$1.json" m="$2"
  case "$m" in
  iops) jq -r '[.jobs[0].read.iops, .jobs[0].write.iops] | map(select(. != null and . > 0)) | .[0] // 0' "$f" ;;
  lat_us) jq -r '[.jobs[0].read.lat_ns.mean, .jobs[0].write.lat_ns.mean] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1000' "$f" ;;
  bw_mibs) jq -r '[.jobs[0].read.bw_bytes, .jobs[0].write.bw_bytes] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1048576' "$f" ;;
  esac
}

fsync_lat_us() {
  jq -r '.jobs[0].sync.lat_ns.mean // 0 | . / 1000' "$TMPDIR_BENCH/fs1.json"
}

printf '%-28s %12s %12s %12s\n' "TEST" "IOPS" "avg lat" "BW"
printf '%-28s %12s %12s %12s\n' "----" "----" "-------" "--"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randread QD1" "$(metric rr1 iops)" "$(metric rr1 lat_us)" "$(metric rr1 bw_mibs)"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randwrite QD1" "$(metric rw1 iops)" "$(metric rw1 lat_us)" "$(metric rw1 bw_mibs)"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randread QD32" "$(metric rr32 iops)" "$(metric rr32 lat_us)" "$(metric rr32 bw_mibs)"
printf '%-28s %12.0f %10.1fµs %9.0fMiB/s\n' "4K randwrite+fsync QD1" "$(metric fs1 iops)" "$(metric fs1 lat_us)" "$(metric fs1 bw_mibs)"
printf '%-28s %12s %10.1fµs %9s\n' "  fsync (sync) latency" "" "$(fsync_lat_us)" ""
printf '%-28s %12s %12s %10.0fMiB/s\n' "1M seq read" "" "" "$(metric sr bw_mibs)"
printf '%-28s %12s %12s %10.0fMiB/s\n' "1M seq write" "" "" "$(metric sw bw_mibs)"
echo
echo "Raw JSON kept in $TMPDIR_BENCH until script exit; rerun a single test with:"
echo "  $FIO --name=t --filename=$DEVICE --direct=1 --ioengine=io_uring --bs=4k --rw=randread --iodepth=1 --time_based --runtime=$RUNTIME"
