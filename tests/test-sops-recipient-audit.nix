# Negative test for the sops-recipient-audit eval-time guard (pure eval, no VM).
#
# CI surface proving the guard fires on the live incident shape (a recipient
# added to .sops.yaml but `sops updatekeys` never run on the encrypted
# files; rpi3-dns has shipped in exactly this state since 2026-06):
#
#   1. A file MISSING a rule-mandated recipient FAILS the assertion (named).
#   2. A file carrying a STALE recipient (not mandated) FAILS (named) —
#      rotated-away keys must not silently keep decrypt rights.
#   3. A file matching NO creation rule FAILS (sops refuses those files).
#   4. Conforming files (both-forms recipient syntax) produce NO findings.
#   5. The REAL repo (default options) produces NO findings — this case is
#      the live enforcement: it goes red the moment a real secrets file
#      drifts from .sops.yaml, independent of host evals.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  audit =
    (import ../modules/nixos/services/sops-recipient-audit.nix).flake.nixosModules.sops-recipient-audit;

  fixtures = ./fixtures/sops-recipients;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "sops-recipient-audit:" a.message) assertions;

  fixtureAssertions = evalAssertions [
    {
      services.sops-recipient-audit = {
        sopsYaml = fixtures + "/.sops.yaml";
        secretsDir = fixtures;
      };
    }
  ];

  hasFinding =
    name: infix:
    let
      hits = builtins.filter (a: lib.hasInfix infix a.message) (failing fixtureAssertions);
    in
    hits != [ ] && lib.hasInfix name (builtins.head hits).message;

  cases = [
    {
      name = "missing-recipient-not-caught";
      pass = hasFinding "shared-missing.yaml" "age1bbbb";
    }
    {
      name = "stale-recipient-not-caught";
      pass = hasFinding "hosta-stale.yaml" "age1cccc";
    }
    {
      name = "no-rule-file-not-flagged";
      pass = hasFinding "unmatched.yaml" "matches no .sops.yaml creation rule";
    }
    {
      name = "conforming-file-falsely-flagged";
      pass =
        builtins.filter (
          a: lib.hasInfix "shared-ok.yaml" a.message || lib.hasInfix "hosta-ok.yaml" a.message
        ) (failing fixtureAssertions) == [ ];
    }
    {
      name = "real-repo-drift";
      pass = failing (evalAssertions [ ]) == [ ];
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "sops-recipient-audit-negative-test" { } "touch $out"
else
  throw ''
    sops-recipient-audit regression (or real drift, for real-repo-drift):
    ${toString broken}
    The guard must catch missing/stale sops recipients vs .sops.yaml
    creation rules without false positives. If it was refactored,
    re-verify with THIS test; if real-repo-drift failed, a real secrets
    file no longer carries the recipients its .sops.yaml rule mandates:
    run sops updatekeys on the file named in the assertion message.
  ''
