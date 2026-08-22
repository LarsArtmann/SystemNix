# SigNoz observability: ClickHouse, OTel collector, dashboards, alerts
# Auth: SigNoz CE OIDC/SAML is Enterprise-only ($4k/mo). Instead, impersonation
# mode disables all internal auth (every request = root admin). The Caddy vHost
# uses protectedVHost (Layer 2): LAN requests bypass auth (direct proxy), external
# requests require oauth2-proxy forward-auth via Pocket ID SSO.
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
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        inherit (packages) signoz;
        signoz-frontend = packages.frontend;
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
        serviceOneshotDefaults
        serviceTypes
        onFailure
        mkStateDir
        ports
        ioTier
        ;
      alerts = import ./_signoz-alerts.nix { inherit pkgs lib inputs; };
      signozScripts = import ./_signoz-scripts.nix { inherit pkgs cfg config; };
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

      # Self-wiring XFS data-mount dependency: hosts that declare a
      # fileSystems."/var/lib/clickhouse" entry (evo-x2: dedicated XFS
      # partition, see hardware-configuration.nix) get clickhouse hard-gated
      # on the mount; hosts without it (VM tests, future hosts) keep the
      # plain directory behavior. This is the anti-contamination rail: with
      # the mount absent (partition missing / fs corrupt), ClickHouse refuses
      # to start instead of silently writing telemetry into the root fs
      # underneath the mountpoint.
      hasClickhouseDataMount = builtins.hasAttr "/var/lib/clickhouse" config.fileSystems;

      # ClickHouse internal self-logs (system db) shipped WITHOUT TTLs on this
      # install — 52 GiB / 9.13B rows (90% of the data dir) measured 2026-08-17.
      # The two self-sampling logs collect at 1 Hz: metric_log via
      # <collect_interval_milliseconds> (default 1000) and asynchronous_metric_log
      # via <asynchronous_metrics_update_period_s> (default 1) — 56M rows/day in
      # async alone. NOTE: flush_interval_milliseconds is the WRONG knob — it
      # only batches rows into parts on disk; row volume scales with the
      # collect/update interval (verified live: flush 2000ms left the rate at
      # 1 Hz). Bound every log family to a 14-day TTL (matches btrbk root
      # snapshot retention) and halve both sampling intervals. Event-driven
      # logs (query_log, part_log, ...) keep one row per event regardless.
      # keeper_changelogs is deliberately absent: no event_date column,
      # managed by the embedded keeper itself.
      clickhouseInternalLogTtlDays = 14;
      clickhouseInternalLogs = {
        query_log = { };
        query_views_log = { };
        query_metric_log = { };
        trace_log = { };
        part_log = { };
        text_log = { };
        # metric_log is WIDE (one column per server metric, ~274 KB of column
        # metadata): MODIFY TTL would rewrite metadata past max_query_size
        # (256 KB) and ClickHouse refuses (QUERY_IS_TOO_LARGE). No config TTL
        # either — a restart-time TTL application would hit the same guard.
        # Retention for this family is partition-drop (monthly granularity) in
        # the converge script; the sampling halving comes from config.
        metric_log = {
          collectIntervalMs = 2000;
          skipTtl = true;
        };
        asynchronous_metric_log = { };
        asynchronous_insert_log = { };
        processors_profile_log = { };
        error_log = { };
        crash_log = { };
        histogram_metric_log = { };
        background_schedule_pool_log = { };
        zookeeper_connection_log = { };
        aggregated_zookeeper_log = { };
      };
      clickhouseInternalLogXml = lib.concatStrings (
        lib.mapAttrsToList (
          name: log:
          # Indentation is stripped to zero by the indented-string parser; XML
          # does not care. The flush override is appended inline on the ttl line.
          ''
            <${name}>${
              lib.optionalString (
                !(log ? skipTtl)
              ) "<ttl>event_date + INTERVAL ${toString clickhouseInternalLogTtlDays} DAY DELETE</ttl>"
            }${
              lib.optionalString (
                log ? collectIntervalMs
              ) "<collect_interval_milliseconds>${toString log.collectIntervalMs}</collect_interval_milliseconds>"
            }
            </${name}>
          '') clickhouseInternalLogs
      );

      # Ownership heal for the XFS data partition (2026-08-22 incident): the
      # migrate-clickhouse-xfs.sh runbook copies with rsync -aHAX but has NO
      # chown step — an interrupted first run left parts of the tree (e.g.
      # data/system) non-clickhouse-owned, and the server dies at metadata
      # load with `posix_stat: Permission denied` (statx needs search on every
      # parent; the owner process being denied = mis-owned PARENT dir). The
      # heal only walks; chown -R runs exclusively when a mis-owned inode
      # exists, so healthy starts pay one find pass and no mutations.
      clickhouseOwnershipHeal = pkgs.writeShellApplication {
        name = "clickhouse-xfs-ownership-heal";
        runtimeInputs = [
          pkgs.findutils
          pkgs.coreutils
        ];
        text = ''
          if offender=$(find /var/lib/clickhouse ! -user clickhouse -print -quit) && [ -n "$offender" ]; then
            echo "heal: mis-owned inode found ($offender) — chown -R clickhouse:clickhouse /var/lib/clickhouse"
            chown -R clickhouse:clickhouse /var/lib/clickhouse
          fi
        '';
      };

      # Converge EXISTING tables to the TTL above. The config XML only sets
      # the TTL at table creation (or on lucky restart semantics); tables that
      # predate it — plus zombie `<name>_N` copies left behind by unclean
      # restarts (stale, no longer written, e.g. trace_log_0..17) — never
      # expire until ALTERed. Fully-expired parts are dropped whole by TTL
      # merges (no rewrite IO), so zombie decay is cheap.
      clickhouseLogTtlScript = pkgs.writeShellApplication {
        name = "signoz-clickhouse-log-ttl";
        runtimeInputs = [ pkgs.clickhouse ];
        text = ''
          DAYS=${toString clickhouseInternalLogTtlDays}
          FAMILIES=(${lib.concatStringsSep " " (map (n: "'${n}'") (lib.attrNames clickhouseInternalLogs))})

          # clickhouse.service being "active" only means the listener exists;
          # metadata may still be loading — poll briefly before failing loud.
          ready=false
          for _attempt in $(seq 1 30); do
            if clickhouse-client --query "SELECT 1" >/dev/null 2>&1; then
              ready=true
              break
            fi
            sleep 2
          done
          if [ "$ready" != true ]; then
            echo "FAIL: clickhouse-server did not answer SELECT 1 within 60s" >&2
            exit 1
          fi

          tables_in_family() {
            clickhouse-client --query "SELECT name FROM system.tables WHERE database = 'system' AND name LIKE '$1%' ORDER BY name"
          }

          engine_of() {
            clickhouse-client --query "SELECT engine_full FROM system.tables WHERE database = 'system' AND name = '$1'"
          }

          has_target_ttl() {
            [[ "$(engine_of "$1")" =~ toIntervalDay\($DAYS\) ]]
          }

          # Permanently read-only tables are crash-recovery leftovers (the
          # flag cannot be cleared via SQL; TTL merges and ALTERs refuse).
          # Detected from the ALTER error itself — system.tables has no
          # readonly column in 26.7 — and reported for a human DROP decision
          # instead of failing the run.
          readonly_tables=""
          is_known_readonly() {
            [[ "$readonly_tables" =~ system\.$1( |$) ]]
          }

          partition_tables=""
          is_partition_managed() {
            [[ "$partition_tables" =~ system\.$1( |$) ]]
          }

          changed=0
          unchanged=0
          partition_managed=""
          readonly_skipped=""
          for family in "''${FAMILIES[@]}"; do
            while IFS= read -r table; do
              [ -z "$table" ] && continue
              if has_target_ttl "$table"; then
                unchanged=$((unchanged + 1))
                continue
              fi
              # max_execution_time=0: the default profile may cap sessions;
              # MODIFY TTL can queue behind TTL merges triggered by earlier
              # ALTERs in this same pass (exclusive table lock) — cancel-type
              # errors are transient, so retry a few times before failing.
              error=""
              attempt=0
              while [ "$attempt" -lt 3 ]; do
                attempt=$((attempt + 1))
                error=$(clickhouse-client --max_execution_time 0 --query "ALTER TABLE system.$table MODIFY TTL event_date + INTERVAL $DAYS DAY DELETE" 2>&1) && error=""
                if [ -z "$error" ]; then
                  break
                fi
                if [[ "$error" =~ QUERY_WAS_CANCELLED ]] && [ "$attempt" -lt 3 ]; then
                  echo "system.$table: ALTER cancelled (lock contention with fresh TTL merges), retry $attempt/3"
                  sleep 10
                else
                  break
                fi
              done
              if [ -z "$error" ]; then
                echo "system.$table: applying $DAYS-day TTL"
                changed=$((changed + 1))
                continue
              fi
              if [[ "$error" =~ QUERY_IS_TOO_LARGE ]]; then
                # Wide table (column per metric): metadata rewrite is refused.
                # Fall back to monthly partition drops — whole partitions older
                # than the retention window are unlinked without any metadata
                # change and without rewriting surviving parts.
                echo "system.$table: metadata too large for MODIFY TTL — using monthly partition drops"
                cutoff=$(date -d "-$DAYS days" +%Y%m)
                dropped=0
                while IFS= read -r partition; do
                  [ -z "$partition" ] && continue
                  if [ "$partition" -lt "$cutoff" ]; then
                    clickhouse-client --query "ALTER TABLE system.$table DROP PARTITION '$partition'"
                    echo "system.$table: dropped partition $partition"
                    dropped=$((dropped + 1))
                  fi
                done < <(clickhouse-client --query "SELECT DISTINCT partition FROM system.parts WHERE database = 'system' AND table = '$table' AND active ORDER BY partition")
                partition_managed="$partition_managed system.$table($dropped)"
                partition_tables="$partition_tables system.$table"
                continue
              fi
              if [[ "$error" =~ TABLE_IS_PERMANENTLY_READ_ONLY ]]; then
                readonly_tables="$readonly_tables system.$table"
                readonly_skipped="$readonly_skipped system.$table"
                continue
              fi
              echo "FAIL: ALTER TABLE system.$table MODIFY TTL: $error" >&2
              exit 1
            done < <(tables_in_family "$family")
          done

          # Convergence assertion (fail-closed): after the ALTER pass, no
          # table in any family may lack the target TTL. Wide partition-managed
          # tables are re-tried (and re-fall-back) on every run — that is their
          # recurring retention mechanism — so they must NOT appear here.
          missing=""
          for family in "''${FAMILIES[@]}"; do
            while IFS= read -r table; do
              [ -z "$table" ] && continue
              if is_known_readonly "$table"; then
                continue
              fi
              if is_partition_managed "$table"; then
                continue
              fi
              if ! has_target_ttl "$table"; then
                missing="$missing system.$table"
              fi
            done < <(tables_in_family "$family")
          done
          if [ -n "$missing" ]; then
            echo "FAIL: tables without $DAYS-day TTL:$missing" >&2
            exit 1
          fi

          echo "clickhouse internal log TTLs converged: $changed altered, $unchanged already at $DAYS days, partition-managed:$partition_managed"
          if [ -n "$readonly_skipped" ]; then
            echo "WARNING: permanently read-only tables skipped (crash-recovery leftovers; consider DROP):$readonly_skipped"
          fi
        '';
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
              journaldLogs = lib.mkEnableOption "journald log collection via OTel receiver" // {
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
                # Static frontend (flake input -> pnpm/rolldown-vite build ->
                # $out/share/signoz/web, symlinked to /etc/signoz/web below).
                # The Go binary templates [[.BaseHref]]/[[.Settings]] into
                # index.html at startup and serves SPA fallbacks itself.
                enabled = true;
              };
              alertmanager = {
                signoz = {
                  # Base URL baked into fired alerts (ruleSource label → the
                  # links Discord messages show). SigNoz defaults to
                  # http://localhost:8080, which is useless from Discord.
                  external_url = "https://signoz.${config.networking.domain}";
                };
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
                # Halves the asynchronous metrics sampling rate (1 Hz -> 0.5 Hz):
                # this is what drives asynchronous_metric_log row volume (one row
                # per metric per update tick, ~750 metrics = 56M rows/day at 1s).
                # Also makes the /metrics prometheus endpoint up to 2s stale —
                # invisible at 15s+ scrape intervals.
                <asynchronous_metrics_update_period_s>2</asynchronous_metrics_update_period_s>
              ${clickhouseInternalLogXml}
                <prometheus>
                  <endpoint>/metrics</endpoint>
                  <port>${toString ports.signoz-clickhouse-metrics}</port>
                  <metrics>true</metrics>
                  <events>true</events>
                  <asynchronous_metrics>true</asynchronous_metrics>
                </prometheus>
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
              # extraServerConfig lands as an etc file; the nixpkgs module has
              # no restartTriggers for it, so config edits (e.g. the prometheus
              # metrics endpoint) deploys silently inert until a manual restart.
              restartTriggers = [
                config.environment.etc."clickhouse-server/config.d/200-nixos-module-extra-config.xml".source
              ];
              # Only when the host declares the dedicated data mount (see
              # hasClickhouseDataMount above). RequiresMountsFor adds
              # Requires=+After= on var-lib-clickhouse.mount; the Condition
              # is evaluated after those dependencies are up, so the path is
              # a mountpoint exactly when the mount succeeded. Belt AND
              # suspenders: either one alone has a hole (Requires without
              # the Condition tolerates a leftover plain dir if the mount
              # unit were masked; the Condition alone doesn't order).
              unitConfig = lib.optionalAttrs hasClickhouseDataMount {
                RequiresMountsFor = "/var/lib/clickhouse";
                ConditionPathIsMountPoint = "/var/lib/clickhouse";
              };
              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "4G";
                  ReadWritePaths = [
                    "/var/lib/clickhouse"
                    "/var/log/clickhouse-server"
                  ];
                })
                (serviceDefaults { })
                ioTier.heavyDB
                # Root-escape (`+`) ExecStartPre: the ownership heal runs as
                # PID-1 privileges (harden{}'s empty CapabilityBoundingSet
                # would EPERM chown inside the sandbox). Gated on the XFS
                # mount host — the plain-state-dir hosts need no heal.
                (lib.optionalAttrs hasClickhouseDataMount {
                  ExecStartPre = [ "+${lib.getExe clickhouseOwnershipHeal}" ];
                })
              ];
            };

            systemd.services.signoz-clickhouse-log-ttl = {
              description = "ClickHouse internal log TTL convergence (14d retention, incl. zombie _N tables)";
              after = [ "clickhouse.service" ];
              wants = [ "clickhouse.service" ];
              # Re-converge whenever clickhouse restarts (incl. config-triggered
              # restarts via its restartTriggers).
              partOf = [ "clickhouse.service" ];
              inherit onFailure;
              wantedBy = [ "multi-user.target" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              restartTriggers = [ (lib.getExe clickhouseLogTtlScript) ];
              serviceConfig = lib.mkMerge [
                (harden { MemoryMax = "256M"; })
                {
                  Type = "oneshot";
                  RemainAfterExit = true;
                }
              ];
              script = lib.getExe clickhouseLogTtlScript;
            };

            # Recurring retention: TTL families self-manage via background
            # TTL merges, but the wide partition-managed tables (metric_log)
            # only drop old months when this runs — hence a daily timer,
            # staggered clear of the 01:00-04:00 backup window.
            systemd.timers.signoz-clickhouse-log-ttl = {
              description = "Daily ClickHouse internal log retention pass";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "04:20";
                Persistent = true;
                Unit = "signoz-clickhouse-log-ttl.service";
              };
            };

            # ── Dedicated XFS data mount monitoring (buildcache pattern) ──────
            # The XFS filesystem at /var/lib/clickhouse is invisible to
            # btrfs-health metrics by design; these gauges close that hole.
            # Fail-closed: the .prom file is written on EVERY run (a dead/
            # absent mount flips clickhouse_xfs_mounted to 0 → Gatus alerts),
            # and "mounted" gates on REAL I/O, not mount-table presence —
            # a zombie VFS entry (stale major:minor after device churn)
            # satisfies findmnt while every read EIOs.
            systemd.services.clickhouse-xfs-metrics = lib.mkIf hasClickhouseDataMount (
              let
                textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
                mnt = "/var/lib/clickhouse";
                usageThresholdPercent = 85;
              in
              {
                description = "ClickHouse XFS data mount Prometheus metrics (mount, usage)";
                startLimitBurst = 3;
                startLimitIntervalSec = 300;
                inherit onFailure;
                path = [
                  pkgs.util-linux
                  pkgs.coreutils
                  pkgs.gnugrep
                ];
                serviceConfig = lib.mkMerge [
                  {
                    Type = "oneshot";
                    User = "root";
                  }
                  (harden {
                    ReadWritePaths = [ textfileDir ];
                    MemoryMax = "128M";
                  })
                  (serviceOneshotDefaults { })
                ];
                script = ''
                  set -eu
                  OUT="${textfileDir}/clickhouse-xfs.prom"
                  TMP="''${OUT}.tmp"
                  mnt="${mnt}"
                  threshold=${toString usageThresholdPercent}

                  mounted=0
                  fstype=""
                  if
                    findmnt -n -o TARGET "$mnt" 2>/dev/null | grep -qx "$mnt" \
                      && timeout 15 ls -A "$mnt" >/dev/null 2>&1
                  then
                    mounted=1
                    fstype="$(findmnt -no FSTYPE "$mnt" 2>/dev/null || echo unknown)"
                  fi

                  usage=0
                  over=0
                  free_bytes=0
                  total_bytes=0
                  if [ "$mounted" = 1 ]; then
                    usage="$(df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9')"
                    free_bytes="$(df -B1 --output=avail "$mnt" | tail -n1 | tr -dc '0-9')"
                    total_bytes="$(df -B1 --output=size "$mnt" | tail -n1 | tr -dc '0-9')"
                    if [ "''${usage:-0}" -ge "$threshold" ] 2>/dev/null; then
                      over=1
                    fi
                  fi

                  # xfs_mounted doubles as the "is actually XFS" signal: the
                  # check is written as a separate gauge so a misconfigured
                  # mount (wrong fs on the partition) is distinguishable from
                  # a dead one.
                  is_xfs=0
                  if [ "$fstype" = "xfs" ]; then
                    is_xfs=1
                  fi

                  mkdir -p "${textfileDir}"
                  cat > "$TMP" <<METRICS
                  # HELP clickhouse_xfs_mounted 1 if the ClickHouse data mount is mounted and answering I/O, 0 otherwise
                  # TYPE clickhouse_xfs_mounted gauge
                  clickhouse_xfs_mounted ''${mounted}
                  # HELP clickhouse_xfs_is_xfs 1 if the mounted filesystem type is xfs (0 = wrong fs or unmounted)
                  # TYPE clickhouse_xfs_is_xfs gauge
                  clickhouse_xfs_is_xfs ''${is_xfs}
                  # HELP clickhouse_xfs_usage_percent ClickHouse data filesystem usage percentage (0-100)
                  # TYPE clickhouse_xfs_usage_percent gauge
                  clickhouse_xfs_usage_percent ''${usage}
                  # HELP clickhouse_xfs_usage_over_threshold 1 if usage >= ${toString usageThresholdPercent}%
                  # TYPE clickhouse_xfs_usage_over_threshold gauge
                  clickhouse_xfs_usage_over_threshold ''${over}
                  # HELP clickhouse_xfs_free_bytes Free bytes on the ClickHouse data filesystem
                  # TYPE clickhouse_xfs_free_bytes gauge
                  clickhouse_xfs_free_bytes ''${free_bytes}
                  # HELP clickhouse_xfs_total_bytes Total bytes on the ClickHouse data filesystem
                  # TYPE clickhouse_xfs_total_bytes gauge
                  clickhouse_xfs_total_bytes ''${total_bytes}
                  METRICS
                  mv "$TMP" "$OUT"
                '';
              }
            );

            systemd.timers.clickhouse-xfs-metrics = lib.mkIf hasClickhouseDataMount {
              description = "Collect ClickHouse XFS data mount metrics every 5 minutes";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "2min";
                OnUnitActiveSec = "5min";
                Persistent = true;
              };
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
              # The rules engine bakes external_url into every rule object at
              # construction (startup); without this trigger signoz.yaml
              # changes never apply — the 2026-08-16 ruleSource=localhost bug
              # was exactly this: config deployed, process never restarted.
              # The web dist is also read/indexed at startup only.
              restartTriggers = [
                config.environment.etc."signoz/signoz.yaml".source
                config.environment.etc."signoz/web".source
              ];
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
                    in
                    "${lib.getExe wrapper}";
                  ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://${cfg.settings.queryService.host}:${toString cfg.settings.queryService.port}/api/v1/version";
                  TimeoutStartSec = "3min";
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
                ioTier.background
                {
                  Environment = [ "GOMEMLIMIT=768MiB" ];
                }
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
              restartTriggers = [
                (lib.getExe provisionScript)
              ]
              ++ lib.catAttrs "source" (lib.attrValues alerts.rules)
              ++ lib.catAttrs "source" (lib.attrValues alerts.dashboards);
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
              preStart = lib.getExe waitReadyScript;
              script = lib.getExe provisionScript;
            };

            environment.etc =
              alerts.rules
              // alerts.dashboards
              // {
                "signoz/web".source = "${packages.frontend}/share/signoz/web";
              };
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
              # The collector reads its config at startup only — without this
              # trigger a new collector.yaml deploys silently inert (same trap
              # class as the signoz.yaml ruleSource=localhost bug).
              restartTriggers = [
                config.environment.etc."signoz/collector.yaml".source
              ];
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
                ioTier.background
                {
                  # 75% of MemoryMax (1G) — matches the query service pattern.
                  # Was 384MiB (37.5%, cargo-culted from a 512M service) since
                  # the ZRAM tuning commit; normalized 2026-08-14.
                  Environment = [ "GOMEMLIMIT=768MiB" ];
                }
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
                      {
                        # The collector's own self-metrics (bound to :8888 by
                        # the OTel runtime): receiver accepted/sent rates,
                        # export failures, processor drops, process health.
                        # Feeds the overview dashboard telemetry panels and the
                        # Telemetry Collector Down / Export Failures alerts.
                        job_name = "signoz-collector";
                        static_configs = [ { targets = [ "127.0.0.1:${toString ports.signoz-collector-metrics}" ]; } ];
                      }
                      {
                        # ClickHouse's own prometheus endpoint (enabled in
                        # extraServerConfig below): uptime, parts, merges,
                        # memory, disks — the telemetry store observing itself.
                        job_name = "clickhouse";
                        static_configs = [ { targets = [ "127.0.0.1:${toString ports.signoz-clickhouse-metrics}" ]; } ];
                        metrics_path = "/metrics";
                      }
                      {
                        # Docker engine metrics (metrics-addr in
                        # default-services.nix): container counts, daemon health.
                        job_name = "docker-engine";
                        static_configs = [ { targets = [ "127.0.0.1:${toString ports.docker-engine-metrics}" ]; } ];
                        metrics_path = "/metrics";
                      }
                    ];
                  };
                };
              }
              // lib.optionalAttrs cfg.components.journaldLogs {
                journald = {
                  directory = "/var/log/journal";
                  # Whole-journal collection at info+ (PRIORITY 0-5). The old
                  # 10-unit warning-only config produced ~100 rows/day of raw
                  # JSON dumps with no severity/service metadata. Total journal
                  # volume is ~5 MB/h (~6 entries/s) — measured 2026-08-16,
                  # 500x below the 2026-08 CPU-burn era (monitor365-server at
                  # 900 entries/s). journald's own per-unit rate limiting
                  # (10k/30s) bounds a recurrence; the collector self-scrape
                  # + export-failure alert watch the pipeline.
                  all = true;
                  priority = "info";
                  # NEVER "beginning": without persistent cursor state a
                  # restart would re-ingest the entire journal.
                  start_at = "end";
                };
              };
              processors = {
                # journald entries arrive as body=Map(every journal field),
                # no severity, no service.name. Extract the useful shape:
                # body=MESSAGE, severity from PRIORITY (string "0".."7"),
                # resource service.name from the unit (containers win).
                # OTLP logs from instrumented services pass through untouched
                # (guarded on IsMap(body) + PRIORITY, which only journald has).
                "transform/journald" =
                  let
                    journaldGuard = ''IsMap(body) and body["PRIORITY"] != nil'';
                    # One OTTL statement per list element — the receiver does
                    # not split embedded newlines.
                    severity = prio: num: text: [
                      ''set(severity_number, ${num}) where ${journaldGuard} and body["PRIORITY"] == "${prio}"''
                      ''set(severity_text, "${text}") where ${journaldGuard} and body["PRIORITY"] == "${prio}"''
                    ];
                  in
                  {
                    log_statements = [
                      {
                        context = "log";
                        statements = [
                          ''set(attributes["systemd_unit"], body["_SYSTEMD_UNIT"]) where ${journaldGuard} and body["_SYSTEMD_UNIT"] != nil''
                          ''set(attributes["syslog_identifier"], body["SYSLOG_IDENTIFIER"]) where ${journaldGuard} and body["SYSLOG_IDENTIFIER"] != nil''
                          ''set(attributes["pid"], body["_PID"]) where ${journaldGuard} and body["_PID"] != nil''
                          ''set(attributes["container_name"], body["CONTAINER_NAME"]) where ${journaldGuard} and body["CONTAINER_NAME"] != nil''
                          ''set(attributes["code_file"], body["CODE_FILE"]) where ${journaldGuard} and body["CODE_FILE"] != nil''
                          ''set(attributes["code_func"], body["CODE_FUNC"]) where ${journaldGuard} and body["CODE_FUNC"] != nil''
                          # service.name precedence: kernel identifier < unit < container
                          ''set(resource.attributes["service.name"], body["SYSLOG_IDENTIFIER"]) where ${journaldGuard} and body["SYSLOG_IDENTIFIER"] != nil''
                          ''set(resource.attributes["service.name"], body["_SYSTEMD_UNIT"]) where ${journaldGuard} and body["_SYSTEMD_UNIT"] != nil''
                          ''set(resource.attributes["service.name"], body["CONTAINER_NAME"]) where ${journaldGuard} and body["CONTAINER_NAME"] != nil''
                        ]
                        ++ severity "0" "SEVERITY_NUMBER_FATAL" "FATAL"
                        ++ severity "1" "SEVERITY_NUMBER_FATAL" "FATAL"
                        ++ severity "2" "SEVERITY_NUMBER_FATAL" "FATAL"
                        ++ severity "3" "SEVERITY_NUMBER_ERROR" "ERROR"
                        ++ severity "4" "SEVERITY_NUMBER_WARN" "WARN"
                        ++ severity "5" "SEVERITY_NUMBER_INFO" "INFO"
                        ++ severity "6" "SEVERITY_NUMBER_DEBUG" "DEBUG"
                        ++ severity "7" "SEVERITY_NUMBER_TRACE" "TRACE"
                        ++ [
                          # MUST be last: replaces the map body, after which
                          # the field accesses above would return nil.
                          ''set(body, body["MESSAGE"]) where ${journaldGuard} and body["MESSAGE"] != nil''
                        ];
                      }
                    ];
                  };
                memory_limiter = {
                  check_interval = "1s";
                  limit_mib = 768;
                  spike_limit_mib = 192;
                };
                batch = {
                  timeout = "5s";
                  send_batch_size = 8192;
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
                    # memory_limiter MUST be first; batch last.
                    processors = [
                      "memory_limiter"
                      "batch"
                    ];
                    exporters = [ "clickhousetraces" ];
                  };
                  metrics = {
                    receivers = [ "otlp" ] ++ lib.optional cfg.components.nodeExporter "prometheus";
                    processors = [
                      "memory_limiter"
                      "batch"
                    ];
                    exporters = [ "signozclickhousemetrics" ];
                  };
                  logs = {
                    receivers = [
                      "otlp"
                    ]
                    ++ lib.optional cfg.components.journaldLogs "journald";
                    processors = [
                      "memory_limiter"
                      "transform/journald"
                      "batch"
                    ];
                    exporters = [ "clickhouselogsexporter" ];
                  };
                };
              };
            };
          })

          { }

          {
            assertions = lib.optionals cfg.enable [
              {
                assertion =
                  !(lib.hasInfix "<background_pool_size>2</background_pool_size>" (
                    config.services.clickhouse.extraServerConfig or ""
                  ));
                message = "signoz: background_pool_size=2 triggers ClickHouse merge_tree sanity check failures. Use the default (16).";
              }
            ];
          }
        ]
      );
    };
}
