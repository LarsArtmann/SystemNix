# Shared metric-absence classifier for the pre-deploy §10 gate.
# Sourced (NEVER executed) by scripts/pre-deploy-check.sh and
# scripts/test-pre-deploy-metrics.sh — the classification cascade is
# the part of the gate whose WARN-vs-FAIL decision decides whether a
# deploy is blocked, so it is fixture-tested (the 2026-09-02 lesson:
# gate logic with no tests twice blocked the deploy carrying its own
# fix).
#
# The sourcer MUST define before calling:
#   pass/warn/fail   — reporting helpers (may be stubs in tests)
#   METRICS_FILE     — the merged live /metrics body to grep
#   KNOWN_NEW_METRICS — space-separated metrics shipping in THIS deploy
#   MONITOR365_METRICS / MONITOR365_UP
#   DISCORDSYNC_METRICS / DISCORDSYNC_API_UP
#   FORGEJO_SCAN_FAILED / POCKET_ID_SCAN_FAILED / TEXTFILE_SCRAPE_ERROR
metrics_gate_classify_absence() {
  local metric="$1"
  if grep -qE "^${metric}(|[{[:space:]])|^# HELP ${metric} |^# TYPE ${metric} " "$METRICS_FILE"; then
    pass "Metric '$metric' present"
  elif echo "$KNOWN_NEW_METRICS" | grep -qw "$metric"; then
    warn "Metric '$metric' absent (known new metric in this deploy — will appear post-switch)"
  elif echo "$MONITOR365_METRICS" | grep -qw "$metric" && [ "$MONITOR365_UP" = false ]; then
    warn "Metric '$metric' absent (Monitor365 endpoint down — not a phantom metric)"
  elif echo "$DISCORDSYNC_METRICS" | grep -qw "$metric" && [ "$DISCORDSYNC_API_UP" = false ]; then
    warn "Metric '$metric' absent (discordsync endpoint down/stopped — not a phantom metric)"
  elif [ "$FORGEJO_SCAN_FAILED" = true ]; then
    warn "Metric '$metric' absent — running system reports forgejo mirror journal scan FAILED (system_forgejo_mirror_scrape_errors=1): fail-closed absence, infrastructure signal"
  elif [ "$POCKET_ID_SCAN_FAILED" = true ]; then
    warn "Metric '$metric' absent — running system reports pocket-id SQLITE_BUSY journal scan FAILED (system_pocket_id_busy_scrape_errors=1): fail-closed absence, infrastructure signal"
  elif [ "$TEXTFILE_SCRAPE_ERROR" = true ]; then
    warn "Metric '$metric' absent — node exporter textfile collector broken on the RUNNING system (see node_textfile_scrape_error above): infrastructure signal, deploy the collector fix"
  else
    fail "Metric '$metric' ABSENT — Gatus health check will be permanently RED (phantom metric)"
    return 1
  fi
}
