#!/bin/sh
# Display watchdog: detects connected display with no signal and recovers.
#
# Problem: When niri stops/crashes, the DRM output is left in
# enabled=disabled + dpms=Off. The monitor shows "No Signal" but nothing
# self-heals because:
#   - niri-drm-healthcheck only runs when niri IS running (pgrep -x niri)
#   - SDDM's X server may be alive but not driving the connector
#   - The kernel doesn't spontaneously re-enable a dead output
#
# Solution: Check if any connected connector is disabled + DPMS off AND
# no Wayland compositor is running. If so, restart display-manager (SDDM)
# which re-acquires the DRM master and drives the display.
#
# Recovery ladder:
#   1. Restart display-manager (SDDM) — fastest, shows login screen
#   2. If SDDM doesn't come back in 15s, do VT switch to force CRTC re-enable
#   3. After 3 consecutive failures, trigger GPU recovery (driver rebind)

set -eu

STATE_DIR="/var/lib/display-watchdog"
STATE_FILE="$STATE_DIR/consecutive-failures"
RECOVERY_THRESHOLD=3
mkdir -p "$STATE_DIR" 2>/dev/null || true

# Only act if no Wayland compositor is running
pgrep -x niri >/dev/null 2>&1 && exit 0
pgrep -x sway >/dev/null 2>&1 && exit 0
pgrep -x weston >/dev/null 2>&1 && exit 0

# Check for connected-but-disabled displays
dead_display=0
for status_file in /sys/class/drm/card*/status; do
  [ -f "$status_file" ] || continue
  status=$(cat "$status_file" 2>/dev/null || echo "unknown")
  [ "$status" = "connected" ] || continue

  connector_dir=$(dirname "$status_file")
  connector_name=$(basename "$connector_dir")

  enabled=$(cat "$connector_dir/enabled" 2>/dev/null || echo "unknown")
  dpms=$(cat "$connector_dir/dpms" 2>/dev/null || echo "unknown")

  if [ "$enabled" = "disabled" ] && [ "$dpms" = "Off" ]; then
    echo "Dead display detected: $connector_name (enabled=$enabled, dpms=$dpms)"
    dead_display=1
    break
  fi
done

[ "$dead_display" -eq 1 ] || {
  # Display is fine — reset counter
  rm -f "$STATE_FILE"
  exit 0
}

# Dead display detected — increment failure counter
count=0
[ -f "$STATE_FILE" ] && count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" >"$STATE_FILE"

echo "Display watchdog: dead display, attempt $count (threshold=$RECOVERY_THRESHOLD)"

if [ "$count" -lt "$RECOVERY_THRESHOLD" ]; then
  # Attempt 1-2: restart display-manager
  echo "Attempting display-manager restart..."
  systemctl restart display-manager.service 2>/dev/null || true

  # Wait for SDDM to come up and drive the display
  sleep 10

  # Check if it worked — re-read the connector state
  for status_file in /sys/class/drm/card*/status; do
    [ -f "$status_file" ] || continue
    status=$(cat "$status_file" 2>/dev/null || echo "unknown")
    [ "$status" = "connected" ] || continue
    connector_dir=$(dirname "$status_file")
    enabled=$(cat "$connector_dir/enabled" 2>/dev/null || echo "unknown")
    dpms=$(cat "$connector_dir/dpms" 2>/dev/null || echo "unknown")
    if [ "$enabled" = "enabled" ] || [ "$dpms" = "On" ]; then
      echo "Display recovered after display-manager restart"
      rm -f "$STATE_FILE"
      exit 0
    fi
  done

  # SDDM didn't fix it — try VT switch to force CRTC re-enable
  echo "display-manager restart didn't recover display. Forcing VT switch..."
  chvt 1 2>/dev/null || true
  sleep 1
  chvt 2 2>/dev/null || true
  echo "VT switch complete"
else
  # Threshold exceeded — GPU driver is likely wedged
  echo "Display watchdog: $count consecutive failures. Triggering GPU recovery."
  rm -f "$STATE_FILE"
  systemctl start gpu-recovery.service 2>/dev/null || {
    echo "gpu-recovery failed. Rebooting."
    systemctl reboot 2>/dev/null || true
  }
fi
