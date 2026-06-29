# Bash shell configuration
_: let
  # Import shared aliases from shell-aliases.nix
  commonAliases = (import ./shell-aliases.nix {}).commonShellAliases;
  # Expected common aliases
  # Type assertions
in {
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
    '';
  };
}
