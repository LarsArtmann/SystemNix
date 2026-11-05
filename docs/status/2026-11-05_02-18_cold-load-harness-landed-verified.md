# Cold-Load Benchmark Harness Landed + Verified — 2026-11-05

**Task queue:** storage batch item 3 (`Task-Queue-ID: 000001a1a7beb2a2a335067e979f00000000`), Source: docs/planning/2026-11-03_data-redesign-latency-first-design.md §4/§5. **Instance:** tq-000001a1a7 re-dispatch (plan header EXECUTING marker, §5 probes only).

## What landed

`scripts/bench-cold-load.sh` — the repeatable before/after probe every /data redesign leg is gated on (A1 proof, A2 escalation trigger). Measures wall time from llama-server exec to first `/health` 200 on a scratch port, with fixed flags (`--ctx-size 4096 --n-gpu-layers 99 --load-mode none`), PSI-gated, file-scoped cold-cache eviction, one compact JSON line per run (`OUT=<file>` appends JSONL). Default model = llama-chat's configured 23.4G Qwen3.6-35B-A3B Q4_K_P (the M12 boot-storm pain case). Design decisions + live spec: design doc §5 LANDED bullet + docs/agents/storage.md harness paragraph.

## Verification matrix (all live on evo-x2, 2026-11-05 01:4x–02:1x)

| check | result |
| --- | --- |
| bash -n + shellcheck | green |
| PSI gate refusal in a storm (io avg10 53–83%) | ABORT rc=1, fix guidance printed |
| PSI_ACCEPT=1 noisy-window smoke | GREEN end-to-end (below) |
| held-port guard (PORT=8848, live embedder) | FAIL rc=1, rogue-port-holder guidance |
| unreadable-model guard | FAIL rc=1 with fix |
| COLD=drop without root | FAIL with the no-new-privileges explanation (agent sandbox blocks sudo entirely — typed AND script-internal) |
| server-death detection | caught instantly via /proc state=Z (a plain `kill -0` NEVER fires for unreaped background children — zombies exist until wait; cost one wasted 1200s poll before the fix) |
| cleanup | no leaked llama-server on the scratch port after runs; tmpdir removed (KEEP_RAW=1 preserves logs) |
| JSONL compactness | jq -c (default pretty output broke one-object-per-line) |

## Green smoke record (accepted-noisy, storm-depressed by design)

```json
{"schema": 1, "ts": "2026-11-05T02:12:28+01:00", "probe": "cold-load", "model": "/data/ai/models/gguf/bge-m3.gguf", "bytes": 1157671200, "server": "/run/current-system/sw/bin/llama-server-rocm", "cold": "vmtouch-fadvise", "load_mode": "none", "port": 18849, "ctx": 4096, "ngl": 99, "psi_gate_max": 20, "psi_pre": 83.01, "psi_post": 51.52, "psi_max_during": 86.6, "psi_avg_during": 67.3, "load_s": 157.02, "mb_s": 7, "psi_accepted": true}
```

vmtouch evicted 282,635 pages (1G) before launch; the 7 MiB/s figure is the honest storm number the PSI gate exists to prevent contaminating real baselines with.

## Build-time discoveries (documented in-script)

- `--no-mmap` is GONE on llama.cpp 0.6.0 → `--load-mode` (none/mmap/mlock/dio).
- LM=dio (DirectIO) observed SIGABRT mid-load under memory pressure on this build (one core-dump observed; not reproducible cleanly) → default LM=none, dio stays opt-in.
- Embedding GGUFs (bge pair) GGML_ASSERT-crash without `--embedding` → EMBED=1 knob.
- vmtouch auto-resolves via `nix build nixpkgs#vmtouch` when absent from PATH.

## Pending

- The strict-gate (PSI_MAX=20) baseline run on the default 23.4G model was launched with PSI_WAIT_S=7200 and was still inside its wait loop at authoring time (box under a real IO storm, io avg10 56–83%) — either it lands a clean baseline JSONL in ~/.cache/data-ai-compsize/baseline-qwen35b.jsonl when the window opens, or it ABORTS at the 2h cap exactly as designed; rerun `OUT=... bash scripts/bench-cold-load.sh` in any calm window for the A1 before-number.

## Surfaces updated (this batch)

- scripts/bench-cold-load.sh (new, executable).
- Design doc §5 probe 2 → LANDED with live spec; docs/todo/storage.md row 222 → [x] LANDED; TODO_LIST.md row → [x] LANDED.
- docs/agents/storage.md → harness paragraph (usage + flags + JSONL contract).

## Follow-up harvest

- kill_pid cleanup-trap bug discovered in scripts/bench-hot-file.sh:81 + scripts/bench-samsung-livefs.sh:146 (function defined nowhere; both EXIT traps dead) → TODO_LIST new [ready] row. No other direct follow-ups; deliberately not harvested: baseline number itself (the script owns it, self-gated on PSI, no agent row needed).
