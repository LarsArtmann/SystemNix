# journald on the Samsung TLC hot tier — the `journal` subvolume (doctrine C:
# unsnapshotted, nodatacow) mounted AT /var/log/journal.
#
# WHY (2026-09-29): the journal was the last always-on writer inside the QLC
# root `@` snapshot set. Every incident of the freeze era showed journal reads
# timing out BECAUSE the journal sat on the storming disk, and btrbk `@`
# snapshots + forever-retained pool receives pinned every journal byte twice.
# On the TLC the journal is de-contended from the QLC storms, `@` rollbacks no
# longer rewind it (post-incident evidence survives a rollback), and its churn
# leaves the QLC entirely.
#
# DELEGATED to the collection module (inputs.nixos-modules.nixosModules.
# hot-tier, repo github:LarsArtmann/nixos-modules — contract-checked in the
# collection's own checks.hot-tier-contract, mutation-proven in its
# tests/negative/ harness, boot-behavior VM-tested via checks.hot-tier-journal-vm):
# the mount family (mkFilesystem cross-fs guard, subvol-prefixed mount
# options, the tmpfiles shadow-dir rule, per-service after/wants wiring) lives
# upstream. This file layers ONLY the SystemNix facts: the Samsung device
# (by-label tlc), the journal subvolume + journald group, and the journald
# ordering edge — upstream journald starts Before=sysinit.target, BEFORE
# local-fs mounts, so without after/wants the fstab mount loses the boot race
# and the journal silently splits across two filesystems (probed live against
# systemd 261.2; full narrative in the collection module header).
#
# Migration (ONE-TIME, order MANDATORY — DONE 2026-09): scripts/migrate-journal-hot.sh
# created the subvolume and copied the journal BEFORE the first deploy
# carrying this mount. The QLC shadow dir under the mountpoint stays as
# rollback insurance.
{
  inputs,
  ...
}:
{
  imports = [ inputs.nixos-modules.nixosModules.hot-tier ];

  config = {
    services.hot-tier = {
      enable = true;
      mounts.journal = {
        device = "/dev/disk/by-label/tlc";
        subvol = "journal";
        mountPoint = "/var/log/journal";
        tmpfilesMode = "02755";
        tmpfilesUser = "root";
        tmpfilesGroup = "systemd-journal";
        # after/wants wiring only (empty attrset): `wants`, NOT requires — a
        # failed mount job (Samsung detached) degrades journald into the QLC
        # shadow dir, never a journald-less boot.
        services.systemd-journald = { };
      };
    };
  };
}
