# Status: llama-rag Integration — SigNoz Alerts Done, 3 Tasks Remain

**Date:** 2026-08-20 05:19
**Session goal:** Complete remaining integration work for the llama-rag module (embeddings + reranking on GPU via llama-server), then deploy and push.

---

## a) FULLY DONE

### Prior sessions (already committed before this session)

1. **`llama-rag.nix` module** (`modules/nixos/services/llama-rag.nix`, 305 lines) — Two llama-server instances: `llama-embeddings` (port 8848, `--embedding`, bge-m3) and `llama-reranker` (port 8849, `--reranking --pooling rank`, bge-reranker-v2-m3). ROCm env vars, `harden {}` + `ioTier.background`, `MemoryMax=2G`, `OOMScoreAdjust=300`, assertions for port/host sanity. Model-fetch oneshot downloads GGUFs from HuggingFace with magic-byte verification and atomic rename.

2. **Port registry** (`lib/ports.nix`) — `llama-embeddings = 8848`, `llama-reranker = 8849` with comments.

3. **Paperless integration** (`modules/nixos/services/paperless.nix`) — Four `PAPERLESS_AI_LLM_EMBEDDING_*` env vars wired to `:8848/v1`, replacing the old "deliberately absent" comment block.

4. **Gatus health checks** (`modules/nixos/services/gatus-config.nix`) — Two `mkHttpCheck` entries (enable-gated): `:8848/health` and `:8849/health`, both with `[STATUS] == 200`, `[RESPONSE_TIME] < 1000`, Discord alerts.

5. **System-health monitoring** (`modules/nixos/services/system-health.nix`) — `llama-embeddings` and `llama-reranker` added to `monitoredServices` for systemd state metrics.

6. **Post-deploy smoke tests** (`scripts/post-deploy-check.sh`) — Liveness (`/health`) + functional probes (`/v1/embeddings` returns 1024-dim vector, `/v1/rerank` ranks correct document first).

7. **Deploy.sh wiring** (`scripts/deploy.sh`) — `llama-rag-model-fetch` added to provisioner restart list.

8. **Configuration enablement** (`platforms/nixos/system/configuration.nix`) — `llama-rag.enable = true;` with architecture decision comment.

9. **VM test updates** (`tests/test-paperless.nix`) — `llamaRagNixosModule` import + 3 embedding env var assertions.

10. **AGENTS.md documentation** — llama-rag section added with three-tier AI stack table, flags verified, model download, Paperless integration, FastFlowLM note. (But DUPLICATE — see section d.)

### This session

11. **SigNoz alerts** (`modules/nixos/services/_signoz-alerts.nix`, lines 191-210) — Added `llama-embeddings-down` and `llama-reranker-down` alert rules following the Ollama pattern (`node_systemd_unit_state{name="<service>.service",state="active"}`, `op = "below"`, `target = 1`, 60s step, `severity = "warning"`). Committed by auto-commit daemon as `de550cff`.

12. **deadnix fix in systemd-timer-monitor.nix** — Pre-commit hook caught unused `serviceDefaults` and `ports` let bindings in `systemd-timer-monitor.nix` (a file I did NOT touch — pre-existing debt from commit `7bfba47a`). The auto-commit daemon committed the fix as `1fd79db8`. This was NOT my work but it blocked my commit and the daemon resolved it.

---

## b) PARTIALLY DONE

### Nothing partially done — remaining items are fully not-started.

---

## c) NOT STARTED

1. **Homepage tile for llama-rag** — `homepage.nix` has 0 references to `llama-rag`/`llamaRag`. Ollama and FastFlowLM both have decorative tiles in the AI group; llama-rag should too for consistency. Needs `llamaRagEnabled` flag + tile entry.

2. **Remove `loadEmbed` from `fastflowlm.nix`** — `fastflowlm.nix` still has 2 references to `loadEmbed` (option definition ~line 167 + `--embed 1` in ExecStart ~line 318). This is dead code — the `--embed 1` flag is documented as broken (co-loads embed-gemma which fails the main model's XRT buffer-object mmap). The option exists but must stay off. Removing it eliminates dead code and a confusing "escape hatch" that doesn't work.

3. **Consolidate duplicate AGENTS.md llama-rag sections** — AGENTS.md has TWO `### llama-rag` sections (one at ~line 167 added by this session's prior work, one at ~line 280 added by a concurrent session). Both describe the same module with slightly different wording. Needs merge into one authoritative section.

4. **Deploy to evo-x2** — All work is eval-checked (`nix flake check --no-build` passed) but NOT deployed. The `llama-rag-model-fetch` oneshot will download ~2.4 GB of GGUF models from HuggingFace on first deploy. Services haven't been started.

5. **Live verification** — After deploy: `systemctl status llama-embeddings llama-reranker`, `/health` on both ports, `/v1/embeddings` dimension check, `/v1/rerank` ranking check, Paperless AI embedding activity in journal.

6. **`git push`** — All commits are local. Not pushed to remote.

---

## d) TOTALLY FUCKED UP

1. **Pre-commit hook caught pre-existing deadnix debt in a file I didn't touch** — My commit of the SigNoz alerts was blocked by the pre-commit hook's `nix flake check` step, which builds `deadnix-check.drv` against the ENTIRE flake (not just staged files). `systemd-timer-monitor.nix` (committed in `7bfba47a` by a prior session) had unused `serviceDefaults` and `ports` let bindings that deadnix flagged. This is NOT a bug in my work — it's pre-existing debt that the pre-commit hook catches repo-wide. The auto-commit daemon resolved it by committing the fix separately (`1fd79db8`), but my manual commit attempt failed with exit 1. **Lesson:** when the pre-commit hook fails on a file you didn't touch, check if the auto-commit daemon will fix it, or fix it yourself in the same commit. The pre-commit hook runs `nix flake check` (full build, not `--no-build`), which is much stricter than the `--no-build` syntax check I'd been using for validation.

2. **Confusion about commit state** — I attempted to commit the SigNoz alerts manually, the pre-commit hook failed, and then the auto-commit daemon committed the same change (plus the deadnix fix) while I was processing the failure. This created a moment where I wasn't sure if my change was committed or lost. The daemon's commit (`de550cff`) has a slightly different message than what I wrote. **Lesson:** in a repo with an active auto-commit daemon, manual commits may race with the daemon. Always check `git log` after a failed commit to see if the daemon already committed the change.

---

## e) WHAT WE SHOULD IMPROVE

1. **Pre-commit hook should lint only staged files, not the whole flake** — The current pre-commit hook runs `nix flake check` (full build including deadnix/statix across ALL files). This means a deadnix issue in ANY file blocks ALL commits, even if the committer didn't touch that file. The deadnix and statix checks should be scoped to staged `.nix` files only (the hook already does this for the per-file linters — `No staged .nix files — skipping Nix linters` — but the `nix flake check` step is unconditional). This is a repo-wide improvement, not specific to llama-rag.

2. **`nix flake check --no-build` vs `nix flake check`** — Throughout this project, `--no-build` has been used for fast syntax validation. But the pre-commit hook runs the FULL `nix flake check` (with builds), which catches deadnix/statix issues that `--no-build` might miss (deadnix-check.drv is a build-time check). The AGENTS.md "Build & Deploy" section says `nix flake check --no-build` for syntax validation — this should note that the pre-commit hook is stricter.

3. **Duplicate AGENTS.md sections from concurrent sessions** — The auto-commit daemon batches multiple sessions' work into shared commits. When two sessions both add documentation for the same module, duplicate sections appear. A lint check for duplicate section headers in AGENTS.md would catch this class of split-brain.

4. **Dead code should be removed proactively** — `loadEmbed` in `fastflowlm.nix` has been documented as broken since 2026-08-18. It should have been removed then, not left as a "might fix it later" escape hatch. The AGENTS.md philosophy says "fix issues on sight" — dead code is an issue.

5. **VRAM pressure is unverified** — The chat model (FastFlowLM, 13.6 GB on NPU) + embedding model (bge-m3, ~1-2 GB on GPU) + reranker (bge-reranker-v2-m3, ~1-2 GB on GPU) all run simultaneously. The VRAM carveout was recently reduced from 34 GiB to 18 GiB by a concurrent session. Whether 18 GiB is sufficient for both GGUF models alongside the compositor and any user-launched GPU work is UNVERIFIED. This is the biggest risk on deploy.

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (this session's remaining work)

1. Add Homepage tile for llama-rag in `homepage.nix` (AI group, decorative, enable-gated)
2. Remove `loadEmbed` option + `--embed 1` ExecStart fragment from `fastflowlm.nix`
3. Consolidate duplicate AGENTS.md `### llama-rag` sections (lines ~167 + ~280 → one)
4. Run `nix flake check --no-build` to validate all changes
5. Commit all remaining changes
6. `nix run .#deploy` — build and deploy to evo-x2
7. Verify `systemctl status llama-embeddings llama-reranker` — both active
8. Verify `curl -sf http://127.0.0.1:8848/health` returns 200
9. Verify `curl -sf http://127.0.0.1:8849/health` returns 200
10. Verify `/v1/embeddings` returns 1024-dimensional vector
11. Verify `/v1/rerank` ranks the correct document first
12. Verify Paperless AI picks up embeddings (`journalctl -u paperless-task-queue`)
13. `git push` — push all commits to remote

### Near-term improvements

14. Verify VRAM usage with both models loaded (`rocm-smi` / `amdgpu_top`)
15. If VRAM is tight, consider reducing `ctxSize` from 8192 to 4096 for embeddings
16. Add `llama-rag` to the `ai-stack.nix` AI stack overview section in AGENTS.md (if not already there)
17. Check if Paperless AI supports reranker env vars (`PAPERLESS_AI_LLM_RERANKER_*`) — if so, wire them
18. Add Gatus response-time baseline after measuring typical embedding/rerank latency
19. Consider adding `nvidia-smi`/`rocm-smi` VRAM utilization metric to system-health collector
20. Verify the `llama-rag-model-fetch` oneshot is idempotent (re-running with models present should be a no-op)
21. Add a Gatus check for model file staleness (models not updated in >90d)
22. Consider adding `--flash-attn` flag for both llama-server instances (if supported by the GGUF models)

### Monitoring & alerting

23. Add a SigNoz alert for VRAM usage >90% on the GPU
24. Add a Gatus endpoint check for `/v1/models` on both ports (model loaded correctly)
25. Add a SigNoz alert for embedding latency p95 > 500ms
26. Add a SigNoz alert for reranker latency p95 > 500ms
27. Consider adding a synthetic RAG pipeline check (embed → rerank → verify) to post-deploy-check.sh
28. Add the llama-rag services to the `backup-coordination` module if they have stateful data (they don't — models are re-downloadable — but document this)

### Documentation

29. Update the FastFlowLM section in AGENTS.md to remove the `--embed 1` broken mention (since loadEmbed is being removed)
30. Add a "RAG Architecture" subsection to AGENTS.md explaining the three-tier AI stack (NPU chat + GPU embeddings + GPU reranker)
31. Document the bge-m3 embedding dimension (1024) in the module for future reference
32. Document why bge-reranker-v2-m3 was chosen over Qwen3-Reranker (causal-LM near-zero score bug in llama.cpp)
33. Add llama-rag to the "Adding a Service" checklist example in AGENTS.md
34. Update `docs/CONTRIBUTING.md` with the llama-rag module as a reference for GPU service modules

### Code quality

35. Consider extracting the ROCm env var pattern into a shared helper (currently duplicated between `ai-stack.nix`, `fastflowlm.nix`, and `llama-rag.nix`)
36. Consider adding a `mkRocmService` helper that combines `harden {}` + ROCm env vars + `ioTier.background` + `OOMScoreAdjust`
37. Run `statix check` on `llama-rag.nix` to catch any lint issues
38. Run `deadnix` on `llama-rag.nix` to catch unused bindings
39. Consider adding type assertions for the model file paths (must end in `.gguf`)
40. Add a `mkDerivedOption` for `embeddingsEndpoint` and `rerankerEndpoint` (computed from host + port) instead of letting callers compute it

### Pre-commit hook improvements

41. Scope the `nix flake check` in pre-commit to only build deadnix/statix checks, not all VM tests (faster, catches the same lint issues)
42. Or: split the pre-commit hook into "fast" (lint staged files) and "slow" (full flake check) phases, with the slow phase being non-blocking or opt-in
43. Add a deadnix check scoped to staged files only (like the statix check already does)
44. Add a duplicate-section-header check for AGENTS.md

### Future features

45. Consider adding a `/v1/embeddings` batch endpoint test to post-deploy-check.sh (batch of 10 documents)
46. Consider adding model warm-up (pre-load a test embedding) to the service ExecStartPost
47. Consider adding a `llama-rag-benchmark` script that measures embedding/rerank throughput
48. Consider adding support for multiple embedding models (switchable via config)
49. Consider adding a GPU memory cgroup limit for llama-rag services (separate from `MemoryMax` which limits system RAM)
50. Consider adding a systemd watchdog (`WatchdogSec`) for llama-server services if they support `sd_notify` (verify — llama.cpp may not)

---

## g) Questions (that I CANNOT figure out myself)

### Q1: VRAM budget — is 18 GiB enough?

The VRAM carveout was recently reduced from 34 GiB to 18 GiB by a concurrent session. The embedding model (bge-m3, ~1-2 GB) and reranker (bge-reranker-v2-m3, ~1-2 GB) need to coexist with the compositor (niri) and any user-launched GPU applications. I cannot verify VRAM usage without deploying, and deploying is irreversible (downloads 2.4 GB of models, starts services). **Should I deploy and measure, or should we increase the VRAM carveout first?** If VRAM is insufficient, the services will OOM or fail to load — I need to know if you'd prefer to risk it or be conservative.

### Q2: Should I fix the pre-commit hook to scope deadnix to staged files?

The pre-commit hook's `nix flake check` step catches deadnix issues in ALL files, not just staged ones. This blocked my commit because of pre-existing debt in `systemd-timer-monitor.nix` (a file I didn't touch). I could modify the pre-commit hook to scope deadnix/statix checks to staged `.nix` files only, matching how the per-file linters already work. **But this is a repo-wide change that affects all contributors — should I do it, or leave it as-is?** The current behavior catches more bugs but blocks commits on unrelated debt.

### Q3: Should I deploy now or wait for all code changes to be complete first?

The remaining code changes (Homepage tile, loadEmbed removal, AGENTS.md consolidation) are small and low-risk. Deploying now would start the 2.4 GB model download while I finish the remaining work, saving time. But if any of the remaining changes requires a re-deploy, that's two deploy cycles. **Deploy now (parallelize download with remaining work), or deploy once after everything is done?**

---

## Summary

The llama-rag module is ~90% complete. The SigNoz alerts were committed this session (by the auto-commit daemon after my manual commit was blocked by a pre-existing deadnix issue). Three small code tasks remain: Homepage tile, loadEmbed removal, AGENTS.md consolidation. After that: deploy, verify, push. The biggest risk is VRAM pressure (18 GiB carveout, unverified). The biggest process issue is the pre-commit hook catching repo-wide deadnix debt instead of scoping to staged files.
