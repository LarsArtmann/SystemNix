# Negative test for the gatus-coverage-audit eval-time guard (pure eval).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves the guard fires on each documented incident shape:
#
#   1. Registered port referenced by a live unit but never probed FAILS.
#   2. Port covered by a gatus URL passes.
#   3. allowPorts suppresses the finding.
#   4. Loopback gatus URL with an unregistered port FAILS (reverse drift).
#   5. External upstream URLs (dot.mullvad.net:853) are exempt.
#   6. Gatus disabled on the host → coverage assertion skipped entirely.
#   7. UNREGISTERED port in unit text is NOT this audit's problem
#      (port-registry-audit owns that direction).
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
    (import ../modules/nixos/services/gatus-coverage-audit.nix).flake.nixosModules.gatus-coverage-audit;

  # No mock needed: nixpkgs' own services/monitoring/gatus.nix (part of
  # every nixosSystem eval) already declares services.gatus.enable and
  # the settings freeform the audit reads.

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "gatus-coverage-audit:" a.message) assertions;

  flaggedWith =
    infix: assertions:
    let
      f = failing assertions;
    in
    f != [ ] && lib.hasInfix infix (builtins.head f).message;

  homepagePort = 8082; # from lib/ports.nix (registered)

  cases = [
    {
      name = "uncovered-port-not-caught";
      pass = flaggedWith "8082 (referenced by: homepage-svc)" (evalAssertions [
        {
          services.gatus.enable = true;
          services.gatus.settings.endpoints = [
            {
              name = "Gatus self";
              url = "http://localhost:9110";
              conditions = [ "[STATUS] == 200" ];
            }
          ];
          systemd.services.homepage-svc = {
            serviceConfig = {
              ExecStart = "/bin/homepage --listen 127.0.0.1:${toString homepagePort}";
            };
          };
        }
      ]);
    }
    {
      name = "covered-port-not-passing";
      pass =
        failing (evalAssertions [
          {
            services.gatus.enable = true;
            services.gatus.settings.endpoints = [
              {
                name = "Homepage";
                url = "http://localhost:${toString homepagePort}";
                conditions = [ "[STATUS] == 200" ];
              }
            ];
            systemd.services.homepage-svc = {
              serviceConfig = {
                ExecStart = "/bin/homepage --listen 127.0.0.1:${toString homepagePort}";
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "allowlist-not-honored";
      pass =
        failing (evalAssertions [
          {
            services.gatus.enable = true;
            services.gatus-coverage-audit.allowPorts = [ homepagePort ];
            systemd.services.homepage-svc = {
              serviceConfig = {
                ExecStart = "/bin/homepage --listen 127.0.0.1:${toString homepagePort}";
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "reverse-drift-not-caught";
      pass = flaggedWith "unregistered port" (evalAssertions [
        {
          services.gatus.enable = true;
          services.gatus.settings.endpoints = [
            {
              name = "Bad check";
              url = "http://localhost:9999/health";
              conditions = [ "[STATUS] == 200" ];
            }
          ];
        }
      ]);
    }
    {
      name = "external-upstream-not-exempt";
      pass =
        failing (evalAssertions [
          {
            services.gatus.enable = true;
            services.gatus.settings.endpoints = [
              {
                name = "DNS over TLS";
                url = "tcp://dot.mullvad.net:853";
                conditions = [ "[CONNECTED] == true" ];
              }
            ];
          }
        ]) == [ ];
    }
    {
      name = "gatus-disabled-not-skipped";
      pass =
        failing (evalAssertions [
          {
            services.gatus.enable = false;
            systemd.services.homepage-svc = {
              serviceConfig = {
                ExecStart = "/bin/homepage --listen 127.0.0.1:${toString homepagePort}";
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "unregistered-in-use-not-this-audits";
      pass =
        failing (evalAssertions [
          {
            services.gatus.enable = true;
            systemd.services.mystery-svc = {
              serviceConfig = {
                ExecStart = "/bin/mystery --listen 127.0.0.1:7777";
              };
            };
          }
        ]) == [ ];
    }
  ];

  failedCases = builtins.filter (c: !c.pass) cases;
in
if failedCases == [ ] then
  pkgs.runCommand "test-gatus-coverage-audit-pass" { } "touch $out"
else
  pkgs.runCommand "test-gatus-coverage-audit-fail" { } ''
    echo "gatus-coverage-audit negative test failures:"
    echo ""
    ${lib.concatMapStrings (c: "echo '  - ${c.name}'\n") failedCases}
    exit 1
  ''
