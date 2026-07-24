#!/usr/bin/env bash
# DNS diagnostics — works even during partial outages.
# Tools (dig, curl, ss) are installed system-wide via base.nix.
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "========== DNS DIAGNOSTICS =========="
echo ""

# --- 1. Physical / network connectivity ---
echo "--- Network Connectivity ---"
DEFAULT_ROUTE=$(ip route show default 2>/dev/null | head -1)
if [ -n "$DEFAULT_ROUTE" ]; then
  GATEWAY=$(echo "$DEFAULT_ROUTE" | awk '{print $3}')
  ok "Default route: $DEFAULT_ROUTE"
  if ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
    ok "Gateway $GATEWAY reachable"
  else
    fail "Gateway $GATEWAY UNREACHABLE — check physical cable / switch / router"
  fi
else
  fail "No default route — network interface may be down"
fi

# Check upstream connectivity (bypass DNS — use raw IPs)
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
  ok "Upstream IP reachable (1.1.1.1)"
else
  fail "Upstream IP unreachable (1.1.1.1) — router/WAN issue, NOT DNS"
fi
echo ""

# --- 2. DNS services ---
echo "--- DNS Services ---"
for svc in dnsblockd dnsblockd-attach-ip; do
  STATE=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
  if [ "$STATE" = "active" ]; then
    ok "$svc: active"
  else
    fail "$svc: $STATE"
  fi
done
echo ""

# --- 3. What's listening on :53 ---
echo "--- Port 53 Listeners ---"
ss -tulpn 2>/dev/null | grep ':53 ' || warn "Nothing listening on :53"
echo ""

# --- 4. DNS resolution test (via local resolver) ---
echo "--- DNS Resolution (local :53) ---"
if command -v dig >/dev/null 2>&1; then
  RESULT=$(dig @127.0.0.1 google.com +short +time=3 +tries=1 2>/dev/null | head -1)
  if [ -n "$RESULT" ]; then
    ok "google.com resolves to $RESULT"
  else
    fail "google.com did NOT resolve via local :53"
  fi
else
  warn "dig not installed — run 'nix run .#dns-diagnostics' or install bind.dnsutils"
fi
echo ""

# --- 5. DNS blocking test ---
echo "--- DNS Blocking ---"
if command -v dig >/dev/null 2>&1; then
  BLOCK_RESULT=$(dig @127.0.0.1 doubleclick.net +short +time=3 +tries=1 2>/dev/null | head -1)
  if [ -n "$BLOCK_RESULT" ]; then
    ok "doubleclick.net → $BLOCK_RESULT (blocked = sinkhole IP)"
  else
    warn "doubleclick.net returned empty (may not be blocked, or resolution failed)"
  fi
fi
echo ""

# --- 6. Direct upstream DNS test (bypass local resolver) ---
echo "--- Upstream DNS Forwarder Test ---"
if command -v dig >/dev/null 2>&1; then
  UPSTREAM=$(dig @9.9.9.9 google.com +short +time=3 +tries=1 2>/dev/null | head -1)
  if [ -n "$UPSTREAM" ]; then
    ok "Upstream DNS (9.9.9.9) resolves google.com → $UPSTREAM"
  else
    fail "Upstream DNS (9.9.9.9) unreachable — WAN/internet connectivity issue"
  fi
fi
echo ""

# --- 7. dnsblockd stats ---
echo "--- dnsblockd Stats ---"
STATS=$(curl -sf http://127.0.0.1:9090/stats 2>/dev/null)
if [ -n "$STATS" ]; then
  echo "$STATS" | jq -r '"Queries: \(.dnsQueries) | Blocks: \(.dnsBlocks) | Blocked: \(.totalBlocked) | Uptime: \(.uptime)"' 2>/dev/null || echo "$STATS"
else
  warn "dnsblockd stats unavailable (is the stats endpoint on :9090?)"
fi
echo ""

# --- 8. Summary ---
echo "========== SUMMARY =========="
if [ -n "${GATEWAY:-}" ] && ping -c 1 -W 2 "$GATEWAY" >/dev/null 2>&1; then
  if command -v dig >/dev/null 2>&1 && [ -n "${RESULT:-}" ]; then
    ok "DNS is WORKING"
  else
    fail "Gateway reachable but DNS resolution failing — check dnsblockd"
  fi
else
  fail "Network connectivity issue — NOT a DNS problem. Check cables/switch/router."
fi
