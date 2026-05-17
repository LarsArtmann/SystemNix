# AI stack: Ollama ROCm inference, llama.cpp, Unsloth Studio, AI tooling
_: {
  flake.nixosModules.ai-stack = {
    pkgs,
    config,
    lib,
    ...
  }: let
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults mkStateDir;
    inherit (config.users) primaryUser;
    primaryGroup = "users";

    inherit (pkgs.rocmPackages) rocwmma;

    rocm = import ../../../lib/rocm.nix {inherit pkgs;};
    rocmEnv = rocm.env;
    rocmRuntimeLibs = rocm.runtimeLibs;

    llama-cpp-rocwmma =
      (pkgs.llama-cpp.override {
        rocmSupport = true;
      }).overrideAttrs (finalAttrs: {
        buildInputs =
          finalAttrs.buildInputs
          ++ [rocwmma];
        cmakeFlags =
          finalAttrs.cmakeFlags
          ++ [
            "-DGGML_HIP_ROCWMMA_FATTN=ON"
            "-DGGML_HIP_MMQ_MFMA=ON"
          ];
        postPatch =
          (finalAttrs.postPatch or "")
          + ''
            sed -i '/target_link_libraries(ggml-hip PRIVATE/a\  target_include_directories(ggml-hip SYSTEM PRIVATE ${rocwmma}/include)' \
              ggml/src/ggml-hip/CMakeLists.txt
          '';
      });

    aiPaths = config.services.ai-models.paths;
    unslothDataDir = aiPaths.unsloth;
    venvPython = "${unslothDataDir}/venv/bin/python";
    venvPip = "${unslothDataDir}/venv/bin/pip";
    sitePkgs = "${unslothDataDir}/venv/lib/python3.13/site-packages";
    studioBackend = "${sitePkgs}/studio/backend";
    studioFrontend = "${sitePkgs}/studio/frontend";
    studioReq = "${studioBackend}/requirements";
    setupDone = "${unslothDataDir}/.studio-setup-done";

    cfg = config.services.unslothStudio;
  in {
    options = {
      services.unslothStudio.enable =
        lib.mkEnableOption "Unsloth Studio - AI Model Training & Inference UI"
        // {
          default = false;
        };
    };

    config = lib.mkMerge [
      # Always-on config
      {
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
          port = 11434;
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

        systemd.services = {
          ollama.serviceConfig =
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
          (pkgs.writeShellScriptBin "gpu-python" ''
            exec env \
              PYTORCH_CUDA_ALLOC_CONF="per_process_memory_fraction:''${GPU_MEM_FRACTION:-0.95}" \
              HSA_OVERRIDE_GFX_VERSION=11.5.1 \
              HSA_ENABLE_SDMA=0 \
              LD_LIBRARY_PATH="${rocm.makeLdLibraryPath lib}" \
              "''${@}"
          '')
        ];

        environment.sessionVariables = {
          OLLAMA_HOST = "127.0.0.1:11434";
        };
      }

      # Conditional: Unsloth Studio
      (lib.mkIf cfg.enable {
        systemd.services = {
          unsloth-setup = {
            description = "Unsloth Studio - First-time setup (non-blocking)";
            after = [];
            wants = [];
            wantedBy = ["unsloth-studio.service"];
            path = with pkgs; [
              python313
              git
              gcc
              gnumake
              cmake
              ninja
              cacert
              pnpm
              coreutils
              bash
            ];
            environment = {
              HOME = unslothDataDir;
              PYTHONDONTWRITEBYTECODE = "1";
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "unsloth-setup" ''
                set -euo pipefail

                if [ ! -f ${venvPython} ]; then
                  echo "Creating Python venv..."
                  ${pkgs.python313}/bin/python -m venv ${unslothDataDir}/venv
                  ${venvPip} install --no-cache-dir --upgrade pip setuptools wheel
                  echo "Installing PyTorch ROCm 6.3 (~4.9GB)..."
                  ${venvPip} install --no-cache-dir \
                    torch torchvision torchaudio \
                    --index-url https://download.pytorch.org/whl/rocm6.3
                  echo "Installing unsloth[amd]..."
                  ${venvPip} install --no-cache-dir \
                    "unsloth[amd] @ git+https://github.com/unslothai/unsloth"
                  echo "CLI install complete."
                fi

                if [ -f ${setupDone} ]; then
                  echo "Studio setup already complete, skipping."
                  exit 0
                fi

                echo "Installing studio Python dependencies..."
                ${venvPip} install --no-cache-dir structlog
                ${venvPip} install --no-cache-dir -r ${studioReq}/base.txt
                ${venvPip} install --no-cache-dir -r ${studioReq}/extras.txt
                ${venvPip} install --no-deps --no-cache-dir -r ${studioReq}/extras-no-deps.txt
                ${venvPip} install --force-reinstall --no-cache-dir -r ${studioReq}/overrides.txt

                if [ -f ${studioReq}/triton-kernels.txt ]; then
                  ${venvPip} install --no-deps --no-cache-dir -r ${studioReq}/triton-kernels.txt
                fi

                ${venvPip} install --no-cache-dir -r ${studioReq}/studio.txt

                if [ -f ${studioReq}/single-env/data-designer-deps.txt ]; then
                  ${venvPip} install --no-cache-dir \
                    -c ${studioReq}/single-env/constraints.txt \
                    -r ${studioReq}/single-env/data-designer-deps.txt
                  ${venvPip} install --no-deps --no-cache-dir \
                    -c ${studioReq}/single-env/constraints.txt \
                    -r ${studioReq}/single-env/data-designer.txt
                fi

                echo "Building frontend..."
                tmpdir=$(mktemp -d)
                cp -r ${studioFrontend}/* "$tmpdir"/
                cd "$tmpdir"
                ${pkgs.pnpm}/bin/pnpm install --no-fund --no-audit --loglevel=error
                ${pkgs.pnpm}/bin/pnpm run build
                mkdir -p ${studioFrontend}/dist
                cp -r dist/* ${studioFrontend}/dist/
                rm -rf "$tmpdir"

                if [ -f ${studioBackend}/core/data_recipe/oxc-validator/package.json ]; then
                  tmpdir=$(mktemp -d)
                  cp -r ${studioBackend}/core/data_recipe/oxc-validator/* "$tmpdir"/
                  cd "$tmpdir"
                  ${pkgs.pnpm}/bin/pnpm install --no-fund --no-audit --loglevel=error
                  cp -r node_modules ${studioBackend}/core/data_recipe/oxc-validator/
                  rm -rf "$tmpdir"
                fi

                date -Iseconds > ${setupDone}
                echo "Studio setup complete."
              '';
              User = primaryUser;
              Group = primaryGroup;
              TimeoutStartSec = "3600";
            };
          };

          unsloth-studio = {
            description = "Unsloth Studio - AI Model Training & Inference UI";
            after = ["network.target" "unsloth-setup.service"];
            requires = ["unsloth-setup.service"];
            wantedBy = ["multi-user.target"];
            path = with pkgs; [git python313 llama-cpp-rocwmma];
            environment =
              rocmEnv
              // {
                HOME = unslothDataDir;
                LLAMA_SERVER_PATH = "${llama-cpp-rocwmma}/bin/llama-server";
                LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath rocmRuntimeLibs;
              };
            unitConfig = {
              ConditionPathExists = setupDone;
            };
            serviceConfig =
              {
                Type = "simple";
                ExecStartPre = "${venvPip} install --no-cache-dir structlog";
                ExecStart = "${venvPython} ${studioBackend}/run.py --host 127.0.0.1 --port 8888";
                User = primaryUser;
                Group = "video";
                WorkingDirectory = "${unslothDataDir}/workspace";
                SupplementaryGroups = ["render"];
                TimeoutStartSec = "60";
              }
              // serviceDefaults {RestartSec = "10s";};
          };
        };

        systemd.tmpfiles.rules = map (sub: mkStateDir "${unslothDataDir}${sub}" "0755" primaryUser primaryGroup) ["/workspace" "/models" "/.unsloth" "/.unsloth/studio"];
      })
    ];
  };
}
