# SUPERB wave-3: Queue-Parity Waves Executed, Deploy Stood Down to exec-3

**Created:** 2026-10-25 13:19 CET · **Session:** wave3 instance (12-26 plan tombstone, `8835d9100`; 7th re-fire of the Pareto/plan/execute template)
**HEAD at start:** `2fe9a9807` · **HEAD at report:** `4375db47e` (+exec-3's `d821522d9` cv shim interleaved)
**Trigger:** owner dispatch ("READ, UNDERSTAND, RESEARCH, REFLECT… Execute and Verify") on the 12-26 plan.

---

## a) FULLY DONE (verifiably)

1. **Tombstone + non-collision adjudication.** Plan marked EXECUTING (`8835d9100`, committed before any item). Pre-deploy discovery: the "lock-wave" session is **exec-3, a resume of the 05-10 plan's executor** (its 12:55 report says so explicitly) — per the 12-26 plan's own clause, the inherited deploy wave D (R1/R2), R10 (their T13), and R7 stood down or closed-by-their-evidence. The pinned-rev probe confirmed the call: `nix flake check --no-build` at `2fe9a9807` is RED on exactly the paperless assertion exec-3's commit message describes fixing — deploying the stale rev would have shipped a broken eval.
2. **Wave P1 — 22/23 wrong-link rows repointed** (`65a00059c`). Each row's library link now points where its cited Source actually lives (gate's primary remedy; per-row home-lib choice respects the fix-domain routing rule). Remaining 1 = the DiscordSync hot-loop row (1137), stood down: the discordsync-immich session is live and owns its rows.
3. **Wave P2 — 34 no-entry rows paired** (`8782f345e`): 14 citation-appends onto same-topic library entries + 18 new library entries (storage 8, stability 4, monitoring 2, upstream 3, desktop 1) + 1 queue row closed done (`/data` 85% alarm — `edb3d4abb` landed in-tree, rides next deploy). Every append keyword-verified against its target line before sed; zero writes to the two contested files.
4. **R7 eval-red CLOSED by exec-3's evidence** (not by this session): `nix flake check` fully green at `cb82632dc` per their hook-gate proof; the only residual red is the cv FOD build (now shimmed by their `d821522d9`).
5. **R21 parity tooling DONE** (`4375db47e`): `scripts/prune-done-todos.sh` — dry-run default, rev-pinned baseline (aborts if HEAD or target dirtiness moves between WARN A and apply), continuation-aware `[x]` prune, grouped CHANGELOG block emit with relative paths + pre-prune line numbers; shellcheck-clean (hook-verified), live dry-run self-test found the 3 current done rows and wrote nothing. AGENTS.md TODO-System rule now documents the unmask effect (prune WARNs 163→221 on 2026-10-25) and points at the script. Both 10-38-report follow-up rows flipped `[x]` with evidence.
6. **Gate state**: DRIFT WARN lines 101 → **41** (60 cleared: 57 by waves P1/P2, 3 by parallel-session additions). All 41 remaining lines (13 wrong-link + 28 no-entry rows) live exclusively in `pipeline.md`/`services.md` — the two files the discordsync session actively edits.

## b) PARTIALLY DONE

1. **R5 contested tail.** 28 no-entry + 13 wrong-link rows remain, all in the contested pair. Exec-3's own additions (daemon batch `b01c215c9`) already cleared ~11 of the original pipeline no-entries mid-session — the surfaces are moving under active editors; a recheck pass at session-quiescence is queued (§f.1).
2. **Wave D disposition.** D01 executed (red on stale rev — the proof that pinned-rev discipline works), D02-D14 stood down to exec-3 (their §f.1/#1-#4 own deploy, proofs, and new-check verification; their cv shim `d821522d9` landed while this report was written — the deploy is unblocked on their side, awaiting their green build + owner's thermal-window answer per their §g.1).

## c) NOT STARTED

1. **R19 tq harvest-gate hardening** — probed: the harvest is NOT a repo script; it lives in the go-taskqueue agent-pool ecosystem (tq server + agents, upstream Go). A 90m L-effort item needing its own discovery pass; deliberately not half-started.
2. **R20-R30** (upstream wave, domain sprints, adjudication ladder) — unopened; the plan's sprint/ladder decomposition-at-open convention applies.
3. **D12-D14 owner packet as a standalone artifact** — folded into §g below instead (no file needed; exec-3's §g.1/g.2 already carry the deploy-side asks).

## d) TOTALLY FUCKED UP (caught in-session)

1. **Line-number sed on a live-contested file** — flips of rows 43/674/675 executed by line number between daemon commits; verified intact after, but the keyword-anchored pattern (used everywhere else) was skipped for expediency exactly once each way. The race window was real (TODO_LIST shifted twice this session).
2. **First analyzer's `grep -nF` leading-dash bug** — `- [ ]` row prefixes parsed as grep options; line lookups silently failed. Fixed with anchored patterns in analyze3.sh, but v1 output was acted on for target-line probes before the bug was noticed (all appends re-verified by keyword before write, so no corruption escaped).
3. **mvdan/sh heredoc-in-python gymnastics** — a `python3 - <<EOF` fixer failed on brace parsing; wasted a round trip before switching to the write tool. The handoff warned about heredocs; the lesson extends to nested-brace payloads, not just `$( )`.
4. **Stale-rev deploy premise** — the worktree was pinned to `2fe9a9807` under the assumption HEAD was deployable; the check (not assumption) caught the paperless assertion. The worktree discipline (pin → check → deploy same rev) is what saved it; recording that this was a near-miss, not a success story.

## e) WHAT WE SHOULD IMPROVE

1. **The pairing gate should emit row line numbers** — both WARN classes print 160 chars of row text; every consumer (this session, the 10-38 session) rebuilds line lookup immediately after. One `grep -n` in the gate deletes a whole analyzer class.
2. **Wrong-link vs no-entry remedy guidance is implicit** — the gate says "fix the row link or move the entry" but the honest split (repoint for routing-mismatch, append-citation for same-topic-entry-missing-source, new-entry for orphaned ask, close for done) took a session to derive. One paragraph in CONTRIBUTING would freeze it.
3. **Parallel-executor discovery is still ad-hoc** — exec-3 was identified only because their commit message self-described the eval unblocks and their untracked 12:55 report was read on suspicion. The tombstone guards plans; nothing guards "which executor am I displacing" before the first build/deploy probe.

## f) Next tasks (session-derived, honest count 4)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Pairing recheck pass on pipeline.md + services.md once the discordsync-immich session closes (28 no-entry + 13 wrong-link; rerun `scripts/check-todo-system.sh`, apply the P1/P2 remedy split) | High | M | Queue parity |
| 2 | First `--apply` exercise of `scripts/prune-done-todos.sh` at the next prune cycle (3 done rows currently await; paste block into CHANGELOG, recount drift row) | Medium | S | Tooling |
| 3 | R19 scoping: locate the tq agent-pool harvest implementation (go-taskqueue ecosystem, not repo scripts) and map the five hardening rules (sudo-skip, stale-snapshot, watch re-fire, log-only, stamp cap) onto it | High | M | Dispatch integrity |
| 4 | Gate hardening: pairing WARNs emit row line numbers (§e.1 — one-line change in `check-todo-system.sh` pairing_check) | Medium | S | Tooling |

*Harvest: all four landed in TODO_LIST.md + docs/todo/{pipeline,services,pipeline,pipeline}.md at authoring time (rows cite this report).*

## g) Questions for the owner (consolidated packet — deploy-side asks live in exec-3's 12:55 §g)

1. **Gate semantics** (from the 12-26 plan §R3): may sessions treat a CHANGELOG mention as a satisfied citation for pairing purposes? And do you want `CHECK_TODO_PAIRING=strict` + `CHECK_TODO_HARVEST=strict` flipped to hard-fail at zero (41 drift + 123 unharvested today — strict now would block every commit until the contested tail clears)?
2. **Prune-entry format** (10-38 report carry-over): keep verbatim per-title CHANGELOG lists (current, 533 lines for 520 rows) or switch to count+range+sample (the new script emits either shape with one flag)?
3. **Foreign-work attribution**: the discordsync session's test rode `a5246a013` and its script edits ride daemon batches — is silent co-riding acceptable house behavior, or should pathspec commits always name foreign-file inclusion explicitly (this session excluded them everywhere)?
4. **Multi-executor coordination** (cross-ref exec-3 §g.3, not duplicated): their three options stand; this session's vote is (a) exec-3 proceeds through T1/T2 — the stand-down pattern worked and cost nothing.

---
*Session evidence: gate `bash scripts/check-todo-system.sh` 13:19 = DRIFT 41 (13 wrong-link + 28 no-entry rows, all pipeline/services), structure clean; classifier `~/.cache/wavep/analyze3.sh` (WRONGLINK 13 / NOENTRY 28); dry-run self-test `bash scripts/prune-done-todos.sh` (3 rows found, zero writes); pinned-rev check red at `2fe9a9807` (paperless assertion), exec-3 green at `cb82632dc`; commits `8835d9100` `65a00059c` `8782f345e` `4375db47e` (pathspec, pre-commit all-green incl. shellcheck + eval).*
