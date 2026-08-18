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
WARN=0

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

  # --compressed: curl ≥8.2x advertises Accept-Encoding by default; servers then
  # gzip the body which an un-decoded grep can never match (phantom "unexpected response")
  response=$(curl -s --compressed -o /tmp/.smoke-body -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || true)
  status="$response"

  if [ "$status" = "000" ]; then
    echo -e "${RED}FAIL${NC} $name — $url unreachable"
    FAIL=$((FAIL + 1))
    return 1
  fi

  if [ "$status" != "$expect_status" ]; then
    echo -e "${RED}FAIL${NC} $name — expected HTTP $expect_status, got $status ($url)"
    FAIL=$((FAIL + 1))
    return 1
  fi

  # Read pattern directly from the body file instead of piping through echo.
  # With `set -o pipefail`, `echo "$body" | grep -q` on a large body (>64KB pipe
  # buffer) fails because grep exits at the first match, echo gets SIGPIPE (141)
  # writing the remainder, and pipefail makes the whole pipeline return 141.
  # `! 141` is then treated as success, producing a false FAIL. Reading the file
  # directly avoids the pipe entirely.
  if [ -n "$expect_body" ]; then
    if ! grep -qiE "$expect_body" /tmp/.smoke-body 2>/dev/null; then
      echo -e "${RED}FAIL${NC} $name — status OK ($status) but body mismatch: expected pattern '$expect_body' not found ($url)"
      echo -e "     first 100 chars: $(head -c 100 /tmp/.smoke-body 2>/dev/null)"
      FAIL=$((FAIL + 1))
      return 1
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

# Report helpers for non-HTTP checks (system state, timers, journals, etc.)
report_pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}
report_fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}
report_skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP=$((SKIP + 1))
}
report_warn() {
  echo -e "${YELLOW}WARN${NC} $1"
  WARN=$((WARN + 1))
}

echo "=== Post-Deploy Smoke Test ==="
echo "Domain: $DOMAIN"
echo ""

# --- Infrastructure ---
check_local "Caddy metrics" "2019" "/metrics" "200" "" 2>/dev/null || true
check "Caddy HTTP redirect" "http://dash.$DOMAIN" "301" "" 2>/dev/null || true

check_local "Pocket ID" "1411" "/healthz" "204" 2>/dev/null ||
  check_local "Pocket ID" "1411" "/" "200" "" 2>/dev/null || true

# Pocket ID: scan recent journal for SQLITE_BUSY or francis panics.
# Write to file then grep — avoids pipefail SIGPIPE trap on large journal output.
journalctl -u pocket-id.service --since "-30min" --no-pager 2>/dev/null >/tmp/.smoke-pocket-id || true
if grep -qEi "SQLITE_BUSY|panic" /tmp/.smoke-pocket-id 2>/dev/null; then
  report_fail "Pocket ID — SQLITE_BUSY or panic in recent journal (run: journalctl -u pocket-id --since -30min)"
else
  report_pass "Pocket ID — no SQLITE_BUSY or panics in recent journal"
fi

check_local "oauth2-proxy" "4180" "/ping" "200" 2>/dev/null || true

check_local "Homepage" "8082" "/" "200" "<html" 2>/dev/null || true

check_local "Gatus" "9110" "/" "200" "" 2>/dev/null || true

check_local "DNS Blocker" "9090" "/health" "200" "" 2>/dev/null || true

# DNS: verify local resolution via dnsblockd
if getent hosts "dash.$DOMAIN" >/dev/null 2>&1; then
  report_pass "DNS — dash.$DOMAIN resolves"
else
  report_fail "DNS — dash.$DOMAIN does not resolve (dnsblockd local zone misconfigured)"
fi

# DNS: dnsblockd memory must stay under 2G
_dns_rss=$(systemctl show -p MemoryCurrent --value dnsblockd 2>/dev/null || echo "0")
if [ "$_dns_rss" -gt 0 ] 2>/dev/null && [ "$_dns_rss" -lt 2147483648 ]; then
  report_pass "DNS — dnsblockd memory $((_dns_rss / 1048576))MB (<2G)"
elif [ "$_dns_rss" -gt 0 ] 2>/dev/null; then
  report_fail "DNS — dnsblockd memory $((_dns_rss / 1048576))MB (exceeds 2G limit)"
else
  report_skip "DNS — cannot determine dnsblockd memory"
fi

# --- Application health endpoints ---
check_local "Forgejo" "3000" "/api/v1/version" "200" "" 2>/dev/null || true

check_local "Immich" "2283" "/api/server/ping" "200" "" 2>/dev/null || true

# DiscordSync: API server binds AFTER the thumb-hash backfill completes
# (~5-11 min after restart, depending on attachment count). Retry to distinguish
# "in startup backfill" (SKIP) from "crashed" (FAIL). Uses /healthz (fast) not
# /api/stats (can take 10+ seconds on a fully loaded instance).
discordsync_ready=false
for _ in 1 2 3; do
  if [ "$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:8085/healthz" 2>/dev/null || true)" = "200" ]; then
    discordsync_ready=true
    break
  fi
  sleep 5
done
if [ "$discordsync_ready" = true ]; then
  echo -e "${GREEN}PASS${NC} DiscordSync (localhost:8085) (200)"
  PASS=$((PASS + 1))
elif pgrep -f discordsync >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} DiscordSync (localhost:8085) — process alive but API not ready (startup backfill in progress)"
  SKIP=$((SKIP + 1))
else
  echo -e "${RED}FAIL${NC} DiscordSync (localhost:8085) — process not running and API unreachable"
  FAIL=$((FAIL + 1))
fi

check_local "Manifest" "2099" "/api/v1/health" "200" 2>/dev/null || true

check_local "Crush Daily" "8081" "/api/health" "200" 2>/dev/null || true

check_local "Overview" "8083" "/" "200" "<html" 2>/dev/null || true

# --- Monitor365: the bug we fixed ---
# Monitor365 is intentionally disabled on evo-x2 (private-git-dep blocker — see
# configuration.nix). When its units are absent from systemd, SKIP instead of
# FAILing a deliberately-off service (red FAILs on known-off services breed alert fatigue).
m365_enabled=false
systemctl list-unit-files 'monitor365*' --no-legend 2>/dev/null | grep -q monitor365 && m365_enabled=true

if $m365_enabled; then
  check_local "Monitor365 API" "3001" "/health" "200" 2>/dev/null || true
  check_local "Monitor365 UI" "3001" "/ui/" "200" "<html" 2>/dev/null || true
else
  echo -e "${YELLOW}SKIP${NC} Monitor365 API/UI — service disabled (units absent from systemd)"
  SKIP=$((SKIP + 1))
fi

check_local "File Renamer" "8086" "/status" "200" "" 2>/dev/null || true

check_local "OpenSEO" "3002" "/" "200" "<html" 2>/dev/null || true

check_local "SearXNG" "8889" "/healthz" "200" 2>/dev/null || true

# SearXNG: functional search test (HTML mode — JSON API is disabled by design).
# Write to file then grep — avoids pipefail SIGPIPE trap on large HTML bodies.
if curl -s --compressed --max-time 10 -o /tmp/.smoke-searx "http://localhost:8889/search?q=test" 2>/dev/null; then
  if grep -qi 'article\|<h4\|result-default' /tmp/.smoke-searx 2>/dev/null; then
    report_pass "SearXNG — functional search returns results"
  else
    report_fail "SearXNG — search returned no results (engine init may have failed at boot)"
  fi
else
  report_skip "SearXNG — search endpoint not reachable"
fi

check_local "Attic cache" "8200" "/" "200" 2>/dev/null || true

# FastFlowLM: FULL end-to-end through the public socket-activated port. This is
# the only check that can catch a dead :52625 (the 2026-08-18 incident: the
# proxy ExecStart'd a binary nixpkgs doesn't build → exit 127 → start-limit-hit
# → systemd deactivated the socket; endpoint refused connections for hours
# while all liveness checks stayed green). Gatus must NOT probe this port
# (every connection pins the 13.6 GB model for another keepAlive window), so
# this deploy-time smoke is the sole functional gate. First connection after
# idle-stop cold-loads the model (1-3 min) — max-time covers it.
flm_enabled=false
systemctl list-unit-files 'fastflowlm*' --no-legend 2>/dev/null | grep -q fastflowlm && flm_enabled=true

if $flm_enabled; then
  # Deliberate connection: re-arms the whole socket→proxy→backend chain.
  if curl -s --compressed --max-time 240 -o /tmp/.smoke-flm "http://127.0.0.1:52625/v1/models" 2>/dev/null; then
    if grep -q '"data"' /tmp/.smoke-flm 2>/dev/null; then
      report_pass "FastFlowLM — /v1/models through socket-activated :52625 (model now pinned ≤ keepAlive)"
    else
      report_fail 'FastFlowLM — :52625 answered but /v1/models body lacks "data" — proxy chain up, backend wrong'
    fi
  else
    report_fail "FastFlowLM — :52625 unreachable: socket dead or proxy/backend broken (journalctl -u 'fastflowlm*' -n 50)"
  fi
else
  report_skip "FastFlowLM — service disabled (units absent from systemd)"
fi

# / redirects to the Pocket ID login (302) since OAuth2 is configured —
# probe /health instead, the same endpoint the agent's ExecStartPre gates on.
check_local "Browser History" "8087" "/health" "200" 2>/dev/null || true

# Browser History: agent timer must be active for collection
if systemctl is-active browser-history-agent.timer >/dev/null 2>&1; then
  report_pass "Browser History — agent timer active"
else
  report_fail "Browser History — agent timer NOT active (history collection offline)"
fi

# Paperless: the login page BODY proves the full Django + PostgreSQL + redis
# stack answers, not just the port. In the 2026-08-18 PG bootstrap incident a
# stale src-version file made the scheduler skip `migrate`, it crash-looped on
# "relation auth_user does not exist", and every paperless unit failed — a
# liveness probe alone cannot distinguish that from a slow boot. Tika and
# Gotenberg prove the Office/E-Mail consume sidecars are up. Ports from
# lib/ports.nix (paperless 2892, tika 9998, gotenberg 3199).
paperless_enabled=false
test -e /etc/systemd/system/paperless-web.service && paperless_enabled=true
if $paperless_enabled; then
  # --retry: post-deploy-check runs seconds after switch-to-configuration
  # restarts paperless-webserver (gunicorn); during that window the socket
  # can answer with an empty/error body before Django is ready. Retrying
  # keeps the check strict (body MUST eventually contain the sign-in marker)
  # while tolerating the restart window.
  # URL: / 302-redirects to /accounts/login/?next=/ — curl without -L only
  # sees the redirect (its body is empty); probe the login page directly,
  # same URL Gatus probes. python urllib auto-follows redirects, which masked
  # this during development — verify smoke checks with curl semantics.
  if paperless_body=$(curl -s --compressed --max-time 10 --retry 5 --retry-delay 3 --retry-all-errors "http://127.0.0.1:2892/accounts/login/?next=/" 2>/dev/null); then
    if echo "$paperless_body" | grep -q "Paperless-ngx sign in"; then
      report_pass "Paperless — web login page (Django + PostgreSQL stack answers)"
    else
      report_fail 'Paperless — :2892 answered but the body lacks "Paperless-ngx sign in" — partial stack, check paperless-scheduler journal'
    fi
  else
    report_fail "Paperless — :2892 unreachable (journalctl -u 'paperless-*' -n 30)"
  fi
  if systemctl is-active tika.service >/dev/null 2>&1; then
    report_pass "Paperless — Tika OCR sidecar active"
  else
    report_fail "Paperless — tika.service NOT active (attachment OCR dead)"
  fi
  if curl -s --compressed --max-time 10 "http://127.0.0.1:3199/health" 2>/dev/null | grep -q .; then
    report_pass "Paperless — Gotenberg health endpoint answers"
  else
    report_fail "Paperless — :3199/health unreachable (Office conversion dead)"
  fi
else
  report_skip "Paperless — service disabled (units absent from systemd)"
fi

# Bank-Sync: the dashboard BODY proves the templ stack + SQLite read models
# answer, /metrics proves the sync daemon wired its callback, and a nonzero
# profile count proves the first Wise sync actually wrote data (catches the
# empty-token/auth-failure class where the dashboard renders but nothing
# ever syncs). Port from lib/ports.nix (bank-sync 8097). Fresh deploys may
# see the profiles WARN while the initial 365d backfill sync is running.
banksync_enabled=false
test -e /etc/systemd/system/bank-sync.service && banksync_enabled=true
if $banksync_enabled; then
  if banksync_body=$(curl -s --compressed --max-time 10 "http://127.0.0.1:8097/" 2>/dev/null); then
    if echo "$banksync_body" | grep -q "Bank-Sync Dashboard"; then
      report_pass "Bank-Sync — dashboard answers (templ stack + read models)"
    else
      report_fail 'Bank-Sync — :8097 answered but the body lacks "Bank-Sync Dashboard"'
    fi
  else
    report_fail "Bank-Sync — :8097 unreachable (journalctl -u bank-sync -n 30)"
  fi
  if banksync_metrics=$(curl -s --compressed --max-time 10 "http://127.0.0.1:8097/metrics" 2>/dev/null); then
    if echo "$banksync_metrics" | grep -q '^bank_sync_sync_total'; then
      report_pass "Bank-Sync — /metrics answers"
    else
      report_fail "Bank-Sync — /metrics answered but lacks bank_sync_sync_total"
    fi
  else
    report_fail "Bank-Sync — /metrics unreachable"
  fi
  if echo "${banksync_metrics:-}" | grep -q '^bank_sync_profiles [1-9]'; then
    report_pass "Bank-Sync — Wise sync wrote data (profiles > 0)"
  else
    report_warn "Bank-Sync — bank_sync_profiles is 0: first sync may still be running, or the Wise token failed (journalctl -u bank-sync -n 50)"
  fi
else
  report_skip "Bank-Sync — service disabled (units absent from systemd)"
fi

# --- Functional checks (not just liveness) ---
echo ""
echo "=== Functional Checks ==="

# Crush Daily: reports should exist after first collection.
# The API returns a JSON array of date strings: ["2026-07-19", "2026-07-18", ...]
if crush_reports=$(curl -s --compressed --max-time 5 "http://localhost:8081/api/reports" 2>/dev/null); then
  if echo "$crush_reports" | grep -qE '"[0-9]{4}-[0-9]{2}-[0-9]{2}"'; then
    echo -e "${GREEN}PASS${NC} Crush Daily has reports"
    PASS=$((PASS + 1))

    # Silent-zero-data guard: the most recent report must have >0 sessions.
    # Catches the entire class of bugs where the service is "healthy" but
    # collected nothing (cross-user /home ACLs, missing runAsUser, broken
    # crush CLI schema discovery, ...). Without this check, a backfill of
    # zero-data reports can sit silently for weeks.
    latest_date=$(echo "$crush_reports" | grep -oE '"[0-9]{4}-[0-9]{2}-[0-9]{2}"' | head -1 | tr -d '"')
    if [ -n "$latest_date" ] &&
      curl -s --compressed --max-time 5 -o /tmp/.smoke-crush-report "http://localhost:8081/api/reports/$latest_date" 2>/dev/null &&
      grep -qE '"session_count":[ ]*[1-9][0-9]*' /tmp/.smoke-crush-report; then
      echo -e "${GREEN}PASS${NC} Crush Daily latest report ($latest_date) has session_count >0"
      PASS=$((PASS + 1))
    elif [ -n "$latest_date" ]; then
      echo -e "${RED}FAIL${NC} Crush Daily latest report ($latest_date) shows 0 sessions — silent-zero-data regression"
      FAIL=$((FAIL + 1))
    fi
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

# DiscordSync: database should have tables.
# Write to file and grep from file — the /api/stats response can contain null
# bytes (embedded data) which bash command-substitution silently strips,
# corrupting the JSON and making grep miss the pattern. Use grep -a (treat
# binary as text) for the same reason.
if curl -s --compressed --max-time 15 -o /tmp/.smoke-discordsync "http://localhost:8085/api/stats" 2>/dev/null; then
  if grep -qa '"guilds"' /tmp/.smoke-discordsync 2>/dev/null; then
    echo -e "${GREEN}PASS${NC} DiscordSync API functional (stats endpoint returns data)"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC} DiscordSync stats unexpected response"
    SKIP=$((SKIP + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} DiscordSync not reachable (may be in startup backfill — API binds after thumb-hash backfill completes)"
  SKIP=$((SKIP + 1))
fi

# SigNoz: impersonation mode must be active (auth delegated to Caddy + Pocket ID)
if signoz_config=$(curl -s --compressed --max-time 5 "http://localhost:8080/api/v1/global/config" 2>/dev/null); then
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

# SigNoz: alert rules must be provisioned (>15 rules expected)
if signoz_rules=$(curl -s --compressed --max-time 5 "http://localhost:8080/api/v1/rules" 2>/dev/null); then
  RULE_COUNT=$(echo "$signoz_rules" | jq -r '.data.rules | length' 2>/dev/null || echo "0")
  RULE_COUNT="${RULE_COUNT:-0}"
  if [ "$RULE_COUNT" -gt 15 ] 2>/dev/null; then
    echo -e "${GREEN}PASS${NC} SigNoz alert rules provisioned ($RULE_COUNT rules)"
    PASS=$((PASS + 1))
  elif [ "$RULE_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}FAIL${NC} SigNoz alert rules under-provisioned ($RULE_COUNT rules, expected >15) — re-trigger signoz-provision.service"
    FAIL=$((FAIL + 1))
  else
    echo -e "${RED}FAIL${NC} SigNoz has ZERO alert rules — signoz-provision.service did not run or failed. Observability gap: no alerts will fire"
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} SigNoz rules endpoint not reachable"
  SKIP=$((SKIP + 1))
fi

# Monitor365: FULL agent↔server connectivity verification.
# Checks BOTH sides: (1) agent metrics endpoint responding (process alive),
# (2) server sees the agent as a connected device. If the agent is dead,
# attempts one restart before declaring failure.
echo ""
echo "--- Monitor365 Agent ↔ Server Connectivity ---"

m365_agent_ok=false
m365_server_ok=false

# Check 1: Agent metrics endpoint (port 9191) — verifies agent process is alive
if curl -sf -m 5 -o /dev/null "http://localhost:9191/metrics" 2>/dev/null; then
  : # agent alive
elif ! $m365_enabled; then
  : # disabled — reported below, no restart attempt on absent units
else
  echo -e "${YELLOW}WARN${NC} Monitor365 agent metrics not responding — attempting restart"
  sudo systemctl reset-failed monitor365.service 2>/dev/null || true
  sudo systemctl start monitor365.service 2>/dev/null || true
  sleep 10
fi

# Check 2: Agent metrics endpoint (port 9191)
if curl -sf -m 5 -o /dev/null "http://localhost:9191/metrics" 2>/dev/null; then
  echo -e "${GREEN}PASS${NC} Monitor365 agent metrics responding (localhost:9191)"
  m365_agent_ok=true
  PASS=$((PASS + 1))
elif ! $m365_enabled; then
  echo -e "${YELLOW}SKIP${NC} Monitor365 agent — service disabled (units absent from systemd)"
  SKIP=$((SKIP + 1))
else
  echo -e "${RED}FAIL${NC} Monitor365 agent metrics NOT responding (localhost:9191) — agent may be crashed or circuit-breaker deadlocked"
  FAIL=$((FAIL + 1))
fi

# Check 3: Server reports agent as connected device.
# The agent takes 15-30s to connect after (re)start. When the server reports
# 0 devices, we retry after a grace period before declaring failure.
# This avoids false FAILs right after deploy (agent was just started).
m365_check_server() {
  local health
  health=$(curl -s --compressed --max-time 5 "http://localhost:3001/health" 2>/dev/null) || return 3
  echo "$health" | grep -qE '"realtime":"connected \([1-9][0-9]* devices\)"' && return 0
  echo "$health" | grep -q '"realtime":"connected (0 devices)"' && return 1
  return 2
}

if m365_health=$(curl -s --compressed --max-time 5 "http://localhost:3001/health" 2>/dev/null); then
  if echo "$m365_health" | grep -q '"realtime"'; then
    if echo "$m365_health" | grep -qE '"realtime":"connected \([1-9][0-9]* devices\)"'; then
      echo -e "${GREEN}PASS${NC} Monitor365 agent connected to server"
      m365_server_ok=true
      PASS=$((PASS + 1))
    elif echo "$m365_health" | grep -q '"realtime":"connected (0 devices)"'; then
      # Agent may still be connecting. Wait 20s and retry.
      echo -e "${YELLOW}WAIT${NC} Monitor365 server reports 0 devices — agent may still be connecting, waiting 20s..."
      sleep 20
      if m365_check_server; then
        echo -e "${GREEN}PASS${NC} Monitor365 agent connected to server (after grace period)"
        m365_server_ok=true
        PASS=$((PASS + 1))
      else
        echo -e "${RED}FAIL${NC} Monitor365 server reports 0 connected devices after grace period"
        FAIL=$((FAIL + 1))
      fi
    else
      echo -e "${YELLOW}WARN${NC} Monitor365 health reachable but unexpected realtime format"
      SKIP=$((SKIP + 1))
    fi
  else
    echo -e "${YELLOW}WARN${NC} Monitor365 health reachable but realtime field missing"
    SKIP=$((SKIP + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} Monitor365 server not reachable on localhost:3001"
  SKIP=$((SKIP + 1))
fi

# Check 4: If agent is up but server still reports 0 devices after the grace
# period, check how long the agent has been running. If it was started <2min
# ago (e.g. by deploy), SKIP — the agent-watchdog timer will verify within 5min.
# If the agent has been running >2min with 0 devices, it's a real CB deadlock —
# restart to clear in-memory circuit breaker state.
if $m365_agent_ok && ! $m365_server_ok; then
  AGENT_UPTIME=$(sudo systemctl show -p ActiveEnterTimestamp --value monitor365.service 2>/dev/null)
  if [ -n "$AGENT_UPTIME" ]; then
    NOW_EPOCH=$(date +%s)
    STARTED_EPOCH=$(date -d "$AGENT_UPTIME" +%s 2>/dev/null || echo 0)
    if [ "$STARTED_EPOCH" -gt 0 ] && [ $((NOW_EPOCH - STARTED_EPOCH)) -lt 120 ]; then
      echo -e "${YELLOW}SKIP${NC} Monitor365 agent recently started ($((NOW_EPOCH - STARTED_EPOCH))s ago) — watchdog timer will verify connectivity within 5min"
      SKIP=$((SKIP + 1))
    else
      echo -e "${YELLOW}WARN${NC} Agent alive but not connected (CB deadlock) — restarting agent to clear circuit breaker"
      sudo systemctl restart monitor365.service 2>/dev/null || true
      sleep 30
      if m365_check_server; then
        echo -e "${GREEN}PASS${NC} Monitor365 agent reconnected after restart"
        PASS=$((PASS + 1))
      else
        echo -e "${RED}FAIL${NC} Monitor365 agent still not connected after restart — check API key or server logs"
        FAIL=$((FAIL + 1))
      fi
    fi
  else
    echo -e "${YELLOW}SKIP${NC} Cannot determine agent uptime — skipping CB deadlock check"
    SKIP=$((SKIP + 1))
  fi
fi

# Monitor365: server-watchdog timer must be active (catches DuckDB pool deadlock)
if systemctl is-active monitor365-server-watchdog.timer >/dev/null 2>&1; then
  report_pass "Monitor365 — server-watchdog timer active"
elif ! $m365_enabled; then
  echo -e "${YELLOW}SKIP${NC} Monitor365 — server-watchdog timer absent (service disabled)"
  SKIP=$((SKIP + 1))
else
  report_fail "Monitor365 — server-watchdog timer NOT active (pool deadlock detection offline)"
fi

# File Renamer: dashboard must show accumulated history, not a split-brain empty fork.
# The watcher and health service MUST share the same state files. A 200 with
# total_operations: 0 on a system that's been renaming for weeks means split-brain
# (watcher writing to ~/.renamer-history.json, dashboard reading dataDir/history.json).
if renamer_status=$(curl -s --compressed --max-time 5 "http://localhost:8086/status" 2>/dev/null); then
  total_ops=$(echo "$renamer_status" | grep -oE '"total_operations":[0-9]+' | grep -oE '[0-9]+$' || echo "0")
  if [ "$total_ops" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}PASS${NC} File Renamer dashboard has real history ($total_ops operations)"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC} File Renamer dashboard shows 0 operations — possible split-brain or fresh install"
    SKIP=$((SKIP + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} File Renamer dashboard not reachable on localhost:8086"
  SKIP=$((SKIP + 1))
fi

# --- External vHost checks (from LAN) ---
echo ""
echo "=== External vHost Checks ==="

check "Homepage (HTTPS)" "https://dash.$DOMAIN/" "200" "<html" 2>/dev/null || true
check "Forgejo (HTTPS)" "https://forgejo.$DOMAIN/api/v1/version" "200" "" 2>/dev/null || true
check "Status (HTTPS)" "https://status.$DOMAIN/" "200" "<html" 2>/dev/null || true
check "Immich (HTTPS)" "https://immich.$DOMAIN/api/server/ping" "200" "" 2>/dev/null || true
# Enable-gated via banksync_enabled (computed in the service-level section
# above): a disabled bank-sync leaves the Caddy vHost proxying to a dead
# port, which would false-FAIL every deploy until the service goes live.
$banksync_enabled && check "Bank-Sync (HTTPS)" "https://banksync.$DOMAIN/" "200" "Bank-Sync Dashboard" 2>/dev/null || true
check "Overview (HTTPS)" "https://overview.$DOMAIN/" "200" "<html" 2>/dev/null || true

# --- Auth gateway health (oauth2-proxy / forward-auth) ---
# Catches P9: oauth2-proxy returning 500 on protected vHosts.
# From LAN, protected vHosts should return 200 (LAN bypass) or redirect (302/303).
# A 500/502/503 means oauth2-proxy itself is broken — the exact SigNoz incident.
echo ""
echo "=== Auth Gateway Health ==="
# Subdomain names MUST match the Caddy vHost definitions in caddy.nix
# (dozzle→logs, monitor365→monitor, searx→search, crush-daily→daily,
# taskchampion→tasks). Wrong names SKIP forever = phantom coverage.
AUTH_VHOSTS=(
  "signoz.$DOMAIN"
  "logs.$DOMAIN"
  "monitor.$DOMAIN"
  "search.$DOMAIN"
  "daily.$DOMAIN"
  "tasks.$DOMAIN"
  "manifest.$DOMAIN"
)
for vhost in "${AUTH_VHOSTS[@]}"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$vhost/" 2>/dev/null || true)
  case "$status" in
  200 | 301 | 302 | 303)
    echo -e "${GREEN}PASS${NC} $vhost → $status (auth gateway healthy)"
    PASS=$((PASS + 1))
    ;;
  500 | 502 | 503)
    echo -e "${RED}FAIL${NC} $vhost → $status (auth gateway BROKEN — check oauth2-proxy)"
    FAIL=$((FAIL + 1))
    ;;
  000)
    echo -e "${YELLOW}SKIP${NC} $vhost unreachable"
    SKIP=$((SKIP + 1))
    ;;
  *)
    echo -e "${YELLOW}WARN${NC} $vhost → $status (unexpected status)"
    SKIP=$((SKIP + 1))
    ;;
  esac
done

# --- System & Desktop Checks ---
echo ""
echo "=== System & Desktop Checks ==="

# BTRFS: commit=300 on mounts (prevents WDT resets on QLC NAND)
if grep -q 'commit=300' /proc/mounts 2>/dev/null; then
  report_pass "BTRFS — commit=300 active on mounts"
else
  report_fail "BTRFS — commit=300 NOT found on any mount (WDT reset risk on QLC NAND)"
fi

# BTRFS: fstrim timer must be enabled (daily TRIM prevents SLC cache exhaustion)
if systemctl is-enabled fstrim.timer >/dev/null 2>&1; then
  report_pass "BTRFS — fstrim.timer enabled"
else
  report_fail "BTRFS — fstrim.timer not enabled (SLC cache exhaustion risk)"
fi

# Registry: nixpkgs must point to github, NOT tarball (lockfile regression guard)
if nix registry list 2>/dev/null | grep -qi 'nixpkgs.*github'; then
  report_pass "Registry — nixpkgs points to github (no tarball regression)"
elif nix registry list 2>/dev/null | grep -qi 'nixpkgs.*tarball'; then
  report_fail "Registry — nixpkgs is a tarball entry (run scripts/fix-nixpkgs-lock.sh)"
else
  report_skip "Registry — cannot determine nixpkgs registry state"
fi

# Shell: fish startup time (threshold 200ms — includes bash subprocess overhead)
if command -v fish >/dev/null 2>&1; then
  _fish_start=$(date +%s%N)
  fish -i -c exit >/dev/null 2>&1 || true
  _fish_end=$(date +%s%N)
  _fish_ms=$(((_fish_end - _fish_start) / 1000000))
  if [ "$_fish_ms" -lt 200 ]; then
    report_pass "Shell — fish startup ${_fish_ms}ms"
  else
    report_warn "Shell — fish startup ${_fish_ms}ms (threshold 200ms)"
  fi
else
  report_skip "Shell — fish not on PATH"
fi

# Shell: direnv smart-nix lib present
if [ -f "${HOME:-}/.config/direnv/lib/zz-smart-nix.sh" ]; then
  report_pass "Shell — direnv smart-nix lib present"
else
  report_skip "Shell — direnv smart-nix lib not found"
fi

# Desktop: DMS wallpaper IPC
if command -v dms >/dev/null 2>&1 && dms ipc call wallpaper get >/dev/null 2>&1; then
  report_pass "Desktop — DMS wallpaper IPC responding"
else
  report_skip "Desktop — DMS wallpaper IPC not responding (expected in non-graphical context)"
fi

# Desktop: quickshell journal errors (last 1h)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null || echo 0)}"
_qs_errors=$(journalctl --user -u quickshell --since "-1hour" --no-pager -p err 2>/dev/null | wc -l || echo 0)
if [ "${_qs_errors:-0}" -eq 0 ]; then
  report_pass "Desktop — no errors in quickshell journal (last 1h)"
else
  report_warn "Desktop — ${_qs_errors} error line(s) in quickshell journal (last 1h)"
fi

# System: I/O pressure (PSI) — catches the exact condition that caused
# Helium 3 FPS + WDT crashes during nix build storms on QLC NAND.
# avg10 > 80% means I/O is saturated for the last 10 seconds.
if [ -f /proc/pressure/io ]; then
  _io_avg10=$(awk '/^some/{print $2}' /proc/pressure/io | cut -d= -f2)
  _io_warn=$(awk "BEGIN { exit !(${_io_avg10:-0} > 80) }" && echo 1 || echo 0)
  if [ "$_io_warn" = "1" ]; then
    report_warn "System — I/O pressure avg10=${_io_avg10}% (>80% threshold — BFQ tiers may need attention)"
  else
    report_pass "System — I/O pressure avg10=${_io_avg10}% (healthy)"
  fi
else
  report_skip "System — /proc/pressure/io not available"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}SKIP: $SKIP${NC}  WARN: $WARN"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo -e "${RED}❌ $FAIL check(s) failed — investigate before proceeding${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}✅ All checks passed${NC}"
  exit 0
fi
