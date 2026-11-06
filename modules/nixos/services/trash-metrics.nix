# Runbook: docs/services/trash-metrics.md
# Trash-size textfile collector.
#
# 2026-11-06: 55G of tmp Go caches sat parked invisible in
# ~/.local/share/Trash for a month (2026-10-08 →) — no metric, no alert,
# no closing loop (storage.md "make parked-trash size observable" row).
# This collector makes every trash location on the box observable;
# companion legs are the trash-prune user timer (30d age expiry) and the
# pre-deploy-check §20 warning threshold.
_: {
  flake.nixosModules.trash-metrics =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ;

      cfg = config.services.trash-metrics;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      collectorScript = pkgs.writeShellApplication {
        name = "trash-size-metrics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
        ];
        # Single source of truth: the committed script (shellcheck'd by
        # pre-commit, selftested via `trash-size-metrics.sh selftest`).
        text = builtins.readFile ../../../scripts/trash-size-metrics.sh;
      };
    in
    {
      options.services.trash-metrics = {
        enable = lib.mkEnableOption "trash-size textfile collector (trash_size_bytes per trash location)";

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/home/lars/.local/share/Trash"
            "/data/.Trash-1000"
          ];
          description = "Trash locations to size. A missing dir emits 0 (honest no-trash), so the gauge family never goes absent";
        };

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "1h";
          description = "Timer cadence. du over trash trees is cheap and the burn-down is day-scale; hourly keeps the pre-deploy leg's number fresh without IO pressure";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.trash-metrics = {
            description = "Trash-size textfile collector (trash_size_bytes per trash location)";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "64M";
                # Same sticky-textfile-dir reclaim rationale as the memory
                # guard and bun watchdog: a foreign-owned stale .prom must
                # not wedge the atomic rename.
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = lib.getExe collectorScript;
                Environment = [
                  "TRASH_METRICS_PATHS=${lib.concatStringsSep " " cfg.paths}"
                ];
                ReadWritePaths = [ textfileDir ];
                # Reading /home and /data trash trees needs nothing extra
                # under harden{}: ProtectSystem makes them read-only, and
                # reads are all this collector does.
              }
            ];
          };

          timers.trash-metrics = {
            description = "Run the trash-size collector";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = cfg.checkInterval;
            };
          };
        };
      };
    };
}
