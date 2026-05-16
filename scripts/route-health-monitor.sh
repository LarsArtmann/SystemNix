#!/usr/bin/env bash
set -euo pipefail

# route-health-monitor — Active-active ECMP with MPTCP for packet-level failover
#
# Architecture:
#   - Both default routes active simultaneously (eno1 + WiFi)
#   - ECMP weights favor eno1 (primary), WiFi gets lower weight
#   - MPTCP creates subflows on BOTH paths — per-packet redundancy
#   - If ISP degrades: WiFi weight increases, eno1 weight decreases
#   - If ISP dies completely: route switches to WiFi-only
#   - If ISP recovers: ECMP restored with eno1 preferred
#
# Failover speed:
#   - MPTCP-aware connections: sub-second (kernel retransmits on surviving subflow)
#   - New TCP connections: instant (route table updated immediately)
#   - Existing non-MPTCP connections: timeout + reconnect (tuned via tcp_retries)

ENO1_GW="${ENO1_GW:-192.168.1.1}"
ENO1_IF="${ENO1_IF:-eno1}"
WIFI_IF="${WIFI_IF:-wlan0}"
LOG_TAG="route-health-monitor"
CHECK_INTERVAL="${CHECK_INTERVAL:-2}"
FAILOVER_THRESHOLD="${FAILOVER_THRESHOLD:-2}"
FAILBACK_THRESHOLD="${FAILBACK_THRESHOLD:-5}"
GATEWAY_TIMEOUT=1
HTTP_TIMEOUT=2

log() { logger -t "$LOG_TAG" "$@"; }

# --- State ---
CURRENT_MODE="eno1-only"
ISP_FAIL_COUNT=0
ISP_OK_COUNT=0
WIFI_AVAILABLE=false
WIFI_GW=""

# --- Helpers ---

set_route_ecmp() {
  local eno1_w="$1"
  local wifi_w="$2"
  local wifi_gw="$3"

  [ -z "$wifi_gw" ] && return 1

  ip route replace default \
    nexthop via "$ENO1_GW" dev "$ENO1_IF" weight "$eno1_w" \
    nexthop via "$wifi_gw" dev "$WIFI_IF" weight "$wifi_w" \
    2>/dev/null
}

set_route_single() {
  local gw="$1" dev="$2"
  ip route replace default via "$gw" dev "$dev" 2>/dev/null
}

check_isp_internet() {
  # Two-phase check: gateway ping + HTTP to public IP
  # Catches partial ISP outages where gateway is up but WAN is down
  if ! ping -c 1 -W "$GATEWAY_TIMEOUT" -I "$ENO1_IF" "$ENO1_GW" >/dev/null 2>&1; then
    return 1
  fi
  # HTTP-level check — bind to eno1 specifically
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null -w '' \
      --connect-timeout "$HTTP_TIMEOUT" \
      --max-time "$HTTP_TIMEOUT" \
      --interface "$ENO1_IF" \
      "http://1.1.1.1" >/dev/null 2>&1
  else
    ping -c 1 -W "$HTTP_TIMEOUT" -I "$ENO1_IF" 1.1.1.1 >/dev/null 2>&1
  fi
}

detect_wifi_gateway() {
  WIFI_GW=""
  WIFI_AVAILABLE=false

  # Auto-detect WiFi interface if configured one doesn't exist
  if ! ip link show "$WIFI_IF" >/dev/null 2>&1; then
    local detected_if
    detected_if=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
      grep ":wifi:connected" | head -1 | cut -d: -f1 || echo "")
    if [ -n "$detected_if" ]; then
      log "AUTO-DETECT: WiFi interface $WIFI_IF not found, using $detected_if"
      WIFI_IF="$detected_if"
    else
      return 1
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
  return 1
}

# --- Initialize ---

detect_initial_mode() {
  # Read the current default route to determine initial state
  # This prevents a service restart from wiping an active WiFi failover
  local route
  route=$(ip route show default 2>/dev/null || echo "")

  if echo "$route" | grep -q "nexthop"; then
    # ECMP multipath route exists — check weights
    if echo "$route" | grep -q "weight 20"; then
      CURRENT_MODE="wifi-heavy"
      log "detected existing wifi-heavy ECMP route on startup"
    else
      CURRENT_MODE="ecmp"
      log "detected existing ECMP route on startup"
    fi
  elif echo "$route" | grep -q "dev $WIFI_IF"; then
    CURRENT_MODE="wifi-only"
    log "detected existing WiFi-only route on startup — preserving failover state"
  else
    CURRENT_MODE="eno1-only"
    log "no existing route or eno1-only route detected"
  fi
}

log "starting ECMP+MPTCP WAN monitor (primary=$ENO1_IF/$ENO1_GW, fallback=$WIFI_IF)"
log "thresholds: failover=${FAILOVER_THRESHOLD} failures, failback=${FAILBACK_THRESHOLD} successes, interval=${CHECK_INTERVAL}s"

# Detect current route state instead of blindly resetting to eno1
detect_initial_mode

# Only set route if no default route exists at all
if [ -z "$(ip route show default 2>/dev/null)" ]; then
  set_route_single "$ENO1_GW" "$ENO1_IF"
  log "no default route found — set eno1 as default"
fi

# --- Main loop ---

while true; do
  detect_wifi_gateway || true

  ISP_OK=false
  if check_isp_internet; then
    ISP_OK=true
  fi

  case "$CURRENT_MODE" in
  ecmp)
    # Both paths active — check if ISP degraded
    if $ISP_OK; then
      ISP_FAIL_COUNT=0
    else
      ISP_FAIL_COUNT=$((ISP_FAIL_COUNT + 1))
      log "ISP degraded in ECMP ($ISP_FAIL_COUNT/$FAILOVER_THRESHOLD)"
      if [ "$ISP_FAIL_COUNT" -ge "$FAILOVER_THRESHOLD" ]; then
        if $WIFI_AVAILABLE; then
          # Shift all weight to WiFi
          set_route_ecmp 1 20 "$WIFI_GW" 2>/dev/null || true
          log "ECMP SHIFT: ISP degraded → WiFi weight=20, eno1 weight=1"
          CURRENT_MODE="wifi-heavy"
        fi
        ISP_FAIL_COUNT=0
      fi
    fi
    ;;

  wifi-heavy)
    # ISP was degraded, WiFi carrying most traffic
    if $ISP_OK; then
      ISP_OK_COUNT=$((ISP_OK_COUNT + 1))
      if [ "$ISP_OK_COUNT" -ge "$FAILBACK_THRESHOLD" ]; then
        # ISP recovered — restore balanced ECMP
        if $WIFI_AVAILABLE; then
          set_route_ecmp 10 3 "$WIFI_GW" 2>/dev/null || true
          log "ECMP RESTORE: ISP recovered → eno1 weight=10, WiFi weight=3"
          CURRENT_MODE="ecmp"
        else
          set_route_single "$ENO1_GW" "$ENO1_IF"
          log "FAILBACK: ISP recovered, WiFi gone → eno1 only"
          CURRENT_MODE="eno1-only"
        fi
        ISP_OK_COUNT=0
        ISP_FAIL_COUNT=0
      fi
    else
      ISP_OK_COUNT=0
      ISP_FAIL_COUNT=$((ISP_FAIL_COUNT + 1))

      # ISP still degraded after shifting — go WiFi-only
      if [ "$ISP_FAIL_COUNT" -ge "$FAILOVER_THRESHOLD" ] && $WIFI_AVAILABLE; then
        set_route_single "$WIFI_GW" "$WIFI_IF"
        log "FAILOVER: ISP dead → WiFi only ($WIFI_IF via $WIFI_GW)"
        CURRENT_MODE="wifi-only"
        ISP_FAIL_COUNT=0
      fi
    fi
    ;;

  wifi-only)
    # ISP was dead, WiFi carrying everything
    if $ISP_OK; then
      ISP_OK_COUNT=$((ISP_OK_COUNT + 1))
      if [ "$ISP_OK_COUNT" -ge "$FAILBACK_THRESHOLD" ]; then
        if $WIFI_AVAILABLE; then
          set_route_ecmp 10 3 "$WIFI_GW" 2>/dev/null || true
          log "FAILBACK: ISP recovered → ECMP (eno1=10, WiFi=3)"
          CURRENT_MODE="ecmp"
        else
          set_route_single "$ENO1_GW" "$ENO1_IF"
          log "FAILBACK: ISP recovered → eno1 only"
          CURRENT_MODE="eno1-only"
        fi
        ISP_OK_COUNT=0
        ISP_FAIL_COUNT=0
      else
        log "ISP recovering ($ISP_OK_COUNT/$FAILBACK_THRESHOLD)"
      fi
    else
      ISP_OK_COUNT=0
      if ! $WIFI_AVAILABLE; then
        log "CRITICAL: both ISP and WiFi down!"
      fi
    fi
    ;;

  eno1-only)
    # WiFi not available or just started — eno1 only
    if $ISP_OK; then
      ISP_FAIL_COUNT=0
      # Try to enable ECMP if WiFi appeared
      if $WIFI_AVAILABLE; then
        if set_route_ecmp 10 3 "$WIFI_GW"; then
          log "ECMP ENABLED: WiFi available → eno1 weight=10, WiFi weight=3"
          CURRENT_MODE="ecmp"
        fi
      fi
    else
      ISP_FAIL_COUNT=$((ISP_FAIL_COUNT + 1))
      if [ "$ISP_FAIL_COUNT" -ge "$FAILOVER_THRESHOLD" ]; then
        if $WIFI_AVAILABLE; then
          set_route_single "$WIFI_GW" "$WIFI_IF"
          log "FAILOVER: ISP down, no ECMP → WiFi only ($WIFI_IF via $WIFI_GW)"
          CURRENT_MODE="wifi-only"
        else
          log "ISP down ($ISP_FAIL_COUNT failures) — no WiFi fallback available"
        fi
        ISP_FAIL_COUNT=0
      fi
    fi
    ;;

  *)
    log "UNKNOWN MODE: $CURRENT_MODE — resetting to eno1"
    set_route_single "$ENO1_GW" "$ENO1_IF"
    CURRENT_MODE="eno1-only"
    ;;
  esac

  sleep "$CHECK_INTERVAL"
done
