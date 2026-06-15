{
  pkgs,
  lib,
  config,
  nix-ssh-config,
  colorScheme,
  ...
}: let
  theme = import ../../common/theme.nix;
  colors = colorScheme.palette;
in {
  imports = [
    ../../common/home-base.nix
    ../programs/shells.nix # NixOS shell configuration
    nix-ssh-config.homeManagerModules.ssh
    ../programs/rofi.nix # Rofi launcher with Catppuccin grid theme
    ../programs/wlogout.nix # Power menu with Catppuccin theme
    ../programs/swaylock.nix # Screen locker with blur + Catppuccin theme
    ../../common/programs/zellij.nix # Zellij terminal multiplexer
    ../../common/programs/yazi.nix # Terminal file manager with Catppuccin theme
    ../../common/programs/zed.nix # Zed editor — shared cross-platform config
    ../desktop/niri-wrapped.nix # Niri scrollable-tiling compositor via niri-flake HM module
    ../desktop/waybar.nix # Status bar for niri
  ];

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
        postInstall =
          (old.postInstall or "")
          + ''
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
    # Jan AI: symlink data folder to centralized /data/ai/models/jan
    activation.jan-data-link = lib.hm.dag.entryAfter ["writeBoundary"] ''
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
      gitui # Terminal UI for git

      # Cursor themes
      adwaita-icon-theme
      hicolor-icon-theme

      # GTK Theming
      catppuccin-gtk
      papirus-icon-theme
      libsForQt5.qt5ct
      qt6.qtbase

      # System Tools
      # Note: rofi moved to multi-wm.nix for system-wide availability
      # Note: xdg-utils moved to base.nix for cross-platform consistency

      # Desktop packages
      # Note: ghostty managed by programs.ghostty above — don't add to packages
      # Note: kitty managed by programs.kitty above — don't add to packages
      # Note: cliphist is installed via common/packages/base.nix (Linux-only)
      dunst
      libnotify
      wlogout
      grimblast
      swappy
      playerctl
      brightnessctl
      ddcutil
      wl-clipboard # Wayland clipboard utilities (wl-copy, wl-paste)
      wl-clip-persist # Keeps clipboard content after programs close
      rofi-calc
      rofi-emoji
      yazi # Terminal file manager (Rust-based, async, image previews)
      gawk # Text processing
    ];
  };

  xdg.desktopEntries.helium = {
    name = "Helium";
    genericName = "Web Browser";
    exec = "env -u QT_STYLE_OVERRIDE helium %U";
    icon = "helium";
    terminal = false;
    categories = ["Network" "WebBrowser"];
    mimeType = ["text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https"];
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
        "text/html" = ["helium.desktop"];
        "application/xhtml+xml" = ["helium.desktop"];
        "x-scheme-handler/http" = ["helium.desktop"];
        "x-scheme-handler/https" = ["helium.desktop"];

        # Terminal
        "x-scheme-handler/terminal" = ["com.mitchellh.ghostty.desktop"];
        "application/x-terminal-emulator" = ["com.mitchellh.ghostty.desktop"];

        # File manager
        "inode/directory" = ["org.gnome.Nautilus.desktop"];

        # Text / code files
        "text/plain" = ["zed.desktop"];
        "text/markdown" = ["zed.desktop"];
        "text/x-yaml" = ["zed.desktop"];
        "application/json" = ["zed.desktop"];
        "application/x-yaml" = ["zed.desktop"];

        # Images
        "image/avif" = ["helium.desktop"];
        "image/bmp" = ["helium.desktop"];
        "image/gif" = ["helium.desktop"];
        "image/heif" = ["helium.desktop"];
        "image/jpeg" = ["helium.desktop"];
        "image/png" = ["helium.desktop"];
        "image/svg+xml" = ["helium.desktop"];
        "image/tiff" = ["helium.desktop"];
        "image/webp" = ["helium.desktop"];
        "image/x-icon" = ["helium.desktop"];

        # Videos
        "video/mp4" = ["helium.desktop"];
        "video/ogg" = ["helium.desktop"];
        "video/quicktime" = ["helium.desktop"];
        "video/webm" = ["helium.desktop"];
        "video/x-matroska" = ["helium.desktop"];
        "video/x-msvideo" = ["helium.desktop"];
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
        accents = [theme.accent];
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

  services.dunst = {
    enable = true;
    settings = {
      global = {
        font = "${theme.font.mono} 13";
        markup = "full";
        format = "<b>%s</b>\n%b";
        sort = "yes";
        indicate_hidden = "yes";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        word_wrap = "yes";
        ignore_newline = "no";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = "yes";
        icon_position = "left";
        max_icon_size = 64;
        min_icon_size = 32;
        sticky_history = "yes";
        history_length = 20;
        dmenu = "${pkgs.rofi}/bin/rofi -dmenu -p dunst:";
        browser = "${pkgs.firefox}/bin/firefox --new-tab";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 12;
        ignore_dbusclose = false;
        layer = "overlay";
        force_xinerama = false;
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
        padding = 16;
        horizontal_padding = 20;
        text_icon_padding = 16;
        frame_width = 0;
        separator_height = 4;
        separator_color = "frame";
        progress_bar = true;
        progress_bar_height = 8;
        progress_bar_frame_width = 0;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;
        progress_bar_corner_radius = 4;
        transparency = 15;
        idle_threshold = 120;
        origin = "top-right";
        offset = "24x48";
        width = "(350, 500)";
        height = "(0, 300)";
        notification_limit = 5;
      };
      experimental = {
        per_monitor_dpi = false;
      };
      urgency_low = {
        background = "#${colors.base00}90";
        foreground = "#${colors.base05}";
        frame_color = "#${colors.base0D}";
        timeout = 5;
        highlight = "#${colors.base0D}";
        default_icon = "dialog-information-symbolic";
      };
      urgency_normal = {
        background = "#${colors.base00}90";
        foreground = "#${colors.base05}";
        frame_color = "#${colors.base0D}";
        timeout = 8;
        highlight = "#${colors.base0D}";
        default_icon = "dialog-information-symbolic";
      };
      urgency_critical = {
        background = "#${colors.base00}f0";
        foreground = "#${colors.base08}";
        frame_color = "#${colors.base08}";
        timeout = 0;
        highlight = "#${colors.base08}";
        default_icon = "dialog-warning-symbolic";
      };
    };
  };
}
