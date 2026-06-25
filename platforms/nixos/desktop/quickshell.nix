{
  config,
  lib,
  pkgs,
  dankMaterialShell,
  colorScheme,
  ...
}: let
  cfg = config.programs.systemnix-quickshell;
  inherit (import ../../../lib/default.nix lib) ports;
in {
  imports = [
    dankMaterialShell.homeModules.niri
    dankMaterialShell.homeModules.dank-material-shell
  ];

  options.programs.systemnix-quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell via DankMaterialShell (replaces Waybar, Dunst, Wlogout, polkit_gnome)";

    package = lib.mkOption {
      type = lib.types.package;
      default = dankMaterialShell.packages.${pkgs.system}.default;
      description = "The DankMaterialShell package";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;

      enableSystemMonitoring = true;
      enableDynamicTheming = false; # Disabled: matugen overrides Catppuccin Mocha (our global theme)
      enableAudioWavelength = true;
      enableCalendarEvents = false;

      # SystemNix DMS plugins — declaratively installed via DMS's plugin system.
      # Each plugin's src points to its directory in pkgs/dms-plugins/.
      # Port values are templated from lib/ports.nix — never hardcoded.
      plugins = {
        systemnix-ollama = {
          src = ../../../pkgs/dms-plugins/systemnix-ollama;
          settings = {
            apiBase = "http://127.0.0.1:${toString ports.ollama}";
            pollInterval = "5000";
          };
        };
        systemnix-dns-stats = {
          src = ../../../pkgs/dms-plugins/systemnix-dns-stats;
          settings.statsUrl = "http://127.0.0.1:${toString ports.dns-blocker-stats}/stats";
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
        systemnix-voice-agent = {
          src = ../../../pkgs/dms-plugins/systemnix-voice-agent;
          settings = {
            whisperUrl = "http://127.0.0.1:${toString ports.whisper}";
            livekitUrl = "http://127.0.0.1:${toString ports.livekit}";
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
          settings.crmUrl = "http://127.0.0.1:${toString ports.twenty}";
        };
        systemnix-dual-wan = {
          src = ../../../pkgs/dms-plugins/systemnix-dual-wan;
          settings = {};
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
      };
    };

    # DMS handles its own systemd service via the upstream HM module.
    # The upstream module binds to config.wayland.systemd.target which
    # niri-flake sets to niri.service — so the shell starts with niri.
    systemd.user.services.dms.Service.Environment = [
      # matugen package is removed (enableDynamicTheming = false), but DMS still
      # probes `which matugen` and logs warnings. This env var makes DMS skip the
      # probe entirely (Theme.qml:143). Catppuccin Mocha is our global theme.
      "DMS_DISABLE_MATUGEN=1"
    ];
  };
}
