# TODO — Ai-stack

FastFlowLM (NPU), llama-rag/llama.cpp (incl. the upstream bisect), ollama, GPU/ROCm runtime, embeddings/RAG consumers, whisper batches.

Domain LIBRARY of the [TODO system](../../TODO_LIST.md) — every open item for this domain, any lifecycle. The dispatch QUEUE of agent-actionable (`[ready]`) items is `TODO_LIST.md`; the tq pool harvests only the queue.

House rules (enforced by convention, see AGENTS.md → "TODO System"): file an item under the domain that owns the FIX, not the symptom it mentions; one item = one ask + `**Source:**` pointer — verification narratives go to the status report, never the item; `[x]` rows are pruned to `CHANGELOG.md` at every pass; NO system-state narratives here (AGENTS.md and `docs/services/*` runbooks own state).

Tag legend: `[ready]` agent-actionable · `[blocked:user]` needs sudo/browser/external console/owner hands · `[blocked:push]` needs an upstream push/tag (agents implement, never push) · `[blocked:deploy]` waits on a deploy · `[watch]` time-gated verification · `[decision]` owner question.

## Prioritized

- [ ] [decision] **MiniMax quota decision (carried ×5)** — upgrade / PAYG / wait for reset
- [ ] [watch] **flm upstream release watch (T3.4)** — v1.0.2 SIGABRT heap bug recurrence watch (20:17 coredump 08-31); v1.0.3 retry gated on the 7.2.2 reboot. **Source:** stability plan T3.4

## Backlog (untriaged harvest)

- [ ] [watch] **llama-rag monitoring depth** — Gatus FUNCTIONAL probes (`/v1/embeddings` 1024-dim + `/v1/rerank` ranking — liveness-only today) + a GPU-utilization/VRAM metric with a SigNoz >90% alert (post RAG-ungrey; the 20260911 regression row owns the outage itself). **Source:** `archived/2026-08-20_05-19_*` §f.19/23-27
- [ ] [decision] Paperless semantic reranking direction — drop the `:8849` reranker side of llama-rag (and its Gatus/smoke checks) at re-enable, or file/track a paperless-ngx feature request first — BLOCKED: does the owner actually want reranking in paperless semantic search? (paperless 3.1.3 has zero reranker support, source-verified; a proxy sidecar is NOT semantically valid — reranking is query-time)
- [ ] [watch] Post-deploy llama-rag verification chain: `/health` 200 on :8848/:8849, `/v1/embeddings` 1024-dim, `/v1/rerank` correct ranking, first PRODUCTION run of `llama-rag-leak-metrics` as root (`leaked_instances 0`; agent-run as lars miscounts), Gatus "llama.cpp Leaked Instances" green. **Source:** docs/status/archived/2026-09-18_02-45_task-000001a0b1d43f78d4325627260af417c7ed.md §b
- [ ] [blocked:user] **flm-dark history delivery proof (narrowed 2026-09-19)** — verify Gatus/Discord alerted during the 7 flm-dark days; the aggregate check already exists ("FastFlowLM NPU LLM", fail-closed on `state_failed`/`start_limit_hit`) and the PMA fallback-ratio recalibration is implemented — the only residual is gatus sqlite history, root-only (`/var/lib/private/gatus/gatus.db`). **Source:** `2026-09-14_09-31` §f.22-23 + 2026-09-19 ai-stack session §b.4/b.7
- [ ] [blocked:user] **Execute the llama-rag re-enable soak (harness SHIPPED 2026-09-19; execution root+owner-gated)** — `sudo ./scripts/llama-rag-soak.sh --server <candidate llama-server> --model /data/ai/models/gguf/bge-m3.gguf --minutes 10` soaks a candidate build under a sandbox mirroring the deployed units (rocm deviceCgroup + HSA env via systemd-run) and judges SPIN on CPU-time deltas (intermittent-spin aware); a PASS verdict is the re-enable gate. Suspect set is upstream of llama.cpp (ROCm runtime / kernel / GPU-state — the pinned 0.3.0 build spun identically, freeze #5). Quiet-IO window only. **Source:** docs/status/2026-09-19_00-19_task-000001a0b68a0a38da1c4a597637e0401f85.md §c.1/§f.1-2
- [ ] [decision] **FastFlowLM staged go-live: v1.0.2 → current upstream (v1.0.6 at last check)** — the long-standing EADDRINUSE corpse obstacle is GONE (backend loads the model fully, 2026-09-20 proof); a bump still needs the live-serve validation + one-time weights re-pull discipline (Q4_K weights hash-mismatch the new manifest) and a release-notes check for the v1.0.2 crash class. Note: guard restore-cap kept the socket down all storm-day by design — socket health is NOT evidence about the binary. **Source:** AGENTS FastFlowLM section; 2026-09-20 deploy-review session §c/§f.5
- [ ] [watch] **llama-vlm live verification + soak** — ports 8127/8128 confirmed LISTENING 2026-09-20 (module enabled, healthy by the dark-guard's accounting) but the eval warning's demanded soak test has never run; verify a real inference through each socket (e4b + cap) and cold-load timing before relying on them for the nightly classify+caption consumer. **Source:** CHANGELOG llama-vlm entry; 2026-09-20 session port probe
