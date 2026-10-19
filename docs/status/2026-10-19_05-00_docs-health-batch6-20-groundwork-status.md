# Docs-Health Batch 6-20 Groundwork — Status & Self-Review

**Date:** 2026-10-19 05:00 CEST · **Mode:** docs-health AUDIT (ANNOTATE + ARCHIVE + HARVEST + VERIFY), batches 6-20 of the tracked 2026-0* corpus sweep
**Trigger:** user dispatch "View ALL `**/2026-0*` files! Execute the docs-health SKILL! SUPERBLY" — the tracked continuation (TODO_LIST:704 → docs/todo/pipeline.md:581)
**Tree state at pause:** ZERO mutations landed — all work so far is classification/spec groundwork under `~/.cache/docshealth/` (the /tmp-volatility lesson applied). Repo worktree untouched by this session.
**Predecessors:** [2026-10-18_01-33 sweep manifest](2026-10-18_01-33_docs-health-corpus-sweep-status-and-archive-manifest.md) (batches 0-5: 116 reports annotated, 61 archived) · [2026-10-06_16-49 full-corpus AUDIT](2026-10-06_16-49_docs-health-full-corpus-audit-status.md)

## TL;DR

Batches 6-20 enumerated precisely (294 files, 2026-09-17_00-25 → 2026-09-30, after catching a lexical-range bug that silently dropped all 09-30 files); the toolchain (annotate.go repair/self-test) verified healthy with its exact mutation semantics read from source; the previous sweep's inline verdict convention reverse-engineered from its landed output (§a FULLY-DONE ledgers stay BARE, open-but-tracked rows stay bare, verdict vocab `done —` / `Won't implement` / `NOT-DO`, per-cell table strikes); batch-00 (31 files) classified by agent with full per-item verdicts; a normalization pipeline built and debugged (527 strike-spec lines + 1,045 routed lines, 0 warnings); the mandatory verify-print gate surfaced a WRONG-EVIDENCE verdict class (agent `v` verdicts whose evidence answers a different ask than the line carries) plus my own transcription-corrupt paths (13, all caught by path validation). Review of the verify-print was IN PROGRESS when the user paused for this report; batches 01-09 (263 files) are unstarted because the parallel agent dispatch hit rate limits — retry is now sequential per user instruction. Nothing applied to the corpus yet; the tree is clean for a parallel session.

## a) FULLY DONE (all under ~/.cache/docshealth/, no repo mutations)

| # | Item | Evidence |
| --- | --- | --- |
| a1 | Skill + references loaded in full (SKILL.md body, harvest-guide, verify-checklist, resolving-items, health-report-format) | read before any action |
| a2 | **Scope pinned to the tracked row**: batches 6-20 = `docs/status/2026-09-17_00-25 → 2026-09-30`; enumerated 294 files (`~/.cache/docshealth/batch6-20-files.txt`) | TODO_LIST:704 + pipeline.md:581 + `find` counts |
| a3 | **Predecessor sweeps read and their contracts extracted**: 2026-10-06 AUDIT (living-docs refresh + 90-row prune precedent), 2026-10-17/18 sweep manifest (batches 0-5 done, ~300-report continuation, /tmp-wipe + rate-limit lessons recorded) | both reports read in full |
| a4 | Baseline gates run: `check-todo-system.sh` rc=0 (structure clean; **WARN 67 unharvested §f reports**), `check-doc-links.sh` OK; TODO_LIST carries **208 `[x]` rows** (contract: never persist) + the living docs' known count-drift debt inherited | gate outputs in transcript |
| a5 | annotate.go health-verified (self-test green) AND its mutation semantics read from source: only numbered items/table data rows mutate, header/separator/metadata lines and already-annotated lines are skipped, marker rendering `v→done —`, `w→Won't implement`, `n→NOT-DO`, `r→append-no-strike` | `annotate.go` sed-reads |
| a6 | **Verdict convention reverse-engineered from landed output** (the thing that makes this sweep consistent with batches 0-5): §a ledgers bare; open-but-tracked bare; strikes land on §f one-shots/done items; per-cell table strike form incl. `~~~~` empty-cell canonical | 09-10_23-49 prose form, mrsync 13-08 table form, corpus-wide verdict-vocab tally |
| a7 | **Batch-00 classified: 31/294 files** — full TSV (file/lines/kind/value), per-file CLASS (2 archive-candidates, 29 open-carriers), and a 260-line open-ask inventory | `~/.cache/docshealth/verdicts/batch-00.tsv` + agent summary |
| a8 | **Normalization pipeline built + debugged**: linespec expansion (comma lists, truncated tails `103-04`→103-104, `110-14`→110-114), `done-at` kind dropped (§a convention), `r` rows split out, strike-beats-r conflict rule, path validation | `normalize.awk`; output: 527 strike + 1,045 routed spec lines, 0 warnings |
| a9 | **Verify-print gate executed**: all 527 spec lines printed against their actual file lines; full-text print of every `v` target line (1,024 lines) for verdict-vs-ask review | `specs/batch-00.verify.txt`, `specs/batch-00.v-full.txt` |

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker |
| --- | --- | --- | --- | --- |
| b1 | **Verify-print review** | First ~44 v-lines reviewed; tool-guard-skipped dead specs identified (heading/blank lines inside ranges — harmless no-ops) | Review of the remaining ~120 v-verdicts + all w/n verdicts; correction pass for the wrong-evidence class | paused for this report |
| b2 | **Wrong-evidence verdict class caught, not yet corrected** | Identified ≥4 suspect `v` rows (e.g. 00-25:61 "btrbk-data EIO P0" struck with *sizing* evidence while the EIO repair is still open at TODO_LIST:113; 00-39:87 niri-check anchoring struck with storage.md evidence; 00-39:93-96 daemon/perm asks with storage.md evidence) | Demote/drop each suspect to `r` (bare) or `w` before ANY apply — the h-bar doctrine: wrong-done is the worst failure | paused |
| b3 | **03-56 suspect**: agent `v` at lines 38-50 covers §b/§c items that read as OPEN (OAuth2 live test, prod DB cleanup) — believed misverdict, unconfirmed | flagged | confirm against the file + TODO rows before apply | paused |
| b4 | **08-38 wholesale range**: agent struck 83-257 as one `v` ("every open item verifiably resolved") — too coarse to apply blind | flagged | split + individually verify (it is the batch's strongest archive candidate) | paused |
| b5 | Workspace discipline | all artifacts under `~/.cache/docshealth/` (verdicts/, specs/, routed/, norms) — /tmp-proof | batches 01-09 not yet classified | rate limits; sequential retry queued |

## c) NOT STARTED (the remaining sweep legs, in pipeline order)

1. Batches 01-09 classification (263 files) — sequential agent retries, same prompt as batch-00.
2. Wrong-evidence adjudication pass + final spec assembly for batch-00.
3. `annotate.go repair --dry-run` → review → apply → `check-rows` over every touched file (gate BEFORE any `git mv`).
4. Archive wave: citation sweep (TODO_LIST/docs/todo/living docs) → banner + `git mv` → dangling-ref fixes → `check-doc-links.sh`.
5. HARVEST: 260 open asks from batch-00 + later batches → dedupe against queue/libraries → route (queue row + library entry, or ROADMAP, or decline-with-reason in the ledger).
6. TODO_LIST `[x]` prune (208 rows → one consolidated CHANGELOG bullet, 2026-10-06 precedent) — pending the §g2 etiquette answer.
7. Living docs VERIFY: README/FEATURES standing counts re-derived from repo (the 2026-10-06 §f.5 debt), ROADMAP Theme-1 staleness, AGENTS endurance pass.
8. Final gates + inline docs-health report (Accuracy/Fitness, as-found scoring).

## d) TOTALLY FUCKED UP (caught, all)

1. **Dispatched two classifier agents in parallel after reading the predecessor's rate-limit lesson** — the 01-33 manifest literally records "Agent rate limits forced one-at-a-time retries"; I read it and still fired two. batch-01 died at dispatch. Known-lesson-not-applied; user corrected to sequential.
2. **Batch enumeration range bug**: `awk '$0 >= "2026-09-17_00-25" && $0 <= "2026-09-30"'` silently excluded EVERY `2026-09-30_*` file (longer strings sort after the bare prefix). 241 vs the true 294. Caught by tail-inspection, fixed with `< "2026-10"`.
3. **Transcription corruption in the saved TSV**: ~13 paths mangled while copying the agent's output to disk (`a0ac8113…`, `202609-18…`, duplicated fragments). All caught by the path-validation step — but the manual-save step is the error source; the validator is the recovery. Keep both.
4. **normalize.awk v1 had two bugs** (shell-var quoting inside the file → fatal redirect; zero-pad rule too narrow for `110-14`-class tails). Caught by warnings + fatal on first run; fixed (truncated-tail general rule + `awk -v`).
5. **Ordered the tool semantics research AFTER dispatching agents** — the convention findings (§a stays bare, routed stays bare) arrived after batch-00's agent had already produced `done-at`/`r`-shaded verdicts. Recoverable in normalization (and done: both kinds dropped from strike specs), but the research should have preceded dispatch.

## e) WHAT WE SHOULD IMPROVE

1. **Read the predecessor manifest's operational lessons BEFORE dispatch, not after** — rate limits, /tmp wipes, and tool-shape findings are all recorded there precisely so the next sweep doesn't re-pay them.
2. **The wrong-evidence class needs a systematic filter**: agent verdicts citing evidence that proves a DIFFERENT item than the line's ask (EIO-P0-struck-with-sizing-evidence). Planned: every `v` whose value names a config/doc unrelated to the line's key nouns gets demoted to `r`. This check is now part of the review pass contract.
3. **Agents should return row-text snippets, not TODO_LIST:NNNN line numbers** — TODO_LIST line numbers rot between agent read and apply (the queue is edited constantly); snippet citations survive. Amend the batch-01+ prompt.
4. **Dead spec lines are harmless but noisy** — ranges spanning headings/blanks inflate spec counts; acceptable (tool guards skip them) but the verify-print must not lull the reviewer (a no-op line next to a real one reads the same).
5. The r-kind divergence (skill's first-class routed arrows vs this corpus's bare-open convention) stays resolved in favor of the LOCAL convention — consistency with batches 0-5 outranks the skill's default; recorded here so a future auditor doesn't "fix" it backwards.

## f) NEXT (continuation, in order)

1. Resume batch-00 review: finish v/w/n verdict-vs-ask adjudication (`specs/batch-00.v-full.txt`), demote wrong-evidence rows, split 08-38's 83-257, confirm/drop the 03-56 suspect.
2. Dispatch batches 01-09 sequentially (same prompt + snippet-citation amendment from e.3).
3. Dry-run → apply → check-rows per batch; repair-partial where check-rows flags.
4. Archive wave + manifest + ref fixes (§c.4).
5. HARVEST with ledger (§c.5) — incl. the park-landed pre-check (grep CHANGELOG/AGENTS for each harvested item's key nouns before minting rows).
6. TODO_LIST prune + CHANGELOG consolidated bullet (§g2-dependent).
7. Living-docs verify leg (README/FEATURES computed counts, ROADMAP Theme-1, AGENTS pass).
8. Final inline health report (as-found scoring, fixes reported separately).
9. Re-point the continuation row (TODO_LIST:704 + pipeline.md:581) at whatever remains (likely the 2026-10 wave) or close it.
10. Answer the check-todo-system unharvested-§f WARN for THIS report (cite it from the continuation row or record the deliberate deferral) — one line when execution resumes.

## g) Questions for the owner (cannot self-answer)

1. **Session scope after batches 6-20**: the tracked row says the 2026-10 tasks/ wave (469 files under `docs/status/` + `docs/status/tasks/`) is "out of scope for 2026-0* but next in line". When 6-20 completes: stop and leave it queued, or continue into the 2026-10 wave in this session while the pipeline is warm?
2. **TODO_LIST prune etiquette**: 208 `[x]` rows have accumulated since the 2026-10-06 prune; many were flipped by sibling sessions within the last 72h (superb-closure wave, task-queue fires). The 2026-10-06 sweep's §g1 asked whether same-day sibling flips are exempt — never answered on record. Prune all 208 now in one consolidated CHANGELOG bullet (strict contract reading), or exempt fresh sibling flips (<7d) until their citing closeouts land?
3. **Verdict aggressiveness for stale one-shots**: batches 0-5 struck time-boxed asks ("deploy before the Sep 17 window") as `Won't implement — one-shot; window passed` even when the underlying event (the deploy) later happened. Apply the same aggressive form in 6-20 (consistent corpus, fewer bare rows), or the conservative form (strike only evidence-backed done; leave stale one-shots bare for the owner)? Default planned: aggressive, per corpus consistency.

## Harvest log (§f self-harvest accounting)

- Items 1-9 are the continuation of the already-tracked row (TODO_LIST:704 → pipeline.md:581); deliberately NOT re-queued — duplicates are the drift class. The row will be re-scoped/closed at sweep completion (item 9).
- Item 10 (this report's gate citation) is a self-referential one-liner bound to this report's own landing; deliberately not harvested as a queue row because the citation lands with the row re-pointing in item 9, same change.
- §g answers will re-scope items 6 (prune) and the batch-3+ verdict bar at resume time.
