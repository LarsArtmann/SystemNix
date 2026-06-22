#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Disk Repartitioning Script for evo-x2 (Lexar SSD NQ790 2TB)
#
# RUN FROM A LIVE USB — the disk must NOT be mounted.
#
# What this does:
#   1. Shrinks p8 (/data) partition boundary from ~1.29 TiB to 1.00 TiB
#      (BTRFS filesystem is already 1.00 TiB — no resize needed)
#   2. Deletes dead partitions: p1 (2G), p3 (31.3G ext4), p5 (4G)
#   3. Deletes swap partition: p2 (10G) — replaced by zramSwap
#   4. Creates p9 (100G ext4, PARTLABEL="rust-cache") for Rust cargo targets
#
# Result:
#   ~215 GiB unallocated at end of disk for future use
#   /data stays at 1.00 TiB (unchanged)
#   /rust-cache gets 100 GiB of ext4 (no COW, no snapshots)
# ═══════════════════════════════════════════════════════════════════════════

DISK="/dev/nvme0n1"

# ── Pre-flight checks ─────────────────────────────────────────────────────

echo "=== Pre-flight checks ==="

# Must NOT be mounted
if findmnt --source "${DISK}p6" >/dev/null 2>&1 || findmnt --source "${DISK}p8" >/dev/null 2>&1; then
  echo "FATAL: Disk partitions are mounted. Boot from a Live USB."
  exit 1
fi

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "FATAL: Must run as root."
  exit 1
fi

# Verify p8 BTRFS is ≤ 1.00 TiB before shrinking the partition
P8_START=$(cat "/sys/block/nvme0n1/nvme0n1p8/start")
P8_SIZE=$(cat "/sys/block/nvme0n1/nvme0n1p8/size")
BTRFS_TARGET_SECTORS=2147483648  # 1.00 TiB in 512-byte sectors

echo "p8 start sector: $P8_START"
echo "p8 current size: $P8_SIZE sectors ($(( P8_SIZE * 512 / 1024 / 1024 / 1024 )) GiB)"

if [ "$P8_SIZE" -lt "$BTRFS_TARGET_SECTORS" ]; then
  echo "FATAL: p8 is already smaller than 1.00 TiB. Aborting."
  exit 1
fi

if [ "$P8_SIZE" -eq "$BTRFS_TARGET_SECTORS" ]; then
  echo "WARNING: p8 is already exactly 1.00 TiB. Nothing to shrink."
fi

echo ""
echo "=== Current partition table ==="
sgdisk -p "$DISK"
echo ""

read -rp "Proceed with repartitioning? Type YES to continue: " CONFIRM
[ "$CONFIRM" = "YES" ] || { echo "Aborted."; exit 1; }

# ── Step 0: Backup GPT ────────────────────────────────────────────────────

echo "=== Backing up GPT to /tmp/gpt-backup.bin ==="
sgdisk -b "/tmp/gpt-backup.bin" "$DISK"

# ── Step 1: Shrink p8 to 1.00 TiB ─────────────────────────────────────────
# parted resizepart only changes the partition table entry — no data moved.
# BTRFS filesystem is already 1.00 TiB, safely within the new boundary.

P8_NEW_END=$(( P8_START + BTRFS_TARGET_SECTORS - 1 ))
echo "=== Shrinking p8 to end at sector $P8_NEW_END (1.00 TiB) ==="
parted "$DISK" unit s resizepart 8 "${P8_NEW_END}s" Yes

# ── Step 2: Delete dead partitions + swap ─────────────────────────────────

echo "=== Deleting dead partitions (p1, p2, p3, p5) ==="
sgdisk -d 1 "$DISK"  # dead btrfs (2G)
sgdisk -d 2 "$DISK"  # swap (10G) — replaced by zramSwap
sgdisk -d 3 "$DISK"  # dead ext4 (31.3G)
sgdisk -d 5 "$DISK"  # dead btrfs (4G)

# ── Step 3: Create p9 (100G ext4 for Rust cache) ──────────────────────────

echo "=== Creating p9 (100G, PARTLABEL=rust-cache) ==="
sgdisk -n 9:0:+100G "$DISK"
sgdisk -c 9:"rust-cache" "$DISK"
sgdisk -t 9:8300 "$DISK"

echo "=== Formatting p9 as ext4 ==="
mkfs.ext4 -F -L rust-cache "${DISK}p9"

# ── Verify ────────────────────────────────────────────────────────────────

echo ""
echo "=== Final partition table ==="
sgdisk -p "$DISK"
echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Reboot into NixOS"
echo "  2. Run: nix run .#deploy"
echo "  3. Move existing cargo target: sudo rm -rf ~/projects/monitor365/target"
echo "     (tmpfiles will create the symlink on next boot)"
echo ""
echo "GPT backup saved at /tmp/gpt-backup.bin (copy to USB if you want to keep it)"
