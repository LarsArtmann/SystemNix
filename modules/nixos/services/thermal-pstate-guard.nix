# Runbook: docs/services/thermal-pstate-guard.md
# Thermal pstate guard.
#
# The freeze #8-#14 family (2026-10-01 → 10-04, seven crashes, accelerating to
# two inside 88 minutes) all died the same death: Tctl pinned at the ~99 °C
# hardware ceiling on a standing cooling deficit, then an instant EC power cut
# mid-traffic (docs/status/2026-10-04_05-22_freeze-14-autopsy-*). The sustained
# heat load is the chronic zone-6 IO storm plus nix build/eval bursts; the
# accelerant is our own pstate configuration — the performance governor pins
# max clocks under ANY load, so every storm rides the ceiling instead of
# backing off. This box exposes no OS-side PPT control (no ryzen_smu for
# Strix Halo, no RAPL constraints, no BIOS platform profile — boot.nix), so
# the amd_pstate driver mode is the ONLY frequency lever.
#
# The guard flips it:
#   normal  = "active" + performance governor + performance EPP (max clocks)
#   hot     = "guided" (GMKtec firmware picks frequencies within thermal
#             headroom) when any monitored sensor sustains its high threshold
#             for enterTicks consecutive 10 s ticks
#   restore = "active" + snapshotted governor/EPP once ALL sensors sit at or
#             below their low thresholds for exitTicks ticks
#
# A written gate ("NO heavy builds") was violated within the hour it was
# written (freeze-14's death-minute nix burst) — this guard is the enforcement
# leg that does not depend on anyone reading a report. It does NOT replace the
# physical cooling inspection (stability.md:117): if the firmware's guided
# policy is as dumb as its fan control, only the inspection fixes the deficit.
#
# Metric freshness follows the memory-guard doctrine: the .prom is rewritten
# atomically on every tick and stamps last_run_timestamp_seconds, so a dead
# guard is detectable by staleness (gatus wiring tracked separately).
_:
{
  flake.nixosModules.thermal-pstate-guard =
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

      cfg = config.services.thermal-pstate-guard;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      guardScript = pkgs.writeShellApplication {
        name = "thermal-pstate-guard-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
        ];
        # Single source of truth: the committed script (shellcheck'd by
        # pre-commit, fixture-tested by checks.thermal-pstate-guard-selftest).
        text = builtins.readFile ../../../scripts/thermal-pstate-guard.sh;
      };

      sensorSpec = lib.concatStringsSep " " (
        map (s: "${s.name}:${toString s.highCelsius}:${toString s.lowCelsius}") cfg.sensors
      );
    in
    {
      options.services.thermal-pstate-guard = {
        enable = lib.mkEnableOption "thermal pstate guard (amd_pstate active<->guided switching on hwmon hysteresis)";

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "10s";
          description = "Timer cadence. The freeze-series climb from ~90 °C to the cut took minutes; 10 s catches it with wide margin while staying a cheap oneshot";
        };

        enterTicks = lib.mkOption {
          type = lib.types.int;
          default = 2;
          description = "Consecutive hot ticks before switching to guided (debounce against single-sample spikes)";
        };

        exitTicks = lib.mkOption {
          type = lib.types.int;
          default = 12;
          description = "Consecutive all-cool ticks before restoring active (dwell; a mid-band excursion resets the counter). Default 2 min at the default cadence";
        };

        verboseIntervalSeconds = lib.mkOption {
          type = lib.types.int;
          default = 600;
          description = "Minimum seconds between two 'still throttled' log lines (action/transition lines always log immediately)";
        };

        normalGovernor = lib.mkOption {
          type = lib.types.str;
          default = "performance";
          description = "Governor restored for every policy when returning to active without a snapshot (external-mode adoption)";
        };

        normalEpp = lib.mkOption {
          type = lib.types.str;
          default = "performance";
          description = "EPP restored for every policy when returning to active without a snapshot";
        };

        sensors = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "hwmon name (the `name` attribute under /sys/class/hwmon/hwmon*), NOT the unstable hwmon index";
                };
                highCelsius = lib.mkOption {
                  type = lib.types.int;
                  description = "Enter-throttle threshold: max temp*_input at or above this (any matching sensor) counts as hot";
                };
                lowCelsius = lib.mkOption {
                  type = lib.types.int;
                  description = "Exit-throttle threshold: every matching sensor must be at or below this for the restore dwell to progress";
                };
              };
            }
          );
          default = [
            {
              name = "k10temp";
              highCelsius = 95;
              lowCelsius = 80;
            }
            {
              name = "nvme";
              highCelsius = 70;
              lowCelsius = 60;
            }
            {
              name = "amdgpu";
              highCelsius = 90;
              lowCelsius = 75;
            }
            {
              name = "acpitz";
              highCelsius = 85;
              lowCelsius = 70;
            }
          ];
          description = "Sensor patterns with hysteresis thresholds. Defaults: k10temp enters at 95 (the freeze family rode 98.4-99.1) and exits at 80; nvme at 70/60; amdgpu edge at 90/75; acpitz at 85/70 (freeze-12 measured 98 at death). Absent patterns never vote and are counted in thermal_pstate_guard_sensors_missing";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.thermal-pstate-guard = {
            description = "Thermal pstate guard: switch amd_pstate to guided at the thermal ceiling, restore active when cool";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "32M";
                # Same sticky-textfile-dir reclaim rationale as the memory
                # guard: a foreign-owned stale .prom must not wedge the
                # atomic rename exactly when the guard matters most.
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                StateDirectory = "thermal-pstate-guard";
                ExecStart = lib.getExe guardScript;
                Environment = [
                  "THERMAL_GUARD_SENSORS=${sensorSpec}"
                  "THERMAL_GUARD_ENTER_TICKS=${toString cfg.enterTicks}"
                  "THERMAL_GUARD_EXIT_TICKS=${toString cfg.exitTicks}"
                  "THERMAL_GUARD_VERBOSE_INTERVAL=${toString cfg.verboseIntervalSeconds}"
                  "THERMAL_GUARD_NORMAL_GOVERNOR=${cfg.normalGovernor}"
                  "THERMAL_GUARD_NORMAL_EPP=${cfg.normalEpp}"
                ];
                ReadWritePaths = [ textfileDir ];
                # /sys writes need nothing extra under harden{}: ProtectSystem
                # exempts the API subtrees /dev, /proc, /sys.
              }
            ];
          };

          timers.thermal-pstate-guard = {
            description = "Run the thermal pstate guard check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1min";
              OnUnitActiveSec = cfg.checkInterval;
            };
          };
        };
      };
    };
}
