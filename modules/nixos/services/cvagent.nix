# Runbook: docs/services/cvagent.md
# cvagent — keep the CV repo's code-derived evidence fresh (scan + mesh).
#
# Daily: scans the configured repositories with cvagent (event-sourced
# sqlite fact store under the operator's state dir) and exports the mesh
# artifacts into the CV checkout: the RFC 6902 variant patch
# data/cv/lars_artmann-en-cvagent.patch.json (renderable via
# `cv render --variant cvagent`) plus data/projects-v2/<slug>.md evidence
# pages. The repo's PMA auto-commit daemon picks the diff up and
# cv-server-content-sync ships it on the next deploy.
#
#   - Runs as the operator user (cv-profile-probe precedent): it writes the
#     CV checkout and ~/.local/state and reads the whole projects tree, so
#     server-grade home protection must not apply (ProtectHome = false).
#   - One broken repository must not kill the export: per-repo scan
#     failures WARN and the run continues (github-auto-assign tolerance
#     doctrine). Only mesh failing — or EVERY scan failing — fails the
#     unit, which pages via OnFailure.
#   - Idempotent and deterministic: re-runs produce byte-identical
#     artifacts (no timestamps); curated project pages are never
#     overwritten (the exporter preserves pages without its marker).
#   - No HTTP endpoint: daemon-less-unit doctrine — failure alerting rides
#     OnFailure (Discord) + the system-health state metrics.
{ inputs, ... }: {
  flake.nixosModules.cvagent =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.cvagent;
      primaryUser = config.users.primaryUser or "lars";
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        ;

      cvagentPkg = inputs.cvagent.packages.${pkgs.stdenv.hostPlatform.system}.default;

      script = pkgs.writeShellApplication {
        name = "cvagent-scan-mesh";
        # cvagent exec's `git` for history collection and the script needs
        # mkdir for the fact-store dir — a unit's default PATH carries
        # neither (2026-11-04 05:56 run: every scan died on
        # "git": executable file not found in $PATH, systemic).
        runtimeInputs = [
          cfg.package
          pkgs.git
          pkgs.coreutils
        ];
        text = ''
          # Deliberately NO -e: per-repo scan failures warn, the export continues.
          set -uo pipefail
          cvagent="${lib.getExe cfg.package}"
          db="${cfg.database}"
          target="${cfg.targetDir}"
          concurrency="${toString cfg.concurrency}"
          min_confidence="${toString cfg.minConfidence}"

          # Environment injection is deliberately NOT used here: cvagent's
          # koanf layer claims the whole CVAGENT_* env namespace, so any
          # CVAGENT_<X> this unit exported would be parsed as config and
          # poison the load (caught live in the 2026-11-01 smoke test).
          mkdir -p "$(dirname "$db")"

          scanned=0
          failed=0
          for repo in ${lib.concatMapStringsSep " " (r: "'${r}'") cfg.repositories}; do
            if "$cvagent" scan "$repo" --db "$db" --concurrency "$concurrency"; then
              scanned=$((scanned + 1))
            else
              echo "WARN: cvagent scan failed: $repo" >&2
              failed=$((failed + 1))
            fi
          done

          if [ "$scanned" -eq 0 ]; then
            echo "ERROR: every repository scan failed (systemic)" >&2
            exit 1
          fi

          "$cvagent" mesh --target "$target" --db "$db" \
            --min-confidence "$min_confidence"

          echo "done: scanned=$scanned failed=$failed target=$target"
        '';
      };
    in
    {
      options.services.cvagent = {
        enable = lib.mkEnableOption "daily cvagent scan + CV-repo mesh export";

        package = lib.mkOption {
          type = lib.types.package;
          default = cvagentPkg;
          description = "cvagent package (PATH CLI and timer binary are the same derivation).";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 05:53:00";
          description = "OnCalendar schedule (default: daily at 05:53, off the 01:00-03:00 backup window and the cv timers' :23/:41).";
        };

        repositories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "/home/lars/projects/SystemNix"
            "/home/lars/projects/Code-To-CV-Agent"
            "/home/lars/projects/go-cqrs-lite"
            "/home/lars/projects/go-aichat"
            "/home/lars/projects/cmdguard"
            "/home/lars/projects/monitor365"
          ];
          description = "Repository checkouts scanned for CV facts (absolute paths).";
        };

        targetDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/lars/projects/CV";
          description = "CV project checkout the mesh artifacts are exported into.";
        };

        database = lib.mkOption {
          type = lib.types.str;
          default = "/home/lars/.local/state/cvagent/cvagent.db";
          description = "sqlite fact-store path (event-sourced journal).";
        };

        minConfidence = lib.mkOption {
          type = lib.types.float;
          default = 0.6;
          description = "Minimum fact confidence entering the CV generation.";
        };

        concurrency = lib.mkOption {
          type = lib.types.ints.positive;
          default = 3;
          description = "Concurrent commit scans within one repository.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.cvagent = {
          description = "cvagent: scan repositories, export CV mesh artifacts";
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              Group = "users";
              ExecStart = lib.getExe script;
              # Scan volume scales with repository history (go-cqrs-lite
              # alone walks 9k commits) — keep the budget generous.
              TimeoutStartSec = "10min";
              Environment = [ "HOME=/home/lars" ];
            }
            (harden {
              # The export writes the CV checkout and the fact store under
              # /home, and scans read across the projects tree — the
              # cv-profile-probe precedent: home protection must not apply.
              ProtectHome = false;
              MemoryMax = "512M";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.cvagent = {
          description = "Daily cvagent scan + CV-repo mesh export";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.schedule;
            RandomizedDelaySec = "10min";
            # Catch up missed windows across reboots (btrbk doctrine).
            Persistent = true;
          };
        };

        # Daemon-less unit: no HTTP endpoint to probe, so monitoring is
        # OnFailure (Discord) + the system-health state metrics.
        services.system-health.extraMonitoredServices = lib.mkAfter [
          "cvagent"
        ];
      };
    };
}
