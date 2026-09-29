# journald on the Samsung TLC hot tier — the `journal` subvolume (doctrine C:
# unsnapshotted, nodatacow) mounted AT /var/log/journal.
#
# Why (2026-09-29): the journal was the last always-on writer inside the QLC
# root `@` snapshot set. Every incident of the freeze era showed journal reads
# timing out BECAUSE the journal sat on the storming disk (2026-08-31
# system-health collector stalls — sev1 evidence collection was the casualty
# of the very storm it was diagnosing), and btrbk `@` snapshots +
# forever-retained pool receives pinned every journal byte twice. On the TLC
# the journal is de-contended from the QLC storms, `@` rollbacks no longer
# rewind it (post-incident evidence survives a rollback), and its churn leaves
# the QLC entirely.
#
# THE ORDERING LANDMINE (probed live against systemd 261.2): the upstream
# systemd-journald.service has NO RequiresMountsFor=/var/log/journal and
# starts Before=sysinit.target — i.e. BEFORE local-fs mounts. A plain fstab
# entry loses that race: journald opens the shadow dir on QLC `@`, keeps
# those fds for the whole boot, and the journal silently splits across two
# filesystems at the next rotation. The after/wants wiring below is
# load-bearing, not decorative.
#
# Failure semantics (Samsung detached): the mount is nofail with a 5s device
# timeout; journald's `wants` (NOT requires) survives the failed mount job and
# logs into the real dir on `@` — degraded equals the pre-migration behavior,
# never a journald-less boot. The failure domain is moot anyway: /nix already
# lives on the same physical disk.
#
# Migration (ONE-TIME, order MANDATORY): scripts/migrate-journal-hot.sh
# creates the subvolume and copies the journal BEFORE the first deploy
# carrying this mount (deploying the mount first would shadow the live
# journal into a split brain). The QLC shadow dir under the mountpoint stays
# as rollback insurance. Regression: tests/test-journal-hot.nix (boots the
# mount path AND the Samsung-absent degraded shape).
{
  config,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) mkFilesystem;
in
{
  config = {
    fileSystems."/var/log/journal" = mkFilesystem {
      device = "/dev/disk/by-label/tlc";
      fsType = "btrfs";
      options = [
        "subvol=journal"
        "noatime"
        "nodiscard"
        "space_cache=v2"
        # Boot survives a detached Samsung; journald degrades to the QLC dir.
        "nofail"
        # Bound the Samsung-absent stall: the default 90s device timeout
        # would delay journald (After= the mount) by 90s at every boot on a
        # dead disk — 5s fails the mount fast and releases journald.
        "x-systemd.device-timeout=5s"
      ];
    };

    systemd.tmpfiles.rules = [
      # Post-boot creator for the MOUNTPOINT dir (systemd never creates
      # mountpoints; tmpfiles runs in sysinit, AFTER local-fs — so this
      # cannot race the mount at boot, it only guarantees the dir exists
      # for the NEXT boot if the QLC shadow is ever cleaned up while
      # unmounted). On this host the dir pre-exists (the live journal dir).
      "d /var/log/journal 02755 root systemd-journal -"
    ];

    systemd.services.systemd-journald = {
      # See the ordering landmine above — without this edge the fstab mount
      # loses the boot race and the journal splits across filesystems.
      after = [ "var-log-journal.mount" ];
      # wants, NOT requires: a failed mount job satisfies After= and Wants=
      # never propagates failure — journald proceeds into the QLC dir.
      wants = [ "var-log-journal.mount" ];
    };
  };
}
