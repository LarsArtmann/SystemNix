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

start_fixture() { # port mode
  python3 - "$1" "$2" <<'PY' &
import http.server, sys

port = int(sys.argv[1])
mode = sys.argv[2]

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

http.server.HTTPServer(("127.0.0.1", port), H).serve_forever()
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
bh_fail() { echo "VERDICT:FAIL"; }
bh_warn() { echo "VERDICT:WARN"; }

run_case() { # port mode expect_verdict expect_rc description
  local port="$1" mode="$2" expect_verdict="$3" expect_rc="$4" desc="$5"
  local out rc=0 verdict
  start_fixture "$port" "$mode"
  # Wait for the listener (bounded).
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$port/health" && break
    sleep 0.3
  done
  out=$(BRS_URL="http://127.0.0.1:$port" \
    BRS_PASS=bh_pass BRS_FAIL=bh_fail BRS_WARN=bh_warn \
    browser_history_registration_smoke) || rc=$?
  stop_fixture
  verdict=$(printf '%s\n' "$out" | sed -n 's/^VERDICT://p' | tail -1)
  verdict="${verdict:-none}"
  if [ "$verdict" != "$expect_verdict" ]; then
    echo "FAIL: $desc — expected verdict $expect_verdict, got '$verdict' (rc=$rc)"
    failures=$((failures + 1))
  elif [ "$rc" != "$expect_rc" ]; then
    echo "FAIL: $desc — expected rc $expect_rc, got $rc (verdict ok)"
    failures=$((failures + 1))
  else
    echo "ok: $desc -> $verdict (rc=$rc)"
  fi
}

run_case 18451 gate-closed      PASS 0 "gate closed (403 + registration_closed body)"
run_case 18452 gate-open        FAIL 1 "gate OPEN regression (400 invalid email) — the §f.15 branch"
run_case 18453 no-csrf-headers  FAIL 1 "no CSRF headers on /health"
run_case 18454 csrf-wall-403    FAIL 1 "bare 403 without registration_closed body (body match is load-bearing)"
run_case 18455 rate-limited     WARN 0 "rate-limited probe (429) warns, never fails"
run_case 18456 unexpected       FAIL 1 "unexpected status (500)"

if [ "$failures" -gt 0 ]; then
  echo "test-browser-history-registration-smoke: $failures failure(s)"
  exit 1
fi
echo "test-browser-history-registration-smoke: all 6 cases green"
