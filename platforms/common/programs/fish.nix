# Fish shell configuration
_:
let
  # Import shared aliases from shell-aliases.nix
  commonAliases = (import ./shell-aliases.nix { }).commonShellAliases;
in
{
  # Common Fish shell configuration
  programs.fish = {
    enable = true;

    # Use shared aliases (no duplication!)
    shellAliases = commonAliases;

    # Common Fish shell initialization
    interactiveShellInit = ''
      # LOCALE: Set English locale for git and other tools
      set -gx LANG en_US.UTF-8
      set -gx LC_CTYPE en_US.UTF-8

      # PERFORMANCE: Disable greeting for faster startup
      set -g fish_greeting

      # Note: GOPATH, GOPRIVATE, GONOSUMDB are managed by Home Manager sessionVariables

      # PERFORMANCE: Optimized history settings
      set -g fish_maximum_history_size 5000

      # Additional Fish-specific optimizations
      set -g fish_autosuggestion_enabled 1

      # GOPATH/bin needs to be in PATH for Go binaries
      if set -q GOPATH
        fish_add_path --prepend --global $GOPATH/bin
      end
    '';
  };
}
