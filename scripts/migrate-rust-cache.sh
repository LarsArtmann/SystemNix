#!/usr/bin/env bash
# One-time setup of the dedicated Rust cache SSD (/mnt/rust-cache).
#
# Run BEFORE the first deploy of services.rust-cache:
#   nix run .#migrate-rust-cache && nix run .#deploy
#
# Context (2026-10-06 user direction): the second SanDisk SDSSDA240G (serial
# 174244451713 - the empty spare) is dedicated to the Rust build cache,
# superseding the 2026-09-22 two-SanDisk btrfs-merge decision. This script
# FORMATS that disk as btrfs (label rust-cache), mounts it, and moves the
# existing Rust caches off /mnt/buildcache.
#
# NOT automated - run manually in a maintenance window (quiesced cache
# consumers: stop rust-analyzer/gopls builds; the disk is currently empty, so
# only the *_MOVE stages touch live data).
#
# Requires: the SanDisk SSD (serial 174244451713) attached via the DAS, and
# passwordless sudo for mount/mkfs.
#
# Safe to re-run: if the disk is already btrfs labelled rust-cache and mounted,
# the format step is skipped and the move steps converge (rsync is idempotent).
set -Eeuo pipefail

DEVICE="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1"
MOUNT="/mnt/rust-cache"
LABEL="rust-cache"
MOUNT_OPTS="noatime,compress=zstd:1,space_cache=v2,commit=120"
SOURCES="/mnt/buildcache" # where the existing Rust caches currently live
SUDO="sudo -n"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}
info() { echo "==> $*"; }

[ "$(id -un)" = "lars" ] || fail "run as lars (nix run .#migrate-rust-cache)"
$SUDO true 2>/dev/null || fail "passwordless sudo required"

for bin in lsblk mkfs.btrfs mount findmnt mountpoint rsync df; do
  command -v "$bin" >/dev/null || fail "$bin not on PATH"
done

info "checking device: $DEVICE"
[ -e "$DEVICE" ] || fail "device not found — is the DAS/USB enclosure powered?"

# Content gate: REFUSE to format anything that is not the exact spare disk.
# (a wrong DEVICE, a device that flipped to another role, or a future
# repurposing must never reach mkfs silently)
FS="$(lsblk -nrno FSTYPE "$DEVICE" 2>/dev/null || true)"
LB="$(lsblk -nrno LABEL "$DEVICE" 2>/dev/null || true)"
MNT_NOW="$(lsblk -nrno MOUNTPOINTS "$DEVICE" 2>/dev/null || true)"
if [ "$LB" = "$LABEL" ] && [ "$FS" = "btrfs" ]; then
  info "already formatted as btrfs label=$LABEL — skipping mkfs"
else
  case "$FS/$LB" in
  btrfs/ssd-btrfs) info "recognized spare disk (btrfs/ssd-btrfs, Docker earmark dropped)" ;;
  *) fail "$DEVICE is fstype='$FS' label='$LB' — expected btrfs+ssd-btrfs or btrfs+$LABEL. If the disk's role changed, edit DEVICE/this gate deliberately." ;;
  esac
  if [ -n "$MNT_NOW" ]; then
    fail "$DEVICE is mounted ($MNT_NOW) — unmount before formatting"
  fi
  info "formatting $DEVICE as btrfs (label $LABEL, single profile)"
  # -f is REQUIRED here (mkfs refuses to overwrite the existing ssd-btrfs
  # filesystem otherwise) and SAFE: the gate above already verified this is
  # the exact serial-pinned spare disk, unmounted, holding only the old
  # ssd-btrfs earmark this script exists to replace.
  $SUDO mkfs.btrfs -f -L "$LABEL" -d single -m single "$DEVICE"
fi

if ! mountpoint -q "$MOUNT"; then
  info "mounting $DEVICE at $MOUNT ($MOUNT_OPTS)"
  $SUDO mkdir -p "$MOUNT"
  $SUDO mount -o "$MOUNT_OPTS" "$DEVICE" "$MOUNT" || fail "mount failed"
fi
[ "$(findmnt -n -o FSTYPE "$MOUNT")" = "btrfs" ] || fail "$MOUNT is not btrfs — refusing to write"

$SUDO mkdir -p "$MOUNT/sccache" "$MOUNT/cargo" "$MOUNT/rust"
$SUDO chown lars:users "$MOUNT/sccache" "$MOUNT/cargo" "$MOUNT/rust"

# move <relative-path> — rsync from /mnt/buildcache into /mnt/rust-cache, verify
# file count, then remove the source to free the buildcache disk. Cache data
# only; rm (not trash) because trashing tens of GB of rebuildable cache would
# write it onto the NVMe the cache setup exists to protect.
move() {
  local rel="$1"
  local src="$SOURCES/$rel"
  local dst="$MOUNT/$rel"
  if mountpoint -q "$SOURCES" && [ -d "$src" ] && [ ! -L "$src" ]; then
    info "moving $rel: $SOURCES/$rel -> $dst"
    mkdir -p "$(dirname "$dst")"
    rsync -a --delete "$src/" "$dst/"
    local sf dfc
    sf="$(find "$src" | wc -l)"
    dfc="$(find "$dst" | wc -l)"
    [ "$dfc" -ge "$sf" ] || fail "verification failed for $rel ($sf src files vs $dfc dst)"
    info "verified $dfc files; removing source $src"
    rm -rf -- "$src"
  else
    info "SKIP (no source or already moved): $rel"
  fi
}

move "cargo"
move "rust"
move "sccache"

echo
info "done. Rust caches on $MOUNT: $(df -h --output=size,used,avail "$MOUNT" | tail -n1)"
echo
echo "Next steps:"
echo "  1. nix run .#deploy   # persistent btrfs mount, env vars (SCCACHE_DIR/CARGO_HOME), symlinks, monitoring"
echo "  2. Open a NEW terminal (env vars), then: cd ~/projects/monitor365 && cargo build"
echo "  3. If the disk write performance degrades over months (no TRIM via the USB"
echo "     bridge), reformat: mkfs.btrfs -L $LABEL $DEVICE (rebuildable cache)."
