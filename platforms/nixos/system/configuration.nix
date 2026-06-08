{
  config,
  pkgs,
  nix-ssh-config,
  lib,
  ...
}: let
  inherit (import ../../../lib/default.nix lib) ports;
  theme = import ../../common/theme.nix;
in {
  imports = [
    # Import common packages shared with macOS
    ../../common/packages/base.nix
    ../../common/packages/fonts.nix
    ../../common/color-scheme.nix
    # Include hardware configuration - essential for NixOS to boot
    ../hardware/hardware-configuration.nix
    # ESSENTIAL MODULES FOR FUNCTIONAL DESKTOP
    ./boot.nix
    ./networking.nix
    ./local-network.nix
    ./primary-user.nix
    ./dns-blocker-config.nix # DNS blocker with unbound + block page (replaces Technitium)
    ./snapshots.nix # BTRFS snapshots with btrbk
    ./scheduled-tasks.nix # Daily scheduled tasks (crush update-providers, etc.)
    ./sudo.nix # Passwordless sudo for wheel group
    ../hardware/amd-gpu.nix
    ../hardware/amd-npu.nix
    ../hardware/bluetooth.nix
    ../../common/nix-settings.nix
  ];

  # Wrap all configuration in config attribute
  config = {
    # dnsblockd CA is trusted via security.pki.certificates in the dns-blocker module

    # Fix for Home Manager + xdg.portal integration
    environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];

    # XDG Desktop Portal for app integration and dark mode preference
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
      config = {
        common.default = ["niri" "gtk"];
      };
    };

    systemd = {
      # Portal-gtk must wait for niri compositor to be ready, otherwise it races
      # during live activation (nh os test/switch) when both are restarted simultaneously
      user.units."xdg-desktop-portal-gtk.service.d/after-niri.conf" = {
        text = ''
          [Unit]
          After=niri.service
        '';
      };

      # Home Manager activation can fail transiently during live system activation
      # (nix profile lock, file-in-use conflicts). Retry up to 3 times with 5s delay.
      services.home-manager-lars = {
        startLimitBurst = 3;
        startLimitIntervalSec = 30;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      tmpfiles.rules = [
        "L+ /var/lib/AccountsService/icons/${config.users.primaryUser} - - - - ${../../../assets/avatar.png}"
      ];
    };

    # Boot configuration is now handled by ./boot.nix module
    # which provides systemd-boot with proper nvme and Ryzen AI Max+ support

    # User account
    users.users.lars = {
      isNormalUser = true;
      description = "Lars";
      extraGroups = ["networkmanager" "wheel" "docker" "input" "video" "audio" "i2c" "render"];
      # INFO: Set password manually with `passwd lars` after installation
      # NOTE: After SSH hardening, password auth will be disabled - you MUST set up SSH keys
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        nix-ssh-config.sshKeys.lars
      ];
      packages = with pkgs; [
        firefox
        obs-studio
      ];
    };

    # AccountsService avatar for SDDM login/lock screen
    services.accounts-daemon.enable = true;

    # Ensure Home Manager profile directory exists
    # This is required for home-manager.useUserPackages = true to work properly
    system.activationScripts.home-manager-profile-dirs = ''
      mkdir -p /nix/var/nix/profiles/per-user/${config.users.primaryUser}
      chown ${config.users.primaryUser}:users /nix/var/nix/profiles/per-user/${config.users.primaryUser}
    '';

    programs.obs-studio = {
      enable = true;
      enableVirtualCamera = true;
    };

    # Enable Fish shell system-wide
    programs.fish.enable = true;

    # Dozzle — Docker container log tailing at logs.home.lan
    # Inline config (not module) to avoid nix flake check eval issue
    virtualisation.oci-containers.containers.dozzle = {
      autoStart = true;
      image = "amir20/dozzle:latest";
      ports = ["127.0.0.1:${toString ports.dozzle}:8080"];
      volumes = ["/var/run/docker.sock:/var/run/docker.sock:ro"];
      environment = {
        DOZZLE_TAILSIZE = "300";
        DOZZLE_FILTER = "status=running";
      };
    };

    # EMEET PIXY webcam auto-activation
    hardware.emeet-pixy = {
      enable = true;
      auto = "tracking-only";
      defaultAudio = "nc";
      user = "lars";
    };

    # AMD GPU Support - imported from hardware module
    #
    # Font configuration (cross-platform)
    # Note: Font packages are now imported from common/packages/fonts.nix
    # to avoid duplication across platforms
    # System packages for audio/video codec support
    environment.systemPackages = with pkgs; [
      libopus # Opus audio codec for Discord voice support
    ];

    fonts.fontconfig.defaultFonts = {
      monospace = [theme.font.mono "Noto Sans Mono"];
      sansSerif = ["DejaVu Sans" "Noto Sans"];
      serif = ["DejaVu Serif" "Noto Serif"];
      emoji = ["Noto Color Emoji"];
    };

    # Experimental features
    # Note: Nix settings now imported from common/core/nix-settings.nix

    # System state version
    system.stateVersion = "25.11";

    services = {
      udisks2.enable = true;
      sops-config.enable = true;
      caddy.enable = true;
      forgejo.enable = true;
      immich.enable = true;
      pocket-id-config.enable = true;
      oauth2-proxy-config.enable = true;
      # photomap — disabled: podman config permission issue
      # photomap.enable = true;
      homepage.enable = true;
      taskchampion-config.enable = true;
      display-manager-config.enable = true;
      audio-config.enable = true;
      niri-desktop.enable = true;
      niri-session-manager.enable = true;
      security-hardening.enable = true;
      gatus-config.enable = true;
      multi-wm.enable = true;
      browser-policies.enable = true;
      steam-config.enable = true;

      # Manifest — Smart LLM router for AI agents (cost optimization)
      manifest = {
        enable = true;
      };

      # Disk usage monitoring with desktop notifications at thresholds
      disk-monitor = {
        enable = true;
      };

      # NVMe SSD health monitoring with desktop notifications for critical events
      nvme-health-monitor = {
        enable = true;
      };

      # OpenSEO — self-hosted SEO suite (rank tracking, keyword research, backlinks)
      openseo.enable = true;

      # Dual-WAN with MPTCP and route health monitoring
      dual-wan.enable = true;

      # Centralized AI model storage (/data/ai/)
      ai-models.enable = true;

      # AI inference stack — Ollama ROCm, llama.cpp, gpu-python
      ai-stack.enable = true;

      # AI-powered screenshot renaming watcher
      # TEMPORARILY DISABLED: charm.land/fantasy@v0.25.0 requires Go 1.26.3, nixpkgs-unstable has 1.26.2
      file-and-image-renamer = {
        enable = false;
        watchPaths = [
          "/home/${config.users.primaryUser}/Downloads"
          "/home/${config.users.primaryUser}/Pictures"
        ];
        syntheticModel = "syn:small:vision";
        syntheticApiKeyFile = "/home/${config.users.primaryUser}/.synthetic_api_key";
      };

      libinput = {
        enable = true;
        mouse = {
          accelProfile = "flat";
        };
        touchpad = {
          tapping = true;
          naturalScrolling = true;
          disableWhileTyping = true;
          clickMethod = "clickfinger";
        };
      };

      fstrim.enable = true;

      signoz = {
        enable = true;
      };

      twenty = {
        enable = true;
      };

      # Voice agents (LiveKit + Whisper ASR)
      voice-agents = {
        enable = false;
      };

      # Hermes AI Agent Gateway (Discord, cron jobs, messaging)
      hermes = {
        enable = true;
      };

      # Crush Daily — AI-powered development insights from Crush databases
      crush-daily = {
        enable = true;
        environmentFile = config.sops.templates."crush-daily-env".path;
      };

      # Minecraft server (local network only, whitelisted)
      minecraft = {
        enable = false;
        whitelist = {
          LartyHD = "8c9ec1ab-f64f-4003-9110-f98a1f0d7f47";
        };
        client = {
          enable = true;
          fov = 100;
          guiScale = 4;
          gamma = 1.0;
          sound = {
            master = 60;
            music = 50;
            noteBlocks = 75;
            weather = 30;
            hostile = 60;
            ambient = 60;
            voice = 60;
          };
        };
      };

      # Monitor365 device monitoring agent + server (single-machine deployment)
      monitor365 = {
        enable = true;
        # Disable expensive collectors (screenshot, camera, photo, keystroke logging)
        collectors = {
          screenshot = lib.mkDefault false;
          camera = lib.mkDefault false;
          keystroke = lib.mkDefault false;
          mouse = lib.mkDefault false;
          clipboard = lib.mkDefault false;
          notifications = lib.mkDefault false;
        };
        logging.level = lib.mkDefault "warn";
        # Agent syncs to local server
        cloud.endpoint = lib.mkDefault "http://localhost:3001";
        # Server (dashboard + API) runs on the same machine
        server = {
          enable = lib.mkDefault true;
          listenAddr = lib.mkDefault "0.0.0.0:3001";
          corsOrigins = lib.mkDefault ["http://localhost:3001"];
        };
      };

      smartd = {
        enable = true;
        autodetect = true;
        defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03)";
      };

      # SSH server with hardening (from nix-ssh-config)
      ssh-server = {
        enable = true;
        allowUsers = [config.users.primaryUser];
        passwordAuthentication = false;
        allowRootLogin = false;
        authorizedKeys = [nix-ssh-config.sshKeys.lars];
      };

      # Declarative Forgejo repository mirroring
      forgejo-repos = {
        enable = true;
        repos = [
          "git@github.com:LarsArtmann/dnsblockd.git"
          "git@github.com:LarsArtmann/BuildFlow.git"
        ];
        autoSync = true;
      };

      # Auto-commit daemon: watches ~/projects, AI-generates commit messages via MiniMax
      projects-management-automation = {
        enable = true;
        paths = ["/home/${config.users.primaryUser}/projects"];
        excludePaths = [
          "/home/${config.users.primaryUser}/projects/forks"
          "/home/${config.users.primaryUser}/projects/archived"
        ];
        autoPush = false;
        debounceSeconds = 10;
        minCommitIntervalSeconds = 60;
      };
    };
  };
}
