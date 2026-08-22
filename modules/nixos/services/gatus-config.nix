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

      # NOTE: the YAML field is `description` (gatus alert.Alert yaml tag).
      # The old `inherit desc` emitted `desc:`, which yaml.v3 silently ignores —
      # descriptions never reached Discord messages.
      discordAlert = desc: [
        {
          type = "discord";
          description = desc;
        }
      ];

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
      ossWebsites = [
        "lars.software"
        "www.lars.software"
        "status.lars.software" # Better Stack status page (CNAME → statuspage.betteruptime.com)
        "gogenfilter.lars.software"
        "gogenfilter.larsartmann.com" # alias CNAME from larsartmann.com.tf
        "atomicwrite.lars.software"
        "go-atomic-write.lars.software" # alias of atomicwrite.lars.software
        "go-output.lars.software"
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
        "cmdguard.lars.software"
        "md-go-validator.lars.software"
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
                  url = "http://127.0.0.1:8123/ping";
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
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                    # Functional, not just liveness: the real sign-in page
                    # (not an error/redirect shell) says "Paperless-ngx sign in".
                    "[BODY] == pat(*Paperless-ngx sign in*)"
                  ];
                  alerts = discordAlert "Paperless down — document management unavailable";
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
              ++ lib.optionals (config.services.llama-rag.enable or false) [
                (mkHttpCheck {
                  name = "llama.cpp Embeddings";
                  group = "AI";
                  url = "http://localhost:${toString config.services.llama-rag.embeddingsPort}/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alerts = discordAlert "llama.cpp embeddings server down — RAG indexing and semantic search unavailable";
                })
                (mkHttpCheck {
                  name = "llama.cpp Reranker";
                  group = "AI";
                  url = "http://localhost:${toString config.services.llama-rag.rerankerPort}/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alerts = discordAlert "llama.cpp reranker down — RAG reranking unavailable, search quality degraded";
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
              ++ lib.optionals (config.services.attic-config.enable or false) [
                (mkHttpCheck {
                  name = "Attic Binary Cache";
                  group = "Infrastructure";
                  url = "http://localhost:${toString ports.attic}/";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alerts = discordAlert "Attic binary cache down — CI builds will not push/pull cached paths, causing redundant recompilation";
                })
                (mkHttpCheck {
                  name = "Attic Storage Size";
                  group = "Infrastructure";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*attic_storage_over_threshold 0*)"
                  ];
                  alerts = discordAlert "Attic storage exceeded maxStorageGigabytes — emergency GC triggered. Check /mnt/pool/services/atticd/storage size.";
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
                    # Match "connected (N devices)" where N >= 1. The [1-9] character
                    # class ensures at least one digit from 1-9 (excludes 0 devices).
                    # NOTE: Gatus pat() uses glob, NOT regex — do NOT prefix with ?
                    # (glob ? = single-char wildcard, which would consume the digit).
                    "[BODY] == pat(*connected ([1-9]* devices)*)"
                  ];
                  alerts = discordAlert "Monitor365 agent not connected to server — API key desync or agent crash";
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
                  # backlog gauge and the consecutive-failures gauge exist.
                  # NOTE: cloud_sync_consecutive_failures is always emitted (set
                  # on every sync cycle: 0 on success, incremented on failure).
                  # The previous condition used cloud_sync_upload_rejected_events_total
                  # which is only emitted when rejections > 0, so it's ABSENT when
                  # the agent has zero rejections — a permanent false negative.
                  # This check catches the agent STOPPING sync entirely (circuit
                  # breaker stuck open, crash loop, auth failure). For VALUE-based
                  # alerting (backlog > N threshold), wire Prometheus/SigNoz
                  # to scrape this endpoint and add an alert rule there.
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*cloud_sync_upload_backlog_size*)"
                    "[BODY] == pat(*cloud_sync_consecutive_failures*)"
                  ];
                  alerts = discordAlert "Monitor365 cloud sync subsystem not emitting metrics — agent may have stopped syncing (circuit breaker open, auth failure, or crash loop). Check: journalctl -u monitor365 -n 50";
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
                  alerts = discordAlert "I/O pressure CRITICAL — PSI I/O stall >10% over 5min. SLC cache exhaustion or sustained I/O starvation. Check: nvme smart-log, fstrim status, btrfs filesystem usage.";
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
                (mkHttpCheck {
                  name = "LAN NIC Present";
                  group = "Monitoring";
                  # 2026-08-22: after a hard crash the RTL8125 fell off the
                  # PCIe bus — PCI enumeration showed no 10ec:8125 at all,
                  # r8125 had nothing to probe, eno1 never got its static IP
                  # and SSH was dead until a second reboot. The metric is
                  # emitted unconditionally by system-health (fail-closed:
                  # absent metric fails the pat()). If this fires, a warm
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
                  alerts = discordAlert "Memory emergency guard TRIPPED (or the guard died): the machine entered a pre-freeze zone (low MemAvailable, near-full zram, or PSI refault thrash) and FastFlowLM + its activation socket were force-stopped. The socket auto-restores once memory recovers; until then LLM clients get connection-refused by design. Check: journalctl -u memory-emergency-guard -n 30, memory_emergency_guard_{avail,zram_fill,psi_some_avg10}_percent in the textfile collector, what is holding RAM (ps aux --sort=-%mem | head)";
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
                  alerts = discordAlert "GPUActive exceeds 60G — GTT buffer objects consuming excessive RAM. Check /proc/meminfo GPUActive. Risk of OOM cascade on Strix Halo (18 GiB VRAM carveout means more workloads spill to GTT).";
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
                  ];
                  alerts = discordAlert "systemd-oomd killed a process since last check — memory pressure triggered OOM. Check: journalctl -u systemd-oomd --grep 'Killed' -n 20. The killed service may be in start-limit-hit state.";
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
                    "[BODY] == pat(*node_textfile_scrape_error 0*)"
                  ];
                  alerts = discordAlert "node_exporter textfile collector has parse errors — ALL textfile metrics (system_health, psi, nvme, btrfs, niri) are being silently dropped. Check each .prom file in /var/lib/prometheus-node-exporter/textfile_collectors/ for invalid syntax (e.g. [not set] poison values, bare lines). This is a meta-check: when it fires, 14+ Gatus checks go permanently RED because their underlying metrics vanish.";
                })
              ]
              ++ lib.optionals (config.services.projects-management-automation.enable or false) [
                (mkHttpCheck {
                  name = "PMA Daemon Health";
                  group = "Monitoring";
                  url = "http://127.0.0.1:${toString ports.pma-health}/readyz";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alerts = discordAlert "PMA health endpoint reports not-ready — the auto-commit daemon or discovery daemon is failing. The process may be alive but non-functional. Check: journalctl -u projects-management-automation -n 50";
                })
              ]
              ++ lib.optionals (config.services.buildcache.enable or false) [
                (mkHttpCheck {
                  name = "Build Cache SSD";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # pat() is a GLOB: HELP comments contain "metric 1", so assert absence
                    # of the 0-value line plus presence of the metric instead ('!' is a
                    # literal in filepath.Match — no glob negation exists).
                    "[BODY] != pat(*buildcache_mounted 0\n*)"
                    "[BODY] == pat(*\nbuildcache_mounted *)"
                    "[BODY] != pat(*buildcache_smart_healthy 0\n*)"
                    "[BODY] == pat(*\nbuildcache_smart_healthy *)"
                  ];
                  alerts = discordAlert "Build cache SSD (/mnt/buildcache) unmounted or SMART-failing — go/cargo/pnpm builds will fail with missing-directory errors. Check: findmnt /mnt/buildcache, sudo smartctl -d sat -H /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311. If the drive died: revert GOCACHE/GOMODCACHE in platforms/nixos/users/home.nix and rebuild caches on NVMe.";
                })
                (mkHttpCheck {
                  name = "Build Cache Usage";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "30m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*buildcache_usage_over_threshold 0*)"
                  ];
                  alerts = discordAlert "Build cache SSD exceeds 85% — the 240 GB drive is filling. Prune: GOCACHE=/mnt/buildcache/go-build go clean -cache; cargo clean in monitor365; pnpm store prune; rm old Playwright browsers.";
                })
                (mkHttpCheck {
                  name = "Pool Mounted";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # HELP comment contains "pool_mounted 1" — absence-of-0 + presence.
                    "[BODY] != pat(*pool_mounted 0\n*)"
                    "[BODY] == pat(*\npool_mounted *)"
                  ];
                  alerts = discordAlert "Mirrored HDD pool (/mnt/pool) unmounted — immich + paperless data, ALL application backups, and the btrbk safety net are offline. Check: findmnt /mnt/pool, systemctl status mnt-pool.mount. If a DAS member died: the raid1 still serves from the other member; replace the drive and btrfs replace.";
                })
                (mkHttpCheck {
                  name = "Pool Usage";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "30m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*pool_usage_over_threshold 0*)"
                  ];
                  alerts = discordAlert "Mirrored HDD pool exceeds 85% — review /mnt/pool usage: backups retention (30d 12w targets, forgejo zips 7d), archive/forensic-snapshots growth.";
                })
              ]
              ++ lib.optionals config.services.signoz.enable [
                (mkHttpCheck {
                  name = "ClickHouse Data Mount";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # pat() is a GLOB (HELP comments contain "clickhouse_xfs_mounted 1"):
                    # assert absence of the 0-value line plus presence (buildcache pattern)
                    "[BODY] != pat(*clickhouse_xfs_mounted 0\n*)"
                    "[BODY] == pat(*\nclickhouse_xfs_mounted *)"
                    "[BODY] != pat(*clickhouse_xfs_is_xfs 0\n*)"
                    "[BODY] == pat(*\nclickhouse_xfs_is_xfs *)"
                  ];
                  alerts = discordAlert "ClickHouse XFS data mount (/var/lib/clickhouse) is unmounted, EIO-dead, or not XFS — clickhouse.service refuses to start by design (ConditionPathIsMountPoint, no telemetry written to the root fs). Observability ingestion is DOWN. Check: findmnt /var/lib/clickhouse, systemctl status var-lib-clickhouse.mount, dmesg | grep -i xfs. If the partition/fs is missing: scripts/migrate-clickhouse-xfs.sh (prepare phase), then redeploy.";
                })
                (mkHttpCheck {
                  name = "ClickHouse Data Usage";
                  group = "Filesystem";
                  url = "http://localhost:${toString nodePort}/metrics";
                  interval = "30m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*clickhouse_xfs_usage_over_threshold 0*)"
                  ];
                  alerts = discordAlert "ClickHouse XFS data filesystem exceeds 85% — XFS cannot shrink and telemetry retention grows unboundedly. Check per-table sizes (clickhouse-client 'SELECT database, formatReadableSize(sum(bytes_on_disk)) FROM system.parts GROUP BY database') and tighten TTLs in signoz.nix (clickhouseInternalLogs / signoz_logs / signoz_traces retention).";
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
                # M07 alert mirrors (DiscordSync plan F40): an independent
                # second layer on top of the Prometheus rules in DiscordSync's
                # monitoring/alerts.yml. /metrics is auth-exempt on localhost.
                # gatus body patterns can only express "== 0" (prefix match on
                # the value line), so each check pins a sticky zero-state.
                # Deliberately NOT mirrored: DB-growth (500 MB/day rate) and
                # sync-failure COUNT (>5) alerts; a gatus absolute-byte ceiling
                # or a zero-failure check would false-fire on transients.
                # Those stay Prometheus-only.
                (mkHttpCheck {
                  name = "DiscordSync Legacy DLQ Empty";
                  group = "Infrastructure";
                  url = "http://localhost:${toString ports.discordsync-api}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # HELP/TYPE lines continue with prose ("Entries...", "gauge"),
                    # so only the value line can match "<metric name> 0".
                    "[BODY] == pat(*discordsync_projection_dlq_legacy_depth 0*)"
                  ];
                  alerts = discordAlert "DiscordSync legacy DLQ non-empty: unrecovered pre-v4.3 dead letters (Jul 3-6 silent-loss incident class). Recover via event-store replay (plan M09)";
                })
                (mkHttpCheck {
                  name = "DiscordSync Turso Sync Active";
                  group = "Infrastructure";
                  url = "http://localhost:${toString ports.discordsync-api}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*discordsync_turso_local_only_mode 0*)"
                  ];
                  alerts = discordAlert "DiscordSync in Turso local-only mode: cloud mirror paused (quota exhausted or sync gave up). Local archive intact, mirror is stale";
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
              ]
              ++ lib.optionals config.services.browser-history.enable [
                (mkHttpCheck {
                  name = "Browser History";
                  group = "Productivity";
                  url = "http://localhost:${toString ports.browser-history}/health";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alerts = discordAlert "Browser History server down — browsing analytics unavailable";
                })
              ]
              ++ lib.optionals (config.services.bank-sync.enable or false) [
                (mkHttpCheck {
                  name = "Bank-Sync";
                  group = "Finance";
                  url = "http://localhost:${toString ports.bank-sync}/";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                    # Functional, not just liveness: the real dashboard (not
                    # an error shell) carries the page title.
                    "[BODY] == pat(*Bank-Sync Dashboard*)"
                  ];
                  alerts = discordAlert "Bank-Sync down — Wise transaction sync halted, dashboard at banksync.home.lan unreachable. Check: systemctl status bank-sync, journalctl -u bank-sync.";
                })
                # Sync-health probe: the dashboard check above stays GREEN
                # while every sync cycle fails (the 2026-08 invisible-outage
                # class). This endpoint pattern-matches /metrics instead:
                # sync_errors_total must be zero AND at least one successful
                # sync must have ever happened (the last-sync timestamp
                # metric only renders after a success). Gatus cannot compute
                # timestamp AGE — a stale-sync (synced once, then scheduler
                # died silently) needs PromQL; covered by the sync_total
                # delta in post-deploy checks until Prometheus alerting
                # lands here.
                (mkHttpCheck {
                  name = "Bank-Sync Sync Health";
                  group = "Finance";
                  url = "http://localhost:${toString ports.bank-sync}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*bank_sync_sync_errors_total 0*)"
                    "[BODY] == pat(*bank_sync_last_sync_timestamp_seconds*)"
                  ];
                  alerts = discordAlert "Bank-Sync syncs are failing (or never succeeded) while the dashboard stays green — the August invisible-outage class. Check: journalctl -u bank-sync -n 100, then curl localhost:8097/metrics and read bank_sync_sync_errors_total + bank_sync_last_sync_timestamp_seconds.";
                })
              ]
              ++ lib.optionals (config.services.papdashboard.enable or false) [
                (mkHttpCheck {
                  name = "PapDashboard";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.papdashboard}/api/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alerts = discordAlert "PapDashboard alert hub down — alert lifecycle UI and NPU insights unavailable (raw Discord alerts still flow)";
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
              ]
              ++ lib.optionals (config.services.systemd-graph.enable or false) [
                (mkHttpCheck {
                  name = "systemd-graph";
                  group = "Review Tools";
                  url = "https://graph.home.lan/";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 2000"
                  ];
                  alerts = discordAlert "systemd-graph UI down — graph.home.lan unreachable";
                })
              ]
              ++ lib.optionals (config.services.systemd-timer-monitor.enable or false) [
                (mkHttpCheck {
                  name = "systemd-timer-monitor";
                  group = "Review Tools";
                  url = "https://timers.home.lan/";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*<!DOCTYPE html*)"
                  ];
                  alerts = discordAlert "systemd-timer-monitor report down — timers.home.lan unreachable or stale";
                })
              ]
              ++ map mkWebsiteCheck ossWebsites
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
                TimeoutStartSec = "3min";
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
