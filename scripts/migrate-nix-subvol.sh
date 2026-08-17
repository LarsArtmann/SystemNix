#!/usr/bin/env bash
# Migrate /nix from a plain directory inside the @ subvolume to a dedicated
# @nix subvolume, so btrbk snapshots of @ (and pool backup sends) exclude the
# rebuildable ~47 GiB nix store.
#
# Usage: sudo bash scripts/migrate-nix-subvol.sh
#
# ORDER MATTERS (2026-08-17 incident): switch-to-configuration mounts NEW
# fileSystems entries IMMEDIATELY. Deploying the subvol=@nix entry before
# this script finishes mounts an EMPTY @nix over /nix and shadows the entire
# store. Recovery from a surviving shell:
#   /run/wrappers/bin/sudo ... wrappers are DEAD (their targets are store
#   paths). Use the ld.so one-liner from a root shell, or reboot into the
#   previous generation from the systemd-boot menu.
#
# Copy mechanics: rsync has NO --reflink option (that's cp syntax; rsync
# gained nothing here). Bulk copy = cp -a --reflink=always (FICLONE, cheap
# on BTRFS, preserves hardlinks via -a). Delta pass = plain rsync.
set -euo pipefail

BTRFS_ROOT=/mnt/btrfs-root
SRC=/nix
DST="$BTRFS_ROOT/@nix"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run as root (sudo bash $0)" >&2
  exit 1
fi

mkdir -p "$BTRFS_ROOT"
if ! findmnt -n "$BTRFS_ROOT" >/dev/null; then
  mount "$BTRFS_ROOT" || {
    echo "ERROR: $BTRFS_ROOT not mounted. Mount the BTRFS toplevel (subvolid=5) first." >&2
    exit 1
  }
fi

if findmnt -n -o FSROOT "$SRC" | grep -q '/@nix'; then
  echo "ERROR: /nix is currently mounted from the EMPTY @nix subvolume (incident" >&2
  echo "state). Restore first (umount /nix from a root shell), then re-run." >&2
  exit 1
fi

if [[ -e $DST ]] && ! btrfs subvolume show "$DST" >/dev/null 2>&1; then
  echo "ERROR: $DST exists but is not a subvolume" >&2
  exit 1
fi

if [[ ! -e $DST ]]; then
  echo ":: Creating subvolume @nix"
  btrfs subvolume create "$DST"
elif [[ -n "$(ls -A "$DST" 2>/dev/null)" ]]; then
  echo ":: Wiping partial @nix contents (staging copies are reflinks — cheap)"
  find "$DST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

echo ":: Bulk copy $SRC -> @nix (cp --reflink, hardlinks preserved)"
# Sockets (/nix/var/nix/daemon-socket) cannot be copied — cp exits nonzero.
# They are runtime artifacts; the daemon recreates them. Everything else is
# copied before cp reports the failure, so continue deliberately.
cp -a --reflink=always "$SRC/." "$DST/" || echo "  (cp hit a socket/uncopyable — expected, continuing)"

echo ":: Delta pass (files changed during the bulk copy)"
rsync -aH --delete --info=stats1 "$SRC/" "$DST/" || echo "  (rsync hit a socket — expected)"

echo
echo "Done. Next steps:"
echo "  1. nix run .#deploy   (or just: switch-to-configuration) — mounts @nix at /nix"
echo "  2. Verify: findmnt -n -o FSROOT /nix   => must print /@nix"
echo "  3. After a few stable days, remove the old copy inside @:"
echo "     mount /mnt/btrfs-root && rm -rf /mnt/btrfs-root/@/nix"
echo "     (space frees gradually as btrbk snapshots referencing it expire)"
