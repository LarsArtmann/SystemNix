# Negative test for the port-registry-audit eval-time guard (pure eval).
#
# Proves the guard fires on each literal form and stays silent on the
# lookalikes that must NOT be flagged:
#
#   1. Unregistered host-form literal (127.0.0.1:8150 in ExecStart) FAILS.
#   2. Registered port passes (no false positive on the happy path).
#   3. allowPorts suppresses the finding for the exempted port.
#   4. Unregistered port in Environment attrset form FAILS.
#   5. colon-form URL (http://host:8150) FAILS.
#   6. Lookalikes (store PATH, version 1.26, clock 2:30) do NOT fire.
#
# The no-false-positives half against the REAL config is enforced by
# `nix flake check` itself — the audit evaluates against evo-x2 there
# (verified clean on first deploy of this guard: 2026-09-14).
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  audit = (import ../modules/nixos/services/port-registry-audit.nix).flake.nixosModules.port-registry-audit;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "port-registry-audit:" a.message) assertions;

  flaggedWith =
    infix: assertions:
    let f = failing assertions; in
    f != [ ] && lib.hasInfix infix (builtins.head f).message;

  cases = [
    {
      name = "unregistered-host-form-not-caught";
      pass = flaggedWith "bad-svc: 8150" (
        evalAssertions [
          {
            systemd.services.bad-svc.serviceConfig.ExecStart = "/bin/app --listen 127.0.0.1:8150";
          }
        ]
      );
    }
    {
      name = "registered-port-falsely-flagged";
      pass =
        failing (
          evalAssertions [
            {
              systemd.services.good-svc.serviceConfig.ExecStart = "/bin/app --listen 127.0.0.1:8099";
            }
          ]
        ) == [ ];
    }
    {
      name = "allowports-not-honored";
      pass =
        failing (
          evalAssertions [
            {
              services.port-registry-audit.allowPorts = [ 8150 ];
              systemd.services.exempt-svc.serviceConfig.ExecStart = "/bin/app --listen 127.0.0.1:8150";
            }
          ]
        ) == [ ];
    }
    {
      name = "environment-attrset-form-not-caught";
      pass = flaggedWith "env-svc: 8151" (
        evalAssertions [
          {
            systemd.services.env-svc.serviceConfig = {
              ExecStart = "/bin/app";
              Environment = {
                UPSTREAM = "http://127.0.0.1:8151";
                MODE = "plain";
              };
            };
          }
        ]
      );
    }
    {
      name = "url-colon-form-not-caught";
      pass = flaggedWith "url-svc: 8152" (
        evalAssertions [
          {
            systemd.services.url-svc.serviceConfig.ExecStart = "/bin/app --webhook http://example.test:8152/hook";
          }
        ]
      );
    }
    {
      name = "lookalikes-falsely-flagged";
      pass =
        failing (
          evalAssertions [
            {
              systemd.services.lookalike-svc.serviceConfig = {
                ExecStart = "/bin/app --toolchain 1.26 --meeting 2:30";
                Environment = [
                  "PATH=/nix/store/abc123-bin:/nix/store/def456-lib"
                  "GOFLAGS=-trimpath"
                  # Live false positive on first deploy of the guard (2026-09-14):
                  # fastflowlm/PMA model name parsed as host:port 35.
                  "OPENAI_MODEL=qwen3.6-moe:35b-a3b"
                ];
              };
            }
          ]
        ) == [ ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "port-registry-audit-negative-test" { } "touch $out"
else
  pkgs.runCommand "port-registry-audit-negative-test"
    { }
    ''
      echo "port-registry-audit negative test FAILED for: ${lib.concatStringsSep ", " broken}"
      exit 1
    ''
