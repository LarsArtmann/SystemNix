# Runbook: docs/services/llama-chat.md
# llama.cpp chat server — the interactive agent brain behind InboxClean's
# dashboard chat (/chat) and any other local OpenAI-compatible consumer.
#
#   llama-chat.socket   127.0.0.1:8850  (public, Accept=true)
#   llama-chat@.service                (per-connection socat bridge → :8851)
#   llama-chat.service                 (backend, private :8851, model resident)
#
# ON-DEMAND since 2026-11-18 (freeze-41 report item 30 — this module's
# sanctioned return path): the freeze #41-#44 chain (Nov 2-3, 5 WDT cuts)
# retired the always-on posture — the 23.4 GB GGUF cold page-in was the
# boot-time storm seed (#40: ~110 GB of reads in the first 75 min) and
# llama-server at OOMScoreAdjust=300 was the kernel's preferred victim at
# every memory cliff (#34/#38/#43). Socket activation (the proven
# llama-vlm pattern, generalized from fastflowlm) kills the re-arm class
# entirely: nothing cold-loads at boot, the socket spawns a per-connection
# socat bridge on first client traffic, the bridge pulls the backend up
# (psi-wait-gated: the 23.4 GB load WAITS for io-PSI calm — clients see a
# slow first answer queued in the socket backlog, never a refused one),
# and the idle TTL unloads the model after cfg.keepAlive without traffic.
# The llama-chat-ensure convergence timer is RETIRED with the always-on
# posture — the socket IS the convergence now. Pairing defense that landed
# with this return (per the configuration.nix re-enable recipe):
# memory-emergency-guard ioPause cgroupPatterns += llama-chat.service
# (2026-11-03, "the re-enable-day guard") and the psi-wait-gate below.
#
# Where the model runs — `accelerator` (owner directive 2026-11-27: "ALL
# AI models should be ran on iGPU or NPU and NEVER on the CPU"):
#
#   igpu  (evo-x2, 2026-11-28): the HIP/ROCm build of llama.cpp from the root
#          nixpkgs (lib/rocm.nix llamaCppHip — the same derivation ai-stack's
#          llama-server-rocm runs) with all 41 layers in GTT on the Radeon
#          8060S. The expert pool is RESIDENT for as long as the backend is
#          up, so inference no longer rides on page-cache hits: the cpu
#          posture's prompt processing fell to 5-18 tok/s whenever IO
#          pressure evicted experts (the 2026-11-27 browser-history summary
#          timeout). Measured under the unit-shaped sandbox on 2026-11-28:
#          load_mode none, 41/41 layers offloaded, 22.1 GiB ROCm0 model
#          buffer, ~1,245 tok/s prompt processing, 53-56 tok/s decode, cold
#          load 2m29s — table + method:
#          docs/status/2026-11-28_03-20_llama-chat-igpu-flip-hip-build-verified.md
#
#   cpu   the escape hatch and this host's posture 2026-10-05..2026-11-27:
#          the plain llama.cpp build, experts in page cache. One line in
#          configuration.nix rolls the flip back.
#
# WHY IT WAS CPU, AND WHAT CHANGED. The llama.cpp/ROCm path on gfx1150 WEDGED
# under systemd units regardless of llama.cpp version — freeze #5
# (2026-09-18) saw the rev-pinned 0.3.0 build spin identically to 0.4.0 (94%
# single-thread CPU right after the vocab warning; llama-rag.nix's ESCAPE
# CONDITION narrative), and a shell direct-run had looked healthy, so
# direct-run verification outside the unit context was ruled insufficient
# evidence. Upstream attribution (2026-11-14,
# docs/status/2026-11-14_07-59_llama-cpp-spin-upstream-attribution.md):
# llama.cpp #19482 — a ROCr userptr-registration spin on the MMAP upload of
# a large model; llama.cpp is only the trigger, so no llama.cpp version ever
# "fixed" it. What changed is the trigger: llama.cpp >=0.9 resolves
# `--load-mode auto` to `none` on iGPUs (ggml-cuda.cu: mmap_support is false
# for IGPU-type devices), leaving the mmap upload path entirely, and the
# 1.0.0 build loads the 23.4 GB chat model cleanly under the unit sandbox.
# This module PINS `--load-mode none` so the escape does not ride on HIP's
# integrated-flag detection.
#
# Guardrails that came out of that history, all load-bearing:
#   - the start contract judges the load: ExecStartPost /health under
#     TimeoutStartSec, so a spin fails the unit and Restart backoff heals
#     instead of active-but-dead;
#   - `--parallel 1` serializes inference. The 2026-11-25 request-time wedge
#     on the pinned embeddings build spun in
#     amdgpu_amdkfd_gpuvm_alloc_memory_of_gpu with four slots taken at once
#     while /health stayed 200 — liveness cannot see that class;
#   - the render group + strict device cgroup (lib/rocm.nix deviceCgroup):
#     /dev/kfd and renderD128 only, so libdrm's device enumeration cannot
#     open the NPU node (the 2026-09-04 D-state corpse class);
#   - a shell direct-run is NOT evidence. Re-soak every new llama.cpp or
#     ROCm build BEFORE deploying it:
#       sudo ./scripts/llama-rag-soak.sh --mode chat --force --as-user lars \
#         --memory-max 48G --warmup-max 1500 --minutes 15 \
#         --server <hip llama-server> --model <gguf> --port <scratch port> \
#         --server-arg=--jinja --server-arg=-ngl --server-arg=all \
#         --server-arg=--load-mode --server-arg=none \
#         --server-arg=--parallel --server-arg=1
#     then probe a real completion against the scratch port: the harness
#     judges the LOAD, the request-time wedge needs a request.
#
# Why a dedicated server and NOT the existing options (posture note
# 2026-11-18: llama-chat itself is now ALSO socket-activated — the on-demand
# tradeoff is the same one FastFlowLM made, accepted because the crash
# history makes "resident at boot" unsellable on this host; interactive
# consumers pay a first-token cold load, queued not refused):
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
      inherit ((import ./_llama-idle-activity.nix { inherit lib pkgs; })) templateActivity;
      inherit (libHelpers)
        harden
        ioTier
        ports
        ;
      inherit (config.users) primaryUser;

      # ROCm helpers. Lazy: only forced while accelerator == "igpu", so the
      # cpu posture and the standalone-module tests never instantiate the
      # HIP build.
      rocm = libHelpers.rocm { inherit pkgs; };
      onIgpu = cfg.accelerator == "igpu";

      llamaServer = lib.getExe' cfg.package "llama-server";

      # --jinja makes llama-server apply the GGUF's embedded chat template,
      # which is what turns OpenAI-format `tools` into native Qwen3.6
      # tool-call responses.
      # The template-kwargs kill the template's default <think> phase —
      # see the header narrative (2026-10-10 deadline-exceeded class).
      execStart =
        "${llamaServer}"
        + " -m ${cfg.modelPath}"
        + " --alias ${cfg.alias}"
        + " --host ${cfg.host}"
        # Backend binds the PRIVATE port (one proxy hop behind the public
        # socket, llama-vlm pattern): cfg.port is served by
        # systemd.sockets.llama-chat, never by llama-server itself.
        + " --port ${toString cfg.backendPort}"
        + " --ctx-size ${toString cfg.ctxSize}"
        + " --threads ${toString cfg.threads}"
        # iGPU offload (header narrative): every layer resident in GTT, and
        # the load path pinned away from the mmap upload that carries the
        # llama.cpp #19482 ROCr spin — `--load-mode auto` already resolves
        # to none on iGPUs, but that resolution rides on HIP's integrated
        # flag, so it is spelled out here.
        # --parallel 1: one inference slot. The 2026-11-25 request-time
        # wedge on the pinned embeddings build spun in
        # amdgpu_amdkfd_gpuvm_alloc_memory_of_gpu with four slots taken at
        # once while /health stayed 200; serializing removes the
        # concurrent-GPUVM-alloc path. Concurrent requests queue instead of
        # interleaving — at iGPU speed a queued turn waits seconds.
        + lib.optionalString onIgpu " --gpu-layers ${cfg.gpuLayers} --load-mode none --parallel 1"
        + " --jinja"
        # Single-quoted for systemd: the unit parser strips bare double
        # quotes and word-splits the JSON into separate argv entries
        # (2026-10-10 deploy: llama-server received "{e" and exited 1).
        + " --chat-template-kwargs '{\"enable_thinking\":false}'";

      # Per-connection bridge (llama-vlm pattern): the public socket hands
      # each accepted connection's fd to one of these; it waits for the
      # backend to become reachable (the psi-gated cold load can take
      # minutes) and then pipes bytes. Starting a bridge starts the backend
      # (wants/after below) — that IS the on-demand activation.
      bridgeConn = pkgs.writeShellApplication {
        name = "llama-chat-proxy-conn";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          host="${cfg.host}"
          port="${toString cfg.backendPort}"
          deadline=$((SECONDS + 1800))
          until (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; do
            if [ "$SECONDS" -ge "$deadline" ]; then
              echo "llama-chat-proxy: backend $host:$port not reachable within 1800 s (psi-wait-gate holding a 23.4 GB cold load?)" >&2
              exit 1
            fi
            sleep 1
          done
          exec ${lib.getExe' pkgs.socat "socat"} - "TCP:$host:$port"
        '';
      };

      # Idle TTL (llama-vlm pattern, freeze-#56 legs): stop the backend
      # after cfg.keepAlive with NO traffic. Traffic signal = per-connection
      # bridge units — every real client connection spawns one (Accept=true),
      # so a live bridge OR any bridge journal line inside the keepAlive
      # window counts as activity; a held-open HTTP keep-alive pool
      # connection (ai-meter) keeps the model resident by design.
      idleCheck = pkgs.writeShellApplication {
        name = "llama-chat-idle-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.systemd
        ];
        text = ''
          # A bridge whose backend never came up gives up at its deadline and
          # exits 1, which parks the instance FAILED. The backend unit owns
          # that failure; a pile of per-connection corpses only buries real
          # entries in `systemctl --failed` (88 of 96 on 2026-11-26, every
          # one a "backend not reachable" deadline), so each sweep clears the
          # template's failed state. Active bridges are untouched.
          systemctl reset-failed 'llama-chat@*.service' 2>/dev/null || true
          if ! systemctl is-active --quiet llama-chat.service; then
            exit 0
          fi
          # Live per-connection bridges = active traffic; also the only
          # reliable cold-load guard (no request is served before the first
          # bridge dials in).
          if systemctl list-units 'llama-chat@*.service' --state=active --no-legend 2>/dev/null | grep -q .; then
            exit 0
          fi
          now_us=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
          active_us=$(systemctl show llama-chat.service -p ActiveEnterTimestampMonotonic --value) || true
          if [ -z "$active_us" ] || [ $((now_us - active_us)) -lt 600000000 ]; then
            exit 0
          fi
          # Freeze-#56 fallback leg (llama-vlm): short probes start AND
          # finish a bridge between two idle-check runs, yet every probe IS
          # traffic — any bridge-unit journal line inside the window counts.
          # Indexed by message id (see _llama-idle-activity.nix): a unit glob
          # here read gigabytes of journal on every run and was the io storm.
          if ${templateActivity} 'llama-chat@' "${cfg.keepAlive}"; then
            exit 0
          fi
          systemctl stop 'llama-chat@*.service' llama-chat.service
        '';
      };
    in
    {
      options.services.llama-chat = {
        enable = lib.mkEnableOption "llama.cpp chat server (socket-activated, OpenAI-compatible with native tool calls)";

        accelerator = lib.mkOption {
          type = lib.types.enum [
            "cpu"
            "igpu"
          ];
          default = "cpu";
          description = "Where the model runs. cpu: the plain llama.cpp build, MoE experts in page cache (this host's posture 2026-10-05..2026-11-27). igpu: the HIP/ROCm build with every layer resident in GTT on the Strix Halo iGPU.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = if onIgpu then rocm.llamaCppHip else pkgs.llama-cpp;
          description = "llama.cpp package. Defaults to the build that matches accelerator; set only to pin a specific build.";
        };

        gpuLayers = lib.mkOption {
          type = lib.types.str;
          default = "all";
          description = "accelerator = \"igpu\" only: the --gpu-layers value (a layer count, \"auto\", or \"all\").";
        };

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
          description = "Memory ceiling of the unit's cgroup. Measured 2026-10-08: 23.4 GB weights (file-backed, charged on cold cache) + ~8.9 GB anon (KV cache 32k ctx + compute buffers) = ~32.3 GB idle-serving — 32G would OOM-kill on cold boot; 48G leaves headroom. It does NOT bound the igpu posture's weights: GPUVM (GTT) allocations are not charged to the cgroup — the 2026-11-28 soak reported a 5.2 GB cgroup peak while ~27 GB sat in GTT.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Bind address - keep loopback only.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-chat;
          description = "Public port (served by systemd.sockets.llama-chat, the on-demand activation surface).";
        };

        backendPort = lib.mkOption {
          type = lib.types.port;
          default = ports.llama-chat-backend;
          description = "Private port the llama-server backend binds behind the socat bridge (one proxy hop, llama-vlm pattern).";
        };

        keepAlive = lib.mkOption {
          type = lib.types.str;
          default = "60min";
          description = "Idle TTL: stop the backend after this much time with no bridge traffic. Longer than llama-vlm's because the 23.4 GB reload is the most expensive on the host (~110 GB reads cold).";
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

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.host == "127.0.0.1" || cfg.host == "::1";
              message = "services.llama-chat.host must be loopback. Expose via reverse proxy if you need remote access.";
            }
          ];

          systemd.services.llama-chat = {
            description = "llama.cpp chat server (${cfg.alias}, ${
              if onIgpu then "iGPU" else "CPU"
            } MoE, native tool calls — backend, socket-activated)";
            # ON-DEMAND (2026-11-18, freeze-41 item 30): deliberately NOT
            # wantedBy anything — the public socket owns activation. History:
            # the always-on posture rode late-applications.target (itself the
            # 2026-10-26 fix for the 2026-10-17 boot-transaction load), and its
            # boot-time cold page-in was the freeze #40/#43 storm seed. The
            # per-connection bridge (llama-chat@.service) wants+after this
            # unit, so first client traffic starts the load; the psi-wait-gate
            # below holds it out of IO storms; the idle TTL unloads it after
            # cfg.keepAlive quiet.
            # NO network-online.target (owner catch 2026-10-17): loopback-only
            # binder (host assertion) + local GGUF + loopback probe — `lo` is
            # up before multi-user on every boot (redis/postgres bind loopback
            # with no network gating).
            unitConfig.ConditionPathExists = cfg.modelPath;

            # ROCm runtime env for the HIP build — the llama-rag unit shape:
            # the HSA vars plus the path of the dlopen'ed ROCm libs.
            environment = lib.mkIf onIgpu (
              rocm.env
              // {
                LD_LIBRARY_PATH = rocm.makeLdLibraryPath lib;
              }
            );

            serviceConfig = lib.mkMerge (
              [
                {
                  Type = "exec";
                  User = cfg.user;
                  Group = cfg.group;
                  Restart = "on-failure";
                  RestartSec = "10";
                  # Crash-loop backoff (2026-11-14, the flm ×5 SIGABRT pile-driver
                  # class; documented OOM→restart→re-OOM loop 2026-11-02): a fixed
                  # RestartSec=10 lets a crash-loop re-fire the FULL 23.4 GB model
                  # page-in every 10s under an IO storm. RestartSteps raises the
                  # delay exponentially (10s→…→15min cap) over 5 consecutive
                  # restarts; a stable run resets the step counter. Matches the
                  # fastflowlm / llama-vlm / llama-rag 5-step/15min pattern; no
                  # RestartRandomizedDelaySec jitter to keep restart timing
                  # deterministic for probes (same choice flm/vlm/rag made).
                  RestartSteps = 5;
                  RestartMaxDelaySec = "15min";
                  OOMScoreAdjust = 300;
                  # Quota matches threads (12 of 16 cores): threads share the CPU
                  # time the quota grants, so a 400% quota would silently quarter
                  # the measured ~17 tok/s interactive throughput.
                  CPUQuota = "1200%";
                  # psi-wait-gate (M10.3 pattern, llama-vlm form): holds the
                  # 23.4 GB GGUF cold page-in until io-PSI calms — the freeze
                  # #40/#43 class was exactly a cold load landing inside an IO
                  # storm. --on-exhausted refuse (freeze #56): an exhausted
                  # proceed admitted a 9 G read 7 s before that cut; exhaustion
                  # fails the unit, restart backoff retries, bridges keep
                  # queuing in the socket backlog. 15-min gate.
                  ExecStartPre = "${lib.getExe pkgs.psi-wait-gate} --name llama-chat --psi-max 30 --max-wait-sec 900 --on-exhausted refuse";
                  # Gate budget (15 min) + cold page-in + probe budget below:
                  # the 23.4 GB load measured ~8.3 min cold under concurrent IO.
                  TimeoutStartSec = "35min";
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
                  ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 400 --retry-delay 2 --retry-all-errors http://${cfg.host}:${toString cfg.backendPort}/health";
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
              ]
              ++ lib.optionals onIgpu [
                # GPU device access (llama-rag unit shape): the render group
                # owns /dev/kfd and /dev/dri/renderD128, and the strict device
                # cgroup keeps libdrm's device enumeration away from the NPU
                # node (lib/rocm.nix deviceCgroup).
                rocm.deviceCgroup
                {
                  SupplementaryGroups = [ "render" ];
                }
              ]
            );

            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          # Public activation surface (llama-vlm pattern): Accept=true —
          # every client connection spawns one llama-chat@<conn>.service
          # bridge that dials the backend. Template name MUST match the
          # socket name (systemd 261 naming rule).
          systemd.sockets.llama-chat = {
            description = "llama.cpp chat server '${cfg.alias}' (public socket, on-demand)";
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "${cfg.host}:${toString cfg.port}" ];
            socketConfig = {
              Accept = true;
              # Four concurrent bridges. cpu: llama-server defaults to 4
              # slots, so this caps the bridges below the slot count —
              # beyond that, connections queue in the backlog (slow answer,
              # never refused). igpu: the unit runs --parallel 1, so requests
              # past the first queue INSIDE llama-server instead.
              MaxConnections = 4;
            };
          };

          # Per-connection bridge — template name MUST match the socket
          # (systemd 261). The "llama-chat@" template and the plain
          # "llama-chat" backend never collide as unit names.
          systemd.services."llama-chat@" = {
            description = "llama-chat per-connection proxy: client fd ↔ backend TCP";
            after = [ "llama-chat.service" ];
            wants = [ "llama-chat.service" ];
            serviceConfig = lib.mkMerge [
              {
                Type = "exec";
                ExecStart = "${bridgeConn}/bin/llama-chat-proxy-conn";
                StandardInput = "socket";
                StandardOutput = "socket";
                # socat bridge exits 143 on any planned stop (idle TTL, unit
                # churn, memory-guard sacrifice, shutdown) — without this
                # every planned stop parks the bridge FAILED and exit-4s a
                # deploy running at that moment (fastflowlm 2026-10-07 class).
                # Per-connection bridges are stateless; the socket re-spawns
                # them per client.
                SuccessExitStatus = [ 143 ];
              }
              (harden { MemoryMax = "64M"; })
            ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
          };

          systemd.services.llama-chat-idle = {
            description = "Stop llama-chat backend after idle TTL expires";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${idleCheck}/bin/llama-chat-idle-check";
            };
          };

          systemd.timers.llama-chat-idle = {
            description = "Probe llama-chat idle state every 5 minutes";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5min";
              OnUnitActiveSec = "5min";
              AccuracySec = "1min";
            };
          };

          # Port hygiene: the private backend port joins the audit allowlist
          # beside the registry-covered public port (llama-vlm does the same
          # for its hop). KEY-guarded at the config shape below — a VALUE-side
          # lib.optionalAttrs still defines the option path and throws on
          # evals (VM tests) that never import gatus-coverage-audit (the
          # 2026-11-19 deploy battery catch).

          # Service-integration registry entry: loopback-only daemon exposed
          # via the Layer 2 vHost (https://llama.<domain>) — llama-server's
          # built-in web UI (/) + OpenAI API (/v1) behind oauth2-proxy
          # forward-auth for external clients, LAN bypass; the loopback-bind
          # assertion above still holds (Caddy proxies to the PUBLIC SOCKET,
          # the port never binds externally — external requests activate the
          # backend on demand like loopback ones).
          # NO gatus check + monitored = false (2026-11-18, on-demand posture):
          # an active /health probe is a cold-load treadmill — every probe
          # spawns a bridge, starts the backend, reloads 23.4 GB after the
          # idle TTL (the freeze-#56 visionreviewd class, but at 60 s gatus
          # cadence it would be PERMANENT residency). Wedge detection moves
          # to: the ExecStartPost start contract (a wedged load FAILS the
          # unit, restart backoff heals) + the idle TTL (a wedged serving
          # process stops logging traffic and gets stopped) + consumer-side
          # alerting (ai-meter upstream 502s).
          services.integration = lib.optionalAttrs (options ? services.integration) {
            llama-chat = {
              inherit (cfg)
                enable
                port
                ;
              subdomain = "llama";
              vHost.layer = "protected";
              monitored = false;
              checks = [ ];
              homepage = {
                name = "llama.cpp Chat";
                group = "AI";
                description = "Qwen3.6 35B-A3B brain — OpenAI-compatible, native tool calls (on-demand: first request may wait for the model load)";
                icon = "open-webui.png";
              };
            };
          };
        })
        # KEY-guarded (not value-guarded): defining services.gatus-coverage-audit
        # unconditionally throws on evals (VM tests) that never import the
        # audit module — the 2026-11-19 deploy battery catch. The public
        # port rides the integration registry; only the private backend hop
        # needs the allowlist entry (llama-vlm does the same for its hop).
        (lib.mkIf cfg.enable (
          lib.optionalAttrs (options ? services.gatus-coverage-audit) {
            services.gatus-coverage-audit.allowPorts = [
              cfg.port
              cfg.backendPort
            ];
          }
        ))
      ];
    };
}
