{
  pkgs,
  lib,
  inputs,
}: let
  mkRule = {
    name,
    description,
    query,
    step ? 300,
    op ? "AND",
    target,
    interval ? "5m",
    severity ? "critical",
  }:
    pkgs.writeText "${lib.strings.sanitizeDerivationName name}-rule.json" (builtins.toJSON {
      data = {
        rule = {
          alertType = "METRIC_BASED_ALERT";
          inherit description;
          enabled = true;
          condition = {
            compositeMetricQuery = {
              promQueries = [
                {
                  name = "A";
                  inherit query step;
                  statsAggExpr = "last";
                }
              ];
            };
            inherit op target;
          };
          evaluationInterval = interval;
          inherit name;
          preferredChannels = lib.optional (severity == "critical") "Discord Alerts";
          source = "RULE";
          labels = {
            inherit severity;
          };
        };
      };
    });
in {
  rules = {
    "signoz/rules/disk-full.json".source = mkRule {
      name = "Disk Space Critical (>90%)";
      description = "Disk usage above 90% on {{.Labels.fstype}} mounted at {{.Labels.mountpoint}}";
      query = ''(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100'';
      target = 90;
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
      description = "Systemd service {{.Labels.name}} is in failed state";
      query = ''node_systemd_units{state="failed"}'';
      step = 60;
      target = 0;
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
      op = "AND_NOT";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/emeet-pixyd-down.json".source = mkRule {
      name = "EMEET PIXY Daemon Down";
      description = "emeet-pixyd metrics endpoint is unreachable";
      query = ''up{job="emeet-pixyd"}'';
      step = 60;
      op = "AND_NOT";
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
      op = "AND_NOT";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/ollama-down.json".source = mkRule {
      name = "Ollama Down";
      description = "Ollama LLM service is not responding — AI inference unavailable";
      query = ''up{job="ollama"}'';
      step = 60;
      op = "AND_NOT";
      target = 1;
      interval = "1m";
      severity = "warning";
    };
    "signoz/rules/docker-down.json".source = mkRule {
      name = "Docker Daemon Down";
      description = "Docker daemon or container runtime is not responding — all container services affected";
      query = ''up{job="cadvisor"}'';
      step = 60;
      op = "AND_NOT";
      target = 1;
      interval = "1m";
    };
    "signoz/rules/service-failed-spike.json".source = mkRule {
      name = "Service Failure Spike";
      description = "Multiple systemd services failing in rapid succession — possible systemic issue";
      query = "sum(increase(ntfy_systemd_unit_failed_total[10m]))";
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
      target = 0;
    };
    "signoz/rules/nvme-spare-low.json".source = mkRule {
      name = "NVMe SSD Spare Blocks Low (<30%)";
      description = "NVMe SSD available spare below 30% on {{.Labels.device}} — drive aging";
      query = "node_nvme_available_spare_percent";
      step = 60;
      op = "AND_NOT";
      target = 30;
      interval = "5m";
      severity = "warning";
    };
    "signoz/rules/nvme-critical-warning.json".source = mkRule {
      name = "NVMe SSD Critical Warning";
      description = "NVMe SSD critical warning flag is set on {{.Labels.device}} — check SMART immediately";
      query = "node_nvme_critical_warning";
      step = 60;
      target = 0;
      interval = "1m";
    };
  };

  dashboards = {
    "signoz/dashboards/overview.json".source = "${inputs.self}/modules/nixos/services/dashboards/signoz-overview.json";
    "signoz/dashboards/gpu.json".source = "${inputs.self}/modules/nixos/services/dashboards/gpu.json";
    "signoz/dashboards/dns.json".source = "${inputs.self}/modules/nixos/services/dashboards/dns.json";
    "signoz/dashboards/docker.json".source = "${inputs.self}/modules/nixos/services/dashboards/docker.json";
    "signoz/dashboards/caddy.json".source = "${inputs.self}/modules/nixos/services/dashboards/caddy.json";
  };
}
