# llama.cpp RAG stack — embeddings + reranking on the GPU (ROCm)
#
# Two lightweight llama-server instances for retrieval-augmented generation:
#
#   llama-embeddings  127.0.0.1:8848  bge-m3          --embedding
#   llama-reranker    127.0.0.1:8849  bge-reranker-v2-m3  --reranking --pooling rank
#
# Both models are ~568M params: cold load ~1s, VRAM ~1-2 GB each. No socket
# activation needed (unlike FastFlowLM's 13.6 GB NPU model) — always-on is
# affordable for services that need instant embedding/rerank responses.
#
# Why two instances: llama.cpp's --embedding and --reranking modes are
# mutually exclusive per server process. Ollama could serve embeddings but
# does NOT support reranking (issue #3368, open since Mar 2024). Using
# llama-server for both keeps the RAG stack on a single engine, fully
# Nix-native, zero Docker.
#
# Model files (GGUF) must be placed in modelDir before starting:
#   /data/ai/models/gguf/bge-m3.gguf
#   /data/ai/models/gguf/bge-reranker-v2-m3.gguf
# Download from HuggingFace community GGUF repos or convert via
# convert_hf_to_gguf.py from the llama.cpp source tree.
_: {
  flake.nixosModules.llama-rag =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.llama-rag;
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        ports
        ioTier
        ;
      inherit (config.users) primaryUser;

      rocm = libHelpers.rocm { inherit pkgs; };
      llama-cpp-rocwmma = pkgs.llama-cpp.override { rocmSupport = true; };
      llamaServer = lib.getExe' llama-cpp-rocwmma "llama-server";
      ldLibPath = rocm.makeLdLibraryPath lib;

      commonServiceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = [ "render" ];
        NoNewPrivileges = false;
        Restart = "on-failure";
        RestartSec = "10";
        OOMScoreAdjust = 300;
        MemoryMax = cfg.memoryMax;
        CPUQuota = "200%";
      };

      embeddingsExecStart =
        "${llamaServer} --embedding"
        + " -m ${cfg.modelDir}/${cfg.embeddingsModel}"
        + " --alias ${cfg.embeddingsAlias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.embeddingsPort}"
        + " --ctx-size ${toString cfg.ctxSize}";

      rerankerExecStart =
        "${llamaServer} --reranking --pooling rank"
        + " -m ${cfg.modelDir}/${cfg.rerankerModel}"
        + " --alias ${cfg.rerankerAlias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.rerankerPort}"
        + " --ctx-size ${toString cfg.ctxSize}";
    in
    {
      options.services.llama-rag = {
        enable =
          lib.mkEnableOption "llama.cpp RAG stack (embeddings + reranking, ROCm GPU)"
          // {
            default = false;
          };

        modelDir = lib.mkOption {
          type = lib.types.str;
          default = "/data/ai/models/gguf";
          description = "Directory containing GGUF model files. Created by ai-models.nix.";
        };

        embeddingsModel = lib.mkOption {
          type = lib.types.str;
          default = "bge-m3.gguf";
          description = "GGUF model filename for the embeddings server (BERT-family, --embedding mode).";
        };

        embeddingsAlias = lib.mkOption {
          type = lib.types.str;
          default = "bge-m3";
          description = "Model alias reported via the /v1/models endpoint and accepted in API requests.";
        };

        rerankerModel = lib.mkOption {
          type = lib.types.str;
          default = "bge-reranker-v2-m3.gguf";
          description = "GGUF model filename for the reranking server (cross-encoder, --reranking mode).";
        };

        rerankerAlias = lib.mkOption {
          type = lib.types.str;
          default = "bge-reranker-v2-m3";
          description = "Model alias reported via the /v1/models endpoint and accepted in API requests.";
        };

        ctxSize = lib.mkOption {
          type = lib.types.int;
          default = 8192;
          description = "Context window size (tokens). bge-m3 and bge-reranker-v2-m3 both support 8192.";
        };

        memoryMax = lib.mkOption {
          type = lib.types.str;
          default = "2G";
          description = "Memory ceiling per service. 568M-param models need <1 GB; 2G gives headroom.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Bind address — keep loopback only.";
        };

        embeddingsPort = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-embeddings;
          description = "Port for the embeddings server (/v1/embeddings).";
        };

        rerankerPort = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-reranker;
          description = "Port for the reranking server (/v1/rerank).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "User to run the services as.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "users";
          description = "Group for the service user.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.embeddingsPort != cfg.rerankerPort;
            message = "services.llama-rag.embeddingsPort and rerankerPort must differ (two separate instances).";
          }
          {
            assertion = cfg.host == "127.0.0.1" || cfg.host == "::1";
            message = "services.llama-rag.host must be loopback. Expose via reverse proxy if you need remote access.";
          }
        ];

        systemd.services.llama-embeddings = {
          description = "llama.cpp embeddings server (bge-m3, ROCm GPU)";
          after = [
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          environment = rocm.env // {
            LD_LIBRARY_PATH = ldLibPath;
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
          };

          serviceConfig = lib.mkMerge [
            commonServiceConfig
            {
              ExecStart = embeddingsExecStart;
            }
            (harden { })
            ioTier.background
          ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };

        systemd.services.llama-reranker = {
          description = "llama.cpp reranking server (bge-reranker-v2-m3, ROCm GPU)";
          after = [
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          environment = rocm.env // {
            LD_LIBRARY_PATH = ldLibPath;
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
          };

          serviceConfig = lib.mkMerge [
            commonServiceConfig
            {
              ExecStart = rerankerExecStart;
            }
            (harden { })
            ioTier.background
          ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };
      };
    };
}
