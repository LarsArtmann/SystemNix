# Import common shell configurations with platform-specific overrides
{lib, ...}: let
  nixAliases = {
    nixup = "darwin-rebuild switch --flake .";
    nixbuild = "darwin-rebuild build --flake .";
    nixcheck = "darwin-rebuild check --flake .";
  };
in {
  programs = {
    fish.shellAliases = lib.mkAfter nixAliases;
    zsh.shellAliases = lib.mkAfter nixAliases;
    bash.shellAliases = lib.mkAfter nixAliases;

    # Darwin-specific Fish shell initialization
    # OPTIMIZED: Lazy loading and combined operations for faster startup
    fish.shellInit = lib.mkAfter ''
      # PERFORMANCE: Combined path setup (single operation)
      if type -q fish_add_path
          fish_add_path --prepend --global \
            ~/.nix-profile/bin \
            /run/current-system/sw/bin \
            /etc/profiles/per-user/$USER/bin \
            /usr/local/bin \
            ~/.orbstack/bin
      end

      # Homebrew integration (Darwin-specific) - quick check
      test -f /opt/homebrew/bin/brew && eval (/opt/homebrew/bin/brew shellenv)

      # PERFORMANCE: Lazy-load completions on first tab press
      # Instead of loading all completions at startup, define a function that loads them on demand
      function __load_completions --on-event fish_postexec
          functions --erase __load_completions
          if command -v carapace >/dev/null 2>&1
              carapace _carapace fish | source
          end
      end

      # PROMPT: Starship prompt (fast - cached)
      command -v starship >/dev/null 2>&1 && starship init fish | source

      # PERFORMANCE: Optimized completions path
      set -g fish_complete_path /usr/local/share/fish/completions $fish_complete_path
    '';

    # Darwin-specific Zsh shell initialization
    zsh.initContent = lib.mkAfter ''
      # Homebrew integration (Darwin-specific)
      if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      # Nix profile PATH (Darwin-specific)
      export PATH="$HOME/.nix-profile/bin:$PATH"

      # OrbStack and local binaries (kubectl, docker, etc.)
      export PATH="/usr/local/bin:$PATH"
      export PATH="$HOME/.orbstack/bin:$PATH"

      # COMPLETIONS: Universal completion engine (1000+ commands)
      if command -v carapace >/dev/null 2>&1; then
        source <(carapace _carapace zsh)
      fi
    '';

    # Darwin-specific Bash shell initialization (FIX: Added for parity)
    bash.initExtra = lib.mkAfter ''
      # Homebrew integration (Darwin-specific)
      if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      # Nix profile PATH (Darwin-specific)
      export PATH="$HOME/.nix-profile/bin:$PATH"

      # OrbStack and local binaries (kubectl, docker, etc.)
      export PATH="/usr/local/bin:$PATH"
      export PATH="$HOME/.orbstack/bin:$PATH"

      # COMPLETIONS: Universal completion engine (1000+ commands)
      if command -v carapace >/dev/null 2>&1; then
        source <(carapace _carapace bash)
      fi
    '';
  };
}
