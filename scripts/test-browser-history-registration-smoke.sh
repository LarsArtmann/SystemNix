#!/usr/bin/env bash
# Fixture battery for scripts/lib/browser-history-registration-smoke.sh
# (run directly or via the browser-history-registration-smoke-selftest
# flake check). Spins a stub HTTP server per mode and asserts the verdict
# branches — the 400-open-gate regression branch (§f.15 of the 2026-10-15
# self-review: the leg shipped without a negative test) above all.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/browser-history-registration-smoke.sh disable=SC1091
source "$here/lib/browser-history-registration-smoke.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "test-browser-history-registration-smoke: python3 required (fixture server)" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "test-browser-history-registration-smoke: curl required" >&2
  exit 1
fi

failures=0
fixture_pid=""

# The fixture binds port 0 (kernel-assigned) and reports the chosen port
# via a file — fixed high ports lose at ephemeral-port roulette: the kernel's
# outbound range (32768-60999) overlaps any fixed port there, and an
# unrelated ESTABLISHED connection (2026-10-15: 39452↔9100) blocks bind
# with EADDRINUSE while ss -l shows nothing.
start_fixture() { # portfile mode
  local portfile="$1" mode="$2"
  rm -f "$portfile"
  python3 - "$portfile" "$mode" <<'PY' &
import http.server, os, sys

portfile, mode = sys.argv[1], sys.argv[2]

class H(http.server.BaseHTTPRequestHandler):
    def _dance_headers(self):
        self.send_header("X-Csrf-Token", "stub-token")
        self.send_header("Set-Cookie", "csrf_token=stub-cookie; Path=/")

    def _body(self, code, payload, dance=True):
        data = payload.encode()
        self.send_response(code)
        if dance:
            self._dance_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_HEAD(self):
        if mode == "no-csrf-headers":
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self._body(200, "{}")

    do_GET = do_HEAD

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        self.rfile.read(length)
        if mode == "gate-closed":
            self._body(403, '{"code":"usermgmt.registration_closed"}')
        elif mode == "gate-open":
            self._body(400, '{"error":"invalid email"}')
        elif mode == "csrf-wall-403":
            # dance IS valid here but the gate body is absent: a bare-403
            # must NOT read as "gate closed" (the body match is load-bearing)
            self._body(403, '{"code":"csrf_invalid"}')
        elif mode == "rate-limited":
            self._body(429, '{"error":"slow down"}')
        else:
            self._body(500, '{"error":"boom"}')

    def log_message(self, *args):
        pass

srv = http.server.HTTPServer(("127.0.0.1", 0), H)
with open(portfile, "w") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
PY
  fixture_pid=$!
}

stop_fixture() {
  if [ -n "$fixture_pid" ]; then
    kill "$fixture_pid" 2>/dev/null || true
    wait "$fixture_pid" 2>/dev/null || true
    fixture_pid=""
  fi
}
trap stop_fixture EXIT

bh_pass() { echo "VERDICT:PASS"; }
bh_fail() { echo "VERDICT:FAIL:$1"; }
bh_warn() { echo "VERDICT:WARN"; }

run_case() { # mode expect_verdict expect_rc description [expect_msg]
  local mode="$1" expect_verdict="$2" expect_rc="$3" desc="$4" expect_msg="${5:-}"
  local out rc=0 verdict portfile port i
  portfile=$(mktemp)
  start_fixture "$portfile" "$mode"
  # Wait for the fixture to report its kernel-assigned port (bounded).
  port=""
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    port=$(cat "$portfile" 2>/dev/null || true)
    [ -n "$port" ] && break
    sleep 0.3
  done
  rm -f "$portfile"
  if [ -z "$port" ]; then
    echo "FAIL: $desc — fixture never reported a port"
    stop_fixture
    failures=$((failures + 1))
    return
  fi
  out=$(BRS_URL="http://127.0.0.1:$port" \
    BRS_PASS=bh_pass BRS_FAIL=bh_fail BRS_WARN=bh_warn \
    browser_history_registration_smoke) || rc=$?
  stop_fixture
  verdict=$(printf '%s\n' "$out" | sed -n 's/^VERDICT://p' | tail -1)
  verdict="${verdict:-none}"
  verdict_class="${verdict%%:*}"
  if [ "$verdict_class" != "$expect_verdict" ]; then
    echo "FAIL: $desc — expected verdict $expect_verdict, got '$verdict' (rc=$rc)"
    failures=$((failures + 1))
  elif [ "$rc" != "$expect_rc" ]; then
    echo "FAIL: $desc — expected rc $expect_rc, got $rc (verdict ok)"
    failures=$((failures + 1))
  elif [ -n "$expect_msg" ] && ! printf '%s\n' "$verdict" | grep -q "$expect_msg"; then
    echo "FAIL: $desc — verdict did not come from the expected branch (wanted '$expect_msg' in: $verdict)"
    failures=$((failures + 1))
  else
    echo "ok: $desc -> $verdict (rc=$rc)"
  fi
}

run_case gate-closed PASS 0 "gate closed (403 + registration_closed body)"
run_case gate-open FAIL 1 "gate OPEN regression (400 invalid email) — the §f.15 branch" "gate OPEN"
run_case no-csrf-headers FAIL 1 "no CSRF headers on /health"
run_case csrf-wall-403 FAIL 1 "bare 403 without registration_closed body (body match is load-bearing)"
run_case rate-limited WARN 0 "rate-limited probe (429) warns, never fails"
run_case unexpected FAIL 1 "unexpected status (500)"

if [ "$failures" -gt 0 ]; then
  echo "test-browser-history-registration-smoke: $failures failure(s)"
  exit 1
fi
echo "test-browser-history-registration-smoke: all 6 cases green"
