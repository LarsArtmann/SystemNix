#!/usr/bin/env bash
# Samsung Phase 1, step 2: initial LIVE rsync of /nix (QLC) -> tlc pool, subvol nix
#
# Safe to run anytime (delta-syncable, re-runnable). The store mutates under us
# during builds — that is EXPECTED and fine: the final delta sync (step 3, after
# quiescing builds/optimizer/gc) is what makes it exact. rsync exit 24 (source
# files vanished mid-copy) is treated as success for exactly this reason.
#
# Guards: pressure gate (same thresholds as deploy.sh), source!=target device,
# /nix must be a mountpoint. I/O is ionice idle-class so the QLC stays responsive.
#
# Run as:  sudo bash scripts/samsung-nix-sync.sh
# (129 GiB off a busy QLC: expect 30 min - a few hours. Use tmux/zellij.)

set -euo pipefail

readonly DEV_BY_ID="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V"
readonly MNT="/mnt/samsung-nix"
readonly SRC="/nix"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo bash $0"

# --- Preflight: every binary BEFORE any mount/change (clickhouse-migration lesson)
for bin in rsync ionice nice mount umount findmnt awk grep mkdir rmdir; do
  command -v "$bin" >/dev/null 2>&1 || die "missing tool '$bin' — aborting before any change"
done

# --- Pressure gate (deploy.sh doctrine: never add QLC bulk IO under pressure)
IO_PSI=$(awk '/^some/ {gsub(/[^0-9.]/, "", $2); print $2; exit}' /proc/pressure/io)
MEMAVAIL_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
MEMTOTAL_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
MEMAVAIL_PCT=$((MEMAVAIL_KB * 100 / MEMTOTAL_KB))
ZRAM_ORIG=$(awk '{print $2}' /sys/block/zram0/mm_stat)
ZRAM_DISK=$(cat /sys/block/zram0/disksize)
ZRAM_PCT=$((ZRAM_ORIG * 100 / ZRAM_DISK))
log "Pressure check: io PSI some avg10=${IO_PSI}% zram=${ZRAM_PCT}% MemAvail=${MEMAVAIL_PCT}%"
if [ "${SYNC_FORCE_PRESSURE:-0}" != "1" ]; then
  AWK_OK=$(awk -v psi="$IO_PSI" -v z="$ZRAM_PCT" -v m="$MEMAVAIL_PCT" 'BEGIN {print (psi < 20 && z < 90 && m >= 10) ? 1 : 0}')
  [ "$AWK_OK" -eq 1 ] || die "system under pressure (want PSI<20, zram<90, MemAvail>=10). Retry when quiet, or SYNC_FORCE_PRESSURE=1 $0"
fi

# --- Source sanity: /nix must be a real mountpoint (the QLC @nix subvol)
findmnt -rn -S "$SRC" >/dev/null || die "$SRC is not a mountpoint — refusing to copy a directory into itself"
SRC_UUID=$(findmnt -rn -S "$SRC" -o UUID)
[ -n "$SRC_UUID" ] || die "could not read source fs UUID"

# --- Target: tlc pool, subvol nix
[ -b "${DEV_BY_ID}-part2" ] || die "${DEV_BY_ID}-part2 missing — did scripts/samsung-prepare.sh run?"
mkdir -p "$MNT"
MOUNTED=0
cleanup() {
  if [ "$MOUNTED" -eq 1 ]; then
    umount "$MNT" || true
  fi
}
trap cleanup EXIT

if ! findmnt -rn -S "$DEV_BY_ID-part2" -o TARGET | grep -qx "$MNT"; then
  mount -o subvol=nix,noatime "${DEV_BY_ID}-part2" "$MNT"
  MOUNTED=1
fi

TGT_UUID=$(findmnt -rn -S "$MNT" -o UUID)
[ -n "$TGT_UUID" ] || die "could not read target fs UUID"
[ "$SRC_UUID" != "$TGT_UUID" ] || die "source and target are the SAME filesystem — /nix already on tlc? Aborting (post-migration footgun)"

if [ -z "$(ls -A "$MNT")" ]; then
  log "Target empty — initial full sync"
else
  log "Target non-empty — delta sync (previous run or partial)"
fi

# --- Sync: hardlinks are load-bearing (store dedup), idle I/O class, one fs
log "rsync $SRC/ -> $MNT/ (idle I/O class; exit 24 'files vanished' = OK for live source)"
set +e
ionice -c 3 nice -n 10 rsync -aHx --delete --numeric-ids --info=progress2,stats2 "$SRC/" "$MNT/"
RC=$?
set -e
case $RC in
  0 | 24) ;;
  *) die "rsync failed with exit $RC — target left as-is; re-run when the system is calm (delta sync continues where it left off)" ;;
esac

log "Sync complete (rsync exit $RC)."
echo "Next: step 3 — quiesce builds + auto-optimise-store + nix-gc, final delta sync,"
echo "fileSystems.\"/nix\" (by-label tlc, subvol nix, neededForBoot), deploy, then step-4"
echo "delta rsync BEFORE reboot, then the reboot window (user)."
