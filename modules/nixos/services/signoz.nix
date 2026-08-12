# SigNoz observability: ClickHouse, OTel collector, dashboards, alerts
# Auth: SigNoz CE OIDC/SAML is Enterprise-only ($4k/mo). Instead, impersonation
# mode disables all internal auth (every request = root admin). The Caddy vHost
# uses protectedVHost (Layer 2): LAN requests bypass auth (direct proxy), external
# requests require oauth2-proxy forward-auth via Pocket ID SSO.
{
  inputs,
  lib,
  ...
}: let
  mkPackages = import ./_signoz-packages.nix {inherit inputs lib;};
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    packages = mkPackages pkgs;
  in {
    packages = lib.optionalAttrs pkgs.stdenv.isLinux {
      inherit (packages) signoz;
      signoz-otel-collector = packages.otelCollector;
      signoz-schema-migrator = packages.schemaMigrator;
    };
  };

  flake.nixosModules.signoz = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.signoz;
    packages = mkPackages pkgs;
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      serviceTypes
      onFailure
      mkStateDir
      ports
      ioTier
      ;
    alerts = import ./_signoz-alerts.nix {inherit pkgs lib inputs;};
    signozScripts = import ./_signoz-scripts.nix {inherit pkgs cfg config;};
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
    inherit (signozScripts) waitReadyScript provisionScript;
  in {
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
        default = {};
        description = "SigNoz service settings (ClickHouse, query service, collector)";
      };

      components = lib.mkOption {
        type = lib.types.submodule {
          options = {
            queryService =
              lib.mkEnableOption "query service"
              // {
                default = true;
              };
            otelCollector =
              lib.mkEnableOption "OTel collector"
              // {
                default = true;
              };
            clickhouse =
              lib.mkEnableOption "managed ClickHouse"
              // {
                default = true;
              };
            nodeExporter =
              lib.mkEnableOption "Prometheus node exporter"
              // {
                default = true;
              };
            cadvisor =
              lib.mkEnableOption "cAdvisor container metrics"
              // {
                default = true;
              };
            journaldLogs =
              lib.mkEnableOption "journald log collection via OTel receiver"
              // {
                default = true;
              };
          };
        };
        default = {};
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
          users.groups.signoz = {};
          systemd.targets.signoz = {
            description = "SigNoz observability stack";
            wantedBy = ["multi-user.target"];
          };
          systemd.tmpfiles.rules = [
            (mkStateDir cfg.settings.queryService.dataDir "0755" "signoz" "signoz")
          ];

          environment.etc."signoz/signoz.yaml".text = lib.generators.toYAML {} {
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
              <background_schedule_pool_size>8</background_schedule_pool_size>
              <background_buffer_flush_schedule_pool_size>4</background_buffer_flush_schedule_pool_size>
              <background_move_pool_size>2</background_move_pool_size>
              <background_fetches_pool_size>1</background_fetches_pool_size>
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
          services.clickhouse.extraUsersConfig = ''
            <clickhouse>
              <profiles>
                <default>
                  <max_threads>2</max_threads>
                </default>
              </profiles>
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
              (serviceDefaults {})
              ioTier.heavyDB
            ];
          };
        })

        (lib.mkIf cfg.components.queryService {
          systemd.services.signoz = {
            description = "SigNoz Observability Platform";
            after = lib.optional cfg.components.clickhouse "clickhouse.service";
            requires = lib.optional cfg.components.clickhouse "clickhouse.service";
            inherit onFailure;
            wantedBy = ["signoz.target"];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                Type = "simple";
                User = "signoz";
                Group = "signoz";
                WorkingDirectory = cfg.settings.queryService.dataDir;
                ExecStart = let
                  wrapper = pkgs.writeShellApplication {
                    name = "signoz-wrapper";
                    runtimeInputs = [pkgs.openssl];
                    text = ''
                      # Impersonation mode: all requests treated as root admin.
                      # Auth is enforced by Caddy protectedVHost (Layer 2):
                      # LAN bypass + external oauth2-proxy forward-auth.
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
                in "${lib.getExe wrapper}";
                ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version";
                TimeoutStartSec = "3min";
                ExecStartPre = let
                  clearMigrationLock = pkgs.writeShellApplication {
                    name = "signoz-clear-migration-lock";
                    runtimeInputs = [pkgs.sqlite];
                    text = ''
                      sqlite3 '${cfg.settings.queryService.dataDir}/signoz.db' 'DELETE FROM migration_lock;' 2>/dev/null || true
                    '';
                  };
                in "${lib.getExe clearMigrationLock}";
              }
              (harden {
                MemoryMax = lib.mkForce "1G";
                ReadWritePaths = [cfg.settings.queryService.dataDir];
              })
              (serviceDefaults {RestartSec = "10";})
              ioTier.background
              {
                Environment = ["GOMEMLIMIT=768MiB"];
              }
            ];
          };

          systemd.services.signoz-provision = {
            description = "SigNoz Provisioning — deploy alert rules, channels, and dashboards";
            after = ["signoz.service"];
            wants = ["signoz.service"];
            inherit onFailure;
            wantedBy = ["signoz.service"];
            path = [
              pkgs.curl
              pkgs.jq
              pkgs.coreutils
            ];
            restartTriggers = [(lib.getExe provisionScript)];
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "512M";
                ReadWritePaths = [cfg.settings.queryService.dataDir];
              })
              {
                Type = "oneshot";
                RemainAfterExit = true;
              }
            ];
            preStart = lib.getExe waitReadyScript;
            script = lib.getExe provisionScript;
          };

          environment.etc = alerts.rules // alerts.dashboards;
        })

        signozMetrics

        (lib.mkIf cfg.components.cadvisor {
          systemd.services.cadvisor = {
            description = "cAdvisor — container metrics";
            wantedBy = ["signoz.target"];
            after = ["docker.service"];
            requires = ["docker.service"];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                ExecStart = "${lib.getExe pkgs.cadvisor} --listen_ip=127.0.0.1 --port=${toString cfg.settings.cadvisorPort} --docker_only=true";
                NoNewPrivileges = lib.mkForce false;
              }
              (harden {})
              (serviceDefaults {})
            ];
          };
        })

        (lib.mkIf cfg.components.otelCollector {
          users.groups.systemd-journal-member = lib.mkIf (
            cfg.components.nodeExporter || cfg.components.cadvisor
          ) {};
          systemd.services.signoz-collector = {
            description = "SigNoz OTel Collector";
            inherit onFailure;
            after = ["signoz.service"] ++ lib.optional cfg.components.clickhouse "clickhouse.service";
            wants = ["signoz.service"] ++ lib.optional cfg.components.clickhouse "clickhouse.service";
            wantedBy = ["signoz.target"];
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
              (serviceDefaults {RestartSec = "10";})
              ioTier.background
              {
                Environment = ["GOMEMLIMIT=384MiB"];
              }
            ];
          };
          environment.etc."signoz/collector.yaml".text = lib.generators.toYAML {} {
            receivers =
              {
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
                          {targets = ["127.0.0.1:${toString config.services.prometheus.exporters.node.port}"];}
                        ];
                      }
                      {
                        job_name = "cadvisor";
                        static_configs = [{targets = ["127.0.0.1:${toString cfg.settings.cadvisorPort}"];}];
                      }
                      {
                        job_name = "caddy";
                        static_configs = [{targets = ["127.0.0.1:${toString ports.caddy-metrics}"];}];
                      }
                      {
                        job_name = "pocket-id";
                        static_configs = [
                          {targets = ["127.0.0.1:${toString config.services.pocket-id-config.metricsPort}"];}
                        ];
                        metrics_path = "/metrics";
                      }
                      {
                        job_name = "dnsblockd";
                        static_configs = [
                          {targets = ["127.0.0.1:${toString config.services.dns-blocker.statsPort}"];}
                        ];
                        metrics_path = "/metrics";
                      }
                      {
                        job_name = "emeet-pixyd";
                        static_configs = [{targets = ["127.0.0.1:${toString ports.emeet-pixyd}"];}];
                        metrics_path = "/metrics";
                      }
                    ];
                  };
                };
              }
              // lib.optionalAttrs cfg.components.journaldLogs {
                journald = {
                  directory = "/var/log/journal";
                  # warning+ only — collecting info-level logs from 14 services
                  # via `journalctl --follow` burned 96% CPU and 3.78 GB read
                  # because the OTel receiver serializes every entry to JSON in
                  # real-time. monitor365-server alone generated 270 MB / 5 min
                  # at info level.
                  priority = "warning";
                  units = [
                    "signoz.service"
                    "signoz-collector.service"
                    "caddy.service"
                    "immich-server.service"
                    "forgejo.service"
                    "pocket-id.service"
                    "oauth2-proxy.service"
                    "discordsync.service"
                    "hermes.service"
                    "dnsblockd.service"
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
                  receivers = ["otlp"];
                  exporters = ["clickhousetraces"];
                };
                metrics = {
                  receivers = ["otlp"] ++ lib.optional cfg.components.nodeExporter "prometheus";
                  exporters = ["signozclickhousemetrics"];
                };
                logs = {
                  receivers =
                    [
                      "otlp"
                    ]
                    ++ lib.optional cfg.components.journaldLogs "journald";
                  exporters = ["clickhouselogsexporter"];
                };
              };
            };
          };
        })

        {}
      ]
    );
  };
}
