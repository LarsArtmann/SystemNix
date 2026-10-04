#!/usr/bin/env bash
# cv-oidc-gate.sh — the cv-server anti-replay restart gate (2026-10-03 class).
#
# cv-server replays the full CRM event history on every start and the CV
# syncer's idempotency is in-memory only (companies dedupe via
# find-before-create, opportunities DO NOT) — the unconditional converge
# restart duplicated 10,489 opportunities on 2026-10-03 16:17. deploy.sh
# therefore restarts cv-server ONLY when the re-rendered OIDC env file
# actually changed (sha256 of /var/lib/cv-oidc/client-secret.env before vs
# after the cv-oidc-env.service converge restart). Drop this gate only after
# the CV syncer grows a durable replay checkpoint.
#
# Pure decision function: no systemctl, no filesystem access — deploy.sh owns
# the plumbing, scripts/check-cv-oidc-gate.sh owns the contract test (the
# echo strings are the deploy-output smoke contract, byte-stable).

cv_oidc_gate_decide() {
  # args: <sha_before> <sha_after>  (deploy.sh passes full sha256sum output
  # lines; the literal "absent" stands in for a missing file)
  # echoes exactly one deploy-facing line; returns 0 = restart cv-server,
  # 1 = skip (unchanged).
  if [ "$1" != "$2" ]; then
    echo "Restarting cv-oidc-env.service + cv-server.service (OIDC client secret changed)"
    return 0
  fi
  echo "cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)"
  return 1
}
