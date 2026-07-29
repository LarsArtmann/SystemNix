# Gatus health check monitoring with Discord alerts and endpoints
_: {
  flake.nixosModules.gatus-config =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.gatus-config;
      inherit (import ../../../lib/default.nix lib)
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
        runtimeInputs = [ pkgs.coreutils ];
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
    in
    {
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
            ui = {
              title = "evo-x2 Status";
              header = "System Status";
              logo = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/gatus.png";
              link = "https://dash.${domain}";
              dark-mode = true;
              default-sort-by = "group";
              buttons = [
                {
                  name = "Dashboard";
                  link = "https://dash.${domain}";
                }
                {
                  name = "Forgejo";
                  link = "https://forgejo.${domain}";
                }
                {
                  name = "SigNoz";
                  link = "https://signoz.${domain}";
                }
                {
                  name = "Dozzle";
                  link = "https://logs.${domain}";
                }
              ];
            };
            alerting.discord = {
              webhook-url = "$DISCORD_WEBHOOK_URL";
              default-alert = {
                failure-threshold = 3;
                success-threshold = 2;
                send-on-resolved = true;
              };
            };
            endpoints = [
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
                conditions = [
                  "[STATUS] == 204"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "Pocket ID down — SSO broken, no service login works";
              })
              (mkHttpCheck {
                name = "oauth2-proxy";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.oauth2-proxy-config.port}/ping";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "oauth2-proxy down — all external service access broken";
              })
              (mkHttpCheck {
                name = "Forgejo";
                group = "Development";
                url = "http://localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}/api/v1/version";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "Forgejo down — git forge unavailable";
              })
              (mkHttpCheck {
                name = "Homepage";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.homepage.port}";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                  "[BODY] == pat(*<html*)"
                ];
                alerts = discordAlert "Homepage dashboard down";
              })
              (mkHttpCheck {
                name = "Immich";
                group = "Media";
                url = "http://localhost:${toString config.services.immich.port}/api/system-config";
                conditions = [
                  "[STATUS] == 401"
                  "[RESPONSE_TIME] < 1000"
                ];
              })
              {
                name = "Redis";
                group = "Infrastructure";
                url = "tcp://127.0.0.1:${toString ports.redis}";
                interval = "60s";
                conditions = [ "[CONNECTED] == true" ];
                alerts = discordAlert "Redis down — Immich ML pipeline and caching broken";
              }
              (mkHttpCheck {
                name = "SigNoz";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.signoz.settings.queryService.port}/api/v1/health";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "SigNoz observability platform down — no metrics/alerts";
              })
              (mkHttpCheck {
                name = "SigNoz Alert Rules Provisioned";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "5m";
                conditions = [ "[BODY] == pat(*system_signoz_alert_rules_healthy 1*)" ];
                alerts = discordAlert "SigNoz alert rules not provisioned — observability gap, no alerts will fire";
              })
              (mkHttpCheck {
                name = "Manifest";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.manifest.port}/api/v1/health";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "Manifest LLM router down — AI cost optimization unavailable";
              })
              {
                name = "TaskChampion";
                group = "Productivity";
                url = "tcp://127.0.0.1:${toString config.services.taskchampion-sync-server.port}";
                interval = "60s";
                conditions = [ "[CONNECTED] == true" ];
                alerts = discordAlert "TaskChampion sync server down — task syncing broken";
              }
              (mkHttpCheck {
                name = "Twenty CRM";
                group = "Productivity";
                url = "http://localhost:${toString config.services.twenty.port}/healthz";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "Twenty CRM down — customer data unavailable";
              })
              (mkHttpCheck {
                name = "Node Exporter";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "60s";
                alerts = discordAlert "Node exporter down — system metrics monitoring blind";
              })
              (mkHttpCheck {
                name = "cAdvisor";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.signoz.settings.cadvisorPort}/metrics";
                interval = "60s";
                alerts = discordAlert "cAdvisor down — container metrics monitoring blind";
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
                conditions = [ "[DNS_RCODE] == NOERROR" ];
                alerts = discordAlert "Local DNS resolver down — name resolution failing";
              }
              {
                name = "DNS Resolver TCP";
                group = "Infrastructure";
                url = "tcp://127.0.0.1:53";
                interval = "60s";
                conditions = [ "[CONNECTED] == true" ];
              }
              (mkHttpCheck {
                name = "DNS Blocker";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.dns-blocker.statsPort}/health";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
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
                conditions = [ "[DNS_RCODE] == NOERROR" ];
              }
              {
                name = "Upstream DNS DoT (Mullvad)";
                group = "Infrastructure";
                url = "tcp://dot.mullvad.net:853";
                interval = "5m";
                conditions = [ "[CONNECTED] == true" ];
                alerts = discordAlert "Mullvad DoT upstream unreachable — DNS-over-TLS path broken";
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
                conditions = [ "[BODY] == ${config.services.dns-blocker.blockIP}" ];
                alerts = discordAlert "DNS blocking not active — ads.google.com resolved without block";
              }
              (mkHttpCheck {
                name = "External HTTPS";
                group = "Infrastructure";
                url = "https://api.github.com/zen";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 3000"
                ];
                alerts = discordAlert "External HTTPS connectivity lost — server cannot reach the internet";
              })
            ]
            # Ollama is only meaningful when the AI stack is enabled. ai-stack sets
            # ollama to WantedBy multi-user.target, so when enabled it runs
            # persistently (unloading idle models via OLLAMA_KEEP_ALIVE). When
            # ai-stack is disabled, this check is omitted rather than reporting a
            # permanent false-negative.
            ++ lib.optionals (config.services.ai-stack.enable or false) [
              (mkHttpCheck {
                name = "Ollama";
                group = "AI";
                url = "http://localhost:${toString config.services.ollama.port}/api/tags";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                ];
                alerts = discordAlert "Ollama LLM inference down — local AI unavailable";
              })
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
                conditions = [ "[CONNECTED] == true" ];
              }
            ]
            ++ [
              (mkHttpCheck {
                name = "OpenSEO";
                group = "Productivity";
                url = "http://localhost:${toString config.services.openseo.port}";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                ];
                alerts = discordAlert "OpenSEO down — SEO rank tracking unavailable";
              })
            ]
            ++ lib.optionals (config.services.monitor365-server.enable or false) [
              (mkHttpCheck {
                name = "Monitor365 Server";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-server}/health";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "Monitor365 server down — device telemetry unavailable";
              })
              (mkHttpCheck {
                name = "Monitor365 Bootstrap";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-server}/health/bootstrap";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY].bootstrapped == true"
                ];
                alerts = discordAlert "Monitor365 bootstrap incomplete — tenant/SSO provisioning may have failed on first boot";
              })
              (mkHttpCheck {
                name = "Monitor365 UI";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-server}/ui/";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<html*)"
                ];
                alerts = discordAlert "Monitor365 UI not serving — WASM dashboard missing";
              })
              (mkHttpCheck {
                name = "Monitor365 External";
                group = "Monitoring";
                url = "https://monitor.${domain}/health";
                interval = "2m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "Monitor365 external endpoint down — reverse proxy or TLS issue";
              })
              (mkHttpCheck {
                name = "Monitor365 Agent Connected";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-server}/health";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  # Gatus 5.36.0's [BODY].jsonpath is broken — use pat() instead.
                  # Match "connected (N devices)" where N >= 1. The pat() placeholder
                  # matches any text, so this verifies the realtime field shows at
                  # least one connected device (the agent).
                  "[BODY] == pat(*connected (?[1-9]* devices)*)"
                ];
                alerts = discordAlert "Monitor365 agent not connected to server — API key desync or agent crash";
              })
              (mkHttpCheck {
                name = "Monitor365 Backup Health";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "10m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*monitor365_backup_healthy 1*)"
                ];
                alerts = discordAlert "Monitor365 backup stale or missing — DuckDB nightly backup may have failed. Check: systemctl status monitor365-server-backup.timer";
              })
            ]
            ++ lib.optionals (config.services.monitor365.enable or false) [
              (mkHttpCheck {
                name = "Monitor365 System Agent";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-metrics}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*collector_events_collected*)"
                ];
                alerts = discordAlert "Monitor365 system agent down — headless device telemetry collector not running";
              })
              (mkHttpCheck {
                name = "Monitor365 Cloud Sync Health";
                group = "Monitoring";
                url = "http://localhost:${toString ports.monitor365-metrics}/metrics";
                interval = "2m";
                # Gatus 5.36.0 cannot do numeric comparison on Prometheus text
                # metrics ([BODY].jsonpath is broken, pat() is presence-only).
                # We verify the sync subsystem is ACTIVE by checking both the
                # backlog gauge and the rejected-events counter exist. The
                # self-healing fix (server skip-and-continue + agent cursor
                # advance) means backlog drains automatically — this check
                # catches the agent STOPPING sync entirely (circuit breaker
                # stuck open, crash loop, auth failure). For VALUE-based
                # alerting (backlog > N threshold), wire Prometheus/SigNoz
                # to scrape this endpoint and add an alert rule there.
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*cloud_sync_upload_backlog_size*)"
                  "[BODY] == pat(*cloud_sync_upload_rejected_events_total*)"
                ];
                alerts = discordAlert "Monitor365 cloud sync subsystem not emitting metrics — agent may have stopped syncing (circuit breaker open, auth failure, or crash loop). Check: journalctl -u monitor365 -n 50";
              })
            ]
            ++ [
              (mkHttpCheck {
                name = "EMEET PIXY";
                group = "Monitoring";
                url = "http://localhost:${toString ports.emeet-pixyd}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*emeet*)"
                ];
                alerts = discordAlert "EMEET PIXY daemon down — webcam auto-management broken";
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
                name = "BTRFS Scrub Health";
                group = "Filesystem";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "10m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*btrfs_scrub_status*)"
                  "[BODY] == pat(*btrfs_scrub_error_free 1*)"
                ];
                alerts = discordAlert "BTRFS scrub found errors — potential data corruption. Run 'btrfs scrub status /' and 'btrfs scrub status /data' to investigate. Check Prometheus btrfs_scrub_errors_total for details.";
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
                alerts = discordAlert "Niri compositor not running — desktop may be unresponsive";
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
            ]
            ++ lib.optionals (config.services.system-health.enable or false) [
              (mkHttpCheck {
                name = "Monitor365 Server Crash Loop";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "1m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_service_start_limit_hit{service=\"monitor365-server\"} 0*)"
                ];
                alerts = discordAlert "Monitor365 server hit start-limit — crash loop detected (DuckDB WAL corruption or OOM). Run: sudo systemctl reset-failed monitor365-server && sudo systemctl start monitor365-server";
              })
              (mkHttpCheck {
                name = "PMA Service";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "2m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_service_active{service=\"projects-management-automation\"} 1*)"
                ];
                alerts = discordAlert "Projects Management Automation daemon down — automated project tracking stopped. Check: journalctl -u projects-management-automation -n 50";
              })
              (mkHttpCheck {
                name = "Service Restart Metrics";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_service_nrestarts*)"
                ];
                alerts = discordAlert "Service restart metrics not being collected — systemd health monitoring disabled";
              })
              (mkHttpCheck {
                name = "GPUActive Memory Threshold";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "1m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_gpu_active_over_threshold 0*)"
                ];
                alerts = discordAlert "GPUActive exceeds 60G — GTT buffer objects consuming excessive RAM. Check /proc/meminfo GPUActive. Risk of OOM cascade on Strix Halo.";
              })
              (mkHttpCheck {
                name = "User Slice Memory";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "1m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_user_slice_memory_over_threshold 0*)"
                ];
                alerts = discordAlert "user-1000.slice memory exceeds 40G — desktop processes consuming excessive RAM (MemoryHigh=56G, MemoryMax=64G). Risk of journald starvation and WDT reset.";
              })
              (mkHttpCheck {
                name = "Monitor365 Buffer Pressure";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_monitor365_buffer_pressure 0*)"
                ];
                alerts = discordAlert "Monitor365 DuckDB exceeds 1.6G — buffer pressure risk. Server may hit MemoryMax under load. Consider reducing retention or increasing MemoryMax.";
              })
              (mkHttpCheck {
                name = "Monitor365 CPU Runaway";
                group = "Monitoring";
                url = "http://localhost:${toString nodePort}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*system_service_cpu_over_threshold{service=\"monitor365\"} 0*)"
                ];
                alerts = discordAlert "Monitor365 agent CPU exceeds 150% average — possible busy-loop (circuit breaker + early-flush bug). Check: journalctl -u monitor365 -n 50, look for cloud_sync failures";
              })
            ]
            ++ [
              (mkHttpCheck {
                name = "Crush Daily";
                group = "AI";
                url = "http://localhost:${toString config.services.crush-daily.port}/api/health";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "Crush Daily down — AI development insights unavailable";
              })
              (mkHttpCheck {
                name = "Dozzle";
                group = "Monitoring";
                url = "http://localhost:${toString ports.dozzle}";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "Dozzle down — container log viewing unavailable";
              })
              (mkHttpCheck {
                name = "Overview";
                group = "Productivity";
                url = "http://localhost:${toString ports.overview}";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                  "[BODY] == pat(*<html*)"
                ];
                alerts = discordAlert "Overview dashboard down — project stats unavailable";
              })
              (mkHttpCheck {
                name = "Gatus";
                group = "Monitoring";
                url = "http://localhost:${toString cfg.port}";
                interval = "5m";
                # With native OIDC enabled, an unauthenticated probe is redirected
                # to the IdP login (302/303) instead of 200. Accept any non-error
                # status so the self-health check doesn't false-alarm.
                conditions = if enableOidc then [ "[STATUS] < 400" ] else [ "[STATUS] == 200" ];
              })
            ]
            ++ lib.optionals config.services.discordsync.enable [
              (mkHttpCheck {
                name = "DiscordSync";
                group = "Infrastructure";
                # Use /healthz for liveness: it returns 200 once the API server is
                # bound (after the long thumb-hash backfill), and fails hard
                # (connection refused) when the process is down. /readyz returns 503
                # during startup which made the previous < 400 condition miss
                # connection failures (status 0).
                url = "http://localhost:${toString ports.discordsync-api}/healthz";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "DiscordSync backup bot down — Discord messages not being captured";
              })
            ]
            ++ lib.optionals (config.services.file-and-image-renamer.enable or false) [
              (mkHttpCheck {
                name = "File Renamer Health";
                group = "Productivity";
                url = "http://localhost:${toString ports.file-and-image-renamer-health}/status";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "File and Image Renamer health dashboard down — screenshot renaming may be stuck";
              })
            ]
            ++ lib.optionals (config.services.qmd-config.enable or false) [
              (mkHttpCheck {
                name = "qmd MCP HTTP Server";
                group = "Productivity";
                # qmd mcp --http exposes GET /health with uptime JSON. Slower
                # interval: the server streams long-lived requests and 5min
                # polls keep it warm without flooding the journal.
                url = "http://localhost:${toString ports.qmd}/health";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alerts = discordAlert "qmd MCP HTTP server down — AI agents (Crush, Claude) cannot search local markdown until it restarts. Check: systemctl --user status qmd-mcp on the primary user's session.";
              })
            ]
            ++ lib.optionals (config.services.searx.enable or false) [
              (mkHttpCheck {
                name = "SearXNG";
                group = "Productivity";
                url = "http://localhost:${toString ports.searxng}/healthz";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alerts = discordAlert "SearXNG metasearch engine down — privacy search unavailable";
              })
            ];
          };
        };

        systemd.services.gatus = {
          inherit onFailure;
          # Gatus must not start before the OIDC client secret has been provisioned.
          after = lib.optional enableOidc "pocket-id-provision.service";
          wants = lib.optional enableOidc "pocket-id-provision.service";
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "512M";
              ReadWritePaths = [ "/var/lib/gatus" ];
            })
            (serviceDefaults { Restart = "on-failure"; })
            {
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
            }
          ];
        };
      };
    };
}
