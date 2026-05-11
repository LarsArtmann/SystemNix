_: {
  flake.nixosModules.gatus-config = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.gatus-config;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;
  in {
    options.services.gatus-config = {
      enable = lib.mkEnableOption "Gatus health check monitoring with pre-configured endpoints";

      port = serviceTypes.servicePort 8083 "HTTP port for Gatus web interface";
    };

    config = lib.mkIf cfg.enable {
      services.gatus = {
        enable = true;
        settings = {
          web.port = cfg.port;
          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/gatus.db";
            caching = true;
          };
          alerting.discord = {
            webhook-url = "__DISCORD_WEBHOOK_URL__";
            default-alert = {
              failure-threshold = 3;
              success-threshold = 2;
              send-on-resolved = true;
            };
          };
          endpoints = [
            {
              name = "Caddy";
              group = "Infrastructure";
              url = "http://127.0.0.1:2019/metrics";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
              alerts = [
                {
                  type = "discord";
                  description = "Caddy reverse proxy down — all services unreachable";
                }
              ];
            }
            {
              name = "Authelia";
              group = "Infrastructure";
              url = "http://localhost:${toString config.services.authelia-config.port}/api/health";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "Gitea";
              group = "Development";
              url = "http://localhost:${toString config.services.gitea.settings.server.HTTP_PORT}/api/v1/version";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "Homepage";
              group = "Infrastructure";
              url = "http://localhost:${toString config.services.homepage.port}";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "Immich";
              group = "Media";
              url = "http://localhost:${toString config.services.immich.port}/api/server-info/ping";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "SigNoz";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.signoz.settings.queryService.port}";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
              alerts = [
                {
                  type = "discord";
                  description = "SigNoz observability platform down — no metrics/alerts";
                }
              ];
            }
            {
              name = "Manifest";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.manifest.port}/api/v1/health";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "TaskChampion";
              group = "Productivity";
              url = "tcp://127.0.0.1:${toString config.services.taskchampion-sync-server.port}";
              interval = "60s";
              conditions = ["[CONNECTED] == true"];
            }
            {
              name = "Twenty CRM";
              group = "Productivity";
              url = "http://localhost:${toString config.services.twenty.port}/healthz";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "Ollama";
              group = "AI";
              url = "http://localhost:${toString config.services.ollama.port}/api/tags";
              interval = "60s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "ComfyUI";
              group = "AI";
              url = "http://localhost:${toString config.services.comfyui.port}";
              interval = "5m";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "Node Exporter";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
              interval = "60s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "cAdvisor";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.signoz.settings.cadvisorPort}/metrics";
              interval = "60s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "DNS Resolver";
              group = "Infrastructure";
              url = "127.0.0.1";
              dns = {
                query-name = "google.com";
                query-type = "A";
              };
              interval = "60s";
              conditions = ["[DNS_RCODE] == NOERROR"];
            }
            {
              name = "DNS Resolver TCP";
              group = "Infrastructure";
              url = "tcp://127.0.0.1:53";
              interval = "60s";
              conditions = ["[CONNECTED] == true"];
            }
            {
              name = "DNS Blocker";
              group = "Infrastructure";
              url = "http://localhost:${toString config.services.dns-blocker.statsPort}/health";
              interval = "30s";
              conditions = ["[STATUS] == 200"];
              alerts = [
                {
                  type = "discord";
                  description = "DNS blocker down — no ad/malware blocking";
                }
              ];
            }
            {
              name = "Upstream DNS (Quad9)";
              group = "Infrastructure";
              url = "9.9.9.9";
              dns = {
                query-name = "google.com";
                query-type = "A";
              };
              interval = "5m";
              conditions = ["[DNS_RCODE] == NOERROR"];
            }
            {
              name = "DNS Blocking Active";
              group = "Infrastructure";
              url = "127.0.0.1";
              dns = {
                query-name = "ads.google.com";
                query-type = "A";
              };
              interval = "5m";
              conditions = ["[DNS_RCODE] == NOERROR"];
              alerts = [
                {
                  type = "discord";
                  description = "DNS blocking not active — ads.google.com resolved without block";
                }
              ];
            }
            {
              name = "Whisper ASR";
              group = "AI";
              url = "http://localhost:${toString config.services.voice-agents.whisperPort}";
              interval = "60s";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "LiveKit";
              group = "AI";
              url = "tcp://127.0.0.1:${toString config.services.livekit.settings.port}";
              interval = "60s";
              conditions = ["[CONNECTED] == true"];
            }
            {
              name = "OpenSEO";
              group = "Productivity";
              url = "http://localhost:${toString config.services.openseo.port}";
              interval = "5m";
              conditions = ["[STATUS] == 200"];
            }
            {
              name = "GPU VRAM Metrics";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
              interval = "60s";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*node_amdgpu_mem_info_vram_used_bytes*)"
                "[BODY] == pat(*node_amdgpu_gpu_busy_percent*)"
              ];
            }
            {
              name = "Root Disk Space";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
              interval = "5m";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*node_filesystem_avail_bytes*)"
              ];
            }
            {
              name = "Niri Compositor";
              group = "Monitoring";
              url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
              interval = "60s";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == pat(*niri_running*)"
              ];
            }
          ];
        };
      };

      systemd.services.gatus = {
        onFailure = ["notify-failure@%n.service"];
        path = [pkgs.gnused pkgs.coreutils];
        preStart = ''
          WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
          RUNTIME_CONFIG="/run/gatus/gatus.yaml"
          STATIC_CONFIG="${config.services.gatus.configFile}"
          ${pkgs.coreutils}/bin/mkdir -p /run/gatus
          ${pkgs.coreutils}/bin/cp "$STATIC_CONFIG" "$RUNTIME_CONFIG"
          if [ -f "$WEBHOOK_FILE" ]; then
            WEBHOOK_URL=$(${pkgs.coreutils}/bin/cat "$WEBHOOK_FILE")
            ${pkgs.gnused}/bin/sed -i "s|__DISCORD_WEBHOOK_URL__|$WEBHOOK_URL|g" "$RUNTIME_CONFIG"
          fi
        '';
        environment.GATUS_CONFIG_PATH = "/run/gatus/gatus.yaml";
        serviceConfig =
          harden {
            MemoryMax = "512M";
            ReadWritePaths = ["/var/lib/gatus" "/run/gatus"];
          }
          // serviceDefaults {Restart = "on-failure";};
      };
    };
  };
}
