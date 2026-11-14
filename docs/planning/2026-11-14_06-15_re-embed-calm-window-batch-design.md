# Design: calm-window idempotent re-embed batch job (llama-embeddings backlog extraction)

**Status:** design (unimplemented). **Date:** 2026-11-14.
**Source rows:** docs/todo/ai-stack.md re-embed-backlog row; docs/research/2026-11-05_ai-deployment-research.md §4.
**Measured problem size (see docs/status/2026-11-14_06-15_ai-demand-profile-and-write-attribution.md):**
the re-embed backlog runs at ~1,500 req/h for 14-hour stretches (18k req/h peak hour, 2026-11-05/06/07)
against an 8-11 req/h query baseline — while the serving unit's cgroup write amplification hit
645 GB written / 8.5 GB read over 5h32m (2026-11-08 invocation).

## Problem

Paperless' document-AI task queue re-requests embeddings for its whole corpus as a side-effect of
daemon uptime and settings churn ("163 GB re-embed backlog class since freeze-#45"). The work is
unbounded, uncheckpointed, and competes with interactive queries on the resident bge-m3 server —
and each re-run re-processes documents that were already embedded (no idempotency at the doc level),
so the same tokens are re-computed across epochs.

## Target design

### Shape: timer-driven oneshot consumer + query-only resident server

- `systemd.services.llama-reembed-batch` (Type=oneshot) + `systemd.timers.llama-reembed-batch`
  (OnCalendar in the 01:00–05:00 window, Persistent=true, RandomizedDelaySec=15min). The resident
  `llama-embeddings.service` stops processing backlog churn and serves queries only.
- Admission control: ExecStartPre = existing `psi-wait-gate` (PSI-max gate, the fastflowlm/llama-vlm
  pattern) + a CPU-quota (CPUQuota=100%) and ioTier.background so the batch never becomes a storm
  source. The post-crash-calm-gate dependency already guards the embeddings server; the batch job
  adds its own gate so a refused window simply skips the run (next timer fires).

### Idempotency: content-hash doc-ids

- Document id = `sha256(mime || source-mod-time || extracted-text)` — NOT paperless' numeric id, so
  re-OCR/re-extraction producing identical text is a cache hit, and any text change is a new key.
  (LlamaIndex ingestion-cache canon.)
- Embedding cache: append-only JSONL or sqlite keyed by content-hash → vector (1024-dim bge-m3).
  Stored under a StateDirectory (`/var/lib/llama-reembed/`), zstd-compressed.
- Upsert path: fetch cached vector when hash matches; else POST /v1/embeddings with batch size
  64 (bge-m3 latency budget: measured 500-800 tokens/request at ~3s/task → 64-input batches
  amortize the per-request overhead without exceeding the 2048 ubatch).

### Durable checkpoints

- Checkpoint file (last-completed paperless document id + content-hash cursor) written after every
  N=500 documents (fsync). A killed run resumes at the cursor; a failed document is logged and
  skipped (fail-open, per the nsfw-immich-scan precedent) — never re-failed into a loop.
- End-of-run marker with run stats (processed/skipped/cached/failed) into the textfile-collector
  dir for SigNoz visibility: `llama_reembed_documents_processed_total` etc.

### Consumer side

- The consumer script polls paperless' document API (search-after cursor on ids, sorted
  deterministically) — no paperless-side code changes; the job is deployment-only wiring like
  `nsfw-immich-scan` (ADR-061 pattern).

## Non-goals / open questions

- Does NOT change paperless' own classification embeddings (PAPERLESS_ENABLE_* paths) — that
  churn is upstream behavior; this job only owns the RAG-index lane.
- Write-amplification root cause is still unattributed (see the status report): the 65:1
  write:read ratio has no canonical llama-server mechanism, so the design targets the WORK
  SCHEDULING; if instrumentation (follow-up row) shows the writes come from an implicit
  llama-server surface, a llama.cpp upstream issue is the fix channel instead.
- Owner decision pending: whether paperless' backlog churn should ALSO be gated at the source
  (paperless task-queue drain rate) — the batch job bounds the damage either way.
