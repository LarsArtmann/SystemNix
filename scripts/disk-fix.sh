#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# evo-x2 Disk Fix — fixes the emergency ONLY
#
# 1. Deletes p9 (stops ext4 overwriting BTRFS)
# 2. Resizes p8 to cover the full 1.00 TiB BTRFS filesystem
# 3. Deletes dead partitions (p1, p2, p3, p5)
# 4. Starts BTRFS scrub
#
# Does NOT create p9. Run disk-create-p9.sh AFTER scrub completes clean.
#
# Run: bash scripts/disk-fix.sh
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

DISK="/dev/nvme0n1"
P8_START_SECTOR=1097861120    # p8 start — hardcoded, never changes
BTRFS_SIZE_SECTORS=2147483648 # 1.00 TiB
BTRFS_END_SECTOR=$((P8_START_SECTOR + BTRFS_SIZE_SECTORS))
TARGET_P8_END_GIB=1560 # gives ~12.5 GiB margin past BTRFS
TARGET_P8_END_SECTOR=$((TARGET_P8_END_GIB * 1024 * 1024 * 1024 / 512))

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
BLD='\033[1m'
NC='\033[0m'
log() { echo -e "${BLU}[$(date +%H:%M:%S)]${NC} $*"; }
ok() { echo -e "${GRN}[$(date +%H:%M:%S)] ✓${NC} $*"; }
warn() { echo -e "${YLW}[$(date +%H:%M:%S)] ⚠${NC} $*"; }
err() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $*" >&2; }
die() {
  err "ABORTED: $*"
  exit 1
}

confirm() {
  local msg="$1"
  echo -en "${YLW}[$(date +%H:%M:%S)]${NC} ${msg} [yes/NO] "
  read -r ans
  [ "$ans" = "yes" ] || die "User declined: $msg"
}

sgdisk() { sudo nix shell nixpkgs#gptfdisk -c sgdisk "$@"; }
partprobe() { sudo nix shell nixpkgs#parted -c partprobe "$DISK" 2>/dev/null || true; }

# Resize partition using sgdisk (non-interactive, unlike parted which prompts on busy devices)
# Preserves start sector, changes end sector. BTRFS identifies by its own UUID, not partition GUID.
resize_p8() {
  local new_end_sector=$1
  sgdisk -d 8 "$DISK"
  partprobe
  sgdisk -n "8:${P8_START_SECTOR}:${new_end_sector}" "$DISK"
  sgdisk -t 8:8300 "$DISK"
  partprobe
}
partprobe() { sudo nix shell nixpkgs#parted -c partprobe "$DISK" 2>/dev/null || true; }

part_exists() { [ -b "${DISK}p$1" ]; }
part_start() { cat "/sys/block/nvme0n1/nvme0n1p$1/start" 2>/dev/null || echo 0; }
part_size() { cat "/sys/block/nvme0n1/nvme0n1p$1/size" 2>/dev/null || echo 0; }
part_end() { echo $(($(part_start "$1") + $(part_size "$1"))); }
sectors_to_gib() { awk "BEGIN { printf \"%.1f\", $1 * 512 / 1073741824 }"; }

assert() {
  local desc="$1"
  shift
  if "$@"; then ok "$desc"; else die "ASSERT FAILED: $desc"; fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 0: RE-VERIFY
# ═══════════════════════════════════════════════════════════════════════════
log "══════ PHASE 0: Re-verify disk state ══════"
echo ""

assert "Running as root or sudo available" bash -c 'test "$(id -u)" -eq 0 || sudo -n true 2>/dev/null'
assert "Disk ${DISK} exists" test -b "$DISK"
assert "p6 (root) exists" part_exists 6
assert "p8 (/data) exists" part_exists 8
assert "/data is mounted" bash -c 'findmnt --target /data >/dev/null 2>&1'

CURRENT_P8_START=$(part_start 8)
assert "p8 start is ${P8_START_SECTOR} (not moved)" test "$CURRENT_P8_START" -eq "$P8_START_SECTOR"

assert "Target end > BTRFS end (math safe)" test "$TARGET_P8_END_SECTOR" -gt "$BTRFS_END_SECTOR"
MARGIN_GIB=$(sectors_to_gib "$((TARGET_P8_END_SECTOR - BTRFS_END_SECTOR))")

BACKUP="/tmp/gpt-backup-$(date +%Y%m%d-%H%M%S).bin"
sgdisk -b "$BACKUP" "$DISK" >/dev/null
ok "GPT backed up to ${BACKUP}"

echo ""
log "${BLD}PLAN:${NC}"
echo "  1. Delete p9 (stops ext4 overwrite of BTRFS)"
echo "  2. Resize p8 to ${TARGET_P8_END_GIB} GiB (covers BTRFS + ${MARGIN_GIB} GiB margin)"
echo "  3. Delete dead partitions (p1, p2, p3, p5)"
echo "  4. Start BTRFS scrub"
echo ""
echo "  p9 will NOT be created — run disk-create-p9.sh after scrub completes clean."
echo ""
confirm "Proceed?"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: DELETE p9 (stop the bleeding)
# ═══════════════════════════════════════════════════════════════════════════
log ""
log "══════ PHASE 1: Delete p9 (stop ext4 overwrite) ══════"

if part_exists 9; then
  log "Unmounting and deleting p9..."
  findmnt --source "${DISK}p9" >/dev/null 2>&1 && sudo umount "${DISK}p9" || true
  sgdisk -d 9 "$DISK"
  partprobe
  assert "p9 deleted" bash -c '! part_exists 9'
else
  ok "p9 does not exist"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: RESIZE p8 (fix the boundary IMMEDIATELY)
# ═══════════════════════════════════════════════════════════════════════════
log ""
log "══════ PHASE 2: Resize p8 to cover BTRFS ══════"
echo ""

log "BTRFS filesystem: 1.00 TiB (unchanged)"
log "Target: set p8 end to ${TARGET_P8_END_GIB} GiB from disk start"
log "  → p8 end sector ${TARGET_P8_END_SECTOR} vs BTRFS end ${BTRFS_END_SECTOR} (${MARGIN_GIB} GiB margin)"
echo ""

assert "FINAL MATH CHECK: target end > BTRFS end" test "$TARGET_P8_END_SECTOR" -gt "$BTRFS_END_SECTOR"

CURRENT_END_GIB=$(sectors_to_gib "$(part_end 8)")
if [ "$(awk "BEGIN { print ($CURRENT_END_GIB <= $TARGET_P8_END_GIB + 1) && ($CURRENT_END_GIB >= $TARGET_P8_END_GIB - 1) }")" = "1" ]; then
  ok "p8 already at target — skip resize"
else
  confirm "Resize p8 from ${CURRENT_END_GIB} to ${TARGET_P8_END_GIB} GiB?"
  log "Resizing via sgdisk (delete + recreate boundary)..."
  resize_p8 "$TARGET_P8_END_SECTOR"

  POST_END=$(part_end 8)
  assert "p8 covers BTRFS after resize" test "$POST_END" -ge "$BTRFS_END_SECTOR"
  ok "p8 resized to $(sectors_to_gib "$(part_size 8)") GiB — BTRFS safe"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: DELETE DEAD PARTITIONS (p8 is now safe — partprobe won't hurt)
# ═══════════════════════════════════════════════════════════════════════════
log ""
log "══════ PHASE 3: Delete dead partitions ══════"

# Turn off disk swap first if still active
if part_exists 2 && swapon --show 2>/dev/null | grep -q "nvme0n1p2"; then
  log "Turning off disk swap (p2)..."
  sudo swapoff "${DISK}p2"
  ok "Disk swap off"
else
  ok "Disk swap already off or p2 gone"
fi

# Delete highest first (sgdisk renumbers after each deletion)
for p in 5 3 2 1; do
  if part_exists "$p"; then
    log "  Deleting p${p}..."
    sgdisk -d "$p" "$DISK"
    partprobe
    assert "p${p} deleted" bash -c '! part_exists '"$p"
  else
    warn "  p${p} already gone"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: BTRFS SCRUB
# ═══════════════════════════════════════════════════════════════════════════
log ""
log "══════ PHASE 4: BTRFS scrub ══════"

assert "/data is readable" bash -c '[ "$(ls /data 2>/dev/null | wc -l)" -gt 0 ]'

echo "Device stats:"
sudo btrfs device stats /data 2>/dev/null | sed 's/^/  /' || true

if sudo btrfs scrub status /data 2>/dev/null | grep -q "running"; then
  warn "Scrub already running"
else
  log "Starting scrub..."
  sudo btrfs scrub start /data >/dev/null 2>&1 && ok "Scrub started" || warn "Scrub failed to start"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: REPORT
# ═══════════════════════════════════════════════════════════════════════════
log ""
log "══════ PHASE 5: Report ══════"
echo ""

echo "Partition table:"
sgdisk -p "$DISK" 2>/dev/null | sed 's/^/  /'
echo ""

echo "BTRFS boundary check:"
P8_END=$(part_end 8)
if [ "$P8_END" -ge "$BTRFS_END_SECTOR" ]; then
  MARGIN=$(sectors_to_gib "$((P8_END - BTRFS_END_SECTOR))")
  echo -e "${GRN}  ✓ p8 covers BTRFS with ${MARGIN} GiB margin${NC}"
else
  echo -e "${RED}  ✗ p8 still too small!${NC}"
fi
echo ""

echo "Scrub status:"
sudo btrfs scrub status /data 2>/dev/null | head -15 | sed 's/^/  /' || true
echo ""

ok "══════ EMERGENCY FIX COMPLETE ══════"
echo ""
echo "Done:"
echo "  ✓ p9 deleted (ext4 overwrite stopped)"
echo "  ✓ p8 resized to $(sectors_to_gib "$(part_size 8)") GiB (covers BTRFS + ${MARGIN_GIB} GiB margin)"
echo "  ✓ Dead partitions deleted (p1, p2, p3, p5)"
echo "  ✓ BTRFS scrub running"
echo ""
echo -e "${BLD}NEXT STEPS:${NC}"
echo "  1. Wait for scrub: watch -n5 'sudo btrfs scrub status /data'"
echo "     → If uncorrectable errors = 0: all good"
echo "     → If uncorrectable errors > 0: some files on /data are damaged"
echo ""
echo "  2. Once scrub completes clean:"
echo "     bash scripts/disk-create-p9.sh"
echo ""
echo "  3. Deploy updated config: cd ~/projects/SystemNix && nix run .#deploy"
echo ""
echo "GPT backup: ${BACKUP}"
