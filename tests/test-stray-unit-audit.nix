# Negative test for the stray-unit-audit eval-time warning (pure eval, no VM).
#
# This is the CI surface that proves the drift detector FIRES on the
# historical dead-guard shapes and stays silent on every legitimate pull
# class:
#
#   1. The 2026-08-31..09-29 btrfs-scrub-- shape (override fragment, no
#      wantedBy, nothing references it) FIRES the warning, named.
#   2. allowUnits suppresses it for the allowlisted unit.
#   3. @-templates and systemd-instantiated names are shape-allowed.
#   4. Same-named timer drives it → not flagged.
#   5. Another unit's `requires` references it → not flagged.
#   6. wantedBy pulls it → not flagged.
#   7. Own requiredBy non-empty (nixpkgs paperless-secret-key class,
#      found live 2026-10-01) → not flagged.
#   8. Referenced as another unit's onFailure sink (rpi3
#      crush-update-failure class) → not flagged.
#
# Assertions key on the SYNTHETIC unit's NAME inside the warning text — a
# bare nixosSystem base carries its own strays (dbus, nix-gc,
# nix-optimise, systemd-user-sessions on a minimal eval), and global
# silence would false-fail on that ambient noise. The no-false-positives
# half against the REAL fleet is the module's baseline allowlist
# (evo-x2 + rpi3-dns both verified silent 2026-10-01).
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  audit =
    (import ../modules/nixos/services/stray-unit-audit.nix).flake.nixosModules.stray-unit-audit;

  evalWarnings =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.warnings;

  flagged =
    name: extraModules:
    let
      strays = builtins.filter (w: lib.hasInfix "stray-unit-audit" w) (evalWarnings extraModules);
      # Only the warning's HEADER (the flagged-unit list) counts — the
      # guidance text below it names btrfs-scrub-- as the historical
      # example and would phantom-match.
      headers = map (w: builtins.head (lib.splitString "\n\n" w)) strays;
    in
    lib.any (h: lib.hasInfix name h) headers;

  strayUnit = {
    systemd.services.btrfs-scrub-- = {
      serviceConfig.ExecStart = "/bin/true";
    };
  };

  cases = [
    {
      name = "stray-not-caught";
      pass = flagged "btrfs-scrub--" [ strayUnit ];
    }
    {
      name = "allowlist-not-honored";
      pass =
        !flagged "btrfs-scrub--" [
          strayUnit
          { services.stray-unit-audit.allowUnits = [ "btrfs-scrub--" ]; }
        ];
    }
    {
      name = "template-falsely-flagged";
      pass =
        !flagged "demo@" [
          {
            systemd.services."demo@" = {
              serviceConfig.ExecStart = "/bin/true";
            };
          }
        ];
    }
    {
      name = "timer-driven-falsely-flagged";
      pass =
        !flagged "driven-sync" [
          {
            systemd.services.driven-sync.serviceConfig.ExecStart = "/bin/true";
            systemd.timers.driven-sync = {
              wantedBy = [ "timers.target" ];
              timerConfig.OnUnitActiveSec = "5min";
            };
          }
        ];
    }
    {
      name = "dep-referenced-falsely-flagged";
      pass =
        !flagged "needed-token" [
          {
            systemd.services.needed-token.serviceConfig.ExecStart = "/bin/true";
            systemd.services.consumer = {
              serviceConfig.ExecStart = "/bin/app";
              wantedBy = [ "multi-user.target" ];
              requires = [ "needed-token.service" ];
            };
          }
        ];
    }
    {
      name = "wanted-by-falsely-flagged";
      pass =
        !flagged "pulled-daemon" [
          {
            systemd.services.pulled-daemon = {
              serviceConfig.ExecStart = "/bin/app";
              wantedBy = [ "multi-user.target" ];
            };
          }
        ];
    }
    {
      name = "required-by-falsely-flagged";
      # nixpkgs paperless-secret-key class (found live 2026-10-01): the unit
      # installs itself into consumers' .requires — attr-graph invisible but
      # very much started.
      pass =
        !flagged "prep-key" [
          {
            systemd.services.prep-key = {
              serviceConfig.ExecStart = "/bin/true";
              requiredBy = [ "consumer-daemon.service" ];
            };
          }
        ];
    }
    {
      name = "onfailure-sink-falsely-flagged";
      # rpi3 crush-update-failure class: failure sinks are pulled by
      # OnFailure=, not by wants/requires.
      pass =
        !flagged "failure-sink" [
          {
            systemd.services.failure-sink.serviceConfig.ExecStart = "/bin/notify";
            systemd.services.main-daemon = {
              serviceConfig.ExecStart = "/bin/app";
              wantedBy = [ "multi-user.target" ];
              onFailure = [ "failure-sink.service" ];
            };
          }
        ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "stray-unit-audit-negative-test" { } "touch $out"
else
  pkgs.runCommand "stray-unit-audit-negative-test" { } ''
    echo "stray-unit-audit negative test FAILED for: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
