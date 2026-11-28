# Behavior test for the service-health-check script (no VM, no systemd).
#
# The 2026-11-28 desktop storm: the acute-vs-chronic classifier had not
# fired once since it was written (2026-10-17). It asked systemd for
# "<unit>.service.timer", a unit that does not exist, so every failed
# scheduled job counted as chronic, and the desktop dedup hashed the whole
# member set while members flapped: 99 critical popups in 35.5 hours, up to
# 291 units listed under "Health Check: services down", none of them down.
#
# This runs the SHIPPED writeShellApplication artifact of the module with
# systemctl / notify-send / sleep replaced by stubs, through every decision
# path of the classifier, its failure ledger and the member-based desktop
# dedup (tests/service-health-check-harness.sh), then proves the harness
# has teeth: each mutation leg re-introduces one defect into a copy of the
# shipped script and must fail it, a comment-only control must pass
# (tests/service-health-check-mutations.sh).
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;
  scheduledTasks = import ../platforms/nixos/system/scheduled-tasks.nix;
  primaryUserModule = import ../platforms/nixos/system/primary-user.nix;

  # scheduled-tasks resolves config.users.users.<primaryUser>.uid at eval
  # time: root exists in a bare nixosSystem, the default "lars" does not.
  # The nur.crush stub covers the host-overlay package the module references
  # (crush-update-providers) in case anything forces its unit.
  checkerScript =
    let
      execStart =
        (lib.nixosSystem {
          inherit system;
          modules = [
            primaryUserModule
            { users.primaryUser = "root"; }
            { system.stateVersion = "26.11"; }
            {
              nixpkgs.overlays = [
                (_: prev: {
                  nur.repos.charmbracelet.crush = prev.writeShellScriptBin "crush" "true";
                })
              ];
            }
            scheduledTasks
          ];
        }).config.systemd.services.service-health-check.serviceConfig.ExecStart;
    in
    lib.removeSuffix "/bin/service-health-check" execStart;

  harness = ./service-health-check-harness.sh;
  mutations = ./service-health-check-mutations.sh;
in
pkgs.runCommand "test-service-health-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
    ];
    meta.description = "service-health-check classifier, ledger and desktop-dedup behavior test (stubbed systemctl/notify-send, with mutation legs)";
  }
  ''
    set -euo pipefail
    work="$PWD/work"
    mkdir -p "$work"
    bash ${harness} "${checkerScript}/bin/service-health-check" "$work/behavior"
    bash ${mutations} "${checkerScript}/bin/service-health-check" ${harness} "$work/mutations"
    echo "ALL PASS: service-health-check behavior + mutation legs" > "$out"
  ''
