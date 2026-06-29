{
  config,
  pkgs,
  lib,
  ...
}: {
  # Import Darwin-specific system configurations
  imports = [
    # Cross-platform preferences (dark mode, fonts, themes — single source of truth)
    ../common/preferences.nix
    ./networking/default.nix
    ./nix/settings.nix
    ./security/pam.nix
    ./security/keychain.nix
    ./services/launchagents.nix # Declarative LaunchAgents (replaces bash scripts)
    ./system/activation.nix
    ./system/settings.nix
    ./environment.nix
    ./programs/chrome.nix # Chrome policy configuration for extension management
    ../common/packages/base.nix
    ../common/packages/fonts.nix
  ];

  # Wrap all configuration in config attribute
  config = {
    # Build-time validation: Ensure critical packages exist in nixpkgs
    # These assertions fail fast if packages are unavailable
    assertions = [
      {
        assertion = builtins.hasAttr "d2" pkgs;
        message = "d2 package not found in nixpkgs - verify package name and availability";
      }
    ];

    # Note: nixpkgs.config is now centralized in ../common/nix-settings.nix
    # This eliminates duplicate allowUnfree and permittedInsecurePackages declarations

    # Homebrew casks for GUI applications not available in nixpkgs
    homebrew = {
      enable = true;
      casks = [
        "headlamp" # Kubernetes dashboard GUI
      ];
    };

    # NOTE: Go overlay removed — nixpkgs go_1_26 is already 1.26.1.
    # Overriding go forced a from-source rebuild that invalidated the
    # binary cache for the ENTIRE dependency tree (1094 derivations).
    # Matches flake.nix approach — see the goOverlay removal note there.

    # Home Manager workaround: Explicit user definition required
    # Home Manager's nix-darwin/default.nix imports ../nixos/common.nix which
    # requires config.users.users.<name>.home to be defined for home.directory
    # See: https://github.com/nix-community/home-manager/issues/6036
    users.users.larsartmann = {
      name = "larsartmann";
      home = "/Users/larsartmann";
    };
  };
}
