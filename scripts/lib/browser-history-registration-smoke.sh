#!/usr/bin/env bash
# Browser-history registration-gate smoke — shared by post-deploy-check
# (fixture-tested by scripts/test-browser-history-registration-smoke.sh and
# the browser-history-registration-smoke-selftest flake check). Extracted
# from the inline post-deploy leg so the fixture exercises the SAME code
# the deploy gate runs — never trust a fixture that greps its own copy of
# the messages.
#
# Contract: /auth/register sits BEHIND the CSRF middleware, so a bare probe
# answers the CSRF wall (403 csrf_invalid), never the gate — the gate's
# real state is invisible without the dance: HEAD $BRS_URL/health (the CSRF
# fetcher — middleware sets X-Csrf-Token + csrf_token cookie on every
# request) then replay both on POST /auth/register. The email is
# DELIBERATELY invalid: the Register service checks the gate BEFORE
# validation (usermgmt v4.14.3 service_register.go: gate → validate), so
# gate-closed answers 403 usermgmt.registration_closed while a
# gate-left-open regression (count-gap recurrence) answers 400 "invalid
# email" — loud, and ZERO debris either way. The 403 verdict additionally
# requires the registration_closed body: a bare 403 could be the CSRF wall
# itself rejecting a half-broken dance, which proves nothing about the gate.
#
# Env contract (all optional; fixtures stub these):
#   BRS_URL   base URL                    (default http://localhost:8087)
#   BRS_PASS / BRS_FAIL / BRS_WARN        verdict callbacks, single msg arg
#   BRS_CURL  curl binary override        (default curl)

browser_history_registration_smoke() {
  local url="${BRS_URL:-http://localhost:8087}"
  local curl_bin="${BRS_CURL:-curl}"
  local pass_cb="${BRS_PASS:-echo PASS}"
  local fail_cb="${BRS_FAIL:-echo FAIL}"
  local warn_cb="${BRS_WARN:-echo WARN}"

  local csrf_hdr csrf_body token cookie reg_code body_matched body_head
  csrf_hdr=$(mktemp)
  csrf_body=$(mktemp)
  token=""
  cookie=""
  if "$curl_bin" -sS -I -o /dev/null -D "$csrf_hdr" --max-time 10 \
    "$url/health" >/dev/null 2>&1; then
    token=$(grep -i '^x-csrf-token:' "$csrf_hdr" | tail -1 | tr -d '\r' | cut -d' ' -f2)
    cookie=$(grep -i '^set-cookie:' "$csrf_hdr" | grep -i 'csrf_token=' | tail -1 | tr -d '\r' | sed 's/^[Ss]et-[Cc]ookie: //' | cut -d';' -f1)
  fi
  if [ -z "$token" ] || [ -z "$cookie" ]; then
    "$fail_cb" "Browser History - registration-gate smoke could not fetch CSRF token+cookie from /health (server answered no CSRF headers)"
    rm -f "$csrf_hdr" "$csrf_body"
    return 1
  fi
  reg_code=$("$curl_bin" -s -o "$csrf_body" -w "%{http_code}" --max-time 10 \
    -X POST "$url/auth/register" \
    -H "Cookie: $cookie" \
    -H "X-Csrf-Token: $token" \
    -H "Content-Type: application/json" \
    --data '{"email":"not-an-email"}' 2>/dev/null || echo none)
  # Capture body-derived facts BEFORE deleting the tempfile.
  body_matched=1
  grep -q 'registration_closed' "$csrf_body" 2>/dev/null || body_matched=0
  body_head=$(head -c 200 "$csrf_body" 2>/dev/null)
  rm -f "$csrf_hdr" "$csrf_body"
  if [ "$reg_code" = "403" ] && [ "$body_matched" = "1" ]; then
    "$pass_cb" "Browser History - registration gate CLOSED (CSRF dance through the wall, 403 usermgmt.registration_closed)"
    return 0
  elif [ "$reg_code" = "403" ]; then
    "$fail_cb" "Browser History - register probe answered 403 WITHOUT registration_closed (body: ${body_head:-empty}) — the CSRF wall or another rejection, gate state not proven"
    return 1
  elif [ "$reg_code" = "400" ]; then
    "$fail_cb" "Browser History - registration gate OPEN: /auth/register reached validation past MAX_USERS (count-gap recurrence — see docs/todo/upstream.md gate-count row)"
    return 1
  elif [ "$reg_code" = "429" ]; then
    "$warn_cb" "Browser History - register probe rate-limited (429); gate state not proven this run"
    return 0
  else
    "$fail_cb" "Browser History - register probe unexpected status ${reg_code:-none} (body: ${body_head:-empty})"
    return 1
  fi
}
