#!/usr/bin/env bash
set -euo pipefail

echo "BTRFS Subvolume Inventory — $(date)"
echo ""

for fs in / /data /mnt/btrfs-root; do
  mountpoint -q "$fs" 2>/dev/null || continue

  echo "━━━ $fs ━━━"
  device=$(findmnt -n -o SOURCE "$fs" 2>/dev/null || echo "unknown")
  echo "Device: $device"
  echo ""

  echo "Subvolumes:"
  sudo btrfs subvolume list -t "$fs" 2>/dev/null || echo "  (cannot list — need root)"
  echo ""

  echo "Snapshots:"
  snapshot_dir=""
  case "$fs" in
  / | /mnt/btrfs-root) snapshot_dir="/mnt/btrfs-root/.snapshots" ;;
  /data) snapshot_dir="/data/.snapshots" ;;
  esac

  if [ -n "$snapshot_dir" ] && [ -d "$snapshot_dir" ]; then
    count=$(find "$snapshot_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    latest=$(find "$snapshot_dir" -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
    echo "  Location: $snapshot_dir"
    echo "  Count: $count"
    [ -n "$latest" ] && echo "  Latest: $(basename "$latest")"
  else
    echo "  (no snapshot directory)"
  fi
  echo ""
done

echo "━━━ All Mounted BTRFS Filesystems ━━━"
findmnt -t btrfs -o TARGET,SOURCE,OPTIONS 2>/dev/null || true
