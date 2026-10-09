# perSystem pkgs instantiation — nixpkgs imported once per system with the
# shared overlays. _module.args.pkgs overrides flake-parts' default pkgs for
# EVERY perSystem module (single evaluator, same semantics as when this lived
# in flake.nix). Split out of flake.nix 2026-10-08.
{
  inputs,
  sharedOverlays,
  linuxOnlyOverlays,
  disableTests,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      # Allow unfree and broken packages for all systems
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.allowBroken = false; # # <-- THIS MUST ALWAYS BE FALSE!
        overlays =
          sharedOverlays
          ++ [ disableTests ]
          ++ lib.optionals (lib.hasSuffix "-linux" system) linuxOnlyOverlays;
      };
    };
}
