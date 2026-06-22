#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Find all files with BTRFS checksum errors on /data
#
# Strategy: Read every file — BTRFS returns I/O error on corrupt extents.
# Lists all damaged files with their sizes.
#
# Run: bash scripts/find-corrupted-files.sh
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

SCAN_DIR="/data"
REPORT="/tmp/corrupted-files-$(date +%Y%m%d-%H%M%S).txt"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; BLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${BLU}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "${GRN}[$(date +%H:%M:%S)] ✓${NC} $*"; }
warn() { echo -e "${YLW}[$(date +%H:%M:%S)] ⚠${NC} $*"; }
err()  { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $*" >&2; }

echo "" > "$REPORT"

log "Scanning ${SCAN_DIR} for corrupted files..."
log "Damaged files will be listed to: ${REPORT}"
log ""

CORRUPTED=0
CHECKED=0
TOTAL_SIZE=0

# Find all regular files, read each one — corrupt extents cause I/O error
# Use `dd` with small block size to trigger read of every extent
while IFS= read -r -d '' file; do
    CHECKED=$((CHECKED + 1))

    # Read the file to trigger checksum verification
    # dd reads in 1M blocks, output to /dev/null
    if ! dd if="$file" of=/dev/null bs=1M 2>/dev/null; then
        # File has read errors — get its size
        SIZE=$(stat -c %s "$file" 2>/dev/null || echo 0)
        SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$SIZE" 2>/dev/null || echo "${SIZE}B")

        echo -e "${RED}  ✗ CORRUPT: ${file} (${SIZE_HUMAN})${NC}"
        echo "${file}	${SIZE}	${SIZE_HUMAN}" >> "$REPORT"
        CORRUPTED=$((CORRUPTED + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi

    # Progress every 1000 files
    if [ $((CHECKED % 1000)) -eq 0 ]; then
        log "Checked ${CHECKED} files... (${CORRUPTED} corrupt so far)"
    fi
done < <(find "$SCAN_DIR" -type f -print0)

echo ""
log "══════ SCAN COMPLETE ══════"
echo ""
echo "Files checked:  ${CHECKED}"
echo "Files corrupt:  ${CORRUPTED}"
TOTAL_HUMAN=$(numfmt --to=iec --suffix=B "$TOTAL_SIZE" 2>/dev/null || echo "${TOTAL_SIZE}B")
echo "Total damaged:  ${TOTAL_HUMAN}"
echo ""
echo "Report saved:   ${REPORT}"

if [ "$CORRUPTED" -gt 0 ]; then
    echo ""
    log "${BLD}Damaged files:${NC}"
    cat "$REPORT" | while IFS=$'\t' read -r path size human; do
        echo -e "  ${RED}✗${NC} ${path} (${human})"
    done
fi
