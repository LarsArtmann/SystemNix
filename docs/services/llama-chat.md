# llama-chat — InboxClean's chat agent brain

Always-on CPU llama-server (llama.cpp) serving Lars's abliterated Qwen3.6
35B-A3B MoE with native tool calls, OpenAI-compatible at `127.0.0.1:8850/v1`.

## Why this shape

- **Interactive agent turns** (InboxClean `/chat` dashboard, one turn bounded
  at 3 min) need first-token latency in milliseconds. FastFlowLM (:52625)
  cold-loads its NPU model for 2-5 min, idle-unloads hourly, and is the
  memory-emergency-guard's designated sacrifice — it serves the ASYNC
  consumers (paperless-gpt tagging, commit-message generation) and stays
  theirs. Ollama is owner-rejected as the standard.
- **CPU, not GPU**: the llama.cpp/ROCm path wedges under systemd units on
  gfx1150 (freeze #5, 2026-09-18 — even the rev-pinned 0.3.0 build; see
  llama-rag.nix). The CPU build (0.5.0) is proven in production by
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

## Model

`/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/
Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf` (23.4 GB,
sha256 `8d344a4336d8ea7da0cbfc12792d1471e568be7abe8930c52260698bfd01d731`
(locally measured 2026-10-08; the earlier `1c6a4813…` noted here was the HF
xet-bridge ETag, not a sha256), completed 2026-10-08 — the April download had been
interrupted). Part of the Jan model tree; no service fetch unit. If the
file is missing the unit skips (`ConditionPathExists`) — but conditions
never RE-evaluate, so the `llama-chat-ensure` 10-min convergence timer
(unit + timer in the module, added 2026-10-08) starts the unit once the
file completes; "started" additionally means `/health` serves 200
(ExecStartPost start-contract; TimeoutStartSec 15min covers a cold 23.4 GB
page-in + probe). First convergence live 2026-10-08 20:23–20:26: timer
fired, model cold-loaded 3m16s, `/v1/models` serving — zero sudo.

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

- Monitored: gatus check `llama.cpp Chat` probes `/health` every 60s (200 =
  model mapped and serving; 503 while loading; red when the unit is down or
  skipped). The integration-registry entry lives in this module.
- Swap the brain: change `services.llama-chat.modelPath` + `alias` (the
  inboxclean `LLM_MODEL` follows automatically) — e.g. the dense 27B
  sibling, or a future GPU re-enable once the ROCm wedge is fixed upstream.
- Verify: `curl :8850/v1/models` must list the alias;
  `journalctl -u llama-chat -n 50` for load/wedge signatures (the freeze-#5
  class: 94% single-thread CPU spin after a vocab warning).
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
