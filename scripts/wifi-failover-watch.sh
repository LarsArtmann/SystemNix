#!/usr/bin/env bash
set -euo pipefail

# wifi-failover-watch — carrier-based standby failover for the static-IP
# ethernet interface.
#
# WHY THIS EXISTS
#   The eno1 default route is static (metric 0). Kernel routes are NOT removed
#   on carrier loss (only on admin down), so pulling the cable leaves the
#   metric-0 default in the table blackholing ALL traffic while the NetworkManager
#   WiFi route (metric 100) sits unused. This daemon deletes the pinned eno1
#   defaults on carrier loss (the NM fallback route takes over instantly) and
#   re-adds the primary route when the cable returns (metric 0 wins again).
#
# DESIGN CONSTRAINTS
#   - CARRIER-based, never ISP-probe-based: transient upstream blips must not
#     evict the primary route (the dual-wan route-health-monitor lesson — it
#     failover'd on 2x 2s probe failures and was disabled for it).
#   - STANDBY model, never ECMP: the fallback interface here is typically a
#     phone hotspot (metered) — no packet splitting, ever.
#   - Idempotent and tolerant: missing interface / missing route / route already
#     present are all no-ops. Only state TRANSITIONS are acted on and logged.

ENO1_IF="${ENO1_IF:-eno1}"
FALLBACK_IF="${FALLBACK_IF:-wlan0}"
GW="${GW:-192.168.1.1}"
POLL="${POLL_INTERVAL:-1}"

log() { echo "wifi-failover: $*"; }

carrier() {
  # Reading /sys/class/net/<if>/carrier fails (EINVAL) while the link is down
  # and the file does not exist when the interface is absent — both mean "no".
  cat "/sys/class/net/${ENO1_IF}/carrier" 2>/dev/null || echo 0
}

has_v4_default() {
  ip -4 route show default 2>/dev/null | grep -Eq "dev ${ENO1_IF}( |$)"
}

del_pinned_defaults() {
  # Delete every default route bound to the ethernet interface, v4 then v6.
  # Loop-guarded: each pass must delete one route or bail out.
  while ip -4 route show default 2>/dev/null | grep -Eq "dev ${ENO1_IF}( |$)"; do
    line="$(ip -4 route show default | grep -E "dev ${ENO1_IF}( |$)" | head -1)"
    log "FAILOVER: carrier lost on ${ENO1_IF} — removing pinned default route (${line})"
    read -r -a route_words <<<"$line"
    ip route del "${route_words[@]}" || break
  done
  while ip -6 route show default 2>/dev/null | grep -Eq "dev ${ENO1_IF}( |$)"; do
    line="$(ip -6 route show default | grep -E "dev ${ENO1_IF}( |$)" | head -1)"
    log "FAILOVER: removing pinned IPv6 default route (${line})"
    read -r -a route_words6 <<<"$line"
    ip -6 route del "${route_words6[@]}" || break
  done
  ip route flush cache 2>/dev/null || true
}

add_primary_default() {
  if has_v4_default; then
    return 0
  fi
  if ip route add default via "${GW}" dev "${ENO1_IF}"; then
    log "RESTORE: carrier back on ${ENO1_IF} — default route via ${GW} re-added (primary again, fallback ${FALLBACK_IF} stays as hot standby)"
    ip route flush cache 2>/dev/null || true
  else
    log "WARN: carrier up on ${ENO1_IF} but could not add default route via ${GW}"
  fi
}

log "starting carrier watch (primary=${ENO1_IF} gw=${GW}, fallback=${FALLBACK_IF}, poll=${POLL}s)"

last="init"
while true; do
  c="$(carrier)"
  if [ "$c" = "1" ]; then
    if [ "$last" != "up" ]; then
      log "${ENO1_IF} carrier UP"
      add_primary_default
    fi
    last="up"
  else
    if [ "$last" != "down" ]; then
      if has_v4_default || ip -6 route show default 2>/dev/null | grep -Eq "dev ${ENO1_IF}( |$)"; then
        del_pinned_defaults
        active="$(ip -4 route show default 2>/dev/null | head -1 || true)"
        log "active default route now: ${active:-NONE (no fallback route present)}"
      fi
    fi
    last="down"
  fi
  sleep "$POLL"
done
