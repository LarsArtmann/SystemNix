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

  # Destructive-command guard (2026-09-12 incident): all six local btrbk
  # snapshots were glob-deleted by `sudo btrfs subvolume delete
  # /mnt/btrfs-root/.snapshots/@.20260*` when the operator meant `du`.
  # Sudo is passwordless here, and btrfs subvolume delete has no confirmation
  # or dry-run. Fish expands globs BEFORE a function receives its arguments,
  # so this guard sees every concrete path that is about to die and demands a
  # typed "delete" confirmation. Interactive sessions only (this rides
  # interactiveShellInit) — scripts, bash, and non-interactive fish are
  # untouched and use the real binaries.
  btrfsGuardHook = ''
    # ── Destructive btrfs/snapshot guard (2026-09-12 incident) ───────────
    function __systemnix_confirm_destructive --description "Print targets and require typing 'delete'"
        set -l what $argv[1]
        set -l paths $argv[2..-1]
        echo (set_color brred)"⚠ $what: "(count $paths)" item(s) will be DELETED:"(set_color normal)
        for p in $paths
            echo "  "(set_color red)$p(set_color normal)
        end
        echo "If you meant a READ-ONLY command (du / show / list): answer anything but 'delete'."
        read -l -P 'type "delete" to proceed > ' confirm
        if test "$confirm" = delete
            return 0
        end
        echo "aborted — nothing was deleted"
        return 1
    end

    # Prints the target paths iff argv matches `btrfs <subvolume-prefix>
    # <delete-prefix> <paths…>` (btrfs-progs accepts unique-prefix
    # abbreviations like `sub del`, so match prefixes, not exact words).
    function __systemnix_btrfs_delete_targets --description "Extract subvolume-delete targets (args arrive POST glob-expansion)"
        set -l n (count $argv)
        set -l i 1
        while test $i -le $n; and not test "$argv[$i]" = btrfs
            set i (math $i + 1)
        end
        if test $i -gt $n
            return 0
        end
        set i (math $i + 1)
        if test $i -le $n; and string match -qr -- '^(su|sub|subv|subvo|subvol|subvolu|subvolum|subvolume)$' "$argv[$i]"
            set i (math $i + 1)
            if test $i -le $n; and string match -qr -- '^(d|de|del|dele|delet|delete)$' "$argv[$i]"
                if test $i -lt $n
                    for j in (seq (math $i + 1) $n)
                        echo $argv[$j]
                    end
                end
            end
        end
    end

    function __systemnix_guard_btrfs_delete --description "Confirm destructive btrfs subvolume deletes"
        set -l paths (__systemnix_btrfs_delete_targets $argv)
        if set -q paths[1]
            __systemnix_confirm_destructive "btrfs subvolume delete" $paths
            or return 1
        end
        return 0
    end

    function __systemnix_guard_snapshot_paths --description "Confirm rm/mv/trash targeting .snapshots or .rescue"
        set -l cmd $argv[1]
        set -l targets
        for t in $argv[2..-1]
            string match -q -- '-*' $t; and continue
            string match -qr -- '(^|/)\.snapshots(/|$)|(^|/)\.rescue(/|$)' $t; and set -a targets $t
        end
        if set -q targets[1]
            __systemnix_confirm_destructive "$cmd on snapshot dirs" $targets
            or return 1
        end
        return 0
    end

    function sudo --description "sudo with destructive-command guard (2026-09-12 snapshot glob-delete incident)"
        set -l argv_count (count $argv)
        set -l i 1
        # Skip sudo's own option flags to find the real command. Value-flags
        # (-u/-g/-p/-C/-r/-t) skip their argument too.
        while test $i -le $argv_count
            switch $argv[$i]
                case '-u' '-g' '-p' '-C' '-r' '-t'
                    set i (math $i + 2)
                case '-*'
                    set i (math $i + 1)
                case '*'
                    break
            end
        end
        if test $i -le $argv_count
            set -l cmd $argv[$i]
            set -l rest
            if test $i -lt $argv_count
                set rest $argv[(math $i + 1)..-1]
            end
            switch $cmd
                case btrfs
                    __systemnix_guard_btrfs_delete $cmd $rest; or return 1
                case rm mv trash
                    __systemnix_guard_snapshot_paths $cmd $rest; or return 1
            end
        end
        command sudo $argv
    end

    function btrfs --description "btrfs with subvolume-delete confirmation (2026-09-12 incident)"
        __systemnix_guard_btrfs_delete $argv
        or return 1
        command btrfs $argv
    end
    # ── End Destructive btrfs/snapshot guard ─────────────────────────────
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
    interactiveShellInit =
      direnvCacheHook
      + initCacheHook
      + btrfsGuardHook
      + ''
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
