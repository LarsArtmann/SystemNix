#!/usr/bin/env bash
# Convert the build cache SSD from ext4 to btrfs with zstd compression.
# NOT AUTOMATED — run manually in a maintenance window (needs sudo + quiesced
# cache consumers: stop gopls editors, wait for nix builds to finish).
#
# Why btrfs over ext4 here (full analysis: docs/planning/2026-08-15_21-23_SMART-BUILDCACHE-OVERHAUL.md):
#   - zstd:1 compression: Go objects/DWARF + rust debuginfo compress ~2-2.5x
#     → ~2x effective capacity on a 220G drive
#   - Checksums: the SandForce SF-2000 has no PLP and 34 dirty shutdowns; on
#     ext4+data=writeback a corrupted cache object is served SILENTLY (Go
#     catches go-build via content hashes; cargo does NOT). On btrfs, a torn
#     write becomes a checksum error = EIO = cache miss = rebuild.
#   - Tradeoff accepted: ~2x higher random-I/O latency than ext4 on this drive
#     (234us vs 503us measured 2026-08-14) — cache hits are still >> cold builds.
#
# What is KEPT: go-mod (private repo modules are slow to re-fetch; 240M toolchain
# modules also live there). Everything else repopulates on demand.
#
# The module change (fsType + options) must be deployed TOGETHER with the
# reformat: flip buildcache.nix fsType to "btrfs" and options to the list in
# step 6 BEFORE running `nix run .#deploy` again, or the mount will fail.
set -euo pipefail

DEVICE="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1"
MOUNT="/mnt/buildcache"
STAGE="/var/tmp/buildcache-stage" # disk-backed (/tmp is tmpfs=RAM — 9G staging must not eat RAM)

echo "This REFORMATS $DEVICE — everything on it is rebuildable cache."
read -rp "Maintenance window confirmed, no builds/gopls running? Type 'yes': " answer
[ "$answer" = "yes" ] || {
  echo "aborted"
  exit 1
}

sudo mkdir -p "$STAGE"
echo "1/7 Staging go-mod (private deps, ~9G)..."
sudo rsync -a --delete "$MOUNT/go-mod/" "$STAGE/go-mod/"

echo "2/7 Unmounting..."
sudo umount "$MOUNT" || sudo systemctl stop mnt-buildcache.automount mnt-buildcache.mount

echo "3/7 Formatting btrfs (single device, zstd via mount option)..."
sudo mkfs.btrfs -L buildcache -m single -d single "$DEVICE"

echo "4/7 Temporarily mounting..."
sudo mount -t btrfs -o compress=zstd:1,noatime "$DEVICE" "$MOUNT"
sudo mkdir -p "$MOUNT/go-mod"

echo "5/7 Restoring go-mod..."
sudo rsync -a "$STAGE/go-mod/" "$MOUNT/go-mod/"

echo "6/7 Done mounting-wise. Now update modules/nixos/services/buildcache.nix:"
echo '    fsType = "btrfs";'
echo '    options = [ "compress=zstd:1" "noatime" "space_cache=v2" "autodefrag"'
echo '               "nofail" "x-systemd.automount" "x-systemd.device-timeout=10s" ];'
echo "  (drop: lazytime — btrfs always lazytimes; data=writeback/commit — btrfs commits differ)"
echo "  Then deploy: nix run .#deploy"

echo "7/7 Cleanup after verified deploy: sudo rm -rf $STAGE"
