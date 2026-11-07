# Weekly boot-evidence scratch gc (2026-11-07, stability "Weekly
# boot-evidence-scratch-gc timer" row): scripts/boot-evidence-scratch-gc.sh
# (selftesting via checks.boot-evidence-scratch-gc-selftest) only ever ran at
# boot-evidence-pull.sh startup — a killed session leaking a >1G dump sat
# until the NEXT manual pull (the >48h no-pull stretch class; 2026-11-02
# reclaim: 2.1G across two leaked dumps). The weekly timer closes that
# window. All safety gates live IN the script (48h mtime age + live-fd
# holder scan), so a concurrent session's fresh scratch is never touched;
# `quiet` journals only reclaimed files.
#
# The unit runs the script from the LIVE checkout (the
# catalog-inventory-sync precedent — this box's agents operate that tree);
# an absent checkout degrades to a no-op note instead of a failing timer.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  script = "${config.home.homeDirectory}/projects/SystemNix/scripts/boot-evidence-scratch-gc.sh";
in
{
  systemd.user.services = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    boot-evidence-scratch-gc = {
      Unit = {
        Description = "Reclaim leaked boot-evidence scratch (age+holder gated, 48h)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'if [ ! -x ${script} ]; then echo \"boot-evidence-gc: checkout script absent (${script}); skipping\"; exit 0; fi; exec ${pkgs.bash}/bin/bash ${script} quiet'";
      };
    };
  };

  systemd.user.timers = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    boot-evidence-scratch-gc = {
      Timer = {
        OnCalendar = "weekly";
        # The age gate is idempotent and the holder gate makes re-runs safe —
        # catch-up after a powered-off week is desired, no storm risk.
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
