# Gatus health check monitoring with Discord alerts and endpoints
_: {
  flake.nixosModules.gatus-config = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.gatus-config;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes mkHttpCheck ports;

    nodePort = config.services.prometheus.exporters.node.port;

    checkGatusEnv = pkgs.writeShellApplication {
      name = "check-gatus-env";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        env_path="${config.sops.templates."gatus-env".path}"
        if [ ! -s "$env_path" ]; then
          echo "gatus: environment file is missing or empty ($env_path) — Discord alerting will fail" >&2
          exit 1
        fi
      '';
    };

    discordAlert = desc: [
      {
        type = "discord";
        inherit desc;
      }
    ];
  in {
    options.services.gatus-config = {
      enable = lib.mkEnableOption "Gatus health check monitoring with pre-configured endpoints";
      port = serviceTypes.servicePort 8083 "HTTP port for Gatus web interface";
    };

    config = lib.mkIf cfg.enable {
      services.gatus = {
        enable = true;
        environmentFile = config.sops.templates."gatus-env".path;
        settings = {
          web.port = cfg.port;
          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/gatus.db";
            caching = true;
          };
          alerting.discord = {
            webhook-url = "$DISCORD_WEBHOOK_URL";
            default-alert = {
              failure-threshold = 3;
              success-threshold = 2;
              send-on-resolved = true;
            };
          };
          endpoints =
            [
              (mkHttpCheck {
                name = "Caddy";
                group = "Infrastructure";
                url = "http://127.0.0.1:2019/metrics";
                alerts = discordAlert "Caddy reverse proxy down — all services unreachable";
              })
              (mkHttpCheck {
                name = "Pocket ID";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.pocket-id-config.port}/healthz";
                conditions = ["[STATUS] == 204"];
              })
              (mkHttpCheck {
                name = "oauth2-proxy";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.oauth2-proxy-config.port}/ping";
              })
              (mkHttpCheck {
                name = "Forgejo";
                group = "Development";
                url = "http://localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}/api/v1/version";
              })
              (mkHttpCheck {
                name = "Homepage";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.homepage.port}";
              })
              (mkHttpCheck {
                name = "Immich";
                group = "Media";
                url = "http://localhost:${toString config.services.immich.port}/api/server-info/ping";
              })
              (mkHttpCheck {
                name = "SigNoz";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.signoz.settings.queryService.port}";
                alerts = discordAlert "SigNoz observability platform down — no metrics/alerts";
              })
              (mkHttpCheck {
                name = "Manifest";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.manifest.port}/api/v1/health";
              })
              {
                name = "TaskChampion";
                group = "Productivity";
                url = "tcp://127.0.0.1:${toString config.services.taskchampion-sync-server.port}";
                interval = "60s";
                conditions = ["[CONNECTED] == true"];
              }
              (mkHttpCheck {
                name = "Twenty CRM";
                group = "Productivity";
                url = "http://localhost:${toString config.services.twenty.port}/healthz";
              })
              (mkHttpCheck {
                name = "Ollama";
                group = "AI";
                url = "http://localhost:${toString config.services.ollama.port}/api/tags";
                interval = "60s";
              })
              (mkHttpCheck {
                name = "Node Exporter";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
              })
              (mkHttpCheck {
                name = "cAdvisor";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.signoz.settings.cadvisorPort}/metrics";
                interval = "60s";
              })
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
              (mkHttpCheck {
                name = "DNS Blocker";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.dns-blocker.statsPort}/health";
                alerts = discordAlert "DNS blocker down — no ad/malware blocking";
              })
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
                conditions = ["[BODY] == ${config.services.dns-blocker.blockIP}"];
                alerts = discordAlert "DNS blocking not active — ads.google.com resolved without block";
              }
            ]
            ++ lib.optionals config.services.voice-agents.enable [
              (mkHttpCheck {
                name = "Whisper ASR";
                group = "AI";
                url = "http://localhost:${toString config.services.voice-agents.whisperPort}";
                interval = "60s";
              })
              {
                name = "LiveKit";
                group = "AI";
                url = "tcp://127.0.0.1:${toString config.services.livekit.settings.port}";
                interval = "60s";
                conditions = ["[CONNECTED] == true"];
              }
            ]
            ++ [
              (mkHttpCheck {
                name = "OpenSEO";
                group = "Productivity";
                url = "http://localhost:${toString config.services.openseo.port}";
                interval = "5m";
              })
              {
                name = "Monitor365 Server";
                group = "Monitoring";
                url = "tcp://127.0.0.1:${toString ports.monitor365-server}";
                interval = "60s";
                conditions = ["[CONNECTED] == true"];
              }
              (mkHttpCheck {
                name = "EMEET PIXY";
                group = "Monitoring";
                url = "http://localhost:8090/metrics";
                interval = "60s";
              })
              (mkHttpCheck {
                name = "GPU VRAM Metrics";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*node_amdgpu_mem_info_vram_used_bytes*)"
                  "[BODY] == pat(*node_amdgpu_gpu_busy_percent*)"
                ];
              })
              (mkHttpCheck {
                name = "Root Disk Space";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*node_filesystem_avail_bytes*)"
                ];
              })
              (mkHttpCheck {
                name = "NVMe SMART Metrics";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*node_nvme_temperature_celsius*)"
                  "[BODY] == pat(*node_nvme_percentage_used*)"
                  "[BODY] == pat(*node_nvme_media_errors_total*)"
                ];
                alerts = discordAlert "NVMe SMART metrics not being collected — disk health unmonitored";
              })
              (mkHttpCheck {
                name = "Niri Compositor";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*niri_running*)"
                ];
              })
              (mkHttpCheck {
                name = "TLS Certificate Expiry";
                group = "Infrastructure";
                url = "https://auth.home.lan";
                interval = "1h";
                conditions = [
                  "[STATUS] == 200"
                  "[CERTIFICATE_EXPIRATION] > 168h"
                ];
                alerts = discordAlert "TLS certificate for *.home.lan expires within 7 days — renew via dnsblockd";
              })
            ];
        };
      };

      systemd.services.gatus = {
        inherit onFailure;
        serviceConfig =
          harden {
            MemoryMax = "512M";
            ReadWritePaths = ["/var/lib/gatus"];
          }
          // serviceDefaults {Restart = "on-failure";}
          // {
            ExecStartPre = "+${lib.getExe checkGatusEnv}";
          };
      };
    };
  };
}
