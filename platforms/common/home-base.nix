# Common Home Manager configuration for all platforms
{config, ...}: {
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

      # Private Go modules (use SSH instead of public proxy)
      # Note: Both case variants needed - Go module paths are case-sensitive
      GOPRIVATE = "github.com/LarsArtmann/*,github.com/larsartmann/*";

      # Disable checksum database for private repos
      GONOSUMDB = "github.com/LarsArtmann/*,github.com/larsartmann/*";
    };

    # PATH additions (available to all shells)
    sessionPath = [
      # Go binaries installed via `go install` (not managed by Nix)
      # Currently: govalid (sivchari/govalid)
      "${config.home.homeDirectory}/go/bin"
    ];

    # Home Manager version for compatibility
    stateVersion = "24.05";
  };
}
