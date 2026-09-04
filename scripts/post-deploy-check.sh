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

# Every FAIL records a STABLE name (the text before the " — " detail
# separator) so the summary can diff this run's fail set against the
# previous run's baseline: failures already known from the previous deploy
# stay advisory, while NEW ones are this deploy's regression signal (exit 3).
SMOKE_FAIL_NAMES="$(mktemp)"
trap 'rm -f "$SMOKE_FAIL_NAMES"' EXIT
record_fail() {
  printf '%s\n' "${1%% — *}" >>"$SMOKE_FAIL_NAMES"
}

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
    record_fail "$name — unreachable"
    return 1
  fi

  if [ "$status" != "$expect_status" ]; then
    echo -e "${RED}FAIL${NC} $name — expected HTTP $expect_status, got $status ($url)"
    FAIL=$((FAIL + 1))
    record_fail "$name — status $status"
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
      record_fail "$name — body mismatch"
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

# --- Shared wait helpers ------------------------------------------------------
# Deploy-time warmup tolerance: this script runs seconds after
# switch-to-configuration restarts services, so one-shot probes race slow
# binders (model loads, DB backfills, engine restarts). Both helpers poll
# until a readiness signal holds; the caller's one-shot functional check
# still produces the verdict. Neither sleeps after the final attempt.

# wait_for_200 <url> <attempts> <interval-seconds>
# Poll until the URL answers HTTP 200. Returns 0 on success, 1 on timeout.
wait_for_200() {
  local url="$1" attempts="$2" interval="$3"
  local i
  for i in $(seq 1 "$attempts"); do
    if [ "$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || true)" = "200" ]; then
      return 0
    fi
    if [ "$i" -lt "$attempts" ]; then sleep "$interval"; fi
  done
  return 1
}

# wait_body_pattern <url> <pattern> <attempts> <interval-seconds>
# Poll until the URL's body matches the fixed-string pattern (BRE). Prints
# the LAST fetched body so callers can capture it for diagnostics; returns
# 0 on match, 1 on timeout. For endpoints whose success signal is content,
# not status (bank-sync dashboard). Bodies are grepped via herestring,
# NEVER `echo "$body" | grep -q`: under set -o pipefail a body larger than
# the 64KiB pipe buffer makes the echo writer die on SIGPIPE (141) the
# moment grep -q exits at its first match — a false "body lacks" FAIL
# (caught live 2026-08-19 when the templ dashboard grew to ~106KiB).
wait_body_pattern() {
  local url="$1" pattern="$2" attempts="$3" interval="$4"
  local body="" i
  for i in $(seq 1 "$attempts"); do
    body=$(curl -s --compressed --max-time 10 "$url" 2>/dev/null || true)
    if grep -q "$pattern" <<<"$body"; then
      printf '%s' "$body"
      return 0
    fi
    if [ "$i" -lt "$attempts" ]; then sleep "$interval"; fi
  done
  printf '%s' "$body"
  return 1
}

# Report helpers for non-HTTP checks (system state, timers, journals, etc.)
report_pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}
report_fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
  record_fail "$1"
}
report_skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP=$((SKIP + 1))
}
report_warn() {
  echo -e "${YELLOW}WARN${NC} $1"
  WARN=$((WARN + 1))
}

# Shared pressure-reporting logic (fixture-tested by
# scripts/test-post-deploy-pressure.sh + the post-deploy-pressure-selftest
# flake check — the WARN/PASS semantics must never call a storm healthy).
# shellcheck source=scripts/lib/pressure-report.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pressure-report.sh"

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
if wait_for_200 "http://localhost:8085/healthz" 3 5; then
  echo -e "${GREEN}PASS${NC} DiscordSync (localhost:8085) (200)"
  PASS=$((PASS + 1))
elif pgrep -f discordsync >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} DiscordSync (localhost:8085) — process alive but API not ready (startup backfill in progress)"
  SKIP=$((SKIP + 1))
else
  echo -e "${RED}FAIL${NC} DiscordSync (localhost:8085) — process not running and API unreachable"
  FAIL=$((FAIL + 1))
  record_fail "DiscordSync (localhost:8085)"
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
# (every connection pins the 21.6 GB model for another keepAlive window), so
# this deploy-time smoke is the sole functional gate. First connection after
# idle-stop cold-loads the model (2-5 min) — max-time covers it.
flm_enabled=false
systemctl list-unit-files 'fastflowlm*' --no-legend 2>/dev/null | grep -q fastflowlm && flm_enabled=true

if $flm_enabled; then
  # Deliberate connection: re-arms the whole socket→proxy→backend chain.
  # max-time 480: v1.0.2 weights are 21.6 GB (was 13.6) — worst-case cold load
  # through the kernel backlog is now ~5 min.
  if curl -s --compressed --max-time 480 -o /tmp/.smoke-flm "http://127.0.0.1:52625/v1/models" 2>/dev/null; then
    # Assert the BOUND model id, not just a JSON envelope: a stale/wrong model
    # file (the v1.0.2 re-pull incident: old weights hash-mismatch the new
    # manifest) still answers with a "data" array. Expected id is derived from
    # the deployed unit's ExecStart so the check tracks config changes.
    flm_model=$(systemctl cat fastflowlm.service 2>/dev/null | sed -n 's/.*flm serve \([^ ]*\).*/\1/p' | head -1)
    if [ -n "$flm_model" ] && grep -q "\"$flm_model\"" /tmp/.smoke-flm 2>/dev/null; then
      report_pass "FastFlowLM — /v1/models serves bound model '$flm_model' through socket-activated :52625 (pinned ≤ keepAlive)"
    elif grep -q '"data"' /tmp/.smoke-flm 2>/dev/null; then
      report_fail "FastFlowLM — :52625 answered but /v1/models lacks bound model '${flm_model:-<derive-failed>}' — stale/wrong model serving (v1.0.2 re-pull class)"
    else
      report_fail 'FastFlowLM — :52625 answered but /v1/models body lacks "data" — proxy chain up, backend wrong'
    fi
  else
    report_fail "FastFlowLM — :52625 unreachable: socket dead or proxy/backend broken (journalctl -u 'fastflowlm*' -n 50)"
  fi
else
  report_skip "FastFlowLM — service disabled (units absent from systemd)"
fi

# CV server (cv module): the PDF export is the money path and the exact one
# that broke in production while every HTML/liveness check stayed green
# (2026-08-27: typst template vanished from the state dir → /export/pdf 404
# for hours). Gate deploys on liveness + a real PDF's magic bytes. Port is
# ports.cv (lib/ports.nix) — keep in sync.
cv_enabled=false
systemctl list-unit-files 'cv-server*' --no-legend 2>/dev/null | grep -q cv-server && cv_enabled=true

if $cv_enabled; then
  cv_health=$(curl -s --compressed -o /tmp/.smoke-cv-health -w "%{http_code}" --max-time 10 "http://127.0.0.1:8098/health/live" 2>/dev/null || true)
  if [ "$cv_health" = "200" ] && grep -q '"status":"pass"' /tmp/.smoke-cv-health 2>/dev/null; then
    cv_ver=$(sed -n 's/.*"version":"\([^"]*\)".*/\1/p' /tmp/.smoke-cv-health | head -1)
    report_pass "CV — /health/live pass (version ${cv_ver:-unknown})"
  else
    report_fail "CV — /health/live not passing (status '${cv_health:-none}') — cv-server down or unhealthy (journalctl -u cv-server -n 50)"
  fi
  # max-time 30: typst compile + first-render font cache on a fresh restart.
  if curl -s --compressed --max-time 30 -o /tmp/.smoke-cv-pdf "http://127.0.0.1:8098/export/pdf" 2>/dev/null && head -c 8 /tmp/.smoke-cv-pdf 2>/dev/null | grep -q '%PDF'; then
    report_pass "CV — /export/pdf compiles a real PDF (typst path, assets synced)"
  else
    report_fail "CV — /export/pdf broken: typst template missing from /var/lib/cv/assets or renderer failed (restart re-syncs assets; journalctl -u cv-server -n 50)"
  fi
  # Funnel DB health (upstream 2026-09-02): /health's pipeline-store check
  # pings the SQLite event store the nightly cv-backup protects. Requires a
  # cv flake input >= a03ff09e — an older deployed binary lacks the key
  # entirely. NOTE: the sibling "database" check is the optional Turso
  # analytics DB (disabled by design in prod) — its "not configured"
  # verdict is benign and deliberately NOT asserted here.
  cv_store=$(curl -s --compressed --max-time 10 "http://127.0.0.1:8098/health" 2>/dev/null | grep -o '"pipeline-store":{"name":"pipeline-store","status":"[a-z]*"' || true)
  case "$cv_store" in
  *'"status":"healthy"'*)
    report_pass "CV — pipeline-store healthy (SQLite funnel store reachable)"
    ;;
  *)
    report_fail "CV — pipeline-store not healthy (${cv_store:-check absent from /health}) — deployed cv binary predates 2026-09-02 or the sqlite store is unreachable (journalctl -u cv-server -n 50)"
    ;;
  esac
else
  report_skip "CV — service disabled (units absent from systemd)"
fi

# llama.cpp RAG stack (llama-rag module): the /health endpoint proves the
# model loaded and the server is serving (llama-server exits nonzero when the
# GGUF is missing). The RAG endpoints themselves are exercised functionally
# below.
llama_rag_enabled=false
systemctl list-unit-files 'llama-*' --no-legend 2>/dev/null | grep -q llama-embeddings && llama_rag_enabled=true

if $llama_rag_enabled; then
  # Warmup tolerance: a deploy restart makes llama-server reload its GGUF
  # (~70s observed for the reranker on ROCm) and it answers /health with
  # 503 until the model is ready. Wait up to 2 min per port before the
  # one-shot checks below declare failure (Gatus covers continuous
  # health; this only needs to catch config regressions post-warmup).
  for port in 8848 8849; do
    wait_for_200 "http://127.0.0.1:$port/health" 12 10 || true
  done
  check_local "llama.cpp Embeddings" "8848" "/health" "200" "ok" 2>/dev/null || true
  check_local "llama.cpp Reranker" "8849" "/health" "200" "ok" 2>/dev/null || true
else
  report_skip "llama.cpp RAG — service disabled (units absent from systemd)"
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

# Browser History: the agent-token provision oneshot must have converged.
# The agent's EnvironmentFile IS the provisioned agent.env — a dead
# provisioner means the agent starts with no DB token (or fails outright).
if test -e /etc/systemd/system/browser-history-agent.service; then
  if systemctl is-active --quiet browser-history-agent-token-provision.service; then
    report_pass "Browser History — agent token provisioned (oneshot active)"
  else
    report_fail "Browser History — agent-token-provision NOT active (no DB token for the agent; check its journal)"
  fi
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
  # SSO-only mode (2026-09-02): the login page must carry the Pocket ID
  # provider form + the JS auto-submit (PAPERLESS_REDIRECT_LOGIN_TO_SSO is a
  # CLIENT-SIDE redirect — paperless's template auto-submits the first
  # provider form; there is no 302) and NO password input
  # (PAPERLESS_DISABLE_REGULAR_LOGIN). Both flags ride in the
  # paperless-oidc-setup env file, so a password form appearing = bridge
  # degraded = auto-break-glass serving. Every branch reports explicitly —
  # a silently-skipped check is a phantom green. --retry tolerates the
  # post-switch gunicorn restart window; keep curl semantics (python urllib
  # auto-follows redirects).
  if paperless_body=$(curl -s --compressed --max-time 10 --retry 5 --retry-delay 3 --retry-all-errors "http://127.0.0.1:2892/accounts/login/?next=/" 2>/dev/null); then
    paperless_sso_ok=true
    grep -q "oidc/pocket-id" <<<"$paperless_body" || paperless_sso_ok=false
    grep -q "getElementById" <<<"$paperless_body" || paperless_sso_ok=false
    grep -q 'type="password"' <<<"$paperless_body" && paperless_sso_ok=false
    if $paperless_sso_ok; then
      report_pass "Paperless — SSO-only login (Pocket ID auto-submit, no password form)"
    elif grep -q 'type="password"' <<<"$paperless_body"; then
      report_fail "Paperless — PASSWORD FORM is serving: the SSO env file did not reach the unit (bridge degraded or flags missing) — journalctl -u paperless-oidc-setup"
    else
      report_fail "Paperless — login page lacks the Pocket ID auto-submit flow (provider form or redirect script missing) — journalctl -u paperless-oidc-setup and paperless-scheduler"
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
  # Restart-race-proof fetch: activation may still be (re)starting
  # bank-sync when this runs — the 10s settle sleep in deploy.sh is not
  # always enough under post-build I/O contention, and a mid-restart
  # answer (connection refused / empty body / error page) must not
  # produce a FAIL. Retry up to 6x5s before declaring failure.
  banksync_body="$(wait_body_pattern "http://127.0.0.1:8097/" "Bank-Sync Dashboard" 6 5)" || true
  if grep -q "Bank-Sync Dashboard" <<<"$banksync_body"; then
    report_pass "Bank-Sync — dashboard answers (templ stack + read models)"
  elif [ -z "$banksync_body" ]; then
    report_fail "Bank-Sync — :8097 unreachable after 6 attempts (journalctl -u bank-sync -n 30)"
  else
    report_fail 'Bank-Sync — :8097 answered but the body lacks "Bank-Sync Dashboard"'
  fi
  if banksync_metrics=$(curl -s --compressed --max-time 10 "http://127.0.0.1:8097/metrics" 2>/dev/null); then
    if grep -q '^bank_sync_sync_total' <<<"$banksync_metrics"; then
      report_pass "Bank-Sync — /metrics answers"
    else
      report_fail "Bank-Sync — /metrics answered but lacks bank_sync_sync_total"
    fi
  else
    report_fail "Bank-Sync — /metrics unreachable"
  fi
  if grep -q '^bank_sync_profiles [1-9]' <<<"${banksync_metrics:-}"; then
    report_pass "Bank-Sync — Wise sync wrote data (profiles > 0)"
  else
    report_warn "Bank-Sync — bank_sync_profiles is 0: first sync may still be running, or the Wise token failed (journalctl -u bank-sync -n 50)"
  fi
  # Invisible-outage guard: the dashboard above can be green while every
  # sync cycle fails (2026-08: 129 consecutive sync errors, 0 transactions,
  # dashboard fine). The unit was just restarted by the deploy, so the
  # errors counter is process-fresh — nonzero means cycles are failing
  # RIGHT NOW. wait_body_pattern refetches the metrics page per attempt:
  # the first cycle may still be in flight when this runs.
  banksync_metrics="$(wait_body_pattern "http://127.0.0.1:8097/metrics" '^bank_sync_sync_errors_total 0' 6 5)" || true
  if grep -q '^bank_sync_sync_errors_total 0' <<<"$banksync_metrics"; then
    report_pass "Bank-Sync — sync cycles clean (sync_errors_total 0)"
  else
    report_fail "Bank-Sync — sync cycles failing since restart (bank_sync_sync_errors_total > 0): journalctl -u bank-sync -n 100"
  fi
  if grep -q '^bank_sync_last_sync_timestamp_seconds' <<<"${banksync_metrics:-}"; then
    report_pass "Bank-Sync — at least one sync succeeded (last-sync timestamp present)"
  else
    report_warn "Bank-Sync — no successful sync yet (last-sync timestamp absent): first cycle may still be running"
  fi
else
  report_skip "Bank-Sync — service disabled (units absent from systemd)"
fi

# InboxClean (port from lib/ports.nix: 8099). /health proves the CQRS stack
# (SQLite + event store migrations ran); the dashboard body proves templ
# rendering. Per-account Gmail states: "main" must be connected; extra
# accounts (work) warn until their one-time OAuth runbook completes
# (see modules/nixos/services/inboxclean.nix header) — never fail on those.
inboxclean_enabled=false
test -e /etc/systemd/system/inboxclean-web.service && inboxclean_enabled=true
if $inboxclean_enabled; then
  inboxclean_health="$(wait_body_pattern "http://127.0.0.1:8099/health" '"status": *"ok"' 6 5)" || true
  if grep -q '"status": *"ok"' <<<"$inboxclean_health"; then
    report_pass "InboxClean — /health ok (CQRS stack + migrations up)"
  elif [ -z "$inboxclean_health" ]; then
    report_fail "InboxClean — :8099/health unreachable after 6 attempts (journalctl -u inboxclean-web -n 30)"
  else
    report_fail "InboxClean — /health answered but status is not ok"
  fi
  inboxclean_body="$(wait_body_pattern "http://127.0.0.1:8099/" 'Dashboard' 6 5)" || true
  if grep -q 'Dashboard' <<<"$inboxclean_body"; then
    report_pass "InboxClean — dashboard renders (templ stack)"
  else
    report_fail "InboxClean — :8099 answered but the dashboard body lacks content"
  fi
  # Per-account Gmail map: {"main":"connected","work":"connected",...}.
  inboxclean_main_state="$(jq -r '.services.gmail.main // "missing"' <<<"${inboxclean_health:-}" 2>/dev/null)" || true
  case "$inboxclean_main_state" in
  connected)
    report_pass "InboxClean — Gmail main connected (OAuth token active)"
    ;;
  missing)
    report_warn "InboxClean — /health carries no services.gmail.main entry (binary predates multi-account?)"
    ;;
  *)
    report_warn "InboxClean — Gmail main '$inboxclean_main_state': complete the OAuth runbook (inboxclean.nix header) and enable services.inboxclean.sync"
    ;;
  esac
  # Extra accounts: WARN on any not-connected, FAIL only on transport errors
  # (already handled above).
  inboxclean_pending="$(jq -r '.services.gmail | to_entries | map(select(.key != "main" and .value != "connected") | .key) | join(", ")' <<<"${inboxclean_health:-}" 2>/dev/null)" || true
  if [ -n "$inboxclean_pending" ]; then
    report_warn "InboxClean — extra account(s) not connected: $inboxclean_pending (run 'inboxclean auth --account <name>')"
  fi
  inboxclean_extra_ok="$(jq -r '.services.gmail | to_entries | map(select(.key != "main" and .value == "connected") | .key) | join(", ")' <<<"${inboxclean_health:-}" 2>/dev/null)" || true
  if [ -n "$inboxclean_extra_ok" ]; then
    report_pass "InboxClean — extra account(s) connected: $inboxclean_extra_ok"
  fi
  # Projection readiness (binaries with /health/projections): FAIL on a
  # failed worker (exhausted restart budget — data is NOT converging),
  # WARN on draining (transient; Init drains before the port opens, so this
  # means the live subscription is racing), WARN-missing on old binaries.
  inboxclean_projections="$(jq -r '.services.projections // "missing"' <<<"${inboxclean_health:-}" 2>/dev/null)" || true
  case "$inboxclean_projections" in
  ready)
    report_pass "InboxClean — projections ready (journal drained, checkpoint current)"
    ;;
  failed)
    report_fail "InboxClean — projection FAILED (exhausted restarts; inspect /health/projections and dead-letters)"
    ;;
  draining)
    report_warn "InboxClean — projections still draining (unexpected post-Init; re-check /health/projections)"
    ;;
  missing)
    report_warn "InboxClean — no services.projections field (binary predates projection readiness)"
    ;;
  esac
  # Convergence guard (2026-08-29 drift incident): the deployed InboxClean
  # binary must match the flake.lock input rev. The unit ExecStart embeds
  # the store path 'inboxclean-<rev-prefix>' for the github input; a
  # mismatch means the switch did not take (stale prod, silently).
  inboxclean_lock_rev="$(jq -r '.nodes.inboxclean.locked.rev // empty' flake.lock 2>/dev/null)" || true
  inboxclean_deployed_rev="$(grep -oP 'inboxclean-\K[0-9a-f]{7,40}' /etc/systemd/system/inboxclean-web.service 2>/dev/null | head -1)" || true
  if [ -n "$inboxclean_lock_rev" ] && [ -n "$inboxclean_deployed_rev" ]; then
    # The package version is self.shortRev (7 chars) while the lock carries
    # the full 40-char rev — compare at the DEPLOYED string's length. The
    # original `case "$deployed" in "$lock"*` glob can never match a 7-char
    # string against a 40-char pattern (pattern longer than the string), so
    # every legit shortRev deploy read as drift on first live run (2026-08-30).
    inboxclean_lock_prefix="${inboxclean_lock_rev:0:${#inboxclean_deployed_rev}}"
    if [ "$inboxclean_deployed_rev" = "$inboxclean_lock_prefix" ]; then
      report_pass "InboxClean — deployed binary matches flake.lock (${inboxclean_deployed_rev:0:10})"
    else
      report_fail "InboxClean — DRIFT: deployed ${inboxclean_deployed_rev:0:10} != flake.lock ${inboxclean_lock_rev:0:10} (switch did not take or lock moved post-eval)"
    fi
  fi
else
  report_skip "InboxClean — service disabled (units absent from systemd)"
fi

# InboxClean -> Paperless archiving (enable-gated via the sync unit's
# EnvironmentFile reference). The check runs as the invoking user, so it can
# NOT hold the token (root-owned sops template) — assert instead that the
# auth-required document list route is alive AND auth-enforced: 401
# unauthenticated is the healthy answer. The API root is deliberately
# avoided: paperless serves it as browsable HTML only, so curl's
# "Accept: */*" is answered 302 (login redirect) and any JSON Accept is
# answered 406 regardless of token (broke the InboxClean ping upstream,
# 2026-09-03). 200 would mean auth is off (misconfig); anything else means
# paperless is down or the route moved — but paperless has its own smoke
# checks, so WARN here.
if grep -q 'inboxclean-paperless-env' /etc/systemd/system/inboxclean-sync.service 2>/dev/null; then
  paperless_api_code="$(curl -s --compressed -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:2892/api/documents/)" || true
  case "$paperless_api_code" in
  401)
    report_pass "InboxClean Paperless — document API alive, auth enforced (401 unauth; token check rides the Gatus auth check)"
    ;;
  200)
    report_fail "InboxClean Paperless — paperless /api/documents/ answered 200 WITHOUT a token (auth misconfigured on paperless?)"
    ;;
  *)
    report_warn "InboxClean Paperless — paperless /api/documents/ unreachable or unexpected code '$paperless_api_code' (paperless smoke section owns the failure path)"
    ;;
  esac
else
  report_skip "InboxClean Paperless — archiving not enabled (no env file on inboxclean-sync)"
fi

# Hermes: the read-only projects bind and the dubious-ownership gitconfig
# live ONLY inside the gateway's mount namespace — unit state and the unit
# file alone cannot prove they reached the running process. The gateway PID's
# mountinfo (world-readable) proves the ro bind; the deployed unit's
# Environment= lines prove GIT_CONFIG_GLOBAL shipped (systemd writes them
# verbatim into /etc/systemd/system/hermes.service). A missing GIT_CONFIG_GLOBAL
# would leave ALL git ops on the bind broken with "dubious ownership" —
# silent to every liveness probe (the D2 class).
hermes_enabled=false
test -e /etc/systemd/system/hermes.service && hermes_enabled=true
if $hermes_enabled; then
  # Derive stateDir from the DEPLOYED unit file (module option) — never
  # hardcode /home/hermes; another host may set services.hermes.stateDir.
  hermes_state=$(grep -oP '^WorkingDirectory=\K.*' /etc/systemd/system/hermes.service)
  if [ -z "$hermes_state" ]; then
    report_fail "Hermes — cannot derive stateDir from deployed unit (WorkingDirectory missing)"
  elif hermes_pid=$(pgrep -f 'hermes gateway run' | head -1) && [ -n "$hermes_pid" ]; then
    if grep -q " ${hermes_state}/workspace/projects ro," "/proc/$hermes_pid/mountinfo" 2>/dev/null; then
      report_pass "Hermes — RO projects bind mounted in gateway namespace"
    else
      report_fail "Hermes — gateway is running WITHOUT the read-only projects bind (check BindReadOnlyPaths / journalctl -u hermes -n 30)"
    fi
    if grep -q '^Environment=GIT_CONFIG_GLOBAL=' /etc/systemd/system/hermes.service; then
      hermes_gitconfig=$(grep -oP "^Environment=GIT_CONFIG_GLOBAL=\K\S+" /etc/systemd/system/hermes.service)
      if test -f "$hermes_gitconfig" && git config --file "$hermes_gitconfig" --get-all safe.directory | grep -q 'workspace/projects'; then
        report_pass "Hermes — git dubious-ownership allow-list deployed"
      else
        report_fail "Hermes — GIT_CONFIG_GLOBAL set but the file is missing or lacks safe.directory"
      fi
    else
      report_fail "Hermes — GIT_CONFIG_GLOBAL missing from the deployed unit: git on the projects bind fails with dubious ownership"
    fi
    # The workspace AGENTS.md itself is unobservable from this user
    # (<stateDir> is 2770 hermes-only). The v2 install script logs
    # unconditionally on every start, proving the ExecStartPre ran and what
    # it decided (installed / upgraded / preserved). NOTE: journalctl's own
    # --grep, NOT a pipe — under `set -o pipefail` a `journalctl | grep -q`
    # on the multi-MB journal SIGPIPEs (141) and false-fails the check.
    if journalctl -u hermes -b --no-pager --grep "hermes-workspace:" >/dev/null 2>&1; then
      report_pass "Hermes — workspace AGENTS.md install ran this boot"
    else
      report_fail "Hermes — workspace doc ExecStartPre left no journal line this boot (journalctl -u hermes -b | grep hermes-workspace)"
    fi
  else
    report_fail "Hermes — gateway process not found (journalctl -u hermes -n 50)"
  fi
else
  report_skip "Hermes — service disabled (unit absent from systemd)"
fi

# PapDashboard: /api/health proves the hub answers (same URL Gatus probes);
# the unauthenticated /api/ingest POST is a ROUTE-EXISTS probe — the auth
# middleware runs BEFORE routing, so 401 = route + middleware alive, while
# 404 = the deployed binary predates the ingest route (the 2026-08-18 stale
# flake-pin class: 1076× 405/404 while every liveness check stayed green) and
# 405 = a method-token mismatch (the lowercase-"post" class). The journal
# check is the only end-to-end proof that gatus's own POSTs land: 401-only
# probes can never catch method/body bugs (WARN on absence — ingests only
# fire on alert transitions, a quiet 30 min is normal).
papdashboard_enabled=false
test -e /etc/systemd/system/papdashboard.service && papdashboard_enabled=true
if $papdashboard_enabled; then
  if curl -s --compressed --max-time 10 --retry 5 --retry-delay 3 --retry-all-errors -o /dev/null "http://127.0.0.1:8088/api/health" 2>/dev/null; then
    report_pass "PapDashboard — /api/health answers"
  else
    report_fail "PapDashboard — :8088/api/health unreachable (journalctl -u papdashboard -n 30)"
  fi
  pap_ingest_code=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "http://127.0.0.1:8088/api/ingest" 2>/dev/null || echo 000)
  case "$pap_ingest_code" in
  401) report_pass "PapDashboard — /api/ingest route exists (401 = auth gate hit before routing)" ;;
  404) report_fail "PapDashboard — /api/ingest 404: deployed binary lacks the ingest route (stale flake pin? nix flake lock --update-input papdashboard)" ;;
  405) report_fail 'PapDashboard — /api/ingest 405: method-token mismatch (check gatus-config.nix method = "POST")' ;;
  *) report_fail "PapDashboard — /api/ingest probe returned $pap_ingest_code (expected 401)" ;;
  esac
  # journalctl's own --grep (PCRE): a `journalctl | grep -q` pipe here would
  # SIGPIPE (141) under pipefail once the journal exceeds the pipe buffer.
  if journalctl -u papdashboard --since '-30min' --no-pager --grep 'path=/api/ingest status=200' >/dev/null 2>&1; then
    report_pass "PapDashboard — gatus ingest 200s visible in journal (end-to-end alert path)"
  else
    report_warn "PapDashboard — no ingest 200s in the last 30 min (normal when no alert transitioned; re-check after the next Gatus alert)"
  fi
else
  report_skip "PapDashboard — service disabled (units absent from systemd)"
fi

# SigNoz coverage audit (signoz-coverage.nix): deploy.sh restarts the
# collector post-switch, so the textfile gauges are FRESH here — assert the
# fail-closed summaries directly from node-exporter :9100. This gates trace-
# coverage regressions at DEPLOY time instead of up to 5 min later (gatus
# interval). grep -o (not -q): reads the whole stream, no SIGPIPE class on
# the large /metrics body.
signoz_coverage_enabled=false
test -e /etc/systemd/system/signoz-coverage-metrics.service && signoz_coverage_enabled=true
if $signoz_coverage_enabled; then
  # missing needs a retry window: OTel batching (~5s) + a just-restarted
  # service's first command mean the collector run immediately post-switch
  # can legitimately see missing=1 (e.g. a freshly-enforced registry entry's
  # first spans). The textfile only refreshes when the collector RUNS, so
  # each retry re-runs it (restart is synchronous for the oneshot). 3
  # attempts ≈ 45s; scrape_errors is instant-fail (no legit transient).
  cov_missing=absent
  cov_errors=absent
  coverage_metrics=""
  for _attempt in 1 2 3; do
    coverage_metrics=$(curl -s --compressed --max-time 15 http://localhost:9100/metrics 2>/dev/null || true)
    if [ -n "$coverage_metrics" ]; then
      cov_missing=$(printf '%s\n' "$coverage_metrics" | grep -oP '^signoz_traces_missing \K[0-9]+' || echo absent)
      cov_errors=$(printf '%s\n' "$coverage_metrics" | grep -oP '^signoz_coverage_scrape_errors \K[0-9]+' || echo absent)
      [ "$cov_missing" = "0" ] && break
    fi
    sudo systemctl restart signoz-coverage-metrics.service 2>/dev/null || true
    sleep 10
  done
  if [ -n "$coverage_metrics" ]; then
    case "$cov_missing" in
    0) report_pass "SigNoz Coverage — traces_missing 0 (every enforced service sent spans in budget)" ;;
    absent) report_fail "SigNoz Coverage — signoz_traces_missing ABSENT from :9100 (collector never ran: journalctl -u signoz-coverage-metrics -n 20)" ;;
    *) report_fail "SigNoz Coverage — traces_missing $cov_missing after 90s retry window (service(s) dark; grep signoz_traces_reporting :9100/metrics)" ;;
    esac
    case "$cov_errors" in
    0) report_pass "SigNoz Coverage — collector scrape_errors 0" ;;
    absent) report_fail "SigNoz Coverage — signoz_coverage_scrape_errors ABSENT from :9100 (textfile stale/missing)" ;;
    *) report_fail "SigNoz Coverage — scrape_errors $cov_errors (ClickHouse queries failing: journalctl -u signoz-coverage-metrics)" ;;
    esac
  else
    report_fail "SigNoz Coverage — node-exporter :9100 unreachable"
  fi
else
  report_skip "SigNoz Coverage — module disabled (unit absent)"
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
      record_fail "Crush Daily latest report shows 0 sessions"
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

# ClickHouse XFS data mount: functional gate for the dedicated-partition
# migration. Gated on the DEPLOYED fstab declaring the mount. Do NOT gate on
# /etc/systemd/system/var-lib-clickhouse.mount — fileSystems entries render
# to /etc/fstab and their units are generated AT RUNTIME by
# systemd-fstab-generator into /run/systemd/generator/; the static path is
# never populated and the gate silently skips = phantom green (caught live
# 2026-08-22: the generator unit existed, the static one did not). If fstab
# declares the mount but it is NOT xfs (or not mounted), clickhouse.service
# refused to start by design — catch it here, not in an alert storm.
if awk '$1 !~ /^#/ && $2 == "/var/lib/clickhouse" { found = 1 } END { exit !found }' /etc/fstab 2>/dev/null; then
  CH_FSTYPE="$(findmnt -no FSTYPE /var/lib/clickhouse 2>/dev/null || true)"
  if [ "$CH_FSTYPE" = "xfs" ]; then
    echo -e "${GREEN}PASS${NC} ClickHouse data mount is XFS (/var/lib/clickhouse)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} /var/lib/clickhouse mounted as '${CH_FSTYPE:-nothing}' (expected xfs) — clickhouse.service is refusing to start by design (ConditionPathIsMountPoint). Check: systemctl status var-lib-clickhouse.mount, dmesg | grep -i xfs"
    FAIL=$((FAIL + 1))
    record_fail "/var/lib/clickhouse mount not xfs"
  fi
  if curl -sf --compressed --max-time 5 "http://127.0.0.1:8123/ping" 2>/dev/null | grep -q "Ok"; then
    echo -e "${GREEN}PASS${NC} ClickHouse answering /ping on :8123 (running on the XFS mount)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} ClickHouse not answering :8123/ping — stack down since the XFS migration deploy. Check: systemctl status clickhouse.service"
    FAIL=$((FAIL + 1))
    record_fail "ClickHouse not answering :8123/ping"
  fi
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
      record_fail "SigNoz impersonation mode NOT enabled"
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
    record_fail "SigNoz alert rules under-provisioned"
  else
    echo -e "${RED}FAIL${NC} SigNoz has ZERO alert rules — signoz-provision.service did not run or failed. Observability gap: no alerts will fire"
    FAIL=$((FAIL + 1))
    record_fail "SigNoz has ZERO alert rules"
  fi
else
  echo -e "${YELLOW}SKIP${NC} SigNoz rules endpoint not reachable"
  SKIP=$((SKIP + 1))
fi

# SigNoz: the provisioner must have CONVERGED on this deploy. A failed
# signoz-provision leaves STALE rules/dashboards in place, so the rule-count
# check above stays green off old state (2026-08-27: provisioner hard-failed
# on a dashboard layout $ref bug for ~18 min while the count check passed —
# a phantom green in this checker itself).
if systemctl list-unit-files 'signoz*' --no-legend 2>/dev/null | grep -q signoz-provision; then
  signoz_prov_result=$(systemctl show signoz-provision.service -p Result --value 2>/dev/null)
  case "$signoz_prov_result" in
  success)
    echo -e "${GREEN}PASS${NC} signoz-provision.service converged (Result=success — rules AND dashboards match nix)"
    PASS=$((PASS + 1))
    ;;
  "")
    echo -e "${YELLOW}WARN${NC} signoz-provision.service has no Result yet (never started since load?)"
    SKIP=$((SKIP + 1))
    ;;
  *)
    echo -e "${RED}FAIL${NC} signoz-provision.service Result=${signoz_prov_result} — rules/dashboards are STALE. Check: journalctl -u signoz-provision -n 50"
    FAIL=$((FAIL + 1))
    record_fail "signoz-provision.service stale"
    ;;
  esac
fi

# SigNoz: surface alerts firing longer than 24h. WARN, not FAIL — an ongoing
# incident (e.g. DAS-dependent units through the pool outage) is a legitimate
# long-firing state; the point is VISIBILITY at every deploy: a rule that can
# never resolve is usually a broken query or an unacknowledged outage.
if signoz_alerts_json=$(curl -s --compressed --max-time 5 "http://localhost:8080/api/v1/alerts" 2>/dev/null) &&
  [ -n "$signoz_alerts_json" ]; then
  LONG_FIRING=$(echo "$signoz_alerts_json" | jq -r '
    .data[]?
    | select(.status.state == "active")
    | select(((now - (.startsAt | sub("\\.[0-9]+"; "") | fromdateiso8601)) / 86400) > 1)
    | .labels.alertname' 2>/dev/null | sort -u)
  if [ -n "$LONG_FIRING" ]; then
    echo -e "${YELLOW}WARN${NC} SigNoz alerts firing >24h (ongoing incidents or unresolvable rules): $(echo "$LONG_FIRING" | tr '\n' ' ')"
    SKIP=$((SKIP + 1))
  else
    echo -e "${GREEN}PASS${NC} no SigNoz alert firing longer than 24h"
    PASS=$((PASS + 1))
  fi
fi

# llama.cpp RAG stack functional probes (enable-gated like the liveness checks
# above). POST /v1/embeddings returns a 1024-dim vector; POST /v1/rerank must
# rank the correct document first. These catch a "healthy but wrong model"
# regression (model swapped without the alias changing).
if $llama_rag_enabled; then
  if curl -s --compressed --max-time 30 -o /tmp/.smoke-lmemb -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d '{"input":"test document"}' \
    "http://localhost:8848/v1/embeddings" 2>/dev/null | grep -q "200"; then
    if jq -e '.data[0].embedding | length == 1024' /tmp/.smoke-lmemb >/dev/null 2>&1; then
      report_pass "llama.cpp Embeddings — /v1/embeddings returns a 1024-dim vector"
    else
      report_fail "llama.cpp Embeddings — /v1/embeddings answered but embedding shape is wrong (expected 1024)"
    fi
  else
    report_fail "llama.cpp Embeddings — /v1/embeddings unreachable (journalctl -u llama-embeddings -n 30)"
  fi

  if curl -s --compressed --max-time 30 -o /tmp/.smoke-lmrr -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d '{"model":"bge-reranker-v2-m3","query":"what is the capital of france","documents":["paris is the capital of france","london is the capital of england"]}' \
    "http://localhost:8849/v1/rerank" 2>/dev/null | grep -q "200"; then
    if jq -e '.results[0].index == 0' /tmp/.smoke-lmrr >/dev/null 2>&1; then
      report_pass "llama.cpp Reranker — /v1/rerank ranks the correct document first"
    else
      report_fail "llama.cpp Reranker — /v1/rerank answered but did not rank the correct document first"
    fi
  else
    report_fail "llama.cpp Reranker — /v1/rerank unreachable (journalctl -u llama-reranker -n 30)"
  fi
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
  record_fail "Monitor365 agent metrics NOT responding (localhost:9191)"
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
        record_fail "Monitor365 server reports 0 connected devices"
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
        record_fail "Monitor365 agent still not connected after restart"
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
# Enable-gated via the twenty unit (banksync pattern): a disabled Twenty
# leaves crm vHost proxying to a dead container port.
test -e /etc/systemd/system/twenty.service && check "Twenty CRM (HTTPS)" "https://crm.$DOMAIN/" "200" "<html" 2>/dev/null || true
check "Overview (HTTPS)" "https://overview.$DOMAIN/" "200" "<html" 2>/dev/null || true

# Enable-gated review tools (LAN-only, no auth)
test -e /etc/systemd/system/systemd-graph.service && check "systemd-graph (HTTPS)" "https://graph.$DOMAIN/" "200" "" 2>/dev/null || true
test -e /etc/systemd/system/systemd-timer-monitor-audit.service && check "systemd-timer-monitor (HTTPS)" "https://timers.$DOMAIN/" "200" "<html" 2>/dev/null || true

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
    record_fail "$vhost → auth gateway broken"
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

# Desktop: polkit dialog render sanity (2026-08-18 adwaita/fusion switch was
# never eyeballed post-deploy — an unresolvable QT_STYLE_OVERRIDE=kvantum
# silently beat the fusion setting from 2026-04-28 until 2026-09-02 because
# nothing ever checked the DEPLOYED env). The polkit agent host is the DMS
# quickshell instance (QuickAuthDialog.qml, QQC2). Checks the historical
# crash class without needing a GUI: every Qt style env var the deployed HM
# sets must RESOLVE, and the QQC2 "module ... is not installed" abort
# signature (the 49-restart polkit crash-loop) must be absent from the
# journal.
_desktop_user=$(id -un)
_hm_vars="/etc/profiles/per-user/${_desktop_user}/etc/profile.d/hm-session-vars.sh"
_qt_plugins="/etc/profiles/per-user/${_desktop_user}/lib/qt-6/plugins"
_qt_qml="/etc/profiles/per-user/${_desktop_user}/lib/qt-6/qml"
_polkit_problems=""
if [ -f "$_hm_vars" ]; then
  # 1. QT_STYLE_OVERRIDE must be empty or name a real QStyle: fusion/windows
  #    are qtbase built-ins; anything else needs a styles/ plugin deployed.
  _style=$(sed -n 's/^export QT_STYLE_OVERRIDE="\([^"]*\)".*/\1/p' "$_hm_vars")
  if [ -n "$_style" ] &&
    [ "$_style" != "fusion" ] && [ "$_style" != "windows" ] && [ "$_style" != "base" ] &&
    ! ls "${_qt_plugins}"/styles/lib*"${_style}"*.so >/dev/null 2>&1; then
    _polkit_problems="${_polkit_problems} QT_STYLE_OVERRIDE='${_style}' does not resolve (no styles plugin deployed);"
  fi
  # 2. QT_QUICK_CONTROLS_STYLE, if set, must have its QQC2 style module
  #    (Basic/Fusion/Imagine/Material/Universal ship with qtdeclarative).
  _controls=$(sed -n 's/^export QT_QUICK_CONTROLS_STYLE="\([^"]*\)".*/\1/p' "$_hm_vars")
  if [ -n "$_controls" ]; then
    case "$_controls" in
    Basic | Fusion | Imagine | Material | Universal) ;;
    *)
      if [ ! -d "${_qt_qml}/QtQuick/Controls.2/${_controls}" ]; then
        _polkit_problems="${_polkit_problems} QT_QUICK_CONTROLS_STYLE='${_controls}' has no QML module;"
      fi
      ;;
    esac
  fi
else
  _polkit_problems=" hm-session-vars.sh not found;"
fi
_qqc_aborts=$(journalctl --user --since "-24 hours" --grep 'is not installed' --no-pager --output cat 2>/dev/null | grep -c 'module' || true)
if [ "${_qqc_aborts:-0}" -gt 0 ]; then
  _polkit_problems="${_polkit_problems} ${_qqc_aborts} QQC2 'module ... is not installed' abort(s) in last 24h (the 2026-08-18 polkit crash-loop class);"
fi
if [ -z "$_polkit_problems" ]; then
  report_pass "Desktop — polkit dialog render sanity (Qt style env resolvable, no QQC2 aborts)"
else
  report_fail "Desktop — polkit render:${_polkit_problems} auth dialogs may fail to open (check qt.platformTheme/style in home.nix vs deployed Qt plugins)"
fi

# System pressure (PSI I/O + memory + zram combined zone) — shared,
# fixture-tested logic (scripts/lib/pressure-report.sh +
# scripts/test-post-deploy-pressure.sh). 2026-09-02 T07: the old inline
# check printed PASS "healthy" while memory PSI avg10 ran 48-77% (a live
# storm) — semantics now mirror the deploy.sh blocking gate and can never
# call a storm healthy.
systemnix_report_pressure

# --- §12 Mail Relay ---
echo ""
echo "=== Mail Relay ==="
if [ -e /etc/systemd/system/postfix.service ]; then
  if systemctl is-active --quiet postfix; then
    report_pass "Mail relay — postfix active"
  else
    report_fail "Mail relay — postfix not active (outbound mail broken; journalctl -u postfix -n 50)"
  fi

  # SMTP banner through the public socket (loopback-only null client).
  # shellcheck disable=SC2016 # $_relay_line must expand INSIDE the inner bash
  _relay_banner=$(timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/25 && read -t 3 -r _relay_line <&3 && printf %s "$_relay_line"' 2>/dev/null || true)
  case "$_relay_banner" in
  220*) report_pass "Mail relay — SMTP banner answering (220 greeting)" ;;
  "") report_fail "Mail relay — no SMTP banner on 127.0.0.1:25 (relay down or not loopback-bound)" ;;
  *) report_fail "Mail relay — unexpected SMTP banner: $_relay_banner" ;;
  esac

  # Go-live gate: the placeholder credential defers every send. Expected
  # WARN (not FAIL) until the user pastes the real Resend key and verifies
  # larsartmann.cloud — same pattern as the google-sync config check.
  if [ -r /run/secrets/rendered/mail-relay-sasl ]; then
    if grep -q "PLACEHOLDER" /run/secrets/rendered/mail-relay-sasl; then
      report_warn "Mail relay — sops credential still the PLACEHOLDER (go-live: sudo sops platforms/nixos/secrets/mail-relay.yaml, then sudo systemctl restart postfix; larsartmann.cloud must be verified in Resend first)"
    else
      report_pass "Mail relay — real upstream credential rendered"
    fi
  else
    report_warn "Mail relay — rendered SASL map missing (sops template not rendered; sends defer)"
  fi

  # Paperless consumes the relay via PAPERLESS_* settings rendered into
  # paperless.conf (NOT unit Environment — the nixpkgs module writes a conf
  # file). Gate on the deployed unit file, not systemctl is-enabled (the
  # requiredBy rc=1 trap).
  if [ -e /etc/systemd/system/paperless-web.service ]; then
    if grep -q "^PAPERLESS_EMAIL_HOST=" /var/lib/paperless/paperless.conf 2>/dev/null; then
      report_pass "Paperless — mail wiring rendered into paperless.conf (PAPERLESS_EMAIL_HOST set)"
    else
      report_fail "Paperless — PAPERLESS_EMAIL_HOST missing from paperless.conf despite relay enabled (relay-gated settings block broke)"
    fi
  else
    report_skip "Paperless — not deployed (mail wiring check skipped)"
  fi

  if [ -e /etc/systemd/system/mail-relay-metrics.timer ]; then
    if [ -f /var/lib/prometheus-node-exporter/textfile_collectors/mail-relay.prom ]; then
      report_pass "Mail relay — queue/credential collector writing textfile"
    else
      report_fail "Mail relay — collector textfile missing (mail-relay-metrics unit failing; queue depth unmonitored)"
    fi
  else
    report_skip "Mail relay — metrics collector not deployed"
  fi
else
  report_skip "Mail relay — postfix not deployed (enable services.mail-relay)"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}SKIP: $SKIP${NC}  WARN: $WARN"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo -e "${RED}❌ $FAIL check(s) failed — investigate before proceeding${NC}"

  # Fail-set baseline diff: failures already seen in the previous run are
  # known-unrelated context (advisory, exit 1); anything NEW is this run's
  # regression signal and exits 3 so automation can distinguish without
  # reading logs. The baseline self-updates every run — a persistent outage
  # is loud ONCE, then advisory, exactly so deploys stay possible while the
  # fix ships. Missing baseline (first run ever) adopts silently.
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/systemnix"
  baseline_file="$state_dir/smoke-fail-baseline.txt"
  mkdir -p "$state_dir"
  LC_ALL=C sort -u "$SMOKE_FAIL_NAMES" -o "$SMOKE_FAIL_NAMES"
  new_fails=""
  had_baseline=0
  if [ -f "$baseline_file" ]; then
    had_baseline=1
    new_fails="$(comm -13 <(LC_ALL=C sort -u "$baseline_file") "$SMOKE_FAIL_NAMES" || true)"
  fi
  cp "$SMOKE_FAIL_NAMES" "$baseline_file"

  if [ -n "$new_fails" ]; then
    echo ""
    echo -e "${RED}NEW failures vs the previous run's baseline (regression signal, exit 3):${NC}"
    printf '  - %s\n' "$new_fails"
    exit 3
  fi
  if [ "$had_baseline" -eq 1 ]; then
    echo "All FAILs match the previous run's baseline — advisory (exit 1). Baseline: $baseline_file"
  else
    echo "First run with a fail baseline — adopting this run's FAIL set (advisory, exit 1). Baseline: $baseline_file"
  fi
  exit 1
else
  echo ""
  echo -e "${GREEN}✅ All checks passed${NC}"
  exit 0
fi
