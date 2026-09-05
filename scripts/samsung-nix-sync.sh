#!/usr/bin/env bash
# Samsung Phase 1: rsync /nix (QLC) -> tlc pool, subvol nix
#
# Re-runnable delta sync. Plain run = initial/interim live sync.
# --final = post-flip-deploy delta: stops nix-gc timer, syncs, then verifies
#           every path of the boot closure exists on the Samsung.
#
# Guards: root-only, flock-serialized, pressure gate with a DISK-IDLE bypass —
# io PSI on this box is permanently inflated by wedged D-state tasks (corpse
# pile re-forms at boot: diskstats deltas of ~0 with PSI ~70-80%), so the
# authoritative "is it safe to add bulk IO" signal is REAL disk activity over a
# 5s window, not PSI. Gate passes if PSI<20 OR measured disks idle.
#
# Target is mounted WITH compress=zstd — btrfs compresses at WRITE time; a
# mount without it stores everything raw and the 1.89x store win evaporates.
# If pre-existing (uncompressed) partial data is detected, a one-time
# `btrfs defragment -r -czstd` recompresses it after the sync.
#
# Run as:  sudo bash scripts/samsung-nix-sync.sh [--final]

set -euo pipefail

readonly DEV_BY_ID="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V"
readonly MNT="/mnt/samsung-nix"
readonly SRC="/nix"
FINAL=0
[ "${1:-}" = "--final" ] && FINAL=1

log() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[ "$(id -u)" -eq 0 ] || die "run as root: sudo bash $0"

# --- Serialize: never two syncs at once
exec 9>/run/samsung-nix-sync.lock
flock -n 9 || die "another samsung-nix-sync is running"
log "Lock acquired. Preflight: checking tools..."

# --- Preflight: every binary BEFORE any mount/change (clickhouse-migration lesson)
for bin in rsync ionice nice mount umount findmnt awk grep mkdir flock btrfs df find systemctl nix; do
  command -v "$bin" >/dev/null 2>&1 || die "missing tool '$bin' — aborting before any change"
done

# --- Pressure gate: zram + MemAvail hard; PSI fast-path OR real-disk-idle bypass
MEMAVAIL_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
MEMTOTAL_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
MEMAVAIL_PCT=$((MEMAVAIL_KB * 100 / MEMTOTAL_KB))
ZRAM_ORIG=$(awk '{print $2}' /sys/block/zram0/mm_stat)
ZRAM_PCT=$((ZRAM_ORIG * 100 / $(cat /sys/block/zram0/disksize)))
IO_PSI=$(awk '/^some/ {gsub(/[^0-9.]/, "", $2); print $2; exit}' /proc/pressure/io)

disk_io_sectors_5s() { # $1 = whole-disk kernel name
  local a b
  a=$(awk -v d="$1" '$3 == d {print $6 + $10}' /proc/diskstats)
  sleep 5
  b=$(awk -v d="$1" '$3 == d {print $6 + $10}' /proc/diskstats)
  echo $((b - a))
}

# io PSI on this box idles corpse-inflated at ~60-83% with provably idle
# disks, so the usable fast-path threshold is SYNC_PSI_MAX (default 62 — user
# decision 2026-09-05). The DISK-IDLE bypass remains the authoritative safety:
# above the threshold we REQUIRE measured disk idleness, not the PSI number.
GATE="undecided"
PSI_MAX="${SYNC_PSI_MAX:-62}"
if [ "${SYNC_FORCE_PRESSURE:-0}" != "1" ]; then
  [ "$MEMAVAIL_PCT" -ge 10 ] || die "MemAvail ${MEMAVAIL_PCT}% < 10% — not now"
  [ "$ZRAM_PCT" -lt 90 ] || die "zram ${ZRAM_PCT}% >= 90% — not now"
  PASS=$(awk -v p="$IO_PSI" -v m="$PSI_MAX" 'BEGIN {print (p < m) ? 1 : 0}')
  if [ "$PASS" -eq 1 ]; then
    GATE="psi<${PSI_MAX}"
  else
    # PSI bypass: measure REAL io on the source (QLC root disk) + target (Samsung)
    log "PSI ${IO_PSI}% >= ${PSI_MAX}% (corpse-inflated). Measuring REAL disk IO over 2x5s..."
    SRC_PART=$(findmnt -rn -T "$SRC" -o SOURCE)
    SRC_PART="${SRC_PART%%\[*}" # findmnt appends "[/subvol]" — strip for lsblk
    SRC_DISK=$(lsblk -no pkname "$SRC_PART")
    TGT_DISK=$(lsblk -no pkname "${DEV_BY_ID}-part2")
    QLC_MB=$(($(disk_io_sectors_5s "$SRC_DISK") / 2048))
    TLC_MB=$(($(disk_io_sectors_5s "$TGT_DISK") / 2048))
    log "Disk-idle test (5s): source ${SRC_DISK}=${QLC_MB}MB, target ${TGT_DISK}=${TLC_MB}MB (PSI ${IO_PSI}% is corpse-inflated)"
    if [ "$QLC_MB" -le 64 ] && [ "$TLC_MB" -le 64 ]; then
      GATE="disks-idle"
    else
      die "disks busy (QLC ${QLC_MB}MB/5s, TLC ${TLC_MB}MB/5s) with PSI ${IO_PSI}% >= ${PSI_MAX}% — retry when calm, or SYNC_FORCE_PRESSURE=1"
    fi
  fi
else
  GATE="forced"
fi
log "Pressure gate PASSED via: $GATE (io PSI some avg10=${IO_PSI}% zram=${ZRAM_PCT}% MemAvail=${MEMAVAIL_PCT}%). Mounting + rsync next..."

# --- Source sanity: /nix must be a real mountpoint on a DIFFERENT fs than target
findmnt -rn -T "$SRC" >/dev/null || die "$SRC is not a mountpoint — refusing to copy a directory into itself"
SRC_UUID=$(findmnt -rn -T "$SRC" -o UUID)
[ -n "$SRC_UUID" ] || die "could not read source fs UUID"

[ -b "${DEV_BY_ID}-part2" ] || die "${DEV_BY_ID}-part2 missing — did scripts/samsung-prepare.sh run?"
mkdir -p "$MNT"
WE_MOUNTED=0
FAILED=0
cleanup() {
  if [ "$WE_MOUNTED" -eq 1 ] && [ "$FAILED" -eq 1 ]; then
    umount "$MNT" || true
  fi
}
trap cleanup EXIT

if ! findmnt -rn -S "${DEV_BY_ID}-part2" -o TARGET | grep -qx "$MNT"; then
  # compress=zstd is load-bearing: btrfs compresses at WRITE time
  mount -o subvol=nix,noatime,compress=zstd "${DEV_BY_ID}-part2" "$MNT"
  WE_MOUNTED=1
fi

TGT_UUID=$(findmnt -rn -T "$MNT" -o UUID)
[ -n "$TGT_UUID" ] || die "could not read target fs UUID"
[ "$SRC_UUID" != "$TGT_UUID" ] || die "source and target are the SAME filesystem — /nix already on tlc? Aborting (post-migration footgun)"

PRE_EXISTING=1
[ -z "$(ls -A "$MNT")" ] && PRE_EXISTING=0
if [ "$PRE_EXISTING" -eq 0 ]; then
  log "Target empty — initial full sync"
else
  log "Target non-empty — delta sync"
fi

# --- Optional final-mode quiesce
if [ "$FINAL" -eq 1 ]; then
  log "--final: stopping nix-gc.timer (store must not mutate during exactness sync)"
  systemctl stop nix-gc.timer 2>/dev/null || log "WARN: could not stop nix-gc.timer (continuing)"
  log "Ensure NO builds/deploys are running — this sync must be the exact final state"
fi

# --- Sync: hardlinks load-bearing (store dedup), idle I/O class, one fs
log "rsync $SRC/ -> $MNT/ (exit 24 'files vanished' = OK for live source)"
set +e
ionice -c 3 nice -n 10 rsync -aHx --delete --numeric-ids --info=progress2,stats2 "$SRC/" "$MNT/"
RC=$?
set -e
case $RC in
0 | 24) ;;
*)
  FAILED=1
  die "rsync failed with exit $RC — re-run when calm (delta continues)"
  ;;
esac

# --- Parity report
SRC_FILES=$(find "$SRC" -xdev | wc -l)
TGT_FILES=$(find "$MNT" | wc -l)
log "Parity: source $SRC_FILES entries, target $TGT_FILES entries (live source drifts; --final is exact)"
df -h "$MNT" | tail -1 | awk '{print "  tlc usage: "$3" used / "$2" total ("$5")"}'

# --- Recompress pre-existing partial data (was possibly written without compress mount)
if [ "$PRE_EXISTING" -eq 1 ] && [ "$FINAL" -eq 0 ]; then
  log "Target had pre-existing data: running one-time btrfs defragment -r -czstd (recompress)"
  ionice -c 3 btrfs filesystem defragment -r -czstd "$MNT" || log "WARN: defrag failed — data written this run IS compressed; earlier partials may not be"
fi

# --- Final-mode closure verification: every boot path must exist on Samsung
if [ "$FINAL" -eq 1 ]; then
  log "--final: verifying boot closure exists on Samsung"
  MISSING=0
  TOTAL=0
  while read -r P; do
    TOTAL=$((TOTAL + 1))
    REL="${P#/nix}"
    [ -e "$MNT$REL" ] || {
      MISSING=$((MISSING + 1))
      echo "  MISSING: $P"
    }
  done < <(nix path-info -r /run/current-system 2>/dev/null)
  log "Closure check: $TOTAL paths, $MISSING missing"
  if [ "$MISSING" -gt 0 ]; then
    FAILED=1
    systemctl start nix-gc.timer 2>/dev/null || true
    die "closure INCOMPLETE — DO NOT REBOOT. Re-run this script (builds realized more paths), then re-check"
  fi
  systemctl start nix-gc.timer 2>/dev/null || true
  log "Closure COMPLETE — safe to reboot into the Samsung store."
fi

log "Sync complete (rsync exit $RC). Target left mounted at $MNT (umount when done: umount $MNT)"
