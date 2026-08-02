# Cross-service backup health monitoring.
#
# Generates Prometheus textfile metrics for all configured backup directories,
# so Gatus can alert when any backup is stale (>maxAgeHours). Staggered backup
# schedules avoid IO spikes: Immich 01:00, Twenty 02:00, Manifest 02:30,
# Monitor365 03:00 (set in each service's timer config).
#
# Replaces the former monitor365-backup-health service — the generic module
# covers monitor365 via the "monitor365" backup entry in configuration.nix.
_: {
  flake.nixosModules.backup-coordination = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (import ../../../lib/default.nix lib) harden serviceOneshotDefaults onFailure;
    cfg = config.services.backup-coordination;

    textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

    metricsScript = pkgs.writeShellApplication {
      name = "backup-health-metrics";
      runtimeInputs = [pkgs.coreutils pkgs.findutils];
      text = ''
        OUT="${textfileDir}/backups.prom"
        NOW="$(date +%s)"
        TEMP="$OUT.tmp"
        ANY_UNHEALTHY=0

        # Ensure the textfile collector directory exists (defense-in-depth —
        # ReadWritePaths should handle this, but the dir may be missing on
        # first boot before prometheus-node-exporter has run).
        mkdir -p "${textfileDir}"

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: backup: let
              pattern =
                if backup.filePattern != null
                then backup.filePattern
                else "*";
            in ''
              # Backup: ${name}
              BACKUP_DIR="${backup.directory}"
              PATTERN="${pattern}"
              MAX_AGE="${toString backup.maxAgeHours}"
              # || true handles: find exit non-zero (dir missing), head SIGPIPE
              LATEST="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "$PATTERN" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2 || true)"
              if [ -n "$LATEST" ] && [ -e "$LATEST" ]; then
                MTIME="$(stat -c %Y "$LATEST" 2>/dev/null || echo 0)"
                AGE_HOURS=$(( (NOW - MTIME) / 3600 ))
                HEALTHY=1
                [ "$AGE_HOURS" -gt "$MAX_AGE" ] && HEALTHY=0
              else
                MTIME=0
                AGE_HOURS=999
                HEALTHY=0
              fi
              [ "$HEALTHY" -eq 0 ] && ANY_UNHEALTHY=1
              {
                echo "backup_healthy{backup=\"${name}\"} $HEALTHY"
                echo "backup_age_hours{backup=\"${name}\"} $AGE_HOURS"
                echo "backup_last_success_timestamp{backup=\"${name}\"} $MTIME"
              } >> "$TEMP"
            ''
          )
          cfg.backups
        )}

        echo "backup_all_healthy $([ "$ANY_UNHEALTHY" -eq 0 ] && echo 1 || echo 0)" >> "$TEMP"
        mv "$TEMP" "$OUT"
      '';
    };
  in {
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
        default = {};
        description = "Backup definitions to monitor for freshness";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.backup-health-metrics = {
        description = "Cross-service backup health metrics for Prometheus textfile";
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          (harden {
            MemoryMax = "128M";
            # Runs as root: backup dirs are owned by different users
            # (immich, twenty, manifest, monitor365-server). Root can read
            # all of them and write to the textfile collector dir.
            # ProtectSystem=full (default) only makes /usr and /boot
            # read-only — /var/lib backup dirs remain readable.
            ReadWritePaths = [textfileDir];
          })
          (serviceOneshotDefaults {})
          {
            Type = "oneshot";
          }
        ];
        path = [metricsScript];
        script = ''
          backup-health-metrics
        '';
      };

      systemd.timers.backup-health-metrics = {
        description = "Collect backup health metrics";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "5m";
        };
      };
    };
  };
}
