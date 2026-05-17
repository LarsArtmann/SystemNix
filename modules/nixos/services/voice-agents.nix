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

    whisperModelsDir = config.services.ai-models.paths.whisper;

    # Docker compose for Whisper ASR - Gradio UI mode
    # Image (beecave/insanely-fast-whisper-rocm) provides:
    #   - /app/app.py    → Gradio WebUI (port 7860)
    #   - /app/main.py   → Directory watcher (batch processing)
    #   - insanely-fast-whisper CLI tool
    # ENTRYPOINT is ["python3"], WORKDIR is /app
    # Env var: MODEL (not WHISPER_MODEL) controls which model to load
    whisperComposeFile = pkgs.writeText "docker-compose.whisper-asr.yml" ''
      name: voice-agents

      services:
        whisper-rocm:
          image: beecave/insanely-fast-whisper-rocm@sha256:1fa17f91846d30748751089a7ef37b490a8e3ec46e8ba4a1df15c28d1e60d3c1
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
        services.whisper-asr-pull = {
          description = "Pull Whisper ASR Docker Image";
          after = ["docker.service" "network-online.target"];
          requires = ["docker.service"];
          wants = ["network-online.target"];
          wantedBy = ["whisper-asr.service"];
          path = [pkgs.docker];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.docker}/bin/docker pull beecave/insanely-fast-whisper-rocm@sha256:1fa17f91846d30748751089a7ef37b490a8e3ec46e8ba4a1df15c28d1e60d3c1";
            TimeoutStartSec = 600;
          };
        };

        services.whisper-asr = {
          description = "Whisper ASR Server - Gradio WebUI (ROCm)";
          after = ["docker.service" "network-online.target" "whisper-asr-pull.service"];
          requires = ["docker.service"];
          wants = ["whisper-asr-pull.service" "network-online.target"];
          wantedBy = ["multi-user.target"];
          startLimitBurst = 3;
          startLimitIntervalSec = 60;
          path = [pkgs.docker pkgs.docker-compose];
          serviceConfig =
            harden {}
            // serviceDefaults {
              RestartSec = "10s";
            }
            // {
              Type = "forking";
              RemainAfterExit = true;
              ExecStartPre = ["-${pkgs.docker-compose}/bin/docker-compose -f ${whisperComposeFile} down --remove-orphans"];
              ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${whisperComposeFile} up -d whisper-rocm";
              ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${whisperComposeFile} down whisper-rocm";
              TimeoutStartSec = 180;
            };
        };
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
