# VM + eval test suite merge (tests/): the original flake.nix checks tail —
# `checks = { ... } // lib.optionalAttrs isLinux (import ./tests { ... })`.
# Split out of flake.nix 2026-10-08.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
        import (root + "/tests") {
          inherit
            pkgs
            lib
            system
            inputs
            ;
        }
      );
    };
}
