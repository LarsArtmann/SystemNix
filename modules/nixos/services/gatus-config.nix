# Gatus health check monitoring with Discord alerts and endpoints
_: {
  flake.nixosModules.gatus-config =
    {
      config,
      options,
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
        mkOidcGate
        discordAlert
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

      # Smart alerting: append a PapDashboard ingest alert (type "custom") to
      # every endpoint when the hub is enabled. Gatus' provider default-alert
      # only fills thresholds for endpoints that DECLARE an alert of that
      # type — without this pass, nothing would reach /api/ingest.
      papIngestEnabled = config.services.papdashboard.enable or false;

      withPapIngest =
        ep:
        let
          existing = ep.alerts or [ ];
          withDescription = lib.findFirst (a: a ? description) null existing;
        in
        ep
        // {
          alerts = existing ++ [
            (
              {
                type = "custom";
              }
              // lib.optionalAttrs (withDescription != null) {
                inherit (withDescription) description;
              }
            )
          ];
        };

      # Public open-source project websites (Firebase Hosting), mirrored from
      # /home/lars/projects/domains/lars.software.tf — keep in sync when a site
      # is added there. Probed from evo-x2, so each check verifies the full
      # external chain: public DNS → Firebase CDN → site content. This catches
      # outages the LAN-only checks cannot see (unclaimed web.app targets,
      # missing DNS records, broken deploys).
      #
      # REMOVED 2026-09-02 (72h log review): three endpoints were permanently
      # dead and each burned ~324 failure events/day in gatus alerts:
      #   - cmdguard.lars.software      — TLS cert mismatch (serves the
      #     *.firebaseapp.com cert; Firebase custom-domain binding is gone)
      #   - go-output.lars.software     — HTTP 404 (Firebase site deleted or
      #     web.app target unclaimed)
      #   - md-go-validator.lars.software — NXDOMAIN (DNS record removed in
      #     lars.software.tf but never removed here)
      # Re-add an endpoint only after `https://<host>/` returns 200 with real
      # content again (verify the DNS record AND the Firebase hosting target).
      ossWebsites = [
        "lars.software"
        "www.lars.software"
        "status.lars.software" # Better Stack status page (CNAME → statuspage.betteruptime.com)
        "gogenfilter.lars.software"
        "gogenfilter.larsartmann.com" # alias CNAME from larsartmann.com.tf
        "atomicwrite.lars.software"
        "go-atomic-write.lars.software" # alias of atomicwrite.lars.software
        "go-workflow-auditlog.lars.software"
        "filewatcher.lars.software"
        "errorfamily.lars.software"
        "art-dupl.lars.software"
        "do-auditlog.lars.software"
        "dynamicmarkdown.lars.software"
        "templcomponents.lars.software"
        "branded-id.lars.software"
        "emeet-pixyd.lars.software"
        "cleanwizard.lars.software"
      ];

      mkWebsiteCheck =
        host:
        mkHttpCheck {
          name = host;
          group = "Open Source Websites";
          url = "https://${host}/";
          interval = "5m";
          conditions = [
            "[STATUS] == 200"
            "[RESPONSE_TIME] < 2000"
            # Firebase serves an HTML error page even for 404s, so STATUS is the
            # hard gate; this confirms real site content (docs/SPA shell) came back.
            "[BODY] == pat(*<html*)"
          ];
          alerts = discordAlert "${host} down — public website unreachable (DNS, Firebase Hosting, or certificate issue)";
        };

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

        # Extension seam for services.integration registry fan-out. Endpoints
        # here ride the SAME withPapIngest pass as the built-in list —
        # appending to services.gatus.settings.endpoints directly from other
        # modules would bypass the PapDashboard ingest alert pass.
        extraEndpoints = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
          description = "Extra gatus endpoints appended after the built-in ones (pass mkHttpCheck-shaped attrsets)";
        };
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
            # Smart-alerting fast path #2: every endpoint ALSO POSTs its
            # trigger/resolve transitions into PapDashboard (localhost ingest,
            # Bearer-key auth via $PAPDASHBOARD_INGEST_KEY from gatus-env).
            # The raw Discord path above stays untouched — PapDashboard death
            # never silences raw alerts. Placeholders remap the state marker to
            # PapDashboard's event types (alert.triggered / alert.resolved).
            # Key is OMITTED (not emptied) when papdashboard is off — gatus
            # validates a present-but-empty custom provider as ErrURLNotSet.
            alerting = {
              discord = {
                webhook-url = "$DISCORD_WEBHOOK_URL";
                default-alert = {
                  failure-threshold = 3;
                  success-threshold = 2;
                  send-on-resolved = true;
                };
              };
            }
            // lib.optionalAttrs (config.services.papdashboard.enable or false) {
              custom = {
                url = "http://localhost:${toString ports.papdashboard}/api/ingest";
                # MUST be uppercase: Go's ServeMux matches method tokens
                # CASE-SENSITIVELY (RFC 9110). gatus passes this through
                # verbatim — lowercase "post" 405s against POST-registered
                # routes (live-verified 2026-08-18: 'post'→405, 'POST'→422
                # validation; 1076+ ingests lost to this one character).
                method = "POST";
                headers = {
                  Content-Type = "application/json";
                  Authorization = "Bearer $PAPDASHBOARD_INGEST_KEY";
                };
                placeholders = {
                  ALERT_TRIGGERED_OR_RESOLVED = {
                    TRIGGERED = "triggered";
                    RESOLVED = "resolved";
                  };
                };
                # Body shape verified against the live /api/ingest schema
                # (huma requires aggregateId + metadata.{correlationId,causationId}).
                body = ''{"type":"alert.[ALERT_TRIGGERED_OR_RESOLVED]","aggregateId":"gatus-[ENDPOINT_NAME]","payload":{"severity":"error","title":"[ENDPOINT_NAME]","body":"[ALERT_DESCRIPTION] — errors: [RESULT_ERRORS]","sourceApp":"gatus"},"metadata":{"correlationId":"gatus","causationId":"gatus","userId":"","sourceApp":"gatus"}}'';
                default-alert = {
                  failure-threshold = 3;
                  success-threshold = 2;
                  send-on-resolved = true;
                };
              };
            };
            endpoints = (if papIngestEnabled then map withPapIngest else lib.id) (
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
                  name = "ClickHouse";
                  group = "Infrastructure";
                  url = "http://127.0.0.1:${toString ports.signoz-clickhouse-http}/ping";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alerts = discordAlert "ClickHouse down — SigNoz observability broken (traces, logs, metrics)";
                })
                # Forgejo + Forgejo Mirror Sync checks moved to their owning
                # module (services.integration.forgejo.checks).
                (mkHttpCheck {
                  name = "Stuck D-State Processes";
                  group = "Infrastructure";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_stuck_dstate_processes 0*)"
                  ];
                  alerts = discordAlert "Processes stuck in uninterruptible D-state for >1h — unkillable even by SIGKILL (driver/firmware wedge, amdxdna class 2026-09-04). Every restart of the owning unit strands another corpse; REBOOT is the only fix. Find them: ps -eo pid,stat,wchan:30,etime,comm, then filter the STAT column for lines starting with D";
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
                (mkHttpCheck {
                  name = "Paperless";
                  group = "Documents";
                  url = "http://localhost:${toString config.services.paperless.port}/accounts/login/";
                  # SSO-only mode (2026-09-02): the login page must show the
                  # Pocket ID provider form with the JS auto-submit mounted
                  # (PAPERLESS_REDIRECT_LOGIN_TO_SSO is a CLIENT-SIDE
                  # redirect — paperless's template auto-submits the first
                  # provider form; there is no 302) and NO password input
                  # (PAPERLESS_DISABLE_REGULAR_LOGIN — the flags ride in the
                  # paperless-oidc-setup env file, so a 200 with a password
                  # field means the bridge degraded and break-glass is
                  # serving: visible, non-silent).
                  conditions =
                    if config.services.pocket-id-config.enable then
                      [
                        "[STATUS] == 200"
                        "[RESPONSE_TIME] < 1000"
                        "[BODY] == pat(*oidc/pocket-id*)"
                        "[BODY] == pat(*getElementById*)"
                        "[BODY] != pat(*type=\"password\"*)"
                      ]
                    else
                      [
                        "[STATUS] == 200"
                        "[RESPONSE_TIME] < 1000"
                        "[BODY] == pat(*Paperless-ngx sign in*)"
                      ];
                  alerts = discordAlert "Paperless SSO degraded — login page lost the Pocket ID auto-submit flow or the password form is back (bridge problem: journalctl -u paperless-oidc-setup)";
                })
                (mkHttpCheck {
                  name = "Paperless Tika";
                  group = "Documents";
                  url = "http://localhost:${toString ports.tika}/";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 2000"
                  ];
                  alerts = discordAlert "Paperless Tika parser down — Office/e-mail documents will fail to consume until it recovers";
                })
                (mkHttpCheck {
                  name = "Paperless Gotenberg";
                  group = "Documents";
                  url = "http://localhost:${toString ports.gotenberg}/health";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 2000"
                  ];
                  alerts = discordAlert "Paperless Gotenberg down — Office-to-PDF conversions will fail until it recovers";
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
                  name = "SigNoz Web UI";
                  group = "Monitoring";
                  url = "http://localhost:${toString config.services.signoz.settings.queryService.port}/";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # Liveness + health: the SPA shell is served (the API 404
                    # page is plain text, not HTML). Leading "<" also keeps the
                    # pre-deploy-check pat() metric extractor from treating
                    # this as a Prometheus metric name.
                    "[BODY] == pat(*<title data-react-helmet*)"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alerts = discordAlert "SigNoz web UI not serving — https://signoz.home.lan returns 404";
                })
                (mkHttpCheck {
                  name = "SigNoz Alert Rules Provisioned";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  # HELP line is "# HELP system_signoz_alert_rules_healthy 1 if ..." — a bare
                  # pat(*metric 1*) would match the comment and stay green when the value is 0.
                  # Assert absence of the 0-value line plus presence of the metric instead.
                  conditions = [
                    "[BODY] != pat(*system_signoz_alert_rules_healthy 0\n*)"
                    "[BODY] == pat(*\nsystem_signoz_alert_rules_healthy *)"
                  ];
                  alerts = discordAlert "SigNoz alert rules not provisioned — observability gap, no alerts will fire";
                })
                (mkHttpCheck {
                  name = "SigNoz OTLP Receiver";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.signoz-otlp-http}/";
                  interval = "2m";
                  conditions = [
                    "[STATUS] < 500"
                  ];
                  alerts = discordAlert "SigNoz OTLP receiver not responding — distributed tracing will silently fail for all services";
                })
                # Telemetry coverage audit (signoz-coverage.nix): the registry
                # demands spans from every enforced service; missing counts
                # services whose traces went dark. Anchored value-check form
                # (real newline in the nix string — the 2026-08-22 escape
                # trap); [1-9] catches any nonzero value including multi-digit.
                (mkHttpCheck {
                  name = "SigNoz Traces Coverage";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nsignoz_traces_missing *)"
                    "[BODY] != pat(*\nsignoz_traces_missing [1-9]*)"
                    "[BODY] == pat(*\nsignoz_coverage_scrape_errors *)"
                    "[BODY] != pat(*\nsignoz_coverage_scrape_errors [1-9]*)"
                  ];
                  alerts = discordAlert "SigNoz trace coverage gap — a registered service stopped sending spans (or the coverage collector failed): silent observability hole. Check signoz_traces_reporting in :9100/metrics for which service went dark";
                })
                (mkHttpCheck {
                  name = "SigNoz Logs Pipeline Fresh";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nsignoz_logs_pipeline_stale *)"
                    "[BODY] != pat(*\nsignoz_logs_pipeline_stale [1-9]*)"
                  ];
                  alerts = discordAlert "SigNoz journald logs pipeline stale — no log records ingested for >30 min (all service logs dark)";
                })
                # Gap budget ratchet (signoz-coverage.maxUpstreamGaps): fires
                # when the registry's upstream-gap count GROWS past the budget
                # — new silent noops may not slip in unnoticed. Lower the
                # budget as gaps close; raising it is a conscious commit.
                (mkHttpCheck {
                  name = "SigNoz Trace Gap Budget";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nsignoz_traces_upstream_gaps_over_threshold *)"
                    "[BODY] != pat(*\nsignoz_traces_upstream_gaps_over_threshold [1-9]*)"
                  ];
                  alerts = discordAlert "SigNoz upstream trace-gap budget exceeded — a new silent-noop service entered the registry. Instrument it upstream and flip its wiring, or consciously raise services.signoz-coverage.maxUpstreamGaps (the ratchet goes DOWN as gaps close)";
                })
                # Manifest + Twenty CRM checks moved to their owning modules
                # (services.integration.{manifest,twenty}.checks).
                {
                  name = "TaskChampion";
                  group = "Productivity";
                  url = "tcp://127.0.0.1:${toString config.services.taskchampion-sync-server.port}";
                  interval = "60s";
                  conditions = [ "[CONNECTED] == true" ];
                  alerts = discordAlert "TaskChampion sync server down — task syncing broken";
                }
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
              ++ [
                (mkHttpCheck {
                  name = "EMEET PIXY";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_emeet_pixyd_expected_down 0*)"
                  ];
                  alerts = discordAlert "EMEET PIXY daemon down with graphical session active — webcam auto-management broken. Check: systemctl --user status emeet-pixyd";
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
                  name = "ZRAM Fill";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_zram_swap_fill_percent*)"
                    "[BODY] == pat(*system_zram_fill_over_threshold 0*)"
                  ];
                  alerts = discordAlert "zram swap over 90% full — with zram as the ONLY swap the kernel falls back to page-cache reclaim once full, the BTRFS I/O storm precursor. Free memory NOW (systemd-cgtop, smem) before the device hits 100%. Metric: system_zram_swap_fill_percent (node_exporter textfile collector, updated every 2min)";
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
                    "[BODY] == pat(*btrfs_health_critical 0*)"
                  ];
                  alerts = discordAlert "BTRFS space health CRITICAL — device-unallocated <5% or metadata pool >90% (metadata-ENOSPC precursor, the 2026-06-26 crash class). nix-gc is auto-blocked below a 5GiB unalloc floor or metadata >90%. Recover: 'sudo systemctl start btrfs-balance-metadata.service' (needs >=5GiB unalloc), expire old btrbk snapshots, or use the 10GiB emergency reserve at /btrfs-emergency-reserve. Live values: btrfs_device_unallocated_pct / btrfs_metadata_utilization_pct.";
                })
                (mkHttpCheck {
                  name = "BTRFS Scrub Errors";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "10m";
                  # Split from the old "BTRFS Scrub Health" (2026-09-15): the
                  # single error_free composite conflated ERRORS with an
                  # incomplete last scrub — a guard-deferred or RUNNING scrub
                  # red the check with zero errors. Errors now have their own
                  # composite; incompleteness moved to "BTRFS Scrub
                  # Incomplete".
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*btrfs_scrub_errors_present 1\n*)"
                    "[BODY] == pat(*\nbtrfs_scrub_errors_present *)"
                  ];
                  alerts = discordAlert "BTRFS scrub found errors — potential data corruption. Run 'btrfs scrub status /' and 'btrfs scrub status /data' to investigate. Check Prometheus btrfs_scrub_errors_total for details.";
                })
                (mkHttpCheck {
                  name = "BTRFS Scrub Incomplete";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "10m";
                  # The never-finished/interrupted leg, EXCLUDING the
                  # guard-deferred class: memory-emergency-guard stops scrub
                  # units on any trip (never restarts them) — while its
                  # churn window is open (btrfs_scrub_deferred_by_guard 1)
                  # an incomplete scrub is EXPECTED. A RUNNING scrub is also
                  # not incomplete (the old check red during every run).
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*btrfs_scrub_incomplete_unexplained 1\n*)"
                    "[BODY] == pat(*\nbtrfs_scrub_incomplete_unexplained *)"
                  ];
                  alerts = discordAlert "BTRFS scrub is incomplete (never started or interrupted) WITHOUT a guard deferral — a silently wedged scrub, not the memory-guard churn-stop class (that sets btrfs_scrub_deferred_by_guard 1 and this check stays green). Check 'btrfs scrub status /' and '/data', memory-emergency-guard journal for recent trips; the next weekly autoScrub window retries.";
                })
                (mkHttpCheck {
                  name = "BTRFS Emergency Reserve";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "10m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*btrfs_emergency_reserve_present 0\n*)"
                    "[BODY] == pat(*\nbtrfs_emergency_reserve_present *)"
                  ];
                  alerts = discordAlert "BTRFS emergency reserve missing — the 10 GiB safety net at /btrfs-emergency-reserve was deleted or never created. Re-provision: 'sudo systemctl start btrfs-emergency-reserve'.";
                })
                (mkHttpCheck {
                  name = "BTRFS Snapshot Canary";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "10m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*\nbtrfs_root_snapshots 0\n*)"
                    "[BODY] == pat(*\nbtrfs_root_snapshots *)"
                  ];
                  alerts = discordAlert "ZERO local btrbk snapshots in /mnt/btrfs-root/.snapshots — the incremental-send chain has no local anchor and the rollback window is GONE (2026-09-12 glob-delete incident class: 'sudo btrfs subvolume delete .snapshots/@.20260*' meant as 'du'). If you just deleted them manually: tonight's 23:00 btrbk-root run re-seeds with a full send (~1h QLC read). The rescue tier (.rescue) keeps a separate survivor. Check: ls /mnt/btrfs-root/.snapshots, journalctl -u btrbk-root.";
                })
                (mkHttpCheck {
                  name = "BTRFS Rescue Snapshots";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "10m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*\nbtrfs_rescue_snapshots 0\n*)"
                    "[BODY] == pat(*\nbtrfs_rescue_snapshots *)"
                    "[BODY] != pat(*\nbtrfs_rescue_append_only 0\n*)"
                    "[BODY] == pat(*\nbtrfs_rescue_append_only *)"
                  ];
                  alerts = discordAlert "Rescue snapshot tier broken — either no snapshots in /mnt/btrfs-root/.rescue or the chattr +a self-test FAILED (append-only no longer blocks subvolume delete; protection is location-only). This is the glob-delete survivor tier for .snapshots (2026-09-12 incident). Check: systemctl status btrfs-rescue-snapshot, ls -la /mnt/btrfs-root/.rescue, lsattr -d /mnt/btrfs-root/.rescue.";
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
                    "[BODY] == pat(*node_nvme_available_spare_percent*)"
                    "[BODY] == pat(*node_nvme_media_errors_total*)"
                  ];
                  alerts = discordAlert "NVMe SMART metrics not being collected — disk health unmonitored";
                })
                (mkHttpCheck {
                  name = "NVMe Collector Key Integrity";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*node_nvme_collector_keys_missing{device=\"nvme0n1\"} 0*)"
                  ];
                  alerts = discordAlert "nvme-metrics collector is missing smart-log JSON keys (nvme-cli key rename?). Affected metrics are omitted, not zeroed — but every alert depending on them has gone blind. The 2026-08 phantom-zero bug hid exactly this way for weeks. Check: journalctl -u nvme-metrics -n 20 (logs the available keys)";
                })
                (mkHttpCheck {
                  name = "NVMe Endurance Warning";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "1h";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*node_nvme_endurance_warning{device=\"nvme0n1\"} 0*)"
                  ];
                  alerts = discordAlert "NVMe SSD endurance exceeds 50% — plan for drive replacement. Check: nvme smart-log /dev/nvme0n1";
                })
                (mkHttpCheck {
                  name = "Niri Compositor";
                  group = "Monitoring";
                  # 2026-08-24 SDDM hard-down false-negative fix: this check
                  # was a bare presence pat (pat(*niri_running*)) and stayed
                  # GREEN through the whole incident — a presence pat cannot
                  # fail while the textfile exists, whatever the compositor
                  # does. Fail-closed on two layers now: (1) the metric must
                  # appear in VALUE form (line-anchored — also rejects the
                  # value-less-line class that gets whole textfiles dropped),
                  # (2) the collector must be FRESH (system_niri_metrics_fresh,
                  # system-health's mtime composite) — node_exporter serves a
                  # frozen textfile forever, so without (2) a dead collector
                  # leaves every niri check green (memory-guard 2026-09-15
                  # phantom-green class).
                  # Compositor DOWNTIME alerts via "Niri Desktop Died"
                  # (session-aware): niri_running 0 is legitimate when
                  # headless — do NOT assert niri_running 1 here.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nniri_running *)"
                  ]
                  ++ lib.optionals (config.services.system-health.enable or false) [
                    "[BODY] != pat(*system_niri_metrics_fresh 0\n*)"
                    "[BODY] == pat(*\nsystem_niri_metrics_fresh *)"
                  ];
                  alerts = discordAlert "niri-health-metrics is FROZEN or its textfile broke — compositor observability is DOWN and every other Niri check is blind (node_exporter serves the last content forever). Check: systemctl status niri-health-metrics.timer niri-health-metrics; journalctl -u niri-health-metrics -n 30; ls -la /var/lib/prometheus-node-exporter/textfile_collectors/niri.prom";
                })
                (mkHttpCheck {
                  name = "Niri Graphical Session";
                  group = "Monitoring";
                  # Debug visibility for the loginctl session detector. Was a
                  # bare presence pat — value-blind through the 2026-08-24
                  # SDDM hard-down. Line-anchored VALUE form now: fails when
                  # the line degrades to a comment or a value-less emission.
                  # No alert by design — 0 is legitimate when headless; the
                  # desktop-died check owns the session-without-compositor
                  # condition.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nniri_graphical_session *)"
                  ];
                })
                (mkHttpCheck {
                  name = "Niri Desktop Died";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*niri_desktop_died 0*)"
                  ];
                  alerts = discordAlert "Niri compositor crashed while a graphical session is active — desktop is unresponsive. Check: systemctl --user status niri.service";
                })
                (mkHttpCheck {
                  name = "Niri Crash Loop";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*niri_crash_loop 0*)"
                  ];
                  alerts = discordAlert "Niri compositor is crash-looping (3+ restarts in 10 min). Check niri journal: journalctl --user -u niri.service -n 50";
                })
                (mkHttpCheck {
                  name = "Niri Zombie Session";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*niri_zombie 0*)"
                  ];
                  alerts = discordAlert "Niri is running with NO graphical session (headless zombie) — it will block the next SDDM login with 'A niri session is already running' (2026-08-18 black-screen class). Recover: reboot, or as the user: systemctl --user stop niri.service niri-session-manager.service. Root cause: something pulled graphical-session.target into the user-manager boot transaction — the session-boot-audit eval guard should have caught it at eval time.";
                })
                (mkHttpCheck {
                  name = "AW Watcher Attached";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*niri_aw_watcher_late 0*)"
                  ];
                  alerts = discordAlert "aw-watcher-window-wayland has NOT attached 10+ min into an active graphical session — window activity tracking is silently dead (2026-09-02 live case: panicked exit 101 ×3 into start-limit-hit with zero alerting). Check: journalctl --user -u activitywatch-watcher-aw-watcher-window-wayland -n 30; recover: systemctl --user reset-failed activitywatch-watcher-aw-watcher-window-wayland && systemctl --user start activitywatch-watcher-aw-watcher-window-wayland";
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
                  name = "I/O Stall Rate";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "1m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*node_psi_io_alert 0*)"
                  ];
                  alerts = discordAlert "I/O pressure CRITICAL — PSI I/O stall high AND disk %util corroborates (crash3 phantom-filtered: idle-disk PSI = D-state corpse pile, covered by the Stuck D-State check, not this one). Check: nvme smart-log, fstrim status, btrfs filesystem usage.";
                })
              ]
              # Crush Daily / Dozzle / Overview checks moved to their owning
              # modules (services.integration.<name>.checks).
              ++ [
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
                (mkHttpCheck {
                  name = "Textfile Collector Health";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nnode_textfile_scrape_error 0\n*)"
                  ];
                  alerts = discordAlert "node_exporter textfile collector has parse errors — ALL textfile metrics (system_health, psi, nvme, btrfs, niri) are being silently dropped. Check each .prom file in /var/lib/prometheus-node-exporter/textfile_collectors/ for invalid syntax (e.g. [not set] poison values, bare lines). This is a meta-check: when it fires, 14+ Gatus checks go permanently RED because their underlying metrics vanish.";
                })
              ]
              ++ map mkWebsiteCheck ossWebsites
              # Registry fan-out (services.integration.<name>.checks) — inside
              # the withPapIngest pass so registry endpoints get the
              # PapDashboard ingest alert appended like every built-in one.
              ++ cfg.extraEndpoints
            );
          };
        };

        systemd.services.gatus =
          let
            oidcGate = mkOidcGate {
              inherit pkgs domain;
              serviceName = "gatus";
              includeProvision = true;
            };
          in
          {
            inherit onFailure;
            after = [
              "network-online.target"
              "dnsblockd.service"
            ]
            ++ lib.optionals enableOidc oidcGate.after;
            wants = [
              "network-online.target"
              "dnsblockd.service"
            ]
            ++ lib.optionals enableOidc oidcGate.wants;
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
                ]
                ++ lib.optionals enableOidc oidcGate.serviceConfig.ExecStartPre;
                # Must exceed the 300s OIDC gate budget (slow-boot dnsblockd)
                TimeoutStartSec = "6min";
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

        # Service-integration registry entry: the status vHost (Layer 1 — native
        # OIDC via the security.oidc block above; forward-auth would
        # double-auth), unit-state monitoring, the OIDC client
        # registration, and the dashboard homepage tile. The gatus
        # self-check and the Textfile Collector Health meta-check stay
        # in the core endpoint list below.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          gatus = {
            enable = cfg.enable;
            subdomain = "status";
            port = cfg.port;
            vHost.layer = "plain";
            monitored = true;
            oidc = {
              # Callback path is fixed upstream at /authorization-code/callback.
              name = "Gatus";
              clientId = "gatus";
              launchURL = "https://status.${domain}";
              callbackURLs = [ "https://status.${domain}/authorization-code/callback" ];
            };
            homepage = {
              name = "Gatus";
              group = "Monitoring";
              description = "Uptime & Health Check Dashboard";
              icon = "gatus.png";
            };
          };
        };
      };
    };
}
