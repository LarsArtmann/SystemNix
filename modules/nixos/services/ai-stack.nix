# AI stack: Ollama ROCm inference, llama.cpp, AI tooling
_: {
  flake.nixosModules.ai-stack =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        serviceDefaults
        ports
        ioTier
        ;
      inherit (config.users) primaryUser;

      rocm = libHelpers.rocm { inherit pkgs; };
      rocmEnv = rocm.env;

      # ============================================================================
      # IMPORTANT: Do NOT add overrideAttrs with -DGGML_HIP_MMQ_MFMA=ON here.
      # It is a NO-OP on RDNA 3.5 (gfx1150 / Strix Halo) and only changes the
      # store hash, defeating binary caching for a ~30 min source build every time.
      #
      # Why it's a no-op:
      #   1. GGML_HIP_MMQ_MFMA defaults to ON in upstream CMake already.
      #   2. It only controls CDNA (MI100/200/300/350 datacenter GPUs), NOT RDNA.
      #   3. Strix Halo (gfx1150) is RDNA 3.5 — uses WMMA (always enabled via
      #      compiler builtins __gfx1150__), NOT MFMA. The MFMA code paths are
      #      compiled out by the architecture guard `#if defined(CDNA)`.
      #   4. nixpkgs does not pass -DGGML_HIP_MMQ_MFMA=OFF, so the upstream
      #      default (ON) already applies — no override needed.
      #
      # Adding the flag previously caused 30+ minutes of unnecessary local builds
      # on EVERY nixpkgs bump because the changed derivation hash never matches
      # cache.nixos.org. Removed 2026-08-02 after verifying the flag has zero
      # effect on this hardware.
      # ============================================================================
      llama-cpp-rocwmma = pkgs.llama-cpp.override { rocmSupport = true; };

      cfg = config.services.ai-stack;
      aiPaths = config.services.ai-models.paths;
    in
    {
      options.services.ai-stack = {
        enable =
          lib.mkEnableOption "AI inference stack — Ollama ROCm, llama.cpp, gpu-python, AI tooling"
          // {
            default = false;
          };
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
          modelsDir = aiPaths.ollama-models;
          host = "127.0.0.1";
          port = ports.ollama;
          environmentVariables = rocmEnv // {
            OLLAMA_FLASH_ATTENTION = "1";
            OLLAMA_NUM_PARALLEL = "2";
            OLLAMA_KV_CACHE_TYPE = "q8_0";
            OLLAMA_KEEP_ALIVE = "1h";
            OLLAMA_MAX_LOADED_MODELS = "1";
            OLLAMA_GPU_OVERHEAD = "1073741824";
            PYTORCH_CUDA_ALLOC_CONF = "per_process_memory_fraction:0.45";
          };
        };

        systemd.services.ollama = {
          # Let nixpkgs' default WantedBy=multi-user.target apply. The prior
          # `wantedBy = lib.mkForce []` suppressed it, making an enabled service
          # silently never start — every deploy left ollama dead with no log
          # entries, a pure split-brain against the Gatus check that expects it.
          # Models still unload after OLLAMA_KEEP_ALIVE; the service stays up so
          # /api/tags is always reachable.
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              DynamicUser = lib.mkForce false;
              User = primaryUser;
              Group = "users";
              SupplementaryGroups = [ "render" ];
              UMask = lib.mkForce "0007";
              OOMScoreAdjust = 500;
            }
            (serviceDefaults { })
            (harden {
              MemoryMax = "32G";
              CPUQuota = "400%"; # Model loading (GGUF quantization) is multi-threaded
              ProtectHome = false;
              NoNewPrivileges = false;
            })
            ioTier.background
          ];
        };

        environment.systemPackages = [
          llama-cpp-rocwmma
          pkgs.tesseract5
          pkgs.poppler-utils
          pkgs.jupyter
          pkgs.python313
          (pkgs.writeShellApplication {
            name = "gpu-python";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              exec env \
                PYTORCH_CUDA_ALLOC_CONF="per_process_memory_fraction:''${GPU_MEM_FRACTION:-0.95}" \
                HSA_OVERRIDE_GFX_VERSION=${rocm.env.HSA_OVERRIDE_GFX_VERSION} \
                HSA_ENABLE_SDMA=${rocm.env.HSA_ENABLE_SDMA} \
                LD_LIBRARY_PATH="${rocm.makeLdLibraryPath lib}" \
                "''${@}"
            '';
          })
          # Wrapper that bakes in LD_LIBRARY_PATH for ROCm runtime libs so the
          # standalone llama.cpp server uses the dedicated VRAM (18 GiB BIOS
          # carveout) on Strix Halo. Without this + the session-level HSA env
          # vars below, llama-server cannot detect gfx1150 and falls back to
          # CPU — zero VRAM usage, model loaded into GTT/system RAM instead.
          (pkgs.writeShellApplication {
            name = "llama-server-rocm";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              exec env \
                LD_LIBRARY_PATH="${rocm.makeLdLibraryPath lib}" \
                ${lib.getExe' llama-cpp-rocwmma "llama-server"} \
                "''${@}"
            '';
          })
        ];

        # ROCm compute env vars at session level so ANY ROCm application
        # (llama-server, hipblas-bench, custom HIP code) launched from an
        # interactive shell detects the gfx1150 GPU. Without HSA_OVERRIDE_GFX_VERSION,
        # ROCm does not officially support gfx1150 (RDNA 3.5 / Strix Halo) and
        # silently falls back to CPU — the 18 GiB VRAM carveout stays unused.
        # HSA_ENABLE_SDMA=0 avoids SDMA hang bugs on gfx11 APUs.
        environment.sessionVariables = rocmEnv // {
          OLLAMA_HOST = "127.0.0.1:${toString ports.ollama}";
        };
      };
    };
}
