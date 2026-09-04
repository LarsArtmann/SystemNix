# Status Report: llama-rag-model-fetch deploy failure — diagnosis, fix verification, clean deploy

**Date:** 2026-08-20 08:06 CEST (session ran 2026-08-19 ~18:55–19:15 CEST)
**Scope:** This session only — the `llama-rag-model-fetch.service` activation failure from deploy `viwrcvqc…`, its fix, and verification. Nothing else.

---

## Incident

Deploy `viwrcvqc344xmadivyx4bkd7h4mw9ppn-nixos-system-evo-x2-26.11.20260816.e5bdc4a` (2026-08-19 18:53) aborted with exit 4:

```
llama-rag-model-fetch.service: Main process exited, code=exited, status=1/FAILURE
mkdir: cannot create directory '/run/llama-rag-model-fetch': Permission denied
```

The failure blocked activation (`Activation (test) failed: Exited(4)`).

## Root Cause

Commit `321f599e` ("split model fetching into dedicated oneshot service") moved the model-fetch script into a standalone unit running as `User = lars`. The script still contained `mkdir -p /run/llama-rag-model-fetch` — but `/run` is root-owned tmpfs; a non-root user cannot create top-level dirs there.

The bug was **latent dead code made live**: in the pre-split commit (`393d2123`) the identical script existed but was never wired to any unit (confirmed by grepping the full pre-split file — `fetchScript` had no ExecStart/ExecStartPre reference). Nobody had ever executed it, so the permission assumption had never been tested.

## Fix (landed by a concurrent session; audited + verified by this session)

While I was diagnosing, a concurrent session rewrote `fetchScript` in `modules/nixos/services/llama-rag.nix` — the correct root-cause fix, not a workaround:

- **Staging inside `modelDir`** (`/data/ai/models/gguf`, `lars:users 755`): `.part` files land next to the target → same-filesystem atomic `mv`, no scratch dir needed at all. Strictly better than my planned fix (`RuntimeDirectory = "llama-rag-model-fetch"`, which would also have been correct but keeps a tmpfs dependency).
- **GGUF magic sniff on download** (`head -c 4` = `GGUF`) before install — rejects HTML error pages / truncated redirects.
- **Source-URL stamp** (`<model>.source` next to the file): a URL change re-fetches; idempotent "present and current" fast path.
- **Unit ordering**: `after = wants = [ "network-online.target" ]` added to the fetch oneshot (previously only the servers had it — a fetch racing DNS-up was a second latent bug).
- Functional smoke probes added to `scripts/post-deploy-check.sh`: `/v1/embeddings` must return a 1024-dim vector; `/v1/rerank` must rank the correct document first (catches "healthy but wrong model" regressions).

My contributions this session: verified the concurrent fix end-to-end (models on disk with correct ownership, `nix eval` + `nix flake check --no-build` clean, generated script inspected byte-level), removed 2 em dashes from the generated bash source (project style rule), and ran the deploy.

## Verification (all live, 2026-08-19 19:12–19:15)

- `llama-rag-model-fetch.service`: `Finished` — "bge-m3.gguf present and current", "bge-reranker-v2-m3.gguf present and current", "all models ready". Ran twice (19:12, 19:14), both clean.
- Deploy smoke: **63 PASS / 0 FAIL / 5 SKIP / 2 WARN**.
  - `llama.cpp Embeddings (localhost:8848) /health` → 200
  - `llama.cpp Reranker (localhost:8849) /health` → 200
  - `/v1/embeddings` → 1024-dim vector (PASS)
  - `/v1/rerank` → correct document ranked first (PASS)
- Gatus checks already existed pre-session (enable-gated, Discord-alerting, `gatus-config.nix:537-558`): both servers watched via `/health` — rule 9 (every service monitored) was already satisfied; I confirmed rather than added.

---

## a) FULLY DONE

1. **Diagnosed the exit-4 activation failure** to the exact line (`mkdir /run/llama-rag-model-fetch`) and the exact commit that introduced it (`321f599e`), including the "dead code made live" history.
2. **Audited the concurrent session's fix** before trusting it: read the full diff, confirmed models present on disk (`bge-m3.gguf` 1.16 GB, `bge-reranker-v2-m3.gguf` 1.16 GB, stamps written, `lars:users` ownership), inspected the generated store-path script byte-level (indentation stripping correct, quoting correct).
3. **Em-dash cleanup** in generated bash source (2 occurrences in `fetchScript` echo strings) — style rule compliance.
4. **Full validation chain**: `nix eval …toplevel.drvPath` clean → `nix flake check --no-build` all checks passed (this is what actually enforces NixOS assertions; drvPath eval does not) → `nix run .#deploy` → `nix run .#post-deploy-check` green.
5. **Confirmed Gatus monitoring** for llama-embeddings/llama-reranker already present and enable-gated.
6. Everything committed (auto-commit daemon; tree clean at report time).

## b) PARTIALLY DONE

1. **AGENTS.md lesson capture** — the `/run`-mkdir-under-user-unit trap (and the "dead code made live" amplifier) is NOT yet in the Non-Obvious Gotchas section. It's a textbook entry: _a unit running as a non-root user can never `mkdir /run/...`; stage in the target dir or use `RuntimeDirectory`_. This report records it; AGENTS.md does not.
2. **Concurrent-session attribution** — per the Critical Rule ("when the tree grows changes you didn't author, flag it"), I flagged the concurrent llama-rag/post-deploy-check edits mid-session, but the batched commits make per-change attribution fuzzy in history.

## c) NOT STARTED

1. **Eval-time guard** for the bug class: nothing in the prevention layers catches "user-run unit script mkdirs a top-level /run path" (grep-able in ExecStart scripts, similar in spirit to the ExecStart-in-harden pre-deploy check).
2. **VM test** for llama-rag (fetch oneshot + both servers behind mocked network) — the module has zero test coverage; `tests/` has the infrastructure (mock-sops, test-helpers) to do it.
3. **Backup stance for the 2.3 GB of GGUF models** — not in `backup-coordination` (defensible: re-fetchable in minutes, and `/data` IS btrbk-snapshotted, so this is arguably fine — but it's an unmade explicit decision).

## d) TOTALLY FUCKED UP!

**Nothing this session.** The original failure (the `/run` mkdir) was authored by the prior session's `321f599e`; it was fixed within ~20 minutes of surfacing. Minor self-critique: I burned one tool call on a nonexistent `read` tool, and my first fix plan (`RuntimeDirectory`) was good-but-second-best — staging in `modelDir` is simpler and I'm glad the concurrent session's version shipped instead.

## e) WHAT WE SHOULD IMPROVE!

1. **Commit my own changes immediately** — my em-dash fix sat uncommitted across a deploy; the daemon eventually swept it up into someone else's batch. Small, but it violates "commit after each smallest self-contained change" and muddies attribution.
2. **Dead code is untested code** — `fetchScript` existed for a full commit cycle (`393d2123` → `321f599e`) without ever executing. When wiring previously-unwired code into a unit, treat it as NEW code: it has never passed even one run. The `nix flake check` green-light covered eval, not execution.
3. **Verification order worked** — diagnosing from the systemd journal (exact line + exit code) before touching anything, then git archaeology (`git show 321f599e`, `393d2123`) to find when/why, was fast and correct. Keep this pattern.
4. **Oneshot User= deserves a lint** — three of our hardest-hit incident classes (this one, `bank-sync-storage-dir` 226, activitywatch `runuser` PAM) share a shape: _a script's filesystem assumptions vs the unit's User/sandbox_. A tiny eval-time or pre-deploy grep over ExecStart scripts for absolute `/run/` mkdir calls in non-root units would have caught today's bug pre-deploy.
5. **Concurrent-session protocol worked as designed** — re-reading files before edit, checking `git status` before deploy, and flagging foreign changes prevented me from double-fixing or clobbering.

## f) Things we should get done next (sorted by impact ÷ effort)

**High impact, low effort:**

1. Add the `/run`-mkdir-under-non-root-unit gotcha to AGENTS.md (Non-Obvious Gotchas → Systemd section) with this incident as the reference.
2. Verify Paperless AI actually picks up the now-running embeddings endpoint (`llm_embedding_backend` env → live RAG indexing — the whole point of the stack).
3. Decide + record the GGUF backup stance (re-fetch-on-loss vs backup-coordination entry) next to the existing `modelDir` docs.
4. Re-check the two standing post-deploy WARNs: "1 error line in quickshell journal (last 1h)" — one `journalctl --user -u quickshell` away from triage.
5. Confirm `bge-m3.gguf.source`/`.source` stamp files don't confuse anything scanning modelDir (e.g. paperless-ai model listing, future model managers).

**High impact, medium effort:**
6. Pre-deploy/eval-time lint: flag `mkdir` of top-level `/run` paths in scripts run by non-root units.
7. VM test for llama-rag: oneshot fetch (with a local HTTP fixture serving fake GGUF files), server startup, port assertions — the module currently has zero tests.
8. Gatus functional (not just liveness) check for the embeddings endpoint — `/health` proves the process; a periodic tiny `/v1/embeddings` probe proves the model actually embeds (phantom-green defense, same liveness-vs-health doctrine as the rest of gatus-config).
9. Consider `--embed`-style functional probes for the reranker too (same rationale as #8).

**Medium impact, low effort:**
10. Add `llama-rag` runtime lessons to the module header comment (the `/run` trap, one line: "stage in modelDir, never /run — unit runs as cfg.user").
11. Sweep other modules for unwired-but-defined scripts (the `393d2123` pattern: `pkgs.writeShellScript` values with no ExecStart reference) — `grep -rn writeShellScript modules/ | cross-ref` — each is a latent today's-bug.
12. Check whether the fetch oneshot should also verify model SIZE (magic sniff passes on a truncated-but-valid-header file; a `<50% of expected` heuristic catches cut downloads).

**Medium impact, medium effort:**
13. Expose RAG stack status on Homepage (tile guarded on `config.services.llama-rag.enable`) so the stack is visible in the dashboard surface.
14. Document llama-rag in `docs/services/` (like systemd-graph/paperless) — endpoints, ports 8848/8849, model lifecycle, the fetch stamp mechanism.
15. Teach `scripts/pre-deploy-check.sh` the fetch-unit pattern: ExecStart script exists AND is executable for units with `ConditionPathIsDirectory` (the unit skips silently when the dir is absent — a wedged `/data` mount would silently skip fetching and the servers would crash-loop on missing GGUF; a pre-deploy note when modelDir isn't mounted would catch it).
16. Revisit `TimeoutStartSec = "20min"` on the fetch oneshot after observing a real cold fetch — if HuggingFace serves at full link speed, 20min is 10x headroom; if the link is slow it's the difference between heal and start-limit-hit. One number, but it's the deploy-blocking path.
17. Investigate whether llama-server's `--ctx-size 8192` for bge-m3 is the right default for Paperless AI's document chunk sizes (embedding quality vs VRAM).

**Lower priority / backlog:**
18. Consider a shared "fetch-and-verify-GGUF" helper in `lib/` if a third model-fetching service appears (fastflowlm hand-managed, llama-rag scripted — one more and it's a pattern worth extracting).
19. Track upstream: llama.cpp `--reranking` mode is recent; watch for API changes in `/v1/rerank` response shape (smoke check asserts `.results[0].index`).
20. The 2.3 GB of GGUF + 13.6 GB fastflowlm model on `/data`: consider whether `/data/ai/models` deserves its own btrbk subvolume policy (currently inside the `/data` toplevel snapshot — snapshots hold ~16 GB of immutable model weights; harmless but space-visible).

## g) Questions I cannot answer myself

1. **Paperless AI + embeddings wiring**: `PAPERLESS_AI_LLM_EMBEDDING_*` points at `:8848` — but env-var changes are overridden by UI-saved values (the `app_config.x or settings.X` trap). Do you know whether the embeddings backend was ever saved via the Paperless AI settings UI, or can we trust env-only? (Determines whether RAG indexing actually activates now or needs a UI-value wipe.)
2. **GGUF backup stance**: is re-download-on-loss acceptable for the RAG models (2.3 GB, HuggingFace-hosted, ~minutes), or do you want them in `backup-coordination`/pool-side like paperless/immich data? I can argue either side; it's a data-policy call.
3. **The quickshell journal WARN** (1 error line in the last hour, standing across recent deploys) and the 17:49 systemd-graph "partial deploy, HTTPS broken" report from an earlier session — are other sessions already on these, or should they enter my queue? (Concurrent-session ownership question — I can't tell from the tree.)

---

_Session artifacts: fix in `modules/nixos/services/llama-rag.nix` (concurrent session + em-dash cleanup), smoke probes in `scripts/post-deploy-check.sh` (concurrent session), deployed generation 2026-08-19 19:12, post-deploy 63/0/5/2._
