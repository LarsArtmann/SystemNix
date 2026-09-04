# Negative test for the sops-key-audit eval-time guard (pure eval, no VM).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves the guard still fires on the 2026-09-04 incident shape
# (secret declared on master, key absent from the encrypted file):
#
#   1. A declared key missing from the sopsFile FAILS the assertion (named).
#   2. A present key passes (no false positive on the happy path).
#   3. A nested `key = "..."` secret is skipped (out of scope by design).
#   4. A runtime sopsFile (/run/secrets/...) is skipped (unreadable at eval).
#
# The no-false-positives half against the REAL config (every real secret key
# present in its real encrypted file) is enforced by `nix flake check` itself
# — this guard's assertions evaluate against evo-x2 there.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  audit = (import ../modules/nixos/services/sops-key-audit.nix).flake.nixosModules.sops-key-audit;

  # Encrypted-shaped fixture: key names plaintext (as in real sops files),
  # values opaque, `sops:` metadata tail mirroring the real files. Must be a
  # real tracked file (path type) — runtime/string sopsFiles are skipped by
  # design, and builtins.toFile returns a string, not a path.
  fixture = ./fixtures/sops-fixture.yaml;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.sops-nix.nixosModules.sops
        audit
      ]
      ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "sops-key-audit:" a.message) assertions;

  cases = [
    {
      name = "missing-key-not-caught";
      pass =
        let
          f = failing (evalAssertions [
            {
              sops.secrets.browser_history_agent_db_token = {
                sopsFile = fixture;
              };
            }
          ]);
        in
        f != [ ] && lib.hasInfix "browser_history_agent_db_token" (builtins.head f).message;
    }
    {
      name = "present-key-falsely-flagged";
      pass =
        failing (evalAssertions [
          {
            sops.secrets.present_key = {
              sopsFile = fixture;
            };
          }
        ]) == [ ];
    }
    {
      name = "nested-key-not-skipped";
      pass =
        failing (evalAssertions [
          {
            sops.secrets.other_name = {
              sopsFile = fixture;
              key = "present_key";
            };
          }
        ]) == [ ];
    }
    {
      name = "runtime-sopsfile-not-skipped";
      pass =
        failing (evalAssertions [
          {
            sops.secrets.runtime_thing = {
              sopsFile = "/run/secrets/does-not-exist";
            };
          }
        ]) == [ ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "sops-key-audit-negative-test" { } "touch $out"
else
  throw ''
    sops-key-audit regression: ${toString broken}
    The eval-time guard must catch the 2026-09-04 incident shape (declared
    secret key missing from its encrypted sopsFile) without false positives.
    If the guard was refactored, re-verify with THIS test — not with
    toplevel.drvPath, which never forces assertions.
  ''
