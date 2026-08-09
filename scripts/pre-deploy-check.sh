#!/usr/bin/env bash
# Pre-deploy validation: catches boot-breaking issues BEFORE nixos-rebuild
# Run: nix run .#pre-deploy-check
set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}
fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
}
warn() {
  echo "  ⚠ $1"
  WARN=$((WARN + 1))
}

echo "=== Pre-Deploy Validation ==="
echo ""

# 1. Flake syntax check
echo "1. Flake syntax validation"
FLAKE_CHECK_OUTPUT="$(nix flake check --no-build 2>&1 || true)"

# Filter out the known "path is not valid" false positive.
# mkPreparedSource (go-nix-helpers) and similar patterns use builtins.pathExists
# at eval time; --no-build doesn't realize source derivations, so these checks
# spuriously fail. The toplevel eval (check #2) is authoritative for deployment.
REAL_ERRORS="$(echo "$FLAKE_CHECK_OUTPUT" | grep 'error:' | grep -v 'is not valid' || true)"

if [ -z "$FLAKE_CHECK_OUTPUT" ]; then
  pass "nix flake check --no-build"
elif [ -n "$REAL_ERRORS" ]; then
  fail "nix flake check --no-build — fix syntax errors before deploying"
  echo "$REAL_ERRORS" | tail -5
else
  warn "nix flake check --no-build — only 'path is not valid' errors (known --no-build limitation, toplevel eval is authoritative)"
fi

# 2. Eval the system configuration
echo ""
echo "2. Configuration evaluation"
if nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath >/dev/null 2>&1; then
  pass "nixosConfigurations.evo-x2 evaluates"
else
  fail "nixosConfigurations.evo-x2 evaluation failed"
fi

# 3. Check no Podman/Docker split-brain
echo ""
echo "3. Container runtime consistency"
BACKEND=$(nix eval --raw .#nixosConfigurations.evo-x2.config.virtualisation.oci-containers.backend 2>/dev/null || echo "podman")
DOCKER_ENABLED=$(nix eval --raw .#nixosConfigurations.evo-x2.config.virtualisation.docker.enable 2>/dev/null || echo "false")
if [ "$DOCKER_ENABLED" = "true" ] && [ "$BACKEND" = "podman" ]; then
  fail "oci-containers backend is podman but docker is enabled — split-brain"
else
  pass "Single container runtime (docker=$DOCKER_ENABLED, backend=$BACKEND)"
fi

# 4. Check mount options for nofail on non-critical mounts
echo ""
echo "4. Mount safety (non-root mounts need nofail or noauto)"
MOUNTS=$(nix eval .#nixosConfigurations.evo-x2.config.fileSystems --json 2>/dev/null | jq -r 'to_entries[] | select(.key != "/" and .key != "/boot" and .key != "/nix") | "\(.key)=\(.value.options | join(","))"' 2>/dev/null || echo "")
if [ -z "$MOUNTS" ]; then
  warn "Could not evaluate mount options"
else
  while IFS= read -r line; do
    MOUNT=$(echo "$line" | cut -d= -f1)
    OPTS=$(echo "$line" | cut -d= -f2-)
    if echo "$OPTS" | grep -qE "nofail|noauto"; then
      pass "$MOUNT has nofail/noauto"
    else
      fail "$MOUNT missing nofail/noauto — boot will emergency if mount fails"
    fi
  done <<<"$MOUNTS"
fi

# 5. Check no ExecStart inside harden()
echo ""
echo "5. Service hardening validation"
# Exclude comment lines (grep -vn ':\s*#') so documentation examples like
# "#   BAD: harden {} // {Type = ...}" in service-defaults.nix don't trip it.
HARDEN_USERS=$(grep -rn 'harden {' --include="*.nix" . 2>/dev/null | grep -vE ':[0-9]+:\s*#' | grep -E 'ExecStart|Type|RemainAfterExit' || true)
if [ -n "$HARDEN_USERS" ]; then
  fail "ExecStart/Type found inside harden() — will be silently dropped:"
  echo "$HARDEN_USERS"
else
  pass "No ExecStart/Type inside harden() calls"
fi

# 6. Check current system health (if running on target)
echo ""
echo "6. Current system health"
if command -v systemctl &>/dev/null; then
  FAILED=$(systemctl --failed --no-pager --plain 2>/dev/null | tail -n +2 | grep -c "\.service" || true)
  FAILED=${FAILED:-0}
  if [ "$FAILED" -eq 0 ]; then
    pass "No failed units"
  else
    warn "$FAILED failed unit(s) — review before deploying"
    systemctl --failed --no-pager 2>/dev/null | head -10 || true
  fi
fi

# 7. DMS desktop shell health
echo ""
echo "7. DMS desktop shell health"
if command -v dms &>/dev/null; then
  if dms doctor &>/dev/null; then
    pass "dms doctor passed"
  else
    warn "dms doctor reported issues — run 'dms doctor' for details"
  fi
else
  pass "dms binary not in PATH (may not be deployed yet)"
fi

# 8. Disk space on root filesystem
echo ""
echo "8. Disk space"
ROOT_PCT=$(df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}' || echo "0")
BUILDS_DIR="/nix/var/nix/builds"
STALE_BUILDS=0
if [ -d "$BUILDS_DIR" ]; then
  STALE_BUILDS=$(find "$BUILDS_DIR" -maxdepth 1 -type d -name 'nix-*' -mmin +60 2>/dev/null | wc -l)
fi
if [ "$ROOT_PCT" -ge 95 ]; then
  fail "Root filesystem at ${ROOT_PCT}% — deploying risks emergency shell. Free space before deploying"
elif [ "$ROOT_PCT" -ge 85 ]; then
  warn "Root filesystem at ${ROOT_PCT}% — consider freeing space before deploying"
else
  pass "Root filesystem at ${ROOT_PCT}% usage"
fi
if [ "$STALE_BUILDS" -gt 0 ]; then
  warn "$STALE_BUILDS stale build sandboxes in /nix/var/nix/builds — run 'nix-build-cleanup' or clean manually"
fi

# 9. Port availability — check that ports assigned to enabled services are free
echo ""
echo "9. Port availability for enabled services"
CONFLICTED_PORTS=0
# Check SearXNG port specifically (common conflict with OTel collector on 8888)
SEARXNG_PORT=$(nix eval --raw .#nixosConfigurations.evo-x2.config.services.searx.settings.server.port 2>/dev/null || echo "")
SEARXNG_ENABLED=$(nix eval --raw .#nixosConfigurations.evo-x2.config.services.searx.enable 2>/dev/null || echo "false")
if [ "$SEARXNG_ENABLED" = "true" ] && [ -n "$SEARXNG_PORT" ]; then
  if ss -tlnH 2>/dev/null | grep -qE "127\.0\.0\.1:$SEARXNG_PORT\b|0\.0\.0\.0:$SEARXNG_PORT\b"; then
    fail "Port $SEARXNG_PORT (SearXNG) is already in use — searx.service will crash-loop"
    ss -tlnH "sport = :$SEARXNG_PORT" 2>/dev/null
    CONFLICTED_PORTS=$((CONFLICTED_PORTS + 1))
  else
    pass "Port $SEARXNG_PORT (SearXNG) is available"
  fi
fi

# 10. Metric presence — verify Gatus pat() metric names actually appear in /metrics
echo ""
echo "10. Metric presence validation (phantom metric detection)"
GATUS_CONFIG="modules/nixos/services/gatus-config.nix"
NODE_EXPORTER_PORT=9100
MONITOR365_PORT=9191

# Extract metric-like names from gatus pat() patterns.
# Skips HTML checks (*<html*), text body checks, and comments.
extract_gatus_metrics() {
  grep -v '^[[:space:]]*#' "$GATUS_CONFIG" |
    grep -oE 'pat\(\*[a-zA-Z_][a-zA-Z0-9_]*' |
    sed 's/pat(\*//' |
    sort -u |
    grep -vE '^<|connected'
}

# Fetch metrics from both endpoints into a temp file for searching
METRICS_FILE=$(mktemp)
trap 'rm -f "$METRICS_FILE"' EXIT

if curl -sf --max-time 5 "http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics" -o "$METRICS_FILE" 2>/dev/null; then
  pass "Node exporter (port ${NODE_EXPORTER_PORT}) responding"
else
  warn "Node exporter (port ${NODE_EXPORTER_PORT}) not responding — skipping metric checks that depend on it"
fi

if curl -sf --max-time 5 "http://127.0.0.1:${MONITOR365_PORT}/metrics" >>"$METRICS_FILE" 2>/dev/null; then
  pass "Monitor365 metrics (port ${MONITOR365_PORT}) responding"
else
  warn "Monitor365 metrics (port ${MONITOR365_PORT}) not responding — skipping metric checks that depend on it"
fi

if [ -s "$METRICS_FILE" ]; then
  MISSING_METRICS=0
  # Metrics being introduced in this deploy — not yet emitted by the running
  # system. Remove entries after deploy verification confirms them in /metrics.
  KNOWN_NEW_METRICS="system_service_memory_over_threshold"
  for metric in $(extract_gatus_metrics); do
    if grep -qE "^${metric}(|[{[:space:]])|^# HELP ${metric} |^# TYPE ${metric} " "$METRICS_FILE"; then
      pass "Metric '$metric' present"
    elif echo "$KNOWN_NEW_METRICS" | grep -qw "$metric"; then
      warn "Metric '$metric' absent (known new metric in this deploy — will appear post-switch)"
    else
      fail "Metric '$metric' ABSENT — Gatus health check will be permanently RED (phantom metric)"
      MISSING_METRICS=$((MISSING_METRICS + 1))
    fi
  done
  if [ "$MISSING_METRICS" -gt 0 ]; then
    warn "$MISSING_METRICS phantom metric/metrics — check if the emitting service is running or if the metric name changed"
  fi
else
  warn "No metrics endpoints responding — cannot validate phantom metrics"
fi

# Summary
echo ""
echo "=== Summary: $PASS passed, $WARN warnings, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ DEPLOY BLOCKED — fix failures above before deploying"
  exit 1
fi

echo ""
echo "✅ Pre-deploy checks passed — safe to deploy"
exit 0
