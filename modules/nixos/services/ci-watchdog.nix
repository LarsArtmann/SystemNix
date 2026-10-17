# Runbook: docs/services/ci-watchdog.md
# ci-watchdog — GitHub Actions canary watchdog for the domains repo.
#
# runner-health.yml (scheduled every 30 min) runs ON GitHub-hosted runners,
# so it is structurally blind during an Actions outage: a billing block or
# disabled Actions kills the canary's own runs, and nothing local notices.
# The 2026-06→08 billing block went unnoticed for ~8 weeks because every
# watcher lived inside the thing that died. This timer runs OUTSIDE Actions
# on evo-x2 and treats the canary's run history as the signal: no recent
# run, a failed run, or a startup-failure conclusion means Actions is
# broken; run annotations separate "billing" from "workflow actually
# broken" (observed: conclusion "failure" on every scheduled run during the
# 2026-09-08 block).
#
# The check program is the domains flake's `ci-watchdog` app (single source
# of truth, wired via services.ci-watchdog.checkProgram from the flake
# input) — it closes over gh/jq/coreutils and exits non-zero on any canary
# anomaly, which trips the unit's onFailure hook.
_: {
  flake.nixosModules.ci-watchdog =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.ci-watchdog;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;
      primaryUser = config.users.primaryUser;
    in
    {
      options.services.ci-watchdog = {
        enable = lib.mkEnableOption "GitHub Actions canary watchdog (domains repo runner-health.yml liveness, outside Actions)";

        checkProgram = lib.mkOption {
          type = lib.types.path;
          description = ''
            The ci-watchdog program (domains flake `ci-watchdog` app —
            gh-authenticated canary check; exits non-zero on stopped
            scheduled runs, billing blocks, or broken canary workflows).
            Wired from the `domains` flake input in the system config.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "30m";
          description = "Timer cadence. The canary itself runs every 30 min on a 4 h max-age window; matching the cadence bounds detection latency to one canary cycle without hammering the API.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.ci-watchdog = {
          description = "GitHub Actions canary watchdog (domains runner-health.yml liveness)";
          inherit onFailure;

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "128M";
              # gh reads the primary user's ~/.config/gh token — never writes.
              ProtectHome = "read-only";
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              # Runs as the primary user so gh finds its OAuth token in
              # ~/.config/gh/hosts.yml (read-only above). No system token
              # copy to rotate or leak.
              User = primaryUser;
              Group = "users";
              StateDirectory = "ci-watchdog";
              ExecStart = toString cfg.checkProgram;
              Environment = [
                "HOME=/home/${primaryUser}"
                "GH_CONFIG_DIR=/home/${primaryUser}/.config/gh"
                # gh's cache must not try the read-only $HOME.
                "XDG_CACHE_HOME=/var/lib/ci-watchdog/cache"
              ];
              TimeoutStartSec = "2min";
            }
          ];
        };

        systemd.timers.ci-watchdog = {
          description = "Run the GitHub Actions canary watchdog";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "10min";
            OnUnitActiveSec = cfg.interval;
            # Catch up after host downtime instead of waiting a full cycle.
            Persistent = true;
          };
        };
      };
    };
}
