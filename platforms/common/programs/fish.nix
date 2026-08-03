# Fish shell configuration
{ pkgs, ... }:
let
  commonAliases = (import ./shell-aliases.nix { }).commonShellAliases;

  # Build-time cache keys from package names. Zero runtime cost — interpolated
  # as literal strings. Invalidated automatically when the package version changes.
  fzfKey = pkgs.fzf.name; # e.g. "fzf-0.74.2"
  starshipKey = pkgs.starship.name; # e.g. "starship-1.26.0"

  # Cached init blocks for fzf and starship. HM's enableFishIntegration is
  # disabled for both — these replace the per-startup `fzf --fish | source`
  # and `starship init fish | source` subprocess spawns with a cached file
  # sourced from ~/.cache/fish-init/. Saves ~3-5ms per startup.
  initCacheHook = ''
    # ── Init Caching (fzf + starship) ────────────────────────────────────
    set -l cache_dir "$XDG_CACHE_HOME/fish-init"
    test -d $cache_dir; or mkdir -p $cache_dir

    # FZF: keybindings + completions (cached by package version)
    set -l fzf_cache "$cache_dir/fzf-${fzfKey}.fish"
    if test -f "$fzf_cache"
        source "$fzf_cache"
    else
        ${pkgs.fzf}/bin/fzf --fish >"$fzf_cache"
        source "$fzf_cache"
    end

    # Starship: prompt integration (cached by package version)
    if test "$TERM" != dumb
        set -l star_cache "$cache_dir/starship-${starshipKey}.fish"
        if test -f "$star_cache"
            source "$star_cache"
        else
            ${pkgs.starship}/bin/starship init fish >"$star_cache"
            source "$star_cache"
        end
    end
    # ── End Init Caching ─────────────────────────────────────────────────
  '';

  # Direnv caching hook: replaces HM's stock direnv fish integration.
  # Stock direnv spawns a subprocess on every prompt (~43ms). This version
  # checks watched-file mtimes natively in fish (instant) and only calls
  # direnv when something actually changed.
  #
  # Must be defined BEFORE HM's `if not functions -q __direnv_export_eval`
  # check — interactiveShellInit runs before HM module integrations in the
  # generated config.fish, so HM sees the function exists and skips its hook.
  #
  # Sentinel includes $fish_pid: each fish session gets its own sentinel.
  # Without this, two sessions in the same directory share a sentinel —
  # session A processes a file change and touches it, hiding the change
  # from session B (B sees nothing newer than the sentinel).
  direnvCacheHook = ''
    # ── Direnv Caching Hook ──────────────────────────────────────────────
    set -g __direnv_cache_sentinel "/tmp/.direnv-cache-$USER-$fish_pid"

    function __direnv_eval_inner --description "Run direnv and update cache state"
        ${pkgs.direnv}/bin/direnv export fish | source
        set -g __direnv_cache_pwd "$PWD"
        echo >$__direnv_cache_sentinel
    end

    function __direnv_export_eval --on-event fish_prompt --description "Direnv hook (cached)"
        set -l need_eval 0

        if not set -q __direnv_cache_pwd; or not test -f "$__direnv_cache_sentinel"
            set need_eval 1
        else if test "$__direnv_cache_pwd" != "$PWD"
            set need_eval 1
        else
            for f in .envrc flake.nix flake.lock shell.nix default.nix .env
                if test -f "$f" -a "$f" -nt "$__direnv_cache_sentinel"
                    set need_eval 1
                    break
                end
            end
        end

        test $need_eval -eq 1; and __direnv_eval_inner

        if test "$direnv_fish_mode" != "disable_arrow"
            function __direnv_cd_hook --on-variable PWD
                if test "$direnv_fish_mode" = "eval_after_arrow"
                    set -g __direnv_export_again 0
                else
                    __direnv_eval_inner
                end
            end
        end
    end

    function __direnv_export_eval_2 --on-event fish_preexec
        if set -q __direnv_export_again
            set -e __direnv_export_again
            __direnv_eval_inner
            echo
        end
        functions --erase __direnv_cd_hook
    end
    # ── End Direnv Caching Hook ──────────────────────────────────────────
  '';
in
{
  # Common Fish shell configuration
  programs.fish = {
    enable = true;

    # Use shared aliases (no duplication!)
    shellAliases = commonAliases;

    # Common Fish shell initialization
    interactiveShellInit = direnvCacheHook + initCacheHook + ''
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
