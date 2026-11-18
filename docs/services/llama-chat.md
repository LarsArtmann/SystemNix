# llama-chat — InboxClean's chat agent brain

Socket-activated CPU llama-server (llama.cpp) serving Lars's abliterated
Qwen3.6 35B-A3B MoE with native tool calls, OpenAI-compatible at
`127.0.0.1:8850/v1`. On-demand since 2026-11-18 (freeze-41 report item 30,
the module's sanctioned return path after the Nov 2-3 freeze chain retired
the always-on posture): a public systemd socket (`llama-chat.socket`,
Accept=true) owns :8850, each client connection spawns a per-connection
socat bridge (`llama-chat@<conn>.service`) that dials the private backend
(`llama-chat.service`, :8851), and the backend's 23.4 GB cold load is
**psi-wait-gated** — it waits for io-PSI calm (≤30%, up to 15 min) before
mapping the model, so a first request under an IO storm queues in the
socket backlog (slow answer, never a refused one). An idle TTL (60 min
without bridge traffic) unloads the model; the next connection reloads
it. Nothing cold-loads at boot or at deploy anymore — the
`llama-chat-ensure` convergence timer is retired with the always-on
posture (the socket IS the convergence).

## Why this shape

- **Interactive agent turns** (InboxClean `/chat` dashboard, one turn bounded
  at 3 min) need first-token latency in milliseconds. FastFlowLM (:52625)
  cold-loads its NPU model for 2-5 min, idle-unloads hourly, and is the
  memory-emergency-guard's designated sacrifice — it serves the ASYNC
  consumers (paperless-gpt tagging, commit-message generation) and stays
  theirs. Ollama is owner-REJECTED as an AI-stack foundation (standing
  directive 2026-10-12: "bad abstraction on top of llama.cpp — I do not want
  ollama"). Never wire a SystemNix service to it. The evo-x2 instance was
  REMOVED the same day (service, gatus check, dashboard tile, SigNoz rule,
  DMS widget, port 11434, ai-models paths); `/data/ai/models/ollama` (~15 G)
  is owner-reclaim residue.
- **CPU, not GPU**: the llama.cpp/ROCm path wedges under systemd units on
  gfx1150 (freeze #5, 2026-09-18 — even the rev-pinned 0.3.0 build; see
  llama-rag.nix). The CPU build (0.6.0 at the 2026-10-10 deploy; 0.5.0 proven earlier) is in production
  llama-vlm. A 3B-active MoE keeps CPU tokens interactive-fast.
- **Native tool calls**: `--jinja` applies the GGUF's Qwen3.6 chat template,
  so OpenAI-format `tools` produce real `tool_calls` responses (verified
  live 2026-10-08). The InboxClean agent drives Gmail tools through this.
- **Thinking OFF** (`--chat-template-kwargs {"enable_thinking":false}`,
  2026-10-10): the Qwen3.6 template defaults `enable_thinking=true`, so every
  completion opened a `<think>` block before any content. At CPU token rates
  that tax is fatal: measured live, a trivial plan probe burned 600/600
  `max_tokens` on reasoning with EMPTY content (`finish_reason=length`);
  InboxClean's real turn (4.9k-token plan context) never finished thinking
  inside the app's 3-minute turn budget — all 4 turns since the brain landed
  died with `context deadline exceeded` (the 2026-10-10 "still broken"
  incident; two flavors, both this: ollama-404 pre-wiring on 10-08, deadline
  on 10-10). Thinking disabled server-side so consumers that send no
  template kwargs (InboxClean's OpenAI client) get it too. Same probe with
  thinking off: 80 tokens, `finish_reason=stop`, valid plan JSON.
- **paperless-triage verdicts (2026-10-27, via ai-meter):** the confidence
  gate in front of paperless-gpt asks one-word YES/NO verdicts with
  `logprobs`+`top_logprobs` (margin = renormalized p(YES)−p(NO), the gate
  signal — llama-server's logprobs are the REASON this endpoint won over
  flm v1.0.2, which has none; live-proven: Faktura → margin +0.985, letter
  → −0.985). ≤5 sequential calls per 5-min sweep, 4k-char prompts, 180 s
  per-call timeout — negligible against interactive turns, and under CPU
  starvation it times out into a refusal (nothing routes, the verdict-down
  Gatus check fires) rather than queuing.

## Model

**Abliterated/uncensored is a HARD requirement for this brain** (owner
directive 2026-10-12: "gpt-oss-120b is OLD and NOT Abliterated so fucking
no!") — mainstream-safety-tuned models are disqualified regardless of
benchmarks or tool-calling reputation; model swaps stay within the
abliterated Qwen3.6-35B-A3B family (HauhauCS tunes / distills /
better quants of the same architecture).

`/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/
Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf` (23.4 GB,
sha256 `8d344a4336d8ea7da0cbfc12792d1471e568be7abe8930c52260698bfd01d731`
(locally measured 2026-10-08; the earlier `1c6a4813…` noted here was the HF
xet-bridge ETag, not a sha256), completed 2026-10-08 — the April download had been
interrupted). Part of the Jan model tree; no service fetch unit. If the
file is missing the backend unit skips (`ConditionPathExists`) and the
socket's bridges time out after 30 min — the model file is the one
external dependency. "Started" still means `/health` serves 200 on the
BACKEND port :8851 (ExecStartPost start-contract; TimeoutStartSec 35min
covers the psi-wait gate + a cold 23.4 GB page-in + probe budget). The
2026-10-08 ensure-timer convergence machinery (timer re-starting a
condition-skipped unit) was RETIRED with the always-on posture on
2026-11-18 — the socket IS the convergence now.

Source: <https://huggingface.co/HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive>

## Measured (2026-10-08, uncapped manual run mirroring unit flags)

- Load: 3m16s from warm page cache; ~8.3 min cold under concurrent IO
  (the unit's 15min start budget covers it).
- Throughput: ~17 tok/s plain generation (12 threads); a 167-token tool
  call answered in 16s. `CPUQuota = 1200%` matches threads=12 — a 400%
  quota would quarter this.
- Tools: `finish_reason: tool_calls` with parsed arguments in auto mode —
  the abliterated tune keeps the Qwen3.6 tool template intact.

## Consumers

- **InboxClean** (`modules/nixos/services/inboxclean.nix`):
  `LLM_PROVIDER=openai`, `OPENAI_BASE_URL=http://127.0.0.1:8850/v1` (keyless
  — llama-server ignores Authorization), `LLM_MODEL=<alias>`. The alias and
  port are wired from this module's options (single source of truth).
  `inboxclean doctor` probes `/v1/models` and fails at deploy time if the
  served id ever drifts from `LLM_MODEL`.

## Operations

- Exposed: `https://llama.home.lan` (integration-registry entry: `subdomain = "llama"`, Layer 2 `protected` vHost — oauth2-proxy forward-auth for external clients, LAN bypass; Caddy proxies to the PUBLIC SOCKET, so external requests activate the backend on demand like loopback ones). Serves llama-server's built-in web UI at `/` and the OpenAI API at `/v1`.
- NOT actively probed (on-demand posture, 2026-11-18): no gatus check and
  no dashboard checkUrl — an active /health probe is a cold-load treadmill
  (the freeze-#56 visionreviewd class; at gatus's 60 s cadence it would
  mean permanent residency, defeating the whole design). Wedge detection:
  the ExecStartPost start contract fails a wedged load (restart backoff
  heals), the idle TTL stops a wedged server that stopped serving traffic,
  and consumers alert (ai-meter upstream 502s). `monitored = false` in the
  registry because a socket-activated backend's inactive state is NORMAL,
  not a health signal.
- Swap the brain: change `services.llama-chat.modelPath` + `alias` (the
  inboxclean `LLM_MODEL` follows automatically) — e.g. the dense 27B
  sibling, or a future GPU re-enable once the ROCm wedge is fixed upstream.
  - Bench sync-check (modelPath split-brain guard, 2026-11-05):
    `scripts/bench-cold-load.sh` derives its default model from THIS
    module's `modelPath` option default at runtime — a swap via the module
    default updates the bench automatically. A swap via an override
    elsewhere (configuration.nix etc., leaving this module's default stale)
    is INVISIBLE to that derive — pass `MODEL=<gguf>` to the bench
    explicitly in that case.
- Verify: `curl :8850/v1/models` must list the alias (first request after
  an idle unload pays the cold load — watch `systemctl status
  llama-chat@*.service` for live bridges and `journalctl -u llama-chat -n 50`
  for load/wedge signatures, the freeze-#5 class: 94% single-thread CPU
  spin after the vocab warning).
- The 23.4 GB expert pool lives in page cache (charged to the unit on a
  cold cache); measured idle-serving footprint ~32.3 GB (weights + ~8.9 GB
  anon KV/compute), so `memoryMax = "48G"` and harden derives
  `MemoryHigh = 80% x 48G = 38.4G`. NEVER merge `MemoryMax` outside a bare
  `harden {}` call: the throttle watermark derives from harden's own
  ARGUMENT — the first deployment silently ran MemoryHigh at 410 MB
  (443 MB peak, 10.7 GB swapped, 1h53m stuck load, 45s timeout on a
  16-token reply). Eval-enforced since 2026-10-09: `memory-watermark-audit.nix`
  throws on ANY unit whose final `MemoryHigh` < 50% of `MemoryMax`
  (negative-tested in `scripts/negative-test-lints.sh`, group `memory`);
  live residue probe: `cat /sys/fs/cgroup/system.slice/llama-chat.service/memory.events`
  — a nonzero `high` counter = throttling since start (resets on restart).
  If the memory-emergency-guard ever trips BECAUSE of this residency, add
  `llama-chat.service` to its churn list — do not silence the guard.
