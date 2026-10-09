# Window Close-Out — buildcache parity guard + prune-verify chain + four review-fix fires (2026-10-03 → 2026-10-04)

**Written:** 2026-10-05 00:25 CEST (task `000001a108f0f6052cb68346b6b400000000`)
**Window:** 7 completed tasks, closeouts spanning 2026-10-03 05:47 → 2026-10-04 02:59
**Method:** every closeout report read first; every load-bearing claim re-verified against the tree, git, and live system probes on 2026-10-05 00:10–00:30.

---

## a) FULLY DONE (verified, not just claimed)

1. **`000001a0fed8b75f` (splice finding re-fire) — no-op, verified.** The mis-spliced `Report:` pointer in the storage.md re-fire-10 row was already repaired by `86a38abe` (in HEAD's history, `merge-base --is-ancestor` confirmed by that fire). Report commit `23128e24` (05:48). Correct no-op: a second fix would have duplicated the lineage under a fresh Task-Queue-ID.
2. **`000001a0fed8bb32` (tail-relocation finding re-fire) — no-op, verified.** All 14 rows the finding named were confirmed inside their domain sections (5 storage, 3 monitoring, 1 stability, 1 desktop, 1 services, plus the single landing-spot copy under pipeline). Report commit `7528e65f` (14:23). The ca60b35b tail-append class was healed by the 192a9309 → 6f29e8fc → dfb00c31 lineage before this fire.
3. **`000001a103c819c9` (buildcacheDirs↔KNOWN_CACHE_ENTRIES parity check) — re-dispatch VERIFIED, work pre-landed.** Script `scripts/check-buildcache-known-parity.sh` + `checks.x86_64-linux.buildcache-known-parity` (flake.nix:3410). Re-verified live this pass: `--selftest` green — `PARITY OK: 15 buildcacheDirs literals covered by 18 KNOWN_CACHE_ENTRIES names`, all 3 drift shapes rejected, fail-closed on empty extraction.
4. **`000001a104283c8bb` (parity pre-commit guard) — LANDED + verified no-op on the second fire.** A sibling session landed the hook leg (`8eb8ece6`, 01:59): `.githooks/pre-commit:413-414` runs the parity check whenever `modules/nixos/services/buildcache.nix` or `scripts/das-link-recovery-check.sh` is staged — closing the docs/shell-only-diff skip window that let hand-edits commit without the guard. The 02:21 fire verified the leg's presence and the selftest without re-landing anything. Both queue surfaces closed in the landing commit (TODO_LIST.md:19 + storage.md).
5. **`000001a104283d4667` (review fix: BLOCKED markers) — done.** `— BLOCKED: verification run fires 2026-10-04 23:50…` appended to both prune-verify rows (TODO_LIST.md:21 + storage.md:182) in `f9652db3` (02:36); report `e7766053` (02:43). Marker presence re-verified live on row 21 this pass. Its §e.1 follow-up (BLOCKED-marker lint leg) was subsequently landed by the 10-04 evening movie-window session (TODO_LIST row now `[x]`, check 5 of check-todo-system.sh).
6. **`000001a104283d5200` (review fix: todo-narrative shrink) — done.** `92e31273` (02:58) shrank both prune-verify pre-state rows to one-liners (pre-state summary + report link + after-recipe + BLOCKED marker), honoring the "NO system-state narratives in todo files" convention; report `4bffb06d` (03:00). Row 21's current shape confirms the shrink.

## b) PARTIALLY DONE

1. **`000001a103f14c57` — the prune verification itself (the window's only open work item).** The window recorded the pre-state (09-20 pins ALIVE, df 632G used / 81G free / 89% at 01:05) and correctly refused a false close-out ~23h before the named run. **This pass closed it with live evidence** (row ticked):
   - Both pins deleted: `journalctl` shows `btrbk` running `btrfs subvolume delete /mnt/btrfs-root/.snapshots/@.20260920T2300` and `@home-hermes.20260920T2300` — but at **2026-10-04 03:05:13–14**, inside the freeze-#13 storm window, when an early `btrbk-pool-clean.service` activation ran its retention prune (started 03:05:13, finished 03:05:16). The 23:50 run the row named fired later the same day and correctly found nothing to do for them (it pool-deleted `@.20261001T2300` instead).
   - df after: **565G used / 138G free / 81%** (00:15 probe) vs pre-state 632G/81G/89% → **~67G net freed** (used −67G, free +57G), far better than the ~40G du-based expectation and 20× the 10-02 emergency prune's 3G — the shared-extent caveat cut the other way this time.
   - Attribution caveat: the 67G is the net root-fs delta since the 01:05 pre-state; other recovery cleanups ran in the same window (freeze-#13/14/15), so 67G is an upper bound on the pins' specific contribution — but the pins' deletion is journal-proven and the pins were the only large expiries scheduled that night.
2. **Pre-commit parity leg positive-fire proof** — wiring verified grep-level + selftest + live negative path, but the leg has never been observed executing on a real staged parity-source edit (queued TODO_LIST row, the 02-11 sibling report §b.1).
3. **The two no-op review-fix fires** produced zero code by design (anchor text already absent) — their "partial" is that the classes they name are prevented by discipline only: the rows-after-closing-footer guard and the spliced-pointer guard are still unbuilt (§c).

## c) NOT STARTED (window skipped; all still open)

1. **Rows-after-closing-footer guard** in `check-todo-system.sh` (TODO_LIST:377) — the ca60b35b class's durable fence; 3rd+ report asking for it.
2. **Queue dedup/halt gate** (TODO_LIST:399, pipeline.md:170) — this window added its two cleanest exhibits: a same-ID double-dispatch 15 minutes apart (02-11 lander + 02-21 verifier) and a re-dispatched verification of an `[x]`-closed row (01-27).
3. **Live-fire proof of the parity pre-commit leg** (TODO_LIST:20).
4. **>90% root auto-prune trigger** (TODO_LIST:22) — tonight's 81% is the calmest root has been since 09-20; the trigger remains unimplemented.
5. **Annotation-verbosity guard** (02-59 report §e.3/§f.2) — was NOT queued by its own fire (explicitly left for the dispatcher); appended to the queue by this pass.
6. **63 queue↔library drifts + the unharvested-report backlog** (TODO_LIST:246/247) — WARN count now **88** (was 87 at the 02:39 fire; 3 of this window's 8 reports contributed; this pass adds markers for those 3).
7. **Time-gated queue format** (`[ready:after …]` → the harvester's native NOTBEFORE; upstream.md:74/75) — unbuilt; the 01:05 harvest of a 23:50 item cost this window three of its seven dispatches.

## d) TOTALLY FUCKED UP

1. **Dispatch-efficiency collapse: 5 of 7 tasks were verification-only fires.** Four review-fix re-fires adjudicated findings whose repairs had already landed under other lineages (some dangling-SHA, pre-rebase), and one re-dispatch re-verified an `[x]`-closed row. Only two in-window tasks produced changes (both docs-only); the window's only code landing (`8eb8ece6`) came from a sibling session dispatched the same ID concurrently. The re-fire/double-dispatch pathology first documented 2026-09-24 now has its most concentrated exhibit set — and the structural gate remains queued, not built.
2. **The 23h-early harvest cascade.** Dispatching the prune-verify at 01:05 for a 23:50 event manufactured three downstream artifacts (pre-state report, BLOCKED-marker review fix, narrative-shrink review fix) — plus a reviewer cycle each. The queue format could have prevented all of it with a time gate that `tq` already supports natively (NOTBEFORE column exists in `tq tasks`); only the item-text → field wiring is missing.
3. **Two fix tickets fought over the same two rows.** 02-39 added BLOCKED markers to the prune rows; 02-59 then shrank the same rows' narratives. Each was correct for its own finding, but the sequence shows the real defect (narratives in todo rows) was caught only after the marker fix had already touched the rows — the verbosity guard (now queued) is the systemic tail of exactly this.
4. **Marker debt: 3 of the window's 8 reports shipped unharvested** (14-21, 01-27, 02-21) — the self-harvest convention exists, the lint exists, authoring-time compliance still doesn't. Fixed for these three by this pass; the standing 88-file backlog keeps its own queued sweep row.
5. **Nothing in the tree is broken.** Docs-only commits all window; `check-todo-system.sh` → `OK` (WARN-only, pre-existing); parity selftest green tonight; no eval surfaces touched; no secrets; working tree clean at pass start.

## e) WHAT WE SHOULD IMPROVE

1. **Build the dedup preflight at the harness level** — skip dispatch when the queue row is `[x]` AND a footer-bearing commit for the ID exists. It would have consumed 5 of this window's 7 fires. Requires the owner's answer on double-dispatch semantics first (§g.2) — if verify-after-land is intentional, the gate needs a "verify" dispatch type instead of a blanket skip.
2. **Wire time-gates into the harvester**: parse `[ready:after DATE TIME]` (or a structured field) into `tq`'s native NOTBEFORE. The 01-09 fire's §e.1 proposed this; upstream rows 74/75 already carry the ask; the machinery half-exists.
3. **Verification recipes should name the trigger UNIT, not just a clock time.** "the 23:50 btrbk-pool-clean run" was wrong about which execution did the work — the 03:05 Persistent-style activation pruned the pins. A recipe of the form "confirm unit X's run at/before TIME" would have attributed correctly on the first journal look.
4. **Guard-before-discipline, batch four small fence items**: rows-after-closing-footer (queued), annotation-verbosity (queued this pass), parity-leg rename-proof (queued this pass), 4th selftest drift shape (queued this pass). All are selftesting-lint class, all cheap.
5. **Self-harvest compliance needs teeth at authoring time**, not post-hoc sweeps: the reports that carry inline dispositions (05-47, 02-39, 02-59) passed the lint without queue edits; the three that shipped bare §f tables did not. The convention sentence in AGENTS.md is insufficient — consider making the report template's §f stub include the marker keyword by default.
6. **No-op fix dispatches should converge in one fire**: fire 1 of each review-fix family re-derived what a `merge-base --is-ancestor` + anchor-grep preflight would have answered. The CONTRIBUTING re-dispatch protocol has the steps; fix-ticket dispatches don't run them as a preflight.

## f) NEXT THINGS (impact-sorted; dedup-checked against TODO_LIST.md at pass time)

_Already queued — do not re-add:_ prune-verify aftermath (closed this pass), live-fire parity leg (TODO_LIST:20), >90% auto-prune (22), rows-after-closing-footer guard (377), re-fire/dedup gate (399), drifts 63 (246), unharvested backlog (247), compaction convention (43), GOBUGGY/writer hunts (40/41), pre-commit amend-awareness (pipeline), gate-hardness decisions (inside 246/247).

1. **Answer the three §g questions below** — each gates a queued structural fix (dedup gate shape, retention-timer policy, send-leg posture).
2. **Dedup preflight implementation** (after §g.2) — harness-level, biggest single waste-killer.
3. **Time-gate wiring** (`[ready:after …]` → NOTBEFORE) — prevents the next 23h-early cascade.
4. **Rows-after-closing-footer guard** — closes the ca60b35b class permanently.
5. **Live-fire the parity pre-commit leg once** (whitespace edit → leg fires → restore) at a quiescent moment.
6. **>90% auto-prune trigger** — root at 81% tonight is the implementation window; the 100% class has fired twice.
7. **btrbk-root send-leg repair or posture decision** — third consecutive signal-kill night (10-04 23:04); pool receives stale; `btrfs-verify-pool-backups` failing both prefixes (§g.3).
8. **Annotation-verbosity guard** (queued this pass) — converts the narrative-in-todos review class into a lint.
9. **Sweep the 63 queue↔library drifts**, then decide gate hardness — every window wades through them.
10. **Mega-harvest the 88 unharvested reports** in domain batches (storage/pipeline first — the count only drifts up).
11. **Parity-leg rename-proof + 4th selftest drift shape** (queued this pass) — two 30-minute fence items.
12. **Multi-stamp queue-row compaction convention** (TODO_LIST:43) — the 10-stamp RE-FIRE row is still the poster child.
13. **golangci-lint-analysis writer hunt** (TODO_LIST:41) — the transient keeps regrowing; the bless-or-fix decision blocks the [6] quiet-down.
14. **`check-todo-system.sh` WARN budget** — decide whether WARN counts (51 drifts / 88 unharvested) get a visible budget line in the gate output so drift direction is readable at a glance.
15. **Correct the "expect ~+40G" figure wherever the prune recipe is cited** — actual net was ~67G; the du-based prediction class keeps underestimating after un-sharing (both directions now observed: 3G and 67G vs 40G nominal).

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Should retention-expiry timers (btrbk-pool-clean et al.) be exempt from Persistent-style catch-up activation?** The 09-20 pins were pruned at 03:05 on 10-04 — 20h before the run the queue item named — because an early pool-clean activation fired inside the freeze-#13 storm window. Outcome was good (space back sooner), but expiry timing is now unpredictable from the item text. Pin expiry-critical timers to their calendar slot, or accept catch-up as the standing mechanism? _(queued as a BLOCKED item in storage)_
2. **Is concurrent double-dispatch of one task ID ever intentional** (a lander session + a verifier session), as happened twice in this window (`000001a104283c8bb` → 02-11/02-21 reports; the pre-commit leg)? The queued dedup gate would break a deliberate verify-after-land pattern — I need the intended semantics before building it. _(queued as a BLOCKED item in pipeline)_
3. **Does the third consecutive signal-killed btrbk-root night (10-02/03/04, memory-guard era) reopen the 2026-09-21 "let the 23:00 self-heal ride" posture?** Local prunes are send-independent since 10-01 so expiry still lands (this window's 67G is proof), but pool receives stay stale and the backup verifier keeps failing both prefixes. Shift the btrbk-root window, raise the catch-up bar, or keep riding? _(queued as a BLOCKED item in storage)_

## h) BAND DRIFT

**None recorded.** `tq facts --type task.reprioritized` returns 0 facts for the window's timespan — and 0 for the journal's entire history (9,324+ facts). No priority moved in this window, so there is nothing to explain; conversely, ADR-0015 accountability remains structurally vacuous until go-taskqueue emits the fact type (standing row: TODO_LIST "go-taskqueue upstream: emit a `task.reprioritized` journal fact").

---

## Pass artifacts (this commit)

- TODO_LIST.md: prune-verify row ticked `[x]` with the journal+df evidence; 6 new rows appended (3 `[ready]` guards/fences + 3 owner-question BLOCKED items from §g).
- CHANGELOG.md: entry for the buildcache parity check + pre-commit guard arc (the window's user-visible repo-infra changes).
- Harvest markers appended to the three unharvested window reports (2026-10-03_14-21, 2026-10-04_01-27, 2026-10-04_02-21).
- No archive moves: none of the window's reports is fully resolved (open §f pointers and §g questions remain in each); annotations suffice.
