#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# evo-x2 Disk Diagnosis — READ ONLY, no changes
#
# Prints a detailed report of current disk state, detects the p8/p9 overlap
# emergency, assesses BTRFS health, and shows the target layout.
#
# Run: bash scripts/disk-diagnose.sh
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

DISK="/dev/nvme0n1"
P8_START_SECTOR=1097861120
BTRFS_SIZE_SECTORS=2147483648 # 1.00 TiB
BTRFS_END_SECTOR=$((P8_START_SECTOR + BTRFS_SIZE_SECTORS))

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
BLD='\033[1m'
NC='\033[0m'
hr() { echo -e "${CYN}────────────────────────────────────────────────────────────────────────${NC}"; }
h1() { echo -e "\n${BLD}${CYN}═══ $1 ═══${NC}\n"; }

sectors_to_gib() { awk "BEGIN { printf \"%.1f\", $1 * 512 / 1073741824 }"; }
sectors_to_tib() { awk "BEGIN { printf \"%.2f\", $1 * 512 / 1099511627776 }"; }

# ─── Partition helpers ─────────────────────────────────────────────────────
part_exists() { [ -b "${DISK}p$1" ]; }
part_start() { cat "/sys/block/nvme0n1/nvme0n1p$1/start" 2>/dev/null || echo "N/A"; }
part_size() { cat "/sys/block/nvme0n1/nvme0n1p$1/size" 2>/dev/null || echo "N/A"; }
part_end() {
  local s=$(part_start "$1")
  local z=$(part_size "$1")
  [ "$s" = "N/A" ] && echo "N/A" || echo $((s + z))
}
part_mounts() { findmnt --source "${DISK}p$1" --output TARGET --noheadings 2>/dev/null | tr '\n' ' ' || echo "—"; }
part_fstype() { lsblk -n -o FSTYPE "${DISK}p$1" 2>/dev/null || echo "—"; }

# ═══════════════════════════════════════════════════════════════════════════
h1 "1. DISK OVERVIEW"
# ───────────────────────────────────────────────────────────────────────────
DISK_SIZE=$(cat /sys/block/nvme0n1/size)
echo "Device:     ${DISK}"
echo "Model:      $(cat /sys/block/nvme0n1/device/model 2>/dev/null | xargs)"
echo "Total size: $(sectors_to_gib "$DISK_SIZE") GiB ($(sectors_to_tib "$DISK_SIZE") TiB)"
echo "Sector size: 512 bytes"
echo "GPT:         $([ -f /sys/block/nvme0n1/pttype ] && cat /sys/block/nvme0n1/pttype || echo 'unknown')"

# ═══════════════════════════════════════════════════════════════════════════
h1 "2. PARTITION TABLE (exact geometry)"
# ───────────────────────────────────────────────────────────────────────────
printf "%-5s  %-12s  %-12s  %-10s  %-8s  %-20s  %s\n" "PART" "START" "END" "SIZE" "FSTYPE" "MOUNTS" "ROLE"
hr
for p in 1 2 3 4 5 6 7 8 9 10; do
  part_exists "$p" || continue
  s=$(part_start "$p")
  z=$(part_size "$p")
  e=$(part_end "$p")
  gib=$(sectors_to_gib "$z")
  fst=$(part_fstype "$p")
  mnt=$(part_mounts "$p")
  case "$p" in
  1) role="dead btrfs?" ;;
  2) role="disk swap" ;;
  3) role="dead ext4 (old root)" ;;
  5) role="dead btrfs?" ;;
  6) role="ROOT (/) — btrfs @" ;;
  7) role="/boot (EFI)" ;;
  8) role="/data — btrfs" ;;
  9) role="rust-cache? (ext4)" ;;
  *) role="" ;;
  esac
  printf "%-5s  %-12s  %-12s  %-8s GiB  %-8s  %-20s  %s\n" "p$p" "$s" "$e" "$gib" "$fst" "$mnt" "$role"
done

# ═══════════════════════════════════════════════════════════════════════════
h1 "3. BTRFS vs PARTITION BOUNDARY (THE CRITICAL CHECK)"
# ───────────────────────────────────────────────────────────────────────────
if ! part_exists 8; then
  echo -e "${RED}p8 does not exist — cannot assess BTRFS safety${NC}"
else
  P8_S=$(part_start 8)
  P8_Z=$(part_size 8)
  P8_E=$(part_end 8)
  echo "BTRFS filesystem on /data:"
  echo "  BTRFS size:     $(sectors_to_gib "$BTRFS_SIZE_SECTORS") GiB (1.00 TiB)"
  echo "  BTRFS end:      sector ${BTRFS_END_SECTOR}"
  echo ""
  echo "Partition p8:"
  echo "  p8 start:       sector ${P8_S}"
  echo "  p8 size:        $(sectors_to_gib "$P8_Z") GiB"
  echo "  p8 end:         sector ${P8_E}"
  echo ""

  OVERLAP=$((BTRFS_END_SECTOR - P8_E))
  if [ "$OVERLAP" -gt 0 ]; then
    OVERLAP_GIB=$(sectors_to_gib "$OVERLAP")
    echo -e "${RED}🚨 CRITICAL: BTRFS extends ${OVERLAP_GIB} GiB PAST p8 boundary!${NC}"
    echo -e "${RED}   ${OVERLAP} sectors of BTRFS data are outside the partition.${NC}"
    echo ""
    echo -e "${YLW}   This means the partition was shrunk too small.${NC}"
    echo -e "${YLW}   If p9 exists, its ext4 filesystem may have overwritten BTRFS data.${NC}"
    echo ""
    echo -e "${BLD}   DAMAGE ASSESSMENT:${NC}"
    if part_exists 9; then
      P9_S=$(part_start 9)
      P9_Z=$(part_size 9)
      P9_E=$(part_end 9)
      echo "   p9 start:     sector ${P9_S}"
      echo "   p9 end:       sector ${P9_E}"
      echo "   p9 size:      $(sectors_to_gib "$P9_Z") GiB"
      # Check if p9 overlaps the BTRFS overflow area
      if [ "$P9_S" -lt "$P8_E" ] || [ "$P9_S" -ge "$P8_E" ]; then
        # p9 starts where p8 ends — but BTRFS extends past p8
        if [ "$P9_S" -lt "$BTRFS_END_SECTOR" ]; then
          P9_BTRFS_OVERLAP=$((P9_E < BTRFS_END_SECTOR ? P9_E - P9_S : BTRFS_END_SECTOR - P9_S))
          P9_BTRFS_OVERLAP_GIB=$(sectors_to_gib "$P9_BTRFS_OVERLAP")
          echo -e "${RED}   p9 overlaps BTRFS data by ${P9_BTRFS_OVERLAP_GIB} GiB${NC}"
          echo -e "${RED}   That ext4 data has OVERWRITTEN BTRFS blocks in this range.${NC}"
          echo -e "${YLW}   BTRFS DUP metadata copies MAY survive — scrub will reveal extent.${NC}"
        fi
      fi
    else
      echo "   p9 does not exist — no ext4 overwrite, but BTRFS is still exposed"
    fi
    echo ""
    echo -e "${GRN}   RECOMMENDATION: Run disk-fix.sh IMMEDIATELY${NC}"
    RISK_LEVEL="CRITICAL"
  elif [ "$OVERLAP" -gt -2097152 ]; then
    echo -e "${YLW}⚠ WARNING: p8 barely covers BTRFS (margin: $(sectors_to_gib "$((0 - OVERLAP))") GiB)${NC}"
    echo -e "${YLW}   Safe but tight — grow p8 before any further operations${NC}"
    RISK_LEVEL="WARNING"
  else
    MARGIN_GIB=$(sectors_to_gib "$((0 - OVERLAP))")
    echo -e "${GRN}✓ SAFE: p8 covers BTRFS with ${MARGIN_GIB} GiB margin${NC}"
    RISK_LEVEL="SAFE"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
h1 "4. BTRFS HEALTH (/data)"
# ───────────────────────────────────────────────────────────────────────────
echo "Device stats (csum/read/write/corruption errors):"
sudo btrfs device stats /data 2>/dev/null || echo "  (unable to read — /data not mounted or btrfs broken)"
echo ""

echo "Scrub status:"
if SCRUB=$(sudo btrfs scrub status /data 2>/dev/null); then
  if echo "$SCRUB" | grep -q "running"; then
    echo -e "${YLW}  Scrub is currently RUNNING:${NC}"
    echo "$SCRUB" | head -15 | sed 's/^/  /'
  else
    echo "$SCRUB" | head -15 | sed 's/^/  /'
  fi
else
  echo "  (no scrub info — /data not mounted)"
fi
echo ""

echo "Filesystem allocation:"
sudo btrfs filesystem df /data 2>/dev/null | sed 's/^/  /' || echo "  (unable to read)"

echo ""
echo "Data readability:"
if ENTRIES=$(ls /data 2>/dev/null | wc -l) && [ "$ENTRIES" -gt 0 ]; then
  echo -e "${GRN}  ✓ /data is readable (${ENTRIES} top-level entries)${NC}"
else
  echo -e "${RED}  ✗ /data is empty or unreadable — possible severe corruption${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════
h1 "5. SWAP STATUS"
# ───────────────────────────────────────────────────────────────────────────
echo "Active swap devices:"
swapon --show 2>/dev/null || echo "  No swap active"
echo ""
echo "ZRAM config (from running system):"
cat /sys/block/zram0/disksize 2>/dev/null && echo "  (zram0 active)" || echo "  zram0 not configured"

# ═══════════════════════════════════════════════════════════════════════════
h1 "6. DEAD PARTITIONS (reclaimable space)"
# ───────────────────────────────────────────────────────────────────────────
TOTAL_RECLAIM=0
for p in 1 2 3 5; do
  if part_exists "$p"; then
    z=$(part_size "$p")
    gib=$(sectors_to_gib "$z")
    echo -e "  p${p}: ${gib} GiB  — $(part_mounts "$p" | xargs)"
    TOTAL_RECLAIM=$((TOTAL_RECLAIM + z))
  fi
done
if [ "$TOTAL_RECLAIM" -gt 0 ]; then
  echo ""
  echo -e "${GRN}Total reclaimable: $(sectors_to_gib "$TOTAL_RECLAIM") GiB${NC}"
else
  echo -e "${GRN}No dead partitions found${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════
h1 "7. TARGET LAYOUT (what disk-fix.sh will produce)"
# ───────────────────────────────────────────────────────────────────────────
TARGET_P8_END_GIB=1548
TARGET_P8_END_SECTOR=$((TARGET_P8_END_GIB * 1024 * 1024 * 1024 / 512))
MARGIN_SECTORS=$((TARGET_P8_END_SECTOR - BTRFS_END_SECTOR))
MARGIN_GIB=$(sectors_to_gib "$MARGIN_SECTORS")

echo "After disk-fix.sh:"
echo ""
printf "  %-6s  %-12s  %-10s  %-8s  %s\n" "PART" "PURPOSE" "SIZE" "FSTYPE" "STATUS"
hr
printf "  %-6s  %-12s  %-10s  %-8s  %s\n" "p6" "/" "512 GiB" "btrfs" "unchanged"
printf "  %-6s  %-12s  %-10s  %-8s  %s\n" "p7" "/boot" "2 GiB" "vfat" "unchanged"
printf "  %-6s  %-12s  %-10s  %-8s  %s\n" "p8" "/data" "~1025 GiB" "btrfs" "shrunk to cover BTRFS + ${MARGIN_GIB} GiB margin"
printf "  %-6s  %-12s  %-10s  %-8s  %s\n" "p9" "/rust-cache" "100 GiB" "ext4" "NEW"
printf "  %-6s  %-12s  %-10s  %-8s  %s\n" "free" "(unallocated)" "~215 GiB" "—" "future use"
echo ""

echo "Exact geometry:"
echo "  p8 end sector:   ${TARGET_P8_END_SECTOR} (${TARGET_P8_END_GIB} GiB from disk start)"
echo "  BTRFS end:       ${BTRFS_END_SECTOR}"
echo "  Margin:          ${MARGIN_SECTORS} sectors (${MARGIN_GIB} GiB)"
echo ""
if [ "${MARGIN_SECTORS:-0}" -gt 0 ]; then
  echo -e "${GRN}✓ Math checks out — BTRFS will be safe${NC}"
else
  echo -e "${RED}✗ MATH ERROR — margin is not positive! DO NOT run disk-fix.sh${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════
h1 "8. GO / NO-GO RECOMMENDATION"
# ───────────────────────────────────────────────────────────────────────────
case "${RISK_LEVEL:-UNKNOWN}" in
CRITICAL)
  echo -e "${RED}🚨 RISK: CRITICAL${NC}"
  echo -e "${YLW}BTRFS extends past p8 boundary. Data may be damaged.${NC}"
  echo -e "${YLW}Run disk-fix.sh NOW to prevent further damage.${NC}"
  echo ""
  echo -e "${BLD}After disk-fix.sh:${NC}"
  echo "  1. Wait for scrub to complete: sudo btrfs scrub status /data"
  echo "  2. If uncorrectable errors > 0, check which files are affected"
  echo "  3. Restore damaged files from backup if available"
  echo ""
  echo -e "${GRN}→ NEXT: bash scripts/disk-fix.sh${NC}"
  ;;
WARNING)
  echo -e "${YLW}⚠ RISK: LOW${NC}"
  echo "p8 covers BTRFS but margin is thin. Safe to proceed with disk-fix.sh."
  echo ""
  echo -e "${GRN}→ NEXT: bash scripts/disk-fix.sh${NC}"
  ;;
SAFE)
  echo -e "${GRN}✓ RISK: NONE${NC}"
  echo "Everything looks good. Safe to proceed with disk-fix.sh."
  echo ""
  echo -e "${GRN}→ NEXT: bash scripts/disk-fix.sh${NC}"
  ;;
*)
  echo -e "${RED}? RISK: UNKNOWN${NC}"
  echo "Could not determine risk level. Review output above manually."
  ;;
esac
