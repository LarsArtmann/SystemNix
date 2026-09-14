# Negative test for the deploy-restart-audit eval-time guard (pure eval).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves the guard fires on each documented incident shape:
#
#   1. Converger-pattern oneshot absent from scripts/deploy.sh FAILS.
#   2. oneshot+RemainAfterExit+restartTriggers absent from deploy.sh FAILS
#      (the inert-restartTriggers trap).
#   3. restartTriggers on a NON-oneshot unit is NOT flagged (stc honors
#      them there) when the unit name is absent from deploy.sh.
#   4. A pattern-matching oneshot that IS named in deploy.sh passes
#      (tq-storage-dir rides the provisioner loop).
#   5. The default upstream allowlist covers postfix-setup.
#   6. Plain timer-driven backup oneshots (no pattern, no triggers) pass.
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
    (import ../modules/nixos/services/deploy-restart-audit.nix).flake.nixosModules.deploy-restart-audit;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "deploy-restart-audit:" a.message) assertions;

  flaggedWith =
    infix: assertions:
    let
      f = failing assertions;
    in
    f != [ ] && lib.hasInfix infix (builtins.head f).message;

  cases = [
    {
      name = "pattern-converger-not-caught";
      pass = flaggedWith "probe-storage-dir" (evalAssertions [
        {
          systemd.services.probe-storage-dir = {
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
          };
        }
      ]);
    }
    {
      name = "inert-restart-triggers-not-caught";
      pass = flaggedWith "probe-converger" (evalAssertions [
        {
          systemd.services.probe-converger = {
            restartTriggers = [ "/store/path/script.sh" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
          };
        }
      ]);
    }
    {
      name = "live-restart-triggers-not-exempt";
      pass =
        failing (evalAssertions [
          {
            # stc honors restartTriggers on non-oneshot units — no deploy.sh
            # entry needed even though the name is absent from the script.
            systemd.services.probe-daemon = {
              restartTriggers = [ "/store/path/config.yaml" ];
              serviceConfig.Type = "simple";
            };
          }
        ]) == [ ];
    }
    {
      name = "deploy-sh-unit-not-passing";
      pass =
        failing (evalAssertions [
          {
            # Named in the provisioner loop of the REAL scripts/deploy.sh.
            systemd.services.tq-storage-dir = {
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "default-allowlist-not-honored";
      pass =
        failing (evalAssertions [
          {
            systemd.services.postfix-setup = {
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "plain-backup-oneshot-not-flagged";
      pass =
        failing (evalAssertions [
          {
            systemd.services.probe-nightly-backup = {
              serviceConfig.Type = "oneshot";
            };
          }
        ]) == [ ];
    }
  ];

  failedCases = builtins.filter (c: !c.pass) cases;
in
if failedCases == [ ] then
  pkgs.runCommand "test-deploy-restart-audit-pass" { } "touch $out"
else
  pkgs.runCommand "test-deploy-restart-audit-fail" { } ''
    echo "deploy-restart-audit negative test failures:"
    echo ""
    ${lib.concatMapStrings (c: "echo '  - ${c.name}'\n") failedCases}
    exit 1
  ''
