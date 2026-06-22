#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# evo-x2 Create p9 — run ONLY after disk-fix.sh + scrub completes clean
#
# Verifies the fix is in place, then creates p9 (100 GiB ext4 /rust-cache).
#
# Run: bash scripts/disk-create-p9.sh
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

DISK="/dev/nvme0n1"
P8_START_SECTOR=1097861120
BTRFS_SIZE_SECTORS=2147483648
BTRFS_END_SECTOR=$((P8_START_SECTOR + BTRFS_SIZE_SECTORS))
TARGET_P8_END_GIB=1560

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; BLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${BLU}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "${GRN}[$(date +%H:%M:%S)] ✓${NC} $*"; }
warn() { echo -e "${YLW}[$(date +%H:%M:%S)] ⚠${NC} $*"; }
err()  { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $*" >&2; }
die()  { err "ABORTED: $*"; exit 1; }

confirm() {
    local msg="$1"
    echo -en "${YLW}[$(date +%H:%M:%S)]${NC} ${msg} [yes/NO] "
    read -r ans
    [ "$ans" = "yes" ] || die "User declined: $msg"
}

sgdisk()    { sudo nix shell nixpkgs#gptfdisk -c sgdisk "$@"; }
parted()    { sudo nix shell nixpkgs#parted -c parted -s "$@"; }
mkfs_ext4() { sudo nix shell nixpkgs#e2fsprogs -c mkfs.ext4 "$@"; }
partprobe() { sudo nix shell nixpkgs#parted -c partprobe "$DISK" 2>/dev/null || true; }

part_exists() { [ -b "${DISK}p$1" ]; }
part_start()  { cat "/sys/block/nvme0n1/nvme0n1p$1/start" 2>/dev/null || echo 0; }
part_size()   { cat "/sys/block/nvme0n1/nvme0n1p$1/size" 2>/dev/null || echo 0; }
part_end()    { echo $(($(part_start "$1") + $(part_size "$1"))); }
sectors_to_gib() { awk "BEGIN { printf \"%.1f\", $1 * 512 / 1073741824 }"; }

assert() { local desc="$1"; shift; if "$@"; then ok "$desc"; else die "ASSERT FAILED: $desc"; fi; }

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 0: VERIFY FIX IS IN PLACE
# ═══════════════════════════════════════════════════════════════════════════
log "══════ PHASE 0: Verify disk-fix.sh ran successfully ══════"
echo ""

assert "p8 exists" part_exists 8

P8_END=$(part_end 8)
assert "p8 covers BTRFS (boundary fixed)" test "$P8_END" -ge "$BTRFS_END_SECTOR"
MARGIN=$(sectors_to_gib "$((P8_END - BTRFS_END_SECTOR))")
ok "p8 covers BTRFS with ${MARGIN} GiB margin"

# Check scrub status
echo "Scrub status:"
sudo btrfs scrub status /data 2>/dev/null | head -15 | sed 's/^/  /'
echo ""

SCRUB_STATUS=$(sudo btrfs scrub status /data 2>/dev/null)
if echo "$SCRUB_STATUS" | grep -q "running"; then
    die "Scrub still running. Wait for it to finish before creating p9."
fi

if echo "$SCRUB_STATUS" | grep -qi "uncorrectable" && ! echo "$SCRUB_STATUS" | grep -qP "uncorrectable.*0"; then
    warn "Scrub found uncorrectable errors. Review before proceeding."
    confirm "Proceed anyway despite scrub errors?"
fi

ok "Scrub complete — safe to create p9"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: CREATE p9
# ═══════════════════════════════════════════════════════════════════════════
log ""
log "══════ PHASE 1: Create p9 ══════"
echo ""

if part_exists 9; then
    warn "p9 already exists — deleting first"
    sgdisk -d 9 "$DISK"
    partprobe
fi

log "Creating p9 (100 GiB, label=rust-cache)..."
sgdisk -n 9:0:+100G "$DISK"
sgdisk -c 9:"rust-cache" "$DISK"
sgdisk -t 9:8300 "$DISK"
partprobe
assert "p9 exists" part_exists 9

# Verify no overlap
P9_START=$(part_start 9)
log "p8 ends at sector ${P8_END}, p9 starts at sector ${P9_START}"
assert "p9 does not overlap p8" test "$P9_START" -ge "$P8_END"

log "Formatting p9 as ext4..."
mkfs_ext4 -F -L rust-cache "${DISK}p9"
ok "p9 formatted as ext4 ($(sectors_to_gib "$(part_size 9)") GiB)"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: REPORT
# ═══════════════════════════════════════════════════════════════════════════
log ""
ok "══════ p9 CREATION COMPLETE ══════"
echo ""

echo "Partition table:"
sgdisk -p "$DISK" 2>/dev/null | sed 's/^/  /'
echo ""

echo "Done:"
echo "  ✓ p9 created (100 GiB ext4 /rust-cache)"
echo "  ✓ Verified: no overlap with p8"
echo ""
echo -e "${BLD}NEXT:${NC}"
echo "  1. Deploy updated config: cd ~/projects/SystemNix && nix run .#deploy"
echo ""
echo "  2. After deploy, clear old cargo target:"
echo "     rm -rf ~/projects/monitor365/target"
echo "     (NixOS tmpfiles will symlink to /rust-cache/monitor365)"
