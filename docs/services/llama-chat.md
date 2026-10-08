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

## Model

`/data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/
Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf` (23.4 GB,
sha256 `1c6a4813…`, completed 2026-10-08 — the April download had been
interrupted). Part of the Jan model tree; no service fetch unit. If the
file is missing the unit skips (`ConditionPathExists`).

Source: <https://huggingface.co/HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive>

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
- The 23.4 GB expert pool lives in page cache; `MemoryMax = 32G` bounds the
  unit. If the memory-emergency-guard ever trips BECAUSE of this residency,
  add `llama-chat.service` to its churn list — do not silence the guard.
