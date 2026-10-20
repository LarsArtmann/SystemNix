#!/usr/bin/env bash
# Fixture tests for the post-deploy §20 CRM OIDC readiness block
# (scripts/lib/crm-oidc-smoke.sh). The check shipped 2026-10-12 with only
# the PASS branch live-exercised (§b.2 of the outage report) — a FAIL
# rehearsal would need Pocket ID actually down (destructive), so these
# fixtures are the only exercise the disabled→FAIL / no-line→WARN / skip
# branches get. The lib is SOURCED, not re-implemented: the fixtures run
# the same crm_oidc_smoke code post-deploy-check §20 executes (the
# metrics-gate lesson — never trust a fixture that greps its own copy of
# the messages).
#
# Fixtures prove each verdict branch:
#   unit file absent                                → SKIP
#   unit file without -oidc-issuer (passkey-only)   → SKIP
#   journal: last line "oidc sign-in enabled"       → PASS
#   journal: last line "oidc sign-in disabled"      → FAIL
#   journal: no oidc line since boot (empty/absent) → WARN
#   journal: unrecognized oidc line                 → WARN
#   journal: disabled THEN enabled (restart heal)   → PASS (last line wins)
# Run: bash scripts/test-crm-oidc-smoke.sh  (also a flake check)
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/crm-oidc-smoke.sh disable=SC1091
source "$REPO_ROOT/scripts/lib/crm-oidc-smoke.sh"

EVENTS=()
crm_pass() { EVENTS+=("PASS"); }
crm_fail() { EVENTS+=("FAIL"); }
crm_warn() { EVENTS+=("WARN"); }
crm_skip() { EVENTS+=("SKIP"); }
# shellcheck disable=SC2034 # CRM_* are read inside the sourced lib via indirection
CRM_PASS=crm_pass CRM_FAIL=crm_fail CRM_WARN=crm_warn CRM_SKIP=crm_skip

TEST_FAILURES=0
expect() {
  local want="$1" desc="$2"
  if [ "${EVENTS[*]}" = "$want" ]; then
    echo "  ok   [$want] $desc"
  else
    echo "  FAIL [$want] $desc (got: ${EVENTS[*]:-none})"
    TEST_FAILURES=$((TEST_FAILURES + 1))
  fi
}
reset() { EVENTS=(); }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# journalctl stub: cats the fixture journal (env-selected), ignores args —
# the lib pipes it through `grep 'oidc sign-in' | tail -1` exactly as it
# does the live journal. Shebang is the ambient bash — a literal
# /usr/bin/env does not exist in the nix build sandbox (the selftest flake
# check runs there).
STUB_BASH="$(command -v bash)"
mkdir -p "$SCRATCH/bin"
cat >"$SCRATCH/bin/journalctl" <<STUB
#!$STUB_BASH
cat "\${FIX_JOURNAL:-$SCRATCH/absent-journal}"
STUB
chmod +x "$SCRATCH/bin/journalctl"
# shellcheck disable=SC2034 # read inside the sourced lib via indirection
CRM_JOURNALCTL="$SCRATCH/bin/journalctl"

UNIT_OK="$SCRATCH/crm-server.service"
cat >"$UNIT_OK" <<'UNIT'
[Service]
EnvironmentFile=/run/secrets/crm-oidc-env
ExecStart=/nix/store/xxx-crm/bin/crm run -listen :8080 -oidc-issuer https://auth.home.lan -oidc-client-id crm -passkeys=false
UNIT

UNIT_PASSKEY_ONLY="$SCRATCH/crm-server-passkey-only.service"
cat >"$UNIT_PASSKEY_ONLY" <<'UNIT'
[Service]
ExecStart=/nix/store/xxx-crm/bin/crm run -listen :8080
UNIT

echo "=== §20 skip branches (crm_oidc_smoke) ==="

reset
crm_oidc_smoke "$SCRATCH/no-such-unit.service"
expect "SKIP" "unit file absent → SKIP (service not deployed)"

reset
crm_oidc_smoke "$UNIT_PASSKEY_ONLY"
expect "SKIP" "unit without -oidc-issuer → SKIP (passkey-only unit by design)"

echo "=== §20 verdict branches (crm_oidc_smoke) ==="

printf '%s\n' \
  "Oct 12 13:24:47 evo-x2 crm-server[900]: time=2026-10-12T13:24:47+02:00 level=INFO msg=\"oidc sign-in enabled\" provider=pocket-id" \
  >"$SCRATCH/journal-enabled"
reset
FIX_JOURNAL="$SCRATCH/journal-enabled"
export FIX_JOURNAL
crm_oidc_smoke "$UNIT_OK"
expect "PASS" "last oidc line enabled → PASS"

printf '%s\n' \
  "Oct 12 13:08:10 evo-x2 crm-server[812]: time=2026-10-12T13:08:10+02:00 level=INFO msg=\"oidc sign-in disabled: provider init failed: ... no such host\"" \
  >"$SCRATCH/journal-disabled"
reset
FIX_JOURNAL="$SCRATCH/journal-disabled"
export FIX_JOURNAL
crm_oidc_smoke "$UNIT_OK"
expect "FAIL" "last oidc line disabled → FAIL (passkey-only degrade live)"
unset FIX_JOURNAL

reset
crm_oidc_smoke "$UNIT_OK"
expect "WARN" "OIDC flags deployed but journal has no oidc line → WARN (restart-loop class)"

printf '%s\n' \
  "Oct 12 13:09:00 evo-x2 crm-server[812]: time=2026-10-12T13:09:00+02:00 level=INFO msg=\"oidc sign-in pending\" provider=pocket-id" \
  >"$SCRATCH/journal-unrecognized"
reset
FIX_JOURNAL="$SCRATCH/journal-unrecognized"
export FIX_JOURNAL
crm_oidc_smoke "$UNIT_OK"
expect "WARN" "unrecognized oidc line → WARN (forward-compat catch)"

printf '%s\n' \
  "Oct 12 13:08:10 evo-x2 crm-server[812]: time=2026-10-12T13:08:10+02:00 level=INFO msg=\"oidc sign-in disabled: provider init failed: ... no such host\"" \
  "Oct 12 13:24:47 evo-x2 crm-server[900]: time=2026-10-12T13:24:47+02:00 level=INFO msg=\"oidc sign-in enabled\" provider=pocket-id" \
  >"$SCRATCH/journal-healed"
reset
FIX_JOURNAL="$SCRATCH/journal-healed"
export FIX_JOURNAL
crm_oidc_smoke "$UNIT_OK"
expect "PASS" "disabled then enabled (restart healed) → PASS (the LAST line is the verdict)"
unset FIX_JOURNAL

echo ""
if [ "$TEST_FAILURES" -eq 0 ]; then
  echo "crm-oidc-smoke fixtures: all branches OK"
else
  echo "crm-oidc-smoke fixtures: $TEST_FAILURES FAILURE(S)"
  exit 1
fi
