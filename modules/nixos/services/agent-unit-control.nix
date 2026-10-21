# Scoped polkit rule: systemd unit stop/start/restart without interactive
# auth for an allowlisted unit set.
#
# The 2026-09-29 freeze-#7 post-mortem (docs/status/2026-10-21 era queue row;
# source: 2026-09-29_10-09 §g.4) found that during a live freeze-class event
# the diagnosing agent could read everything but stop NOTHING: every
# `systemctl stop <storm-unit>` hit the polkit auth_admin wall and died on the
# interactive prompt an agent shell cannot answer. The same wall blocks routine
# convergence (llama-chat 2026-10-08: "polkit bars agents from starts" — the
# workaround was a root convergence UNIT per service).
#
# This module is the scoped answer: members of the configured group may
# stop/start/restart ONLY the units in `units` without a password. The allow
# list is the blast radius — everything else keeps the default admin
# authorization (auth_admin_keep), and unit-file management
# (enable/disable/mask) is deliberately NOT granted, so a compromised agent
# session cannot persist a change, only nudge the running state of the listed
# units. Group-scoped (default "wheel") so membership stays an owner decision;
# grant the group to an agent identity to hand it exactly this power.
{
  flake.nixosModules.agent-unit-control =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.agent-unit-control;
    in
    {
      options.services.agent-unit-control = {
        enable = lib.mkEnableOption "scoped polkit rule for passwordless unit stop/start/restart";

        group = lib.mkOption {
          type = lib.types.str;
          default = "wheel";
          description = ''
            Group whose members may manage the allowlisted units without
            interactive auth. wheel is already admin-trusted, so this only
            NARROWS what a trusted session can do passwordlessly.
          '';
        };

        units = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            # The storm units the freeze-7 class needs stopped mid-event
            # (memory-emergency-guard ioChurnUnits — keep in sync when that
            # list grows) plus the known convergence-blocked services.
            "btrbk-root.service"
            "btrbk-data.service"
            "btrbk-pool.service"
            "btrfs-balance-metadata.service"
            "btrfs-balance-data.service"
            "btrfs-scrub@-.service"
            "btrfs-scrub@data.service"
            "btrfs-scrub@mnt-pool.service"
            "fastflowlm.socket"
            "fastflowlm.service"
            "llama-chat.service"
            "buildcache-usb-recovery.service"
            "pool-usb-recovery.service"
          ];
          description = ''
            Units members of `group` may stop/start/restart without
            interactive auth. Exact unit names (Instance= escapes included);
            the polkit matcher is exact, not prefix.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.units != [ ];
            message = "services.agent-unit-control: an empty allowlist would make the polkit rule dead config — disable the module or list units";
          }
        ];

        security.polkit.extraConfig = ''
          // agent-unit-control: passwordless stop/start/restart for the
          // allowlisted units only (freeze-7 diagnosing-agent class).
          polkit.addRule(function(action, subject) {
            if (action.id === "org.freedesktop.systemd1.manage-units" &&
                subject.isInGroup("${cfg.group}")) {
              var unit = action.lookup("unit");
              if (unit) {
                var allowed = [${lib.concatMapStringsSep ", " (u: ''"${u}"'') cfg.units}];
                if (allowed.indexOf(unit) !== -1) {
                  return polkit.Result.YES;
                }
              }
            }
          });
        '';
      };
    };
}
