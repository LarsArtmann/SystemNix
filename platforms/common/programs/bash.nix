# Bash shell configuration
_:
let
  # Import shared aliases from shell-aliases.nix
  commonAliases = (import ./shell-aliases.nix { }).commonShellAliases;
  # Expected common aliases
  # Type assertions
in
{
  # Common Bash shell configuration
  programs.bash = {
    enable = true;

    # Use shared aliases (no duplication!)
    shellAliases = commonAliases;

    # Bash-specific configuration
    historyControl = [
      "erasedups"
      "ignoredups"
      "ignorespace"
    ];
    historyFileSize = 10000;
    historySize = 5000;

    shellOptions = [
      "cdspell"
      "checkwinsize"
      "cmdhist"
      "histappend"
      "autocd"
      "globstar"
      "nocaseglob"
    ];

    initExtra = ''
      export GH_PAGER=""

      export HISTCONTROL=ignoredups:erasedups
      export HISTSIZE=10000
      export HISTFILESIZE=10000

      # superfile wrapper (cd-on-quit): after quitting, source superfile's
      # lastdir file so the shell lands in the browsed directory. Function,
      # NOT an alias — bash expands aliases before function lookup, so an
      # alias `spf` would shadow this and break cd-on-quit. Calls
      # `command superfile` (the upstream flake binary name).
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
