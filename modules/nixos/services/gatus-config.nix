# Gatus health check monitoring with Discord alerts and endpoints
_: {
  flake.nixosModules.gatus-config = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.gatus-config;
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      onFailure
      serviceTypes
      mkHttpCheck
      mkSecretCheck
      ports
      ;

    nodePort = config.services.prometheus.exporters.node.port;

    checkGatusEnv = mkSecretCheck pkgs {
      name = "gatus-env";
      secretPath = config.sops.templates."gatus-env".path;
      message = "gatus: environment file is missing or empty (${
        config.sops.templates."gatus-env".path
      }) — Discord alerting will fail";
    };

    discordAlert = desc: [
      {
        type = "discord";
        inherit desc;
      }
    ];

    inherit (config.networking) domain;

    # Native OIDC via Pocket ID (Layer 1 SSO). Provision-only: evo-x2 always
    # runs pocket-id-config.provision, which writes the client secret to the
    # file below. systemd LoadCredential reads it as root (DynamicUser means the
    # gatus user does not exist to own files directly) and exposes the value to
    # the service via $CREDENTIALS_DIRECTORY, where the oidc env writer copies it
    # into an env file that gatus consumes via config.yaml $VAR interpolation.
    enableOidc =
      (config.services.pocket-id-config.enable or false)
      && (config.services.pocket-id-config.provision.enable or false);
    clientSecretPath = "${config.services.pocket-id.dataDir}/client-secrets/gatus";

    gatusOidcEnv = pkgs.writeShellApplication {
      name = "gatus-oidc-env";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        set -eu
        out="''${RUNTIME_DIRECTORY:-/run/gatus}/oidc.env"
        if [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -f "''${CREDENTIALS_DIRECTORY}/gatus-oidc-secret" ]; then
          printf 'GATUS_OIDC_CLIENT_SECRET=%s\n' "$(cat "''${CREDENTIALS_DIRECTORY}/gatus-oidc-secret")" > "$out"
          chmod 600 "$out"
        else
          : > "$out"
        fi
      '';
    };
  in {
    options.services.gatus-config = {
      enable = lib.mkEnableOption "Gatus health check monitoring with pre-configured endpoints";
      port = serviceTypes.servicePort ports.gatus "HTTP port for Gatus web interface";
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
          # Native OIDC (Layer 1 SSO) via Pocket ID. Empty when OIDC is off.
          # allowed-subjects omitted: single-admin IdP, so any authenticated user
          # (= the admin) may view the dashboard.
          security = lib.optionalAttrs enableOidc {
            oidc = {
              issuer-url = "https://auth.${domain}";
              client-id = "gatus";
              client-secret = "$GATUS_OIDC_CLIENT_SECRET";
              redirect-url = "https://status.${domain}/authorization-code/callback";
              scopes = [
                "openid"
                "profile"
                "email"
              ];
            };
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
                url = "http://127.0.0.1:${toString ports.caddy-metrics}/metrics";
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
                url = "http://localhost:${toString config.services.immich.port}/api/system-config";
                conditions = ["[STATUS] == 401"];
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
              (mkHttpCheck {
                name = "Monitor365 Server";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-server}";
                interval = "60s";
              })
              (mkHttpCheck {
                name = "EMEET PIXY";
                group = "Monitoring";
                url = "http://localhost:${toString ports.emeet-pixyd}/metrics";
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
                name = "BTRFS Chunk Health";
                group = "Filesystem";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*btrfs_device_unallocated_pct*)"
                  "[BODY] == pat(*btrfs_metadata_utilization_pct*)"
                ];
                alerts = discordAlert "BTRFS chunk allocation critical — device-unallocated <10% or metadata >85%. Nightly GC has been auto-blocked to prevent metadata ENOSPC crash. Free space: grow partition or delete old snapshots.";
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
              (mkHttpCheck {
                name = "Memory Metrics";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*node_memory_MemAvailable_bytes*)"
                  "[BODY] == pat(*node_memory_MemTotal_bytes*)"
                ];
                alerts = discordAlert "Memory metrics not being collected — memory alerting disabled";
              })
              (mkHttpCheck {
                name = "Swap Metrics";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*node_memory_SwapFree_bytes*)"
                  "[BODY] == pat(*node_memory_SwapTotal_bytes*)"
                ];
                alerts = discordAlert "Swap metrics not being collected — swap alerting disabled";
              })
              (mkHttpCheck {
                name = "Memory Pressure";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "30s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*node_psi_memory_alert 0*)"
                ];
                alerts = discordAlert "Memory pressure CRITICAL — PSI some>50% or full>10%. Risk of OOM cascade. Check Helium/Electron processes.";
              })
              (mkHttpCheck {
                name = "Crush Daily";
                group = "AI";
                url = "http://localhost:${toString config.services.crush-daily.port}/api/health";
                interval = "5m";
              })
              (mkHttpCheck {
                name = "Dozzle";
                group = "Monitoring";
                url = "http://localhost:${toString ports.dozzle}";
                interval = "5m";
              })
              (mkHttpCheck {
                name = "Gatus";
                group = "Monitoring";
                url = "http://localhost:${toString cfg.port}";
                interval = "5m";
                # With native OIDC enabled, an unauthenticated probe is redirected
                # to the IdP login (302/303) instead of 200. Accept any non-error
                # status so the self-health check doesn't false-alarm.
                conditions =
                  if enableOidc
                  then ["[STATUS] < 400"]
                  else ["[STATUS] == 200"];
              })
            ]
            ++ lib.optionals config.services.discordsync.enable [
              (mkHttpCheck {
                name = "DiscordSync";
                group = "Infrastructure";
                url = "http://localhost:${toString ports.discordsync-api}/healthz";
                interval = "60s";
                alerts = discordAlert "DiscordSync backup bot down — Discord messages not being captured";
              })
            ];
        };
      };

      systemd.services.gatus = {
        inherit onFailure;
        # Gatus must not start before the OIDC client secret has been provisioned.
        after = lib.optional enableOidc "pocket-id-provision.service";
        wants = lib.optional enableOidc "pocket-id-provision.service";
        serviceConfig =
          harden {
            MemoryMax = "512M";
            ReadWritePaths = ["/var/lib/gatus"];
          }
          // serviceDefaults {Restart = "on-failure";}
          // {
            ExecStartPre = [
              "+${lib.getExe checkGatusEnv}"
              "${lib.getExe gatusOidcEnv}"
            ];
            RuntimeDirectory = "gatus";
            LoadCredential = lib.optional enableOidc "gatus-oidc-secret:${clientSecretPath}";
            # Compose the full EnvironmentFile list: the sops template
            # (DISCORD_WEBHOOK_URL) plus the runtime-generated OIDC secret file
            # (the '-' prefix makes a missing file non-fatal when OIDC is off).
            EnvironmentFile = lib.mkForce [
              config.sops.templates."gatus-env".path
              "-/run/gatus/oidc.env"
            ];
          };
      };
    };
  };
}
