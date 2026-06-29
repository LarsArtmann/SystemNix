{
  pkgs,
  lib,
  ...
}: let
  # Common development environment variables (platform-agnostic)
  commonEnvVars = {
    # Core system settings
    EDITOR = "micro"; # micro-full is installed in base.nix
    # VISUAL and MANPAGER are set in home-base.nix sessionVariables (single source of truth)
    LANG = "en_US.UTF-8";

    # Optimize NIX_PATH for better performance
    NIX_PATH = lib.mkForce "nixpkgs=flake:nixpkgs";

    # Development environment enhancements
    NODE_OPTIONS = "--max-old-space-size=4096";
    NPM_CONFIG_AUDIT = "false";
    NPM_CONFIG_FUND = "false";

    # Build and deployment optimization
    NIXPKGS_ALLOW_UNFREE = "1";
    NIXPKGS_ALLOW_BROKEN = "0"; # Strict: No broken packages
    NIXPKGS_ALLOW_INSECURE = "0"; # Strict: No insecure packages

    # Additional environment variables
    PAGER = "less";
    LESS = "-R"; # Enable color output in less
    CLICOLOR = "1"; # Enable color output in ls
    LSCOLORS = "ExGxBxDxCxEgEdxbxgxcxd"; # Custom ls colors

    # Crush AI assistant
    CRUSH_SHORT_TOOL_DESCRIPTIONS = "1";
  };
in {
  # Shell configuration (platform-agnostic)
  environment.shells = with pkgs; [
    fish
    zsh
    bash
  ];

  # Environment variables
  environment.variables = commonEnvVars;
}
