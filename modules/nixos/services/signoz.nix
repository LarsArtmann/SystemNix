{
  inputs,
  lib,
  ...
}: let
  version = "0.117.1";
  collectorVersion = "0.144.2";

  mkPackages = pkgs: let
    src = inputs.signoz-src;
    collectorSrc = inputs.signoz-collector-src;

    buildGoModule = pkgs.buildGoModule.override {go = pkgs.go_1_25;};

    collectorVendorHash = "sha256-FEzjJTYItt6mMPUu2cFnfYP6oTjnWiqCVKO+dUIm1pg=";

    schemaMigrator = buildGoModule {
      pname = "signoz-schema-migrator";
      version = collectorVersion;
      src = collectorSrc;
      vendorHash = collectorVendorHash;
      subPackages = ["cmd/signozschemamigrator"];
      ldflags = ["-s" "-w"];
      postInstall = "mv $out/bin/signozschemamigrator $out/bin/signoz-schema-migrator";
    };

    otelCollector = buildGoModule {
      pname = "signoz-otel-collector";
      version = collectorVersion;
      src = collectorSrc;
      vendorHash = collectorVendorHash;
      subPackages = ["cmd/signozotelcollector"];
      ldflags = ["-s" "-w"];
      postInstall = "mv $out/bin/signozotelcollector $out/bin/signoz-otel-collector";
    };

    signoz = buildGoModule {
      pname = "signoz";
      inherit version;
      inherit src;
      vendorHash = "sha256-z6WdVvDvFsbQ1apEr+jHFPB+mLLZj3jeUUX92atTuUk=";
      subPackages = ["cmd/community"];
      tags = ["timetzdata"];

      ldflags = [
        "-s"
        "-w"
        "-X github.com/SigNoz/signoz/pkg/version.version=${version}"
        "-X github.com/SigNoz/signoz/pkg/version.variant=community"
        "-X github.com/SigNoz/signoz/pkg/version.hash=nix"
        "-X github.com/SigNoz/signoz/pkg/version.time=1970-01-01T00:00:00Z"
        "-X github.com/SigNoz/signoz/pkg/version.branch=nix"
        "-X github.com/SigNoz/signoz/pkg/query-service/constants.HTTPHostPort=0.0.0.0:8080"
      ];

      postInstall = ''
        mv $out/bin/community $out/bin/signoz
        mkdir -p $out/share/signoz
        cp -r $src/conf $out/share/signoz/ 2>/dev/null || true
        cp -r $src/templates $out/share/signoz/ 2>/dev/null || true
      '';

      meta = with lib; {
        description = "SigNoz observability platform (community edition)";
        homepage = "https://signoz.io";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };
  in {
    inherit signoz otelCollector schemaMigrator;
  };
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
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults;
  in {
    options.services.signoz = {
      enable = lib.mkEnableOption "SigNoz observability platform";

      settings = lib.mkOption {
        type = lib.types.submodule {
          options = {
            clickhouse = {
              url = lib.mkOption {
                type = lib.types.str;
                default = "tcp://127.0.0.1:9000";
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
              port = lib.mkOption {
                type = lib.types.port;
                default = 8080;
                description = "Port for the SigNoz query service web UI and API";
              };
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
            cadvisorPort = lib.mkOption {
              type = lib.types.port;
              default = 9110;
              description = "Port for cAdvisor container metrics";
            };
            collector = {
              port = lib.mkOption {
                type = lib.types.port;
                default = 4317;
                description = "OTLP gRPC receiver port";
              };
              httpPort = lib.mkOption {
                type = lib.types.port;
                default = 4318;
                description = "OTLP HTTP receiver port";
              };
            };
          };
        };
        default = {};
        description = "SigNoz service settings (ClickHouse, query service, collector)";
      };

      components = lib.mkOption {
        type = lib.types.submodule {
          options = {
            queryService = lib.mkEnableOption "query service" // {default = true;};
            otelCollector = lib.mkEnableOption "OTel collector" // {default = true;};
            clickhouse = lib.mkEnableOption "managed ClickHouse" // {default = true;};
            nodeExporter = lib.mkEnableOption "Prometheus node exporter" // {default = true;};
            cadvisor = lib.mkEnableOption "cAdvisor container metrics" // {default = true;};
          };
        };
        default = {};
        description = "Toggle individual SigNoz stack components";
      };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
      {
        users.users.signoz = {
          isSystemUser = true;
          group = "signoz";
          home = cfg.settings.queryService.dataDir;
          createHome = true;
        };
        users.groups.signoz = {};
        systemd.tmpfiles.rules = [
          "d ${cfg.settings.queryService.dataDir} 0755 signoz signoz -"
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
            <keeper_server>
              <tcp_port>9181</tcp_port>
              <server_id>1</server_id>
              <log_storage_path>/var/lib/clickhouse/coordination/log</log_storage_path>
              <snapshot_storage_path>/var/lib/clickhouse/coordination/snapshots</snapshot_storage_path>
              <raft_configuration>
                <server>
                  <id>1</id>
                  <hostname>localhost</hostname>
                  <port>9234</port>
                </server>
              </raft_configuration>
            </keeper_server>
            <zookeeper>
              <node>
                <host>localhost</host>
                <port>9181</port>
              </node>
            </zookeeper>
          </clickhouse>
        '';
      })

      (lib.mkIf cfg.components.queryService {
        systemd.services.signoz = {
          description = "SigNoz Observability Platform";
          after = lib.optional cfg.components.clickhouse "clickhouse.service";
          requires = lib.optional cfg.components.clickhouse "clickhouse.service";
          onFailure = ["notify-failure@%n.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig =
            {
              Type = "simple";
              User = "signoz";
              Group = "signoz";
              WorkingDirectory = cfg.settings.queryService.dataDir;
              ExecStart = "${packages.signoz}/bin/signoz server --config /etc/signoz/signoz.yaml";
              ExecStartPost = "${pkgs.curl}/bin/curl -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version";
            }
            // harden {
              MemoryMax = lib.mkForce "1G";
            }
            // serviceDefaults {RestartSec = "10";};
        };

        systemd.services.signoz-provision = {
          description = "SigNoz Provisioning — deploy alert rules, channels, and dashboards";
          after = ["signoz.service"];
          wants = ["signoz.service"];
          onFailure = ["notify-failure@%n.service"];
          wantedBy = ["signoz.service"];
          path = [pkgs.curl pkgs.jq pkgs.coreutils];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          preStart = ''
            ${pkgs.coreutils}/bin/timeout 120 ${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -sf http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version > /dev/null 2>&1; do sleep 2; done'
          '';
          script = ''
            SIGNOZ_URL="http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}"
            CHANNEL_NAME="Discord Alerts"

            # Deploy notification channels (idempotent: delete existing by name, then create fresh)
            WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
            if [ -f "$WEBHOOK_FILE" ]; then
              ${pkgs.coreutils}/bin/echo "Deploying notification channels..."
              WEBHOOK_URL=$(${pkgs.coreutils}/bin/cat "$WEBHOOK_FILE")
              EXISTING_CHANNELS=$(${pkgs.curl}/bin/curl -sf "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || echo '[]')

              EXISTING_CHANNEL_ID=$(echo "$EXISTING_CHANNELS" | ${pkgs.jq}/bin/jq -r --arg n "$CHANNEL_NAME" '.[] | select(.name == $n) | .id // empty' | head -1)
              if [ -n "$EXISTING_CHANNEL_ID" ]; then
                ${pkgs.coreutils}/bin/echo "  Deleting existing channel: $CHANNEL_NAME ($EXISTING_CHANNEL_ID)"
                ${pkgs.curl}/bin/curl -sf -X DELETE "$SIGNOZ_URL/api/v1/channels/$EXISTING_CHANNEL_ID" 2>/dev/null || true
              fi

              CHANNEL_JSON=$(${pkgs.jq}/bin/jq -n --arg url "$WEBHOOK_URL" '{
                name: "Discord Alerts",
                discord_configs: [{
                  send_resolved: true,
                  webhook_url: $url
                }]
              }')
              ${pkgs.coreutils}/bin/echo "  Creating channel: $CHANNEL_NAME"
              ${pkgs.curl}/bin/curl -sf -X POST \
                -H "Content-Type: application/json" \
                -d "$CHANNEL_JSON" \
                "$SIGNOZ_URL/api/v1/channels" 2>/dev/null || true
            else
              ${pkgs.coreutils}/bin/echo "Skipping channels: Discord webhook secret not found at $WEBHOOK_FILE"
            fi

            # Deploy alert rules (idempotent: delete existing by name, then create fresh)
            ${pkgs.coreutils}/bin/echo "Deploying alert rules..."
            EXISTING_RULES=$(${pkgs.curl}/bin/curl -sf "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || echo '{"data":[]}')

            for rule_file in /etc/signoz/rules/*.json; do
              if [ -f "$rule_file" ]; then
                RULE_NAME=$(${pkgs.jq}/bin/jq -r '.data.rule.name // empty' "$rule_file")
                if [ -n "$RULE_NAME" ]; then
                  EXISTING_ID=$(echo "$EXISTING_RULES" | ${pkgs.jq}/bin/jq -r --arg n "$RULE_NAME" '.data[] | select(.rule.name == $n) | .id // empty' | head -1)
                  if [ -n "$EXISTING_ID" ]; then
                    ${pkgs.coreutils}/bin/echo "  Deleting existing: $RULE_NAME ($EXISTING_ID)"
                    ${pkgs.curl}/bin/curl -sf -X DELETE "$SIGNOZ_URL/api/v1/rules/$EXISTING_ID" 2>/dev/null || true
                  fi
                fi
                ${pkgs.coreutils}/bin/echo "  Creating: $(basename $rule_file)"
                ${pkgs.curl}/bin/curl -sf -X POST \
                  -H "Content-Type: application/json" \
                  -d @"$rule_file" \
                  "$SIGNOZ_URL/api/v1/rules" 2>/dev/null || true
              fi
            done

            # Deploy dashboards
            ${pkgs.coreutils}/bin/echo "Deploying dashboards..."
            for dash_file in /etc/signoz/dashboards/*.json; do
              if [ -f "$dash_file" ]; then
                ${pkgs.coreutils}/bin/echo "  Applying: $(basename $dash_file)"
                ${pkgs.curl}/bin/curl -sf -X POST \
                  -H "Content-Type: application/json" \
                  -d @"$dash_file" \
                  "$SIGNOZ_URL/api/v1/dashboards" 2>/dev/null || true
              fi
            done

            ${pkgs.coreutils}/bin/echo "Provisioning complete."
          '';
        };

        environment.etc = {
          "signoz/rules/disk-full.json".source = pkgs.writeText "disk-full-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "Disk usage above 90% on {{.Labels.fstype}} mounted at {{.Labels.mountpoint}}";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100";
                        step = 300;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND";
                  target = 90;
                };
                evaluationInterval = "5m";
                name = "Disk Space Critical (>90%)";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/cpu-sustained.json".source = pkgs.writeText "cpu-sustained-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "CPU usage above 90% for 15 minutes on {{.Labels.instance}}";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
                        step = 300;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND";
                  target = 90;
                };
                evaluationInterval = "5m";
                name = "CPU Sustained High (>90%)";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/memory-critical.json".source = pkgs.writeText "memory-critical-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "Memory usage above 90% on {{.Labels.instance}}";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
                        step = 300;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND";
                  target = 90;
                };
                evaluationInterval = "5m";
                name = "Memory Critical (>90%)";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/service-down.json".source = pkgs.writeText "service-down-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "Systemd service {{.Labels.name}} is in failed state";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "node_systemd_units{state=\"failed\"}";
                        step = 60;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND";
                  target = 0;
                };
                evaluationInterval = "1m";
                name = "Systemd Service Failed";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/gpu-thermal.json".source = pkgs.writeText "gpu-thermal-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "AMD GPU temperature above 90°C on {{.Labels.card}}";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "node_amdgpu_gpu_temp_celsius";
                        step = 300;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND";
                  target = 90;
                };
                evaluationInterval = "5m";
                name = "GPU Thermal Throttling (>90°C)";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/dnsblockd-down.json".source = pkgs.writeText "dnsblockd-down-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "dnsblockd metrics endpoint is unreachable";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "up{job=\"dnsblockd\"}";
                        step = 60;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND_NOT";
                  target = 1;
                };
                evaluationInterval = "1m";
                name = "DNS Blocker Down";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/emeet-pixyd-down.json".source = pkgs.writeText "emeet-pixyd-down-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "emeet-pixyd metrics endpoint is unreachable";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "up{job=\"emeet-pixyd\"}";
                        step = 60;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND_NOT";
                  target = 1;
                };
                evaluationInterval = "1m";
                name = "EMEET PIXY Daemon Down";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/gpu-vram-high.json".source = pkgs.writeText "gpu-vram-high-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "GPU VRAM usage above 85% on {{.Labels.card}} — risk of OOM cascade (niri SIGABRT, desktop freeze)";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "(node_amdgpu_mem_info_vram_used_bytes / node_amdgpu_mem_info_vram_total_bytes) * 100";
                        step = 300;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND";
                  target = 85;
                };
                evaluationInterval = "5m";
                name = "GPU VRAM Critical (>85%)";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/rules/niri-down.json".source = pkgs.writeText "niri-down-rule.json" (builtins.toJSON {
            data = {
              rule = {
                alertType = "METRIC_BASED_ALERT";
                description = "Niri Wayland compositor is not running — desktop may be unresponsive";
                enabled = true;
                condition = {
                  compositeMetricQuery = {
                    promQueries = [
                      {
                        name = "A";
                        query = "niri_running";
                        step = 60;
                        statsAggExpr = "last";
                      }
                    ];
                  };
                  op = "AND_NOT";
                  target = 1;
                };
                evaluationInterval = "1m";
                name = "Niri Compositor Down";
                preferredChannels = ["Discord Alerts"];
                source = "RULE";
              };
            };
          });

          "signoz/dashboards/overview.json".source = "${inputs.self}/modules/nixos/services/dashboards/signoz-overview.json";
        };
      })

      (lib.mkIf cfg.components.nodeExporter {
        services.prometheus.exporters.node = {
          enable = true;
          port = 9100;
          listenAddress = "127.0.0.1";
          enabledCollectors = ["cpu" "diskstats" "filesystem" "loadavg" "meminfo" "netdev" "stat" "systemd" "time" "vmstat" "hwmon" "pressure"];
          extraFlags = ["--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/k3s/.+).+$" "--collector.netdev.device-exclude=^(veth.*|br-.*|docker.*).+$" "--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile_collectors"];
        };

        systemd = {
          tmpfiles.rules = [
            "d /var/lib/prometheus-node-exporter/textfile_collectors 0755 nobody nogroup -"
          ];

          services.amdgpu-metrics = {
            description = "AMD GPU metrics collector for node_exporter textfile";
            path = [pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.findutils];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "amdgpu-metrics" ''
                set -euo pipefail
                OUT="/var/lib/prometheus-node-exporter/textfile_collectors/amdgpu.prom"
                TMP="''${OUT}.tmp"

                strip_pct() {
                  local val="$1"
                  "''${val%\%}"
                }

                {
                  for card in /sys/class/drm/card*/device/gpu_busy_percent; do
                    if [ -f "$card" ]; then
                      pct=$(cat "$card" | tr -d '%\n')
                      card_name=$(echo "$card" | grep -oP 'card\d+')
                      echo "node_amdgpu_gpu_busy_percent{card=\"''${card_name}\"} ''${pct}"
                    fi
                  done

                  for mem in /sys/class/drm/card*/device/mem_busy_percent; do
                    if [ -f "$mem" ]; then
                      pct=$(cat "$mem" | tr -d '%\n')
                      card_name=$(echo "$mem" | grep -oP 'card\d+')
                      echo "node_amdgpu_mem_busy_percent{card=\"''${card_name}\"} ''${pct}"
                    fi
                  done

                  for temp in /sys/class/drm/card*/device/gpu_temp; do
                    if [ -f "$temp" ]; then
                      millideg=$(cat "$temp" | tr -d '\n')
                      card_name=$(echo "$temp" | grep -oP 'card\d+')
                      echo "node_amdgpu_gpu_temp_celsius{card=\"''${card_name}\"} $(awk "BEGIN{printf \"%.1f\", ''${millideg}/1000}")"
                    fi
                  done

                  for vram in /sys/class/drm/card*/device/mem_info_vram_total /sys/class/drm/card*/device/mem_info_vram_used; do
                    if [ -f "$vram" ]; then
                      bytes=$(cat "$vram" | tr -d '\n')
                      card_name=$(echo "$vram" | grep -oP 'card\d+')
                      metric=$(echo "$vram" | awk -F/ '{print $NF}')
                      echo "node_amdgpu_''${metric}_bytes{card=\"''${card_name}\"} ''${bytes}"
                    fi
                  done
                } > "$TMP"

                mv "$TMP" "$OUT"
              '';
            };
          };

          timers.amdgpu-metrics = {
            description = "Collect AMD GPU metrics every 30s";
            wantedBy = ["timers.target"];
            timerConfig = {
              OnBootSec = "10s";
              OnUnitActiveSec = "30s";
            };
          };
        };
      })

      (lib.mkIf cfg.components.cadvisor {
        systemd.services.cadvisor = {
          description = "cAdvisor — container metrics";
          wantedBy = ["multi-user.target"];
          after = ["docker.service"];
          requires = ["docker.service"];
          serviceConfig =
            {
              ExecStart = "${pkgs.cadvisor}/bin/cadvisor --listen_ip=127.0.0.1 --port=${toString cfg.settings.cadvisorPort} --docker_only=true";
              NoNewPrivileges = lib.mkForce false;
            }
            // harden {}
            // serviceDefaults {};
        };
      })

      (lib.mkIf cfg.components.otelCollector {
        users.groups.systemd-journal-member = lib.mkIf (cfg.components.nodeExporter || cfg.components.cadvisor) {};
        systemd.services.signoz-collector = {
          description = "SigNoz OTel Collector";
          onFailure = ["notify-failure@%n.service"];
          after = ["signoz.service"] ++ lib.optional cfg.components.clickhouse "clickhouse.service";
          wants = ["signoz.service"] ++ lib.optional cfg.components.clickhouse "clickhouse.service";
          wantedBy = ["multi-user.target"];
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
          serviceConfig =
            {
              Type = "simple";
              User = "signoz";
              Group = "signoz";
              SupplementaryGroups = lib.optional (cfg.components.nodeExporter || cfg.components.cadvisor) "systemd-journal";
              WorkingDirectory = cfg.settings.queryService.dataDir;
              ExecStart = "${packages.otelCollector}/bin/signoz-otel-collector --config /etc/signoz/collector.yaml";
            }
            // harden {
              MemoryMax = lib.mkForce "1G";
            }
            // serviceDefaults {RestartSec = "10";};
        };
        environment.etc."signoz/collector.yaml".text = lib.generators.toYAML {} {
          receivers =
            {
              otlp = {
                protocols = {
                  grpc = {endpoint = "127.0.0.1:${toString cfg.settings.collector.port}";};
                  http = {endpoint = "127.0.0.1:${toString cfg.settings.collector.httpPort}";};
                };
              };
            }
            // lib.optionalAttrs cfg.components.nodeExporter {
              prometheus = {
                config = {
                  global = {scrape_interval = "30s";};
                  scrape_configs = [
                    {
                      job_name = "node-exporter";
                      static_configs = [{targets = ["127.0.0.1:${toString config.services.prometheus.exporters.node.port}"];}];
                    }
                    {
                      job_name = "cadvisor";
                      static_configs = [{targets = ["127.0.0.1:${toString cfg.settings.cadvisorPort}"];}];
                    }
                    {
                      job_name = "caddy";
                      static_configs = [{targets = ["127.0.0.1:2019"];}];
                    }
                    {
                      job_name = "authelia";
                      static_configs = [{targets = ["127.0.0.1:${toString config.services.authelia-config.port}"];}];
                    }
                    {
                      job_name = "dnsblockd";
                      static_configs = [{targets = ["127.0.0.1:${toString config.services.dns-blocker.statsPort}"];}];
                      metrics_path = "/metrics";
                    }
                    {
                      job_name = "emeet-pixyd";
                      static_configs = [{targets = ["127.0.0.1:8090"];}];
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
                units = ["signoz.service" "signoz-collector.service" "caddy.service" "immich-server.service" "gitea.service" "docker.service" "postgresql.service" "authelia-main.service"];
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
              metrics = {level = "basic";};
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
                receivers = ["otlp"] ++ lib.optional (cfg.components.nodeExporter || cfg.components.cadvisor) "journald";
                exporters = ["clickhouselogsexporter"];
              };
            };
          };
        };
      })

      {}
    ]);
  };
}
