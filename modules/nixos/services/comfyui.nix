# ComfyUI persistent AI image generation server (ROCm GPU acceleration)
_: {
  flake.nixosModules.comfyui = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.comfyui;
    inherit (config.users) primaryUser;
    userHome = config.users.users.${primaryUser}.home;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;
    rocm = import ../../../lib/rocm.nix {inherit pkgs;};

    rocmRuntimeLibs = rocm.runtimeLibs;

    rocmEnv =
      rocm.env
      // {
        PYTORCH_HIP_ALLOC_CONF = "garbage_collection_threshold:0.6,max_split_size_mb:128,per_process_memory_fraction:0.50";
        TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = "1";
        TORCH_COMPILE_DISABLE = "1";
        PYTHONDONTWRITEBYTECODE = "1";
      };
  in {
    options.services.comfyui = {
      enable = lib.mkEnableOption "ComfyUI — persistent AI image generation server with GPU model caching";

      package = lib.mkOption {
        type = lib.types.str;
        default = "${userHome}/projects/anime-comic-pipeline/ComfyUI";
        description = "Path to ComfyUI installation (mutable directory, not copied to store)";
      };

      venvPython = lib.mkOption {
        type = lib.types.str;
        default = "${userHome}/projects/anime-comic-pipeline/venv/bin/python";
        description = "Path to the Python venv with torch/diffusers installed";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Listen host";
      };

      port = serviceTypes.servicePort 8188 "Listen port";

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User to run ComfyUI as (needs render/video group access for GPU)";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.comfyui = {
        description = "ComfyUI — Persistent AI Image Generation Server";
        onFailure = ["notify-failure@%n.service"];
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        startLimitBurst = 3;
        startLimitIntervalSec = 60;

        environment =
          rocmEnv
          // {
            HOME = "/home/${cfg.user}";
            LD_LIBRARY_PATH = lib.makeLibraryPath rocmRuntimeLibs;
            HF_HOME = config.services.ai-models.paths.huggingface;
          };

        path = with pkgs; [
          git
          python313
        ];

        serviceConfig =
          harden {
            ProtectHome = false;
            ProtectSystem = false;
            MemoryMax = "8G";
            ReadWritePaths = [
              "/home/${cfg.user}"
              "/data/ai"
            ];
          }
          // serviceDefaults {
            RestartSec = "10s";
          }
          // {
            Type = "simple";
            User = cfg.user;
            Group = "users";
            WorkingDirectory = cfg.package;
            ExecCondition = "${pkgs.writeShellScript "comfyui-check-venv" ''
              if [ ! -x "${cfg.venvPython}" ]; then
                echo "comfyui: Python venv not found at ${cfg.venvPython}, skipping startup"
                exit 1
              fi
            ''}";
            ExecStart = "${cfg.venvPython} ${cfg.package}/main.py --listen ${cfg.host} --port ${toString cfg.port} --bf16-unet --bf16-vae --bf16-text-enc";
            OOMScoreAdjust = -100;
            SupplementaryGroups = ["render" "video"];
            TimeoutStartSec = "300";
            TimeoutStopSec = "60";
          };
      };
    };
  };
}
