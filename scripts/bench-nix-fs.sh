#!/usr/bin/env bash
# bench-nix-fs.sh — head-to-head filesystem comparison for the /nix store role.
#
# Tests ext4 vs XFS(reflink) vs BTRFS(zstd) on a blank disk with THREE
# nix-representative workloads:
#   A. fio file-based: 4K randread QD1/QD32, 4K randwrite, fsync-per-write
#      (exec-path reads; nix-db sqlite fsyncs)
#   B. metadata burst: create 20k deterministic small files (4K-132K, like
#      store-path outputs), read them all, delete them all — timed (builds, GC)
#   C. real content: rsync a fixed sample of real /nix/store paths onto each
#      fs — copy time + ON-DISK usage (measures zstd compression reality)
#
# Usage: bench-nix-fs.sh [device]     (default /dev/nvme0n1 — the blank Samsung)
# DESTRUCTIVE to the target device. Refuses mounted devices.
set -euo pipefail

DEVICE="${1:-/dev/nvme0n1}"
MNT=/mnt/nixfs-bench
FIO=/nix/store/gpvq80c0ai5df2b8gaqbb4bfmbq8n4nk-fio-3.42/bin/fio
RESULT=/tmp/nixfs-bench-results.txt
STORE_SAMPLE=/tmp/nixfs-store-sample.dirs

[ -x "$FIO" ] || FIO="$(nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake "git+file:///home/lars/projects/SystemNix"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.fio' 2>/dev/null)/bin/fio"
[ -x "$FIO" ] || { echo "FAIL: fio missing at $FIO"; exit 1; }
echo "$FIO" > "/tmp/nixfs-fio-path.$(id -u)"

if [ "$(id -u)" -ne 0 ]; then
  echo "(not root — re-execing via sudo -n)"
  exec sudo -n bash "$0" "$DEVICE"
fi
FIO=$(cat "$(ls /tmp/nixfs-fio-path.* 2>/dev/null | head -1)")
rm -f /tmp/nixfs-fio-path.* 2>/dev/null || true

[ -b "$DEVICE" ] || { echo "FAIL: $DEVICE not a block device"; exit 1; }
case "$DEVICE" in /dev/zram*|/dev/loop*) echo "REFUSING zram/loop"; exit 1 ;; esac
if lsblk -nr -o MOUNTPOINTS "$DEVICE" 2>/dev/null | grep -q '[^[:space:]]'; then
  echo "REFUSING: $DEVICE (or partition) is mounted"; exit 1
fi
for b in mkfs.ext4 mkfs.xfs mkfs.btrfs wipefs mount umount rsync find xargs jq; do
  command -v "$b" >/dev/null || { echo "FAIL: $b not on PATH"; exit 1; }
done

psi() { awk '{printf "PSI io some avg10=%s%", $2}' /proc/pressure/io | sed 's/someavg10=//;s/%//'; }

# Fixed real store-path sample (~1.5G), same for every fs
if [ ! -s "$STORE_SAMPLE" ]; then
  ls /nix/store | shuf -n 60 --random-source=/dev/zero > "$STORE_SAMPLE.tmp"
  : > "$STORE_SAMPLE"
  total=0
  while read -r p; do
    sz=$(du -sk "/nix/store/$p" 2>/dev/null | cut -f1) || continue
    if [ $((total + sz)) -le $((1536 * 1024)) ]; then
      echo "$p" >> "$STORE_SAMPLE"; total=$((total + sz))
    fi
  done < "$STORE_SAMPLE.tmp"
  rm -f "$STORE_SAMPLE.tmp"
fi
SAMPLE_KB=$(du -sk --files0-from=<(sed 's|^|/nix/store/|' "$STORE_SAMPLE") 2>/dev/null | awk '{s+=$1} END{print s}')
echo "### nix-fs benchmark on $DEVICE — store sample: $(wc -l < "$STORE_SAMPLE") paths, $((SAMPLE_KB / 1024)) MiB apparent" | tee "$RESULT"

setup_fs() {
  local fstype="$1"
  wipefs -a "$DEVICE" >/dev/null 2>&1 || true
  mkdir -p "$MNT"
  case "$fstype" in
    ext4)  mkfs.ext4 -F -q -L nixfs "$DEVICE" >/dev/null; mount -o noatime "$DEVICE" "$MNT" ;;
    xfs)   mkfs.xfs -f -m reflink=1 -L nixfs "$DEVICE" >/dev/null; mount -o noatime "$DEVICE" "$MNT" ;;
    btrfs) mkfs.btrfs -f -L nixfs "$DEVICE" >/dev/null; mount -o noatime,compress=zstd,space_cache=v2 "$DEVICE" "$MNT" ;;
  esac
}

teardown_fs() { umount "$MNT" 2>/dev/null || umount -l "$MNT" 2>/dev/null || true; rm -rf "$MNT"; }

fio_test() { # name rw extra...
  local name="$1" rw="$2"; shift 2
  "$FIO" --name="$name" --filename="$MNT/fio.bin" --size=2G --direct=1 \
    --ioengine=io_uring --rw="$rw" --bs=4k --time_based --runtime=12 \
    --group_reporting --output-format=json --output="/tmp/fio-$name.json" "$@" >/dev/null 2>&1
  local iops lat
  iops=$(jq -r '[.jobs[0].read.iops, .jobs[0].write.iops] | map(select(. != null and . > 0)) | .[0] // 0' "/tmp/fio-$name.json")
  lat=$(jq -r '[.jobs[0].read.lat_ns.mean, .jobs[0].write.lat_ns.mean] | map(select(. != null and . > 0)) | .[0] // 0 | . / 1000' "/tmp/fio-$name.json")
  printf '    %-24s %10.0f IOPS %9.1f µs\n' "$name" "$iops" "$lat"
  rm -f "$MNT/fio.bin"
}

metadata_test() {
  local t
  t=$( { cd "$MNT" && time (seq 1 20000 | xargs -P8 -I{} sh -c 'd=$(( $1 / 500 )); mkdir -p m$d; head -c $(( 4096 + ($1 % 32) * 4096 )) /dev/zero > m$d/f$1' _ {} && sync) ; } 2>&1 | awk '/real/ {print $2}')
  printf '    %-24s %s (create 20k files + sync)\n' "metadata create" "$t"
  t=$( { cd "$MNT" && time (find m0* -type f -print0 | xargs -P8 -0 cat > /dev/null) ; } 2>&1 | awk '/real/ {print $2}')
  printf '    %-24s %s (read all)\n' "metadata read" "$t"
  t=$( { time (rm -rf "$MNT"/m0*) ; } 2>&1 | awk '/real/ {print $2}')
  printf '    %-24s %s (delete all)\n' "metadata delete" "$t"
}

store_copy_test() {
  mkdir -p "$MNT/store"
  local t disk_kb
  t=$( { time (rsync -a --files-from="$STORE_SAMPLE" /nix/store/ "$MNT/store/") ; } 2>&1 | awk '/real/ {print $2}')
  disk_kb=$(df -k --output=used "$MNT" | tail -1 | tr -d ' ')
  printf '    %-24s %s (rsync %d MiB) → on-disk: %d MiB (ratio %.2fx)\n' \
    "real store copy" "$t" $((SAMPLE_KB / 1024)) $((disk_kb / 1024)) \
    "$(awk -v a="$SAMPLE_KB" -v d="$disk_kb" 'BEGIN{printf "%.2f", a / d}')"
  rm -rf "$MNT/store"
}

for fs in ext4 xfs btrfs; do
  echo "" | tee -a "$RESULT"
  echo "=== $fs ($(psi)) ===" | tee -a "$RESULT"
  setup_fs "$fs"
  {
    fio_test rr-qd1  randread  --iodepth=1
    fio_test rr-qd32 randread  --iodepth=32
    fio_test rw-qd1  randwrite --iodepth=1
    fio_test fsync   randwrite --iodepth=1 --fsync=1
    metadata_test
    store_copy_test
  } | tee -a "$RESULT"
  teardown_fs
done

echo "" | tee -a "$RESULT"
echo "Done. Full results: $RESULT (device left unformatted — run mkfs of the winner)"
wipefs -a "$DEVICE" >/dev/null 2>&1 || true
