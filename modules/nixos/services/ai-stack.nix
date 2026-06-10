# AI stack: Ollama ROCm inference, llama.cpp, AI tooling
_: {
  flake.nixosModules.ai-stack = {
    pkgs,
    config,
    lib,
    ...
  }: let
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) harden serviceDefaults ports;
    inherit (config.users) primaryUser;

    rocm = libHelpers.rocm {inherit pkgs;};
    rocmEnv = rocm.env;

    llama-cpp-rocwmma =
      (pkgs.llama-cpp.override {
        rocmSupport = true;
      }).overrideAttrs (finalAttrs: {
        cmakeFlags =
          finalAttrs.cmakeFlags
          ++ [
            "-DGGML_HIP_MMQ_MFMA=ON"
          ];
      });

    cfg = config.services.ai-stack;
    aiPaths = config.services.ai-models.paths;
  in {
    options.services.ai-stack = {
      enable =
        lib.mkEnableOption "AI inference stack — Ollama ROCm, llama.cpp, gpu-python, AI tooling"
        // {default = false;};
    };

    config = lib.mkIf cfg.enable {
      security.pam.loginLimits = [
        {
          domain = "*";
          type = "hard";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "*";
          type = "soft";
          item = "memlock";
          value = "unlimited";
        }
      ];

      services.ollama = {
        enable = true;
        package = pkgs.ollama-rocm;
        home = aiPaths.ollama;
        models = aiPaths.ollama-models;
        host = "127.0.0.1";
        port = ports.ollama;
        environmentVariables =
          rocmEnv
          // {
            OLLAMA_FLASH_ATTENTION = "1";
            OLLAMA_NUM_PARALLEL = "2";
            OLLAMA_KV_CACHE_TYPE = "q8_0";
            OLLAMA_KEEP_ALIVE = "1h";
            OLLAMA_MAX_LOADED_MODELS = "1";
            OLLAMA_GPU_OVERHEAD = "8589934592";
            PYTORCH_CUDA_ALLOC_CONF = "per_process_memory_fraction:0.45";
          };
      };

      systemd.services.ollama = {
        wantedBy = lib.mkForce [];
        startLimitBurst = 5;
        startLimitIntervalSec = 300;
        serviceConfig =
          {
            DynamicUser = lib.mkForce false;
            User = primaryUser;
            Group = "users";
            SupplementaryGroups = ["render"];
            UMask = lib.mkForce "0007";
            OOMScoreAdjust = 500;
          }
          // serviceDefaults {}
          // harden {
            MemoryMax = "32G";
            ProtectHome = false;
            NoNewPrivileges = false;
          };
      };

      environment.systemPackages = with pkgs; [
        llama-cpp-rocwmma
        tesseract5
        poppler-utils
        jupyter
        python313
        (pkgs.writeShellApplication {
          name = "gpu-python";
          text = ''
            exec env \
              PYTORCH_CUDA_ALLOC_CONF="per_process_memory_fraction:''${GPU_MEM_FRACTION:-0.95}" \
              HSA_OVERRIDE_GFX_VERSION=${rocm.env.HSA_OVERRIDE_GFX_VERSION} \
              HSA_ENABLE_SDMA=${rocm.env.HSA_ENABLE_SDMA} \
              LD_LIBRARY_PATH="${rocm.makeLdLibraryPath lib}" \
              "''${@}"
          '';
        })
      ];

      environment.sessionVariables = {
        OLLAMA_HOST = "127.0.0.1:${toString ports.ollama}";
      };
    };
  };
}
