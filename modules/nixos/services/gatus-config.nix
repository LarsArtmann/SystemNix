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
                  name = "Forgejo Mirror Sync";
                  group = "Development";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_forgejo_mirror_scrape_errors 0*)"
                    "[BODY] == pat(*system_forgejo_mirror_sync_stalled 0*)"
                    "[BODY] == pat(*system_forgejo_mirror_erroring 0*)"
                  ];
                  alerts = discordAlert "Forgejo pull-mirror syncing broken. stalled=1: freshest mirror sync >10h old — dead queue (restart forgejo.service; the unique queue wedges after a hard freeze, cron pushes then dedup-skip silently). erroring=1: syncs actively failing — journalctl -u forgejo --grep SyncMirrors (credential-helper ENOENT / DNS allowlist rejects). scrape_errors=1: forgejo sqlite unreadable.";
                })
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
                  name = "BTRFS Scrub Health";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "10m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*btrfs_scrub_status*)"
                    "[BODY] != pat(*btrfs_scrub_error_free 0\n*)"
                    "[BODY] == pat(*\nbtrfs_scrub_error_free *)"
                  ];
                  alerts = discordAlert "BTRFS scrub found errors — potential data corruption. Run 'btrfs scrub status /' and 'btrfs scrub status /data' to investigate. Check Prometheus btrfs_scrub_errors_total for details.";
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
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*niri_running*)"
                  ];
                })
                (mkHttpCheck {
                  name = "Niri Graphical Session";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*niri_graphical_session*)"
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
                  name = "Nix Daemon";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "1m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_active{service=\"nix-daemon\"} 1*)"
                    "[BODY] == pat(*system_service_start_limit_hit{service=\"nix-daemon\"} 0*)"
                  ];
                  alerts = discordAlert "Nix daemon down or in start-limit crash-loop — ALL nix operations fail with 'Connection refused'. Likely killed by systemd-oomd during a build. Fix: sudo systemctl reset-failed nix-daemon && sudo systemctl start nix-daemon";
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
                  name = "PMA CPU Death-Loop";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_cpu_over_threshold{service=\"projects-management-automation\"} 0*)"
                  ];
                  alerts = discordAlert "PMA CPU exceeds 150% sustained — likely a commit death-loop. The service is technically 'active' but burning CPU. Check: journalctl -u projects-management-automation -n 50. Consider: sudo systemctl restart projects-management-automation";
                })
                (mkHttpCheck {
                  name = "PMA Memory Pressure";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_memory_over_threshold{service=\"projects-management-automation\"} 0*)"
                  ];
                  alerts = discordAlert "PMA cgroup memory exceeds 90% of its MemoryMax (16G) — a legitimate repo-discovery scan rides MemoryHigh=12G, so this alert means the hard OOM-kill ceiling is in reach. Check: systemctl status projects-management-automation and system_service_memory_bytes in the textfile collector. Full narrative: docs/crash-analysis-2026-08-09.md";
                })
                (mkHttpCheck {
                  name = "PMA Commit Health";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  # Anchored forms (real \n): value must sit at line start —
                  # collector down or section disabled = metric absent = the
                  # check fails fail-closed. Catches BOTH directions of the
                  # 2026-08-22..09-02 blackout class: sustained commit
                  # failures (dead provider, nothing landing) and sustained
                  # heuristic fallbacks (work landing with degraded messages
                  # because the whole AI provider chain is down).
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nsystem_pma_commit_scrape_errors 0\n*)"
                    "[BODY] == pat(*\nsystem_pma_commit_failures_over_threshold 0\n*)"
                    "[BODY] == pat(*\nsystem_pma_commit_fallbacks_over_threshold 0\n*)"
                  ];
                  alerts = discordAlert "PMA commits are failing or riding heuristic fallbacks — the auto-commit pipeline is degraded (2026-08-22..09-02: 11 days, ~3,800 failed commits on a dead AI provider, invisible to liveness). Failures: journalctl -u projects-management-automation --since -1h --grep 'commit failed'. Fallbacks: same with 'heuristic fallback'. Check the provider chain (FastFlowLM :52625 socket, minimax/zai keys) before it becomes a backlog.";
                })
                (mkHttpCheck {
                  name = "FastFlowLM NPU LLM";
                  group = "Monitoring";
                  # MUST NOT probe :52625 — every probe is a TCP connection =
                  # permanent keepalive. Use the system-health metrics at
                  # :9100 instead. Idle is healthy (model unloaded); only
                  # failure + crash-loop alert.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_state_failed{service=\"fastflowlm\"} 0*)"
                    "[BODY] == pat(*system_service_start_limit_hit{service=\"fastflowlm\"} 0*)"
                  ];
                  alerts = discordAlert "FastFlowLM NPU LLM failed or in start-limit crash-loop — local commit-message generation unavailable. Check: journalctl -u fastflowlm -n 50, /dev/accel0 presence, /data/ai/models/fastflowlm contents";
                })
                (mkHttpCheck {
                  name = "FastFlowLM Memory Pressure";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_memory_over_threshold{service=\"fastflowlm\"} 0*)"
                  ];
                  alerts = discordAlert "FastFlowLM cgroup memory exceeds 90% of its MemoryMax (40G) — the 21.6 GB model mmap'd from /data plus KV cache is reaching the OOM-kill ceiling. Check: flm-loaded models, /data/ai/models/fastflowlm size, pma discovery worker count";
                })
              ]
              ++
                lib.optionals
                  (
                    (config.services.system-health.enable or false)
                    && (config.services.system-health.lanInterface or "") != ""
                  )
                  [
                    (mkHttpCheck {
                      name = "LAN NIC Present";
                      group = "Monitoring";
                      # 2026-08-22: after a hard crash the RTL8125 fell off the
                      # PCIe bus — PCI enumeration showed no 10ec:8125 at all,
                      # r8125 had nothing to probe, eno1 never got its static IP
                      # and SSH was dead until a second reboot. The metric is
                      # emitted by system-health whenever lanInterface is set, and
                      # this check is gated on the SAME condition — a host that
                      # watches no LAN NIC gets neither metric nor check (no
                      # phantom 1). If this fires, a warm
                      # reboot is NOT reliable — power-cycle the machine.
                      url = "http://localhost:${toString nodePort}/metrics";
                      interval = "2m";
                      conditions = [
                        "[STATUS] == 200"
                        # pat() is a GLOB over the whole /metrics body and '!' is a LITERAL in
                        # filepath.Match (no negation syntax): the metric's HELP comment
                        # ("# HELP system_lan_nic_present 1 if ...") itself contains
                        # "system_lan_nic_present 1", so pat(*metric 1*) stays green when the
                        # value is 0. Assert the 0-value line is absent + the metric is present.
                        "[BODY] != pat(*system_lan_nic_present 0\n*)"
                        "[BODY] == pat(*\nsystem_lan_nic_present *)"
                      ];
                      alerts = discordAlert "LAN NIC (eno1 / RTL8125) is ABSENT from the bus — wired networking is DOWN (static IP + SSH unreachable). A warm reboot does NOT retrain it: POWER-CYCLE the machine (shut down, wait 10s, power on). Check: ls /sys/class/net/eno1, journalctl -k -b -1 | grep 10ec:8125, lspci | grep -i network";
                    })
                  ]
              ++
                lib.optionals
                  (
                    (config.services.system-health.enable or false)
                    && (config.services.system-health.dasUsbPath or "") != ""
                  )
                  [
                    (mkHttpCheck {
                      name = "DAS USB Link";
                      group = "Monitoring";
                      # Root-cause alert for the single-USB-link DAS topology:
                      # all 4 external disks (2x pool Toshiba, buildcache SSD,
                      # spare btrfs SSD) sit behind /sys/bus/usb/devices/8-1.
                      # When the link drops, buildcache + pool + SSD checks all
                      # fire at once — this check names the CAUSE (2026-08-22:
                      # zero reconnect attempts for 22+ min). Anchored form is
                      # mandatory: the metric's HELP embeds "system_das_link_present 1".
                      url = "http://localhost:${toString nodePort}/metrics";
                      interval = "2m";
                      conditions = [
                        "[STATUS] == 200"
                        "[BODY] != pat(*system_das_link_present 0\n*)"
                        "[BODY] == pat(*\nsystem_das_link_present *)"
                      ];
                      alerts = discordAlert "DAS USB link (8-1) is DOWN — ALL external disks (pool members, buildcache, spare SSDs) vanished simultaneously. Software recovery is impossible without the link: physically reseat the DAS USB cable + enclosure power, then REBOOT (warm reboot may not re-enumerate). After boot: scripts/das-link-recovery-check.sh, verify findmnt /mnt/pool and /mnt/buildcache, e2fsck decision for buildcache. Runbook: AGENTS.md 'DAS USB link' section.";
                    })
                  ]
              ++ lib.optionals (config.services.system-health.enable or false) [
                (mkHttpCheck {
                  name = "System Profile Anchor";
                  group = "Monitoring";
                  # Manual activations (switch-to-configuration outside
                  # `nix run .#deploy` — banned; 2026-08-18 google-sync
                  # crash-loop, 2026-08-22 hand-activated XFS migration) leave
                  # /run/current-system anchored to NO numbered profile: a
                  # reboot silently reverts to the last real generation and
                  # nothing warns. 0 = revert-on-reboot risk. Emitted
                  # unconditionally by system-health (fail-closed) and the
                  # anchored form is mandatory: the HELP embeds
                  # "system_current_system_profiled 1".
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*system_current_system_profiled 0\n*)"
                    "[BODY] == pat(*\nsystem_current_system_profiled *)"
                  ];
                  alerts = discordAlert "The RUNNING system is not anchored to any numbered nix profile generation — it was activated manually (banned pattern; deploy.sh post-switch steps and the profile/boot-entry trail are missing). A REBOOT WILL REVERT the machine to the last real generation. Fix: run `nix run .#deploy` NOW to persist the current config. Check: readlink /run/current-system vs ls /nix/var/nix/profiles/";
                })
                (mkHttpCheck {
                  name = "Boot Generation Freshness";
                  group = "Monitoring";
                  # The 2026-09-07 stuck-boot class: parallel deploys advanced
                  # the loader DEFAULT past the store the machine boots from;
                  # a reboot then hangs pre-journal. Also the exit-4 class:
                  # activation advances /run/current-system but skips the
                  # profile bump, and a reboot silently reverts. deploy.sh's
                  # anchoring print cannot cover the reboot-into-stale case —
                  # only a runtime metric can. 0 = booted != newest profile.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*system_booted_is_newest_profile 0\n*)"
                    "[BODY] == pat(*\nsystem_booted_is_newest_profile *)"
                  ];
                  alerts = discordAlert "The BOOTED system does not match the newest numbered nix profile generation — a reboot would boot a DIFFERENT (possibly store-dead) toplevel (2026-09-07 stuck-boot class) or silently revert. Check: `readlink -f /run/booted-system` vs `readlink -f /nix/var/nix/profiles/system`, run `nix run .#deploy` to re-anchor, and `nix run .#pre-reboot-check` BEFORE any reboot.";
                })
                (mkHttpCheck {
                  name = "Memory Emergency Guard";
                  group = "Monitoring";
                  # The 2026-08-22 freezes: #1 (00:27) zram 100% full made
                  # flm's 25 GB model unevictable; #2 (05:49) the guard tripped
                  # 7x but flm's activation socket re-woke it via the
                  # alert→enricher feedback loop, and the final refault-thrash
                  # freeze (PSI some avg10 >50%, MemAvailable still >=10%) fell
                  # between the guard's thresholds AND between its 60 s ticks.
                  # The guard now ALSO stops fastflowlm.socket on trip (restores
                  # it once memory recovers), trips on PSI>=40% AND zram>=80%,
                  # and ticks every 30 s. This check alerts when the guard
                  # FIRED (within the last 30 min) or died (absent metrics).
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*memory_emergency_guard_avail_percent*)"
                    "[BODY] == pat(*memory_emergency_guard_last_trip_recent 0*)"
                  ];
                  alerts = discordAlert "Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, PSI refault thrash, episodic memory stall, or sustained I/O stall with disk-busy corroboration) and FastFlowLM + its activation socket + the resumable I/O churn units (btrbk/balance/scrub) were force-stopped. The socket auto-restores once memory recovers; until then LLM clients get connection-refused by design. Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10,io_psi_some_avg60}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)";
                })
                (mkHttpCheck {
                  name = "Memory Pressure Warning";
                  group = "Monitoring";
                  # The WARNING tier (2026-08-22): the CRITICAL check fired
                  # 17s before the 05:49 freeze and 43min before the 00:27
                  # one. some avg60 >= 20% = the storm FORMING — time to
                  # look, shed load, or cancel heavy jobs while the machine
                  # still responds. Alert-only by user decision: NO
                  # automated action beyond the existing guard.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "1m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*node_psi_memory_warning 1\n*)"
                    "[BODY] == pat(*\nnode_psi_memory_warning *)"
                  ];
                  alerts = discordAlert "Sustained memory pressure WARNING — PSI some avg60 >= 20% for a full minute. The storm is forming (2026-08-22 freeze precursor profile). No action taken yet (alert-only by design). Check: heavy nix builds / VM tests / crush sessions running? node_psi_memory_some_avg60, system_cgroup_mem_bytes{...} top consumers. Consider stopping heavy jobs while the machine still responds.";
                })
                (mkHttpCheck {
                  name = "Crush Session Pressure";
                  group = "Monitoring";
                  # Admission-control monitor (2026-08-22 census: ~12
                  # concurrent sessions were a major freeze contributor;
                  # user decision: monitor-only). Anchored form mandatory —
                  # the HELP text embeds the threshold semantics.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*system_crush_sessions_over_threshold 1\n*)"
                    "[BODY] == pat(*\nsystem_crush_sessions_over_threshold *)"
                  ];
                  alerts = discordAlert "Crush agent session pressure: more than 6 concurrent crush sessions detected (2026-08-22 freeze census ran ~12 = 52 crush + 50 bun processes as a major memory consumer). Monitor-only by decision — consider closing idle sessions (`crush` TUIs left open), or wrap heavy work in heavy-job.";
                })
                (mkHttpCheck {
                  name = "SEV1 Escalation Bridge";
                  group = "Monitoring";
                  # The local escalation path (fullscreen overlay + DMS
                  # notification) for guard-trip/guard-dead/infra-criticals.
                  # This check guards the GUARD of the human loop: if the
                  # bridge dies, criticals still reach Discord (gatus) but
                  # the desktop overlay/notification path is dead. The
                  # overlay self-expires after 2 min without bridge
                  # refreshes, so a dead bridge cannot stick an overlay.
                  # Tiered since 2026-08-31 (hardened 2026-09-02: NO memory
                  # condition may overlay; page is RESERVED with no current
                  # emitter): warn-tier conditions (infra hardware
                  # criticals) show a static yellow banner ONCE and fire
                  # this Discord alert; notify-tier (memory/meta) fire the
                  # alert only. sev1_bridge_page_alerts_active distinguishes
                  # tiers at the metrics level.
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nsev1_bridge_runs_total *)"
                    "[BODY] != pat(*sev1_bridge_alerts_active [1-9]\n*)"
                  ];
                  alerts = discordAlert "SEV1 escalation bridge problem: either the bridge died (desktop escalation for criticals is DOWN — Discord still works) or SEV1 conditions are ACTIVE. Warn-tier (infra hardware criticals: DAS link, LAN NIC, btrfs critical) = a static yellow banner shows ONCE on the desktop + this Discord alert. Notify-tier (ALL memory conditions, SYSTEM MONITORING STALE, zram critical) = notification + this Discord alert only, NO overlay BY DESIGN (2026-09-02: high memory must never flash the screen). Check: journalctl -u sev1-bridge -n 30, cat /run/systemnix/sev1/alert (line 4 = severity).";
                })
                (mkHttpCheck {
                  name = "Hermes Agent Gateway";
                  group = "Monitoring";
                  # No HTTP probe: the gateway's only listener is Discord/
                  # platform webhooks, not a health endpoint. Unit-state
                  # metrics from system-health are the liveness signal
                  # (fail-closed: absent metrics fail the pat()s).
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_state_failed{service=\"hermes\"} 0*)"
                    "[BODY] == pat(*system_service_start_limit_hit{service=\"hermes\"} 0*)"
                  ];
                  alerts = discordAlert "Hermes agent gateway failed or in start-limit crash-loop — Discord bot and AI gateway are DOWN. Check: journalctl -u hermes -n 50 (ExecStartPre perms/migration, upstream connectivity, config errors)";
                })
                (mkHttpCheck {
                  name = "Hermes Memory Pressure";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_service_memory_over_threshold{service=\"hermes\"} 0*)"
                  ];
                  alerts = discordAlert "Hermes cgroup memory exceeds 90% of its MemoryMax (24G) — PyTorch/ROCm mappings plus active agent sessions are reaching the OOM-kill ceiling. Check: journalctl -u hermes -n 50, active sessions, /home/hermes growth";
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
                  alerts = discordAlert "GPUActive exceeds 60G — GTT buffer objects consuming excessive RAM. Check /proc/meminfo GPUActive. Risk of OOM cascade on Strix Halo (GTT-first: with the 512 MiB carveout ALL GPU memory is shared system RAM).";
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
                  name = "CPU Runaway (Any Service)";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_any_service_cpu_over_threshold 0*)"
                  ];
                  alerts = discordAlert "A monitored service exceeds 150% average CPU — possible busy-loop or runaway. Check: curl localhost:9100/metrics | grep cpu_over_threshold | grep ' 1$'";
                })
                (mkHttpCheck {
                  name = "/tmp TmpFS Usage";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_tmpfs_tmp_over_threshold 0*)"
                  ];
                  alerts = discordAlert "/tmp tmpfs exceeds 80% (~38 GiB of 48 GiB cap) — runaway build or temp file accumulation. Check: du -sh /tmp/* | sort -rh | head";
                })
                (mkHttpCheck {
                  name = "DNS Blocker Stats API Fresh";
                  group = "Infrastructure";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  # Anchored forms: the \n MUST reach gatus as a real newline
                  # (single-backslash in this double-quoted nix string) —
                  # presence-of-1 at line start + not-0 keep the check
                  # fail-closed through probe absence (collector down =
                  # metric absent = both conditions fail = alert fires).
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*system_dnsblockd_metrics_fresh 0\n*)"
                    "[BODY] == pat(*\nsystem_dnsblockd_metrics_fresh 1*)"
                  ];
                  alerts = discordAlert "dnsblockd :9090 stats API is wedged or unreachable while the DNS resolver may still be healthy (2026-08-27 class). Recovery runbook: sudo systemctl restart dnsblockd — for a goroutine dump FIRST, see scripts/dnsblockd-goroutine-dump.sh (root).";
                })
                (mkHttpCheck {
                  name = "Local DNS System Resolver";
                  group = "Infrastructure";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  # Anchored forms: the \n MUST reach gatus as a real newline
                  # (single-backslash in this double-quoted nix string) —
                  # presence-of-1 at line start + not-0 keep the check
                  # fail-closed through probe absence (collector down =
                  # metric absent = both conditions fail = alert fires).
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*system_local_dns_resolves 0\n*)"
                    "[BODY] == pat(*\nsystem_local_dns_resolves 1*)"
                  ];
                  alerts = discordAlert "System resolver cannot resolve *.home.lan — /etc/resolv.conf drifted off 127.0.0.1 (dnsblockd bypassed) while the direct :53 probe stays green (2026-09-02 class: manual resolv.conf edit to 1.1.1.1 during a NIC outage killed local DNS for ~10h and blocked deploys). Fix: restore 'nameserver 127.0.0.1' first in /etc/resolv.conf (a deploy rewrites it via environment.etc), then find what wrote the file.";
                })
                (mkHttpCheck {
                  name = "fstrim Duration";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "30m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_fstrim_duration_over_threshold 0*)"
                  ];
                  alerts = discordAlert "fstrim took >30 min — possible SLC cache churn backlog or I/O contention. Check: journalctl -u fstrim -n 20, btrfs filesystem usage /";
                })
                (mkHttpCheck {
                  name = "Gatus Sustained Failures";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_gatus_meta_scrape_errors 0*)"
                    "[BODY] == pat(*system_gatus_endpoints_in_error_long 0*)"
                    "[BODY] == pat(*system_gatus_results_stale 0*)"
                  ];
                  alerts = discordAlert "Gatus self-check failed: either endpoints have sustained failures (zero successes in retention), the result DB is stale (>15 min no writes = gatus wedged), or the meta-scrape itself errored (DB unreadable). Check: Gatus dashboard, journalctl -u gatus, /var/lib/private/gatus/gatus.db mtime.";
                })
                (mkHttpCheck {
                  name = "Memory Events Thrash";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_memory_events_any_high 0*)"
                  ];
                  alerts = discordAlert "A monitored service is thrashing against its MemoryMax ceiling (memory.events max > 100). Page-cache death-loop pattern (OOM-killer won't fire — page cache is reclaimable). Check: grep system_service_memory_events_high in /var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom to identify which service.";
                })
                (mkHttpCheck {
                  name = "Root Disk Usage";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_disk_usage_over_threshold 0*)"
                  ];
                  alerts = discordAlert "Root filesystem exceeds 85% usage — chronic disk fill issue. Check: du -sh /nix/store/* | sort -rh | head, nix-collect-garbage --delete-older-than 7d, btrfs filesystem usage /";
                })
                (mkHttpCheck {
                  name = "Service Crash Loop";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_any_service_crash_loop 0*)"
                  ];
                  alerts = discordAlert "A monitored service is crash-looping (3+ restarts in 2 min). Check: curl localhost:9100/metrics | grep system_service_crash_loop | grep ' 1$'. Run: sudo systemctl reset-failed <svc> && sudo systemctl start <svc>";
                })
                (mkHttpCheck {
                  name = "Service Restart Churn";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_any_service_restart_churn 0*)"
                  ];
                  alerts = discordAlert "A monitored service accumulated 5+ automatic restarts since its last explicit start — a slow crash-churn that never trips the 3-in-2min loop detector (e.g. hermes exit-75 drain chains). Check: curl localhost:9100/metrics | grep system_service_restart_churn | grep ' 1$', then journalctl -u <svc> -n 50";
                })
                (mkHttpCheck {
                  name = "OOMD Kills";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_oomd_kills_alert 0*)"
                    "[BODY] == pat(*system_oomd_kills_scrape_errors 0*)"
                  ];
                  alerts = discordAlert "systemd-oomd killed a process since last check (memory pressure OOM; check: journalctl -u systemd-oomd --grep 'Killed' -n 20 — the killed service may be in start-limit-hit state), OR the bounded oomd journal scan timed out (system_oomd_kills_scrape_errors=1; check: systemctl status system-health-metrics)";
                })
                (mkHttpCheck {
                  name = "Docker Container Restarts";
                  group = "Monitoring";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*system_any_docker_container_restart_alert 0*)"
                  ];
                  alerts = discordAlert "A Docker container is rapidly restarting (3+ restarts in 2 min). Check: docker ps -a, docker inspect --format '{{.RestartCount}}' <container>. Likely OOM-killed by systemd-oomd (exit code 137).";
                })
              ]
              ++
                lib.optionals
                  (
                    (config.services.system-health.enable or false)
                    && config.services.system-health.monitoredUserManagers != [ ]
                  )
                  [
                    (mkHttpCheck {
                      name = "User Unit Failures";
                      group = "Monitoring";
                      url = "http://localhost:${toString nodePort}/metrics";
                      interval = "2m";
                      conditions = [
                        "[STATUS] == 200"
                        "[BODY] == pat(*\nsystem_user_units_failed{*)"
                        "[BODY] != pat(*\nsystem_user_units_failed{*} [1-9]*)"
                        "[BODY] != pat(*\nsystem_user_units_scrape_errors{*} 1*)"
                      ];
                      alerts = discordAlert "A systemd USER unit is in failed state (2026-08-31: smart-audio sat dead in start-limit-hit the whole boot with nothing alerting), OR the user-manager query is wedged (scrape_errors=1). Check: systemctl --machine=lars@.host --user --failed --no-legend, then journalctl --user -u <unit> -n 50";
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
              ++ lib.optionals (config.services.backup-coordination.enable or false) [
                (mkHttpCheck {
                  name = "All Backups Healthy";
                  group = "Infrastructure";
                  url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                  interval = "5m";
                  client.timeout = "10s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*backup_all_healthy 0\n*)"
                    "[BODY] == pat(*\nbackup_all_healthy *)"
                  ];
                  alerts = discordAlert "One or more service backups are stale (>25h)";
                })
              ]
              ++ lib.optionals (config.services.pocket-id-config.enable or false) [
                (mkHttpCheck {
                  name = "Secret Rotation Health";
                  group = "Infrastructure";
                  url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                  interval = "1h";
                  client.timeout = "10s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] != pat(*secret_rotation_all_fresh 0\n*)"
                    "[BODY] == pat(*\nsecret_rotation_all_fresh *)"
                  ];
                  alerts = discordAlert "One or more OIDC client secrets are stale (>90d) — consider rotating";
                })
                # Pocket ID is the ONLY login path for the SSO-only surface
                # (paperless since 2026-09-02 has no second login) plus every
                # other Layer-1 app — its SQLite locking up under memory/IO
                # pressure is a homelab-wide auth SPOF event. 2026-08-22: a
                # fatal locked chain crashed the health check and lost a
                # client row; 2026-09-02: 30 "database is locked" events/24h
                # while logins still worked (degraded, not dead). Anchored
                # patterns (real \n): scan failure = scrape_errors 1 = the
                # other two conditions fail-closed red.
                (mkHttpCheck {
                  name = "Pocket ID SQLite Health";
                  group = "Infrastructure";
                  url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                  interval = "5m";
                  client.timeout = "10s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nsystem_pocket_id_busy_scrape_errors 0\n*)"
                    "[BODY] == pat(*\nsystem_pocket_id_busy_over_threshold 0\n*)"
                  ];
                  alerts = discordAlert "Pocket ID SQLite is locking up (SQLITE_BUSY storm or collector scan failed) — paperless SSO, forgejo/gatus/immich logins and every oauth2-proxy vHost are at risk. Check: journalctl -u pocket-id --since -24h --grep 'database is locked'. Collateral of memory/IO pressure (zram-full evenings); resolves when pressure drains.";
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
      };
    };
}
