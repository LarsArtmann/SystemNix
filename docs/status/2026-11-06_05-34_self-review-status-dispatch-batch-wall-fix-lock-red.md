# Self-review + status — dispatch batch close-out (wall fix, doctrine, drift recount, lock-red)

**Session:** 2026-11-06 04:5x–05:34 CET (resume instance; executed the non-owner-gated [ready] legs from the 04-37 close-out). Storm throughout: io PSI avg10 91→98.5, load 145→156.

**Scope line — VERIFIED here:** all claims below rest on artifacts from this session: A/B flake-check walks (before/after logs at `~/.cache/stateversion/{before-fc-kg,after2-fc-kg,after3-fc-kg}.log`, keep-going, worktree at clean-HEAD `6ba980df0` + my synced files, tree-equality proven file-by-file via `diff -q` before the after-walk); `docs-freshness --audit-all` recount (`~/.cache/docs-gates/auditall-20261106-b.log`, rc captured); pinned-source reads (`nixos/modules/misc/version.nix` warnIf mechanism, `nixos/lib/testing/nodes.nix` defaults merge); commits `6ba980df0`, `7ee80ef51` (amend of daemon-batched `559524f1e`), `2f3290fb3`, daemon-batched `f6da605c3` (contents verified mine via `git show --stat`); PSI probes at 04:5x and 05:0x.
**NOT verified here:** no check was BUILT (`--no-build` everywhere — check derivations evaluated, their run-time scripts not executed); the main tree never eval'd green as a whole this session (sibling lock-red, see d.1) — the 91→0 proof is worktree-conditional on the OLD green lock + my file set, and HEAD carries identical file content but a different lock; `bash scripts/check-todo-system.sh` was NOT re-run after my ticks (report-unit counter unchanged since 186); VM-test BUILD-time warning behavior unproven (would need building one VM test); sibling-session liveness/intent for flake.lock is inferred from commit cadence only.

## a) FULLY DONE

1. **Capture-once-then-grep doctrine — `6ba980df0`.** AGENTS.md "Build & Deploy" paragraph (one eval, N inspections; tee to `~/.cache/` first) + pipeline.md:380 ticked `[x]`. Practiced live: every heavy walk this session ran once into a file, all greps hit files.
2. **stateVersion warning wall eliminated — 91→0, `7ee80ef51`.** 16 emitting surfaces pinned (15 bare-`nixosSystem` audit helpers + the borg-restore fixture; VM family via runNixOSTest `defaults` with `mkDefault`, per-test overrides still win). Value `"26.11"` read from the pin's own `cfg.release` — zero behavior delta. A/B evidence: before 91 warnings + doc-counts error / after 0 warnings, 0 errors, rc=0.
3. **FEATURES.md doc-counts re-stamp 146→147 (152 files) — `f6da605c3` (daemon-batched, contents verified).** Fixed a RED HEAD shipped by the trash-metrics session (README-only re-stamp; docs-only commit skipped the hook's flake check — the eval-irrelevant-skip seam). Doc-counts eval-green in the after-walk.
4. **docs-gates item-counter recount — 12,638 items / 2,521 reports** (baseline 12,628/2,516, 03:3x). Discharges the 04-37 §f.9 obligation; drift row (pipeline.md:400) updated with the delta and the watch-the-delta guidance.
5. **T11 gate probe:** PSI avg10 = 98.5 (needs <20 ×3min) — correctly NOT attempted; stays pending.
6. **Session close-out:** 05-30 status report + self-harvested follow-ups (`2f3290fb3`), rows ticked on the library surface (no queue one-liners existed for either row — verified, so no drift).

## b) PARTIALLY DONE

1. **Lock-audit red — watched, flagged, deliberately not fixed.** Sibling's flake.lock regrew the `treefmt-nix` deep copy (`27b3b12a` vs root `treefmt-nix_2`/`0d6d739a`); flake.nix:1066 already follows the root edge, so the fix is a consumer-level follows line I could land in 1 minute — withheld because the lock is an ACTIVE sibling session's surface (3 daemon-batched lock commits during my window). Flagged in 05-30 §e.1 with a watch row. Effort to finish: S, gated on sibling state.
2. **Worktree eval surface (`~/.cache/systemnix-verify`) — kept, intentionally** (cheap green-eval surface until the lock settles; removal note in 05-30 §f.3). Stray root `default.nix` artifact from my sloppy cp WAS cleaned.

## c) NOT STARTED (all parked with reasons, none forgotten)

1. **T26 batch 2** (2026-09-27 pair) — owner pacing answer pending (carry-over).
2. **T15/T16/T27** — deploy-gated (D2 authorization pending).
3. **Pushes mr-sync / go-cqrs-lite** — owner + churn-gated; now ALSO lock-coupled.
4. **T11 bench legs** (`bench-samsung-livefs.sh`, USB leg, parity table) — PSI gate unmet.
5. **Archive pass** for the six resolved 2026-09-26 files — owner policy answer pending.

## d) TOTALLY FUCKED UP

1. **My first seam attempt shipped a 37-error regression into the tree and got daemon-committed mid-flight.** The `[ node base ]` node-wrap is rejected by the tester's `nodes.<name>` typing ("not of type submodule"). The A/B walk caught it — but only AFTER a full storm-priced walk; a 30-second single-attr smoke eval (`crush-daily.drvPath`) would have caught it before the daemon's batch window. The regressed state was HEAD-visible for ~15 min (nobody consumed it; CI never saw it unpushed). Lesson queued in e.1.
2. **`rg -rn` typed TWICE this session** (hook: strikes 3+4 of this exact trap ON THIS HOST) — the very failure AGENTS.md documents with a 2026-10-23 incident. Pure discipline failure, zero cost, maximal irony.
3. **88-char commit subject rejected** (house limit 72) — the resume summary I was handed EXPLICITLY said "75 was REJECTED"; I burned a hook cycle re-learning it at 88.
4. **Sloppy multi-source cp contaminated the eval surface:** `cp tests/default.nix FEATURES.md <worktree>/` planted a stray root `default.nix` (untracked files ARE part of a git flake's store copy) that rode through the green after-walk unnoticed until status review. The walk was green anyway — luck, not design.
5. **Two wasted full evals on a wrong hypothesis:** I probed `drvPath` evals for warnings (mail-relay/boot — 0 found) before realizing warnings only surface under flake-check forcing depth. Under full storm, that's ~10 min of IO for a guess I could have cheaply falsified by reading version.nix's `apply`/warnIf first (I read it AFTER).

## e) WHAT WE SHOULD IMPROVE

1. **Smoke-eval-before-batch-window discipline for eval-shaped edits:** any .nix edit that must EVAL goes through one cheap single-attr smoke (`nix eval .#checks…<attr>.drvPath`) BEFORE the daemon's ~10-min heuristic commit can sweep it. This session's 37-error window is the case study. (AGENTS.md candidate; harvest row added.)
2. **Read the pinned source BEFORE probing when a mechanism is greppable:** version.nix's warnIf answered in 30s what two eval probes failed to show. Reorder: source-read → hypothesis → probe.
3. **The eval-irrelevant-skip seam needs a targeted gate** (docs-only re-stamps bypass the doc-counts check that exists to catch them) — already queued as [decision] row via 05-30 §f.2.
4. **Worktree-as-eval-surface under sibling lock-red worked superbly** — deserves an AGENTS.md pattern note (2-3 lines) so the next session doesn't re-derive it under pressure (harvest row added).
5. **cp discipline:** never multi-source `cp a b dir/` into a flake tree; one file per cp, verify with status. (Self-rule; not worth a row.)

## f) Next tasks (session-derived; existing rows cited, two new rows harvested)

1. **Lock-audit red resolution** — Critical, S, Bug: if the sibling session is done, land the prescribed consumer follows (or re-regen the lock) + green toplevel proof. Watch row: 05-30 §e.1.
2. **Main-tree green confirmation** post-lock-fix (`flake check --no-build --keep-going`, capture-once) — Critical, S, Quality.
3. **D2 deploy** once authorized + lock green (carries T18/T19 waves) — Critical, M, Feature/Deploy. Owner-gated (g.2).
4. **Post-deploy battery** (anchor check vs newest system-N-link, `post-deploy-check.sh`, §20 Trash gate, trash timer/metric live, tmp-cleanup caps live) — Critical, M, Deploy.
5. **T26 batch 2** (2026-09-27 pair: `09-47_window-closeout-five-tasks`, `…redispatch-churn…`) — High, M, Documentation. Owner pacing-gated (g.3).
6. **Archive pass** for the six resolved 2026-09-26 files (check-rows --strict + bare-rows + `git mv` + manifest) — Medium, S, Documentation. Owner-gated (g.3).
7. **T11 bench legs** — High, M, Quality — PSI-gated (avg10 must be <20 ×3min; was 98.5).
8. **VM-test build-time stateVersion verify** (build one VM test post-calm; the eval wall is proven quiet, build-time forcing is not) — Medium, S, Quality. NEW row (harvested to pipeline.md).
9. **7 remaining T26 batch-1 harvested rows** (figure-change runbook, baseline-discipline rule, closure-claim lint, capture-once ✓done, crush-hot-db fold, planning-docs figure sweep, SigNoz zombie tables ~10G, btrbk doc-PR) — Medium, S-M each, Quality/Documentation (rows live in pipeline/storage/monitoring/upstream.md).
10. **doc-counts pre-commit leg [decision]** (owner answer) — Medium, S, Pipeline. Row: pipeline.md (05-30 §f.2).
11. **Worktree-as-eval-surface AGENTS.md pattern note [decision]** — Low, S, Documentation. NEW row (harvested to pipeline.md).
12. **Remove `~/.cache/systemnix-verify` worktree** after lock settles — Low, S, Cleanup.
13. **Pushes mr-sync / go-cqrs-lite** — Medium, S, upstream (blocked:push; also lock-coupled via float register).
14. **check-todo-system recount** after next prune/batch (186 baseline; not re-run this session) — Low, S, Documentation.
15. **mutation-smoke night-quiet semantics** (pipeline row, 03-58 §f.23) — Medium, S, Bug.
16. **dead-guard-lint v2 non-`-z`/`-n` forms** (pipeline.md:41) — Medium, M, Quality.
17. **cvagent GLM traffic through ai-meter proxy** (pipeline.md row) — Medium, M, Feature.
18. **post-deploy gate-awareness: refused calm-gate ≠ smoke regression** (pipeline.md row) — Medium, S, Bug — becomes live with every refused-gate deploy until landed.
19. **stray `stateVersionBase` semantics doc**: nothing — the makeTest comment carries it; skip (explicitly not queued to avoid noise).

(Not padded to 50: items beyond this are already tracked in the domain libraries; inventing more from memory would violate the report's scope line.)

## g) Questions I cannot answer myself

1. **Lock-red takeover:** the sibling's flake.lock left HEAD failing the infra-follows audit. Is that session finished (→ I land the one-line consumer follows + green proof now), or is more lock work in flight that I must keep hands off? I cannot know their intent; I can only see commit cadence.
2. **D2 deploy authorization (carried, third ask):** fire detached-at-calm vs at-keyboard — the float gate is closed; only the PSI extreme-band and the red lock stand in the way.
3. **T26 pacing + archive policy (carried):** continue month-batches now (holding only for lock-green), and archive the six resolved 2026-09-26 files in the same session or mark-in-place?

> HARVESTED 2026-11-06 (this report): f.8 → pipeline.md [ready] row (VM build-time stateVersion verify); f.11 → pipeline.md [decision] row (worktree-as-eval-surface AGENTS.md note). Items f.1-f.7, f.10, f.13-f.18 already live as tracked rows or owner-gated watch items (cited inline); f.12 is a transient scratch note (05-30 §f.3); f.19 explicitly not queued (no-op). g-questions are owner asks, not work items.
