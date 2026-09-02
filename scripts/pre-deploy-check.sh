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

# Filter out known-benign error classes:
# - "path is not valid": mkPreparedSource (go-nix-helpers) and similar
#   patterns use builtins.pathExists at eval time; --no-build doesn't
#   realize source derivations, so these checks spuriously fail. The
#   toplevel eval (check #2) is authoritative for deployment.
# - "unable to download 'https://.../<hash>.narinfo'": substituter
#   unreachability (attic DNS-dead during the 2026-09-02 resolv.conf drift;
#   attic 502s during DAS outages). Nix prints these as `error:` even when it
#   falls back to building locally: infrastructure noise, not flake
#   syntax/eval problems.
#   They must never block a deploy: the deploy that RESTORES DNS is exactly
#   the one this class would block (chicken-and-egg, live 2026-09-02).
REAL_ERRORS="$(echo "$FLAKE_CHECK_OUTPUT" | grep 'error:' | grep -vE "is not valid|unable to download 'https?://[^']+\.narinfo" || true)"

if [ -z "$FLAKE_CHECK_OUTPUT" ]; then
  pass "nix flake check --no-build"
elif [ -n "$REAL_ERRORS" ]; then
  fail "nix flake check --no-build — fix syntax errors before deploying"
  echo "$REAL_ERRORS" | tail -5
else
  warn "nix flake check --no-build — only known-benign error classes ('path is not valid' --no-build limitation, substituter narinfo unreachability); toplevel eval is authoritative"
fi

# 1b. Tracked-files trap — flakes only see TRACKED files: a NEW module under
# modules/ that is not `git add`ed yet makes EVERY evo-x2 eval fail with
# "attribute missing" while the file sits visibly on disk (aborted a deploy
# 2026-08-27). Concurrent-session trees are especially prone: another agent
# writes the module and imports it before staging it.
echo ""
echo "1b. Untracked files under modules/ (tracked-files trap)"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  UNTRACKED_MODULES=$(git status --porcelain modules/ platforms/ 2>/dev/null | grep -E '^\?\?' || true)
  if [ -n "$UNTRACKED_MODULES" ]; then
    warn "untracked files invisible to flake evals — git add them or they break the NEXT eval that imports them:"
    while IFS= read -r line; do echo "      $line"; done <<<"$UNTRACKED_MODULES"
  else
    pass "no untracked files under modules/ or platforms/"
  fi
else
  pass "not a git worktree (deploying from a copy) — check skipped"
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

# 4b. ClickHouse XFS data mount prerequisite: if the to-be-deployed config
# declares fileSystems."/var/lib/clickhouse", the labeled fs must already
# exist (created by scripts/migrate-clickhouse-xfs.sh prepare BEFORE the
# deploy). A missing device means the deploy would leave the stack down by
# design (nofail mount fails + ConditionPathIsMountPoint blocks clickhouse).
echo ""
echo "4b. ClickHouse XFS data mount prerequisite"
HAS_CH_MOUNT=$(nix eval .#nixosConfigurations.evo-x2.config.fileSystems --json 2>/dev/null | jq -r 'has("/var/lib/clickhouse")' 2>/dev/null || echo "false")
if [ "$HAS_CH_MOUNT" = "true" ]; then
  if [ -e /dev/disk/by-label/clickhouse ]; then
    pass "labeled XFS device /dev/disk/by-label/clickhouse present"
    if findmnt -no FSTYPE /var/lib/clickhouse 2>/dev/null | grep -qx xfs; then
      pass "/var/lib/clickhouse already mounted as xfs (migration complete)"
    fi
  elif findmnt -no FSTYPE /var/lib/clickhouse 2>/dev/null | grep -qx xfs; then
    pass "/var/lib/clickhouse already mounted as xfs (migration complete)"
  else
    fail "/dev/disk/by-label/clickhouse absent — run 'sudo bash scripts/migrate-clickhouse-xfs.sh prepare' BEFORE deploying, or the SigNoz stack stays down post-switch (by design: no root-fs contamination)"
  fi
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
# Byte-based, not percentage: a % threshold scales absurdly on large disks —
# 95% of the 723G root still leaves ~36G free, which cannot cause the
# emergency-shell outcome this check guards against (activation needs ~1-2G).
# FAIL < 5G (activation headroom + margin), WARN < 15G. Percentage shown for
# context only. Learned 2026-08-17: snapshot-pinned data (btrbk @ retention)
# cannot be freed by deletion anyway — only expiry reclaims it.
ROOT_AVAIL_KB=$(df -Pk / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
ROOT_PCT=$(df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}' || echo "0")
ROOT_AVAIL_GB=$((ROOT_AVAIL_KB / 1024 / 1024))
BUILDS_DIR="/nix/var/nix/builds"
STALE_BUILDS=0
if [ -d "$BUILDS_DIR" ]; then
  STALE_BUILDS=$(find "$BUILDS_DIR" -maxdepth 1 -type d -name 'nix-*' -mmin +60 2>/dev/null | wc -l)
fi
if [ "$ROOT_AVAIL_GB" -lt 5 ]; then
  fail "Root filesystem has only ${ROOT_AVAIL_GB}G free (${ROOT_PCT}%) — deploying risks emergency shell. Free space before deploying"
elif [ "$ROOT_AVAIL_GB" -lt 15 ]; then
  warn "Root filesystem has only ${ROOT_AVAIL_GB}G free (${ROOT_PCT}%) — consider freeing space before deploying"
else
  pass "Root filesystem usage ${ROOT_PCT}% (${ROOT_AVAIL_GB}G free)"
fi
if [ "$STALE_BUILDS" -gt 0 ]; then
  warn "$STALE_BUILDS stale build sandboxes in /nix/var/nix/builds — run 'sudo systemctl start nix-build-cleanup.service' (the same unit the 4h timer fires; removes only sandboxes untouched >1h — do NOT rm -rf blindly, live builds sit there)"
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

# Static config traps (mirrors the flake.nix gatus-pattern-lint — defense in
# depth at deploy time: the working tree can carry a regression CI hasn't
# rejected yet, e.g. mid-race with the auto-commit daemon).
PHANTOM_PATTERNS=$(grep -v '^[[:space:]]*#' "$GATUS_CONFIG" | grep -nE 'pat\(\*[a-z_0-9]+ 1\*\)' || true)
if [ -n "$PHANTOM_PATTERNS" ]; then
  fail "bare pat(*<metric> 1*) matches the metric's own HELP comment (phantom green): ${PHANTOM_PATTERNS} — use the anchored form [BODY] != pat(*m 0\\n*) + [BODY] == pat(*\\nm *)"
else
  pass "no bare pat(*<metric> 1*) phantom-green conditions in gatus config"
fi
ESCAPED_PATTERNS=$(grep -v '^[[:space:]]*#' "$GATUS_CONFIG" | grep -nE 'pat\(.*\\\\n' || true)
if [ -n "$ESCAPED_PATTERNS" ]; then
  fail "pat() with literal backslash-n (nix source '\\\\n') can NEVER match — filepath.Match escapes it to the letter 'n'; write the real newline as single-backslash \\n"
else
  pass "no literal backslash-n escapes inside pat() in gatus config"
fi

# Extract metric-like names from gatus pat() patterns.
# Skips HTML checks (*<html*), text body checks, and comments. Body-text
# patterns like pat(*Paperless-ngx sign in*) extract a leading word that is
# NOT a metric — Prometheus metric names are lowercase by convention, so
# dropping any candidate containing uppercase keeps human-text checks out.
# `connected` (InboxClean /health JSON) and `email_state(s)` (InboxClean
# /health/projections JSON, 2026-08-30 — the LIVE projection is named
# "email_state", singular; the upstream test fixture says "email_states" and
# is NOT prod truth) are lowercase JSON FIELD assertions on non-/metrics
# endpoints — the extractor cannot tell them apart from metrics, and they
# never appear in any /metrics scrape. `oidc` (2026-09-02, paperless Layer 1
# SSO) is the same class: pat(*oidc/pocket-id*) asserts the allauth login
# BUTTON on the paperless HTML login page — a body-content pattern, not a
# metric; the slash-suffix is dropped by the [a-zA-Z0-9_]* extract.
extract_gatus_metrics() {
  # Also catch the anchored form pat(*\n<metric> — the leading real-newline
  # escape precedes the name there (2026-08-31: signoz-coverage checks were
  # invisible to phantom validation without this).
  # The name must be terminated by a NON-name character and that character
  # must not be '=' (2026-09-02: pat(*type="password"* — an HTML-attribute
  # body-content pattern from the paperless SSO check) extracted 'type' as a
  # metric and phantom-failed §10; name=value attribute tokens are never
  # metrics).
  grep -v '^[[:space:]]*#' "$GATUS_CONFIG" |
    grep -oE 'pat\(\*(\\n)?[a-zA-Z_][a-zA-Z0-9_]*[^a-zA-Z0-9_]' |
    grep -v '=$' |
    sed 's/pat(\*//;s/^\\n//;s/.$//' |
    sort -u |
    grep -vE '^<|connected|email_states?|oidc$|[A-Z]'
}

# Fetch metrics from each endpoint separately to avoid false-positive phantom
# failures when one endpoint is down but metrics from it are checked anyway.
METRICS_FILE=$(mktemp)
trap 'rm -f "$METRICS_FILE"' EXIT

MONITOR365_UP=false

if curl -sf --compressed --max-time 5 "http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics" -o "$METRICS_FILE" 2>/dev/null; then
  pass "Node exporter (port ${NODE_EXPORTER_PORT}) responding"
else
  warn "Node exporter (port ${NODE_EXPORTER_PORT}) not responding — node-exporter metrics will be skipped"
fi

if curl -sf --compressed --max-time 5 "http://127.0.0.1:${MONITOR365_PORT}/metrics" >>"$METRICS_FILE" 2>/dev/null; then
  pass "Monitor365 metrics (port ${MONITOR365_PORT}) responding"
  MONITOR365_UP=true
else
  warn "Monitor365 metrics (port ${MONITOR365_PORT}) not responding — monitor365 metrics will be skipped"
fi

# Per-service /metrics endpoints that gatus pats() probe DIRECTLY (bank-sync
# :8097, discordsync-api :8085, …). Without fetching these, every gatus body
# check against a service's own /metrics registers as a phantom metric and
# blocks deploys even though the live service verifiably emits it (observed
# 2026-08-21: the bank-sync/discordsync gatus probes blocked all deploys).
# URLs in gatus-config.nix are Nix-interpolated (${toString ports.<name>}),
# so resolve each name against lib/ports.nix. Non-fatal per endpoint: a down
# service already fails its own health checks elsewhere.
GATUS_SERVICE_METRIC_PORTS=$(grep -oE 'localhost:\$\{toString ports\.[a-zA-Z0-9_-]+\}/metrics' "$GATUS_CONFIG" 2>/dev/null | sed -E 's/.*ports\.([a-zA-Z0-9_-]+)\}.*/\1/' | sort -u)
DISCORDSYNC_API_UP=false
for port_name in $GATUS_SERVICE_METRIC_PORTS; do
  port_num=$(sed -nE "s/^[[:space:]]*${port_name} = ([0-9]+);.*/\1/p" lib/ports.nix | head -1)
  if [ -n "$port_num" ] && curl -sf --compressed --max-time 5 "http://127.0.0.1:${port_num}/metrics" >>"$METRICS_FILE" 2>/dev/null; then
    pass "Service metrics '${port_name}' (port ${port_num}) responding"
    if [ "${port_name}" = "discordsync-api" ]; then
      DISCORDSYNC_API_UP=true
    fi
  else
    warn "Service metrics '${port_name}' (port ${port_num:-unresolved}) not responding — its gatus pats will flag absent"
  fi
done

# Metrics known to come from Monitor365's endpoint (not node exporter textfile).
# When Monitor365 is down, these are absent for infrastructure reasons, not
# because they're phantom metrics in the config.
MONITOR365_METRICS="collector_events_collected cloud_sync_consecutive_failures cloud_sync_upload_backlog_size"

# Textfile-collector breakage on the RUNNING system (2026-09-02, live twice):
# a collector emitting a value-less line ("metric " + empty var) makes
# node_exporter reject the ENTIRE textfile — every system_* metric goes dark
# at once and this gate hard-blocked the very deploy carrying the collector
# fix (chicken-and-egg). node_textfile_scrape_error=1 is the POSITIVE
# infra-down signal: absent textfile metrics are then an infrastructure
# signal, not config phantoms — WARN, never block (same doctrine as the
# monitor365/discordsync down-endpoint exceptions).
TEXTFILE_SCRAPE_ERROR=false
if [ -s "$METRICS_FILE" ] && grep -qE '^node_textfile_scrape_error 1' "$METRICS_FILE"; then
  TEXTFILE_SCRAPE_ERROR=true
  warn "node_textfile_scrape_error=1 — the RUNNING system's textfile collector is broken (a .prom file is being rejected whole). Absent textfile metrics below are downgraded to warnings; deploying the collector fix is the remedy. Inspect: ls /var/lib/prometheus-node-exporter/textfile_collectors/ + journalctl -u '*-metrics' -n 30"
  # Surface the offending lines directly — a metric line with a name but no
  # value is the exact syntax node_exporter rejects.
  for pf in /var/lib/prometheus-node-exporter/textfile_collectors/*.prom; do
    if [ -r "$pf" ] && bad_lines=$(grep -nE '^[a-zA-Z_:][a-zA-Z0-9_:]*(\{[^}]*\})?[[:space:]]*$' "$pf" 2>/dev/null); then
      warn "value-less metric lines in $pf (rejects the whole file): $(echo "$bad_lines" | head -3 | tr '\n' ';')"
    fi
  done
fi

# Same doctrine for discordsync's OWN :8085 endpoint metrics (2026-08-31
# 00:10 live block: the user deliberately STOPPED discordsync to relieve IO
# pressure — its endpoint vanished and the phantom-metric gate hard-failed
# EVERY subsequent deploy, including deploys unrelated to discordsync. A
# stopped/failed service's endpoint metrics are an infrastructure signal,
# not a config bug: WARN, never block. The gatus checks for discordsync go
# red on their own while it is down — that is the correct visibility.)
DISCORDSYNC_METRICS="discordsync_projection_dlq_legacy_depth discordsync_projection_dlq_legacy_unchanged discordsync_turso_local_only_mode"

# Forgejo mirror journal-scan metrics: the collector emits the errors_30m/
# erroring pair ONLY when its bounded journalctl scan succeeds — on scan
# failure (timeout under IO pressure) it reports
# system_forgejo_mirror_scrape_errors=1 and the pair is ABSENT BY DESIGN
# (fail-closed, 2026-09-02 fix). Keyed on the POSITIVE signal, not a name
# list: when the running system itself reports the scan failed, absence is
# an infrastructure signal, not a config phantom.
FORGEJO_SCAN_FAILED=false
if [ -s "$METRICS_FILE" ] && grep -qE '^system_forgejo_mirror_scrape_errors 1' "$METRICS_FILE"; then
  FORGEJO_SCAN_FAILED=true
fi

if [ -s "$METRICS_FILE" ]; then
  MISSING_METRICS=0
  # Metrics not yet emitted by the RUNNING system (pre-deploy). These metrics
  # exist in the to-be-deployed config but not in the currently running system.
  # Remove entries after deploy verification confirms them in /metrics.
  #
  # 2026-08-24 sweep (docs/status 2026-08-2* harvest): verified live against
  # the textfile collectors in /var/lib/prometheus-node-exporter/textfile_collectors
  # and REMOVED — 21 entries retired: system_zram_* (5), system_lan_nic_present,
  # system_das_link_present, system_current_system_profiled,
  # system_forgejo_mirror_* (3), node_psi_memory_warning/_some_avg60,
  # system_crush_sessions(_over_threshold), system_cgroup_mem_{,anon_,shmem_,
  # unevictable_}bytes (4), sev1_bridge_{alerts_active,runs_total}.
  # clickhouse_xfs_* were retired earlier (2026-08-22 XFS session).
  # discordsync_projection_dlq_legacy_depth (2026-08-21): RETIRED from this
  # list 2026-08-25 — the input bump to 2862b613 landed the metric live
  # (11,404 frozen rows, truthful). The gatus check now asserts the companion
  # discordsync_projection_dlq_legacy_unchanged flag (growth detector) — that
  # one is NEW in the same deploy, listed below; remove after this deploy
  # confirms it in :8085/metrics (expected 1 = stable backlog).
  # discordsync_projection_dlq_legacy_unchanged (2026-08-25): emitted by the
  # discordsync rev 2862b613 gauge added for the "Legacy DLQ Stable" check.
  # bank_sync_* (2026-08-22): the gatus "Bank-Sync Sync Health" probe
  # (2026-08-21 session) references the sync_errors/last_sync metrics from
  # bank-sync's own :8097/metrics exporter. UNVERIFIABLE while the DAS is
  # detached (bank-sync dataDir lives on /mnt/pool → service dependency-down):
  # the locked flake input (5d7866f) verifiably emits both
  # (internal/server/metrics.go:257,299 — verified against the locked rev
  # 2026-08-22). Remove after the first post-DAS-recovery deploy confirms
  # them (post-deploy-check.sh Bank-Sync section asserts :8097/metrics).
  # system_dnsblockd_metrics_fresh (2026-08-28): new wedge tripwire from the
  # monitoring-hardening round — the running generation's collector doesn't
  # emit it yet, so pre-deploy sees absence. Remove after the first deploy
  # confirms it in the textfile collector output.
  # system_oomd_kills_scrape_errors (2026-08-31): REMOVED same day — the
  # deploy that introduced it confirmed the metric live in the textfile
  # (scrape_errors 0, collector runs 1.3s flat after the bounding fix).
  # 2026-08-31 sweep (follow-up session): retired 10 entries after probing
  # the live endpoints — signoz_traces_{missing,reporting},
  # signoz_coverage_scrape_errors, signoz_logs_pipeline_stale,
  # system_user_units_{failed,scrape_errors}, system_dnsblockd_metrics_fresh
  # (all :9100 textfile) + discordsync_projection_dlq_legacy_unchanged,
  # discordsync_turso_local_only_mode (:8085) + bank_sync_sync_errors_total,
  # bank_sync_last_sync_timestamp_seconds (:8097, DAS back). Every entry in
  # this list must die the moment its metric is confirmed live — the list is
  # a one-deploy loan, not a museum.
  # signoz_traces_upstream_gaps_over_threshold (2026-08-31): gap-budget
  # ratchet metric from the same session — appears with the deploy that adds
  # the "SigNoz Trace Gap Budget" gatus check. Remove after confirmation.
  # pool_usb_recovery_members_present / _device_errors (2026-08-31): added by
  # the pool-recovery session (545a102b, healthy-members gatus check); the
  # pool-recovery-metrics collector carrying them is a NEW unit in this same
  # deploy — the running system cannot serve them pre-switch. Remove after
  # this deploy confirms them in the textfile.
  # 2026-09-02 sweep: RETIRED the three entries above (signoz gap budget +
  # both pool_usb_recovery gauges) — the 2026-09-02 pre-deploy run confirmed
  # all three present in :9100/metrics.
  # system_local_dns_resolves (2026-09-02): RETIRED same day — confirmed
  # live in the system_health textfile (value 1) by the follow-up session.
  # system_pma_commit_* (2026-09-02): three gauges from the PMA commit
  # blackout fix (scrape_errors + failures_over_threshold +
  # fallbacks_over_threshold, "PMA Commit Health" gatus check). Emitted by
  # the system-health textfile collector shipping in this same deploy; the
  # running generation's collector predates them. Remove after the first
  # deploy confirms them in :9100/metrics (expected 0/0/0 once the
  # backlog drains; failures may legitimately read 1 during the
  # transition hour — 785 backlog failures sat in the 1h window at
  # deploy time).
  # niri_aw_* (2026-09-02, aw-watcher attach monitoring) and
  # system_pocket_id_busy_* (2026-09-02, pocket-id SQLITE_BUSY watch —
  # collector + checks landed together undeployed in e5ad4901): the metrics
  # ride THIS deploy's collectors — absent from the running scrape only
  # until the switch lands.
  KNOWN_NEW_METRICS="system_pma_commit_scrape_errors system_pma_commit_failures_over_threshold system_pma_commit_fallbacks_over_threshold niri_aw_watcher_attached niri_aw_watcher_late system_pocket_id_busy_over_threshold system_pocket_id_busy_scrape_errors"
  for metric in $(extract_gatus_metrics); do
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
    elif [ "$TEXTFILE_SCRAPE_ERROR" = true ]; then
      warn "Metric '$metric' absent — node exporter textfile collector broken on the RUNNING system (see node_textfile_scrape_error above): infrastructure signal, deploy the collector fix"
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

# 11. vendorHash freshness for local Go packages
echo ""
echo "11. vendorHash freshness for local Go packages"
# vendorHash mismatches are FOD failures that --no-build cannot catch (AGENTS.md).
# --dry-run reveals whether the FOD is cached or would need building (stale hash).
GO_PKGS=("dnsblockd" "monitor365" "netwatch" "emeet-pixyd" "file-and-image-renamer" "crush-daily")
for pkg in "${GO_PKGS[@]}"; do
  # shellcheck disable=SC2086
  output=$(nix build .#$pkg.goModules --dry-run 2>&1 || true)
  if echo "$output" | grep -q "would build"; then
    warn "$pkg.goModules not cached — vendorHash may be stale or needs building"
  elif echo "$output" | grep -qE "would (copy|fetch)"; then
    pass "$pkg.goModules cached (vendorHash valid)"
  else
    warn "$pkg.goModules — unable to determine status (may not be a buildGoModule)"
  fi
done

# 12. ExecStart executables exist — 203/EXEC prevention
# A unit whose ExecStart path doesn't exist fails instantly with status=203/EXEC,
# restarts to start-limit-hit, and blocks activation with exit 4 (seen live with
# fastflowlm 2026-08-17: package had flat layout, unit referenced bin/flm).
# Eval can't check store-path existence — this catches it pre-deploy.
echo ""
echo "12. ExecStart executable existence (203/EXEC prevention)"
EXECSTARTS=$(nix eval --json .#nixosConfigurations.evo-x2.config.systemd.services --apply '
  builtins.mapAttrs (name: svc:
    let
      es = svc.serviceConfig.ExecStart or null;
      lines = if es == null then [] else if builtins.isList es then es else [ es ];
    in map (line: { unit = name; line = builtins.toString line; }) lines
  )' 2>/dev/null | jq -r '.[] | .[] | "\(.unit)\t\(.line)"' 2>/dev/null || echo "")
if [ -z "$EXECSTARTS" ]; then
  warn "Could not evaluate ExecStart lines — skipping 203/EXEC check"
else
  EXECSTART_MISSING=0
  while IFS=$'\t' read -r unit line; do
    # Strip systemd prefix modifiers (-, :, +, !) and take the first token.
    bin=$(echo "$line" | sed 's/^[-:+!]*//' | awk '{print $1}')
    # Skip lines with runtime expansion (%H, $VAR, ${...}) or non-absolute paths.
    case "$bin" in
    /*) ;;
    *) continue ;;
    esac
    case "$bin" in
    *%* | *'$'*) continue ;;
    esac
    if [ ! -x "$bin" ]; then
      case "$bin" in
      /nix/store/*)
        outRoot=$(echo "$bin" | cut -d/ -f1-4)
        if [ -d "$outRoot" ]; then
          fail "$unit: ExecStart binary missing inside BUILT output: $bin (203/EXEC — package layout bug, path can never exist)"
          EXECSTART_MISSING=$((EXECSTART_MISSING + 1))
        else
          warn "$unit: ExecStart binary not built yet: $bin (verify layout after build)"
        fi
        ;;
      *)
        fail "$unit: ExecStart binary missing: $bin (would fail 203/EXEC)"
        EXECSTART_MISSING=$((EXECSTART_MISSING + 1))
        ;;
      esac
    fi
  done <<<"$EXECSTARTS"
  TOTAL_LINES=$(echo "$EXECSTARTS" | wc -l)
  if [ "$EXECSTART_MISSING" -eq 0 ]; then
    pass "All $TOTAL_LINES ExecStart binaries exist"
  fi
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
