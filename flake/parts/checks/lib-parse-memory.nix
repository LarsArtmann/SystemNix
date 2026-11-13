# Regression contract for lib/systemd.nix parseMemoryBytes (2026-11-13).
#
# The nixos-modules collection's tests/lib-eval.nix found that
# builtins.match yields null — not "" — for a non-participating optional
# group, so a bare-byte MemoryMax ("5242880") crashed the multiplier
# dynamic-select. SystemNix's lib/systemd.nix is the forked-during-
# migration twin (byte-parity at extraction), so it carried the same
# crash; the identical null → "" fix landed in both repos on 2026-11-13.
#
# The lib is imported through `root` with the perSystem lib — the house
# idiom for check-side lib access (same as features-drift /
# registry-matrix). The `flake.lib` output suffered a long-standing
# "anomaly" (helpers failing with `attribute 'genAttrs' missing`) that
# was root-caused 2026-11-13: flake.nix passed `{ inherit (nixpkgs)
# lib; }` to a lib/default.nix whose parameter is the SIMPLE `lib:` form,
# so the whole wrapper attrset bound to the parameter. Fixed in flake.nix
# (`import ./lib lib`); this perSystem idiom was always correct and stays
# the house style.
#
# This check pins the fix through the PUBLIC surface (harden's derived
# MemoryHigh), never by re-importing the internals: suffixed forms, the
# bare-byte form, explicit MemoryHigh passthrough, and the unparsable
# fallback ("80%" stays literal).
{
  root,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      checks.lib-parse-memory =
        let
          fleetLib = import (root + "/lib") lib;
          high = max: (fleetLib.harden { MemoryMax = max; }).MemoryHigh.content;
          guards =
            assert high "512M" == "429496729";
            assert high "1G" == "858993459";
            assert high "5242880" == "4194304"; # the crash shape: bare bytes, no suffix
            assert
              (fleetLib.harden {
                MemoryMax = "512M";
                MemoryHigh = "600M";
              }).MemoryHigh.content == "600M";
            assert (fleetLib.harden { MemoryMax = "80%"; }).MemoryHigh.content == "80%"; # unparsable → literal fallback
            true;
        in
        builtins.deepSeq guards (
          pkgs.runCommand "lib-parse-memory-check" { } ''
            echo "lib parseMemoryBytes: bare-byte + suffixed + fallback forms pinned" > $out
          ''
        );
    };
}
