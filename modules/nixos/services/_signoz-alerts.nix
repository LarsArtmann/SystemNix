{
  pkgs,
  lib,
  inputs,
}:
let
  # SigNoz v5 alerting API payload.
  # op semantics (preserved from the legacy AND/AND_NOT operators):
  #   "above_or_equal" = alert when metric is at/above target (legacy "AND")
  #   "below"          = alert when metric drops strictly below target (legacy "AND_NOT")
  # v5 requires every rule to reference at least one notification channel.
  # Guard against mathematically vacuous conditions.
  #   target=0 + above_or_equal → fires when metric >= 0 → ALWAYS true for non-negative metrics
  #   target=0 + below          → fires when metric < 0  → NEVER true for non-negative metrics
  # Both are almost certainly bugs. See AGENTS.md gotcha:
  # "SigNoz alert rule target=0 + above_or_equal = always firing".
  validateTarget =
    name: op: target:
    if target == 0 && op == "above_or_equal" then
      throw "mkRule: rule '${name}' has target=0 with op='above_or_equal' — always true for non-negative metrics. Use target=1 (at least one) or op='below' with target=1 (alert when value drops)."
    else if target == 0 && op == "below" then
      throw "mkRule: rule '${name}' has target=0 with op='below' — never true for non-negative metrics. Use target=1 with op='below' (alert when value drops below 1)."
    else
      true;

  mkRule =
    {
      name,
      description,
      query,
      step ? 300,
      op ? "above_or_equal",
      target,
      interval ? "5m",
      severity ? "critical",
    }:
    assert validateTarget name op target;
    pkgs.writeText "${lib.strings.sanitizeDerivationName name}-rule.json" (
      builtins.toJSON {
        alert = name;
        alertType = "METRIC_BASED_ALERT";
        ruleType = "promql_rule";
        version = "v5";
        inherit description;
        # Fired alerts carry annotations (not the top-level description, which
        # is UI-only). The Discord message template renders
        # .Annotations.description; $value is expanded at rule-eval time.
        # {{$value}} MUST have zero spaces inside the braces: SigNoz's
        # preprocessTemplate special-cases only the EXACT strings
        # {{$value}}/{{$threshold}}; "{{ $value }}" gets rewritten to
        # {{index .Labels "value"}} → renders empty.
        annotations = {
          description = "${description} (current: {{$value}})";
        };
        evalWindow = interval;
        frequency = interval;
        disabled = false;
        source = "RULE";
        condition = {
          compositeQuery = {
            queryType = "promql";
            panelType = "graph";
            queries = [
              {
                type = "promql";
                spec = {
                  name = "A";
                  inherit query step;
                };
              }
            ];
          };
          selectedQueryName = "A";
          inherit op target;
          matchType = "last";
        };
        labels = {
          inherit severity;
        };
        preferredChannels = [ "Discord Alerts" ];
      }
    );
in
{
  rules = {
    "signoz/rules/disk-full.json".source = mkRule {
      name = "Disk Space Critical (>90%)";
      description = "Disk usage above 90% on {{.Labels.fstype}} mounted at {{.Labels.mountpoint}}";
      query = ''(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100'';
      target = 90;
    };
    "signoz/rules/tmp-tmpfs-high.json".source = mkRule {
      name = "/tmp TmpFS Usage High (>80%)";
      description = "/tmp tmpfs usage above 80% (~38 GiB of 48 GiB cap) — runaway build or temp file accumulation risking exhaustion";
      query = "system_tmpfs_tmp_usage_percent";
      target = 80;
      severity = "warning";
    };
    "signoz/rules/cpu-sustained.json".source = mkRule {
      name = "CPU Sustained High (>90%)";
      description = "CPU usage above 90% for 15 minutes on {{.Labels.instance}}";
      query = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
      target = 90;
      severity = "warning";
    };
    "signoz/rules/memory-critical.json".source = mkRule {
      name = "Memory Critical (>90%)";
      description = "Memory usage above 90% on {{.Labels.instance}}";
      query = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
      target = 90;
    };
    "signoz/rules/swap-critical.json".source = mkRule {
      name = "Swap Usage Critical (>80%)";
      description = "Swap usage above 80% on {{.Labels.instance}} — system under severe memory pressure, OOM cascade imminent";
      query = "(1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100";
      target = 80;
    };
    "signoz/rules/service-down.json".source = mkRule {
      name = "Systemd Service Failed";
      description = "Systemd unit {{.Labels.name}} is in failed state";
      # Per-unit series so the alert names the failing unit. The aggregate
      # node_systemd_units{state="failed"} has no name label — alerts from it
      # could not say WHICH unit failed.
      query = ''node_systemd_unit_state{state="failed"} == 1'';
      step = 60;
      target = 1;
      interval = "1m";
    };
    "signoz/rules/gpu-thermal.json".source = mkRule {
      name = "GPU Thermal Throttling (>90°C)";
      description = "AMD GPU temperature above 90°C";
      # node_amdgpu_gpu_temp_celsius does not exist (0 series — node_exporter
      # exposes GPU temp only via hwmon). Two-source OR for bus-renumber
      # resilience: the hwmon chip label is PCI-address-keyed (breaks silently
      # when this box renumbers buses after hard crashes), while ClickHouse's
      # async metric name (amdgpu_edge) is stable but only exists while CH
      # runs. Together they cover each other's blind spot.
      query = ''max(node_hwmon_temp_celsius{chip=~".*c5:00_0"} or ClickHouseAsyncMetrics_Temperature_amdgpu_edge)'';
      target = 90;
    };
    "signoz/rules/dnsblockd-down.json".source = mkRule {
      name = "DNS Blocker Down";
      description = "dnsblockd service unit is not active";
      # up{job="dnsblockd"} NEVER matched: the OTel prometheus receiver stores
      # the scrape job as the resource attribute service.name (dotted labels
      # are unmatchable in PromQL), so no series ever carried a `job` label —
      # the rule was permanently phantom-green while the stats API wedged
      # 2026-08-27. The systemd collector's unit-state gauge is the real
      # signal for process death (same fix as the ollama rule).
      query = ''node_systemd_unit_state{name="dnsblockd.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/dnsblockd-stats-wedged.json".source = mkRule {
      name = "DNS Blocker Stats API Wedged";
      description = "dnsblockd /metrics scrape failing — stats API wedged or unreachable (DNS may still resolve)";
      # Process can be active while its :9090 stats API is wedged (live
      # 2026-08-27: handlers stuck mid-request, CLOSE_WAIT pileup). When the
      # scrape SUCCEEDS, dnsblockd's OTel bridge self-reports the
      # service_name label on the up series; when it fails the receiver
      # emits a bare-label up=0 series, the labeled one goes stale, and
      # count(...) drops to 0 — `or vector(0)` turns that into a fireable
      # value. WARNING severity: DNS resolution itself is covered by the
      # Gatus DNS checks and usually survives the wedge.
      # Fragility note: depends on dnsblockd's self-reported service_name
      # label; if upstream drops its OTel bridge labels, this alert would
      # fire permanently false — keep an eye on it after dnsblockd bumps.
      query = ''count(up{service_name="dnsblockd"}) or vector(0)'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/dnsblockd-crashes.json".source = mkRule {
      name = "DNS Blocker Listener Crashes";
      description = "dnsblockd DNS listener crashed and may not have recovered";
      query = "increase(dnsblockd_dns_crashes_total[5m])";
      step = 60;
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/emeet-pixyd-down.json".source = mkRule {
      name = "EMEET PIXY Daemon Down";
      description = "emeet-pixyd is not running while a graphical session is active — webcam auto-management broken";
      # Session-aware gate (mirrors the Gatus design): emeet-pixyd is a
      # graphical-session user service, legitimately absent when nobody is
      # logged in — a raw up{job=}/running check false-fires on every
      # SSH-only period. The textfile collector already computes the gated
      # boolean (niri running AND daemon missing = 1). Also fixes the
      # phantom-green: up{job="emeet-pixyd"} never matched any series.
      query = "system_emeet_pixyd_expected_down";
      step = 60;
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/gpu-vram-high.json".source = mkRule {
      name = "GPU VRAM Critical (>85%)";
      description = "GPU VRAM usage above 85% on {{.Labels.card}} — risk of OOM cascade (niri SIGABRT, desktop freeze)";
      query = "(node_amdgpu_mem_info_vram_used_bytes / node_amdgpu_mem_info_vram_total_bytes) * 100";
      target = 85;
    };
    "signoz/rules/niri-down.json".source = mkRule {
      name = "Niri Compositor Down";
      description = "Graphical session is active but niri is not running — desktop died mid-session";
      # Session-aware gate (same design as the Gatus niri checks): raw
      # `niri_running < 1` false-fires critical on every headless/SSH-only
      # period (it sat firing 2026-08-27 while the machine was healthy).
      # niri_desktop_died = 1 ONLY when a graphical session exists AND niri
      # is gone (60s grace built into the emitter).
      query = "niri_desktop_died";
      step = 60;
      target = 1;
      interval = "1m";
    };
    "signoz/rules/ollama-down.json".source = mkRule {
      name = "Ollama Down";
      description = "Ollama LLM service unit is not active — AI inference unavailable";
      # ollama exposes no /metrics endpoint (404) — up{job="ollama"} was a
      # phantom series that could never fire. The systemd collector's unit
      # state gauge is the real signal.
      query = ''node_systemd_unit_state{name="ollama.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/llama-embeddings-down.json".source = mkRule {
      name = "llama.cpp Embeddings Down";
      description = "llama.cpp embeddings server is not active — RAG indexing and semantic search unavailable";
      query = ''node_systemd_unit_state{name="llama-embeddings.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/llama-reranker-down.json".source = mkRule {
      name = "llama.cpp Reranker Down";
      description = "llama.cpp reranker is not active — RAG reranking unavailable, search quality degraded";
      query = ''node_systemd_unit_state{name="llama-reranker.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/cv-server-down.json".source = mkRule {
      name = "CV Server Down";
      description = "cv-server unit is not active — resume site and PDF export at cv.home.lan unreachable";
      # Unit-state gauge (same pattern as ollama/dnsblockd): no series carries
      # a `job` label in the OTel metrics store, so up{job="cv-server"} could
      # never fire. Gatus owns HTTP liveness for cv.home.lan — this adds the
      # unit-level death signal (crash-loops, boot-time failures) to the
      # SigNoz alert surface.
      query = ''node_systemd_unit_state{name="cv-server.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/docker-down.json".source = mkRule {
      name = "Docker Daemon Down";
      description = "Docker engine daemon unit is not active";
      # up{job="docker-engine"} was phantom-green (no series carries a `job`
      # label — see dnsblockd-down). Unit-state gauge is the real signal;
      # engine metrics presence is separately visible via the collector's
      # scrape coverage.
      query = ''node_systemd_unit_state{name="docker.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/service-failed-spike.json".source = mkRule {
      name = "Service Failure Spike";
      description = "Multiple systemd units in failed state simultaneously — possible systemic issue";
      # ntfy_systemd_unit_failed_total was never emitted by anything (phantom
      # metric — the rule could never fire). Sum the real per-unit failed state.
      query = ''sum(node_systemd_unit_state{state="failed"})'';
      step = 60;
      target = 3;
    };
    "signoz/rules/nvme-thermal.json".source = mkRule {
      name = "NVMe SSD Thermal Warning (>70°C)";
      description = "NVMe SSD temperature above 70°C on {{.Labels.device}} — approaching throttle limit";
      query = "node_nvme_temperature_celsius";
      target = 70;
      severity = "warning";
    };
    "signoz/rules/nvme-endurance.json".source = mkRule {
      name = "NVMe SSD Endurance Critical (>50%)";
      description = "NVMe SSD has consumed over 50% of rated endurance on {{.Labels.device}} — plan for replacement";
      query = "node_nvme_percentage_used";
      target = 50;
      severity = "warning";
    };
    "signoz/rules/nvme-media-errors.json".source = mkRule {
      name = "NVMe SSD Media Errors Detected";
      description = "NVMe SSD has media/data integrity errors on {{.Labels.device}} — possible flash cell degradation";
      query = "node_nvme_media_errors_total";
      target = 1;
    };
    "signoz/rules/nvme-spare-low.json".source = mkRule {
      name = "NVMe SSD Spare Blocks Low (<30%)";
      description = "NVMe SSD available spare below 30% on {{.Labels.device}} — drive aging";
      query = "node_nvme_available_spare_percent";
      step = 60;
      op = "below";
      target = 30;
      interval = "5m";
      severity = "warning";
    };
    "signoz/rules/nvme-critical-warning.json".source = mkRule {
      name = "NVMe SSD Critical Warning";
      description = "NVMe SSD critical warning flag is set on {{.Labels.device}} — check SMART immediately";
      query = "node_nvme_critical_warning";
      step = 60;
      target = 1;
      interval = "1m";
    };
    "signoz/rules/collector-down.json".source = mkRule {
      name = "Telemetry Collector Down";
      description = "SigNoz OTel collector unit is not active — ALL telemetry ingestion (logs/traces/metrics) is at risk";
      # up{job="signoz-collector"} was phantom-green (no `job` label exists
      # in the OTel metrics store — see dnsblockd-down).
      query = ''node_systemd_unit_state{name="signoz-collector.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/telemetry-export-failures.json".source = mkRule {
      name = "Telemetry Export Failures";
      description = "OTel collector failed to export log records/spans to ClickHouse in the last 10m — data loss in progress (schema drift, CH down, or disk full)";
      # Regex selector keeps the query valid when a signal has zero failures
      # (absent series → no match → no false fire).
      query = ''sum(increase({__name__=~"otelcol_exporter_send_failed_(log_records|spans|metric_points)"}[10m]))'';
      step = 60;
      target = 1;
      interval = "1m";
      severity = "critical";
    };
    "signoz/rules/clickhouse-down.json".source = mkRule {
      name = "ClickHouse Down";
      description = "ClickHouse service unit is not active — the telemetry store itself is down";
      # up{job="clickhouse"} was phantom-green (no `job` label exists — see
      # dnsblockd-down).
      query = ''node_systemd_unit_state{name="clickhouse.service",state="active"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
    };
    # Telemetry coverage audit (signoz-coverage.nix): SigNoz watching itself.
    # Gatus carries the fast path (5m); this rule survives a gatus outage.
    "signoz/rules/traces-coverage-missing.json".source = mkRule {
      name = "SigNoz Trace Coverage Missing";
      description = "A service registered in signoz-coverage stopped sending spans within its freshness budget — silent observability hole. Check signoz_traces_reporting by service in node-exporter /metrics";
      query = ''signoz_traces_missing'';
      step = 300;
      target = 1;
      interval = "5m";
    };
    "signoz/rules/coverage-collector-errors.json".source = mkRule {
      name = "SigNoz Coverage Collector Errors";
      description = "The signoz-coverage textfile collector failed its ClickHouse queries — coverage data is untrustworthy until it recovers";
      query = ''signoz_coverage_scrape_errors'';
      step = 300;
      target = 1;
      interval = "5m";
      severity = "warning";
    };
    "signoz/rules/logs-pipeline-stale.json".source = mkRule {
      name = "SigNoz Logs Pipeline Stale";
      description = "No log records ingested for >30 min — the journald logs pipeline is dark for ALL services";
      query = ''signoz_logs_pipeline_stale'';
      step = 300;
      target = 1;
      interval = "5m";
    };
  };

  dashboards = {
    "signoz/dashboards/overview.json".source =
      "${inputs.self}/modules/nixos/services/dashboards/overview.json";
    "signoz/dashboards/gpu.json".source = "${inputs.self}/modules/nixos/services/dashboards/gpu.json";
    "signoz/dashboards/dns.json".source = "${inputs.self}/modules/nixos/services/dashboards/dns.json";
    "signoz/dashboards/docker.json".source =
      "${inputs.self}/modules/nixos/services/dashboards/docker.json";
    "signoz/dashboards/caddy.json".source =
      "${inputs.self}/modules/nixos/services/dashboards/caddy.json";
  };
}
