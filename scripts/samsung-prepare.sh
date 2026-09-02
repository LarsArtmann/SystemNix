#!/usr/bin/env bash
# Samsung 970 EVO Plus 1TB — Phase 1, step 1: partition + format + nix subvol
#
# Ratified Rev 2 layout (docs/planning/2026-08-31_samsung-role-assignment-first-principles.md):
#   p1: 4 GiB EFI (ef00), FAT32 label SAMSUNG-EFI — formatted, UNMOUNTED, reserved for a
#       future boot migration (zero-repartition then)
#   p2: rest of disk (~927.5 G), BTRFS label tlc — the ONLY data partition; every role
#       is a subvolume (compress=zstd arrives later as a MOUNT option, not mkfs)
#   subvol created here: nix (for the /nix migration, step 2)
#
# Safety: refuses to run unless the target is the Samsung, ~931.5G, completely BLANK
# (zero partitions, zero filesystem signatures). Non-destructive to everything else:
# nothing mounts this disk yet, the running system stays on the Lexar.
#
# Run as:  sudo bash scripts/samsung-prepare.sh

set -euo pipefail

readonly DEV_BY_ID="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V"
readonly EXPECT_MODEL="970 EVO Plus"
readonly MIN_GB=925   # expected 931.5 GiB
readonly MAX_GB=938
readonly POOL_LABEL="tlc"
readonly ESP_LABEL="SAMSUNG-EFI"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo bash $0"

# --- Preflight: resolve EVERY binary before anything destructive (clickhouse-migration lesson)
for bin in sgdisk mkfs.fat mkfs.btrfs btrfs lsblk udevadm findmnt wipefs mount umount awk grep; do
  command -v "$bin" >/dev/null 2>&1 || die "missing tool '$bin' — not on PATH under sudo; aborting before any change"
done

# --- Target verification -----------------------------------------------------
log "Verifying target: $DEV_BY_ID"
[ -b "$DEV_BY_ID" ] || die "device does not exist — Samsung not attached? Never fall back to nvmeXn1 kernel names (enumeration shifts)"

MODEL="$(lsblk -ndo MODEL "$DEV_BY_ID")"
SIZE_GB="$(lsblk -ndo SIZE --bytes "$DEV_BY_ID" | awk '{printf "%d", $1 / 1073741824}')"
PARTS="$(lsblk -rno TYPE "$DEV_BY_ID" | awk '$1 == "part"' | wc -l)"
SIGS="$(wipefs -n "$DEV_BY_ID" 2>/dev/null || true)"

printf '  model: %s\n  size:  %s GiB\n' "$MODEL" "$SIZE_GB"

[[ "$MODEL" == *"$EXPECT_MODEL"* ]] || die "model mismatch: expected *$EXPECT_MODEL*, got '$MODEL'"
[ "$SIZE_GB" -ge "$MIN_GB" ] && [ "$SIZE_GB" -le "$MAX_GB" ] || die "size mismatch: expected ${MIN_GB}-${MAX_GB} GiB, got ${SIZE_GB} GiB"
[ "$PARTS" -eq 0 ] || die "disk already has $PARTS partition(s) — this script only prepares a BLANK disk. Re-preparing would destroy data; partition manually if that is truly intended."
[ -z "$SIGS" ] || die "disk has filesystem signatures (not blank):\n$SIGS\nInspect with 'wipefs -n $DEV_BY_ID' and decide manually."
findmnt -S "$DEV_BY_ID" >/dev/null && die "device (or a partition) is mounted — refusing"

# --- Plan + confirmation -----------------------------------------------------
cat <<PLAN

Will create on $DEV_BY_ID ($MODEL, ${SIZE_GB} GiB):
  p1  4 GiB    EFI (ef00)  FAT32 label $ESP_LABEL   [formatted, stays UNMOUNTED, reserved]
  p2  rest     BTRFS label $POOL_LABEL              [single data pool]
  btrfs subvol: nix

Next steps after this (NOT done here): initial live rsync of /nix (step 2),
final delta sync + fileSystems entry + deploy (steps 3-4), reboot window (step 5).
PLAN

read -r -p "Proceed? [y/N] " ANSWER
case "$ANSWER" in
  y | Y | yes) ;;
  *) die "aborted — nothing was changed" ;;
esac

# --- Partition ----------------------------------------------------------------
log "Partitioning (sgdisk: zap + p1 4G ef00 + p2 rest 8300)"
sgdisk -Z "$DEV_BY_ID"
sgdisk -n 1:0:+4G -t 1:ef00 -c 1:ESP "$DEV_BY_ID"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"$POOL_LABEL" "$DEV_BY_ID"
udevadm settle

# --- Format -------------------------------------------------------------------
log "Formatting: p1 FAT32 ($ESP_LABEL), p2 BTRFS ($POOL_LABEL)"
mkfs.fat -F32 -n "$ESP_LABEL" "${DEV_BY_ID}-part1"
mkfs.btrfs -L "$POOL_LABEL" "${DEV_BY_ID}-part2"

# --- nix subvol -----------------------------------------------------------------
log "Creating btrfs subvol 'nix' on the ${POOL_LABEL} pool"
MNT="$(mktemp -d)"
MOUNTED=0
cleanup() {
  if [ "$MOUNTED" -eq 1 ]; then
    umount "$MNT" || true
  fi
  rmdir "$MNT" || true
}
trap cleanup EXIT
mount "${DEV_BY_ID}-part2" "$MNT"
MOUNTED=1
btrfs subvolume create "$MNT/nix"

# --- Verify ---------------------------------------------------------------------
log "Verification"
PART_COUNT="$(lsblk -rno TYPE "$DEV_BY_ID" | awk '$1 == "part"' | wc -l)"
[ "$PART_COUNT" -eq 2 ] || die "expected 2 partitions after sgdisk, found $PART_COUNT"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEV_BY_ID"
echo "--- btrfs subvolumes on ${POOL_LABEL}:"
btrfs subvolume list "$MNT"
grep -q " path nix$" < <(btrfs subvolume list "$MNT") || die "subvol 'nix' not found after creation"
umount "$MNT"
MOUNTED=0

log "DONE. Samsung is ready for step 2 (initial live rsync of /nix)."
echo "ESP is intentionally formatted-but-unmounted (reserved for a future boot migration)."
