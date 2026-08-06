{ lib, ... }: {
  # Import common Nix settings (Darwin-specific overrides below)
  imports = [ ../../common/nix-settings.nix ];

  # Darwin-specific Nix settings overrides
  # Note: Most settings are inherited from ../../common/nix-settings.nix
  # Only Darwin-specific overrides are needed here
  nix.settings = {
    # Darwin override: sandbox disabled due to compatibility issues with macOS
    # Using lib.mkForce to properly override the common module's sandbox = true
    sandbox = lib.mkForce false;
  };

  # ── nixpkgs tarball regression: ROOT CAUSE FIX ──────────────────────────
  # Mirrors the NixOS fix in platforms/nixos/system/configuration.nix.
  # Layer 1: empty local flake-registry (eliminates global tarball entries).
  # Layer 2: correct-format registry overrides (from.id + from.ref, not combined string).
  nix.settings.flake-registry = builtins.toFile "empty-flake-registry.json" ''
    {"flakes":[],"version":2}
  '';
  nix.registry.nixpkgs-nixos-unstable = {
    from = {
      type = "indirect";
      id = "nixpkgs";
      ref = "nixos-unstable";
    };
    to = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };
    exact = true;
  };
  nix.registry.nixpkgs-nixpkgs-unstable = {
    from = {
      type = "indirect";
      id = "nixpkgs";
      ref = "nixpkgs-unstable";
    };
    to = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixpkgs-unstable";
    };
    exact = true;
  };
}
