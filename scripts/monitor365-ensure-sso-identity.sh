#!/usr/bin/env bash
# monitor365-ensure-sso-identity — pre-start heal for the Pocket ID SSO
# identity monitor365 matches logins against (email ONLY, no JIT
# provisioning).
#
# Runs as an ExecStartPre of monitor365-server.service. That placement is
# the whole design constraint: this script guards an AUXILIARY heal (SSO
# login keeps working after a DB restore loses the user row), while the
# unit it runs under IS the control plane. A heal that fails closed takes
# down telemetry collection, the realtime API and the dashboard to protect
# one login path — strictly worse than the condition it repairs. So this
# script is fail-open by construction: only a genuinely unclassifiable
# condition warns, and nothing here ever exits non-zero once the database
# has been consulted.
#
# Why the outcome is classified rather than asserted: upstream exposes NO
# read-only identity probe (`verify-bootstrap` validates env config only,
# `create-admin` is the only user-facing command; crates/server/src/
# admin_cmd.rs, source-verified 2026-10-28). The write attempt is
# therefore also the state assertion, and a UNIQUE-CONSTRAINT violation on
# (tenant_id, lower(email)) is POSITIVE PROOF the row exists — the DB
# itself just told us so. Upstream's pre-check phrasing is not stable
# ("User ... already exists" today, a bare "Duplicate key ... violates
# unique constraint" once the read path and the write path disagree,
# live 2026-10-28 22:54 → restart loop → start-limit-hit), so matching the
# wording alone is what took the control plane down for 2.5 h.
#
# Usage: monitor365-ensure-sso-identity.sh [admin-email]
#        (falls back to $MONITOR365_ADMIN_EMAIL)
# Needs: monitor365-server + coreutils on PATH.

set -uo pipefail

email="${1:-${MONITOR365_ADMIN_EMAIL:-}}"
if [ -z "$email" ]; then
  # Misconfiguration, not a database verdict: this one DOES fail, because
  # silently continuing would leave the identity heal permanently inert
  # while appearing healthy.
  echo "monitor365-ensure-sso-identity: ERROR: no admin email given (argv[1] or MONITOR365_ADMIN_EMAIL)" >&2
  exit 2
fi

if out="$(monitor365-server create-admin --email "$email" 2>&1)"; then
  echo "monitor365-ensure-sso-identity: created SSO admin ${email}"
  exit 0
fi

case "$out" in
  *"already exists"*)
    echo "monitor365-ensure-sso-identity: SSO admin ${email} already exists"
    ;;
  *"Duplicate key"* | *"violates unique constraint"*)
    echo "monitor365-ensure-sso-identity: SSO admin ${email} already exists (unique constraint on tenant_id + email)"
    ;;
  *"No tenants found"*)
    echo "monitor365-ensure-sso-identity: WARNING: no tenants yet — in-server bootstrap provisions tenant+admin when fully configured" >&2
    ;;
  *)
    echo "monitor365-ensure-sso-identity: WARNING: create-admin failed for an unrecognised reason; continuing so the control plane can start. SSO logins may 401 with 'Unauthorized: SSO user not found' until the identity exists. Remediation: monitor365-server create-admin --email ${email}. Output was: ${out}" >&2
    ;;
esac

exit 0
