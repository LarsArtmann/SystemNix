# Local push-stall watchdog (2026-10-30, plan T15 / webphone AGENTS
# "manual-push bar"): the auto-commit daemon's push-leg can stall
# silently for hours — the 2026-10-30 fax train sat 9h20m unpushed with
# green, verified commits. GitHub CI cannot see unpushed commits (it
# checks out the remote tip), so a LOCAL timer is the only automation
# home (webphone T21 modeling: the watcher is LOCAL-only by structure).
#
# Hourly fire over the webphone checkout; the script exits 1 on a stall,
# so the unit lands FAILED — visible in `systemctl --user list-failed`
# and `journalctl --user -u push-stall-watch`. Threshold is the bar's
# 60-minute anchor (webphone AGENTS, ratified 2026-10-11).
{
  pkgs,
  lib,
  ...
}:
let
  # Lars' dev machines keep the fleet checkouts under /home/lars/projects.
  webphoneRepo = "/home/lars/projects/webphone";
  stallWatch = pkgs.writeShellApplication {
    name = "push-stall-watch-unit";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
      pkgs.coreutils
    ];
    text = ''
      cd ${webphoneRepo} || exit 0 # repo missing on this host: nothing to watch
      if ! ${webphoneRepo}/scripts/push-stall-watch.sh; then
        echo "push-stall-watch: STALL — unpushed commits older than the 60-min manual-push bar; push or investigate"
        exit 1
      fi
      echo "push-stall-watch: OK — no unpushed stall"
    '';
  };
in
{
  systemd.user.services = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    push-stall-watch = {
      Unit = {
        Description = "Webphone push-stall watchdog (manual-push bar, 60-min anchor)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${stallWatch}/bin/push-stall-watch-unit";
      };
    };
  };

  systemd.user.timers = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    push-stall-watch = {
      Timer = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1h";
        # A missed fire while powered off self-corrects at the next fire;
        # the stall class is hours-scale, no catch-up storm wanted.
        Persistent = false;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
