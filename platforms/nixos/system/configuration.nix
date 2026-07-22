{
  config,
  pkgs,
  nix-ssh-config,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) ports;
  theme = import ../../common/theme.nix;
in
{
  imports = [
    # Import common packages shared with macOS
    ../../common/packages/base.nix
    ../../common/packages/fonts.nix
    ../../common/locale.nix
    # Include hardware configuration - essential for NixOS to boot
    ../hardware/hardware-configuration.nix
    # ESSENTIAL MODULES FOR FUNCTIONAL DESKTOP
    ./boot.nix
    ./networking.nix
    ./local-network.nix
    ./primary-user.nix
    ./dns-blocker-config.nix # DNS blocker: dnsblockd embedded resolver + block page
    ./snapshots.nix # BTRFS snapshots with btrbk
    ./btrfs-health.nix # BTRFS chunk allocation health monitor + GC guard (prevents 2026-06-26 crash)
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
    environment.pathsToLink = [
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];

    # XDG Desktop Portal for app integration and dark mode preference
    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common.default = [
          "niri"
          "gnome"
          "gtk"
        ];
      };
    };

    security.wrappers.fusermount3 = {
      source = "${pkgs.fuse3}/bin/fusermount3";
      owner = "root";
      group = "root";
      setuid = true;
    };

    systemd = {
      # Portal services must wait for niri compositor to be ready, otherwise they race
      # during live activation (nh os test/switch) when both are restarted simultaneously
      user.units."xdg-desktop-portal-gtk.service.d/after-niri.conf" = {
        text = ''
          [Unit]
          After=niri.service
        '';
      };
      user.units."xdg-desktop-portal-gnome.service.d/after-niri.conf" = {
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
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "input"
        "video"
        "audio"
        "i2c"
        "render"
        "lp"
        "scanner"
      ];
      # INFO: Set password manually with `passwd lars` after installation
      # NOTE: After SSH hardening, password auth will be disabled - you MUST set up SSH keys
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        nix-ssh-config.sshKeys.lars
      ];
      packages = [
        pkgs.firefox
        pkgs.obs-studio
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
    # Backend set to docker to avoid running Podman alongside Docker
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.dozzle = {
      autoStart = true;
      image = "amir20/dozzle:latest";
      ports = [ "127.0.0.1:${toString ports.dozzle}:8080" ];
      volumes = [ "/var/run/docker.sock:/var/run/docker.sock:ro" ];
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
    environment.systemPackages = [
      pkgs.libopus # Opus audio codec for Discord voice support
    ];

    fonts.fontconfig.defaultFonts = {
      monospace = [
        theme.font.mono
        "Noto Sans Mono"
      ];
      sansSerif = [
        "DejaVu Sans"
        "Noto Sans"
      ];
      serif = [
        "DejaVu Serif"
        "Noto Serif"
      ];
      emoji = [ "Noto Color Emoji" ];
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
      pocket-id-config = {
        enable = true;
        provision = {
          enable = true;
          adminUser = {
            username = "lars";
            email = "lars@larsartmann.cloud";
            firstName = "Lars";
            lastName = "Artmann";
          };
        };
      };
      oauth2-proxy-config.enable = true;
      homepage.enable = true;
      taskchampion-config.enable = true;
      display-manager-config.enable = true;
      audio-config.enable = true;
      niri-desktop.enable = true;
      niri-session-manager.enable = true;
      security-hardening.enable = true;
      gatus-config.enable = true;
      multi-wm.enable = true;
      browser-policies = {
        enable = true;
        chromiumExtensions =
          let
            ext = id: name: { inherit id name; };
          in
          [
            # Privacy / Content Blocking
            (ext "cjpalhdlnbpafiamejdnhcphjbkeiagm" "uBlock Origin")
            # Productivity
            (ext "chphlpgkkbolifaimnlloiipkdnihall" "OneTab")
            # Time Tracking
            (ext "nglaklhklhcoonedhgnpgddginnjdadi" "ActivityWatch Web Watcher")
            # Email
            (ext "oeopbcgkkoapgobdbedcemjljbihmemj" "Checker Plus for Gmail")
            # YouTube
            (ext "ckagfhpboagdopichicnebandlofghbc" "YouTube Shorts Blocker")
            (ext "bbeaicapbccfllodepmimpkgecanonai" "BlockTube")
            (ext "mnjggcdmjocbbbhaepdhchncahnbgone" "SponsorBlock for YouTube")
            (ext "enamippconapkdmgfgjchkhakpfinmaj" "DeArrow - Better Titles and Thumbnails")
            (ext "hdannnflhlmdablckfkjpleikpphncik" "YouTube Playback Speed Control")
            (ext "pgpdaocammeipkkgaeelifgakbhjoiel" "YouTube Full Title For Videos")
            # GitHub
            (ext "hlepfoohegkhhmjieoechaddaejaokhf" "Refined GitHub")
            (ext "nbiddhncecgemgccalnoanpnenalmkic" "GitHub Issue Link Status")
            (ext "ocfdgncpifmegplaglcnglhioflaimkd" "GitHub Better Line Counts")
            (ext "pemednoikdemhakcchcmjlckmepoighb" "GitHub Milestones Timeline")
            (ext "ialbpcipalajnakfondkflpkagbkdoib" "Lovely forks")
            # Development Tools
            (ext "fmkadmapgofadopljbjfkapdkoienihi" "React Developer Tools")
            (ext "jabopobgcpjmedljpbcaablpmlmfcogm" "WhatFont")
            # Translation
            (ext "cofdbpoegempjloogbagkncekinflcnj" "DeepL: translate and write with AI")
            # Social / Content
            (ext "ajkipkkhchaaccpbpkclolpebkgbmodl" "9gag Post Filter")
            (ext "iffnacikcgjlndahdgnckeekdefoafbn" "Reddit Image Opener")
          ];
      };
      steam-config.enable = true;
      discordsync = {
        enable = true; # Discord backup service
        gcsBucket = "discordsync-backup";
      };

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
      # DISABLED: route-health-monitor evicts the eno1 default route on transient
      # ISP probe failures (2s timeout to 1.1.1.1), pinning traffic to WiFi-only.
      dual-wan.enable = false;

      # Mullvad VPN daemon — DISABLED.
      # talpid_dns periodically overwrites /etc/resolv.conf even when disconnected,
      # breaking dnsblockd resolution every ~90s. Re-enable manually only when needed:
      #   mullvad-vpn.enable = true; mullvad dns set custom 192.168.1.150
      mullvad-vpn.enable = false;

      # Centralized AI model storage (/data/ai/)
      ai-models.enable = true;

      # AI inference stack — Ollama ROCm, llama.cpp, gpu-python
      ai-stack.enable = true;

      file-and-image-renamer = {
        enable = true;
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

      gpu-active = {
        enable = true;
      };

      system-health = {
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

      # qmd — on-device markdown hybrid search engine.
      # CLI: `qmd search ...`, `qmd collection add ...`
      # Service: persistent HTTP MCP on localhost:8181 — Crush/clients connect
      # to http://localhost:8181/mcp so embedding/reranker models stay loaded
      # across requests (stdio mode pays 5-15s reload cost per reconnect).
      # CPU-only by default — Vulkan probing is brittle on Strix Halo and
      # competes with Ollama for VRAM. Override `qmdForceCpu = false` to opt in.
      qmd-config = {
        enable = true;
        # Add per-user collections declaratively here if desired:
        # bootstrapCollections = [
        #   { name = "notes"; path = "/home/${config.users.primaryUser}/notes"; pattern = "**/*.md"; context = "Personal notes and ideas"; }
        # ];
      };

      # Overview — local project dashboard (discovers git repos, shows stats/activity)
      overview = {
        enable = true;
        port = ports.overview;
        searchPaths = [ "/home/${config.users.primaryUser}/projects" ];
        logLevel = "info";
        # Daemon architecture: overview delegates all discovery to the
        # project-discovery daemon over the unix socket. It never touches the
        # filesystem directly, so it runs fully unprivileged (no "users" group)
        # and needs only modest memory (~250MB steady state — the daemon pays
        # the 7GB discovery spike, not overview).
        daemonSocket = "unix:///run/project-discovery/daemon.sock";
        memoryMax = "512M";
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

      # Monitor365 unified agent — system + desktop collectors
      # TEMPORARILY DISABLED: upstream wasm_bindgen_test build failure blocks all deploys
      monitor365 = {
        enable = false;
        settings.collectors = {
          # Headless collectors
          network.enabled = lib.mkDefault true;
          battery.enabled = lib.mkDefault true;
          system_info.enabled = lib.mkDefault true;
          process.enabled = lib.mkDefault true;
          location.enabled = lib.mkDefault true;
          fs_event.enabled = lib.mkDefault true;
          # bluetooth disabled (zbus::blocking panics inside tokio)
          bluetooth.enabled = lib.mkDefault false;
          # Desktop collectors (skip gracefully if no graphical session)
          screenshots.enabled = lib.mkDefault true;
          camera = {
            enabled = lib.mkDefault true;
            interval_seconds = lib.mkDefault 3600; # 1h minimum enforced by validation
          };
          keystrokes.enabled = lib.mkDefault true;
          mouse.enabled = lib.mkDefault true;
          clipboard.enabled = lib.mkDefault true;
          notifications.enabled = lib.mkDefault true;
          app_usage.enabled = lib.mkDefault true;
          afk_status.enabled = lib.mkDefault true;
        };
      };

      # Monitor365 server (dashboard + API) runs on the same machine
      # TEMPORARILY DISABLED: upstream wasm_bindgen_test build failure blocks all deploys
      monitor365-server = {
        enable = false;
        # DuckDB is the sole store on local-only BTRFS (#1 data-loss risk).
        # Local nightly backup is the prerequisite for any future offsite sync.
        backup = {
          enable = lib.mkDefault true;
          schedule = lib.mkDefault "*-*-* 03:00:00";
          keep = lib.mkDefault 7;
        };
        bootstrap = {
          tenantName = lib.mkDefault "LarsArtmann";
          adminEmail = lib.mkDefault "lars@larsartmann.cloud";
        };
        sso.enable = lib.mkDefault true;
      };

      smartd = {
        enable = true;
        autodetect = true;
        defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03)";
      };

      # SSH server with hardening (from nix-ssh-config)
      ssh-server = {
        enable = true;
        allowUsers = [ config.users.primaryUser ];
        passwordAuthentication = false;
        allowRootLogin = false;
        authorizedKeys = [ nix-ssh-config.sshKeys.lars ];
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

      # Auto-commit daemon: watches ~/projects, AI-generates commit messages via MiniMax.
      # Also co-locates the project-discovery daemon (shared by overview and other
      # consumers) — the daemon amortizes the ~7GB discovery spike across all
      # consumers instead of each paying it independently. 8G covers the measured
      # peak with headroom; steady state is ~250MB.
      projects-management-automation = {
        enable = true;
        paths = [ "/home/${config.users.primaryUser}/projects" ];
        excludePaths = [
          "/home/${config.users.primaryUser}/projects/forks"
          "/home/${config.users.primaryUser}/projects/archived"
        ];
        autoPush = false;
        debounceSeconds = 60;
        minCommitIntervalSeconds = 120;
        enableDiscoveryDaemon = true;
        memoryMax = "8G";
      };
    };
  };
}
