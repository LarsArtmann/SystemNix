#!/usr/bin/env bash
# Fixture for scripts/monitor365-pool-copy-guard.sh — executed via
# checks.monitor365-pool-copy-guard-selftest so the ExecStartPre is never
# first exercised on a live backup overrun. Stubs `systemctl` on PATH;
# no bus, no units, no privileges needed.
# MONITOR365_POOL_COPY_GUARD_SCRIPT overrides the script under test.
set -uo pipefail

FAILURES=0
pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

SCRIPT="${MONITOR365_POOL_COPY_GUARD_SCRIPT:-$(dirname "$0")/monitor365-pool-copy-guard.sh}"
STUB_DIR="$(mktemp -d)"

# Writes a systemctl stub printing $1 and exiting $2, then runs the guard.
run_with() {
  # Shebang must be the RUNNING bash, not /usr/bin/env: the sandboxed
  # check builder has no /usr/bin/env, and the stub silently "failed"
  # with a bad interpreter instead of exercising the guard (sso fixture
  # lesson, caught by leg1 on that check's first run).
  cat >"$STUB_DIR/systemctl" <<STUB
#!${BASH}
cat <<'MSG'
$1
MSG
exit ${2:-0}
STUB
  chmod +x "$STUB_DIR/systemctl"
  PATH="$STUB_DIR:$PATH" bash "$SCRIPT" 2>&1
}

# ── Busy states → refuse (copying would race the quiesced window) ──
rc=0
OUT=$(run_with "active" 0) || rc=$?
[ "$rc" -ne 0 ] && pass "leg1 active refuses" || fail "leg1 active exited 0: ${OUT}"
echo "$OUT" | grep -q "still active" &&
  pass "leg1 message names the state" || fail "leg1 wrong message: ${OUT}"

rc=0
OUT=$(run_with "activating" 0) || rc=$?
[ "$rc" -ne 0 ] && pass "leg2 activating refuses" || fail "leg2 activating exited 0: ${OUT}"

rc=0
OUT=$(run_with "reloading" 0) || rc=$?
[ "$rc" -ne 0 ] && pass "leg3 reloading refuses" || fail "leg3 reloading exited 0: ${OUT}"

# ── Dead states → proceed (is-active exits nonzero; stdout decides) ──
rc=0
OUT=$(run_with "inactive" 3) || rc=$?
[ "$rc" -eq 0 ] && pass "leg4 inactive proceeds" || fail "leg4 inactive exited ${rc}: ${OUT}"

# "failed" = the 30-min timeout killed the backup: writer gone, file
# settled, the copy may proceed.
rc=0
OUT=$(run_with "failed" 3) || rc=$?
[ "$rc" -eq 0 ] && pass "leg5 failed (timeout kill) proceeds" || fail "leg5 failed exited ${rc}: ${OUT}"

rc=0
OUT=$(run_with "unknown" 4) || rc=$?
[ "$rc" -eq 0 ] && pass "leg6 unknown proceeds" || fail "leg6 unknown exited ${rc}: ${OUT}"

# ── Unreadable state → fail CLOSED (copying blind is worse than a ──
# ── skipped night; backup-coordination alerts on pool staleness)  ──
rc=0
OUT=$(run_with "" 1) || rc=$?
[ "$rc" -ne 0 ] && pass "leg7 bus failure refuses" || fail "leg7 bus failure exited 0: ${OUT}"
echo "$OUT" | grep -q "refusing to copy blind" &&
  pass "leg7 fail-closed message" || fail "leg7 wrong message: ${OUT}"

if [ "$FAILURES" -eq 0 ]; then
  echo "monitor365-pool-copy-guard fixture: ALL LEGS GREEN"
  exit 0
fi
echo "monitor365-pool-copy-guard fixture: $FAILURES FAILURE(S)"
exit 1
