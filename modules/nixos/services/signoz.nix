# SigNoz observability: ClickHouse, OTel collector, dashboards, alerts
{
  inputs,
  lib,
  ...
}: let
  ports = (import ../../../lib/default.nix lib).ports;
  version = "0.127.1";
  collectorVersion = "0.144.5";

  mkPackages = pkgs: let
    src = inputs.signoz-src;
    collectorSrc = inputs.signoz-collector-src;

    buildGoModule = pkgs.buildGoModule.override {go = pkgs.go_1_25;};

    collectorVendorHash = "sha256-Woj11mfGSyxiZvCUb32r1Jp86IyT+6Ymwl0ZhhnlzQk=";

    schemaMigrator = buildGoModule {
      pname = "signoz-schema-migrator";
      version = collectorVersion;
      src = collectorSrc;
      vendorHash = collectorVendorHash;
      subPackages = ["cmd/signozschemamigrator"];
      ldflags = [
        "-s"
        "-w"
      ];
      postInstall = "mv $out/bin/signozschemamigrator $out/bin/signoz-schema-migrator";
    };

    otelCollector = buildGoModule {
      pname = "signoz-otel-collector";
      version = collectorVersion;
      src = collectorSrc;
      vendorHash = collectorVendorHash;
      subPackages = ["cmd/signozotelcollector"];
      ldflags = [
        "-s"
        "-w"
      ];
      postInstall = "mv $out/bin/signozotelcollector $out/bin/signoz-otel-collector";
      meta.mainProgram = "signoz-otel-collector";
    };

    signoz = buildGoModule {
      pname = "signoz";
      inherit version;
      inherit src;
      vendorHash = "sha256-4HkmDq+c7Oygei2QzlPFtdQNDdalS2M27p3ALxQKi24=";
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
        "-X github.com/SigNoz/signoz/pkg/query-service/constants.HTTPHostPort=0.0.0.0:${toString ports.signoz}"
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
        mainProgram = "signoz";
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
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      serviceTypes
      onFailure
      mkStateDir
      ports
      ;
    alerts = import ./_signoz-alerts.nix {inherit pkgs lib inputs;};
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
            serviceConfig =
              harden {
                MemoryMax = "4G";
                ReadWritePaths = [
                  "/var/lib/clickhouse"
                  "/var/log/clickhouse-server"
                ];
              }
              // serviceDefaults {};
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
            serviceConfig =
              {
                Type = "simple";
                User = "signoz";
                Group = "signoz";
                WorkingDirectory = cfg.settings.queryService.dataDir;
                ExecStart = let
                  jwtFile = "${cfg.settings.queryService.dataDir}/jwt-secret";
                  wrapper = pkgs.writeShellScriptBin "signoz-wrapper" ''
                    if [ ! -f '${jwtFile}' ]; then
                      ${pkgs.openssl}/bin/openssl rand -base64 48 > '${jwtFile}'
                      chmod 400 '${jwtFile}'
                    fi
                    export SIGNOZ_TOKENIZER_JWT_SECRET="$(cat '${jwtFile}')"
                    exec ${lib.getExe packages.signoz} server --config /etc/signoz/signoz.yaml
                  '';
                in "${lib.getExe wrapper}";
                ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version";
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
              // harden {
                MemoryMax = lib.mkForce "1G";
                ReadWritePaths = [cfg.settings.queryService.dataDir];
              }
              // serviceDefaults {RestartSec = "10";};
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
            serviceConfig =
              harden {
                MemoryMax = "512M";
                ReadWritePaths = [cfg.settings.queryService.dataDir];
              }
              // {
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

          environment.etc = alerts.rules // alerts.dashboards;
        })

        (lib.mkIf cfg.components.nodeExporter {
          services.prometheus.exporters.node = {
            enable = true;
            port = ports.signoz-node-exporter;
            listenAddress = "127.0.0.1";
            enabledCollectors = [
              "cpu"
              "diskstats"
              "filesystem"
              "loadavg"
              "meminfo"
              "netdev"
              "stat"
              "systemd"
              "time"
              "vmstat"
              "hwmon"
              "pressure"
            ];
            extraFlags = [
              "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/k3s/.+).+$"
              "--collector.netdev.device-exclude=^(veth.*|br-.*|docker.*).+$"
              "--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile_collectors"
            ];
          };

          systemd = lib.mkMerge [
            {
              tmpfiles.rules = [
                (mkStateDir "/var/lib/prometheus-node-exporter/textfile_collectors" "1777" "nobody" "nogroup")
              ];
            }
            {
              services.amdgpu-metrics = {
                description = "AMD GPU metrics collector for node_exporter textfile";
                inherit onFailure;
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = let
                    amdgpuMetrics = pkgs.writeShellApplication {
                      name = "amdgpu-metrics";
                      runtimeInputs = [
                        pkgs.coreutils
                        pkgs.gnugrep
                        pkgs.gawk
                      ];
                      text = ''
                        OUT="/var/lib/prometheus-node-exporter/textfile_collectors/amdgpu.prom"
                        TMP="''${OUT}.tmp"

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
                  in
                    lib.getExe amdgpuMetrics;
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
            }
            {
              services.nvme-metrics = {
                description = "NVMe SMART metrics collector for node_exporter textfile";
                inherit onFailure;
                serviceConfig =
                  {
                    Type = "oneshot";
                    ExecStart = let
                      nvmeMetrics = pkgs.writeShellApplication {
                        name = "nvme-metrics";
                        runtimeInputs = [
                          pkgs.nvme-cli
                          pkgs.coreutils
                          pkgs.gnugrep
                        ];
                        text = ''
                          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/nvme.prom"
                          TMP="''${OUT}.tmp"
                          DEVICE="/dev/nvme0n1"

                          if ! command -v nvme &>/dev/null; then
                            echo "nvme-cli not found, skipping" >&2
                            exit 0
                          fi

                          SMART=$(nvme smart-log -o json "$DEVICE" 2>/dev/null) || {
                            echo "Failed to read SMART log from $DEVICE" >&2
                            exit 1
                          }

                          DEV_NAME=$(basename "$DEVICE")

                          extract() {
                            local key="$1"
                            local val
                            val=$(echo "$SMART" | grep -oP "\"''${key}\"\s*:\s*\K[0-9]+") && echo "$val" || echo "0"
                          }

                          TEMP_KELVIN=$(echo "$SMART" | grep -oP '"temperature"\s*:\s*\K[0-9]+')
                          TEMP_CELSIUS=$((TEMP_KELVIN - 273))

                          {
                            echo "# HELP node_nvme_temperature_celsius NVMe SSD temperature in Celsius"
                            echo "# TYPE node_nvme_temperature_celsius gauge"
                            echo "node_nvme_temperature_celsius{device=\"''${DEV_NAME}\"} ''${TEMP_CELSIUS}"

                            echo "# HELP node_nvme_critical_warning NVMe critical warning flags (0 = none)"
                            echo "# TYPE node_nvme_critical_warning gauge"
                            echo "node_nvme_critical_warning{device=\"''${DEV_NAME}\"} $(extract critical_warning)"

                            echo "# HELP node_nvme_available_spare_percent NVMe available spare as percentage"
                            echo "# TYPE node_nvme_available_spare_percent gauge"
                            echo "node_nvme_available_spare_percent{device=\"''${DEV_NAME}\"} $(extract available_spare)"

                            echo "# HELP node_nvme_percentage_used NVMe endurance used percentage (0-100, 100 = worn out)"
                            echo "# TYPE node_nvme_percentage_used gauge"
                            echo "node_nvme_percentage_used{device=\"''${DEV_NAME}\"} $(extract percentage_used)"

                            echo "# HELP node_nvme_data_units_read_total NVMe data units read (1 unit = 512 bytes)"
                            echo "# TYPE node_nvme_data_units_read_total counter"
                            echo "node_nvme_data_units_read_total{device=\"''${DEV_NAME}\"} $(extract data_units_read)"

                            echo "# HELP node_nvme_data_units_written_total NVMe data units written (1 unit = 512 bytes)"
                            echo "# TYPE node_nvme_data_units_written_total counter"
                            echo "node_nvme_data_units_written_total{device=\"''${DEV_NAME}\"} $(extract data_units_written)"

                            echo "# HELP node_nvme_power_cycles_total NVMe power cycle count"
                            echo "# TYPE node_nvme_power_cycles_total counter"
                            echo "node_nvme_power_cycles_total{device=\"''${DEV_NAME}\"} $(extract power_cycles)"

                            echo "# HELP node_nvme_power_on_hours_total NVMe power-on hours"
                            echo "# TYPE node_nvme_power_on_hours_total counter"
                            echo "node_nvme_power_on_hours_total{device=\"''${DEV_NAME}\"} $(extract power_on_hours)"

                            echo "# HELP node_nvme_unsafe_shutdowns_total NVMe unsafe shutdown count"
                            echo "# TYPE node_nvme_unsafe_shutdowns_total counter"
                            echo "node_nvme_unsafe_shutdowns_total{device=\"''${DEV_NAME}\"} $(extract unsafe_shutdowns)"

                            echo "# HELP node_nvme_media_errors_total NVMe media and data integrity errors"
                            echo "# TYPE node_nvme_media_errors_total counter"
                            echo "node_nvme_media_errors_total{device=\"''${DEV_NAME}\"} $(extract media_errors)"

                            echo "# HELP node_nvme_error_log_entries_total NVMe error log entry count"
                            echo "# TYPE node_nvme_error_log_entries_total counter"
                            echo "node_nvme_error_log_entries_total{device=\"''${DEV_NAME}\"} $(extract num_err_log_entries)"
                          } > "$TMP"

                          mv "$TMP" "$OUT"
                        '';
                      };
                    in "${nvmeMetrics}/bin/nvme-metrics";
                  }
                  // harden {
                    CapabilityBoundingSet = "CAP_SYS_ADMIN";
                  };
              };

              timers.nvme-metrics = {
                description = "Collect NVMe SMART metrics every 60s";
                wantedBy = ["timers.target"];
                timerConfig = {
                  OnBootSec = "30s";
                  OnUnitActiveSec = "60s";
                };
              };
            }
            {
              services.psi-metrics = {
                description = "Memory pressure (PSI) metrics for node_exporter textfile";
                inherit onFailure;
                serviceConfig =
                  {
                    Type = "oneshot";
                    ExecStart = let
                      psiMetrics = pkgs.writeShellApplication {
                        name = "psi-metrics";
                        runtimeInputs = [pkgs.gawk];
                        text = ''
                          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/psi.prom"
                          TMP="''${OUT}.tmp"

                          PSI="/proc/pressure/memory"
                          [ -f "$PSI" ] || exit 0

                          some_avg10=$(awk '/^some/ {split($2, a, "="); print a[2]}' "$PSI")
                          full_avg10=$(awk '/^full/ {split($2, a, "="); print a[2]}' "$PSI")

                          # Derived alert: 1 when >50% of tasks stalled on memory (10s avg),
                          # or >10% fully stalled — early warning before OOM cascade.
                          alert=0
                          awk "BEGIN{exit !($some_avg10 > 0.50)}" && alert=1
                          awk "BEGIN{exit !($full_avg10 > 0.10)}" && alert=1

                          {
                            echo "# HELP node_psi_memory_some_avg10 Proportion of last 10s where some tasks stalled on memory"
                            echo "# TYPE node_psi_memory_some_avg10 gauge"
                            echo "node_psi_memory_some_avg10 ''${some_avg10}"
                            echo "# HELP node_psi_memory_full_avg10 Proportion of last 10s where all tasks stalled on memory"
                            echo "# TYPE node_psi_memory_full_avg10 gauge"
                            echo "node_psi_memory_full_avg10 ''${full_avg10}"
                            echo "# HELP node_psi_memory_alert Derived boolean: 1 when pressure exceeds early-warning threshold"
                            echo "# TYPE node_psi_memory_alert gauge"
                            echo "node_psi_memory_alert ''${alert}"
                          } > "$TMP"

                          mv "$TMP" "$OUT"
                        '';
                      };
                    in "${psiMetrics}/bin/psi-metrics";
                  }
                  // harden {
                    ReadWritePaths = ["/var/lib/prometheus-node-exporter/textfile_collectors"];
                  };
              };

              timers.psi-metrics = {
                description = "Collect memory pressure metrics every 15s";
                wantedBy = ["timers.target"];
                timerConfig = {
                  OnBootSec = "5s";
                  OnUnitActiveSec = "15s";
                };
              };
            }
          ];
        })

        (lib.mkIf cfg.components.cadvisor {
          systemd.services.cadvisor = {
            description = "cAdvisor — container metrics";
            wantedBy = ["signoz.target"];
            after = ["docker.service"];
            requires = ["docker.service"];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig =
              {
                ExecStart = "${lib.getExe pkgs.cadvisor} --listen_ip=127.0.0.1 --port=${toString cfg.settings.cadvisorPort} --docker_only=true";
                NoNewPrivileges = lib.mkForce false;
              }
              // harden {}
              // serviceDefaults {};
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
            serviceConfig =
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
                    ++ lib.optional (cfg.components.nodeExporter || cfg.components.cadvisor) "journald";
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
