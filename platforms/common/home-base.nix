# Common Home Manager configuration for all platforms
{ config, ... }:
let
  privateGoPattern = "github.com/larsartmann/go-cqrs-lite,github.com/larsartmann/go-finding,github.com/larsartmann/go-structure-linter,github.com/LarsArtmann/go-commit";
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

      # Only the 4 truly private LarsArtmann repos need to skip the Go proxy.
      # All other repos are public and served by proxy.golang.org.
      # Setting GOPRIVATE too broadly (e.g. github.com/LarsArtmann/*) causes Go to
      # skip the proxy for ALL repos, breaking vendorHash computation in the Nix sandbox
      # (sandbox has no SSH keys → git clone fails → build fails → fakeHash forever).
      GOPRIVATE = privateGoPattern;

      GONOSUMDB = privateGoPattern;
    };

    # Home Manager version for compatibility
    stateVersion = "24.05";
  };

  # Auto-start/restart user services after activation (fixes new services landing inactive)
  systemd.user.startServices = "sd-switch";
}
