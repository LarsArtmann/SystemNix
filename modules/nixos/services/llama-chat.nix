# Runbook: docs/services/llama-chat.md
# llama.cpp chat server — the interactive agent brain behind InboxClean's
# dashboard chat (/chat) and any other local OpenAI-compatible consumer.
#
#   llama-chat  127.0.0.1:8850  qwen3.6-27b-aggressive  --jinja (native tool calls)
#
# Why a dedicated always-on GPU server and NOT the existing options:
#   - FastFlowLM (:52625, NPU): socket-activated with a 2-5 min cold load,
#     idle-unloads after 1h, and is the memory-emergency-guard's designated
#     sacrifice — perfect for ASYNC workloads (paperless-gpt tagging,
#     commit-message generation), hostile for interactive agent turns
#     (InboxClean bounds one chat turn at 3 min; a guard trip mid-turn kills
#     the conversation).
#   - Ollama (:11434): owner-rejected as the standard.
# A resident ~17.5 GB Q4 27B on the iGPU answers the first token in
# milliseconds and survives memory-guard trips (it is not on any sacrifice
# list — revisit if it ever becomes a trip CAUSE).
#
# llama.cpp comes from the same REV-PINNED nixpkgs as llama-rag (flake input
# `nixpkgs-llama-rag`): 0.3.0 is the last build proven serving on gfx1150 —
# root nixpkgs 0.4.0+ builds wedge mid-model-load (full narrative in
# llama-rag.nix). Drop both pins together once the regression is fixed
# upstream and re-verified live.
#
# Model: Lars's own abliterated Qwen3.6 tune from the Jan model tree.
# Qwen3.6 ships a native tool-call chat template, which --jinja enables —
# the InboxClean agent drives its Gmail tools through OpenAI-format tool
# calls. To swap brains (e.g. the 35B-A3B MoE once its interrupted download
# is finished), change modelPath + alias here AND LLM_MODEL in the
# inboxclean wiring (configuration.nix); `inboxclean doctor` verifies the
# served model id against /v1/models at deploy time.
#
# No fetch unit: the GGUF is part of the Jan-managed model tree
# (/data/ai/models/jan/llamacpp, ~92 G, backed by the ai-models backup
# exclusions), not a service-owned download. If the file is missing the
# unit skips (ConditionPathExists) instead of crash-looping.
_: {
  flake.nixosModules.llama-chat =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.services.llama-chat;
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        ports
        ;
      inherit (config.users) primaryUser;

      llamaPkgs = import inputs.nixpkgs-llama-rag {
        inherit (pkgs) system;
        config.allowUnfree = true;
      };
      rocm = libHelpers.rocm { pkgs = llamaPkgs; };
      llama-cpp-rocwmma = llamaPkgs.llama-cpp.override { rocmSupport = true; };
      llamaServer = lib.getExe' llama-cpp-rocwmma "llama-server";
      ldLibPath = rocm.makeLdLibraryPath lib;

      # --jinja makes llama-server apply the GGUF's embedded chat template,
      # which is what turns OpenAI-format `tools` into native Qwen3.6
      # tool-call responses (verified live 2026-10-08: finish_reason
      # "tool_calls" with parsed function arguments).
      execStart =
        "${llamaServer}"
        + " -m ${cfg.modelPath}"
        + " --alias ${cfg.alias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.port}"
        + " --ctx-size ${toString cfg.ctxSize}"
        + " --n-gpu-layers ${toString cfg.gpuLayers}"
        + " --jinja";
    in
    {
      options.services.llama-chat = {
        enable = lib.mkEnableOption "llama.cpp chat server (ROCm GPU, always-on, OpenAI-compatible with native tool calls)";

        modelPath = lib.mkOption {
          type = lib.types.str;
          default = "/data/ai/models/jan/llamacpp/models/qwen3.6-27b-aggressive/Qwen3.6-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf";
          description = "GGUF to serve. Must embed a tool-call chat template (Qwen3.6 family does).";
        };

        alias = lib.mkOption {
          type = lib.types.str;
          default = "qwen3.6-27b-aggressive";
          description = "Model id reported via /v1/models and accepted in API requests; consumers' LLM_MODEL must match.";
        };

        ctxSize = lib.mkOption {
          type = lib.types.int;
          default = 32768;
          description = "Context window (tokens). 32k covers long email threads with tool-call history.";
        };

        gpuLayers = lib.mkOption {
          type = lib.types.int;
          default = 999;
          description = "Layers offloaded to the GPU (999 = all).";
        };

        memoryMax = lib.mkOption {
          type = lib.types.str;
          default = "28G";
          description = "Memory ceiling: ~17.5 GB Q4 weights + KV cache for 32k ctx + ROCm overhead.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Bind address - keep loopback only.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-chat;
          description = "Port for the OpenAI-compatible API (/v1).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = primaryUser;
          description = "User to run the service as.";
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
            assertion = cfg.host == "127.0.0.1" || cfg.host == "::1";
            message = "services.llama-chat.host must be loopback. Expose via reverse proxy if you need remote access.";
          }
        ];

        systemd.services.llama-chat = {
          description = "llama.cpp chat server (${cfg.alias}, ROCm GPU, native tool calls)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathExists = cfg.modelPath;

          environment = rocm.env // {
            LD_LIBRARY_PATH = ldLibPath;
          };

          serviceConfig = lib.mkMerge [
            {
              Type = "exec";
              User = cfg.user;
              Group = cfg.group;
              SupplementaryGroups = [ "render" ];
              Restart = "on-failure";
              RestartSec = "10";
              OOMScoreAdjust = 300;
              MemoryMax = cfg.memoryMax;
              CPUQuota = "200%";
              # Same D-state rationale as llama-rag: a stop during saturated
              # disk I/O cannot complete until the mmap reads finish.
              TimeoutStopSec = "2min";
              ExecStart = execStart;
            }
            (harden { })
            rocm.deviceCgroup
          ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };
      };
    };
}
