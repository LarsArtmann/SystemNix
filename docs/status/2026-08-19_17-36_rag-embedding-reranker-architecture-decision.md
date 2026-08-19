# Status Report: RAG Embedding + Reranker Architecture Decision

**Date:** 2026-08-19 17:36  
**Session focus:** Evaluating whether to add HuggingFace Text Embeddings Inference (TEI) permanently, and finding the best reranker-capable serving stack for the homelab

---

## Executive Summary

The user asked whether to add [HuggingFace text-embeddings-inference](https://github.com/huggingface/text-embeddings-inference) permanently. Over three rounds of discussion, the recommendation evolved significantly as I corrected my own mistakes. The final answer: **don't add TEI, don't add Docker, don't add any new inference engine**. The existing Nix-native AI stack (Ollama + llama.cpp) already covers both embeddings and reranking. The only new work is a small `llama-server` reranker service module + one Ollama model pull + a few Paperless env vars.

---

## a) FULLY DONE

### Research: TEI vs alternatives vs existing stack

| Item | Status | Notes |
|---|---|---|
| Repo scan for existing TEI/embedding/reranker references | ✅ Done | Zero TEI references. Embeddings only exist as: deliberately-disabled `loadEmbed` in fastflowlm.nix, unset `PAPERLESS_AI_LLM_EMBEDDING_*` vars in paperless.nix, and directory paths in ai-models.nix. |
| Ollama existing config reviewed | ✅ Done | `ai-stack.nix` — ROCm-backed, `:11434`, `OLLAMA_MAX_LOADED_MODELS=1`, always-on (wantedBy multi-user.target). Already serves OpenAI-compatible `/v1/embeddings`. |
| TEI capabilities + tradeoffs researched | ✅ Done | Rust-based, one model per container, `/rerank` endpoint, lean footprint. No gfx1150 ROCm support listed. |
| Infinity (michaelfeil/infinity) researched | ✅ Done | Python/FastAPI, multi-model per instance, `/rerank` endpoint, `latest-cpu` Docker image. Reported OOM/timeout under sustained load (not relevant for batch-of-1). |
| vLLM reranking support researched | ✅ Done | Full `/v1/rerank` endpoint, officially supports gfx1150 (Ryzen AI MAX). But 3GB+ image — sledgehammer for a 568M cross-encoder. |
| **llama.cpp reranking support researched** | ✅ Done | **This is the finding that changed the recommendation.** Native `/rerank` + `/v1/rerank` endpoints (PR #9510, merged Sept 2024). bge-reranker-v2-m3 is the reference model with a preset flag. BertForSequenceClassification merged (PR #13858). `llama-cpp-rocwmma` already packaged in SystemNix with a `llama-server-rocm` wrapper. |
| **Ollama reranking support researched** | ✅ Done | **Does NOT support reranking.** No `/rerank` endpoint, no code, issue #3368 open since Mar 2024, multiple unmerged PRs. Confirmed via API docs, OpenAPI spec, source code search, and issue tracker. |
| Existing Paperless AI config reviewed | ✅ Done | `paperless.nix` lines 111-136: `PAPERLESS_AI_LLM_*` → FastFlowLM. Embedding vars deliberately absent with a 10-line comment explaining why (`--embed 1` breaks the NPU model load). |
| Existing FastFlowLM module reviewed | ✅ Done | Socket-activated, `:52625`, `loadEmbed` option exists but documented as broken. |
| Port registry reviewed | ✅ Done | `lib/ports.nix` — no reranker port exists. Ollama at 11434, FastFlowLM at 52625/52626. |
| Final architecture recommendation delivered | ✅ Done | See "Final Recommendation" below. |

---

## b) PARTIALLY DONE

### Nothing — this was a research/decision session, not an implementation session. All research items in (a) are complete; all implementation items in (c) are not started.

---

## c) NOT STARTED

All implementation work — deferred pending user confirmation:

1. **`lib/ports.nix` — add `reranker` port** (e.g. `reranker = 8848;` or similar unused port)
2. **`modules/nixos/services/llama-reranker.nix` — new module** — a lightweight `llama-server-rocm` service running `--reranking --embedding --pooling rank -m bge-reranker-v2-m3.gguf` on the new port. `MemoryMax=2G`, `ioTier.background`, GPU-accelerated via existing ROCm wrapper. No socket activation needed (1GB model, not 13.6GB).
3. **GGUF model acquisition** — bge-reranker-v2-m3 needs to be in GGUF format. Options: (a) community GGUF from HuggingFace, (b) `convert_hf_to_gguf.py` from llama.cpp repo. Model goes in `/data/ai/models/` (the ai-models.nix paths structure already exists).
4. **`platforms/nixos/system/configuration.nix` — enable the new module**
5. **`paperless.nix` — add embedding env vars** pointing to Ollama: `PAPERLESS_AI_LLM_EMBEDDING_BACKEND`, `PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT`, `PAPERLESS_AI_LLM_EMBEDDING_MODEL`, `PAPERLESS_AI_LLM_EMBEDDING_API_KEY`
6. **`ai-stack.nix` — bump `OLLAMA_MAX_LOADED_MODELS` from 1 to 2** so the chat model and `bge-m3` embedding model can co-reside (bge-m3 is ~1.2GB, negligible against 34 GiB VRAM)
7. **Ollama model pull** — `ollama pull bge-m3` (or `bge-m3` equivalent — need to verify Ollama has it; if not, `nomic-embed-text` as fallback, though user said it's "too weak")
8. **Gatus health check** — on the reranker `/health` endpoint
9. **Homepage tile** — optional, if the user wants a visible tile for the reranker
10. **`AGENTS.md` update** — document the RAG architecture decision, the llama.cpp reranking finding, and the Ollama embedding + llama-server reranking split
11. **Paperless reranker wiring** — verify whether `paperless-ai` exposes a `PAPERLESS_AI_LLM_RERANKER_*` env var. It uses llama-index under the hood which supports rerankers natively, but the Paperless AI plugin may not expose it yet. If not, the reranker endpoint is ready for when it does, or for a custom search interface.
12. **VM test** — test the reranker service starts and responds to `/v1/rerank` with a query+documents pair

---

## d) TOTALLY FUCKED UP

### My own reasoning errors across the three rounds

**Round 1 — I recommended TEI without checking the existing stack.**

I did the repo scan (correct), found no TEI references (correct), but then immediately jumped to "add TEI" without asking the most basic question: *can the inference engines already running do this?* I recommended a new Docker dependency, a new module, a new port, a new image — for a workload that needed zero new infrastructure. This is the "fastest solution, not the best solution" anti-pattern from the project's own philosophy docs.

**Round 2 — I recommended Infinity (Docker) over TEI, still without checking llama.cpp.**

The user pointed out nomic-embed-text was too weak and liked reranking. I correctly pivoted to "you need a reranker-capable server" but then evaluated TEI vs Infinity vs vLLM — all Docker/container options — and recommended Infinity. I still hadn't checked whether `llama-server` (already in the repo as `llama-cpp-rocwmma` + `llama-server-rocm`) supports reranking. It does. It has since September 2024.

**Round 2 — I recommended Docker when the project is Nix-native.**

The project has an entire `ai-stack.nix` module with Ollama (ROCm), llama.cpp (ROCm), GPU tooling, and session vars. The AGENTS.md says "Use flake commands", "Never hardcode", and the whole ethos is declarative Nix. I proposed pulling a Docker image for something that's a `nixpkgs.llama-cpp` override away. The user caught this immediately.

**Round 3 — I got it right, but only because the user pushed twice.**

When the user asked "Why is llama-server not enough?", I finally researched llama.cpp's reranking support and found it's fully supported. The answer should have been the Round 1 answer.

### What I should have done from the start

1. **Round 1:** Before recommending ANY new tool, ask: "Can Ollama do embeddings? Can llama-server do reranking? Can the existing stack cover this?" — then research those questions.
2. **Round 1:** The user's question "Should we add TEI permanently?" deserved a "let me check what you already have first" response, not a "here's how to add TEI" response.
3. **Round 2:** When the user said "I like the reranker idea", I should have immediately searched for reranking support in the existing stack before evaluating external tools.
4. **Throughout:** I should have recognized the Nix-native constraint from the project context and deprioritized Docker-based solutions unless there was no native alternative.

---

## e) WHAT WE SHOULD IMPROVE

### Process improvements

1. **Check the existing stack BEFORE researching external tools.** The most important lesson from this session. When asked "should we add X?", the first research question should be "can we already do X with what we have?" — not "how do we add X?".

2. **Recognize project constraints from context.** AGENTS.md is loaded with Nix-native patterns, flake commands, "never hardcode", declarative config. Docker is used (Twenty, Whisper) but only when there's no native alternative. I should have weighted this heavily from the start.

3. **The "reranking is not embeddings" distinction matters.** I conflated them in Round 1 (recommended Ollama embeddings when the user wanted reranking). These are fundamentally different model architectures (bi-encoder vs cross-encoder) requiring different serving capabilities. I should have asked the user to clarify which they needed, or researched both paths in parallel.

4. **Verify capabilities of existing tools before recommending new ones.** llama.cpp has had reranking since Sept 2024. Ollama still doesn't have it. This is the kind of thing I should verify before proposing architecture, not after the user pushes back.

### Architecture improvements (for the implementation phase)

5. **The `--reranking` and `--embeddings` endpoints are mutually exclusive per llama-server instance.** This is fine for our design (Ollama owns embeddings, llama-server owns reranking), but it should be documented in the module.

6. **Causal-LM rerankers (Qwen3-Reranker) have a known near-zero score bug in llama.cpp** (PR #25448 unmerged). We should use BERT/XLM-RoBERTa-family rerankers (bge-reranker-v2-m3) which work correctly.

7. **`OLLAMA_MAX_LOADED_MODELS=2` tradeoff** — the 270MB-1.2GB embedding model co-residing with a chat model. Need to verify this doesn't cause VRAM pressure on the 34 GiB carveout with a chat model already loaded. It shouldn't (bge-m3 is ~1.2GB fp16), but should be verified live.

8. **GGUF model format** — bge-reranker-v2-m3 needs to be in GGUF. Need to either find a community GGUF or convert it. The `convert_hf_to_gguf.py` script is in the llama.cpp source tree (not in the nixpkgs package by default — may need to be run manually or packaged).

9. **Paperless AI reranker support is unverified** — I stated the reranker endpoint is "ready for when Paperless AI adds reranker support" but did not verify whether `paperless-ai` (the plugin) currently exposes a reranker env var or config option. This needs checking before assuming the reranker is useful for Paperless specifically.

10. **Ollama `bge-m3` availability unverified** — I recommended `bge-m3` for Ollama embeddings but did not verify Ollama has it as a pullable model. Ollama's model library may not include it. If not, alternatives: `bge-large-en` (1.3GB), or stick with `nomic-embed-text` (which the user said is "too weak").

---

## f) Up to 50 Things We Should Get Done Next

### Immediate — RAG stack implementation (this session's decision)

1. Verify Ollama has `bge-m3` or equivalent strong embedding model in its pullable library
2. Verify `paperless-ai` exposes a reranker env var/config (search the upstream repo)
3. Acquire or convert `bge-reranker-v2-m3` GGUF model
4. Add `reranker` port to `lib/ports.nix`
5. Create `modules/nixos/services/llama-reranker.nix` module
6. Enable the module in `configuration.nix`
7. Wire `PAPERLESS_AI_LLM_EMBEDDING_*` env vars in `paperless.nix` → Ollama `:11434/v1`
8. Bump `OLLAMA_MAX_LOADED_MODELS` from 1 to 2 in `ai-stack.nix`
9. Pull `bge-m3` (or chosen embedding model) via Ollama
10. Add Gatus health check for the reranker `/health` endpoint
11. Add Gatus health check for the Ollama embeddings endpoint
12. Add Homepage tile for the reranker (optional, if user wants visibility)
13. Write a VM test for the reranker service (`tests/test-llama-reranker.nix`)
14. Update `AGENTS.md` with the RAG architecture decision and the llama.cpp reranking finding
15. Run `nix flake check --no-build` to validate the new module
16. Deploy and verify the reranker responds to `/v1/rerank` with a test query+documents pair
17. Deploy and verify Paperless AI picks up the embedding endpoint (check logs for embedding activity)
18. Verify `OLLAMA_MAX_LOADED_MODELS=2` doesn't cause VRAM pressure with a chat model loaded

### Short-term — AI stack improvements

19. Revisit the FastFlowLM `--embed 1` bug — has it been fixed upstream? The AGENTS.md says it's broken as of 2026-08-18; check for a new flm release
20. Evaluate whether `bge-m3` on Ollama (GPU) outperforms a CPU-only TEI/Infinity for the Paperless use case (likely yes, but benchmark)
21. Document the three-tier AI stack in AGENTS.md: FastFlowLM (chat/NPU), Ollama (embeddings/GPU), llama-server (reranking/GPU)
22. Consider whether the reranker should be socket-activated like FastFlowLM (1GB model cold-loads in ~1s, probably not worth the complexity)
23. Check whether `llama-cpp-rocwmma` in nixpkgs is recent enough to include the reranking PRs (Sept 2024 + May 2025 BertForSequenceClassification)

### Medium-term — Paperless AI + RAG

24. Investigate Paperless AI's reranker support — does it use llama-index's `CohereRerank` or similar? Can we point it at the llama-server `/v1/rerank` endpoint?
25. If Paperless AI doesn't support reranking natively, evaluate whether a custom search interface (e.g. a small Go service) over the Paperless DB + reranker is worth building
26. Backfill embeddings for existing Paperless documents (bulk index all existing docs once the embedding endpoint is live)
27. Test semantic search quality with bge-m3 embeddings + bge-reranker-v2-m3 reranking on the existing Paperless archive
28. Evaluate `bge-reranker-v2-gemma` (Gemma-based, larger, potentially better quality) as an alternative reranker model

### Infrastructure

29. Verify the reranker service survives the BFQ I/O priority tier system correctly (`ioTier.background` may be too low for interactive search queries — consider `ioTier.service`)
30. Add the reranker model path to `ai-models.nix` tmpfiles rules if storing under `/data/ai/models/`
31. Consider whether the reranker needs `OLLAMA_GPU_OVERHEAD`-style VRAM reservation or can share the existing carveout dynamically
32. Monitor GPU memory usage with both Ollama (chat + embeddings) and llama-server (reranking) loaded simultaneously
33. Add OTel endpoint env var to the reranker service (`OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318`)

### Monitoring & alerts

34. Add SigNoz alert for reranker service down
35. Add SigNoz alert for Ollama embedding model not loaded (check via `/api/tags`)
36. Add Gatus check for Paperless AI embedding activity (indirect — check Paperless logs for embedding errors)
37. Add a Prometheus metric for reranker query latency (if llama-server exposes `/metrics`)

### Documentation

38. Write a `docs/services/rag-stack.md` describing the three-tier AI stack and how to operate it
39. Update the Paperless section of AGENTS.md to remove the "NO embedding settings" caveat once embeddings are live
40. Update the FastFlowLM section of AGENTS.md to note the embedding/reranking split (embeddings → Ollama, reranking → llama-server)
41. Add the reranker to the AI stack architecture diagram if one exists

### Security

42. Verify the reranker endpoint is only accessible on localhost (not exposed via Caddy — it's an internal service)
43. Verify the Ollama embeddings endpoint is only accessible on localhost (already configured, but double-check after `MAX_LOADED_MODELS` change)

### Cleanup

44. Remove the `loadEmbed` option from `fastflowlm.nix` if embeddings are permanently served by Ollama (it's documented as broken and will never be used)
45. Clean up the `PAPERLESS_AI_LLM_EMBEDDING_*` comment in `paperless.nix` — replace the "not set" explanation with the actual configuration
46. Remove the `/data/ai/models/embeddings` tmpfiles rule from `ai-models.nix` if it's unused (or repurpose it for the GGUF reranker model)
47. Evaluate whether `nomic-embed-text` should be removed from Ollama if `bge-m3` replaces it

### Future considerations

48. Monitor Ollama's reranking PRs (#11328, #14172) — if Ollama adds native reranking, the llama-server reranker service can be retired and everything consolidates into Ollama
49. Evaluate vLLM as a unified inference server if the AI stack grows beyond 3 engines (chat + embeddings + reranking + potentially vision/audio)
50. Consider whether the Paperless AI workflow benefits from a re-ranking step in the consume pipeline (rank OCR-extracted text segments for better tagging/classification)

---

## g) Questions I CANNOT Answer Myself

### 1. Which embedding model for Ollama?

I recommended `bge-m3` but did not verify it exists in Ollama's pullable model library. Ollama's model registry is curated and may not include every HuggingFace model. If `bge-m3` isn't available, the alternatives are:
- `nomic-embed-text` (user said "too weak")
- `bge-large-en` (if available in Ollama)
- `mxbai-embed-large` (if available)
- A custom Modelfile importing the HuggingFace GGUF directly

**Question:** Do you have a preference for the embedding model, or should I verify what's pullable from Ollama and pick the strongest available?

### 2. Should the reranker run on GPU or CPU?

I recommended GPU (via `llama-server-rocm`) since the existing wrapper and ROCm env vars are already set up. But a 568M cross-encoder on CPU is ~50-100ms per query — instant for human perception. Running on CPU would:
- Avoid any GPU VRAM contention with Ollama + FastFlowLM
- Eliminate gfx1150 ROCm compatibility risk (llama.cpp's ROCm support for gfx1150 is via the WMMA path, but reranking uses different code paths than generation)
- Simplify the service (no ROCm env vars, no render group)

Running on GPU would:
- Be ~5x faster (~10-20ms per query)
- Share the existing ROCm setup
- Risk VRAM pressure if a chat model + embedding model + reranker are all loaded

**Question:** GPU (share existing ROCm stack, faster, slight VRAM risk) or CPU (zero contention, simpler, still fast enough for batch-of-1)?

### 3. Is the reranker for Paperless specifically, or for a broader RAG pipeline?

I assumed the reranker is for Paperless AI's search/RAG. But the user might be planning a broader RAG pipeline (e.g. a custom search interface over multiple data sources, a chatbot with retrieval, etc.). This affects:
- Whether we need to wire it into Paperless at all
- Whether we need a public-facing endpoint (Caddy vHost) or keep it localhost-only
- Whether we need to build a custom retrieval service on top of it
- The choice of reranker model (bge-reranker-v2-m3 is multilingual and general-purpose; a domain-specific reranker might be better for a specific use case)

**Question:** Is the reranker specifically for Paperless AI, or are you planning a broader RAG/search pipeline that I should design for?

---

## Final Recommendation (for reference)

```
┌─────────────────────────────────────────────────────────┐
│                    RAG Stack Architecture                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Chat LLM:     FastFlowLM  :52625  (NPU, socket-act'd)  │
│  Embeddings:   Ollama      :11434  (GPU, always-on)     │
│  Reranking:    llama-server :<port>  (GPU, new service)  │
│                                                         │
│  Paperless AI:                                           │
│    LLM        → FastFlowLM  (already wired)             │
│    Embeddings → Ollama      (new env vars)               │
│    Reranking   → llama-server (when paperless-ai supports)│
│                                                         │
│  Zero new Docker containers                              │
│  Zero new external dependencies                          │
│  1 new Nix module (llama-reranker.nix)                   │
│  1 GGUF model (~1.1 GB)                                  │
│  1 Ollama model pull (~1.2 GB)                           │
│  1 env var change (OLLAMA_MAX_LOADED_MODELS: 1→2)       │
│  ~5 Paperless env vars                                   │
└─────────────────────────────────────────────────────────┘
```

---

## Session self-critique

I made three consecutive wrong recommendations before getting to the right answer. The root cause was the same each time: **I jumped to recommending tools before checking what the existing stack could do.** The user had to push back twice to get me to research the obvious question ("can llama-server do reranking?"). This is the "fastest solution, not the best solution" anti-pattern, and it cost the user two rounds of back-and-forth that should have been zero.

The correct first response to "Should we add TEI permanently?" should have been: "Let me check what you already have for embeddings and reranking" — followed by researching Ollama and llama.cpp capabilities — followed by "No, you don't need TEI. Ollama does embeddings and llama.cpp does reranking. Here's the wiring."

I got there eventually, but the path was embarrassingly long.

---

*Generated 2026-08-19 17:36*
