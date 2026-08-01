# Cross-service backup health monitoring.
#
# Generates Prometheus textfile metrics for all configured backup directories,
# so Gatus can alert when any backup is stale (>maxAgeHours). Staggered backup
# schedules avoid IO spikes: Immich 01:00, Twenty 02:00, Manifest 02:30,
# Monitor365 03:00 (set in each service's timer config).
#
# monitor365-backup-health (in monitor365.nix) is the reference implementation.
# This module generalizes the pattern for all services.
_: {
  flake.nixosModules.backup-coordination =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.backup-coordination;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      metricsScript = pkgs.writeShellApplication {
        name = "backup-health-metrics";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          OUT="${textfileDir}/backups.prom"
          NOW="$(date +%s)"
          TEMP="$OUT.tmp"
          ANY_UNHEALTHY=0

          ${
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: backup:
                let
                  pattern =
                    if backup.filePattern != null then backup.filePattern else "*";
                in
                ''
                  # Backup: ${name}
                  BACKUP_DIR="${backup.directory}"
                  PATTERN="${pattern}"
                  MAX_AGE="${toString backup.maxAgeHours}"
                  LATEST="$(ls -t "$BACKUP_DIR"/$PATTERN 2>/dev/null | head -1)"
                  if [ -n "$LATEST" ]; then
                    MTIME="$(stat -c %Y "$LATEST")"
                    AGE_HOURS=$(( (NOW - MTIME) / 3600 ))
                    HEALTHY=1
                    [ "$AGE_HOURS" -gt "$MAX_AGE" ] && HEALTHY=0
                  else
                    MTIME=0
                    AGE_HOURS=999
                    HEALTHY=0
                  fi
                  [ "$HEALTHY" -eq 0 ] && ANY_UNHEALTHY=1
                  echo "backup_healthy{backup=\"${name}\"} $HEALTHY" >> "$TEMP"
                  echo "backup_age_hours{backup=\"${name}\"} $AGE_HOURS" >> "$TEMP"
                  echo "backup_last_success_timestamp{backup=\"${name}\"} $MTIME" >> "$TEMP"
                ''
              ) cfg.backups
            )
          }

          echo "backup_all_healthy $([ "$ANY_UNHEALTHY" -eq 0 ] && echo 1 || echo 0)" >> "$TEMP"
          mv "$TEMP" "$OUT"
        '';
      };
    in
    {
      options.services.backup-coordination = {
        enable = lib.mkEnableOption "Cross-service backup health monitoring via Prometheus textfile metrics";

        backups = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                directory = lib.mkOption {
                  type = lib.types.str;
                  description = "Directory containing backup files";
                };
                filePattern = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Glob pattern for backup files (default: *)";
                };
                maxAgeHours = lib.mkOption {
                  type = lib.types.int;
                  default = 25;
                  description = "Maximum age in hours before backup is considered stale";
                };
              };
            }
          );
          default = { };
          description = "Backup definitions to monitor for freshness";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.backup-health-metrics = {
          description = "Cross-service backup health metrics for Prometheus textfile";
          serviceConfig = {
            Type = "oneshot";
            # Runs as root: backup dirs are owned by different users
            # (immich, twenty, manifest, monitor365-server). Root can read
            # all of them and write to the textfile collector dir.
            ReadWritePaths = [ textfileDir ];
          };
          path = [ metricsScript ];
          script = ''
            backup-health-metrics
          '';
        };

        systemd.timers.backup-health-metrics = {
          description = "Collect backup health metrics";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "5m";
          };
        };
      };
    };
}
