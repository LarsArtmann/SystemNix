{
  pkgs,
  config,
  lib,
  wallpapers,
  colorScheme,
  ...
}: let
  theme = import ../../common/theme.nix;
  colors = colorScheme.palette;
  wallpaperDir = "$HOME/.local/share/wallpapers";
  spring = {
    damping-ratio = 0.8;
    stiffness = 1000;
    epsilon = 0.0001;
  };
  sd = import ../../../lib/default.nix lib;

  ssh-suspend-guard = pkgs.writeShellApplication {
    name = "ssh-suspend-guard";
    runtimeInputs = [pkgs.systemd pkgs.procps];
    text = ''
      POLL_INTERVAL=30
      inhibit_pid=""

      cleanup() {
        [ -n "$inhibit_pid" ] && kill "$inhibit_pid" 2>/dev/null || true
      }
      trap cleanup EXIT

      has_ssh() {
        pgrep -a sshd 2>/dev/null | grep -q '@'
      }

      while true; do
        if has_ssh; then
          if [ -z "$inhibit_pid" ] || ! kill -0 "$inhibit_pid" 2>/dev/null; then
            systemd-inhibit --what=sleep --mode=block \
              --who="ssh-suspend-guard" \
              --why="Active SSH session prevents suspend" \
              sleep infinity &
            inhibit_pid=$!
            echo "SSH session active — holding sleep inhibitor (pid=$inhibit_pid)"
          fi
        else
          if [ -n "$inhibit_pid" ]; then
            kill "$inhibit_pid" 2>/dev/null || true
            wait "$inhibit_pid" 2>/dev/null || true
            inhibit_pid=""
            echo "No SSH sessions — released sleep inhibitor"
          fi
        fi
        sleep "$POLL_INTERVAL"
      done
    '';
  };

  wallpaper-set = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = with pkgs; [awww coreutils];
    text = ''
      mode="''${1:-random}"
      wallpaper_dir="''${2:-$HOME/.local/share/wallpapers}"

      wait_for_daemon() {
        for _ in $(seq 1 60); do
          awww query >/dev/null 2>&1 && return 0
          sleep 1
        done
        return 1
      }

      set_random() {
        local img
        img=$(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n1)
        if [[ -z $img ]]; then
          echo "No wallpaper images found in $wallpaper_dir" >&2
          return 1
        fi
        awww img "$img" --transition-type random --transition-duration 3
      }

      wait_for_daemon || exit 1

      case "$mode" in
      restore)
        awww restore 2>/dev/null || set_random
        ;;
      random)
        set_random
        ;;
      *)
        echo "Usage: $0 <random|restore> [wallpaper_dir]" >&2
        exit 1
        ;;
      esac
    '';
  };
in {
  config = {
    home.file.".local/share/wallpapers".source = wallpapers;

    programs.niri.settings = {
      prefer-no-csd = true;

      spawn-at-startup = [
        {command = ["ghostty" "-e" "sudo" "btop"];}
        {command = ["ghostty" "-e" "nvtop"];}
      ];

      screenshot-path = "~/Pictures/screenshots/%Y-%m-%d %H-%M-%S.png";

      xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

      input = {
        keyboard = {
          xkb = {
            layout = "us";
            variant = "";
          };
          repeat-delay = 300;
          repeat-rate = 50;
          track-layout = "window";
        };

        touchpad = {
          tap = true;
          dwt = true;
          dwtp = true;
          natural-scroll = true;
          tap-button-map = "left-middle-right";
          click-method = "clickfinger";
          drag = true;
          disabled-on-external-mouse = true;
        };

        mouse = {
          natural-scroll = false;
          accel-profile = "flat";
        };

        trackball = {
          accel-profile = "flat";
          scroll-method = "on-button-down";
          scroll-button = 273;
        };

        tablet = {
          map-to-output = "eDP-1";
        };

        warp-mouse-to-focus.enable = true;
        focus-follows-mouse = {
          max-scroll-amount = "10%";
        };
        workspace-auto-back-and-forth = true;
      };

      cursor = {
        theme = theme.cursorTheme;
        size = theme.cursorSize;
      };

      layout = {
        gaps = 8;
        center-focused-column = "on-overflow";
        always-center-single-column = true;
        background-color = "#${colors.base00}";

        preset-column-widths = [
          {proportion = 0.33333;}
          {proportion = 0.5;}
          {proportion = 0.66667;}
        ];

        default-column-width = {proportion = 0.5;};

        focus-ring = {
          width = 2;
          active = {
            color = "#${colors.base0D}";
          };
          inactive = {
            color = "#${colors.base03}";
          };
          urgent = {
            color = "#${colors.base08}";
          };
        };

        border = {
          width = 0;
        };

        shadow = {
          enable = true;
          softness = 30;
          spread = 5;
          offset = {
            x = 0;
            y = 5;
          };
          draw-behind-window = true;
          color = "#00000060";
        };

        struts = {
          left = 0;
          right = 0;
          top = 0;
          bottom = 0;
        };
      };

      binds = let
        sh = cmd: ["sh" "-c" cmd];
        screenshot = grimArgs: "mkdir -p ~/Pictures/screenshots && grim ${grimArgs} /tmp/screenshot.png && wl-copy < /tmp/screenshot.png && swappy -f /tmp/screenshot.png";
      in {
        "Mod+Return".action.spawn = ["ghostty"];
        "Mod+Shift+Return".action.spawn = ["kitty"];

        "Mod+Q".action.close-window = {};
        "Mod+Shift+Q".action.quit = {};
        "F11".action.fullscreen-window = {};
        "Mod+Shift+Space".action.toggle-window-floating = {};
        "Mod+Shift+M".action.maximize-column = {};
        "Mod+T".action.toggle-column-tabbed-display = {};

        "Mod+Left".action.focus-column-left = {};
        "Mod+Right".action.focus-column-right = {};
        "Mod+Up".action.focus-window-up = {};
        "Mod+Down".action.focus-window-down = {};

        "Mod+H".action.focus-column-left = {};
        "Mod+L".action.focus-column-right = {};
        "Mod+K".action.focus-window-up = {};
        "Mod+J".action.focus-window-down = {};

        "Mod+Shift+Left".action.move-column-left = {};
        "Mod+Shift+Right".action.move-column-right = {};
        "Mod+Shift+Up".action.move-window-up = {};
        "Mod+Shift+Down".action.move-window-down = {};

        "Mod+Shift+H".action.move-column-left = {};
        "Mod+Shift+L".action.move-column-right = {};
        "Mod+Shift+K".action.move-window-up = {};
        "Mod+Shift+J".action.move-window-down = {};

        "Mod+BracketLeft".action.consume-window-into-column = {};
        "Mod+BracketRight".action.expel-window-from-column = {};
        "Mod+R".action.switch-preset-column-width = {};
        "Mod+Shift+R".action.reset-window-height = {};
        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Equal".action.set-column-width = "+10%";

        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;

        "Mod+Shift+1".action.move-column-to-workspace = 1;
        "Mod+Shift+2".action.move-column-to-workspace = 2;
        "Mod+Shift+3".action.move-column-to-workspace = 3;
        "Mod+Shift+4".action.move-column-to-workspace = 4;
        "Mod+Shift+5".action.move-column-to-workspace = 5;
        "Mod+Shift+6".action.move-column-to-workspace = 6;
        "Mod+Shift+7".action.move-column-to-workspace = 7;
        "Mod+Shift+8".action.move-column-to-workspace = 8;
        "Mod+Shift+9".action.move-column-to-workspace = 9;

        "Mod+Page_Up".action.focus-workspace-up = {};
        "Mod+Page_Down".action.focus-workspace-down = {};
        "Mod+Shift+Page_Up".action.move-column-to-workspace-up = {};
        "Mod+Shift+Page_Down".action.move-column-to-workspace-down = {};

        "Mod+D".action.spawn = ["rofi" "-show" "drun"];
        "Mod+Space".action.spawn = ["rofi" "-show" "drun"];
        "Mod+Shift+Slash".action.spawn = sh "niri msg binds | rofi -dmenu -p 'Keybindings:' -theme-str 'window {width: 80%; height: 80%;}'";
        "Alt+C".action.spawn = sh "cliphist list | rofi -dmenu -p 'Clipboard:' -kb-delete-entry 'Ctrl+Delete' -theme-str 'window {width: 50%;} listview {columns: 1; lines: 12; scrollbar: true; } element {orientation: horizontal; padding: 8px; spacing: 8px; } element-text {horizontal-align: 0.0; vertical-align: 0.5; } scrollbar {enabled: true; width: 4px; padding: 0; } scrollbar-handle {background-color: @selected; border-radius: 2px; }' | cliphist decode | wl-copy";
        "Mod+period".action.spawn = sh "rofi -modi emoji -show emoji -theme-str 'window {width: 40%;}'";
        "Mod+Shift+C".action.spawn = sh "rofi -show calc -modi calc -no-show-match -no-sort -theme-str 'window {width: 30%;}'";
        # dunstctl keybind removed — DankMaterialShell provides notification center
        "Mod+Shift+E".action.spawn = ["emacs"];
        "Mod+Shift+B".action.spawn = ["firefox"];
        "Mod+Z".action.spawn = ["zed"];
        "Mod+Shift+F".action.spawn = sh "ghostty --class floating -e yazi";
        "Mod+Shift+D".action.spawn = sh "zellij --layout dev";

        "Mod+Shift+Escape".action.spawn = ["swaylock"];
        "Mod+Shift+P".action.power-off-monitors = {};
        "Mod+Shift+S".action.suspend = {};

        "Mod+W".action.spawn = sh "${lib.getExe wallpaper-set} random ${wallpaperDir}";

        "Mod+Shift+F11".action.spawn = sh (screenshot ''-g "$(slurp)"'');
        "Mod+F11".action.spawn = sh (screenshot "");
        "Mod+Ctrl+F11".action.spawn = sh (screenshot "-o $(niri msg focused-output | head -1)");

        "XF86AudioRaiseVolume" = {
          action.spawn = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.5";
          allow-when-locked = true;
        };
        "XF86AudioLowerVolume" = {
          action.spawn = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
          allow-when-locked = true;
        };
        "XF86AudioMute" = {
          action.spawn = sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          allow-when-locked = true;
        };
        "XF86AudioMicMute" = {
          action.spawn = sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          allow-when-locked = true;
        };

        "XF86AudioPlay" = {
          action.spawn = sh "playerctl play-pause";
          allow-when-locked = true;
        };
        "XF86AudioNext" = {
          action.spawn = sh "playerctl next";
          allow-when-locked = true;
        };
        "XF86AudioPrev" = {
          action.spawn = sh "playerctl previous";
          allow-when-locked = true;
        };

        "XF86MonBrightnessUp" = {
          action.spawn = sh "ddcutil setvcp 10 + 10 2>/dev/null || brightnessctl set +5%";
          allow-when-locked = true;
        };
        "XF86MonBrightnessDown" = {
          action.spawn = sh "ddcutil setvcp 10 - 10 2>/dev/null || brightnessctl set 5%-";
          allow-when-locked = true;
        };
      };

      window-rules = [
        {
          matches = [{app-id = "^org.prismlauncher.PrismLauncher$";}];
          opacity = 1.0;
        }
        {
          matches = [{is-floating = false;}];
          opacity = 0.95;
          geometry-corner-radius = {
            top-left = 8.0;
            top-right = 8.0;
            bottom-left = 8.0;
            bottom-right = 8.0;
          };
          clip-to-geometry = true;
          draw-border-with-background = false;
        }
        {
          matches = [{title = "^Picture-in-Picture$";}];
          open-floating = true;
        }
        {
          matches = [
            {app-id = "^pavucontrol$";}
            {app-id = "^com.saivert.pwvucontrol$";}
          ];
          open-floating = true;
        }
        {
          matches = [{app-id = "^floating$";}];
          open-floating = true;
          default-floating-position = {
            x = 0.25;
            y = 0.15;
            relative-to = "top-left";
          };
          default-column-width = {proportion = 0.5;};
          default-window-height = {proportion = 0.7;};
        }
        {
          matches = [
            {app-id = "^steam_app_.*";}
          ];
          open-fullscreen = true;
          opacity = 1.0;
        }
        {
          matches = [
            {app-id = "^steam_app_.*";}
            {app-id = "^steam$";}
            {title = "^Counter-Strike";}
          ];
          open-fullscreen = true;
          opacity = 1.0;
        }
        {
          matches = [{app-id = "^xdg-desktop-portal-gtk$";}];
          open-floating = true;
        }
        {
          matches = [
            {
              app-id = "^org.keepassxc.KeePassXC$";
              title = "Generate Password";
            }
          ];
          open-floating = true;
        }
        {
          matches = [
            {app-id = "^firefox$";}
            {app-id = "^Firefox$";}
          ];
          open-on-workspace = "browser";
          default-column-width = {proportion = 0.75;};
        }
        {
          matches = [
            {app-id = "^com.mitchellh.ghostty$";}
            {app-id = "^kitty$";}
            {app-id = "^foot$";}
            {app-id = "^helium$";}
          ];
          open-on-workspace = "main";
          default-column-width = {proportion = 0.75;};
        }
        {
          matches = [{app-id = "^emacs$";}];
          open-on-workspace = "dev";
          default-column-width = {proportion = 0.66667;};
        }
        {
          matches = [
            {app-id = "^Slack$";}
            {app-id = "^discord$";}
            {app-id = "^vesktop$";}
            {app-id = "^telegramdesktop$";}
            {app-id = "^signal$";}
          ];
          open-on-workspace = "chat";
        }
        {
          matches = [
            {app-id = "^Spotify$";}
            {app-id = "^spotify$";}
          ];
          open-on-workspace = "media";
        }
      ];

      workspaces = {
        main = {};
        browser = {};
        dev = {};
        chat = {};
        media = {};
      };

      animations = {
        horizontal-view-movement.kind.spring = spring;
        window-open.kind.spring = spring;
        window-close.kind.spring = spring;
        window-movement.kind.spring = spring;
        window-resize.kind.spring = spring;
        workspace-switch.kind.spring = spring;
      };
    };

    systemd.user.services = {
      awww-daemon = {
        Unit = {
          Description = "awww wallpaper daemon";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
          StartLimitBurst = 3;
          StartLimitIntervalSec = 300;
        };
        Service =
          sd.hardenUser {}
          // sd.serviceDefaultsUser {RestartSec = "3s";}
          // {
            ExecStartPre = let
              checkWayland = pkgs.writeShellApplication {
                name = "awww-check-wayland";
                text = ''
                  if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
                    echo "awww-daemon: WAYLAND_DISPLAY not set, compositor not ready"
                    exit 1
                  fi
                '';
              };
            in
              lib.getExe checkWayland;
            ExecStart = "${lib.getExe' pkgs.awww "awww-daemon"}";
          };
        Install.WantedBy = ["graphical-session.target"];
      };

      awww-wallpaper = {
        Unit = {
          Description = "Set wallpaper (self-healing via PartOf)";
          After = ["graphical-session.target"];
          PartOf = ["awww-daemon.service" "graphical-session.target"];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe wallpaper-set} restore";
        };
        Install.WantedBy = ["graphical-session.target"];
      };

      swayidle = {
        Unit = {
          Description = "Idle management daemon";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
          StartLimitBurst = 3;
          StartLimitIntervalSec = 120;
        };
        Service =
          sd.serviceDefaultsUser {}
          // {
            ExecStart = let
              swayidleSuspend = pkgs.writeShellApplication {
                name = "swayidle-suspend";
                runtimeInputs = [pkgs.systemd];
                text = ''
                  systemctl suspend
                '';
              };
            in "${lib.getExe' pkgs.swayidle "swayidle"} -w timeout 43200 ${lib.getExe swayidleSuspend} before-sleep ${lib.getExe' pkgs.swaylock "swaylock"}";
            TimeoutStartSec = "10s";
          };
        Install.WantedBy = ["graphical-session.target"];
      };

      ssh-suspend-guard = {
        Unit = {
          Description = "Prevents suspend while SSH sessions are active";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
          StartLimitBurst = 3;
          StartLimitIntervalSec = 120;
        };
        Service =
          sd.hardenUser {}
          // sd.serviceDefaultsUser {}
          // {
            ExecStart = lib.getExe ssh-suspend-guard;
            TimeoutStartSec = "10s";
          };
        Install.WantedBy = ["graphical-session.target"];
      };

      cliphist = {
        Unit = {
          Description = "Clipboard history watcher";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
          StartLimitBurst = 3;
          StartLimitIntervalSec = 120;
        };
        Service =
          sd.serviceDefaultsUser {}
          // {
            ExecStart = "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --watch ${lib.getExe pkgs.cliphist} store";
            TimeoutStartSec = "10s";
          };
        Install.WantedBy = ["graphical-session.target"];
      };
    };
  };
}
