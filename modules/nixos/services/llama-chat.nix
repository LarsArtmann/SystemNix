# Runbook: docs/services/llama-chat.md
# llama.cpp chat server — the interactive agent brain behind InboxClean's
# dashboard chat (/chat) and any other local OpenAI-compatible consumer.
#
#   llama-chat  127.0.0.1:8850  qwen3.6-35b-a3b-aggressive  --jinja (native tool calls)
#
# Why CPU and NOT the GPU: the llama.cpp/ROCm path on gfx1150 WEDGES under
# systemd units regardless of version — freeze #5 (2026-09-18) proved the
# rev-pinned 0.3.0 build spins identically to 0.4.0 (94% single-thread CPU
# right after the vocab warning; see llama-rag.nix's ESCAPE CONDITION
# narrative). Direct-run verification outside the unit context is
# insufficient evidence there. The CPU llama.cpp build (0.5.0 from root
# nixpkgs) is the proven-in-production path on this host — llama-vlm's
# caption/verdict servers run it under systemd daily. CPU is not a
# compromise here: the model is a Qwen3.6 35B-A3B MoE (3B active params),
# so CPU inference still streams interactive-fast tokens while the full
# 23.4 GB expert pool sits in page cache (128 GB host).
#
# Why a dedicated always-on server and NOT the existing options:
#   - FastFlowLM (:52625, NPU): socket-activated with a 2-5 min cold load,
#     idle-unloads after 1h, and is the memory-emergency-guard's designated
#     sacrifice — perfect for ASYNC workloads (paperless-gpt tagging,
#     commit-message generation), hostile for interactive agent turns
#     (InboxClean bounds one chat turn at 3 min; a guard trip mid-turn kills
#     the conversation).
#   - Ollama (:11434): owner-rejected as the standard.
#
# Model: Lars's own abliterated Qwen3.6 MoE tune from the Jan model tree
# (the April download was interrupted; completed + sha256-verified
# 2026-10-08). Qwen3.6 ships a native tool-call chat template, which --jinja
# enables — the InboxClean agent drives its Gmail tools through OpenAI-format
# tool calls (round-trip verified live 2026-10-08 on the sibling qwen3:4b:
# finish_reason "tool_calls" with parsed arguments). To swap brains, change
# modelPath + alias here AND LLM_MODEL in the inboxclean wiring
# (modules/nixos/services/inboxclean.nix); `inboxclean doctor` verifies the
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
      options,
      lib,
      pkgs,
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

      llamaServer = lib.getExe' cfg.package "llama-server";

      # --jinja makes llama-server apply the GGUF's embedded chat template,
      # which is what turns OpenAI-format `tools` into native Qwen3.6
      # tool-call responses. No --n-gpu-layers: the ROCm path is wedged on
      # this host (freeze #5); CPU + MoE is the deliberate posture above.
      execStart =
        "${llamaServer}"
        + " -m ${cfg.modelPath}"
        + " --alias ${cfg.alias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.port}"
        + " --ctx-size ${toString cfg.ctxSize}"
        + " --threads ${toString cfg.threads}"
        + " --jinja";
    in
    {
      options.services.llama-chat = {
        enable = lib.mkEnableOption "llama.cpp chat server (CPU, always-on, OpenAI-compatible with native tool calls)";

        package = lib.mkPackageOption pkgs "llama-cpp" { };

        modelPath = lib.mkOption {
          type = lib.types.str;
          default = "/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf";
          description = "GGUF to serve. Must embed a tool-call chat template (Qwen3.6 family does).";
        };

        alias = lib.mkOption {
          type = lib.types.str;
          default = "qwen3.6-35b-a3b-aggressive";
          description = "Model id reported via /v1/models and accepted in API requests; consumers' LLM_MODEL must match.";
        };

        ctxSize = lib.mkOption {
          type = lib.types.int;
          default = 32768;
          description = "Context window (tokens). 32k covers long email threads with tool-call history.";
        };

        threads = lib.mkOption {
          type = lib.types.int;
          default = 12;
          description = "CPU threads. 12 of 16 cores — leaves headroom for the desktop session instead of pinning everything.";
        };

        memoryMax = lib.mkOption {
          type = lib.types.str;
          default = "32G";
          description = "Memory ceiling: 23.4 GB MoE weights (page cache) + KV cache for 32k ctx + runtime overhead.";
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
          description = "llama.cpp chat server (${cfg.alias}, CPU MoE, native tool calls)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          unitConfig.ConditionPathExists = cfg.modelPath;

          serviceConfig = lib.mkMerge [
            {
              Type = "exec";
              User = cfg.user;
              Group = cfg.group;
              Restart = "on-failure";
              RestartSec = "10";
              OOMScoreAdjust = 300;
              MemoryMax = cfg.memoryMax;
              CPUQuota = "400%";
              # Same D-state rationale as llama-rag: a stop during saturated
              # disk I/O cannot complete until the mmap reads finish. The
              # initial 23.4 GB page-in is IO-heavy but one-shot at boot.
              TimeoutStartSec = "10min";
              TimeoutStopSec = "2min";
              ExecStart = execStart;
            }
            (harden { })
          ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };

        # Service-integration registry entry: loopback-only server (no vHost
        # — the port registry forbids external exposure), so this is the sole
        # Gatus surface watching :8850. Without it the port is served but
        # nothing notices a wedged/missing brain (the freeze-#5 class) until
        # InboxClean chat turns start failing.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          llama-chat = {
            inherit (cfg) enable;
            vHost.layer = "none";
            checks = [
              {
                # /health is 200 only after the GGUF is mapped and the model
                # is serving; it 503s while loading and refuses when the unit
                # is down or skipped (ConditionPathExists with a missing GGUF).
                name = "llama.cpp Chat";
                group = "AI";
                url = "http://localhost:${toString cfg.port}/health";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 2000"
                ];
                alert = "llama.cpp chat server down — InboxClean /chat agent brain unreachable. Check: systemctl status llama-chat, journalctl -u llama-chat -n 50 (freeze-#5 class: 94% single-thread CPU spin after the vocab warning means the ROCm/CPU path wedged).";
              }
            ];
          };
        };
      };
    };
}
