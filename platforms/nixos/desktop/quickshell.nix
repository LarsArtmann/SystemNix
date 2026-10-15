{
  config,
  lib,
  pkgs,
  dankMaterialShell,
  ...
}:
let
  cfg = config.programs.systemnix-quickshell;
  theme = import ../../common/theme.nix;
  inherit (import ../../../lib/default.nix lib) ports;
in
{
  imports = [
    dankMaterialShell.homeModules.niri
    dankMaterialShell.homeModules.dank-material-shell
  ];

  options.programs.systemnix-quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell via DankMaterialShell (replaces Waybar, Dunst, Wlogout, polkit_gnome)";

    package = lib.mkOption {
      type = lib.types.package;
      default =
        dankMaterialShell.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          (prev: {
            postInstall = prev.postInstall + ''
              # Weather "pop": the bar weather widget inherits widgetIconColor/
              # widgetTextColor, which resolve to the muted surfaceText gray in dark
              # mode — hard to read. Recolor icon + temperature to the theme's
              # primary accent. Scoped to Weather.qml only; every other bar widget
              # keeps the muted look. Drop when upstream ships a per-widget accent
              # option (none exists in the stable SettingsSpec as of 2026-09-30).
              weatherQml="$out/share/quickshell/dms/Modules/DankBar/Widgets/Weather.qml"
              test -f "$weatherQml"
              chmod -R u+w "$out/share/quickshell/dms/Modules/DankBar/Widgets"
              sed -i \
                -e 's/color: Theme\.widgetIconColor/color: Theme.primary/g' \
                -e 's/color: Theme\.widgetTextColor/color: Theme.primary/g' \
                "$weatherQml"
              grep -q 'color: Theme\.primary' "$weatherQml"

              # Clipboard modal density + cleanliness (2026-10-15, PasteBot-parity
              # pass). Upstream ships a "Text" caption above EVERY plain-text row,
              # one preview line, and a 650x550 modal. Changes, all verified by the
              # grep guards below (build fails if upstream text drifts):
              #   1. No per-row type caption for plain "text" entries (Image/Long
              #      Text captions stay — they carry information).
              #   2. Two preview lines instead of one (fits itemHeight 68: label 18
              #      + 2x21 text + spacing = 64 <= 68).
              #   3. Wider/taller modal: 650x550 -> 880x620 (more entries, longer
              #      previews per line).
              #   4. Denser rows: itemHeight 72 -> 68.
              # Drop these patches if upstream grows settings keys for them.
              clipDir="$out/share/quickshell/dms/Modals/Clipboard"
              test -f "$clipDir/ClipboardEntry.qml" && test -f "$clipDir/ClipboardConstants.qml"
              chmod -R u+w "$clipDir"
              entryQml="$clipDir/ClipboardEntry.qml"
              perl -0pi -e 's/(switch \(entryType\) \{.*?\n                \}\n)/$1                visible: entryType !== "text"\n/s' "$entryQml"
              sed -i \
                -e 's/maximumLineCount: entryType === "long_text" ? 3 : 1/maximumLineCount: 2/' \
                "$entryQml"
              grep -q 'visible: entryType !== "text"' "$entryQml"
              grep -q 'maximumLineCount: 2' "$entryQml"
              constQml="$clipDir/ClipboardConstants.qml"
              sed -i \
                -e 's/property int modalWidth: 650/property int modalWidth: 880/' \
                -e 's/property int modalHeight: 550/property int modalHeight: 620/' \
                -e 's/property int itemHeight: 72/property int itemHeight: 68/' \
                "$constQml"
              grep -q 'modalWidth: 880' "$constQml"
              grep -q 'modalHeight: 620' "$constQml"
              grep -q 'itemHeight: 68' "$constQml"
            '';
          });
      description = "The DankMaterialShell package";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
      inherit (cfg) package;

      # Clipboard daemon config (clsettings.json → core clipboard.Config).
      # maxHistory is NOT a settings.json key — it lives here. Missing keys keep
      # the Go defaults (MaxEntrySize 5M, MaxPinned 25).
      clipboardSettings.maxHistory = 100000;

      enableSystemMonitoring = true;
      enableDynamicTheming = false;
      enableAudioWavelength = true;
      enableCalendarEvents = false;

      settings = {
        fontFamily = theme.font.name;
        monoFontFamily = theme.font.mono;
        cornerRadius = 12;
        inherit (theme) iconTheme;

        showDock = true;
        dockAutoHide = true;
        dockSmartAutoHide = true;
        dockIconSize = 48;
        dockPosition = 2;
        dockTransparency = 0.92;

        lockScreenShowPowerActions = true;
        lockScreenShowSystemIcons = true;
        lockScreenShowTime = true;
        lockScreenShowDate = true;
        lockScreenShowMediaPlayer = true;
        lockScreenShowPasswordField = true;

        notificationOverlayEnabled = true;
        notificationPopupShadowEnabled = true;
        notificationPopupPrivacyMode = false;
        # Monitor-aware: popups only on the focused monitor, not both screens
        notificationFocusedMonitor = true;
        notificationShowTimeoutBar = true;
        notificationHistoryMaxAgeDays = 30;
        notificationHistoryMaxCount = 200;

        showSeconds = true;
        padHours12Hour = true;
        clockDateFormat = "ddd MMM d";

        useAutoLocation = true;

        osdAlwaysShowValue = true;
        fontScale = 1.5;

        showWorkspaceIndex = true;

        # PasteBot-style clipboard behavior: Enter/click on a history entry
        # pastes it directly into the focused window (DMS synthesizes Ctrl+V
        # via the compositor's virtual-keyboard protocol; niri supports it).
        # Without these, selecting an entry only copies it.
        clipboardEnterToPaste = true;
        clipboardClickToPaste = true;
        # Per-row chrome: keep ONLY pin (all actions stay in the right-click
        # context menu). Default ["pin","edit","delete"] put a 3-icon cluster
        # on every row — visual noise in a dense history list.
        clipboardVisibleEntryActions = [ "pin" ];

        showWorkspaceApps = true;
        maxWorkspaceIcons = 5;
      };

      # SystemNix DMS plugins — declaratively installed via DMS's plugin system.
      # Each plugin's src points to its directory in pkgs/dms-plugins/.
      # Port values are templated from lib/ports.nix — never hardcoded.
      # systemnix-ollama widget REMOVED 2026-10-12 with the ollama service
      # (owner directive; plugin source deleted from pkgs/dms-plugins/).
      plugins = {
        systemnix-dns-stats = {
          src = ../../../pkgs/dms-plugins/systemnix-dns-stats;
          settings = {
            statsUrl = "http://127.0.0.1:${toString ports.dns-blocker-stats}/stats";
            # Bearer token retired 2026-08-21 (OIDC SSO is the only dashboard
            # credential now). The widget shows its empty state until Pocket ID
            # grows machine credentials; re-add tokenPath when they exist.
          };
        };
        systemnix-gpu-monitor = {
          src = ../../../pkgs/dms-plugins/systemnix-gpu-monitor;
          settings.cardPath = "/sys/class/drm/card0/device";
        };
        systemnix-task-radar = {
          src = ../../../pkgs/dms-plugins/systemnix-task-radar;
          settings.apiUrl = "http://127.0.0.1:${toString ports.taskchampion}";
        };
        systemnix-service-health = {
          src = ../../../pkgs/dms-plugins/systemnix-service-health;
          settings.gatusUrl = "http://127.0.0.1:${toString ports.gatus}/api/v1/endpoints/statuses";
        };
        systemnix-btrfs = {
          src = ../../../pkgs/dms-plugins/systemnix-btrfs;
          settings = {
            timerName = "btrbk.timer";
            diskMount = "/";
          };
        };
        systemnix-camera = {
          src = ../../../pkgs/dms-plugins/systemnix-camera;
          settings.daemonUrl = "http://127.0.0.1:${toString ports.emeet-pixyd}";
        };
        systemnix-servers = {
          src = ../../../pkgs/dms-plugins/systemnix-servers;
          settings.diskMount = "/";
        };
        systemnix-crm = {
          src = ../../../pkgs/dms-plugins/systemnix-crm;
          # T42 (2026-10-08): Kith CRM loopback healthz — unauthenticated
          # by design (crm main.go), so the status pill measures the server
          # without auth/TLS noise; the vHost chain is gatus's job.
          settings.crmUrl = "http://127.0.0.1:${toString ports.crm}/healthz";
        };
        systemnix-dual-wan = {
          src = ../../../pkgs/dms-plugins/systemnix-dual-wan;
          settings = { };
        };
        systemnix-npu = {
          src = ../../../pkgs/dms-plugins/systemnix-npu;
          settings.devfreqPath = "/sys/class/devfreq";
        };
        systemnix-sops = {
          src = ../../../pkgs/dms-plugins/systemnix-sops;
          settings = {
            secretsDir = "/run/secrets";
            sopsFile = "/run/secrets/sops-nix-age-key";
          };
        };
        # Snippets launcher (PasteBot ⌘⇧C replacement): ":s" trigger in the
        # spotlight, one .txt file per snippet, ":s > name" captures the
        # current clipboard as a new snippet. Paste action reuses the DMS
        # clipboard daemon (dms cl copy + send-paste) — no wtype/ydotool.
        systemnix-snippets = {
          src = ../../../pkgs/dms-plugins/systemnix-snippets;
          settings.snippetsDir = "${config.home.homeDirectory}/.local/share/snippets";
        };
        # Community plugins — launcher-type plugins integrated into DMS spotlight
        dms-emoji-launcher = {
          src = pkgs.fetchFromGitHub {
            owner = "devnullvoid";
            repo = "dms-emoji-launcher";
            rev = "1c0a7d337a52b48f9499060076703a35e8dd4f4f";
            hash = "sha256-NQ14YenDiNK2VqXQ3z7jAkatbSRtYJHhOhvv7AJlUD8=";
          };
          settings = { };
        };
        dms-calculator = {
          src = pkgs.fetchFromGitHub {
            owner = "rochacbruno";
            repo = "DankCalculator";
            rev = "1db5865419a40a33171a475855a59e0b8bf7187f";
            hash = "sha256-j8C62+sevr6b+akzVSAqUVysIhb6Vbr8jnWcTXeOtE8=";
          };
          settings.calcEngine = "js";
        };
      };
    };

    # DMS handles its own systemd service via the upstream HM module.
    # The upstream module binds to config.wayland.systemd.target which
    # niri-flake sets to niri.service — so the shell starts with niri.
    systemd.user.services.dms = {
      Service = {
        Environment = [
          # matugen package is removed (enableDynamicTheming = false), but DMS still
          # probes `which matugen` and logs warnings. This env var makes DMS skip the
          # probe entirely (Theme.qml:143). Catppuccin Mocha is our global theme.
          "DMS_DISABLE_MATUGEN=1"
        ];
        # Defense-in-depth: DMS is now the launcher, clipboard, and all modals.
        # Prevent a repeat of the 2026-06-30 rofi OOM (7 GB leak → compositor killed).
        # 4G is generous for a Qt/QML shell but stops runaway leaks before global OOM.
        MemoryMax = "4G";
        # Restart hardening: upstream Quickshell has an unfixed ScriptModel UAF crash
        # (issue #863) triggered by rapid Wayland toplevel churn (polkit dialogs,
        # window open/close storms). DMS WILL crash occasionally — the goal is fast
        # recovery without hammering the system. Backoff prevents the 288-restart
        # storm observed on 2026-07-11.
        Restart = lib.mkForce "always";
        RestartSec = 2;
      };
      Unit = {
        # High burst count: DMS crashes are transient (model churn). Allow many
        # restarts within 5 minutes before giving up — losing the shell is worse
        # than a few quick restarts. Clear with: systemctl --user reset-failed dms
        StartLimitIntervalSec = 300;
        StartLimitBurst = 30;
      };
    };
  };
}
