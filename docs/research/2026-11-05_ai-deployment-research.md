# What Is Wrong With the Way We Deploy and Use AI — Research Report

**Date:** 2026-11-05 · **Trigger:** owner question after freezes #47/#48 + calm-gate landing (gen 983)
**Method:** incident forensics (forensic bundles, module audit, live probes) checked against external canon: vLLM / Ollama / Triton docs, serverless-GPU cold-start literature (OSDI'24/OSDI'26), systemd + Kubernetes + AWS restart-policy canon, vector-DB ingest pathology docs, kernel cgroup-v2 docs. Live probes re-verified 2026-11-05.

## Verdict per theme

### 1. Demand classification — we have none; canon demands one

- **Canon:** scale-to-zero is "often a liability" for LLMs (KServe/Knative guidance — 16 GB of weights = a minute-plus cold start; serverless GPU cold starts run 40–120 s, weights dominate). The standard answer is a per-endpoint decision: warm replica for latency-critical, scale-to-zero only for light/spiky demand. Ollama's `keep_alive` 5-minute idle-unload is the only mainstream *automatic* idle unload; Triton and vLLM make residency an *orchestrator decision* (explicit load/unload API, opt-in sleep mode). Tiered reclamation: KV cache → weights-to-CPU → discard.
- **Us:** "enabled" is the only mode. `nsfw-classifier` is boot-resident **and** runs a batch scan timer (`nsfw-immich-scan`) — spiky+batch demand paying continuous residency. `fastflowlm`/`llama-vlm` are socket-activated (Accept=true) — the correct demand-driven pattern, already canon-shaped. `monitor365`/`dnsblockd` are genuinely continuous (resident is right).
- **Divergence:** spiky and batch consumers are boot-resident. Canon fix: measure per-service request rates, then socket-activate / idle-stop the spiky ones.

### 2. Residency mechanics — our cold reads are llama.cpp working exactly as designed

- **Canon:** llama.cpp defaults to lazy mmap, **but llama-server's default warmup eagerly faults the entire model at startup** — so every boot-started llama-server IS a full-model cold read at boot, by design. Multi-model practice: pin what fits (`--load-mode mmap+mlock`), page-cache the rest (vmtouch pre-warm), reload on demand.
- **Us:** the measured T+120 s cold readers (flm 12.0 G, vlm 9.7 G, monitor365 7.5 G, embeddings 6.2 G, …) are warmup fault-ins. Nothing serializes or pre-warms them; the calm-gate now refuses them on recovery boots (landed 2026-11-05). `stability:260` (PSI entry gate) is DONE in spirit; **`stability:261` (serialize concurrent cold loads) is still open and canon-endorsed** — six warmups racing one cold QLC is the pile-up.
- **Verdict:** mechanics understood, discipline missing: no per-model pin/pre-warm/reload decision has ever been made.

### 3. Restart policy — the hardest divergence, one line to fix

- **Canon:** systemd ≥254 ships `RestartSteps`/`RestartMaxDelaySec` exponential backoff (man page: "values between 3 and 5 are good choices"); v262 adds `RestartRandomizedDelaySec` jitter *explicitly because* simultaneously failing instances cause "resource congestion". Kubernetes CrashLoopBackOff: 10 s doubling to a 5-min cap, reset after 10 min healthy. AWS Builders Library: retries are selfish — naive restarts delay recovery.
- **Us:** fleet-wide `Restart=on-failure` + fixed `RestartSec=10` + `startLimitBurst=5/300s`. Worst case = **five full model loads in ~50 s** of crash-loop (the flm-real ×5 SIGABRT pile-driver, 2026-11-05, is exactly this shape).
- **Fix:** `RestartSteps=4` + `RestartMaxDelaySec=10min` on every model-loading unit (verify NixOS systemd ≥254 first). Canon-identical, config-only.

### 4. Ingest idempotency — our storm engine matches a documented industry pathology

- **Canon:** full-backlog re-ingestion is the classic RAG anti-pattern; canonical fixes are content-hash doc-id idempotency (LlamaIndex's ingestion cache), incremental ingest, durable checkpoints, batched upserts (64–256), and building new collections off-to-the-side instead of in-place churn. Vector DBs document the amplification: Qdrant's vacuum optimizer triggers at 20 % deletes; Chroma's WAL **replays on every startup** — a huge WAL means slow startups and continuous write pressure.
- **Us:** "163 GB re-embed backlog class since #45" (llama-rag.nix:71-73); the pre-switch embeddings instance measured **465.4 GB written / 7.2 GB read in 4h20 m (65:1)** — backlog reprocessing running as a side-effect of daemon uptime, never as a scheduled, checkpointed, budgeted job. Write-destination attribution still open (queued, ai-stack).
- **Fix direction:** extract re-embed work into a calm-window timer job with content-hash idempotency; the resident server then only serves queries.

### 5. Admission control — we are AHEAD of canon here

- **Canon:** PSI is the canonical kernel pressure telemetry (systemd-oomd has used it since Fedora 34); backoff+jitter to avoid thundering restart herds.
- **Us:** `psi-wait-gate` + `post-crash-calm-gate` are PSI-based admission control — systemd-oomd-class design, plus the recovery-boot failure-memory layer that the cloud implements as warm-pool orchestration. Keep; this is the strongest part of the stack.

### 6. IO enforcement — coherent and verified live

- **Canon:** `io.weight`/ioprio are honored only under BFQ (or blk-iocost, disabled by default); `mq-deadline`/`none` ignore them.
- **Us:** both NVMe run **BFQ** (live-verified 2026-11-05) and ioTier fragments set `IOSchedulingClass` best-effort/idle → **enforced, not decorative**. Accepted trade: BFQ costs some sequential throughput on NVMe vs none/mq-deadline; fairness won.

### 7. Ghost artifacts — no industry equivalent; our eval-guard layer is the unique lever

- The 19-day unwired calm-gate class. No check exists that a `pkgs/` entry is actually consumed by a module/app. An eval-time "unconsumed artifact" gate closes the class.

## Ranked deltas (Pareto order)

| # | Delta | Cost | Kills |
| - | ----- | ---- | ----- |
| 1 | Restart backoff (`RestartSteps=4`, cap 10min) on model-loader units | one line ×4 modules | crash-loop model-reload pile-drivers |
| 2 | Extract re-embed backlog → calm-window, content-hash-idempotent timer job | design + module work | the storm engine at root |
| 3 | Demand profiling (request rates per AI service) → socket-activate / idle-stop spiky ones | measurement + decision | guaranteed boot cold-reads nobody asked for |
| 4 | Ghost-package detector eval check | small check | 19-day-unwired class |
| 5 | Serialize concurrent cold loads (`stability:261`, existing) | After=-chain or slot | six-warmup boot pile-up |
| 6 | 465 GB write-destination attribution (existing §b follow-up) | forensics | unknown amplifier |

## Sources

- vLLM sleep mode: docs.vllm.ai/en/latest/features/sleep_mode/; vLLM blog 2025-10-26
- Ollama keep_alive (5 m default unload): docs.ollama.com/faq, /api/generate
- Triton model control (NONE default = load all, EXPLICIT = API load/unload): NVIDIA Triton model_management docs
- Serverless GPU cold starts (40–120 s; weights dominate; ServerlessLLM OSDI'24 reduces 10–200×; Foundry arXiv 2604.06664): cloud.google.com AI cold-start guide; modal.com/docs/guide/cold-start; spheron.network 2026; kubezilla KServe 0.20 tutorial
- llama.cpp mmap/warmup/load-mode: llama-server manpage; PR #8712 (warmup); discussions #1876, #26469; byteiota.com load-mode article
- systemd RestartSteps/RestartMaxDelaySec (v254), RestartRandomizedDelaySec (v262): systemd.service(5)
- K8s CrashLoopBackOff (10 s → 300 s cap, 10-min reset): kubernetes.io pod-lifecycle
- Restart-storm canon: AWS Builders Library, "Timeouts, retries, and backoff with jitter" (Brooker 2019)
- Ingest idempotency + vector-DB write amplification: docs.llamaindex.ai ingestion_pipeline; qdrant.tech optimizer + bulk-upload docs; cookbook.chromadb.dev performance/maintenance
- PSI canon: systemd-oomd.service(8); Fedora 34 change (systemd-oomd default)
- cgroup v2 IO controller enforcement matrix: docs.kernel.org/admin-guide/cgroup-v2.html
