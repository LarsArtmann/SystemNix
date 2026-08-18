#!/usr/bin/env bash
# Detects niri DRM zombie state and triggers recovery.
#
# Two detection methods:
#   1. Display signal check: connected display with enabled=disabled + dpms=Off
#      while niri is running means the GPU pipeline is wedged.
#   2. niri journal errors: "Permission denied" or "DeviceMissing" in recent logs.
#
# Display death uses a lower threshold (2 consecutive checks) because GPU
# corruption only gets worse with time. Journal errors use threshold 3.

set -euo pipefail

STATE_DIR="/var/lib/niri-drm-healthcheck"
mkdir -p "$STATE_DIR" 2>/dev/null || true

read_count() {
  if [ -f "$STATE_DIR/$1" ]; then
    cat "$STATE_DIR/$1" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

write_count() {
  echo "$2" >"$STATE_DIR/$1"
}

reset_count() {
  rm -f "$STATE_DIR/$1"
}

pgrep -x niri >/dev/null 2>&1 || {
  reset_count display
  reset_count journal
  exit 0
}

# ── Login-screen guard (same rationale as display-watchdog.sh) ────────────
# niri running with NO user graphical session is the lingering-boot /
# login-screen state: it is headless BY DESIGN there (no seat, no outputs —
# hence the "error doing early import: DeviceMissing" spam). Restarting
# cannot attach outputs (the restarted instance is just as headless) and
# only churns the session every DISPLAY_THRESHOLD checks — the 2026-08-18
# two-minute restart loop that kept disrupting greeter/logins. Only act
# when a real graphical session exists.
has_graphical_session=0
found=$(
  loginctl list-sessions --no-legend 2>/dev/null |
    while read -r sid _rest; do
      c=$(loginctl show-session "$sid" -p Class --value 2>/dev/null || true)
      t=$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)
      if [ "$c" = "user" ] && { [ "$t" = "wayland" ] || [ "$t" = "x11" ]; }; then
        echo 1
      fi
    done
) || found=""
case "$found" in
*1*) has_graphical_session=1 ;;
esac

if [ "$has_graphical_session" -eq 0 ]; then
  echo "niri running but no user graphical session (login screen / SSH-only) — headless is expected, not recovering."
  reset_count display
  reset_count journal
  exit 0
fi

# ── Check 1: Display signal (highest priority) ─────────────────────────────
# If niri is running but a connected display has enabled=disabled + dpms=Off,
# the GPU pipeline is corrupted (e.g., from earlyoom killing GPU processes).
# This is more reliable than journal grepping because niri may not log errors
# for a wedged DRM pipeline.
DISPLAY_THRESHOLD=2

dead_display=0
for status_file in /sys/class/drm/card*/status; do
  [ -f "$status_file" ] || continue
  status=$(cat "$status_file" 2>/dev/null || echo "unknown")
  [ "$status" = "connected" ] || continue

  connector_dir=$(dirname "$status_file")
  enabled=$(cat "$connector_dir/enabled" 2>/dev/null || echo "unknown")
  dpms=$(cat "$connector_dir/dpms" 2>/dev/null || echo "unknown")

  if [ "$enabled" = "disabled" ] && [ "$dpms" = "Off" ]; then
    echo "Dead display while niri running: $(basename "$connector_dir") (enabled=$enabled, dpms=$dpms)"
    dead_display=1
    break
  fi
done

if [ "$dead_display" -eq 1 ]; then
  count=$(read_count display)
  count=$((count + 1))
  write_count display "$count"

  if [ "$count" -ge "$DISPLAY_THRESHOLD" ]; then
    echo "Display dead for $count consecutive checks (threshold=$DISPLAY_THRESHOLD). Restarting niri."
    reset_count display
    systemctl --user restart niri.service 2>/dev/null || true
  else
    echo "Display dead, check $count/$DISPLAY_THRESHOLD. Waiting for confirmation."
  fi
  exit 0
else
  reset_count display
fi

# ── Check 2: niri journal DRM errors ───────────────────────────────────────
JOURNAL_THRESHOLD=3

# wc under pipefail can emit "0\n0" when journalctl fails (e.g. this unit
# also runs for the SDDM user manager) — normalize instead of trusting it.
drm_errors=$(journalctl --grep "Permission denied|DeviceMissing" --user -u niri -n 11 --since "30 sec ago" --no-pager --output cat 2>/dev/null |
  wc -l) || true
drm_errors="${drm_errors:-0}"
drm_errors=$(echo "$drm_errors" | tr -cd '0-9')
drm_errors="${drm_errors:-0}"

if [ "$drm_errors" -ge 10 ]; then
  count=$(read_count journal)
  count=$((count + 1))
  write_count journal "$count"

  if [ "$count" -ge "$JOURNAL_THRESHOLD" ]; then
    echo "niri DRM zombie confirmed ($count consecutive checks). Restarting niri."
    reset_count journal
    systemctl --user restart niri.service 2>/dev/null || true
  else
    echo "niri DRM errors detected ($drm_errors in 30s, check $count/$JOURNAL_THRESHOLD). Waiting for confirmation."
  fi
else
  reset_count journal
fi
