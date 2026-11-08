#!/usr/bin/env bash
# Fixture battery for the 2026-10-28 post-deploy probe additions (they
# shipped verification-checked-only: docs/status/2026-10-28_01-20_… §b.1/b.2):
#
#   Leg A  unit_enabled wants-symlink harness (lib/unit-enabled-probe.sh):
#          multi-user / timer-alias / late-applications / other-unit
#          carve-out / present-but-disabled / absent — against a fixture
#          root reached through a SYMLINKED /etc/systemd/system (the
#          trailing-slash trap the first version shipped with: find does
#          not follow a symlinked root, so the passing legs only stay
#          green while the slash survives).
#
#   Leg B  authenticated /api/ingest probe status matrix
#          (lib/pap-ingest-probe.sh) against a fixture HTTP server:
#          2xx pass; 401/403/405/400/422 each map to their NAMED fail
#          diagnosis; transport reset maps to the catch-all. The server
#          also records the winning request so the probe's wire shape
#          (method, Authorization bearer, JSON body keys) is pinned — the
#          body was mirrored from gatus-config.nix and never fired at
#          authoring time.
#
#   Leg C  wiring pins: post-deploy-check.sh must source both libs and
#          carry no inline definitions (a re-inline would silently orphan
#          legs A/B from the file deploys actually run).
#
# Run directly or via the post-deploy-probe-selftest flake check.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/unit-enabled-probe.sh disable=SC1091
source "$here/lib/unit-enabled-probe.sh"
# shellcheck source=lib/pap-ingest-probe.sh disable=SC1091
source "$here/lib/pap-ingest-probe.sh"

PASS_CNT=0
FAIL_CNT=0
ok() { PASS_CNT=$((PASS_CNT + 1)); }
bad() {
  echo "FAIL: $1" >&2
  FAIL_CNT=$((FAIL_CNT + 1))
}
assert_eq() { # assert_eq <desc> <got> <want>
  if [ "$2" = "$3" ]; then ok; else bad "$1: got '$2', want '$3'"; fi
}
assert_contains() { # assert_contains <desc> <haystack> <needle>
  case "$2" in
  *"$3"*) ok ;;
  *) bad "$1: '$3' not found in: $2" ;;
  esac
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Leg A: unit_enabled harness ───────────────────────────────────────────
# Fixture root: /etc/systemd/system as a symlink to the static tree — the
# live shape the trailing-slash comment documents. The stub find remaps the
# hardcoded probe root onto the fixture and execs the REAL find, so the
# symlink-following behavior under test is the real binary's.
FIX="$WORK/etcroot"
mkdir -p "$FIX/etc/systemd" "$FIX/etc/static/systemd/system" "$FIX/bin"
ln -s "$FIX/etc/static/systemd/system" "$FIX/etc/systemd/system"
SYSTEM_DIR="$FIX/etc/static/systemd/system"
mkdir -p \
  "$SYSTEM_DIR/multi-user.target.wants" \
  "$SYSTEM_DIR/timers.target.wants" \
  "$SYSTEM_DIR/late-applications.target.wants" \
  "$SYSTEM_DIR/paperless-scheduler.service.wants"
ln -s /dev/null "$SYSTEM_DIR/multi-user.target.wants/papdashboard.service"
ln -s /dev/null "$SYSTEM_DIR/timers.target.wants/gc.timer"
ln -s /dev/null "$SYSTEM_DIR/late-applications.target.wants/tq-agent-pool.service"
ln -s /dev/null "$SYSTEM_DIR/paperless-scheduler.service.wants/paperless-web.service"
: >"$SYSTEM_DIR/dead.service" # present but NOT enabled (the NixOS always-writes-unit-files class)

REAL_FIND="$(command -v find)"
cat >"$FIX/bin/find" <<EOF
#!$(command -v bash)
if [ "\$1" = "/etc/systemd/system/" ]; then
  shift
  exec "$REAL_FIND" "$FIX/etc/systemd/system/" "\$@"
fi
exec "$REAL_FIND" "\$@"
EOF
chmod +x "$FIX/bin/find"

run_ue() { # run_ue <unit> — unit_enabled with the fixture find on PATH
  PATH="$FIX/bin:$PATH" unit_enabled "$1"
}
ue() { # ue <desc> <unit> <want:0|1>
  if run_ue "$2"; then got=0; else got=1; fi
  assert_eq "$1" "$got" "$3"
}
ue "multi-user wants symlink enables" papdashboard.service 0
ue "same-name timer alias enables" gc.service 0
ue "other-unit wants carve-out enables (paperless-web)" paperless-web.service 0
ue "late-applications wants enables" tq-agent-pool.service 0
ue "present-but-unenabled unit does NOT enable" dead.service 1
ue "absent unit does NOT enable" never-defined.service 1

# ── Leg B: ingest probe status matrix ─────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  bad "python3 required for the fixture ingest server"
elif ! command -v curl >/dev/null 2>&1; then
  bad "curl required for the ingest probe legs"
else
  start_ingest_fixture() { # start_ingest_fixture <portfile> <status|reset>
    rm -f "$1"
    python3 - "$1" "$2" "$WORK/last_request" "$WORK/last_body" <<'PY' &
import http.server, os, sys

portfile, status, reqfile, bodyfile = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

import socket, struct

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        with open(reqfile, "w") as f:
            f.write("%s %s\n" % (self.command, self.path))
            for k, v in self.headers.items():
                f.write("%s: %s\n" % (k, v))
        with open(bodyfile, "wb") as f:
            f.write(body)
        if status == "reset":
            # Force an RST close (linger 0): curl sees a mid-response reset
            # and reports 000 — the deterministic transport-fail shape. A
            # bare wfile.close() here crashes the handler's flush instead.
            self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
            self.close_connection = True
            return
        self.send_response(int(status))
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, *a):
        pass

srv = http.server.HTTPServer(("127.0.0.1", 0), H)
with open(portfile, "w") as f:
    f.write(str(srv.server_port))
srv.handle_request()
PY
  }

  wait_portfile() { # wait_portfile <portfile>
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      [ -s "$1" ] && return 0
      sleep 0.2
    done
    return 1
  }

  verdict_pass_msgs=()
  verdict_fail_msgs=()
  vpass() { verdict_pass_msgs+=("$1"); }
  vfail() { verdict_fail_msgs+=("$1"); }

  matrix_leg() { # matrix_leg <status|reset> <want:PASS|FAIL> <needle-in-msg>
    local status="$1" want="$2" needle="$3" portfile msg
    portfile="$WORK/port.$status"
    start_ingest_fixture "$portfile" "$status"
    if ! wait_portfile "$portfile"; then
      bad "matrix $status: fixture server never reported its port"
      return
    fi
    local port
    port="$(cat "$portfile")"
    verdict_pass_msgs=()
    verdict_fail_msgs=()
    local code
    code="$(pap_ingest_post "http://127.0.0.1:$port/api/ingest" "fixture-key" triggered)"
    pap_ingest_verdict "$code" vpass vfail
    if [ "$want" = PASS ]; then
      assert_eq "matrix $status verdict kind" "${#verdict_pass_msgs[@]}" 1
      assert_eq "matrix $status fail msgs empty" "${#verdict_fail_msgs[@]}" 0
      msg="${verdict_pass_msgs[0]:-}"
    else
      assert_eq "matrix $status verdict kind" "${#verdict_fail_msgs[@]}" 1
      assert_eq "matrix $status pass msgs empty" "${#verdict_pass_msgs[@]}" 0
      msg="${verdict_fail_msgs[0]:-}"
    fi
    assert_contains "matrix $status named diagnosis" "$msg" "$needle"
    wait # reap the fixture server
  }

  matrix_leg 200 PASS "accepted"
  matrix_leg 201 PASS "accepted"
  matrix_leg 204 PASS "accepted"
  matrix_leg 401 FAIL "rotation drift"
  matrix_leg 403 FAIL "rotation drift"
  matrix_leg 405 FAIL "method-token mismatch"
  matrix_leg 400 FAIL "schema drift"
  matrix_leg 422 FAIL "schema drift"
  matrix_leg 500 FAIL "returned 500"
  matrix_leg reset FAIL "returned 000"

  # Wire-shape leg: the 200 leg's recorded request must carry POST, the
  # ingest path, the bearer key, and the alert body keys gatus-config.nix
  # sends (the probe's body was mirrored from there, never live-fired).
  assert_eq "probe method+path" "$(head -1 "$WORK/last_request")" "POST /api/ingest"
  assert_contains "probe carries bearer key" "$(cat "$WORK/last_request")" "Authorization: Bearer fixture-key"
  assert_contains "probe body: aggregateId" "$(cat "$WORK/last_body")" '"aggregateId":"postdeploy-smoke"'
  assert_contains "probe body: event type" "$(cat "$WORK/last_body")" '"type":"alert.triggered"'
  assert_contains "probe body: metadata" "$(cat "$WORK/last_body")" '"metadata":{"correlationId":"postdeploy"'
  assert_contains "probe body: content type header" "$(cat "$WORK/last_request")" "Content-Type: application/json"

  # Key-discovery legs (PAP_INGEST_ENV_FILES seam): first matching key name
  # wins, the second file is consulted only when the first yields nothing,
  # and an env with neither key name resolves empty.
  printf 'PAP_API_KEY=alpha\nOTHER=1\n' >"$WORK/env-a"
  printf 'PAPDASHBOARD_INGEST_KEY=beta\n' >"$WORK/env-b"
  printf 'OTHER=1\n' >"$WORK/env-c"
  PAP_INGEST_ENV_FILES="$WORK/env-a" pap_ingest_resolve_key
  assert_eq "resolve prefers PAP_API_KEY" "${pap_ingest_key:-}" "alpha"
  PAP_INGEST_ENV_FILES="$WORK/env-c $WORK/env-b" pap_ingest_resolve_key
  assert_eq "resolve falls through empty-name file" "${pap_ingest_key:-}" "beta"
  PAP_INGEST_ENV_FILES="$WORK/env-c" pap_ingest_resolve_key
  assert_eq "resolve empty on no key name" "${pap_ingest_key:-}" ""
  PAP_INGEST_ENV_FILES="$WORK/env-missing $WORK/env-a" pap_ingest_resolve_key
  assert_eq "resolve skips unreadable files" "${pap_ingest_key:-}" "alpha"
fi

# ── Leg C: wiring pins against the deployed-artifact copy ─────────────────
PC="$here/post-deploy-check.sh"
if [ ! -r "$PC" ]; then
  # Direct-run outside the selftest staging: resolve the repo copy.
  PC="$here/../post-deploy-check.sh"
fi
assert_contains "post-deploy-check sources unit-enabled-probe" "$(cat "$PC")" 'lib/unit-enabled-probe.sh'
assert_contains "post-deploy-check sources pap-ingest-probe" "$(cat "$PC")" 'lib/pap-ingest-probe.sh'
if grep -q '^unit_enabled() {' "$PC"; then bad "post-deploy-check re-inlined unit_enabled (orphans leg A from the deployed file)"; else ok; fi
if grep -q '^pap_ingest_post() {' "$PC"; then bad "post-deploy-check re-inlined pap_ingest_post (orphans leg B from the deployed file)"; else ok; fi

echo "post-deploy probe fixtures: $PASS_CNT passed, $FAIL_CNT failed"
if [ "$FAIL_CNT" -gt 0 ]; then exit 1; fi
exit 0
