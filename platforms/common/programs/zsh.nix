# Zsh shell configuration (Cross-Platform)
# Performance-optimized config migrated from dotfiles/.zshrc
{ config, ... }:
let
  # Import shared aliases from shell-aliases.nix
  commonAliases = (import ./shell-aliases.nix { }).commonShellAliases;
  # Expected common aliases
  # Type assertions
in
{
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

    # superfile wrapper (cd-on-quit): after quitting, source superfile's
    # lastdir file so the shell lands in the browsed directory. Function,
    # NOT an alias — zsh expands aliases before function lookup, so an
    # alias `spf` would shadow this and break cd-on-quit. Calls
    # `command superfile` (the upstream flake binary name).
    initExtra = ''
      spf() {
        if [[ "$(uname -s)" == "Darwin" ]]; then
          export SPF_LAST_DIR="$HOME/Library/Application Support/superfile/lastdir"
        else
          export SPF_LAST_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/superfile/lastdir"
        fi
        command superfile "$@"
        [ ! -f "$SPF_LAST_DIR" ] || { . "$SPF_LAST_DIR"; rm -f -- "$SPF_LAST_DIR" >/dev/null; }
      }
    '';
  };
}
