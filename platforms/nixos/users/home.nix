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
      # pnpm 11 ignores npm_config_* env vars AND .npmrc for store-dir, so the
      # store is redirected via symlink at its default location instead —
      # mechanism-independent, survives pnpm config-scheme changes.
      ".local/share/pnpm/store".source = config.lib.file.mkOutOfStoreSymlink "/mnt/buildcache/pnpm-store";
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

  # Qt settings for consistency with GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk2";
    style = {
      name = "gtk2";
      package = pkgs.qt6.qtbase;
    };
  };

  # Dunst disabled — DankMaterialShell provides its own notification server
  services.dunst.enable = lib.mkForce false;
}
