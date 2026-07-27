# SigNoz observability: ClickHouse, OTel collector, dashboards, alerts
# Auth: SigNoz CE OIDC/SAML is Enterprise-only ($4k/mo). Instead, impersonation
# mode disables all internal auth (every request = root admin) and the ENTIRE
# auth boundary is Caddy + oauth2-proxy (Pocket ID) on signoz.<domain>.
# The Caddy vHost applies forward-auth UNCONDITIONALLY — no LAN bypass —
# because impersonation mode means SigNoz itself has zero access control.
{
  inputs,
  lib,
  ...
}:
let
  mkPackages = import ./_signoz-packages.nix { inherit inputs lib; };
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      packages = mkPackages pkgs;
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.isLinux {
        inherit (packages) signoz;
        signoz-otel-collector = packages.otelCollector;
        signoz-schema-migrator = packages.schemaMigrator;
      };
    };

  flake.nixosModules.signoz =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.signoz;
      packages = mkPackages pkgs;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceTypes
        onFailure
        mkStateDir
        ports
        ;
      alerts = import ./_signoz-alerts.nix { inherit pkgs lib inputs; };
      signozMetrics = import ./_signoz-metrics.nix {
        inherit
          cfg
          pkgs
          lib
          harden
          onFailure
          ports
          mkStateDir
          ;
      };
    in
    {
      options.services.signoz = {
        enable = lib.mkEnableOption "SigNoz observability platform";

        settings = lib.mkOption {
          type = lib.types.submodule {
            options = {
              clickhouse = {
                url = lib.mkOption {
                  type = lib.types.str;
                  default = "tcp://127.0.0.1:${toString ports.signoz-clickhouse}";
                  description = "ClickHouse connection URL";
                };
                database = lib.mkOption {
                  type = lib.types.str;
                  default = "signoz_metrics";
                  description = "ClickHouse database for metrics";
                };
                tracesDatabase = lib.mkOption {
                  type = lib.types.str;
                  default = "signoz_traces";
                  description = "ClickHouse database for traces";
                };
                logsDatabase = lib.mkOption {
                  type = lib.types.str;
                  default = "signoz_logs";
                  description = "ClickHouse database for logs";
                };
              };
              queryService = {
                port = serviceTypes.servicePort ports.signoz "Port for the SigNoz query service web UI and API";
                host = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1";
                  description = "Bind address for the query service";
                };
                dataDir = lib.mkOption {
                  type = lib.types.str;
                  default = "/var/lib/signoz";
                  description = "Data directory for the query service (runtime path, not copied to store)";
                };
              };
              cadvisorPort = serviceTypes.servicePort ports.signoz-cadvisor "Port for cAdvisor container metrics";
              collector = {
                port = serviceTypes.servicePort ports.signoz-otlp-grpc "OTLP gRPC receiver port";
                httpPort = serviceTypes.servicePort ports.signoz-otlp-http "OTLP HTTP receiver port";
              };
            };
          };
          default = { };
          description = "SigNoz service settings (ClickHouse, query service, collector)";
        };

        components = lib.mkOption {
          type = lib.types.submodule {
            options = {
              queryService = lib.mkEnableOption "query service" // {
                default = true;
              };
              otelCollector = lib.mkEnableOption "OTel collector" // {
                default = true;
              };
              clickhouse = lib.mkEnableOption "managed ClickHouse" // {
                default = true;
              };
              nodeExporter = lib.mkEnableOption "Prometheus node exporter" // {
                default = true;
              };
              cadvisor = lib.mkEnableOption "cAdvisor container metrics" // {
                default = true;
              };
            };
          };
          default = { };
          description = "Toggle individual SigNoz stack components";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            users.users.signoz = {
              isSystemUser = true;
              group = "signoz";
              home = cfg.settings.queryService.dataDir;
              createHome = true;
            };
            users.groups.signoz = { };
            systemd.targets.signoz = {
              description = "SigNoz observability stack";
              wantedBy = [ "multi-user.target" ];
            };
            systemd.tmpfiles.rules = [
              (mkStateDir cfg.settings.queryService.dataDir "0755" "signoz" "signoz")
            ];

            environment.etc."signoz/signoz.yaml".text = lib.generators.toYAML { } {
              gateway = {
                url = "http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}";
              };
              telemetrystore = {
                provider = "clickhouse";
                clickhouse = {
                  dsn = cfg.settings.clickhouse.url;
                  cluster = "default";
                };
              };
              sqlstore = {
                provider = "sqlite";
                sqlite = {
                  path = "${cfg.settings.queryService.dataDir}/signoz.db";
                  mode = "wal";
                  busy_timeout = "10s";
                };
              };
              web = {
                enabled = false;
              };
              instrumentation = {
                logs.level = "info";
                metrics.enabled = false;
              };
            };
          }

          (lib.mkIf cfg.components.clickhouse {
            services.clickhouse.enable = true;
            services.clickhouse.extraServerConfig = ''
              <clickhouse>
                <keeper_server>
                  <tcp_port>${toString ports.signoz-clickhouse-keeper}</tcp_port>
                  <server_id>1</server_id>
                  <log_storage_path>/var/lib/clickhouse/coordination/log</log_storage_path>
                  <snapshot_storage_path>/var/lib/clickhouse/coordination/snapshots</snapshot_storage_path>
                  <raft_configuration>
                    <server>
                      <id>1</id>
                      <hostname>localhost</hostname>
                      <port>${toString ports.signoz-clickhouse-raft}</port>
                    </server>
                  </raft_configuration>
                </keeper_server>
                <zookeeper>
                  <node>
                    <host>localhost</host>
                    <port>${toString ports.signoz-clickhouse-keeper}</port>
                  </node>
                </zookeeper>
              </clickhouse>
            '';
            systemd.tmpfiles.rules = [
              (mkStateDir "/var/log/clickhouse-server" "0755" "clickhouse" "clickhouse")
            ];
            systemd.services.clickhouse = {
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "4G";
                  ReadWritePaths = [
                    "/var/lib/clickhouse"
                    "/var/log/clickhouse-server"
                  ];
                })
                (serviceDefaults { })
              ];
            };
          })

          (lib.mkIf cfg.components.queryService {
            systemd.services.signoz = {
              description = "SigNoz Observability Platform";
              after = lib.optional cfg.components.clickhouse "clickhouse.service";
              requires = lib.optional cfg.components.clickhouse "clickhouse.service";
              inherit onFailure;
              wantedBy = [ "signoz.target" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              serviceConfig = lib.mkMerge [
                {
                  Type = "simple";
                  User = "signoz";
                  Group = "signoz";
                  WorkingDirectory = cfg.settings.queryService.dataDir;
                  ExecStart =
                    let
                      wrapper = pkgs.writeShellApplication {
                        name = "signoz-wrapper";
                        runtimeInputs = [ pkgs.openssl ];
                        text = ''
                          # Impersonation mode: all requests treated as root admin.
                          # Auth is enforced by Caddy + oauth2-proxy (Pocket ID), not SigNoz.
                          export SIGNOZ_IDENTN_IMPERSONATION_ENABLED=true
                          export SIGNOZ_IDENTN_TOKENIZER_ENABLED=false
                          export SIGNOZ_IDENTN_APIKEY_ENABLED=false
                          export SIGNOZ_USER_ROOT_ENABLED=true
                          export SIGNOZ_USER_ROOT_EMAIL="admin@${config.networking.domain}"
                          export SIGNOZ_USER_ROOT_ORG_NAME="default"
                          ROOT_PW_FILE="${cfg.settings.queryService.dataDir}/root-password"
                          if [ ! -f "$ROOT_PW_FILE" ]; then
                            openssl rand -base64 48 > "$ROOT_PW_FILE"
                            chmod 400 "$ROOT_PW_FILE"
                          fi
                          SIGNOZ_USER_ROOT_PASSWORD="$(cat "$ROOT_PW_FILE")"
                          export SIGNOZ_USER_ROOT_PASSWORD
                          exec ${lib.getExe packages.signoz} server --config /etc/signoz/signoz.yaml
                        '';
                      };
                    in
                    "${lib.getExe wrapper}";
                  ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version";
                  ExecStartPre =
                    let
                      clearMigrationLock = pkgs.writeShellApplication {
                        name = "signoz-clear-migration-lock";
                        runtimeInputs = [ pkgs.sqlite ];
                        text = ''
                          sqlite3 '${cfg.settings.queryService.dataDir}/signoz.db' 'DELETE FROM migration_lock;' 2>/dev/null || true
                        '';
                      };
                    in
                    "${lib.getExe clearMigrationLock}";
                }
                (harden {
                  MemoryMax = lib.mkForce "1G";
                  ReadWritePaths = [ cfg.settings.queryService.dataDir ];
                })
                (serviceDefaults { RestartSec = "10"; })
              ];
            };

            systemd.services.signoz-provision = {
              description = "SigNoz Provisioning — deploy alert rules, channels, and dashboards";
              after = [ "signoz.service" ];
              wants = [ "signoz.service" ];
              inherit onFailure;
              wantedBy = [ "signoz.service" ];
              path = [
                pkgs.curl
                pkgs.jq
                pkgs.coreutils
              ];
              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "512M";
                  ReadWritePaths = [ cfg.settings.queryService.dataDir ];
                })
                {
                  Type = "oneshot";
                  RemainAfterExit = true;
                }
              ];
              preStart = lib.getExe (
                pkgs.writeShellApplication {
                  name = "signoz-wait-ready";
                  runtimeInputs = [
                    pkgs.curl
                    pkgs.coreutils
                  ];
                  text = ''
                    end=$((SECONDS + 120))
                    while [ $SECONDS -lt $end ]; do
                      if curl -sf http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version >/dev/null 2>&1; then
                        exit 0
                      fi
                      sleep 2
                    done
                    echo "SigNoz did not become ready within 120s" >&2
                    exit 1
                  '';
                }
              );
              script = lib.getExe (
                pkgs.writeShellApplication {
                  name = "signoz-provision";
                  runtimeInputs = [
                    pkgs.curl
                    pkgs.jq
                    pkgs.coreutils
                  ];
                  text = ''
                    SIGNOZ_URL="http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}"
                    CHANNEL_NAME="Discord Alerts"

                    # Deploy notification channels (idempotent: delete existing by name, then create fresh)
                    WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
                    if [ -f "$WEBHOOK_FILE" ]; then
                      echo "Deploying notification channels..."
                      WEBHOOK_URL=$(cat "$WEBHOOK_FILE")
                      EXISTING_CHANNELS=$(curl -sf "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || echo '{"data":[]}')

                      EXISTING_CHANNEL_ID=$(echo "$EXISTING_CHANNELS" | jq -r --arg n "$CHANNEL_NAME" '.data[] | select(.name == $n) | .id // empty' | head -1)
                      if [ -n "$EXISTING_CHANNEL_ID" ]; then
                        echo "  Deleting existing channel: $CHANNEL_NAME ($EXISTING_CHANNEL_ID)"
                        curl -sf --max-time 10 -X DELETE "$SIGNOZ_URL/api/v1/channels/$EXISTING_CHANNEL_ID" 2>/dev/null || true
                      fi

                      CHANNEL_JSON=$(jq -n --arg url "$WEBHOOK_URL" '{
                        name: "Discord Alerts",
                        discord_configs: [{
                          send_resolved: true,
                          webhook_url: $url
                        }]
                      }')
                      echo "  Creating channel: $CHANNEL_NAME"
                      curl -sf --max-time 10 -X POST \
                        -H "Content-Type: application/json" \
                        -d "$CHANNEL_JSON" \
                        "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || true
                    else
                      echo "Skipping channels: Discord webhook secret not found at $WEBHOOK_FILE"
                    fi

                    # Deploy alert rules (idempotent: delete existing by name, then create fresh)
                    echo "Deploying alert rules..."
                    EXISTING_RULES=$(curl -sf --max-time 10 "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || echo '{"data":{"rules":[]}}')

                    for rule_file in /etc/signoz/rules/*.json; do
                      if [ -f "$rule_file" ]; then
                        RULE_NAME=$(jq -r '.data.rule.name // empty' "$rule_file")
                        if [ -n "$RULE_NAME" ]; then
                          EXISTING_ID=$(echo "$EXISTING_RULES" | jq -r --arg n "$RULE_NAME" '.data.rules[]? // empty | select(.name == $n) | .id // empty' | head -1)
                          if [ -n "$EXISTING_ID" ]; then
                            echo "  Deleting existing: $RULE_NAME ($EXISTING_ID)"
                            curl -sf --max-time 10 -X DELETE "$SIGNOZ_URL/api/v1/rules/$EXISTING_ID" 2>/dev/null || true
                          fi
                        fi
                        echo "  Creating: $(basename "$rule_file")"
                        curl -sf --max-time 10 -X POST \
                          -H "Content-Type: application/json" \
                          -d @"$rule_file" \
                          "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || true
                      fi
                    done

                    # Deploy dashboards
                    echo "Deploying dashboards..."
                    for dash_file in /etc/signoz/dashboards/*.json; do
                      if [ -f "$dash_file" ]; then
                        echo "  Applying: $(basename "$dash_file")"
                        curl -sf --max-time 10 -X POST \
                          -H "Content-Type: application/json" \
                          -d @"$dash_file" \
                          "$SIGNOZ_URL/api/v1/dashboards" 2>/dev/null || true
                      fi
                    done

                    echo "Provisioning complete."
                  '';
                }
              );
            };

            environment.etc = alerts.rules // alerts.dashboards;
          })

          signozMetrics

          (lib.mkIf cfg.components.cadvisor {
            systemd.services.cadvisor = {
              description = "cAdvisor — container metrics";
              wantedBy = [ "signoz.target" ];
              after = [ "docker.service" ];
              requires = [ "docker.service" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              serviceConfig = lib.mkMerge [
                {
                  ExecStart = "${lib.getExe pkgs.cadvisor} --listen_ip=127.0.0.1 --port=${toString cfg.settings.cadvisorPort} --docker_only=true";
                  NoNewPrivileges = lib.mkForce false;
                }
                (harden { })
                (serviceDefaults { })
              ];
            };
          })

          (lib.mkIf cfg.components.otelCollector {
            users.groups.systemd-journal-member = lib.mkIf (
              cfg.components.nodeExporter || cfg.components.cadvisor
            ) { };
            systemd.services.signoz-collector = {
              description = "SigNoz OTel Collector";
              inherit onFailure;
              after = [ "signoz.service" ] ++ lib.optional cfg.components.clickhouse "clickhouse.service";
              wants = [ "signoz.service" ] ++ lib.optional cfg.components.clickhouse "clickhouse.service";
              wantedBy = [ "signoz.target" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              preStart = ''
                ${packages.otelCollector}/bin/signoz-otel-collector migrate bootstrap \
                  --clickhouse-dsn "${cfg.settings.clickhouse.url}" \
                  --clickhouse-cluster "default" \
                  --clickhouse-replication=false || true
                ${packages.otelCollector}/bin/signoz-otel-collector migrate sync up \
                  --clickhouse-dsn "${cfg.settings.clickhouse.url}" \
                  --clickhouse-cluster "default" \
                  --clickhouse-replication=false || true
              '';
              serviceConfig = lib.mkMerge [
                {
                  Type = "simple";
                  User = "signoz";
                  Group = "signoz";
                  SupplementaryGroups = lib.optional (
                    cfg.components.nodeExporter || cfg.components.cadvisor
                  ) "systemd-journal";
                  WorkingDirectory = cfg.settings.queryService.dataDir;
                  ExecStart = "${lib.getExe packages.otelCollector} --config /etc/signoz/collector.yaml";
                }
                (harden {
                  MemoryMax = lib.mkForce "1G";
                })
                (serviceDefaults { RestartSec = "10"; })
              ];
            };
            environment.etc."signoz/collector.yaml".text = lib.generators.toYAML { } {
              receivers = {
                otlp = {
                  protocols = {
                    grpc = {
                      endpoint = "127.0.0.1:${toString cfg.settings.collector.port}";
                    };
                    http = {
                      endpoint = "127.0.0.1:${toString cfg.settings.collector.httpPort}";
                    };
                  };
                };
              }
              // lib.optionalAttrs cfg.components.nodeExporter {
                prometheus = {
                  config = {
                    global = {
                      scrape_interval = "30s";
                    };
                    scrape_configs = [
                      {
                        job_name = "node-exporter";
                        static_configs = [
                          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
                        ];
                      }
                      {
                        job_name = "cadvisor";
                        static_configs = [ { targets = [ "127.0.0.1:${toString cfg.settings.cadvisorPort}" ]; } ];
                      }
                      {
                        job_name = "caddy";
                        static_configs = [ { targets = [ "127.0.0.1:${toString ports.caddy-metrics}" ]; } ];
                      }
                      {
                        job_name = "pocket-id";
                        static_configs = [
                          { targets = [ "127.0.0.1:${toString config.services.pocket-id-config.metricsPort}" ]; }
                        ];
                        metrics_path = "/metrics";
                      }
                      {
                        job_name = "dnsblockd";
                        static_configs = [
                          { targets = [ "127.0.0.1:${toString config.services.dns-blocker.statsPort}" ]; }
                        ];
                        metrics_path = "/metrics";
                      }
                      {
                        job_name = "emeet-pixyd";
                        static_configs = [ { targets = [ "127.0.0.1:${toString ports.emeet-pixyd}" ]; } ];
                        metrics_path = "/metrics";
                      }
                    ];
                  };
                };
              }
              // lib.optionalAttrs (cfg.components.nodeExporter || cfg.components.cadvisor) {
                journald = {
                  directory = "/var/log/journal";
                  priority = "info";
                  units = [
                    "signoz.service"
                    "signoz-collector.service"
                    "caddy.service"
                    "immich-server.service"
                    "forgejo.service"
                    "docker.service"
                    "postgresql.service"
                    "pocket-id.service"
                    "oauth2-proxy.service"
                  ];
                };
              };
              exporters = {
                clickhousetraces = {
                  datasource = "${cfg.settings.clickhouse.url}/${cfg.settings.clickhouse.tracesDatabase}";
                  retry_on_failure = {
                    enabled = true;
                    initial_interval = "5s";
                    max_interval = "30s";
                    max_elapsed_time = "300s";
                  };
                };
                signozclickhousemetrics = {
                  dsn = "${cfg.settings.clickhouse.url}/${cfg.settings.clickhouse.database}";
                };
                clickhouselogsexporter = {
                  dsn = "${cfg.settings.clickhouse.url}/${cfg.settings.clickhouse.logsDatabase}";
                  timeout = "10s";
                  use_new_schema = true;
                };
              };
              service = {
                telemetry = {
                  metrics = {
                    level = "basic";
                  };
                };
                pipelines = {
                  traces = {
                    receivers = [ "otlp" ];
                    exporters = [ "clickhousetraces" ];
                  };
                  metrics = {
                    receivers = [ "otlp" ] ++ lib.optional cfg.components.nodeExporter "prometheus";
                    exporters = [ "signozclickhousemetrics" ];
                  };
                  logs = {
                    receivers = [
                      "otlp"
                    ]
                    ++ lib.optional (cfg.components.nodeExporter || cfg.components.cadvisor) "journald";
                    exporters = [ "clickhouselogsexporter" ];
                  };
                };
              };
            };
          })

          { }
        ]
      );
    };
}
