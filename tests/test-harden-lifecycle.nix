# Negative test for the harden{} lifecycle-key guard (pure eval, no VM).
#
# lib/systemd.nix THROWS when handed Exec*/Type/RemainAfterExit/Restart —
# the documented "harden {} ExecStart trap". Cases:
#
#   1. harden { Type = "oneshot"; … } THROWS.
#   2. harden { ExecStart = …; } THROWS.
#   3. harden { Restart = …; } THROWS.
#   4. hardenUser { ExecStartPre = …; } THROWS (inherits the guard).
#   5. Legitimate hardening args (the set used across the tree) pass.
#   6. The result still carries the expected hardening attributes.
#
# The no-false-positives half against the REAL tree is enforced by every
# evo-x2 eval — any module passing a lifecycle key now aborts evaluation.
{
  pkgs,
  inputs,
}:
let
  lib = inputs.nixpkgs.lib;

  harden = import ../lib/systemd.nix { inherit lib; };
  hardenUser = args: harden (args // { mode = "user"; });

  # Force the helper's full result; a throw => not success.
  threw = fragment: !(builtins.tryEval (builtins.deepSeq (fragment { }) null)).success;

  result = harden {
    MemoryMax = "2G";
    ReadWritePaths = [ "/var/lib/x" ];
    CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
    ProtectHome = false;
    SupplementaryGroups = [ "wheel" ];
  };

  cases = [
    {
      name = "type-inside-harden-not-caught";
      pass = threw (_: harden { Type = "oneshot"; });
    }
    {
      name = "execstart-inside-harden-not-caught";
      pass = threw (_: harden { ExecStart = "/bin/x"; });
    }
    {
      name = "restart-inside-harden-not-caught";
      pass = threw (_: harden { Restart = "on-failure"; });
    }
    {
      name = "hardenuser-execstartpre-not-caught";
      pass = threw (_: hardenUser { ExecStartPre = "/bin/wait"; });
    }
    {
      name = "legit-args-throw-falsely";
      pass = (builtins.tryEval (builtins.deepSeq result null)).success;
    }
    {
      name = "result-lost-hardening-attrs";
      pass =
        result ? MemoryMax
        && result ? ReadWritePaths
        && result ? CapabilityBoundingSet
        && result ? PrivateTmp
        && result ? ProtectHome;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "harden-lifecycle-negative-test" { } "touch $out"
else
  pkgs.runCommand "harden-lifecycle-negative-test" { } ''
    echo "harden lifecycle guard negative test FAILED for: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
