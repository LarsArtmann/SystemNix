# Voice agents: LiveKit real-time communication + Whisper ASR (ROCm)
_: {
  flake.nixosModules.voice-agents =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (config.networking) domain;
      cfg = config.services.voice-agents;
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers) serviceTypes ports images;
      inherit (libHelpers.mkDockerServiceFactory { inherit pkgs; }) mkDockerService;

      rocm = libHelpers.rocm { inherit pkgs; };

      whisperModelsDir = config.services.ai-models.paths.whisper;

      whisperImage = images.whisper-rocm.ref;

      whisperComposeFile = pkgs.writeText "docker-compose.whisper-asr.yml" (
        builtins.toJSON {
          name = "voice-agents";
          services.whisper-rocm = {
            image = whisperImage;
            container_name = "whisper-asr";
            restart = "unless-stopped";
            command = "app.py";
            ports = [ "${toString cfg.whisperPort}:7860" ];
            environment = {
              MODEL = cfg.whisperModel;
              HSA_OVERRIDE_GFX_VERSION = rocm.env.HSA_OVERRIDE_GFX_VERSION;
            };
            volumes = [ "${whisperModelsDir}:/root/.cache/huggingface" ];
            devices = [
              "/dev/dri:/dev/dri"
              "/dev/kfd:/dev/kfd"
            ];
          };
        }
      );

      docker = mkDockerService {
        name = "whisper-asr";
        composeFile = whisperComposeFile;
        stateDir = "/var/lib/whisper-asr";
        memoryMax = "8G";
        extraHarden = {
          ProtectHome = "read-only";
          RestrictNamespaces = lib.mkForce false;
          NoNewPrivileges = lib.mkForce false;
          CPUQuota = "300%";
        };
        extraServiceConfig = {
          RestartSec = "10s";
          SupplementaryGroups = [ "docker" ];
        };
        imagePull = whisperImage;
      };
    in
    {
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
          inherit (docker) services;
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

        # Service-integration registry entries: the Whisper ASR + LiveKit
        # Gatus checks and their homepage tiles. The voice/whisper vHosts
        # STAY hand-written in caddy.nix (the subdomains are not in the
        # shared dns-local list — voice-agents is not enabled on any current
        # host). Replaces rows in gatus-config.nix / homepage.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          livekit = {
            enable = cfg.enable;
            vHost.layer = "none";
            checks = [
              {
                name = "LiveKit";
                group = "AI";
                url = "tcp://127.0.0.1:${toString config.services.livekit.settings.port}";
                interval = "60s";
                conditions = [ "[CONNECTED] == true" ];
                alert = "";
              }
            ];
            homepage = {
              name = "LiveKit";
              group = "AI";
              href = "https://voice.${domain}";
              description = "Real-Time Voice Infrastructure";
              icon = "voip-info.png";
            };
          };
          whisper = {
            enable = cfg.enable;
            vHost.layer = "none";
            checks = [
              {
                name = "Whisper ASR";
                group = "AI";
                url = "http://localhost:${toString cfg.whisperPort}";
                interval = "60s";
                alert = "";
              }
            ];
            homepage = {
              name = "Whisper ASR";
              group = "AI";
              href = "https://whisper.${domain}";
              description = "Speech-to-Text (Gradio)";
              icon = "web-whisper.png";
            };
          };
        };
      };
    };
}
