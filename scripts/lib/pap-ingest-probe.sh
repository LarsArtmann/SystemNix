# PapDashboard authenticated /api/ingest probe — post-deploy battery leg.
#
# Extracted 2026-11-08 from post-deploy-check.sh so the status matrix has a
# fixture leg (the probe shipped 2026-10-28 verification-checked-only: the
# rendered key is root-gated and the probe mutates prod, so its first real
# fire was the next deploy's smoke — docs/status/2026-10-28_01-20_…
# §b.1). The lib is sourced by post-deploy-check.sh; the selftest
# (scripts/test-post-deploy-probe-fixtures.sh) drives the SAME functions
# against a fixture HTTP server.
#
# Contract (each non-2xx maps to its named diagnosis — the named legs are
# the point: a bare "probe failed" reads as signal noise):
#   200/201/204  PASS  auth + method + body end-to-end
#   401/403      FAIL  rendered key vs PAP_API_KEY drift (sops/gatus-env rotation)
#   405          FAIL  method-token mismatch
#   400/422      FAIL  body schema drift (gatus-config.nix body vs the huma schema)
#   anything else FAIL (000 transport fail included)

pap_ingest_resolve_key() { # -> pap_ingest_key (empty when no readable rendered env carries one)
  # PAP_INGEST_ENV_FILES is the seam the selftest points at fixture env
  # files; production keeps the two rendered-sops paths.
  local pap_env
  pap_ingest_key=""
  for pap_env in ${PAP_INGEST_ENV_FILES:-/run/secrets-rendered/papdashboard-env /run/secrets-rendered/gatus-env}; do
    if [ -r "$pap_env" ]; then
      pap_ingest_key=$(grep -E '^(PAP_API_KEY|PAPDASHBOARD_INGEST_KEY)=' "$pap_env" 2>/dev/null | head -1 | cut -d= -f2-)
      [ -n "$pap_ingest_key" ] && break
    fi
  done
}

pap_ingest_post() { # pap_ingest_post <url> <key> <event-type> -> HTTP status code (000 on transport fail)
  # curl ALWAYS prints the -w output (000) even when the transport fails, so
  # the fallback must be `|| true`, never `|| echo 000` (that would
  # double-emit "000\n000" into the caller's capture).
  curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $2" \
    -d "{\"type\":\"alert.$3\",\"aggregateId\":\"postdeploy-smoke\",\"payload\":{\"severity\":\"info\",\"title\":\"post-deploy smoke\",\"body\":\"synthetic authenticated ingest probe (post-deploy-check)\",\"sourceApp\":\"gatus\"},\"metadata\":{\"correlationId\":\"postdeploy\",\"causationId\":\"postdeploy\",\"userId\":\"\",\"sourceApp\":\"gatus\"}}" \
    "$1" 2>/dev/null || true
}

pap_ingest_verdict() { # pap_ingest_verdict <status> <pass_fn> <fail_fn>
  local code="$1" pass="$2" fail="$3"
  case "$code" in
  200 | 201 | 204) "$pass" "PapDashboard - authenticated ingest POST accepted (auth+method+body end-to-end)" ;;
  401 | 403) "$fail" "PapDashboard - authenticated ingest POST rejected ($code): rendered key does not match PAP_API_KEY (rotation drift between sops and gatus-env?)" ;;
  405) "$fail" "PapDashboard - authenticated ingest POST 405: method-token mismatch" ;;
  400 | 422) "$fail" "PapDashboard - authenticated ingest POST $code: body schema drift (gatus-config.nix body vs the live /api/ingest huma schema)" ;;
  *) "$fail" "PapDashboard - authenticated ingest POST returned $code (expected 2xx)" ;;
  esac
}
