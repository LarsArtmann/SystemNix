#!/usr/bin/env bash
set -euo pipefail

MNT="/mnt/btrfs-root"
SNAP_DIR="$MNT/.snapshots"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_NAME="@.pre-deploy-${TIMESTAMP}"

# Trigger automount by listing the subvolume
ls "$MNT/@" >/dev/null 2>&1 || {
  echo "WARNING: Cannot access ${MNT}/@ — skipping pre-deploy snapshot"
  exit 0
}

mkdir -p "$SNAP_DIR"

# Create snapshot (never block deploy on failure)
if sudo btrfs subvolume snapshot "$MNT/@" "$SNAP_DIR/$SNAP_NAME" 2>/dev/null; then
  echo "Created pre-deploy snapshot: $SNAP_NAME"
else
  echo "WARNING: Pre-deploy snapshot failed — continuing deploy anyway"
  exit 0
fi

# Rotate: keep last 10 pre-deploy snapshots
sudo find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@.pre-deploy-*' 2>/dev/null | sort | head -n -10 | while IFS= read -r snap; do
  sudo btrfs subvolume delete "$snap" >/dev/null 2>&1 && echo "Rotated: $(basename "$snap")" || true
done
