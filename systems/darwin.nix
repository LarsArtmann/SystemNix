# Lars-MacBook-Air — macOS via nix-darwin (aarch64-darwin)
#
# Assembles the full nix-darwin system: Homebrew taps pinned to flake inputs,
# Home Manager wiring, and the platform configuration.
{
  inputs,
  mkLarsPackages,
  sharedOverlays,
  sharedHomeManagerConfig,
  sharedHomeManagerSpecialArgs,
}: let
  inherit
    (inputs)
    nix-darwin
    nix-homebrew
    homebrew-bundle
    homebrew-cask
    home-manager
    ;
in
  nix-darwin.lib.darwinSystem {
    specialArgs = {
      inherit (inputs.self) inputs;
      inherit (inputs) nixpkgs helium nur;
      larsPackages = mkLarsPackages "aarch64-darwin";
    };
    modules = [
      {
        nixpkgs = {
          hostPlatform = "aarch64-darwin";
          config.allowUnfree = true;
          overlays = sharedOverlays;
        };
        # otel-tui is Linux-only (40+ min from-source build on macOS, disk-hungry)
        _module.args.otel-tui = null;
      }

      # Import nix-homebrew for declarative Homebrew management
      nix-homebrew.darwinModules.nix-homebrew
      {
        nix-homebrew = {
          enable = true;
          enableRosetta = true;
          user = "larsartmann";
          autoMigrate = true;
          # Pin Homebrew taps to flake inputs for reproducibility
          taps = {
            "homebrew/bundle" = homebrew-bundle;
            "homebrew/cask" = homebrew-cask;
          };
        };
      }

      # Import Home Manager module for Darwin
      home-manager.darwinModules.home-manager

      # Define Home Manager configuration inline for top-level visibility
      {
        home-manager =
          sharedHomeManagerConfig
          // {
            users.larsartmann = {...}: {
              imports = [
                ../platforms/darwin/home.nix
              ];
            };
            extraSpecialArgs = sharedHomeManagerSpecialArgs;
          };
      }

      # Core Darwin configuration
      ../platforms/darwin/default.nix
    ];
  }
