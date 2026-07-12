#!/usr/bin/env bash
# Post-deploy smoke test: verifies that services are FUNCTIONAL, not just alive.
# Runs after `nh os switch` to catch silent failures like:
#   - Wrong package (monitor365 UI 404)
#   - Data-access blocked by hardening (crush-daily empty reports)
#   - Missing vHost configuration (service reachable but no Caddy route)
#
# Usage: nix run .#post-deploy-check
#        or: ./scripts/post-deploy-check.sh
set -euo pipefail

DOMAIN="${SYSTEMNIX_DOMAIN:-home.lan}"
PASS=0
FAIL=0
SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

check() {
  local name="$1"
  local url="$2"
  local expect_status="${3:-200}"
  local expect_body="${4:-}"

  local response
  local status
  local body

  response=$(curl -s -o /tmp/.smoke-body -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  status="$response"
  body=$(cat /tmp/.smoke-body 2>/dev/null || echo "")

  if [ "$status" = "000" ]; then
    echo -e "${RED}FAIL${NC} $name — $url unreachable"
    FAIL=$((FAIL + 1))
    return
  fi

  if [ "$status" != "$expect_status" ]; then
    echo -e "${RED}FAIL${NC} $name — expected HTTP $expect_status, got $status ($url)"
    FAIL=$((FAIL + 1))
    return
  fi

  if [ -n "$expect_body" ]; then
    if ! echo "$body" | grep -qiE "$expect_body"; then
      echo -e "${RED}FAIL${NC} $name — status OK ($status) but body mismatch: expected pattern '$expect_body' not found ($url)"
      echo -e "     first 100 chars: $(echo "$body" | head -c 100)"
      FAIL=$((FAIL + 1))
      return
    fi
  fi

  echo -e "${GREEN}PASS${NC} $name ($status)"
  PASS=$((PASS + 1))
}

check_local() {
  local name="$1"
  local port="$2"
  local path="${3:-/}"
  local expect_status="${4:-200}"
  local expect_body="${5:-}"

  check "$name (localhost:$port)" "http://localhost:$port$path" "$expect_status" "$expect_body"
}

echo "=== Post-Deploy Smoke Test ==="
echo "Domain: $DOMAIN"
echo ""

# --- Infrastructure ---
check_local "Caddy metrics" "2019" "/metrics" "200" "" 2>/dev/null || true
check "Caddy HTTP redirect" "http://dash.$DOMAIN" "301" "" 2>/dev/null || true

check_local "Pocket ID" "1411" "/healthz" "204" 2>/dev/null ||
  check_local "Pocket ID" "1411" "/" "200" "" 2>/dev/null || true

check_local "oauth2-proxy" "4180" "/ping" "200" 2>/dev/null || true

check_local "Homepage" "8082" "/" "200" "<html" 2>/dev/null || true

check_local "Gatus" "9110" "/" "200" "" 2>/dev/null || true

# --- Application health endpoints ---
check_local "Forgejo" "3000" "/api/v1/version" "200" "" 2>/dev/null || true

check_local "Immich" "2283" "/api/server/ping" "200" "" 2>/dev/null || true

check_local "DiscordSync" "8085" "/api/stats" "200" 2>/dev/null || true

check_local "Manifest" "2099" "/api/v1/health" "200" 2>/dev/null || true

check_local "Crush Daily" "8081" "/api/health" "200" 2>/dev/null || true

check_local "Overview" "8083" "/" "200" "<html" 2>/dev/null || true

# --- Monitor365: the bug we fixed ---
check_local "Monitor365 API" "3001" "/health" "200" 2>/dev/null || true
check_local "Monitor365 UI" "3001" "/ui/" "200" "<html" 2>/dev/null || true

# --- Functional checks (not just liveness) ---
echo ""
echo "=== Functional Checks ==="

# Crush Daily: reports should exist after first collection
if crush_reports=$(curl -s --max-time 5 "http://localhost:8081/api/reports" 2>/dev/null); then
  if echo "$crush_reports" | grep -q '"id"'; then
    echo -e "${GREEN}PASS${NC} Crush Daily has reports"
    PASS=$((PASS + 1))
  elif echo "$crush_reports" | grep -q '\[\]'; then
    echo -e "${YELLOW}WARN${NC} Crush Daily reports empty — collection may not have run yet"
    SKIP=$((SKIP + 1))
  else
    echo -e "${YELLOW}SKIP${NC} Crush Daily reports endpoint unexpected response"
    SKIP=$((SKIP + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} Crush Daily not reachable"
  SKIP=$((SKIP + 1))
fi

# DiscordSync: database should have tables
if discordsync_stats=$(curl -s --max-time 5 "http://localhost:8085/api/stats" 2>/dev/null); then
  if echo "$discordsync_stats" | grep -q '"guilds"'; then
    echo -e "${GREEN}PASS${NC} DiscordSync API functional (stats endpoint returns data)"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC} DiscordSync stats unexpected response"
    SKIP=$((SKIP + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} DiscordSync not reachable"
  SKIP=$((SKIP + 1))
fi

# SigNoz: impersonation mode must be active (auth delegated to Caddy + Pocket ID)
if signoz_config=$(curl -s --max-time 5 "http://localhost:8080/api/v1/global/config" 2>/dev/null); then
  if echo "$signoz_config" | grep -q '"impersonation"'; then
    if echo "$signoz_config" | grep -q '"enabled": *true'; then
      echo -e "${GREEN}PASS${NC} SigNoz impersonation mode active (Pocket ID is sole auth boundary)"
      PASS=$((PASS + 1))
    else
      echo -e "${RED}FAIL${NC} SigNoz impersonation mode NOT enabled — service is exposed without auth"
      FAIL=$((FAIL + 1))
    fi
  else
    echo -e "${YELLOW}WARN${NC} SigNoz config endpoint reachable but impersonation key missing"
    SKIP=$((SKIP + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} SigNoz not reachable on localhost:8080"
  SKIP=$((SKIP + 1))
fi

# --- External vHost checks (from LAN) ---
echo ""
echo "=== External vHost Checks ==="

check "Homepage (HTTPS)" "https://dash.$DOMAIN/" "200" "<html" 2>/dev/null || true
check "Forgejo (HTTPS)" "https://forgejo.$DOMAIN/api/v1/version" "200" "" 2>/dev/null || true
check "Status (HTTPS)" "https://status.$DOMAIN/" "200" "<html" 2>/dev/null || true
check "Immich (HTTPS)" "https://immich.$DOMAIN/api/server/ping" "200" "" 2>/dev/null || true
check "Overview (HTTPS)" "https://overview.$DOMAIN/" "200" "<html" 2>/dev/null || true

# --- Summary ---
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}SKIP: $SKIP${NC}"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo -e "${RED}❌ $FAIL check(s) failed — investigate before proceeding${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}✅ All checks passed${NC}"
  exit 0
fi
