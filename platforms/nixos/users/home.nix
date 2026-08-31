{
  pkgs,
  lib,
  config,
  nix-ssh-config,
  colorScheme,
  ...
}:
let
  theme = import ../../common/theme.nix;
  colors = colorScheme.palette;
  inherit (import ../../../lib/default.nix lib) wrapWithMemoryLimit;

  # `open` — macOS-style file/URL opener that works from ANY context,
  # including SSH sessions that lack the graphical environment.
  # SSH shells have no WAYLAND_DISPLAY/DBus session env, so raw xdg-open
  # either fails outright ("no method available") or would launch apps
  # detached from the niri session. This wrapper rebuilds the session env
  # from the running compositor's sockets, validates a MIME handler exists
  # (one actionable error line instead of xdg-open's browser-fallback
  # waterfall), then detaches so the app survives SSH logout.
  openCommand = pkgs.writeShellApplication {
    name = "open";
    runtimeInputs = with pkgs; [
      coreutils # id, realpath, basename
      file # xdg-mime query filetype shells out to `file`
      util-linux # setsid
      xdg-utils # xdg-open + xdg-mime
    ];
    text = ''
      # Rebuild the graphical-session environment when missing (SSH).
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        uid="$(id -u)"
        export XDG_RUNTIME_DIR="/run/user/$uid"
      fi

      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      fi

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        # niri's IPC socket is named niri.<wayland-display>.<pid>.sock — the
        # display name is recoverable even when no session env is inherited.
        for socket in "$XDG_RUNTIME_DIR"/niri.*.sock; do
          if [ -e "$socket" ]; then
            display="$(basename "$socket")"
            display="''${display#niri.}"
            WAYLAND_DISPLAY="''${display%%.*}"
            export WAYLAND_DISPLAY
            break
          fi
        done
      fi

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        # Fallback: any compositor's socket (sway backup WM, …)
        for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
          case "$socket" in
            *.lock) continue ;;
          esac
          if [ -e "$socket" ]; then
            WAYLAND_DISPLAY="$(basename "$socket")"
            export WAYLAND_DISPLAY
            break
          fi
        done
      fi

      if [ -z "''${XDG_CURRENT_DESKTOP:-}" ]; then
        export XDG_CURRENT_DESKTOP=niri
      fi

      if [ -z "''${WAYLAND_DISPLAY:-}" ] || [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        echo "open: no running graphical session found for user $(id -un)." >&2
        echo "  This command opens files on the niri desktop, but no Wayland" >&2
        echo "  session socket exists. Log into the niri desktop first, then retry." >&2
        echo "  Searched: \$WAYLAND_DISPLAY, $XDG_RUNTIME_DIR/niri.*.sock, $XDG_RUNTIME_DIR/wayland-*" >&2
        exit 1
      fi

      # Validate + absolutize BEFORE launching: a missing MIME association
      # should produce one actionable line, and xdg-open handles absolute
      # paths more reliably than relative ones.
      args=()
      for arg in "$@"; do
        if [ -e "$arg" ]; then
          arg="$(realpath -- "$arg")"
          mimetype="$(xdg-mime query filetype "$arg")"
          if [ -z "$(xdg-mime query default "$mimetype")" ]; then
            echo "open: no default application registered for '$mimetype' ($arg)." >&2
            echo "  Add it to xdg.mimeApps.defaultApplications in platforms/nixos/users/home.nix." >&2
            exit 1
          fi
        fi
        args+=("$arg")
      done

      # Detach (macOS `open` semantics): fire-and-forget, survives SSH logout.
      setsid --fork xdg-open "''${args[@]}" </dev/null >/dev/null 2>&1
    '';
  };
in
{
  imports = [
    ../../common/home-base.nix
    ../programs/shells.nix # NixOS shell configuration
    nix-ssh-config.homeManagerModules.ssh
    ../programs/rofi.nix # Rofi launcher — Sway backup WM only (niri uses DMS spotlight)
    # wlogout removed — DankMaterialShell provides power menu
    # swaylock module removed — DMS provides lock screen via dms ipc lock lock
    # swaylock-effects kept as package fallback in dms-lock wrapper
    ../../common/programs/zellij.nix # Zellij terminal multiplexer
    ../../common/programs/yazi.nix # Terminal file manager with Catppuccin theme
    ../../common/programs/zed.nix # Zed editor — shared cross-platform config
    ../desktop/niri-wrapped.nix # Niri scrollable-tiling compositor via niri-flake HM module
    # waybar.nix retired — DankMaterialShell replaces it entirely
    ../desktop/quickshell.nix # Quickshell desktop shell via DankMaterialShell
  ];

  # Quickshell desktop shell — replaces Waybar, Dunst, Wlogout, polkit_gnome
  programs.systemnix-quickshell.enable = true;

  # SSH hosts defined in common/programs/ssh-config.nix

  # D-Bus/GSettings dark mode — read by xdg-desktop-portal-gtk Settings interface,
  # which Chromium-based browsers (Helium) query for UI chrome theming on Wayland compositors.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # Programs configuration
  programs = {
    # Ghostty terminal configuration (primary)
    ghostty = {
      enable = true;
      settings = {
        font-family = theme.font.mono;
        font-size = 16;
        theme = "Catppuccin Mocha";
        background-opacity = 0.85;
        confirm-close-surface = false;
        window-decoration = false;
        copy-on-select = false;
        mouse-hide-while-typing = true;
        clipboard-read = "allow";
        clipboard-write = "allow";
      };
    };

    # Kitty terminal configuration (backup)
    kitty = {
      enable = true;
      package = pkgs.kitty.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          substituteInPlace $out/lib/kitty/kitty/constants.py \
            --replace "kitty_run_data.get('bundle_exe_dir')" "None  # Nix: use PATH lookup for GC resilience"
        '';
      });
      font = {
        name = theme.font.mono;
        size = 16;
      };
      themeFile = "Catppuccin-Mocha";
      settings = {
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        background_opacity = "0.85";
        confirm_os_window_close = 0;
        update_check_interval = 0;
        enable_audio_bell = false;
        visual_bell_duration = "0.2";
        visual_bell_color = "#${colors.base0D}";
        window_alert_on_bell = true;
      };
    };

    # Foot terminal configuration (lightweight Wayland alternative)
    foot = {
      enable = true;
      settings = {
        main = {
          font = "${theme.font.mono}:size=12";
          dpi-aware = "yes";
          pad = "12x12";
          shell = "fish";
        };
        cursor = {
          style = "block";
          blink = "yes";
        };
        mouse = {
          hide-when-typing = "yes";
        };
        colors = {
          alpha = "0.95";
          background = "${colors.base00}";
          foreground = "${colors.base05}";
          # Catppuccin Mocha colors
          regular0 = "${colors.base03}"; # black
          regular1 = "${colors.base08}"; # red
          regular2 = "${colors.base0B}"; # green
          regular3 = "${colors.base0A}"; # yellow
          regular4 = "${colors.base0D}"; # blue
          regular5 = "${colors.base0F}"; # magenta
          regular6 = "${colors.base0C}"; # cyan
          regular7 = "${colors.subtext1}"; # white
          bright0 = "${colors.base04}"; # bright black
          bright1 = "${colors.base08}"; # bright red
          bright2 = "${colors.base0B}"; # bright green
          bright3 = "${colors.base0A}"; # bright yellow
          bright4 = "${colors.base0D}"; # bright blue
          bright5 = "${colors.base0F}"; # bright magenta
          bright6 = "${colors.base0C}"; # bright cyan
          bright7 = "${colors.subtext0}"; # bright white
        };
      };
    };
  };

  # Go/Rust/lint cache self-healing for a dead or absent /mnt/buildcache.
  # Fish conf.d (runs BEFORE config.fish, in login AND interactive shells).
  # 2026-08-24: the original hand-written version probed writability with a
  # BARE `mkdir -p $val` — on the dead buildcache automount every probe
  # blocked for the full 10s x-systemd.device-timeout, and SDDM's login
  # chain (wayland-session -> fish --login, which inherits GOCACHE et al.
  # from /etc/profile.d/hm-session-vars.sh) spent ~40s in uninterruptible
  # sleep before niri ever started. display-watchdog restarted the display
  # manager at ~20s, bouncing every login back to SDDM (black-screen loop).
  # Probes must be SIGKILL-bounded: SIGTERM/coreutils default stays pending
  # until the kernel device-timeout releases the syscall; only SIGKILL
  # interrupts the autofs wait (TASK_KILLABLE) at the 1s bound.
  xdg.configFile."fish/conf.d/00-go-cache-guard.fish".text = ''
    # Probe each DISTINCT parent directory once, not each variable: on this
    # host eight cache vars point into /mnt/buildcache/* — per-var SIGKILL
    # probes cost ~1s each against a dead automount (9 vars ≈ 8s login, the
    # exact SDDM black-screen cost class). A dead dir is remembered and the
    # remaining vars under it redirect without re-probing.
    set -g __dead_cache_dirs
    function __cache_dir_alive -a dir
        if contains -- $dir $__dead_cache_dirs
            return 1
        end
        if timeout --signal=KILL 1 mkdir -p $dir 2>/dev/null; and timeout --signal=KILL 1 touch $dir/.cache-write-probe 2>/dev/null
            rm -f $dir/.cache-write-probe
            return 0
        end
        set -a __dead_cache_dirs $dir
        return 1
    end

    function __go_cache_redirect -a var fallback
        if not set -q $var
            return
        end
        set -l val $$var
        if __cache_dir_alive (dirname $val)
            return
        end
        echo "⚠ $var=$val is unwritable or unreachable (dead mount?) — redirecting to $fallback"
        set -gx $var $fallback
        timeout --signal=KILL 1 mkdir -p $fallback
    end

    # 2026-08-27: stale sessions carry UNEXPANDED '$HOME/...' env literals
    # (exported verbatim from nix print-dev-env attrs — Nix does not expand
    # $HOME in plain strings; the CV devshell GOPATH attr was the offender,
    # fixed at source). A literal's dirname is a RELATIVE '$HOME' path, so
    # the liveness probe above would mkdir it INTO the CWD and call it
    # alive — Go then writes './$HOME/.go/pkg/sumdb' junk next to every
    # module. Expand before probing.
    function __expand_literal_home -a var
        if set -q $var; and string match -q '*$HOME*' -- $$var
            echo "⚠ $var=$$var is an unexpanded literal — expanding"
            set -gx $var (string replace -a '$HOME' -- $HOME $$var)
        end
    end
    __expand_literal_home TMPDIR
    __expand_literal_home GOCACHE
    __expand_literal_home GOMODCACHE
    __expand_literal_home GOLANGCI_LINT_CACHE
    __expand_literal_home CARGO_HOME
    __expand_literal_home PIP_CACHE_DIR
    __expand_literal_home SCCACHE_DIR
    __expand_literal_home npm_config_cache
    __expand_literal_home PLAYWRIGHT_BROWSERS_PATH
    __expand_literal_home GOPATH

    __go_cache_redirect TMPDIR $HOME/tmp
    __go_cache_redirect GOCACHE $HOME/tmp/go-cache
    __go_cache_redirect GOMODCACHE $HOME/tmp/go-mod
    __go_cache_redirect GOLANGCI_LINT_CACHE $HOME/tmp/go-lint
    # 2026-08-24 follow-up: the login chain inherits EVERY dead-mount cache
    # var from hm-session-vars.sh, not just the Go ones — an unprobed var
    # still blocks the full device-timeout per lookup during login
    # (docs/status/2026-08-24_08-00_sddm §b.1).
    __go_cache_redirect CARGO_HOME $HOME/tmp/cargo
    __go_cache_redirect PIP_CACHE_DIR $HOME/tmp/pip
    __go_cache_redirect SCCACHE_DIR $HOME/tmp/sccache
    __go_cache_redirect npm_config_cache $HOME/tmp/npm
    __go_cache_redirect PLAYWRIGHT_BROWSERS_PATH $HOME/tmp/playwright

    if test "$GOTOOLCHAIN" = local
        echo "⚠ GOTOOLCHAIN=local blocks go.work ≥1.26.6 projects — switching to auto"
        set -gx GOTOOLCHAIN auto
    end
  '';

  home = {
    enableNixpkgsReleaseCheck = false;

    # Build caches moved to the USB SSD (/mnt/buildcache) — keeps ephemeral
    # build churn off the QLC NVMe (SLC cache exhaustion) and out of tmpfs
    # (RAM pressure). Managed by modules/nixos/services/buildcache.nix.
    # GOCACHE is content-hash verified by go itself; corruption from
    # data=writeback + no PLP just triggers a rebuild.
    # Note: gopls stays on NVMe (~/.cache/gopls) — LSP is latency-sensitive;
    # ~/.cache/nix stays on NVMe — touched on every nix eval.
    file = {
      ".cache/goimports".source = config.lib.file.mkOutOfStoreSymlink "/mnt/buildcache/goimports";
      ".cache/go".source = config.lib.file.mkOutOfStoreSymlink "/mnt/buildcache/go";
      # Belt-and-braces for GOCACHE: processes WITHOUT the session env
      # (systemd user services, dbus-activated apps, emergency shells) fall
      # back to Go's default ~/.cache/go-build — a real dir there silently
      # moves build churn back onto the NVMe (2026-08-16: 5.4 GB accumulated
      # in the USB-outage window). Kept in sync with the reap list in
      # modules/nixos/services/buildcache.nix (buildcache-usb-recovery).
      ".cache/go-build".source = config.lib.file.mkOutOfStoreSymlink "/mnt/buildcache/go-build";
      # pnpm 11 ignores npm_config_* env vars AND .npmrc for store-dir, so the
      # store is redirected via symlink at its default location instead —
      # mechanism-independent, survives pnpm config-scheme changes.
      ".local/share/pnpm/store".source = config.lib.file.mkOutOfStoreSymlink "/mnt/buildcache/pnpm-store";

      # golangci-lint-lsp wrapper — pins the lint cache to /mnt/buildcache but
      # falls back to ~/tmp/go-lint when the mount is dead (the fish
      # 00-go-cache-guard logic, SIGKILL-bounded so a wedged automount can
      # never hang the LSP launch). Replaces the stray hand-copied wrapper
      # that pinned $HOME/tmp/golangci-lint-cache UNCONDITIONALLY and grew
      # ~900M of lint cache on the QLC NVMe even while the buildcache was
      # healthy. Referenced by the HM crushrc (golangci_lint_ls LSP).
      ".local/bin/golangci-lint-lsp-wrapper".text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        pick_cache() {
          local candidate="''${GOLANGCI_LINT_CACHE:-/mnt/buildcache/golangci-lint}"
          if timeout --signal=KILL 1 mkdir -p "$candidate" 2>/dev/null \
            && timeout --signal=KILL 1 touch "$candidate/.cache-write-probe" 2>/dev/null; then
            rm -f "$candidate/.cache-write-probe"
            printf '%s' "$candidate"
            return 0
          fi
          candidate="$HOME/tmp/go-lint"
          mkdir -p "$candidate"
          printf '%s' "$candidate"
        }

        CACHE_ROOT="$(pick_cache)"
        export GOLANGCI_LINT_CACHE="$CACHE_ROOT"
        export GOLANGCI_LINT_ANALYSIS_CACHE="''${CACHE_ROOT}-analysis"
        mkdir -p "$GOLANGCI_LINT_ANALYSIS_CACHE"

        exec golangci-lint-langserver "$@"
      '';
      ".local/bin/golangci-lint-lsp-wrapper".executable = true;
    };
    # Jan AI: symlink data folder to centralized /data/ai/models/jan
    activation.jan-data-link = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      JAN_DATA="$HOME/.config/Jan/data"
      JAN_TARGET="/data/ai/models/jan"
      if [ -d "$JAN_TARGET" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$JAN_DATA")"
        if [ ! -L "$JAN_DATA" ]; then
          $DRY_RUN_CMD rm -rf "$JAN_DATA"
        fi
        $DRY_RUN_CMD ln -sfn "$JAN_TARGET" "$JAN_DATA"
      fi
    '';

    # NixOS-specific session variables
    sessionVariables = {
      # Build caches on the USB SSD — run nix run .#migrate-buildcache BEFORE
      # the first deploy so the target dirs exist and the symlinked sources
      # (~/.cache/goimports, ~/.cache/go) have been moved aside.
      GOCACHE = "/mnt/buildcache/go-build";
      GOMODCACHE = "/mnt/buildcache/go-mod";
      GOLANGCI_LINT_CACHE = "/mnt/buildcache/golangci-lint";
      PIP_CACHE_DIR = "/mnt/buildcache/pip";
      PLAYWRIGHT_BROWSERS_PATH = "/mnt/buildcache/playwright";
      # npm reads npm_config_* env vars as .npmrc settings. pnpm 11 does NOT
      # (see the pnpm store symlink above) — its metadata cache only.
      npm_config_cache = "/mnt/buildcache/npm";

      # ── Cache-key unification (2026-08-15; docs/planning/2026-08-15_21-23_SMART-BUILDCACHE-OVERHAUL.md) ──
      # The build cache grew 2-3x because identical packages were compiled
      # under multiple cache keys. Both vars below collapse it to ONE key.
      #
      # GOTOOLCHAIN=local: the running (nix-pinned) go is the ONLY toolchain.
      # The default "auto" silently downloads newer toolchains demanded by
      # go.mod (go-codec's "go 1.26.6" pulled a 240 MiB toolchain into go-mod
      # and forked the cache: 15k duplicate entries in one day). With "local",
      # version mismatches fail LOUDLY — fix the go.mod or bump nixpkgs
      # deliberately. Known loud repo today: go-codec (user is mid-upgrade).
      GOTOOLCHAIN = "local";
      # GOEXPERIMENT=jsonv2: gates only the encoding/json/v2 package's
      # availability — v1 output is byte-identical (70 repos already compile
      # their deps under this flag; verified on go1.26.5: WITHOUT the flag,
      # importing json/v2 is a hard build error). Machine-wide setting gives
      # all 162 repos one X: flag-set → one cache branch. Repos must still
      # carry the flag THEMSELVES for other contributors (17 satellites are
      # broken — TODO_LIST sweep item). Drop this var when Go graduates the
      # experiment out of GOEXPERIMENT (unknown experiment = loud build error).
      GOEXPERIMENT = "jsonv2";

      # Rust: sccache = content-addressed GLOBAL compile cache (cross-project
      # hits — project B's serde is a HIT, rustc never runs), hard LRU cap
      # cargo lacks, ends per-project target/ duplication growth. Nix builds
      # unaffected (sandboxed, no env). Dir creation + GC: buildcache module.
      RUSTC_WRAPPER = "sccache";
      SCCACHE_DIR = "/mnt/buildcache/sccache";
      SCCACHE_CACHE_SIZE = "32G";
      # CARGO_HOME since 2026-08-17: was the @cargo NVMe subvolume (snapshot-
      # excluded via automount). With the subvolume retired, the registry/git
      # churn moves here — same off-NVMe doctrine as GOCACHE/GOMODCACHE.
      # Seeded at migration from ~/.cargo (registry, git, advisory dbs, bin,
      # credentials.toml). ~/.cargo remains as a plain dir only for tools
      # that hardcode it; cargo itself no longer touches it.
      CARGO_HOME = "/mnt/buildcache/cargo";

      # Wayland specific
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      NIXOS_OZONE_WL = "1";

      # Dark mode preference - respected by many apps and browsers
      GTK_THEME = "${theme.gtkThemeName}:dark";
      QT_STYLE_OVERRIDE = lib.mkForce "kvantum";

      # Cursor theme for Wayland compositors
      # Cursor size is determined by the cursor theme's built-in sizes
      # Bibata has XL size (96px) built-in
      XCURSOR_THEME = theme.cursorTheme;

      # Fallback for X11 applications (rarely used)
      XCURSOR_SIZE = toString theme.cursorSize;
    };

    # NixOS-specific packages
    packages = with pkgs; [
      # GUI Tools
      pwvucontrol # Native PipeWire volume control (GTK, Rust)
      mpv # Media player — default for audio MIME types (see mimeApps below)
      signal-desktop # Secure messaging application

      # AI Tools
      jan # Local AI assistant (data → /data/ai/models/jan via activation)

      # XL Cursor theme for TV viewing (2 meters away)
      bibata-cursors

      # Development tools
      cargo # Rust package manager
      rustc # Rust compiler
      rustfmt # Rust code formatter
      clippy # Rust linter
      rust-analyzer # Rust language server
      sccache # Rust/C compile cache — global, content-addressed, 32G LRU (see sessionVariables)
      gitui # Terminal UI for git

      # Memory-limited + I/O-throttled dev commands — wrap go/cargo/pnpm with
      # cgroup MemoryMax (prevents OOM on Strix Halo under GPUActive pressure)
      # and BFQ I/O scheduling BE/7 + Nice=10 (prevents QLC NAND I/O storms
      # from starving the desktop — fixes Helium 3 FPS video drops during
      # build storms). Usage: go-test-memlimit ./..., cargo-build-memlimit --release
      (wrapWithMemoryLimit pkgs {
        name = "go-test";
        maxMemory = "4G";
        command = lib.getExe pkgs.go;
        extraArgs = [ "test" ];
      })
      (wrapWithMemoryLimit pkgs {
        name = "go-build";
        maxMemory = "4G";
        command = lib.getExe pkgs.go;
        extraArgs = [ "build" ];
      })
      (wrapWithMemoryLimit pkgs {
        name = "cargo-test";
        maxMemory = "8G";
        command = lib.getExe pkgs.cargo;
        extraArgs = [ "test" ];
      })
      (wrapWithMemoryLimit pkgs {
        name = "cargo-build";
        maxMemory = "8G";
        command = lib.getExe pkgs.cargo;
        extraArgs = [ "build" ];
      })
      (wrapWithMemoryLimit pkgs {
        name = "pnpm-test";
        maxMemory = "4G";
        command = lib.getExe pkgs.pnpm;
        extraArgs = [ "test" ];
      })

      # Cursor themes
      adwaita-icon-theme
      hicolor-icon-theme

      # GTK Theming
      catppuccin-gtk
      papirus-icon-theme
      libsForQt5.qt5ct
      qt6.qtbase

      # System Tools
      # Note: xdg-utils moved to base.nix for cross-platform consistency

      # Desktop packages
      # Note: ghostty managed by programs.ghostty above — don't add to packages
      # Note: kitty managed by programs.kitty above — don't add to packages
      # Note: cliphist CLI in base.nix (manual use only, service retired — DMS manages clipboard)
      libnotify
      swappy
      playerctl
      brightnessctl
      ddcutil
      wl-clipboard # Wayland clipboard utilities (wl-copy, wl-paste)
      gawk # Text processing

      # macOS-style opener that works locally AND over SSH
      # (defined in the let block above)
      openCommand
    ];
  };

  xdg.desktopEntries.helium = {
    name = "Helium";
    genericName = "Web Browser";
    exec = "env -u QT_STYLE_OVERRIDE helium %U";
    icon = "helium";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  # XDG configuration (Linux specific)
  xdg = {
    enable = true;

    # User directories
    userDirs = {
      enable = true;
      createDirectories = true;
      # Override to lowercase "projects" for consistency with all other custom paths
      extraConfig = {
        PROJECTS = "${config.home.homeDirectory}/projects";
      };
      # Explicitly disable session variables to silence Home Manager deprecation warning
      # (default changed from true to false in Home Manager 26.05)
      setSessionVariables = false;
    };

    # Application config files
    configFile = {
      # Dark mode preference for xdg-desktop-portal (respected by browsers and modern apps)
      "xdg-desktop-portal/config".text = ''
        [preferred]
        color-scheme=dark
      '';

      # Crush provider auth from sops — NEVER store keys in crush's auth store
      # (~/.local/share/crush/crush.json, machine-owned plaintext state that
      # agents can read; the 2026-08-18 leak class). crushrc api_key supports
      # $(command) expansion at load, so each key flows sops → /run/secrets →
      # process memory without ever touching a writable file. crushrc-declared
      # keys are never persisted back — synthetic has provably stayed out of
      # the auth store and session DB snapshots since 2026-08-18. Guarded:
      # absent secret or PLACEHOLDER value = provider skipped. hyper stays
      # store-owned on purpose (OAuth refresh state, self-rotating). NOTE: do
      # not track a real "crush/crushrc" in the ~/.config/crush dotfiles repo
      # — it collides with this HM symlink.
      "crush/crushrc".text = ''
        crush_key() {
          local f="/run/secrets/$2" k
          test -r "$f" || return 0
          k=$(cat "$f")
          case "$k" in "" | PLACEHOLDER*) return 0 ;; esac
          provider add "$1" --api-key "$k"
        }
        crush_key synthetic synthetic_api_key
        crush_key zai zai_api_key
        crush_key gemini gemini_api_key
        crush_key minimax minimax_api_key
        crush_key kimi-coding kimi_api_key

        # glm-5.3-flash exists ONLY here: charm's auto-updated zai catalog
        # does not list it, so deleting the old user crush.json dropped it
        # from the model list (live regression 2026-08-31, restored same
        # day). Pricing from the user's known-good def; effort tiers
        # normalized to z.ai's current xhigh scheme (catalog glm-5.3/5.2
        # already serve xhigh — the old hand-written "max" was stale
        # naming). model add has NO reasoning_levels flag (source:
        # shellconfig/model.go) — the picker tier list for flash falls back
        # to crush's default handling of default_reasoning_effort.
        model add zai/glm-5.3-flash --name "GLM-5.3-Flash" --context-window 1000000 --default-max-tokens 131072 --can-reason true --supports-images true --price-input 0.15 --price-output 0.5 --price-cache-hit 0.03 --reasoning-effort xhigh

        # Local llama.cpp (user starts llama-server ad hoc; nothing on
        # lib/ports.nix serves :8899). discover_models DEFAULTS TO TRUE —
        # crush queries /v1/models at session start, so whatever GGUF is
        # loaded shows up with zero hand-maintained entries (the old
        # crush.json carried a stale hardcoded model with invented pricing).
        # Server down = provider lists no models; connection refused is
        # instant, no startup cost.
        provider add llamacpp --type llamacpp --base-url "http://127.0.0.1:8899/v1"

        # Context files (moved from the user crush.json options.context_paths).
        option context-path $HOME/.config/crush/AGENTS.md
        option context-path AGENTS.md

        # LSP servers (moved from the user crush.json lsp section). Deliberately
        # NO env pins: gopls/oxlint inherit the session env, where
        # GOCACHE/GOMODCACHE/GOLANGCI_LINT_CACHE point at /mnt/buildcache (the
        # fish 00-go-cache-guard redirects to ~/tmp only while the mount is
        # dead). The old crush.json hardcoded $HOME/tmp/* pins that bypassed
        # the buildcache doctrine and stranded ~48G of Go caches on the QLC
        # NVMe (removed 2026-08-31). golangci_lint_ls goes through the
        # HM-managed wrapper, which re-pins the lint cache with the same
        # alive-check fallback for env-less launch paths.
        lsp add gopls --command gopls --timeout 60 --options '{"analyses":{"stdversion":false}}'
        lsp add oxlint --command oxlint --args --lsp --filetypes typescript --filetypes typescriptreact --filetypes javascript --filetypes javascriptreact --root-markers .oxlintrc.json --root-markers .oxlintrc.jsonc --root-markers oxlint.config.ts
        lsp add golangci_lint_ls --command "$HOME/.local/bin/golangci-lint-lsp-wrapper"

        # qmd — local RAG/hybrid search over markdown + code collections
        # (BM25 + vector embeddings + LLM rerank, fully on-device). Global CLI
        # from environment.systemPackages; stdio MCP server. GGUF models
        # (~2 GB) auto-download to ~/.cache/qmd on first semantic search.
        mcp add qmd --command qmd --args mcp
      '';

      # Niri session manager — declarative app mappings
      # Prevents duplicate spawns and maps niri app_ids to actual launch commands
      "niri-session-manager/config.toml".text = ''
        [single_instance_apps]
        apps = [
            "helium",
            "firefox",
            "Firefox",
            "signal",
            "Slack",
            "discord",
            "vesktop",
            "telegramdesktop",
            "Spotify",
            "spotify",
            "org.keepassxc.KeePassXC",
            # ghostty is gtk-single-instance: every surface shares one process.
            # Without this entry the session restore spawns ONE ghostty per SAVED
            # WINDOW — restored empty shells get re-saved → the window count only
            # grows across logins (2026-08-31: 152 empty terminals per login)
            "com.mitchellh.ghostty",
        ]

        [skip_apps]
        apps = [
            "Jan",
        ]

        [app_mappings]
        "signal" = ["signal-desktop"]
        "telegramdesktop" = ["telegram-desktop"]
        "org.keepassxc.KeePassXC" = ["keepassxc"]
        "com.mitchellh.ghostty" = ["ghostty"]

        [terminal_state]
        enabled = true
        terminal_app_ids = ["kitty", "foot", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "alacritty"]
        shell_names = ["fish", "bash", "zsh", "sh", "dash", "-fish", "-bash", "-zsh", "-sh", "sudo", "doas"]
        helper_names = ["kitten"]
        max_walk_depth = 20
      '';

      "swappy/config".text = ''
        [Default]
        save_dir=$HOME/Pictures/screenshots
        save_filename_format=screenshot_%Y%m%d_%H%M%S.png
        show_panel=false
        line_size=5
        text_size=20
        text_font=${theme.font.mono}
        paint_mode=arrow
        early_exit=true
      '';
    };

    # Default applications for MIME types
    mimeApps = {
      enable = true;
      defaultApplications = {
        # Web browsing
        "text/html" = [ "helium.desktop" ];
        "application/xhtml+xml" = [ "helium.desktop" ];
        "x-scheme-handler/http" = [ "helium.desktop" ];
        "x-scheme-handler/https" = [ "helium.desktop" ];

        # Terminal
        "x-scheme-handler/terminal" = [ "com.mitchellh.ghostty.desktop" ];
        "application/x-terminal-emulator" = [ "com.mitchellh.ghostty.desktop" ];

        # File manager
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];

        # Text / code files
        "text/plain" = [ "zed.desktop" ];
        "text/markdown" = [ "zed.desktop" ];
        "text/x-yaml" = [ "zed.desktop" ];
        "application/json" = [ "zed.desktop" ];
        "application/x-yaml" = [ "zed.desktop" ];

        # Images
        "image/avif" = [ "helium.desktop" ];
        "image/bmp" = [ "helium.desktop" ];
        "image/gif" = [ "helium.desktop" ];
        "image/heif" = [ "helium.desktop" ];
        "image/jpeg" = [ "helium.desktop" ];
        "image/png" = [ "helium.desktop" ];
        "image/svg+xml" = [ "helium.desktop" ];
        "image/tiff" = [ "helium.desktop" ];
        "image/webp" = [ "helium.desktop" ];
        "image/x-icon" = [ "helium.desktop" ];

        # Audio — mpv (browsers handle audio files poorly; mpv works via `open`
        # from SSH too)
        "audio/aac" = [ "mpv.desktop" ];
        "audio/flac" = [ "mpv.desktop" ];
        "audio/mpeg" = [ "mpv.desktop" ];
        "audio/mp4" = [ "mpv.desktop" ];
        "audio/ogg" = [ "mpv.desktop" ];
        "audio/opus" = [ "mpv.desktop" ];
        "audio/wav" = [ "mpv.desktop" ];
        "audio/webm" = [ "mpv.desktop" ];
        "audio/x-flac" = [ "mpv.desktop" ];
        "audio/x-matroska" = [ "mpv.desktop" ];
        "audio/x-wav" = [ "mpv.desktop" ];

        # Videos
        "video/mp4" = [ "helium.desktop" ];
        "video/ogg" = [ "helium.desktop" ];
        "video/quicktime" = [ "helium.desktop" ];
        "video/webm" = [ "helium.desktop" ];
        "video/x-matroska" = [ "helium.desktop" ];
        "video/x-msvideo" = [ "helium.desktop" ];
      };
    };
  };

  # GTK settings for Catppuccin Mocha theme
  gtk = {
    enable = true;
    gtk4.theme.name = theme.gtkThemeName;
    font = with theme.font; {
      inherit name size;
    };
    theme = {
      name = theme.gtkThemeName;
      package = pkgs.catppuccin-gtk.override {
        accents = [ theme.accent ];
        size = lib.strings.toLower theme.density;
        inherit (theme) variant;
      };
    };
    iconTheme = {
      name = theme.iconTheme;
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = theme.cursorTheme;
      package = pkgs.bibata-cursors;
      size = theme.cursorSize;
    };
    # Force dark mode preference for all GTK applications
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Qt settings for consistency with GTK.
  # NEVER use gtk2 here: the gtk2 Qt platform/theme plugins are Qt5-only —
  # on Qt6 every QQC2 app then aborts with `module "gtk2" is not installed`
  # (2026-08-18: niri-flake-polkit crash-looped 49x, auth dialogs dead; an
  # earlier user-sudo prompt storm surfaced it). "adwaita" platform theme
  # (qadwaitadecorations — the maintained successor of the archived
  # qgnomeplatform, same FedoraQt lineage) honors the GTK dark preference;
  # "fusion" is a built-in QQC2 style that always resolves and stays
  # look-neutral (Adwaita *style* would fight the Catppuccin Mocha palette).
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name = "fusion";
      package = pkgs.qt6.qtbase;
    };
  };

  # Dunst disabled — DankMaterialShell provides its own notification server
  services.dunst.enable = lib.mkForce false;
}
