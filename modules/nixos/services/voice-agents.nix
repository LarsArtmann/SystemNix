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
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) serviceTypes ports images;
    inherit (libHelpers.mkDockerServiceFactory {inherit pkgs;}) mkDockerService;

    rocm = libHelpers.rocm {inherit pkgs;};

    whisperModelsDir = config.services.ai-models.paths.whisper;

    whisperImage = images.whisper-rocm.ref;

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
            - HSA_OVERRIDE_GFX_VERSION=${rocm.env.HSA_OVERRIDE_GFX_VERSION}
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

      whisperPort = serviceTypes.servicePort ports.whisper "Port for Whisper ASR Gradio WebUI";

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
          port = ports.livekit;
          rtc = {
            port_range_start = ports.livekit-udp-start;
            port_range_end = ports.livekit-udp-end;
            use_external_ip = false;
          };
        };
      };

      systemd = {
        services = docker.services;
        tmpfiles.rules = docker.tmpfiles;
      };

      networking.firewall = lib.mkIf cfg.openFirewall {
        allowedTCPPorts = [
          ports.livekit
          cfg.whisperPort
        ];
        allowedUDPPortRanges = [
          {
            from = ports.livekit-udp-start;
            to = ports.livekit-udp-end;
          }
        ];
      };
    };
  };
}
