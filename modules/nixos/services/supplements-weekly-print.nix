# Runbook: docs/services/supplements-weekly-print.md
# supplements-weekly-print — print the current ISO week's supplement-stack
# sheet every Monday 00:00 local through the tracking-papers print-safe
# pipeline (brief: tracking-papers
# docs/planning/2026-10-04_print-mechanism-brief.md, Option 2; Lars picked
# automation 2026-11-24).
#
# Why the pipeline lives in tracking-papers: the print pipeline is that
# repo's product concern (print-safe mirror, the generator, the gray-flood
# incident record). SystemNix owns only the schedule. The unit calls the
# flake-built app, which dry-run-validates before ink, verifies completion
# (print-safe's exit does NOT prove paper: the held-job mode), runs the
# bounded held-job release loop for an asleep printer, and records the
# outcome in the printer log.
#
# Alerting: Discord direct (onFailureP0), not toast-only. A 00:00 failure
# fires while nobody is at the desktop, so a toast is guaranteed unseen;
# this is the 2026-10-12 gatus-sole-resolver lesson (toast-only = one
# DND-suppressible signal) applied to a unit whose whole purpose is
# cadence guarantee.
#
# Not web-facing: no port, no vHost, no integration registry entry, no
# dashboard tile (tile coverage asserts only subdomain'd entries).
{ inputs, ... }:
{
  flake.nixosModules.supplements-weekly-print =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.supplements-weekly-print;
      primaryUser = config.users.primaryUser;
      primaryHome = config.users.users.${primaryUser}.home;
      app = inputs.tracking-papers.packages.${pkgs.stdenv.hostPlatform.system}.print-supplements-weekly;
      inherit (import ../../../lib/default.nix lib)
        harden
        ioTier
        mkStateDir
        serviceOneshotDefaults
        onFailureP0
        ;
    in
    {
      options.services.supplements-weekly-print = {
        enable = lib.mkEnableOption "the Monday 00:00 supplement-stack sheet auto-print (tracking-papers print-safe pipeline)";

        onCalendar = lib.mkOption {
          type = lib.types.str;
          default = "Mon *-*-* 00:00:00";
          description = "OnCalendar schedule (default: Monday 00:00 local; Persistent replays a missed week at the next boot/resume).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.tmpfiles.rules = [
          # Base dir for the staged weekly artifacts the app renders into
          # (sheets/ is deliberately untouched: gallery catalog edits stay
          # conscious). The app mkdir -p's the -sheets leaf itself.
          (mkStateDir "${primaryHome}/.local/state/tracking-papers" "0750" primaryUser "users")
        ];

        systemd.services.supplements-weekly-print = {
          description = "Print this ISO week's supplement-stack sheet (print-safe pipeline)";
          after = [ "cups.service" ];
          wants = [ "cups.service" ];
          onFailure = onFailureP0;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = lib.getExe app;
              User = primaryUser;
              # systemd does not export HOME for system services; WeasyPrint
              # (fontconfig/Pango) needs one. %h resolves to the User= home.
              Environment = [ "HOME=%h" ];
              # generator + WeasyPrint + print-safe (<=600s printer wait)
              # + release loop (<=600s): the 5min oneshot floor is too short.
              TimeoutStartSec = "25min";
            }
            (harden {
              MemoryMax = "512M";
              ReadWritePaths = [
                "${primaryHome}/projects/tracking-papers/docs"
                "${primaryHome}/.local/state/tracking-papers"
                "${primaryHome}/.cache/fontconfig"
              ];
            })
            ioTier.background
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.supplements-weekly-print = {
          description = "Weekly supplement sheet print cadence (Monday 00:00 local)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.onCalendar;
            Persistent = true;
          };
        };
      };
    };
}
