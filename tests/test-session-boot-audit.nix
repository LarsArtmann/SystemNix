# Negative test for the session-boot-audit guard (2026-08-18 black-screen class).
# Pure eval — no VM. Forces minimal NixOS configs and inspects assertions:
# `nix eval …toplevel.drvPath` is assertion-blind, so THIS is the only CI
# surface that proves the guard still fires on the historical bug.
{
  pkgs,
  inputs,
  system,
}:
let
  audit =
    (import ../modules/nixos/desktop/session-boot-audit.nix).flake.nixosModules.session-boot-audit;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  # Only the guard's OWN assertions — a bare nixosSystem carries unrelated
  # failing boilerplate (no fileSystems, no bootloader) we must not count.
  failing =
    assertions:
    builtins.filter (a: !a.assertion && pkgs.lib.hasPrefix "session-boot-audit:" a.message) assertions;

  # The exact historical bug (commit 6ea92969, 2026-08-15): a unit pulled
  # into the boot transaction via default.target Wants= graphical-session.target.
  evilUnit = {
    systemd.user.services.evil-gate = {
      wantedBy = [ "default.target" ];
      wants = [ "graphical-session.target" ];
    };
  };

  # The same unit, allow-listed: the documented escape hatch must silence it.
  allowedConfig = {
    services.session-boot-audit.allowedUnits = [ "evil-gate" ];
  };

  # Suffix-spelled reference: the pull token says "evil-dup.service" but
  # the unit's own edges live under the bare key "evil-dup" (NixOS option
  # keys are suffix-less). Without canonical-name merging the token resolves
  # to a NEW node with no outgoing edges — the chain silently breaks.
  suffixReference = {
    systemd.user.services.evil-puller = {
      wantedBy = [ "default.target" ];
      wants = [ "evil-dup.service" ];
    };
    systemd.user.services.evil-dup.wants = [ "graphical-session.target" ];
  };

  # Raw text only: exercises the systemd-directive parser ([Install] section).
  rawTextUnit = {
    systemd.user.units."evil-raw.service".text = ''
      [Unit]
      Wants=graphical-session.target

      [Install]
      WantedBy=default.target
    '';
  };

  cases = [
    {
      name = "historical-bug-not-caught";
      pass = (failing (evalAssertions [ evilUnit ])) != [ ];
    }
    {
      name = "allowedUnits-escape-hatch-broken";
      pass =
        (failing (evalAssertions [
          evilUnit
          allowedConfig
        ])) == [ ];
    }
    {
      name = "suffix-spelled-reference-not-merged";
      pass = (failing (evalAssertions [ suffixReference ])) != [ ];
    }
    {
      name = "raw-text-unit-not-caught";
      pass = (failing (evalAssertions [ rawTextUnit ])) != [ ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "session-boot-audit-negative-test" { } "touch $out"
else
  throw ''
    session-boot-audit guard regression: ${toString broken}
    The guard must fire on the historical black-screen bug. If the module was
    refactored, re-verify with this test — not with toplevel.drvPath (which
    never forces assertions).
  ''
