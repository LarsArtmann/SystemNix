# Negative test for the systemd-shape-audit eval-time guard (pure eval, no VM).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves the guard fires on each documented incident shape:
#
#   1. Type=oneshot + Restart=always FAILS the assertion (named unit).
#   2. Matching timer + Restart=on-failure FAILS the assertion.
#   3. allowTimerRestart suppresses class 2 for the allowlisted unit.
#   4. Path unit triggered by PathExists FAILS the assertion.
#   5. PathChanged (the correct trigger) does NOT fire it.
#   6. A clean timer+oneshot (Restart unset → defaults to no) passes.
#
# The no-false-positives half against the REAL config is enforced by
# `nix flake check` itself — the audit evaluates against evo-x2 there.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  audit =
    (import ../modules/nixos/services/systemd-shape-audit.nix).flake.nixosModules.systemd-shape-audit;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "systemd-shape-audit:" a.message) assertions;

  flaggedWith =
    infix: assertions:
    let
      f = failing assertions;
    in
    f != [ ] && lib.hasInfix infix (builtins.head f).message;

  cases = [
    {
      name = "oneshot-always-not-caught";
      pass = flaggedWith "invalid Restart" (evalAssertions [
        {
          systemd.services.bad-oneshot = {
            serviceConfig = {
              Type = "oneshot";
              Restart = "always";
            };
          };
        }
      ]);
    }
    {
      name = "timer-restart-race-not-caught";
      pass = flaggedWith "Restart != no" (evalAssertions [
        {
          systemd.services.racy-sync = {
            serviceConfig = {
              Type = "oneshot";
              Restart = "on-failure";
              RestartSec = "5min";
            };
          };
          systemd.timers.racy-sync = {
            wantedBy = [ "timers.target" ];
            timerConfig.OnUnitActiveSec = "5min";
          };
        }
      ]);
    }
    {
      name = "allowlist-not-honored";
      pass =
        failing (evalAssertions [
          {
            services.systemd-shape-audit.allowTimerRestart = [ "racy-sync" ];
            systemd.services.racy-sync = {
              serviceConfig = {
                Type = "oneshot";
                Restart = "on-failure";
              };
            };
            systemd.timers.racy-sync = {
              wantedBy = [ "timers.target" ];
              timerConfig.OnCalendar = "daily";
            };
          }
        ]) == [ ];
    }
    {
      name = "pathexists-not-caught";
      pass = flaggedWith "PathExists" (evalAssertions [
        {
          systemd.paths.bad-path = {
            wantedBy = [ "multi-user.target" ];
            pathConfig.PathExists = "/run/some-trigger";
          };
        }
      ]);
    }
    {
      name = "pathchanged-falsely-flagged";
      pass =
        failing (evalAssertions [
          {
            systemd.paths.good-path = {
              wantedBy = [ "multi-user.target" ];
              pathConfig.PathChanged = "/run/some-trigger";
            };
          }
        ]) == [ ];
    }
    {
      name = "clean-timer-oneshot-falsely-flagged";
      pass =
        failing (evalAssertions [
          {
            systemd.services.clean-sync.serviceConfig.Type = "oneshot";
            systemd.timers.clean-sync = {
              wantedBy = [ "timers.target" ];
              timerConfig.OnCalendar = "daily";
            };
          }
        ]) == [ ];
    }
    {
      name = "home-in-user-execstart-not-caught";
      pass = flaggedWith "$HOME" (evalAssertions [
        {
          systemd.user.services.home-user = {
            serviceConfig.ExecStart = "/bin/app --config $HOME/.config/app";
          };
        }
      ]);
    }
    {
      name = "percent-h-falsely-flagged";
      pass =
        failing (evalAssertions [
          {
            systemd.user.services.specifier-user = {
              serviceConfig.ExecStart = "/bin/app --config %h/.config/app";
            };
          }
        ]) == [ ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "systemd-shape-audit-negative-test" { } "touch $out"
else
  pkgs.runCommand "systemd-shape-audit-negative-test" { } ''
    echo "systemd-shape-audit negative test FAILED for: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
