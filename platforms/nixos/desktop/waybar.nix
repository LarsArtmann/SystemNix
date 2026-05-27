{
  lib,
  pkgs,
  ...
}: let
  waybarCamera = pkgs.writeShellApplication {
    name = "waybar-camera";
    runtimeInputs = [pkgs.emeet-pixyd];
    text = ''
      emeet-pixyd waybar 2>/dev/null || echo '{"text":"📷 ---","tooltip":"EMEET PIXY: daemon not running","class":"custom-camera offline"}'
    '';
  };

  waybarDnsStats = pkgs.writeShellApplication {
    name = "waybar-dns-stats";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.bc];
    text = ''
      STATS=$(curl -sf --connect-timeout 2 http://127.0.0.1:9090/stats 2>/dev/null || echo "")
      if [ -z "$STATS" ]; then
        echo "DNS: off"
        exit 0
      fi
      TOTAL=$(echo "$STATS" | jq -r '.totalBlocked // 0' 2>/dev/null)
      if [ "$TOTAL" = "null" ] || [ -z "$TOTAL" ]; then
        TOTAL=0
      fi
      if [ "$TOTAL" -ge 1000000 ]; then
        FMT=$(echo "scale=1; $TOTAL / 1000000" | bc)M
      elif [ "$TOTAL" -ge 1000 ]; then
        FMT=$(echo "scale=1; $TOTAL / 1000" | bc)K
      else
        FMT="$TOTAL"
      fi
      RECENT=$(echo "$STATS" | jq -r '.recentBlocks[:3] | map(.domain) | join(", ")' 2>/dev/null || echo "")
      echo "{\"text\": \"$FMT blocked\", \"tooltip\": \"DNS Blocker\\nTotal: $TOTAL domains\\nRecent: $RECENT\"}"
    '';
  };

  waybarMedia = pkgs.writeShellApplication {
    name = "waybar-media";
    runtimeInputs = [pkgs.playerctl pkgs.gnused];
    text = ''
      status=$(playerctl status 2>/dev/null)
      if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
        echo ""
        exit 0
      fi

      artist=$(playerctl metadata artist 2>/dev/null || echo "")
      title=$(playerctl metadata title 2>/dev/null || echo "")
      album=$(playerctl metadata album 2>/dev/null || echo "")
      player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null || echo "")

      case "$player" in
        spotify) icon="🎵" ;;
        firefox) icon="🌐" ;;
        *) icon="🎶" ;;
      esac

      class=""
      if [ "$status" = "Paused" ]; then
        class="paused"
        icon="⏸"
      fi

      artist=$(echo "$artist" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

      if [ -n "$album" ] && [ "$album" != "" ]; then
        album_tooltip="\nAlbum: $album"
      else
        album_tooltip=""
      fi

      echo "{\"text\": \"$icon ''${artist} - ''${title}\", \"tooltip\": \"<b>''${artist}</b> — ''${title}''${album_tooltip}\nPlayer: $player | $status\", \"class\": \"$class\"}"
    '';
  };

  waybarClipboard = pkgs.writeShellApplication {
    name = "waybar-clipboard";
    runtimeInputs = [pkgs.cliphist pkgs.gawk pkgs.coreutils pkgs.gnused];
    text = ''
      CLIP_CONTENT=$(cliphist list | head -1 | awk -F'\t' '{print $2}' || echo "Empty")
      CLIP_TRUNCATED=$(echo "$CLIP_CONTENT" | head -c 15)
      if [ "''${#CLIP_CONTENT}" -gt 15 ]; then
        CLIP_TRUNCATED="''${CLIP_TRUNCATED}..."
      fi
      COUNT=$(cliphist list | wc -l || echo "0")
      echo "{\"text\": \"$CLIP_TRUNCATED\", \"tooltip\": \"Clipboard ($COUNT items)\\nClick: open history\\nMiddle-click: clear all\"}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
    '';
  };

  waybarClipboardMenu = pkgs.writeShellApplication {
    name = "waybar-clipboard-menu";
    runtimeInputs = [pkgs.cliphist pkgs.rofi pkgs.wl-clipboard];
    text = ''
      cliphist list | rofi -dmenu -p 'Clipboard:' -kb-delete-entry 'Ctrl+Delete' -theme-str 'window {width: 50%;} listview {columns: 1; lines: 12; scrollbar: true; } element {orientation: horizontal; padding: 8px; spacing: 8px; } element-text {horizontal-align: 0.0; vertical-align: 0.5; } scrollbar {enabled: true; width: 4px; padding: 0; } scrollbar-handle {background-color: #89b4fa; border-radius: 2px; }' | cliphist decode | wl-copy
    '';
  };

  waybarClipboardClear = pkgs.writeShellApplication {
    name = "waybar-clipboard-clear";
    runtimeInputs = [pkgs.cliphist];
    text = ''
      cliphist wipe
    '';
  };

  waybarWeather = pkgs.writeShellApplication {
    name = "waybar-weather";
    runtimeInputs = [pkgs.curl pkgs.coreutils];
    text = ''
      WTTR=$(curl -sf "wttr.in/?format=3" 2>/dev/null || echo "")
      if [ -z "$WTTR" ]; then
        echo '{"text":"N/A","tooltip":"Weather: unavailable","class":"error"}'
        exit 0
      fi
      TEMP=$(echo "$WTTR" | cut -d' ' -f1)
      COND=$(echo "$WTTR" | cut -d' ' -f2- | tr -d '+')
      echo "{\"text\": \"$TEMP $COND\", \"tooltip\": \"Weather: $TEMP $COND\"}"
    '';
  };
in {
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 42;
        spacing = 4;

        modules-left = [
          "niri/workspaces"
          "niri/window"
        ];

        modules-center = [
          "clock"
          "custom/media"
        ];

        modules-right = [
          "custom/camera"
          "custom/dns-stats"
          "disk"
          "custom/weather"
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "temperature"
          "custom/clipboard"
          "tray"
          "custom/power"
        ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            main = "🖥";
            browser = "🌐";
            dev = "💻";
            chat = "💬";
            media = "🎵";
            focused = "󰮯";
            default = "";
            urgent = "🔥";
          };
        };

        "niri/window" = {
          format = "{title}";
          icon = true;
          icon-size = 18;
          max-length = 50;
          rewrite = {
            "(.+) — Mozilla Firefox" = "🦊 $1";
            "(.+) - Mozilla Firefox" = "🦊 $1";
          };
        };

        "custom/camera" = {
          exec = lib.getExe waybarCamera;
          return-type = "json";
          interval = 2;
          on-click = "${pkgs.emeet-pixyd}/bin/emeet-pixyd toggle-privacy";
          on-middle-click = "${pkgs.emeet-pixyd}/bin/emeet-pixyd center";
          on-right-click = "${pkgs.emeet-pixyd}/bin/emeet-pixyd track";
        };

        "custom/dns-stats" = {
          format = "🛡 {} {text}";
          exec = lib.getExe waybarDnsStats;
          return-type = "json";
          interval = 30;
          on-click = "xdg-open http://127.0.0.1:9090/stats";
        };

        "clock" = {
          format = "󰥔 {:%H:%M:%S}";
          format-alt = "󰃭 {:%Y-%m-%d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "cpu" = {
          format = "⚡ {usage}%";
          tooltip-format = "CPU: {usage}%  Load: {load}";
          interval = 2;
          min-length = 5;
          states = {
            high = 85;
          };
        };

        "memory" = {
          format = "💾 {percentage}%";
          tooltip-format = "RAM: {used:0.1f}G / {total:0.1f}G";
          interval = 3;
          min-length = 5;
          states = {
            high = 90;
          };
        };

        "temperature" = {
          thermal-zone = 0;
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = ["" "" ""];
          tooltip-format = "CPU: {temperatureC}°C";
        };

        "disk" = {
          path = "/";
          format = "💿 {percentage_used}%";
          tooltip-format = "Root: {used}/{total} ({percentage_used}%)\n{path}";
          interval = 30;
          states = {
            warning = 80;
            critical = 90;
          };
        };

        "network" = {
          format-wifi = "📶 {essid}";
          format-ethernet = "🔌 {ipaddr}";
          format-disconnected = "🚫 Disconnected";
          tooltip-format = "{ifname} via {gwaddr}\n{ipaddr}/{cidr}";
          interval = 5;
        };

        "pulseaudio" = {
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-muted = "🔇 Muted";
          format-icons = {
            headphone = "🎧";
            headset = "🎧";
            default = ["🔈" "🔉" "🔊"];
          };
          on-click = "pwvucontrol";
          on-scroll-up = "pamixer -i 5";
          on-scroll-down = "pamixer -d 5";
          tooltip-format = "{desc}  {volume}%";
        };

        "custom/media" = {
          exec = lib.getExe waybarMedia;
          return-type = "json";
          interval = 2;
          on-click = "playerctl play-pause";
          on-scroll-up = "playerctl next";
          on-scroll-down = "playerctl previous";
          max-length = 40;
        };

        "custom/clipboard" = {
          format = "📋 {text}";
          exec = lib.getExe waybarClipboard;
          return-type = "json";
          interval = 5;
          on-click = lib.getExe waybarClipboardMenu;
          on-middle-click = lib.getExe waybarClipboardClear;
        };

        "custom/power" = {
          format = "⏻";
          on-click = "wlogout";
          tooltip = "Power menu";
        };

        "custom/weather" = {
          format = "🌤 {} {text}";
          exec = lib.getExe waybarWeather;
          return-type = "json";
          interval = 1800;
          on-click = "xdg-open https://wttr.in";
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
        min-height: 0;
        padding: 0 6px;
        transition: none;
      }

      window#waybar {
        background: #1e1e2e;
        color: #cdd6f4;
        border-bottom: 1px solid #313244;
      }

      #workspaces button {
        padding: 0 8px;
        background: transparent;
        color: #6c7086;
      }

      #workspaces button:hover {
        color: #cdd6f4;
      }

      #workspaces button.active {
        color: #89b4fa;
      }

      #workspaces button.urgent {
        color: #f38ba8;
      }

      #niri-window {
        color: #a6adc8;
        padding: 0 12px;
      }

      #clock {
        color: #cdd6f4;
        font-weight: bold;
        padding: 0 12px;
      }

      #custom-media {
        color: #b4befe;
        font-size: 13px;
      }

      #cpu, #memory, #temperature, #network, #pulseaudio, #disk,
      #custom-clipboard, #custom-dns-stats, #custom-camera, #tray, #custom-power {
        padding: 0 10px;
        color: #a6adc8;
      }

      #custom-camera.tracking {
        color: #a6e3a1;
      }

      #custom-camera.privacy {
        color: #f38ba8;
      }

      #custom-camera.in-call {
        font-weight: bold;
      }

      #custom-camera.offline {
        color: #585b70;
      }

      #custom-clipboard:hover, #custom-power:hover, #custom-dns-stats:hover,
      #custom-camera:hover {
        color: #cdd6f4;
        background: #313244;
      }

      #cpu.high, #memory.high {
        color: #f38ba8;
      }

      #disk.warning {
        color: #f9e2af;
      }

      #disk.critical {
        color: #f38ba8;
        font-weight: bold;
      }

      #temperature.critical {
        color: #f38ba8;
        font-weight: bold;
      }

      #network.disconnected {
        color: #f38ba8;
      }

      #pulseaudio.muted {
        color: #585b70;
      }

      #tray {
        padding: 0 8px;
      }

      #custom-power {
        color: #f38ba8;
      }

      tooltip {
        background: #1e1e2e;
        border: 1px solid #45475a;
        border-radius: 8px;
        padding: 8px 12px;
        color: #cdd6f4;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }

      tooltip label {
        color: #cdd6f4;
        padding: 2px;
      }

      #clock:hover,
      #cpu:hover,
      #memory:hover,
      #temperature:hover,
      #disk:hover,
      #network:hover,
      #pulseaudio:hover,
      #tray:hover,
      #custom-weather:hover,
      #custom-media:hover {
        color: #cdd6f4;
        background: #313244;
      }

      #custom-media.paused {
        color: #585b70;
      }

      #custom-weather.error {
        color: #585b70;
      }
    '';
  };

  systemd.user.services.waybar = {
    Service = {
      Restart = lib.mkForce "always";
      RestartSec = "3s";
    };
    Unit = {
      StartLimitBurst = 5;
      StartLimitIntervalSec = 120;
    };
  };
}
