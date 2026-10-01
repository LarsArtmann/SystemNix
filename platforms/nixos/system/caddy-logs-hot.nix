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
{lib, ...}: let
  inherit (import ../../../lib/default.nix lib) mkFilesystem;
in {
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
      after = ["var-log-caddy.mount"];
      wants = ["var-log-caddy.mount"];
    };
  };
}
