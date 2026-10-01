# Caddy access logs on the Samsung TLC hot tier — the `caddy-logs` subvolume
# (doctrine C: unsnapshotted, nodatacow) mounted AT /var/log/caddy.
#
# Why (2026-09-30): the per-vhost JSON access logs (1.7G and growing) were an
# always-churning writer inside the QLC root `@` snapshot set — every write
# rode the storming QLC disk AND every deleted log byte stayed pinned by
# btrbk `@` snapshots (2w window) + forever-retained pool receives. On the
# TLC the churn leaves the QLC entirely and deletion frees IMMEDIATELY
# (unsnapshotted Samsung, see the Snapshot-pinning doctrine).
#
# Ordering: caddy is a normal service (starts well after local-fs.target), so
# the plain fstab mount wins the boot race by construction — unlike journald
# (journal-hot.nix) there is no Before=sysinit landmine. The after/wants
# wiring below is still explicit: `wants` (NOT requires) survives a failed
# mount job, so a detached Samsung degrades caddy to logging into the QLC
# shadow dir — the pre-migration behavior, never a caddy-less boot. The
# mountpoint dir is guaranteed by tmpfiles for the next boot if the shadow
# is ever cleaned while unmounted.
#
# Migration (ONE-TIME, order MANDATORY): scripts/migrate-caddy-logs-hot.sh
# creates the subvolume and copies the logs BEFORE the first deploy carrying
# this mount (deploying the mount first would shadow the live logs into a
# split brain). The QLC shadow dir under the mountpoint stays as rollback
# insurance.
{
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) mkFilesystem;
in
{
  config = {
    fileSystems."/var/log/caddy" = mkFilesystem {
      device = "/dev/disk/by-label/tlc";
      fsType = "btrfs";
      options = [
        "subvol=caddy-logs"
        "noatime"
        "nodiscard"
        "space_cache=v2"
        # Samsung-detached degradation: fail the mount fast, caddy logs to
        # the QLC shadow dir (same 5s bound rationale as journal-hot.nix).
        "nofail"
        "x-systemd.device-timeout=5s"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/log/caddy 0750 caddy caddy -"
    ];

    systemd.services.caddy = {
      after = [ "var-log-caddy.mount" ];
      wants = [ "var-log-caddy.mount" ];
      # TRAP (VM-test-proven 2026-10-01): nixpkgs caddy sets LogsDirectory=caddy
      # for its default logDir — and systemd turns ANY *Directory= path into an
      # implicit RequiresMountsFor (systemd.exec "Automatic Dependencies":
      # Requires= + After= on every mount unit needed to access the path). That
      # hard dependency DEFEATS the wants-not-requires degradation above: with
      # the Samsung detached, caddy died with result 'dependency' instead of
      # degrading to the QLC shadow dir. Dropping LogsDirectory means NOTHING
      # chowns the dir after the mount — systemd's *Directory= machinery (which
      # creates + chowns at service start, correctly ordered after the mount)
      # was doing that job too. The tmpfiles rule CANNOT take it over:
      # tmpfiles-setup runs in early sysinit BEFORE the hot-tier mount lands
      # (guest journal: setup finished 3.8s, mount 7.8s), so it only ever fixes
      # the QLC shadow dir — the mounted subvol root stays root-owned and caddy
      # died with EACCES on first config load. The re-ownership must run with
      # FULL PRIVILEGES at service start: preStart / plain ExecStartPre execute
      # as the SERVICE USER (caddy) and fail chown with EPERM — the "+" prefix
      # (systemd.exec) runs this one command as root, sandbox dropped. The
      # tmpfiles rule keeps guaranteeing the shadow dir's EXISTENCE on degraded
      # boots; writability comes from ReadWritePaths (production override /
      # non-sandboxed default).
      serviceConfig.LogsDirectory = lib.mkForce [ ];
      serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "caddy-logdir-own" ''
          chown caddy:caddy /var/log/caddy
        ''}"
      ];
    };
  };
}
