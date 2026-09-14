# Negative test for the mount-gating-audit eval-time guard (pure eval, no VM).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves the guard fires on each documented incident shape:
#
#   1. ReadWritePaths under /mnt/ with no gating FAILS (named unit + path).
#   2. RequiresMountsFor on the exact path passes.
#   3. RequiresMountsFor on an ANCESTOR (mount root) passes.
#   4. RequiresMountsFor on a DESCENDANT passes (atticd-storage-dir shape).
#   5. ConditionPathIsMountPoint on an ancestor passes (buildcache-gc shape).
#   6. ConditionPathIsDirectory does NOT satisfy (shadow-dir masking class).
#   7. allowUnits suppresses the finding.
#   8. /data paths are out of scope (fixed internal partition).
#   9. Component-boundary precision: /mnt/pool does not gate /mnt/poolx.
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
    (import ../modules/nixos/services/mount-gating-audit.nix).flake.nixosModules.mount-gating-audit;

  evalAssertions =
    extraModules:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ audit ] ++ extraModules;
    }).config.assertions;

  failing =
    assertions:
    builtins.filter (a: !a.assertion && lib.hasPrefix "mount-gating-audit:" a.message) assertions;

  flaggedWith =
    infix: assertions:
    let
      f = failing assertions;
    in
    f != [ ] && lib.hasInfix infix (builtins.head f).message;

  cases = [
    {
      name = "ungated-mnt-not-caught";
      pass = flaggedWith "ungated-svc: /mnt/pool/backups/x" (evalAssertions [
        {
          systemd.services.ungated-svc = {
            serviceConfig = {
              Type = "oneshot";
              ReadWritePaths = [ "/mnt/pool/backups/x" ];
            };
          };
        }
      ]);
    }
    {
      name = "exact-rmf-not-passing";
      pass =
        failing (evalAssertions [
          {
            systemd.services.gated-exact = {
              unitConfig.RequiresMountsFor = [ "/mnt/pool/backups/x" ];
              serviceConfig.ReadWritePaths = [ "/mnt/pool/backups/x" ];
            };
          }
        ]) == [ ];
    }
    {
      name = "ancestor-rmf-not-passing";
      pass =
        failing (evalAssertions [
          {
            systemd.services.gated-ancestor = {
              unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
              serviceConfig.ReadWritePaths = [ "/mnt/pool/backups/cv" ];
            };
          }
        ]) == [ ];
    }
    {
      name = "descendant-rmf-not-passing";
      pass =
        failing (evalAssertions [
          {
            # atticd-storage-dir shape: WritePaths on the parent, gate on
            # the deeper path (the gate pulls the same mount unit).
            systemd.services.gated-descendant = {
              unitConfig.RequiresMountsFor = [ "/mnt/pool/services/x/storage" ];
              serviceConfig.ReadWritePaths = [ "/mnt/pool/services/x" ];
            };
          }
        ]) == [ ];
    }
    {
      name = "condition-mountpoint-not-passing";
      pass =
        failing (evalAssertions [
          {
            systemd.services.gated-condition = {
              serviceConfig = {
                ReadWritePaths = [ "/mnt/buildcache/go" ];
                ConditionPathIsMountPoint = "/mnt/buildcache";
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "condition-directory-not-caught";
      pass = flaggedWith "shadow-svc: /mnt/pool/svc" (evalAssertions [
        {
          # A root-fs shadow dir satisfies ConditionPathIsDirectory — the
          # exact 2026-08-31 masking bug. It must NOT count as gating.
          systemd.services.shadow-svc = {
            serviceConfig = {
              Type = "oneshot";
              ReadWritePaths = [ "/mnt/pool/svc" ];
              ConditionPathIsDirectory = "/mnt/pool/svc";
            };
          };
        }
      ]);
    }
    {
      name = "allowlist-not-honored";
      pass =
        failing (evalAssertions [
          {
            services.mount-gating-audit.allowUnits = [ "ungated-svc" ];
            systemd.services.ungated-svc = {
              serviceConfig = {
                Type = "oneshot";
                ReadWritePaths = [ "/mnt/pool/backups/x" ];
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "data-out-of-scope-not-flagged";
      pass =
        failing (evalAssertions [
          {
            systemd.services.data-svc = {
              serviceConfig = {
                Type = "oneshot";
                ReadWritePaths = [ "/data/ai/models/ollama" ];
              };
            };
          }
        ]) == [ ];
    }
    {
      name = "component-boundary-not-enforced";
      pass = flaggedWith "sibling-svc: /mnt/poolx" (evalAssertions [
        {
          # /mnt/pool must NOT gate /mnt/poolx — a naive hasPrefix check
          # would let this through.
          systemd.services.sibling-svc = {
            unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
            serviceConfig = {
              Type = "oneshot";
              ReadWritePaths = [ "/mnt/poolx" ];
            };
          };
        }
      ]);
    }
  ];

  failedCases = builtins.filter (c: !c.pass) cases;
in
if failedCases == [ ] then
  pkgs.runCommand "test-mount-gating-audit-pass" { } "touch $out"
else
  pkgs.runCommand "test-mount-gating-audit-fail" { } ''
    echo "mount-gating-audit negative test failures:"
    echo ""
    ${lib.concatMapStrings (c: "echo '  - ${c.name}'\n") failedCases}
    exit 1
  ''
