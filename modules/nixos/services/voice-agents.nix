# Voice agents: LiveKit real-time communication + Whisper ASR (ROCm)
_: {
  flake.nixosModules.voice-agents = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.networking) domain;
    cfg = config.services.voice-agents;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;
    inherit (import ../../../lib/docker.nix {inherit pkgs lib harden serviceDefaults;}) mkDockerService;

    whisperModelsDir = config.services.ai-models.paths.whisper;

    whisperImage = "beecave/insanely-fast-whisper-rocm@sha256:1fa17f91846d30748751089a7ef37b490a8e3ec46e8ba4a1df15c28d1e60d3c1";

    whisperComposeFile = pkgs.writeText "docker-compose.whisper-asr.yml" ''
      name: voice-agents

      services:
        whisper-rocm:
          image: ${whisperImage}
          container_name: whisper-asr
          restart: unless-stopped
          command: app.py
          ports:
            - '${toString cfg.whisperPort}:7860'
          environment:
            - MODEL=${cfg.whisperModel}
            - HSA_OVERRIDE_GFX_VERSION=11.5.1
          volumes:
            - ${whisperModelsDir}:/root/.cache/huggingface
          devices:
            - /dev/dri:/dev/dri
            - /dev/kfd:/dev/kfd
    '';

    docker = mkDockerService {
      name = "whisper-asr";
      composeFile = whisperComposeFile;
      stateDir = "/var/lib/whisper-asr";
      memoryMax = "8G";
      extraHarden = {
        ProtectHome = "read-only";
        RestrictNamespaces = lib.mkForce false;
        NoNewPrivileges = lib.mkForce false;
      };
      extraServiceConfig = {
        RestartSec = "10s";
        SupplementaryGroups = ["docker"];
      };
      imagePull = whisperImage;
    };
  in {
    options.services.voice-agents = {
      enable = lib.mkEnableOption "Voice agents (LiveKit + Whisper ASR)";

      domain = lib.mkOption {
        type = lib.types.str;
        default = domain;
        description = "Domain for voice agent services";
      };

      whisperModel = lib.mkOption {
        type = lib.types.str;
        default = "openai/whisper-large-v3";
        description = "Whisper model to use";
      };

      whisperPort = serviceTypes.servicePort 7860 "Port for Whisper ASR Gradio WebUI";

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall ports for external access";
      };
    };

    config = lib.mkIf cfg.enable {
      sops.templates."livekit-keys.env" = {
        content = ''
          ${config.sops.placeholder.livekit_keys}
        '';
      };

      services.livekit = {
        enable = true;
        keyFile = config.sops.templates."livekit-keys.env".path;
        settings = {
          port = 7880;
          rtc = {
            port_range_start = 50000;
            port_range_end = 51000;
            use_external_ip = false;
          };
        };
      };

      systemd = {
        services = docker.services;
      };

      networking.firewall = lib.mkIf cfg.openFirewall {
        allowedTCPPorts = [
          7880
          cfg.whisperPort
        ];
        allowedUDPPortRanges = [
          {
            from = 50000;
            to = 51000;
          }
        ];
      };

      services.caddy.virtualHosts = {
        "voice.${cfg.domain}" = {
          extraConfig = ''
            reverse_proxy localhost:7880
          '';
        };
        "whisper.${cfg.domain}" = {
          extraConfig = ''
            reverse_proxy localhost:${toString cfg.whisperPort}
          '';
        };
      };
    };
  };
}
