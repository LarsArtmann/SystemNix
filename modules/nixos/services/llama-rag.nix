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
# Model files (GGUF) are downloaded at activation into modelDir
# (/data/ai/models/gguf, created by ai-models.nix) by the
# llama-rag-model-fetch oneshot, then the servers are started:
#   /data/ai/models/gguf/bge-m3.gguf
#   /data/ai/models/gguf/bge-reranker-v2-m3.gguf
# Sources are gpustack's verified GGUF conversions of the BAAI checkpoints
# (gpustack/bge-m3-GGUF, gpustack/bge-reranker-v2-m3-GGUF).
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

      # Deterministic per-model download URLs. The fetch oneShot downloads
      # each file into modelDir at activation (and into the NVMe-trash for the
      # previous version when the URL changes — a partial relocation heals by
      # re-downloading, there is no conflict with a moving fastflowlm model).
      modelFetches = [
        {
          url = "https://huggingface.co/gpustack/bge-m3-GGUF/resolve/main/bge-m3-FP16.gguf";
          file = cfg.embeddingsModel;
        }
        {
          url = "https://huggingface.co/gpustack/bge-reranker-v2-m3-GGUF/resolve/main/bge-reranker-v2-m3-FP16.gguf";
          file = cfg.rerankerModel;
        }
      ];

      # Compact but readable bash: loop the URL pairs, sniff the first 4 KiB,
      # refuse mismatches, then curl --fail silently.
      fetchScript = pkgs.writeShellScript "llama-rag-model-fetch.sh" ''
        set -euo pipefail
        outdir=''${1:-${cfg.modelDir}}
        pfx=/run/llama-rag-model-fetch
        mkdir -p "$pfx"
        for spec in ${builtins.toString (map (m: "'${m.url}' '${m.file}'") modelFetches)}; do
          set -- $spec
          url="$1"; file="$2"
          target="$outdir/$file"
          if [ -e "$target" ]; then
            magic="$(head -c 4 "$target" 2>/dev/null)" || true
            if [ "$magic" = "GGUF" ]; then
              echo "llama-rag: OK $target (present)"
              continue
            fi
            echo "llama-rag: stale/corrupt $target (magic '${magic:-}') — re-fetching"
            rm -f -- "$target"
          fi
          echo "llama-rag: downloading $url"
          tmpfile="$pfx/$file.part"
          if curl -fsSL --retry 3 --retry-delay 5 -o "$tmpfile" "$url"; then
            other="$pfx/$file.prev"
            if [ -e "$target" ]; then mv -f -- "$target" "$other"; fi
            chmod 644 "$tmpfile"
            if mv -f -- "$tmpfile" "$target"; then
              echo "llama-rag: installed $target"
              if [ -e "$other" ]; then rm -f -- "$other"; fi
            fi
          else
            echo "llama-rag: download FAILED for $url" >&2
            rm -f -- "$tmpfile"
            exit 1
          fi
        done
      '';

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

        systemd.services.llama-rag-model-fetch = {
          description = "Fetch llama.cpp RAG GGUF models (bge-m3 + bge-reranker-v2-m3)";
          wantedBy = [ "multi-user.target" ];
          before = [
            "llama-embeddings.service"
            "llama-reranker.service"
          ];
          path = [
            pkgs.curl
            pkgs.coreutils
          ];
          unitConfig.ConditionPathIsDirectory = cfg.modelDir;
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            ExecStart = "${fetchScript} ${cfg.modelDir}";
            # 2 × ~0.6-1.2 GB downloads; the INI is remote and can be slow.
            TimeoutStartSec = "20min";
          };
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
        };

        systemd.services.llama-embeddings = {
          description = "llama.cpp embeddings server (bge-m3, ROCm GPU)";
          after = [
            "network-online.target"
            "llama-rag-model-fetch.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          requires = [ "llama-rag-model-fetch.service" ];

          environment = rocm.env // {
            LD_LIBRARY_PATH = ldLibPath;
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
            "llama-rag-model-fetch.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          requires = [ "llama-rag-model-fetch.service" ];

          environment = rocm.env // {
            LD_LIBRARY_PATH = ldLibPath;
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
