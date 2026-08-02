# Common Home Manager configuration for all platforms
{ config, ... }:
let
  # All LarsArtmann repos are treated as potentially private.
  # The wildcard ensures new private repos work without config updates.
  # The Nix sandbox uses its own GOPRIVATE in the build expression, not these
  # session variables, so this broad pattern only affects interactive shells
  # (where SSH keys are available for git clone fallback).
  privateGoPattern = "github.com/larsartmann/*,github.com/LarsArtmann/*";
in
{
  # Import common program configurations
  imports = [
    # Shell configurations (shared aliases, no duplication!)
    ./programs/fish.nix
    ./programs/zsh.nix
    ./programs/bash.nix

    # Other program configurations
    # SSH hosts shared across platforms (key auth via nix-ssh-config flake input)
    ./programs/ssh-config.nix
    ./programs/starship.nix
    ./programs/activitywatch.nix
    ./programs/tmux.nix
    ./programs/git.nix
    ./programs/fzf.nix
    ./programs/direnv.nix
    ./programs/pre-commit.nix
    ./programs/keepassxc.nix
    ./programs/taskwarrior.nix

    # Browser configuration with extension management
    ./programs/chromium.nix
  ];

  # Cross-platform shell configurations (Fish, Zsh, Bash)
  # All shells now use shared aliases from shell-aliases.nix
  # Platform-specific aliases added via lib.mkAfter in platform configs

  # Common program configurations
  programs = {
    # Enable Home Manager to manage itself
    home-manager.enable = true;

    # Go language configuration (Nix-native GOPATH management)
    go = {
      enable = true;
      # Note: env variables are set via home.sessionVariables below
      # This ensures GOPATH is available in all shells, not just Go commands
    };
  };

  # Home configuration
  home = {
    # Session variables (available to all shells and applications)
    sessionVariables = {
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      VISUAL = "code --wait";

      # Go development
      GOPATH = "${config.home.homeDirectory}/go";

      # All LarsArtmann repos skip the Go proxy and sum database.
      # See the privateGoPattern let binding above for rationale.
      GOPRIVATE = privateGoPattern;

      GONOSUMDB = privateGoPattern;
    };

    # Home Manager version for compatibility
    stateVersion = "24.05";
  };

  # Auto-start/restart user services after activation (fixes new services landing inactive)
  systemd.user.startServices = "sd-switch";
}
