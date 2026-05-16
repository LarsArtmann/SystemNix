# Zsh shell configuration (Cross-Platform)
# Performance-optimized config migrated from dotfiles/.zshrc
{config, ...}: let
  # Import shared aliases from shell-aliases.nix
  commonAliases = (import ./shell-aliases.nix {}).commonShellAliases;
  # Expected common aliases
  # Type assertions
in {
  # Common Zsh shell configuration
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    # Use shared aliases (no duplication!)
    shellAliases = commonAliases;

    # Autosuggestions
    autosuggestion.enable = true;

    # History
    history = {
      ignoreDups = true;
      ignoreSpace = true;
      save = 10000;
      size = 10000;
      share = false;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    # Syntax highlighting
    syntaxHighlighting.enable = true;

    # Environment variables
    envExtra = ''
      # Environment variables
      export GH_PAGER=""

      # Note: GOPATH is now managed by Home Manager programs.go
      # See: platforms/common/home-base.nix

      # Source private environment variables (not tracked in git)
      if [[ -f ~/.env.private ]]; then
        source ~/.env.private
      fi
    '';
  };
}
