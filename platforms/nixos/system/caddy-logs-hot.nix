# Caddy access logs on the Samsung TLC hot tier — the `caddy-logs` subvolume
# (doctrine C: unsnapshotted, nodatacow) mounted AT /var/log/caddy.
#
# WHY (2026-09-30): the per-vhost JSON access logs (1.7G and growing) were an
# always-churning writer inside the QLC root `@` snapshot set — every write
# rode the storming QLC disk AND every deleted log byte stayed pinned by
# btrbk `@` snapshots + forever-retained pool receives. On the TLC the churn
# leaves the QLC entirely and deletion frees IMMEDIATELY (unsnapshotted).
#
# DELEGATED to the collection module (inputs.nixos-modules.nixosModules.
# hot-tier, repo github:LarsArtmann/nixos-modules — contract-checked in the
# collection's own checks.hot-tier-contract, mutation-proven in its
# tests/negative/ harness, boot-behavior VM-tested via checks.hot-tier-caddy-vm):
# the mount family AND the *Directory= trap machinery live upstream —
# dropLogsDirectory neutralizes nixpkgs caddy's LogsDirectory (systemd turns
# ANY *Directory= path into an implicit RequiresMountsFor, defeating the
# wants-not-requires degradation: with the Samsung detached caddy died with
# result 'dependency' instead of degrading to the QLC shadow dir —
# VM-test-proven 2026-10-01), and healOwnership adds the `+`-privileged
# ExecStartPre chown (nothing else chowns the mounted dir after the mount
# lands: tmpfiles runs before it, plain ExecStartPre runs as caddy and
# EPERMs). This file layers ONLY the SystemNix facts: the Samsung device,
# the caddy-logs subvolume, and the caddy service wiring (caddy:caddy).
#
# Migration (ONE-TIME, order MANDATORY — DONE 2026-10): scripts/migrate-caddy-logs-hot.sh
# created the subvolume and copied the logs BEFORE the first deploy carrying
# this mount. The QLC shadow dir under the mountpoint stays as rollback
# insurance.
{
  inputs,
  ...
}:
{
  imports = [ inputs.nixos-modules.nixosModules.hot-tier ];

  config = {
    services.hot-tier = {
      enable = true;
      mounts.caddy-logs = {
        device = "/dev/disk/by-label/tlc";
        subvol = "caddy-logs";
        mountPoint = "/var/log/caddy";
        tmpfilesMode = "0750";
        tmpfilesUser = "caddy";
        tmpfilesGroup = "caddy";
        services.caddy.dropLogsDirectory = true;
      };
    };
  };
}
