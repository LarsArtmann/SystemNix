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
# Recovery ladder:
#   1. Restart display-manager (SDDM) — fastest, shows login screen
#   2. If SDDM doesn't come back in 15s, do VT switch to force CRTC re-enable
#   3. After 3 consecutive failures, trigger GPU recovery (driver rebind)

set -eu

# --- State persistence (inlined from lib.sh — writeShellApplication breaks relative sourcing) ---
_state_dir=""
_state_file=""
_state_threshold=0
_state_count=0

state_init() {
  _state_dir="$1"
  _state_file="$1/$2"
  _state_threshold="$3"
  _state_count=0
  mkdir -p "$_state_dir" 2>/dev/null || true
}

state_hit() {
  if [ -f "$_state_file" ]; then
    _state_count=$(cat "$_state_file" 2>/dev/null || echo 0)
  fi
  _state_count=$((_state_count + 1))
  echo "$_state_count" >"$_state_file"
  [ "$_state_count" -ge "$_state_threshold" ]
}

state_reset() {
  rm -f "$_state_file"
  _state_count=0
}

state_init "/var/lib/display-watchdog" "consecutive-failures" 3

pgrep -x niri >/dev/null 2>&1 && exit 0
pgrep -x sway >/dev/null 2>&1 && exit 0
pgrep -x weston >/dev/null 2>&1 && exit 0

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
  state_reset
  exit 0
}

if state_hit; then
  echo "Display watchdog: $_state_count consecutive failures. Triggering GPU recovery."
  state_reset
  systemctl start gpu-recovery.service 2>/dev/null || {
    echo "gpu-recovery failed. Rebooting."
    systemctl reboot 2>/dev/null || true
  }
else
  echo "Display watchdog: dead display, attempt $_state_count (threshold=$_state_threshold)"

  echo "Attempting display-manager restart..."
  systemctl restart display-manager.service 2>/dev/null || true
  sleep 10

  for status_file in /sys/class/drm/card*/status; do
    [ -f "$status_file" ] || continue
    status=$(cat "$status_file" 2>/dev/null || echo "unknown")
    [ "$status" = "connected" ] || continue
    connector_dir=$(dirname "$status_file")
    enabled=$(cat "$connector_dir/enabled" 2>/dev/null || echo "unknown")
    dpms=$(cat "$connector_dir/dpms" 2>/dev/null || echo "unknown")
    if [ "$enabled" = "enabled" ] || [ "$dpms" = "On" ]; then
      echo "Display recovered after display-manager restart"
      state_reset
      exit 0
    fi
  done

  echo "display-manager restart didn't recover display. Forcing VT switch..."
  chvt 1 2>/dev/null || true
  sleep 1
  chvt 2 2>/dev/null || true
  echo "VT switch complete"
fi
