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
# insufficient evidence there. The CPU llama.cpp build (0.6.0 from root
# nixpkgs as of the 2026-10-10 thinking-fix deploy; 0.5.0 when this
# module first landed) is the proven-in-production path on this host — llama-vlm's
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
#   - Ollama (:11434): owner-REJECTED — "bad abstraction on top of
#     llama.cpp" (standing directive 2026-10-12, fleet-wide). Never wire a
#     SystemNix service to it; the evo-x2 instance was REMOVED the same day
#     (service + widget + SigNoz rule + port + ai-models paths);
#     /data/ai/models/ollama (~15 G) is owner-reclaim residue.
#
# Model: Lars's own abliterated Qwen3.6 MoE tune from the Jan model tree
# (the April download was interrupted; completed + sha256-verified
# 2026-10-08). ABLITERATED IS A HARD REQUIREMENT (owner directive
# 2026-10-12: gpt-oss-120b rejected — "OLD and NOT Abliterated"); swaps
# stay within the abliterated Qwen3.6-35B-A3B family (quants/distills/
# newer HauhauCS-class tunes of the same 3B-active architecture).
# Qwen3.6 ships a native tool-call chat template, which --jinja
# enables — the InboxClean agent drives its Gmail tools through OpenAI-format
# tool calls (round-trip verified live 2026-10-08 on the sibling qwen3:4b:
# finish_reason "tool_calls" with parsed arguments). To swap brains, change
# modelPath + alias here AND LLM_MODEL in the inboxclean wiring
# (modules/nixos/services/inboxclean.nix); `inboxclean doctor` verifies the
# served model id against /v1/models at deploy time.
#
# Thinking OFF (--chat-template-kwargs, 2026-10-10): the Qwen3.6 template
# defaults enable_thinking=true, so every chat completion opened a <think>
# block BEFORE any content. Measured live: a trivial plan-style probe burned
# 600/600 max_tokens on reasoning alone (content EMPTY, finish=length) in
# 59s at ~10-25 t/s CPU; the real InboxClean turn (4.9k-token context) never
# finished thinking inside the app's 3-minute turn budget — 4/4 turns died
# with "context deadline exceeded" since the brain landed. With
# enable_thinking=false the same probe returns converging JSON in 80 tokens
# (finish=stop). Server-side (not per-request) so every OpenAI-compatible
# consumer — InboxClean included, which sends no template kwargs — gets it.
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
        ioTier
        ports
        ;
      inherit (config.users) primaryUser;

      llamaServer = lib.getExe' cfg.package "llama-server";

      # --jinja makes llama-server apply the GGUF's embedded chat template,
      # which is what turns OpenAI-format `tools` into native Qwen3.6
      # tool-call responses. No --n-gpu-layers: the ROCm path is wedged on
      # this host (freeze #5); CPU + MoE is the deliberate posture above.
      # The template-kwargs kill the template's default <think> phase —
      # see the header narrative (2026-10-10 deadline-exceeded class).
      execStart =
        "${llamaServer}"
        + " -m ${cfg.modelPath}"
        + " --alias ${cfg.alias}"
        + " --host ${cfg.host}"
        + " --port ${toString cfg.port}"
        + " --ctx-size ${toString cfg.ctxSize}"
        + " --threads ${toString cfg.threads}"
        + " --jinja"
        # Single-quoted for systemd: the unit parser strips bare double
        # quotes and word-splits the JSON into separate argv entries
        # (2026-10-10 deploy: llama-server received "{e" and exited 1).
        + " --chat-template-kwargs '{\"enable_thinking\":false}'";

      # Convergence helper (2026-10-08): ConditionPathExists is evaluated
      # once per start attempt — a unit skipped at boot (model still a .part
      # download) stays skipped forever after the file completes. The ensure
      # timer re-attempts convergence: model present + unit not running →
      # systemctl start. Zero manual systemd state (owner doctrine 2026-10-08:
      # "everything should be nix managed"; polkit bars agents from starts).
      ensureScript = pkgs.writeShellApplication {
        name = "llama-chat-ensure";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if [ ! -e ${cfg.modelPath} ]; then
            echo "llama-chat-ensure: model ${cfg.modelPath} absent — nothing to converge"
            exit 0
          fi
          if systemctl is-active --quiet llama-chat.service; then
            exit 0
          fi
          echo "llama-chat-ensure: model present, llama-chat not active — starting"
          systemctl start llama-chat.service
        '';
      };
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
          default = "48G";
          description = "Memory ceiling. Measured 2026-10-08: 23.4 GB weights (file-backed, charged on cold cache) + ~8.9 GB anon (KV cache 32k ctx + compute buffers) = ~32.3 GB idle-serving — 32G would OOM-kill on cold boot; 48G leaves headroom.";
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
          # Model load is APPLICATION READINESS, not boot work (owner ruling
          # 2026-10-17, closes session §g.1): the 23.4 GB GGUF cold page-in +
          # readiness probe ran INSIDE the boot transaction (10m49s on the
          # 2026-10-17 storm boot — the single largest bounded contributor to
          # FinishTimestamp, and the gatus boot-userspace regression line's
          # "usual suspect"). After=multi-user.target moves the unit PAST the
          # target's wait set (same post-boot pattern as netbird-evox2-login):
          # boot finishes without the load; the server then maps at its own
          # pace with the same start contract ("Started" == /health 200) and
          # the 10-min ensure-timer converging a skipped load. Consumers see
          # connection-refused until ready — InboxClean chat/ai-meter degrade
          # gracefully (no gatus check probes llama-chat directly; verified
          # 2026-10-17 before this move).
          after = [
            "network-online.target"
            "multi-user.target"
          ];
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
              # Quota matches threads (12 of 16 cores): threads share the CPU
              # time the quota grants, so a 400% quota would silently quarter
              # the measured ~17 tok/s interactive throughput.
              CPUQuota = "1200%";
              # Same D-state rationale as llama-rag: a stop during saturated
              # disk I/O cannot complete until the mmap reads finish. The
              # initial 23.4 GB page-in is IO-heavy but one-shot at boot —
              # 15min covers a cold page-in under an IO storm PLUS the
              # ExecStartPost probe budget below (was 10min).
              TimeoutStartSec = "15min";
              TimeoutStopSec = "2min";
              ExecStart = execStart;
              # Start contract (2026-10-08, same doctrine as the daemon
              # socket contract): "started" means /health serves 200, not
              # just that execve succeeded. llama-server binds its listener
              # early and 503s while the 23.4 GB model maps, so -f +
              # --retry-all-errors retries through the whole load; a load
              # that wedges (freeze-#5 class) FAILS the unit and
              # Restart=on-failure heals instead of active-but-dead.
              # 400 retries (~13min at 2s/iter, attempts return instantly
              # while 503ing) keeps the probe budget inside the 15min
              # TimeoutStartSec: 240 exhausted at exactly 8min on the
              # 2026-10-12 boot (page-in starved by the IO storm), wasting
              # the 8min load and forcing a full remap on the restart.
              ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 400 --retry-delay 2 --retry-all-errors http://${cfg.host}:${toString cfg.port}/health";
            }
            # harden derives MemoryHigh (the throttle watermark) as 80% of
            # the MemoryMax ARGUMENT — calling `harden {}` bare merges its
            # phantom 512M default: the standalone MemoryMax won at 32G but
            # MemoryHigh stayed at 410M and strangled the first deployment
            # (443 MB peak, 10.7 GB swapped, 1h53m stuck load; a 16-token
            # reply timed out at 45s with 46k throttle events). The ceiling
            # MUST flow into harden so both watermarks agree.
            (harden { MemoryMax = cfg.memoryMax; })
            # BE/5 (heavyDB tier, session row 8): user-facing inference —
            # ahead of the BE/6 background daemons (rag/enrichers), behind
            # desktop BE/3. Only shapes the cold-load window + steady-state
            # checkpoint writes; serving itself is anon-memory (KV cache),
            # barely any IO.
            ioTier.heavyDB
          ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;
        };

        systemd.services.llama-chat-ensure = {
          description = "Converge llama-chat when its model file exists (ConditionPathExists never re-evaluates)";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${ensureScript}/bin/llama-chat-ensure";
          };
        };

        systemd.timers.llama-chat-ensure = {
          description = "Re-attempt llama-chat convergence every 10 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "10min";
            AccuracySec = "1min";
          };
        };

        # Service-integration registry entry: loopback-only daemon exposed
        # via the Layer 2 vHost (https://llama.<domain>) — llama-server's
        # built-in web UI (/) + OpenAI API (/v1) behind oauth2-proxy
        # forward-auth for external clients, LAN bypass; the loopback-bind
        # assertion above still holds (Caddy proxies, the port never binds
        # externally). Gatus /health is the wedge detector (the freeze-#5
        # class): without it the port is served but nothing notices a
        # wedged/missing brain until InboxClean chat turns start failing.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          llama-chat = {
            inherit (cfg)
              enable
              port
              ;
            subdomain = "llama";
            vHost.layer = "protected";
            monitored = true;
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
            homepage = {
              name = "llama.cpp Chat";
              group = "AI";
              description = "Qwen3.6 35B-A3B brain — OpenAI-compatible, native tool calls";
              icon = "open-webui.png";
              checkUrl = "http://127.0.0.1:${toString cfg.port}/health";
            };
          };
        };
      };
    };
}
