#!/bin/sh
# Display watchdog: detects dead display and recovers.
#
# Two scenarios:
#   1. Compositor dead (niri not running) — display left in enabled=disabled + dpms=Off.
#      Nothing self-heals because niri-drm-healthcheck only runs when niri IS running.
#   2. Compositor alive but display dead (GPU pipeline corruption from OOM kills etc).
#      niri process survives but the DRM output is wedged — black screen, no signal.
#
# Recovery ladder:
#   1. If niri alive + display dead → restart niri via systemctl --user -M (re-acquires DRM master)
#   2. If niri dead + display dead → restart display-manager (SDDM)
#   3. After 3 consecutive failures, log critical alert (manual intervention required)

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

niri_alive=0
pgrep -x niri >/dev/null 2>&1 && niri_alive=1
pgrep -x sway >/dev/null 2>&1 && exit 0
pgrep -x weston >/dev/null 2>&1 && exit 0

# Check DRM connector state for any connected display
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

# ── Scenario 1: niri alive but display dead (GPU pipeline corruption) ──────
# This is the OOM-kill-GPU-processes scenario: niri process survives but the
# DRM pipeline is wedged. Restarting niri re-acquires DRM master and resets
# the output pipeline.
if [ "$niri_alive" -eq 1 ]; then
  echo "niri alive but display dead — restarting niri to recover DRM pipeline"
  systemctl --user -M "${PRIMARY_USER:-lars}@" restart niri.service 2>/dev/null || true
  sleep 5

  # Verify recovery
  for status_file in /sys/class/drm/card*/status; do
    [ -f "$status_file" ] || continue
    status=$(cat "$status_file" 2>/dev/null || echo "unknown")
    [ "$status" = "connected" ] || continue
    connector_dir=$(dirname "$status_file")
    enabled=$(cat "$connector_dir/enabled" 2>/dev/null || echo "unknown")
    dpms=$(cat "$connector_dir/dpms" 2>/dev/null || echo "unknown")
    if [ "$enabled" = "enabled" ] || [ "$dpms" = "On" ]; then
      echo "Display recovered after niri restart"
      state_reset
      exit 0
    fi
  done

  # niri restart didn't fix it — escalate
  if state_hit; then
    echo "CRITICAL: Display still dead after $_state_count niri restart attempts. Manual intervention required."
    state_reset
  else
    echo "niri restart didn't recover display (attempt $_state_count/$_state_threshold). Will retry."
  fi
  exit 0
fi

# ── Scenario 2: niri dead + display dead (original logic) ──────────────────
if state_hit; then
  echo "CRITICAL: Display watchdog: $_state_count consecutive failures. Manual intervention required."
  state_reset
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
