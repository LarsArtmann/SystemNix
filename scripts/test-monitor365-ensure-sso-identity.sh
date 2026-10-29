#!/usr/bin/env bash
# Fixture for scripts/monitor365-ensure-sso-identity.sh — executed via
# checks.monitor365-sso-identity-selftest so the ExecStartPre is never
# first exercised on boot. Stubs `monitor365-server` on PATH; no DuckDB
# needed.
# MONITOR365_SSO_IDENTITY_SCRIPT overrides the script under test.
set -uo pipefail

FAILURES=0
pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

SCRIPT="${MONITOR365_SSO_IDENTITY_SCRIPT:-$(dirname "$0")/monitor365-ensure-sso-identity.sh}"
STUB_DIR="$(mktemp -d)"
EMAIL="lars@example.test"

# Writes a stub that prints $1 and exits $2, then runs the script against it.
run_with() {
  # $1 = stdout/stderr text, $2 = exit code
  cat >"$STUB_DIR/monitor365-server" <<STUB
#!/usr/bin/env bash
cat <<'MSG'
$1
MSG
exit ${2:-0}
STUB
  chmod +x "$STUB_DIR/monitor365-server"
  PATH="$STUB_DIR:$PATH" bash "$SCRIPT" "$EMAIL" 2>&1
}

# ── Leg 1: fresh create succeeds → reported as created, exit 0 ──
rc=0
OUT=$(run_with "created admin ${EMAIL}" 0) || rc=$?
[ "$rc" -eq 0 ] && pass "leg1 exit 0" || fail "leg1 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "created SSO admin" &&
  pass "leg1 create path" || fail "leg1 wrong message: ${OUT}"

# ── Leg 2: current upstream wording ("already exists") → exit 0 ──
rc=0
OUT=$(run_with "Error: User '${EMAIL}' already exists in tenant t1" 1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg2 exit 0" || fail "leg2 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "already exists$" &&
  pass "leg2 legacy wording classified" || fail "leg2 wrong message: ${OUT}"

# ── Leg 3: THE 2026-10-28 REGRESSION — unique-constraint proof of presence ──
# This is the exact upstream output that put the control plane into a
# restart loop: the read path disagreed with the write path, so the insert
# hit the index instead of the pre-check. Exit 0 is mandatory.
rc=0
OUT=$(run_with "Error: Failed to create admin user: Database error: Constraint Error: Duplicate key \"tenant_id: t-abc, email: ${EMAIL}\" violates unique constraint." 1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg3 exit 0 on unique-constraint" || fail "leg3 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "unique constraint on tenant_id + email" &&
  pass "leg3 duplicate-key classified as present" || fail "leg3 wrong message: ${OUT}"

# ── Leg 4: empty tenant set is a WARN, not a failure ──
rc=0
OUT=$(run_with "Error: No tenants found. Run 'init' first." 1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg4 exit 0" || fail "leg4 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "no tenants yet" &&
  pass "leg4 warns on empty tenant set" || fail "leg4 wrong message: ${OUT}"

# ── Leg 5: unrecognised failure is fail-OPEN (never gates the unit) ──
rc=0
OUT=$(run_with "Error: Conflicting lock is held" 1) || rc=$?
[ "$rc" -eq 0 ] && pass "leg5 fail-open exit 0" || fail "leg5 exit ${rc}: ${OUT}"
echo "$OUT" | grep -q "WARNING: create-admin failed for an unrecognised reason" &&
  pass "leg5 loud warning" || fail "leg5 missing warning: ${OUT}"
echo "$OUT" | grep -q "monitor365-server create-admin --email ${EMAIL}" &&
  pass "leg5 remediation named" || fail "leg5 remediation missing: ${OUT}"

# ── Leg 6: missing email is a real error (heal would be inert) ──
rc=0
OUT=$(MONITOR365_ADMIN_EMAIL="" PATH="$STUB_DIR:$PATH" bash "$SCRIPT" 2>&1) || rc=$?
[ "$rc" -eq 2 ] && pass "leg6 exit 2 on missing email" || fail "leg6 exit ${rc}: ${OUT}"

# ── Leg 7: argv wins over the env fallback ──
rc=0
OUT=$(MONITOR365_ADMIN_EMAIL="env@example.test" PATH="$STUB_DIR:$PATH" bash "$SCRIPT" "argv@example.test" 2>&1) || rc=$?
echo "$OUT" | grep -q "argv@example.test" &&
  pass "leg7 argv email used" || fail "leg7 env email leaked: ${OUT}"

if [ "$FAILURES" -eq 0 ]; then
  echo "monitor365-ensure-sso-identity fixture: ALL LEGS GREEN"
  exit 0
fi
echo "monitor365-ensure-sso-identity fixture: $FAILURES FAILURE(S)"
exit 1
