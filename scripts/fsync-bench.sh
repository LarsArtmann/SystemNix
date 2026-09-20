#!/usr/bin/env bash
# fsync-bench — measure synchronous small-write (WAL-commit) latency on a
# DIRECTORY, for the hot-DB tier before/after comparisons.
#
# Why not bench-disk.sh: that one characterizes a RAW device (root, destructive).
# The hot-DB waves (docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md)
# need the DB-shaped number on the LIVE filesystems — fsync-per-write of small
# appends, the SQLite/PG WAL commit shape — on the QLC root (where gatus,
# discordsync, browser-history, inboxclean DBs sit today) vs the Samsung tlc
# filesystem (/mnt/hot, the Phase-2 hot-DB tier), idle AND under a controlled
# write load (the QLC pain is the under-load cliff, not the idle number).
#
# Usage:
#   scripts/fsync-bench.sh <dir>                 # 4K appends + fsync, idle
#   ITERS=500 scripts/fsync-bench.sh <dir>       # more samples
#   scripts/fsync-bench.sh <dir> --nodatacow     # chattr +C the scratch file
#                                                # first (simulates the hot-tier
#                                                # subvol shape; works unprivileged
#                                                # on a user-owned empty file)
#   scripts/fsync-bench.sh <dir> --load          # run a bounded fio 4K randwrite
#                                                # load on the SAME filesystem
#                                                # during the measurement
#   LOAD_RUNTIME=90 ...                          # load duration (default: bench
#                                                # duration + 10s headroom)
#
# Unprivileged by design (agent sessions have no sudo): the scratch file is
# created in <dir> as the invoking user — point it at any user-writable dir on
# the filesystem in question (e.g. /var/tmp for the QLC root `@` subvol,
# /mnt/hot/crush for the Samsung tlc toplevel). It never touches real DBs.
set -euo pipefail

DIR="${1:?usage: fsync-bench.sh <dir> [--nodatacow] [--load]}"
NOCOW=0
LOAD=0
for arg in "$@"; do
  case "$arg" in
  --nodatacow) NOCOW=1 ;;
  --load) LOAD=1 ;;
  esac
done

ITERS="${ITERS:-300}"
BYTES="${BYTES:-4096}"
LOAD_RUNTIME="${LOAD_RUNTIME:-0}"

[ -d "$DIR" ] || { echo "FAIL: $DIR is not a directory" >&2; exit 1; }
[ -w "$DIR" ] || { echo "FAIL: $DIR not writable by $(id -un)" >&2; exit 1; }

command -v python3 >/dev/null || { echo "FAIL: python3 required" >&2; exit 1; }

SCRATCH="$(mktemp "$DIR/.fsync-bench-XXXXXX")"
LOADFILE=""
LOAD_PID=""
cleanup() {
  if [ -n "$LOAD_PID" ]; then
    kill "$LOAD_PID" 2>/dev/null || true
  fi
  if [ -n "$LOADFILE" ]; then
    rm -f "$LOADFILE"
  fi
  rm -f "$SCRATCH"
}
trap cleanup EXIT

if [ "$NOCOW" = "1" ]; then
  chattr +C "$SCRATCH"
  TAG="nodatacow"
else
  TAG="cow"
fi

psi() { awk 'NR==1 {for (i=1; i<=NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); print $i } }' /proc/pressure/io; }

if [ "$LOAD" = "1" ]; then
  FIO="$(command -v fio || true)"
  [ -n "$FIO" ] || FIO="/nix/store/gpvq80c0ai5df2b8gaqbb4bfmbq8n4nk-fio-3.42/bin/fio"
  [ -x "$FIO" ] || { echo "FAIL: fio not found for --load" >&2; exit 1; }
  [ "$LOAD_RUNTIME" -gt 0 ] 2>/dev/null || LOAD_RUNTIME=$((ITERS + 10))
  LOADFILE="$(mktemp "$DIR/.fsync-bench-load-XXXXXX")"
  "$FIO" --name=fsyncbench-load --filename="$LOADFILE" --rw=randwrite --bs=4k \
    --iodepth=8 --direct=1 --time_based --runtime="$LOAD_RUNTIME" \
    --size=256M --output=/dev/null --minimal &
  LOAD_PID=$!
  sleep 3 # let the load spin up before sampling
fi

echo "# fsync-bench dir=$DIR mode=$TAG bytes=$BYTES iters=$ITERS psi_before=$(psi) psi_after=$(psi)"

python3 - "$SCRATCH" "$ITERS" "$BYTES" <<'PY'
import os, sys, time

path, iters, nbytes = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
fd = os.open(path, os.O_WRONLY)
payload = b"x" * nbytes
lat = []
off = 0
for _ in range(iters):
    t0 = time.perf_counter_ns()
    os.lseek(fd, off, os.SEEK_END)
    os.write(fd, payload)
    os.fsync(fd)
    t1 = time.perf_counter_ns()
    lat.append((t1 - t0) / 1e6)  # ms
    off += nbytes
os.close(fd)
lat.sort()

def pct(p):
    return lat[min(len(lat) - 1, int(len(lat) * p))]

mean = sum(lat) / len(lat)
print(f"mean_ms={mean:.3f} p50_ms={pct(0.50):.3f} p90_ms={pct(0.90):.3f} "
      f"p99_ms={pct(0.99):.3f} max_ms={lat[-1]:.3f} fsync_per_s={1000.0/mean:.1f}")
PY

echo "# psi_after=$(psi)"
