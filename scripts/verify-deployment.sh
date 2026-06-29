#!/usr/bin/env bash
# Post-deploy verification script for SystemNix TODO items
# Run this on evo-x2 after deployment to verify blocked items

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

log_pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASS++)) || true
}
log_fail() {
  echo -e "${RED}✗${NC} $1"
  ((FAIL++)) || true
}
log_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARN++)) || true
}
log_info() { echo -e "  → $1"; }

echo "=== SystemNix Post-Deploy Verification ==="
echo "Date: $(date)"
echo ""

# --- Priority 0: Hermes Follow-up -------------------------------------------

echo "--- Hermes Status ---"

if systemctl is-active --quiet hermes.service; then
  log_pass "hermes.service is active"
else
  log_fail "hermes.service is NOT active"
fi

# Check GLM-5.1 rate limit in logs
log_info "Checking GLM-5.1 rate limit logs (last 50 lines)..."
if journalctl -u hermes --since "24 hours ago" -n 50 | grep -qi "rate.*limit\|429\|402"; then
  log_warn "Rate limit errors found in hermes logs — investigate GLM-5.1 usage"
  journalctl -u hermes --since "24 hours ago" | grep -i "rate.*limit\|429\|402" | tail -5
else
  log_pass "No rate limit errors in last 24h"
fi

# Check hermes git remote access
if [ -f /home/hermes/.ssh/id_ed25519 ]; then
  log_pass "hermes SSH key installed"
  if sudo -u hermes ssh -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    log_pass "hermes GitHub SSH authentication works"
  else
    log_warn "hermes GitHub SSH not yet configured — add deploy key to GitHub"
  fi
else
  log_fail "hermes SSH key missing — run scripts/hermes-setup/"
fi

# Check essential Hermes env vars (Discord token is required for the bot gateway)
if [ -f /home/hermes/.env ] && grep -q "DISCORD_BOT_TOKEN" /home/hermes/.env; then
  log_pass "DISCORD_BOT_TOKEN present in hermes .env"
else
  log_warn "DISCORD_BOT_TOKEN missing from hermes .env — check sops template + redeploy"
fi

# Check fallback_model config
if [ -f /home/hermes/config.yaml ] && grep -q "fallback_model" /home/hermes/config.yaml; then
  log_pass "fallback_model configured in hermes config.yaml"
  grep "fallback_model" /home/hermes/config.yaml | head -1
else
  log_warn "fallback_model not set in config.yaml — run: sudo -u hermes hermes config set fallback_model <model>"
fi

# --- Priority 1: Deploy & Verify ---------------------------------------------

echo ""
echo "--- Boot Performance ---"
BOOT_TIME=$(systemd-analyze 2>/dev/null | head -1 | grep -oP '[\d.]+s' | head -1 || echo "unknown")
if [ "$BOOT_TIME" != "unknown" ]; then
  # Extract numeric value
  BT_NUM=$(echo "$BOOT_TIME" | sed 's/s//')
  if (($(echo "$BT_NUM < 60" | bc -l 2>/dev/null || echo "0"))); then
    log_pass "Boot time: $BOOT_TIME (target: <60s)"
  else
    log_warn "Boot time: $BOOT_TIME (target: ~35s, investigate if >60s)"
  fi
else
  log_warn "Could not determine boot time — run: systemd-analyze"
fi

echo ""
echo "--- SigNoz Verification ---"

# Check SigNoz is reachable
if curl -sf http://localhost:8080/api/v1/health 2>/dev/null | grep -q "ok\|healthy"; then
  log_pass "SigNoz health check OK"
else
  log_fail "SigNoz not reachable on localhost:8080"
fi

# Check Discord alert channel
if [ -f /var/lib/signoz/discord-webhook.url ]; then
  WEBHOOK=$(cat /var/lib/signoz/discord-webhook.url)
  if curl -sf -X POST -H "Content-Type: application/json" -d '{"content":"SigNoz test alert"}' "$WEBHOOK" 2>/dev/null; then
    log_pass "Discord webhook delivery works"
  else
    log_warn "Discord webhook test failed — check URL validity"
  fi
else
  log_warn "Discord webhook URL file missing"
fi

# Check provisioned dashboards exist
log_info "Checking SigNoz dashboards..."
DASH_COUNT=$(curl -sf http://localhost:8080/api/v1/dashboards 2>/dev/null | grep -o '"id"' | wc -l || echo "0")
if [ "$DASH_COUNT" -gt 0 ]; then
  log_pass "SigNoz dashboards provisioned: $DASH_COUNT"
else
  log_warn "No SigNoz dashboards found — check provision logs"
fi

# Check alert rules
log_info "Checking SigNoz alert rules..."
RULE_COUNT=$(curl -sf http://localhost:8080/api/v1/rules 2>/dev/null | grep -o '"id"' | wc -l || echo "0")
if [ "$RULE_COUNT" -gt 0 ]; then
  log_pass "SigNoz alert rules active: $RULE_COUNT"
else
  log_warn "No SigNoz alert rules found"
fi

echo ""
echo "--- Gatus Verification ---"

if curl -sf http://localhost:9110/api/v1/endpoints/status 2>/dev/null | grep -q "status"; then
  log_pass "Gatus API reachable on localhost:9110"
else
  log_fail "Gatus not reachable on localhost:9110"
fi

# Check TLS cert expiry monitoring
if curl -sf http://localhost:9110/api/v1/endpoints/status 2>/dev/null | grep -qi "tls\|cert\|expiry"; then
  log_pass "TLS certificate checks present in Gatus"
else
  log_warn "TLS certificate expiry check not found in Gatus"
fi

echo ""
echo "--- General System Health ---"

# Memory/swap (Gatus should be monitoring these)
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')
log_info "Memory: ${MEM_USED}MB / ${MEM_TOTAL}MB used, Swap: ${SWAP_USED}MB used"

# BTRFS snapshot health
if [ -d /mnt/btrfs-root/@snapshots ]; then
  LATEST=$(ls -t /mnt/btrfs-root/@snapshots 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    AGE=$((($(date +%s) - $(stat -c %Y "/mnt/btrfs-root/@snapshots/$LATEST" 2>/dev/null || echo 0)) / 86400))
    if [ "$AGE" -le 3 ]; then
      log_pass "BTRFS snapshot fresh: $LATEST (${AGE}d old)"
    else
      log_warn "BTRFS snapshot stale: $LATEST (${AGE}d old)"
    fi
  else
    log_warn "No BTRFS snapshots found"
  fi
else
  log_warn "BTRFS snapshot directory not mounted"
fi

# Disk usage for /data
DATA_USAGE=$(df -h /data 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "100")
if [ "$DATA_USAGE" -lt 90 ]; then
  log_pass "/data disk usage: ${DATA_USAGE}%"
else
  log_warn "/data disk usage high: ${DATA_USAGE}%"
fi

echo ""
echo "=== Verification Summary ==="
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo -e "${GREEN}All checks passed!${NC}"
  exit 0
elif [ "$FAIL" -eq 0 ]; then
  echo -e "${YELLOW}All critical checks passed, $WARN warnings to review.${NC}"
  exit 0
else
  echo -e "${RED}$FAIL checks failed — manual intervention required.${NC}"
  exit 1
fi
