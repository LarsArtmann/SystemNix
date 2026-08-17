#!/usr/bin/env bash
# Migrate /nix from a plain directory inside the @ subvolume to a dedicated
# @nix subvolume, so btrbk snapshots of @ (and the pool backup sends) exclude
# the ~47 GiB nix store. The store is fully rebuildable; generations keep
# their own GC roots under /nix/var/nix/profiles, so it needs no snapshots.
#
# Usage: sudo bash scripts/migrate-nix-subvol.sh
#
# Steps:
#   1. Create @nix subvolume (toLEVEL, sibling of @)
#   2. rsync -aH --reflink=always /nix/ -> @nix/ (hardlinks preserved,
#      reflink = near-instant on BTRFS, resumable if interrupted)
#   3. Re-run rsync to catch the delta, then deploy (`nix run .#deploy`)
#      which mounts /nix from @nix
#   4. After a verified reboot: delete the old /nix dir inside @
#      (space is reclaimed as old btrbk snapshots expire: 14d local,
#      30d/12w on the pool)
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

if [[ -d "$DST/store" ]]; then
  echo ":: @nix already exists — running delta sync only"
else
  echo ":: Creating subvolume @nix"
  btrfs subvolume create "$DST"
fi

echo ":: Syncing $SRC -> $DST (reflink, hardlinks preserved)"
rsync -aH --reflink=always --info=progress2 "$SRC/" "$DST/"

echo ":: Delta pass (catch files changed during the first pass)"
rsync -aH --reflink=always --delete "$SRC/" "$DST/"

echo
echo "Done. Next steps:"
echo "  1. nix run .#deploy          # mounts /nix from @nix"
echo "  2. reboot                    # clean slate, everything on the new subvol"
echo "  3. Verify: findmnt /nix      # FSROOT must be /@nix"
echo "  4. After a few days of stable boots, remove the old copy:"
echo "     mount /mnt/btrfs-root && rm -rf /mnt/btrfs-root/@/nix"
echo "     (space frees gradually as btrbk snapshots referencing it expire)"
