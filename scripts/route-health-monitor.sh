#!/bin/bash
# route-health-monitor — Active-passive WAN failover
#
# eno1 (ethernet/ISP) is ALWAYS preferred when healthy.
# WiFi (Kittyspot hotspot) is ONLY used when ISP internet is down.
#
# Health check strategy:
#   - Phase 1: ping gateway (link-level check)
#   - Phase 2: HTTP fetch to public endpoints (internet-level check)
#   This catches partial ISP outages where gateway is up but internet is down.
#
# The script uses a consecutive-failure counter to avoid flapping:
#   - 3+ consecutive ISP failures → failover to WiFi
#   - 3+ consecutive ISP recoveries → failback to eno1
#   - This prevents rapid toggling on unstable connections

set -euo pipefail

ENO1_GW="${ENO1_GW:-192.168.1.1}"
ENO1_IF="${ENO1_IF:-eno1}"
WIFI_IF="${WIFI_IF:-wlan0}"
LOG_TAG="route-health-monitor"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
FAILOVER_THRESHOLD="${FAILOVER_THRESHOLD:-3}"
FAILBACK_THRESHOLD="${FAILBACK_THRESHOLD:-3}"
GATEWAY_TIMEOUT=2
HTTP_TIMEOUT=3

log() { logger -t "$LOG_TAG" "$@"; }

# --- State ---
CURRENT_MODE="eno1"
ISP_FAIL_COUNT=0
ISP_OK_COUNT=0
WIFI_AVAILABLE=false
WIFI_GW=""

# --- Helpers ---

set_route() {
  local gw="$1" dev="$2"
  ip route replace default via "$gw" dev "$dev" 2>/dev/null
  log "ROUTE: default via $gw dev $dev"
}

check_gateway() {
  local gw="$1" dev="$2"
  ping -c 1 -W "$GATEWAY_TIMEOUT" -I "$dev" "$gw" >/dev/null 2>&1
}

check_internet() {
  # HTTP-level check — catches partial ISP outages where gateway is up but WAN is down
  # Uses curl with --interface to bind to specific interface
  # Fall back to ping if curl unavailable
  local dev="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null -w '' \
      --connect-timeout "$HTTP_TIMEOUT" \
      --max-time "$HTTP_TIMEOUT" \
      --interface "$dev" \
      "http://1.1.1.1" >/dev/null 2>&1
  else
    ping -c 1 -W "$HTTP_TIMEOUT" -I "$dev" 1.1.1.1 >/dev/null 2>&1
  fi
}

detect_wifi_gateway() {
  WIFI_GW=""
  # Auto-detect WiFi interface if the configured one doesn't exist
  if ! ip link show "$WIFI_IF" >/dev/null 2>&1; then
    # Try to find any WiFi interface managed by NetworkManager
    local detected_if
    detected_if=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
      | grep ":wifi:connected" | head -1 | cut -d: -f1 || echo "")
    if [ -n "$detected_if" ] && [ "$detected_if" != "$WIFI_IF" ]; then
      log "AUTO-DETECT: WiFi interface changed from $WIFI_IF to $detected_if"
      WIFI_IF="$detected_if"
    fi
  fi

  local state
  state=$(nmcli -t -f GENERAL.STATE device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 || echo "")
  if echo "$state" | grep -q "connected"; then
    WIFI_GW=$(nmcli -t -f IP4.GATEWAY device show "$WIFI_IF" 2>/dev/null | cut -d: -f2 || echo "")
    if [ -n "$WIFI_GW" ]; then
      WIFI_AVAILABLE=true
      return 0
    fi
  fi
  WIFI_AVAILABLE=false
  return 1
}

switch_to_wifi() {
  if [ -z "$WIFI_GW" ]; then
    log "FAILOVER BLOCKED: WiFi gateway not available"
    return 1
  fi
  set_route "$WIFI_GW" "$WIFI_IF"
  CURRENT_MODE="wifi"
  log "FAILOVER: ISP down, switched to WiFi ($WIFI_IF via $WIFI_GW)"
}

switch_to_eno1() {
  set_route "$ENO1_GW" "$ENO1_IF"
  CURRENT_MODE="eno1"
  log "FAILBACK: ISP recovered, switched to eno1 ($ENO1_IF via $ENO1_GW)"
}

# --- Main loop ---

log "starting active-passive WAN failover monitor (primary=$ENO1_IF/$ENO1_GW, fallback=$WIFI_IF)"
log "thresholds: failover after ${FAILOVER_THRESHOLD} failures, failback after ${FAILBACK_THRESHOLD} successes"

# Initial route: eno1
set_route "$ENO1_GW" "$ENO1_IF"

while true; do
  # Detect WiFi state every cycle
  detect_wifi_gateway || true

  # Check ISP health: gateway first, then internet
  ISP_GATEWAY_OK=false
  ISP_INTERNET_OK=false

  if check_gateway "$ENO1_GW" "$ENO1_IF"; then
    ISP_GATEWAY_OK=true
    if check_internet "$ENO1_IF"; then
      ISP_INTERNET_OK=true
    fi
  fi

  case "$CURRENT_MODE" in
    eno1)
      if $ISP_INTERNET_OK; then
        # ISP healthy — reset counters
        ISP_FAIL_COUNT=0
      else
        ISP_FAIL_COUNT=$((ISP_FAIL_COUNT + 1))
        if $ISP_GATEWAY_OK && ! $ISP_INTERNET_OK; then
          log "ISP: gateway up but no internet (failure $ISP_FAIL_COUNT/$FAILOVER_THRESHOLD)"
        else
          log "ISP: gateway unreachable (failure $ISP_FAIL_COUNT/$FAILOVER_THRESHOLD)"
        fi

        if [ "$ISP_FAIL_COUNT" -ge "$FAILOVER_THRESHOLD" ] && $WIFI_AVAILABLE; then
          switch_to_wifi
          ISP_FAIL_COUNT=0
          ISP_OK_COUNT=0
        fi
      fi
      ;;

    wifi)
      if $ISP_INTERNET_OK; then
        ISP_OK_COUNT=$((ISP_OK_COUNT + 1))
        if [ "$ISP_OK_COUNT" -ge "$FAILBACK_THRESHOLD" ]; then
          switch_to_eno1
          ISP_OK_COUNT=0
          ISP_FAIL_COUNT=0
        else
          log "ISP: recovering ($ISP_OK_COUNT/$FAILBACK_THRESHOLD consecutive successes)"
        fi
      else
        # ISP still down while on WiFi — reset recovery counter
        ISP_OK_COUNT=0
      fi

      # Also check WiFi is still alive
      if ! $WIFI_AVAILABLE; then
        log "CRITICAL: WiFi lost while ISP is down — no connectivity"
        # Stay on wifi mode but log aggressively
      fi
      ;;

    *)
      log "UNKNOWN MODE: $CURRENT_MODE — resetting to eno1"
      set_route "$ENO1_GW" "$ENO1_IF"
      CURRENT_MODE="eno1"
      ;;
  esac

  sleep "$CHECK_INTERVAL"
done
