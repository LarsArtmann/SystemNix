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
        annotations = {
          description = "${description} (current: {{ $value }})";
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
      description = "AMD GPU temperature above 90°C on {{.Labels.card}}";
      query = "node_amdgpu_gpu_temp_celsius";
      target = 90;
    };
    "signoz/rules/dnsblockd-down.json".source = mkRule {
      name = "DNS Blocker Down";
      description = "dnsblockd metrics endpoint is unreachable";
      query = ''up{job="dnsblockd"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
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
      description = "emeet-pixyd metrics endpoint is unreachable";
      query = ''up{job="emeet-pixyd"}'';
      step = 60;
      op = "below";
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
      description = "Niri Wayland compositor is not running — desktop may be unresponsive";
      query = "niri_running";
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/ollama-down.json".source = mkRule {
      name = "Ollama Down";
      description = "Ollama LLM service is not responding — AI inference unavailable";
      query = ''up{job="ollama"}'';
      step = 60;
      op = "below";
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/docker-down.json".source = mkRule {
      name = "Docker Daemon Down";
      description = "Docker daemon or container runtime is not responding — all container services affected";
      query = ''up{job="cadvisor"}'';
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
  };

  dashboards = {
    "signoz/dashboards/overview.json".source =
      "${inputs.self}/modules/nixos/services/dashboards/signoz-overview.json";
    "signoz/dashboards/gpu.json".source = "${inputs.self}/modules/nixos/services/dashboards/gpu.json";
    "signoz/dashboards/dns.json".source = "${inputs.self}/modules/nixos/services/dashboards/dns.json";
    "signoz/dashboards/docker.json".source =
      "${inputs.self}/modules/nixos/services/dashboards/docker.json";
    "signoz/dashboards/caddy.json".source =
      "${inputs.self}/modules/nixos/services/dashboards/caddy.json";
  };
}
