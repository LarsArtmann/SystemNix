{
  config,
  lib,
  pkgs,
  dankMaterialShell,
  dmsPaste,
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
    # PasteBot-parity paste workflow (snippets launcher plugin +
    # clipboard-parity settings) — github:LarsArtmann/dms-paste,
    # extracted from this tree 2026-10-16.
    dmsPaste.homeModules.dms-paste
  ];

  options.programs.systemnix-quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell via DankMaterialShell (replaces Waybar, Dunst, Wlogout, polkit_gnome)";

    package = lib.mkOption {
      type = lib.types.package;
      # QML polish legs live HERE (no longer via dms-paste's lib.patchDms)
      # since 2026-10-28: DMS 2.x moved clipboard geometry onto Theme
      # density expressions (`maximumLineCount: entryType === "long_text" ?
      # 3 + Math.min(0, Theme.densityLevel) : 1`, `itemHeight:
      # Theme.listItemTwoLineHeight + Theme.densityStepM`), so patchDms's
      # literal-string seds stopped matching and its own grep guards killed
      # installPhase with NO log line (the 2026-10-23 silent-installPhase
      # class, re-hit 2026-10-28). Every leg below is a property-name
      # rewrite followed by its own POSITIVE guard, so upstream drift fails
      # loudly instead of silently skipping; perl is no longer needed.
      # LIFT: once github:LarsArtmann/dms-paste tracks DMS 2.x, drop these
      # bodies and call lib.patchDms again (pastebot-parity-audit.nix keeps
      # the settings contract either way — it never inspected these files).
      default =
        dankMaterialShell.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          (prev: {
            postInstall = (prev.postInstall or "") + ''
              # ── Clipboard modal (PasteBot parity) ───────────────────────
              # 1) no per-row type caption for plain "text" entries (Image /
              #    Long Text captions stay — they carry information)
              # 2) two preview lines instead of one (fits row height 68:
              #    label 18 + 2x21 text + spacing = 64 <= 68)
              # 3) wider/taller modal 650x550 -> 880x620, denser rows -> 68
              clipDir="$out/share/quickshell/dms/Modals/Clipboard"
              test -f "$clipDir/ClipboardEntry.qml"
              test -f "$clipDir/ClipboardConstants.qml"
              chmod -R u+w "$clipDir"
              entryQml="$clipDir/ClipboardEntry.qml"
              # Anchor on the caption's UNIQUE font line: the row's type
              # caption is the only StyledText with fontSizeSmall, whereas
              # `color: root.colorForRole(Theme.primary)` also styles the
              # pinned-indicator DIcon — an earlier color-anchored sed hid
              # the pin marker on text entries too (caught 2026-10-28 by
              # diffing the patched QML against upstream).
              sed -i \
                -e 's|^\( *font\.pixelSize: Theme\.fontSizeSmall\)$|\1\n                visible: entryType !== "text"|' \
                "$entryQml"
              grep -q 'visible: entryType !== "text"' "$entryQml"
              sed -i -e 's|^\( *maximumLineCount: \).*$|\12|' "$entryQml"
              grep -q '^ *maximumLineCount: 2$' "$entryQml"
              constQml="$clipDir/ClipboardConstants.qml"
              sed -i \
                -e 's|^\( *readonly property int modalWidth: \).*$|\1880|' \
                -e 's|^\( *readonly property int modalHeight: \).*$|\1620|' \
                -e 's|^\( *readonly property [a-z]* itemHeight: \).*$|\168|' \
                "$constQml"
              grep -q 'modalWidth: 880' "$constQml"
              grep -q 'modalHeight: 620' "$constQml"
              grep -q 'itemHeight: 68' "$constQml"

              # ── Weather "pop" ───────────────────────────────────────────
              # The bar weather widget inherits widgetIconColor/
              # widgetTextColor, which resolve to the muted surfaceText gray
              # in dark mode — hard to read. Recolor icon + temperature to
              # the theme's primary accent, scoped to Weather.qml only. Drop
              # when upstream ships a per-widget accent option (none exists
              # in the stable SettingsSpec as of 2026-09-30).
              #
              # Glob + LOOP, not `head -1`: DMS 2.x ships BOTH the legacy
              # Modules/DankBar and the live Modules/DBar trees, and only the
              # live one still uses the widget*Color tokens — the 2026-10-28
              # failure was `ls | head -1` picking DankBar, whose Weather.qml
              # has no such color, so the sed no-opped and the single-file
              # grep guard aborted installPhase (float-proof-20261028-214409).
              weatherPatched=0
              for weatherQml in "$out/share/quickshell/dms"/Modules/*/Widgets/Weather.qml; do
                [ -f "$weatherQml" ] || continue
                chmod u+w "$weatherQml"
                sed -i \
                  -e 's/color: Theme\.widgetIconColor/color: Theme.primary/g' \
                  -e 's/color: Theme\.widgetTextColor/color: Theme.primary/g' \
                  "$weatherQml"
                if grep -q 'color: Theme\.primary' "$weatherQml"; then
                  weatherPatched=$((weatherPatched + 1))
                fi
              done
              # At least one Weather widget must end up recolored — a module
              # rename or a dropped widget still fails loudly here.
              test "$weatherPatched" -gt 0
            '';
          });
      description = "The DankMaterialShell package";
    };
  };

  config = lib.mkIf cfg.enable {
    # PasteBot-parity paste workflow: registers the paste-snippets launcher
    # plugin (":s" trigger) and mkDefaults the clipboard-parity settings
    # (enterToPaste/clickToPaste/maxHistory 100000/visibleEntryActions=["pin"])
    # from the dms-paste input. Pinned by pastebot-parity-audit.nix.
    programs.dms-paste.enable = true;

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
      inherit (cfg) package;

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
        # Hide empty workspaces in the bar pill strip: named workspaces
        # always exist in niri (no hide-when-empty), so the compositor
        # still routes to them; the bar just stops showing unused slots.
        showOccupiedWorkspacesOnly = true;

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
        # Snippets launcher (paste-snippets, github:LarsArtmann/dms-paste):
        # registered by the dms-paste home module via programs.dms-paste —
        # not listed here anymore.
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
