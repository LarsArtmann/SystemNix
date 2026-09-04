# Negative test for the tmp-cleaner eval-time guards (pure eval, no VM).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves the guards still fire on the historical bug shape:
#
#   1. tmp-cleaner-audit catches an INLINE /tmp/* glob + rm cleaner.
#   2. The same cleaner WITH a systemd-private exclusion passes.
#   3. The real scheduled-tasks.nix passes both its self-assertion and the
#      audit (no false positives on the deployed config).
#   4. The self-assertion is WIRED: config.assertions must actually contain
#      a passing "tmp-cleanup guard:" entry. (A source-mutation case —
#      stripping the exclusion and expecting the assertion to fire — cannot
#      run under `nix flake check --no-build`: importing a synthesized
#      mutated module needs a realized store path. The behavioral half of
#      that coverage — the real script must PRESERVE an aged systemd-private
#      dir — lives in tests/test-tmp-cleanup.nix, which runs the deployed
#      unit in a VM.)
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  # The module file is a flake-parts wrapper (top-level lambda `_:`) —
  # apply it, then pull the NixOS module out of flake.nixosModules.
  audit =
    ((import ../modules/nixos/services/tmp-cleaner-audit.nix) { }).flake.nixosModules.tmp-cleaner-audit;
  scheduledTasks = import ../platforms/nixos/system/scheduled-tasks.nix;
  primaryUserModule = import ../platforms/nixos/system/primary-user.nix;

  # scheduled-tasks resolves config.users.users.<primaryUser>.uid at eval
  # time — root exists in a bare nixosSystem; the default "lars" does not.
  # The nur.crush stub covers the host-overlay package the module references
  # (crush-update-providers) in case anything forces its unit.
  base = [
    primaryUserModule
    { users.primaryUser = "root"; }
    {
      nixpkgs.overlays = [
        (_: prev: {
          nur.repos.charmbracelet.crush = prev.writeShellScriptBin "crush" "true";
        })
      ];
    }
  ];

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = base ++ extraModules;
    }).config.assertions;

  # Only the two tmp-cleaner guards' OWN assertions — a bare nixosSystem
  # carries unrelated failing boilerplate we must not count.
  failing =
    assertions:
    builtins.filter (
      a:
      !a.assertion
      && (lib.hasPrefix "tmp-cleaner-audit:" a.message || lib.hasPrefix "tmp-cleanup guard:" a.message)
    ) assertions;

  # The historical bug shape, inline variant: top-level /tmp sweep + rm,
  # no exclusion (what a future "quick cleanup script" looks like).
  evilInlineCleaner = {
    systemd.services.evil-cleaner.serviceConfig.ExecStart =
      "${pkgs.bashInteractive}/bin/bash -c 'for f in /tmp/*; do rm -rf \"$f\"; done'";
  };

  # Same shape, but carrying the documented exclusion — must pass.
  exemptedInlineCleaner = {
    systemd.services.fine-cleaner.serviceConfig.ExecStart =
      "${pkgs.bashInteractive}/bin/bash -c 'for f in /tmp/*; do case \"$f\" in systemd-private-*) continue;; esac; rm -rf \"$f\"; done'";
  };

  # The assertion for the deployed script must be present AND passing:
  # guards against both deletion of the tripwire and accidental renaming
  # of its message prefix (which this test and docs reference).
  guardWired =
    assertions:
    builtins.any (a: a.assertion && lib.hasPrefix "tmp-cleanup guard:" a.message) assertions;

  cases = [
    {
      name = "inline-glob-cleaner-not-caught";
      pass =
        (failing (evalAssertions [
          audit
          evilInlineCleaner
        ])) != [ ];
    }
    {
      name = "exempted-inline-cleaner-rejected";
      pass =
        (failing (evalAssertions [
          audit
          exemptedInlineCleaner
        ])) == [ ];
    }
    {
      name = "real-scheduled-tasks-failing-its-own-guard";
      pass =
        (failing (evalAssertions [
          audit
          scheduledTasks
        ])) == [ ];
    }
    {
      name = "self-assertion-unwired";
      pass =
        let
          assertions = evalAssertions [ scheduledTasks ];
        in
        guardWired assertions && (failing assertions) == [ ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "tmp-cleaner-audit-negative-test" { } "touch $out"
else
  throw ''
    tmp-cleaner guard regression: ${toString broken}
    The eval-time guards must fire on the historical 2026-08-18..30 bug
    (tmp-cleanup deleting systemd-private-* backing dirs). If a guard was
    refactored, re-verify with THIS test — not with toplevel.drvPath
    (which never forces assertions).
  ''
