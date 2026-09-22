#!/usr/bin/env bash
# Merge BOTH SanDisk SDSSDA240G SSDs into ONE btrfs filesystem at /mnt/buildcache.
# DECIDED 2026-09-22 (user): the ssd-btrfs Docker earmark is DROPPED (never taken
# up — Docker data-root is /data/docker on QLC) and both SSDs merge into one
# logical cache. Supersedes the single-disk ext4→btrfs conversion plan.
# NOT AUTOMATED — run manually in a maintenance window (needs sudo + quiesced
# cache consumers: stop gopls editors, wait for nix builds to finish).
#
# Why btrfs multi-device:
#   - One mountpoint, two devices: ~447G raw. `-d single` spreads data chunks
#     and keeps devices add/remove-able online later; `-m raid1` (btrfs default
#     on 2 devices) keeps the fs mountable-degraded if one SSD dies. A cache is
#     rebuildable, so no data-profile redundancy beyond metadata.
#   - zstd:1: rust debuginfo + Go objects/DWARF compress ~2-2.5x → ~4x effective
#     capacity vs today's 220G ext4 (84% full; rust targets alone = 121G).
#   - Checksums: the SandForce SF-2000 has no PLP and a dirty-shutdown history;
#     on ext4+data=writeback a corrupted cache object is served SILENTLY (Go
#     catches go-build via content hashes; cargo does NOT). On btrfs a torn
#     write = checksum error = EIO = cache miss = rebuild.
#   - XFS rejected: no transparent compression (btrfs/ZFS/f2fs are the only
#     mainline options; ZFS was already rejected on this box — txg-sync stalls).
#   - Failure domain unchanged: both SSDs already share ONE USB link + JMS567
#     enclosure — a link drop already takes out both simultaneously.
#   - Tradeoff accepted: ~2x higher random-I/O latency than ext4 on this drive
#     (234us vs 503us measured 2026-08-14) — cache hits are still >> cold builds.
#
# What is KEPT: go-mod (private repo modules are slow to re-fetch; 240M toolchain
# modules also live there). Everything else repopulates on demand — expect cold
# rust builds (121G of target/ dirs) + sccache misses for a few days.
#
# The module change must be deployed TOGETHER with the reformat (step 7):
# flip buildcache.nix (fsType/options + recovery findmnt) BEFORE `nix run .#deploy`,
# or the fstab mount fails.
set -euo pipefail

DISK1="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1" # current ext4 buildcache
DISK2="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1" # btrfs ssd-btrfs (Docker earmark dropped 2026-09-22)
MOUNT="/mnt/buildcache"
STAGE="/var/tmp/buildcache-stage" # disk-backed (/tmp is tmpfs=RAM — staging must not eat RAM)

echo "This REFORMATS BOTH devices into one btrfs fs — everything on them is"
echo "rebuildable cache except go-mod, which is staged and restored."
read -rp "Maintenance window confirmed, no builds/gopls running? Type 'yes': " answer
[ "$answer" = "yes" ] || {
  echo "aborted"
  exit 1
}

for bin in lsblk mkfs.btrfs rsync btrfs; do
  command -v "$bin" >/dev/null || {
    echo "FAIL: $bin not on PATH — resolve before stopping anything"
    exit 1
  }
done

# Content gates: refuse to wipe anything that is not the exact device+role.
# (a wrong DEVICE, a device that flipped to another role, or a future
# repurposing must never reach mkfs silently)
D1_FS=$(lsblk -nrno FSTYPE "$DISK1" 2>/dev/null || true)
D1_LB=$(lsblk -nrno LABEL "$DISK1" 2>/dev/null || true)
if [ "$D1_FS" != "ext4" ] || [ "$D1_LB" != "buildcache" ]; then
  echo "REFUSING: $DISK1 is fstype='$D1_FS' label='$D1_LB' —"
  echo "expected ext4 + label 'buildcache'. If the device role changed, edit"
  echo "DISK1 at the top of this script deliberately."
  exit 1
fi
D2_FS=$(lsblk -nrno FSTYPE "$DISK2" 2>/dev/null || true)
D2_LB=$(lsblk -nrno LABEL "$DISK2" 2>/dev/null || true)
D2_MNT=$(lsblk -nrno MOUNTPOINTS "$DISK2" 2>/dev/null || true)
if [ "$D2_FS" != "btrfs" ] || [ "$D2_LB" != "ssd-btrfs" ]; then
  echo "REFUSING: $DISK2 is fstype='$D2_FS' label='$D2_LB' —"
  echo "expected btrfs + label 'ssd-btrfs'. If its role changed since the"
  echo "2026-09-22 earmark drop, edit DISK2 at the top of this script deliberately."
  exit 1
fi
if [ -n "$D2_MNT" ]; then
  echo "REFUSING: $DISK2 is mounted: $D2_MNT — unmount before merging."
  exit 1
fi

sudo mkdir -p "$STAGE"

echo "1/8 Staging go-mod (private deps)..."
sudo rsync -a --delete "$MOUNT/go-mod/" "$STAGE/go-mod/"

echo "2/8 Unmounting $MOUNT..."
sudo umount "$MOUNT" 2>/dev/null || sudo systemctl stop mnt-buildcache.automount mnt-buildcache.mount

echo "3/8 Formatting BOTH devices as one btrfs fs (data single, metadata raid1)..."
sudo mkfs.btrfs -L buildcache -d single -m raid1 "$DISK1" "$DISK2"

echo "4/8 Mounting..."
sudo mount -t btrfs -o compress=zstd:1,noatime "$DISK1" "$MOUNT"
sudo mkdir -p "$MOUNT/go-mod"

echo "5/8 Restoring go-mod..."
sudo rsync -a "$STAGE/go-mod/" "$MOUNT/go-mod/"

echo "6/8 Verifying filesystem..."
sudo btrfs filesystem df "$MOUNT"

echo "7/8 Done mounting-wise. Now update modules/nixos/services/buildcache.nix:"
echo '    fsType = "btrfs";'
echo '    options = [ "noatime" "compress=zstd:1" "space_cache=v2" "commit=120"'
echo '               "nofail" "x-systemd.automount" "x-systemd.device-timeout=2s"'
echo '               "x-systemd.device-bound" ];'
echo "  (drop: lazytime — btrfs always lazytimes; data=writeback — n/a. NO"
echo "   autodefrag: it amplifies writes on flash. Keep device-timeout=2s +"
echo "   device-bound exactly as today. Mounting stays via DISK1's by-id path —"
echo "   btrfs auto-assembles multi-device members; the pool mounts by-label"
echo "   through the same bridge. Also update: the description option, the mkfs"
echo "   comment at the top, and the two recovery-unit 'findmnt -n -t ext4'"
echo "   calls → -t btrfs.)"
echo "  Then deploy in the SAME window: nix run .#deploy"

echo "8/8 Cleanup after verified deploy: sudo rm -rf $STAGE"
