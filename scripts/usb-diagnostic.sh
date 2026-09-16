#!/usr/bin/env bash
set -euo pipefail

# Explicit device REQUIRED — kernel sd-letters reshuffle on every replug, so a
# /dev/sda default diagnoses whatever drive happened to grab the name.
if [ $# -ne 1 ]; then
  echo "usage: $0 <device>   (e.g. /dev/disk/by-id/… or /dev/sdb — NO default)" >&2
  exit 2
fi
DEV="$1"
[ -e "$DEV" ] || { echo "✗ $DEV does not exist" >&2; exit 2; }
BASENAME=$(basename "$DEV")
# Partition suffix is device-type dependent (nvme → p1); probe both forms.
if [ -e "${DEV}1" ]; then
  PART="${DEV}1"
elif [ -e "${DEV}p1" ]; then
  PART="${DEV}p1"
else
  PART="${DEV}1"
fi
echo "========================================"
echo "  USB Stick Diagnostic Report — $DEV"
echo "========================================"
echo ""

echo "=== Device Info ==="
lsblk -o NAME,SIZE,VENDOR,MODEL,MOUNTPOINT,LABEL,FSTYPE,UUID "$DEV"
echo ""

echo "=== Mount Status ==="
findmnt "$DEV" 2>/dev/null || echo "Not mounted"
findmnt "$PART" 2>/dev/null || echo "$PART not mounted"
grep -w "$BASENAME" /proc/mounts || echo "No $BASENAME entries in /proc/mounts"
echo ""

echo "=== Swap on $BASENAME? ==="
swapon --show 2>/dev/null | grep -w "$BASENAME" || echo "No swap on $BASENAME"
grep -w "$BASENAME" /proc/swaps 2>/dev/null || echo "No $BASENAME in /proc/swaps"
echo ""

echo "=== Kernel Disk Stats ==="
cat /sys/block/$BASENAME/stat 2>/dev/null || echo "Device /sys/block/$BASENAME/stat not found"
echo ""
echo "Fields: reads_completed reads_merged sectors_read ms_reading writes_completed writes_merged sectors_written ms_writing ios_in_progress ms_doing_io weighted_ms_doing_io"
echo ""

echo "=== I/O Stats (3 samples, 2s apart) ==="
iostat -d "$DEV" 2 3 2>/dev/null || echo "iostat not available"
echo ""

echo "=== Processes Using the Device (fuser) ==="
timeout 15 sudo fuser -vm "$DEV" "$PART" 2>&1 || echo "No processes found by fuser (or probe timed out)"
echo ""

echo "=== Open Files on Device (lsof) ==="
timeout 15 sudo lsof "$DEV" "$PART" 2>&1 || echo "Nothing open (or probe timed out)"
echo ""

echo "=== Udev Info ==="
udevadm info --query=all --name="$DEV" 2>/dev/null | head -30 || true
echo ""

echo "=== SMART/Health (if available) ==="
# timeout: this script runs DURING USB wedges — an unbounded smartctl against a
# hung bridge hangs the diagnostic itself. head closes early → SIGPIPE under
# pipefail, hence || true.
timeout 30 sudo smartctl -a "$DEV" 2>&1 | head -40 || echo "smartctl unavailable or timed out (30s) — a hang here IS a finding (wedged bridge)"
echo ""

echo "=== Kernel Messages (this boot) ==="
timeout 15 journalctl -k -b --grep "$BASENAME|san|usb" --no-pager -n 20 || true
echo ""

echo "=== Per-Process I/O (top writers) ==="
echo "PID  COMM           WRITE_KB  READ_KB"
for pid in /proc/[0-9]*; do
  pname=$(cat "$pid/comm" 2>/dev/null) || continue
  w=$(awk '/write_bytes/{print $2}' "$pid/io" 2>/dev/null) || continue
  r=$(awk '/read_bytes/{print $2}' "$pid/io" 2>/dev/null) || continue
  if [ "$w" -gt 1000000 ] 2>/dev/null || [ "$r" -gt 1000000 ] 2>/dev/null; then
    echo "$(basename "$pid")  $pname  $((w / 1024))  $((r / 1024))"
  fi
done | sort -t' ' -k3 -n -r | head -20 || true
echo ""

echo "=== Live I/O Snapshot (3s delta) ==="
read1=$(cat /sys/block/$BASENAME/stat 2>/dev/null || echo "0 0 0 0 0 0 0 0 0 0 0")
sleep 3
read2=$(cat /sys/block/$BASENAME/stat 2>/dev/null || echo "0 0 0 0 0 0 0 0 0 0 0")
echo "Before: $read1"
echo "After:  $read2"

read -ra f1 <<<"$read1"
read -ra f2 <<<"$read2"
echo ""
echo "  Reads completed:     ${f1[0]} → ${f2[0]} (delta: $((f2[0] - f1[0])))"
echo "  Sectors read:        ${f1[2]} → ${f2[2]} (delta: $((f2[2] - f1[2])) sectors = $(((f2[2] - f1[2]) * 512 / 1024 / 1024)) MB)"
echo "  Writes completed:    ${f1[4]} → ${f2[4]} (delta: $((f2[4] - f1[4])))"
echo "  Sectors written:     ${f1[6]} → ${f2[6]} (delta: $((f2[6] - f1[6])) sectors = $(((f2[6] - f1[6]) * 512 / 1024 / 1024)) MB)"
echo ""

echo "========================================"
echo "  Report Complete"
echo "========================================"
