# Runbook: docs/services/bun-memory-watchdog.md
# Bun memory watchdog.
#
# 2026-10-10 near-freeze: `bun test` (the qmd mcp toolchain that agent
# sessions spawn) climbed past 70 GB RSS on the 128 GB host with no natural
# ceiling and took the box to the edge of the memory-emergency-guard's trip
# zone. Bun processes cannot be capped by a systemd unit — agent sessions
# spawn them as plain user processes inside session scopes — so the only
# launcher-agnostic containment is a periodic /proc sweep that SIGKILLs any
# bun whose VmRSS crosses the kill threshold.
#
# Design contract:
#   - match on the RESOLVED /proc/PID/exe basename (exact, never a cmdline
#     substring or pattern), re-verified immediately before the kill
#     (PID-reuse guard)
#   - default threshold 16 GiB VmRSS: the 2026-10-10 offender sat at ~70 GB
#     before anything reacted; 16 GiB leaves headroom for legitimate bun
#     workloads while stopping a leak two orders of magnitude earlier
#   - SIGKILL, not a graceful term: the user-facing contract is "crash kill"
#     — a bun already leaking past 16 GiB has nothing worth saving
#   - BUN_WATCHDOG_DRY_RUN_FILE turns kills into append-only records; the
#     fixture selftest (checks.bun-memory-watchdog-selftest) and manual
#     drills use it; the production unit never sets it
#   - metric freshness follows the memory-guard doctrine: the .prom is
#     rewritten atomically every tick and stamps last_run_timestamp_seconds,
#     so a dead watchdog is detectable by staleness (gatus wiring tracked
#     separately, same as the thermal guard at introduction)
_: {
  flake.nixosModules.bun-memory-watchdog =
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

      cfg = config.services.bun-memory-watchdog;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      watchdogScript = pkgs.writeShellApplication {
        name = "bun-memory-watchdog-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
        ];
        # Single source of truth: the committed script (shellcheck'd by
        # pre-commit, fixture-tested by checks.bun-memory-watchdog-selftest).
        text = builtins.readFile ../../../scripts/bun-memory-watchdog.sh;
      };
    in
    {
      options.services.bun-memory-watchdog = {
        enable = lib.mkEnableOption "bun memory watchdog (SIGKILL bun processes crossing the RSS kill threshold)";

        checkInterval = lib.mkOption {
          type = lib.types.str;
          default = "30s";
          description = "Timer cadence. The 2026-10-10 offender grew from idle to 70 GB within one agent-session task; 30 s bounds the worst-case overshoot while staying a cheap oneshot";
        };

        thresholdGiB = lib.mkOption {
          type = lib.types.int;
          default = 16;
          description = "VmRSS (kB) at or above which a bun process is SIGKILLed. 16 GiB on the 128 GB host leaves room for every legitimate bun workload while catching a leak ~4x before it threatens memory-emergency-guard territory";
        };

        processNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "bun" ];
          description = "Exact exe basenames the sweep may kill. Matched against the resolved /proc/PID/exe basename only — never a cmdline substring";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.bun-memory-watchdog = {
            description = "Bun memory watchdog: SIGKILL bun processes whose VmRSS crosses the kill threshold";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "64M";
                # Same sticky-textfile-dir reclaim rationale as the memory
                # guard: a foreign-owned stale .prom must not wedge the
                # atomic rename exactly when the watchdog matters most.
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                StateDirectory = "bun-memory-watchdog";
                ExecStart = lib.getExe watchdogScript;
                Environment = [
                  "BUN_WATCHDOG_THRESHOLD_KB=${toString (cfg.thresholdGiB * 1024 * 1024)}"
                  "BUN_WATCHDOG_PROCESS_NAMES=${lib.concatStringsSep " " cfg.processNames}"
                ];
                ReadWritePaths = [ textfileDir ];
                # /proc reads need nothing extra under harden{}: ProtectSystem
                # exempts the API subtrees /dev, /proc, /sys.
              }
            ];
          };

          timers.bun-memory-watchdog = {
            description = "Run the bun memory watchdog sweep";
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
