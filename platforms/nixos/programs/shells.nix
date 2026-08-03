# NixOS shell configurations with platform-specific overrides
{ lib, ... }:
let
  nixAliases = {
    nixup = "sudo nixos-rebuild switch --flake .";
    nixbuild = "sudo nixos-rebuild build --flake .";
    nixcheck = "sudo nixos-rebuild test --flake .";
  };
in
{
  programs = {
    fish.shellAliases = lib.mkAfter nixAliases;
    zsh.shellAliases = lib.mkAfter nixAliases;
    bash.shellAliases = lib.mkAfter nixAliases;

    # NixOS-specific Fish shell initialization
    fish.shellInit = lib.mkAfter ''
      # Nix path setup (NixOS-specific)
      # Note: /run/current-system/sw/bin and wrappers are already in PATH from /etc/profile
      # with correct order (wrappers first for setuid programs like sudo)
      # DO NOT use fish_add_path --prepend here - it breaks sudo and other setuid programs

      # NixOS-specific completions
      if test -d /etc/profiles/per-user/$USER/share/nixos/completions
          set -g fish_complete_path /etc/profiles/per-user/$USER/share/nixos/completions $fish_complete_path
      end

      # COMPLETIONS: Universal completion engine — cached to avoid
      # re-generating ~7ms of fish init on every startup.
      if command -v carapace >/dev/null 2>&1
          set -l cache_dir "$XDG_CACHE_HOME/fish-init"
          test -d $cache_dir; or mkdir -p $cache_dir
          set -l cara_ver (carapace --version 2>/dev/null | string match -r '[\d.]+$')
          set -l cara_cache "$cache_dir/carapace-$cara_ver.fish"
          if test -f $cara_cache
              source $cara_cache
          else
              carapace _carapace fish >$cara_cache
              source $cara_cache
          end
      end

      # Additional Fish-specific optimizations
      set -g fish_autosuggestion_enabled 1
    '';

    # NixOS-specific Zsh shell initialization
    zsh.initContent = lib.mkAfter ''
      # NixOS-specific completions
      if [ -d /etc/profiles/per-user/$USER/share/nixos/completions ]; then
        fpath+=/etc/profiles/per-user/$USER/share/nixos/completions
      fi

      # COMPLETIONS: Universal completion engine (1000+ commands)
      if command -v carapace >/dev/null 2>&1; then
        source <(carapace _carapace zsh)
      fi
    '';

    # NixOS-specific Bash shell initialization
    bash.initExtra = lib.mkAfter ''
      # NixOS-specific completions
      if [ -d /etc/profiles/per-user/$USER/share/nixos/completions ]; then
        export BASH_COMPLETION_USER_DIR="/etc/profiles/per-user/$USER/share/nixos/completions:$BASH_COMPLETION_USER_DIR"
      fi

      # COMPLETIONS: Universal completion engine (1000+ commands)
      if command -v carapace >/dev/null 2>&1; then
        source <(carapace _carapace bash)
      fi
    '';
  };
}
