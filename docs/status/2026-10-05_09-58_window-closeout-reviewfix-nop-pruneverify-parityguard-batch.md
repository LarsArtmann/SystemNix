# Window Close-Out — Review-Fix No-Ops, Prune Verification, Parity Guard Batch (7 tasks)

**Date:** 2026-10-05 09:58 CEST
**Window:** 2026-10-03 05:47 → 2026-10-04 02:59 (task completions), verified against tree at HEAD `c6aaa6c5`
**Tasks covered:** `000001a0fed8b75…`, `000001a0fed8bb32…`, `000001a103f14c57…`, `000001a103c819c9…`, `000001a104283c8bb…`, `000001a104283d4667…`, `000001a104283d5200…`
**Overlap note:** a prior close-out (`docs/status/2026-10-05_00-25_window-closeout-parity-guard-prune-verify-review-fix-batch.md`) already covered the prune-verify resolution and parts of this batch; this report is the per-task accounting for the full 7-task window and does not re-derive that narrative.

---

## a) FULLY DONE (verified against the tree, not just claimed)

1. **Splice-finding fix ticket closed as verified no-op** (`000001a0fed8b75…`, report `2026-10-03_05-47`): the finding's mis-spliced `Report:` pointer in the storage.md re-fire-10 row was already healed by `86a38abe` before the dispatch ran; exact-byte verification of the splice site on both surfaces (TODO_LIST.md + docs/todo/storage.md) confirmed correct ordering with separating space. Correct no-op decision — no duplicate fix commit manufactured.
2. **Tail-relocation finding closed as verified no-op** (`000001a0fed8bb32…`, report `2026-10-03_14-21`): all 14–16 rows the finding named as appended after TODO_LIST's closing footer were verified relocated into their `###` sections (lineage `192a9309` → `6f29e8fc` → `dfb00c31` → `15168c12`); exactly one copy of the landing-spot row; closing pointer line is the file's last line; zero duplicate row fingerprints. Honest gap recorded: the rows-after-footer *guard* does not exist yet (discipline-only protection — later closed by the check-todo-system structure legs landed 2026-10-04/05).
3. **10-04 prune-verify task handled correctly under a premature dispatch** (`000001a103f14c57…`, report `2026-10-04_01-09`): the session refused the false close-out (run fires 23:50, dispatch arrived 01:05), verified both 09-20 pins alive live, recorded df pre-state (632G used / 81G free / 89%), re-derived the expiry calendar (10-04 23:50 is the expiry run), and BLOCKED-marked both queue surfaces with a 3-command after-recipe. **Resolution (verified 2026-10-05 00:15 pass, TODO_LIST row 21):** an early `btrbk-pool-clean` activation at 2026-10-04 03:05:13 deleted both 09-20 pins (journal `btrfs subvolume delete`, both prefixes); the 23:50 run then no-oped them. df 632→565G used, 81→138G free, 89%→81% — **~67G net freed** (upper bound; freeze-#13/14/15 recovery cleanups shared the window). Row `[x]` with evidence.
4. **buildcacheDirs↔KNOWN_CACHE_ENTRIES parity selftesting check verified landed** (`000001a103c819c9…`, report `2026-10-04_01-27`): `scripts/check-buildcache-known-parity.sh` (commit `07533607` + fix `e24afb09`) re-verified CONFIRMED — live run `PARITY OK: 15 buildcacheDirs literals covered by 18 KNOWN_CACHE_ENTRIES names`, `--selftest` green (positive control + 3 drift shapes + fail-closed), `nix build .#checks.x86_64-linux.buildcache-known-parity` rc=0. Verification note recorded on the library surface (`83501f42`). CHANGELOG entry exists.
5. **Pre-commit parity leg landed and since live-fire proven** (`000001a104283c8bb…`, reports `2026-10-04_02-11` (lander) + `02-21` (verifier)): `.githooks/pre-commit` leg (commit `8eb8ece6`) runs the parity check directly when either parity source is staged, closing the docs/shell-only-diff skip window. The lander's known gap — "never observed FIRING" — was closed 2026-10-05: the leg was observed firing and passing on a staged whitespace-only parity-source edit through an isolated `GIT_INDEX_FILE` harness (TODO_LIST row 20, `[x]` with transcript). Same commit closed both queue surfaces in sync on first pass.
6. **BLOCKED-marker finding fixed exactly** (`000001a104283d4667…`, report `2026-10-04_02-39`): ` — BLOCKED: verification run fires 2026-10-04 23:50 btrbk-pool-clean; re-dispatch after.` appended to BOTH rows (TODO_LIST + storage.md sibling), fix commit `f9652db3`, single footer, gates green.
7. **Todo-narrative-shrink finding fixed exactly** (`000001a104283d5200…`, report `2026-10-04_02-59`): both prune-verify pre-state rows shrunk to one-liners (pre-state summary + report link + after-recipe + BLOCKED marker), everything else moved to the status report per the AGENTS.md TODO-system convention; fix commit `92e31273`; queue↔library parity maintained; pathspec-commit discipline applied.

## b) PARTIALLY DONE

1. **The prune-verify item itself** was, at window close, half-done by design (pre-state recorded, measurement pending the 23:50 run) — since fully closed (see a.3). The early-activation timing surprise it exposed is queued as an owner question (TODO_LIST row 106).
2. **Regression protection at window close was discipline-only for two classes**, both since fenced: the rows-after-footer guard and the BLOCKED-marker/time-gate lint leg (check-todo-system check 5, landed 2026-10-04 movie-window session, TODO_LIST row 759 `[x]`). The annotation-verbosity guard (the 02-59 finding's class) is still OPEN — queued TODO_LIST row 611.
3. **Daemon-race residual window on staged-path legs** (the parity leg keys on staged paths; a daemon sweep that commits the source first skips the leg on amend — the 2026-09-28 heal-breadcrumb class): inherent, noted in both parity reports, not fixed; the rename-proof row (TODO_LIST 104) covers the sibling orphaning hazard.

## c) NOT STARTED (backlog the window skipped)

Nothing owed by these 7 tickets was skipped. Standing backlog observed un-touched and unchanged by the window: the >90% root auto-prune trigger (row 22), the 51 queue↔library pairing drifts and ~87 unharvested §f-bearing reports (WARN-only gate, pipeline rows), the btrbk-root send-kill streak (3 nights by 10-04, now TODO_LIST row 107 BLOCKED on owner posture), and the full 600+-row open queue.

## d) TOTALLY FUCKED UP

1. **The dispatch machinery harvested a time-gated row ~23h early** — the root cause of this window's entire fix chain. The premature harvest produced a pre-state commit (`90cb3434`) whose narrative bloat then drew TWO reviewer findings (unfinished rows missing BLOCKED marker; system-state narratives in todo files), i.e. one premature dispatch cost three extra dispatch cycles plus two review rounds. The BLOCKED-marker repair was made **by hand**; the enforcement leg only landed later via a different session. The structural fix (a `[ready:after <time>]`-style gate the harvester respects) does not exist — new BLOCKED question this report.
2. **The re-fire loop kept burning after the window.** The two reviewer-fix ticket families from this window's neighborhood re-fired 5–9 times on 2026-10-05 against stale git-state premises (findings asserting `4da612b8` dangling when merge-base proves it an ancestor of HEAD — every fire re-verified instead of halting). TODO_LIST row 18 is now a ~9-stamp wall. Intake premise-gate row queued (613); the dispatcher-side dedup/halt gate remains unbuilt and is itself blocked on the owner's double-dispatch-semantics answer (row 612).
3. **Double-dispatch proven live inside the window**: task `000001a104283c8bb` went to two concurrent sessions 10 minutes apart (02-11 lander, 02-21 verifier) — two reports, one Task-Queue-ID. No damage (the verifier correctly no-op'd), but it is the second live exhibit that the dedup gate is needed and cannot be built until dispatch semantics are confirmed.
4. **Docs debt counters grew through the window**: check-todo-system WARN-class drift stood at 51 pairing drifts + 86→87 unharvested §f reports at window close, both growing every dispatch window. WARN-not-fail means they cost nothing today and compound later.
5. **Nothing code-side broke.** The window's only non-doc artifact (the pre-commit parity leg) is selftesting-wired and since positively live-fired. The 10-05 `bank-sync.nix` flake-check failure flagged in later fire reports is a foreign parallel-session surface, not this window's.

## e) WHAT WE SHOULD IMPROVE

1. **Verify-before-dispatch on the queue side, not just the agent side**: three of seven tasks were re-dispatches onto already-landed or time-gated work. A harvester preflight ([x] row + footer-bearing commit → skip; time-gated language → hold) would have made this entire window ~3 tasks instead of 7. Blocked on owner semantics decisions (rows 505/612 + the new time-gate question).
2. **Premise-check reviewer findings at intake** — every 10-05 re-fire traceable to one stale dangling-commit premise; row 613 has the protocol clause. Cheap, high leverage.
3. **Guards over discipline, consistently**: the window produced two hand-repairs (BLOCKED markers, row shrink) of exactly the classes that later got lint legs. Land the guard in the same session as the convention repair, not a window later.
4. **Self-harvest at authoring worked well here** (01-27 and 02-39 reports routed their new items at authoring time; the 02-59 report explicitly deferred one item to the dispatcher — it has since been queued as row 611, so the deferral resolved safely). Keep the explicit-disposition pattern.

## f) NEXT THINGS

Nearly all follow-ups from the window's six §f inventories are already queued and several since DONE (live-fire of the parity leg: row 20 `[x]`; BLOCKED-marker lint: row 759 `[x]`; premise-gate: row 613; verbosity guard: row 611; rename-proof: row 104; 4th drift shape: row 105). Genuinely NEW items harvested by this close-out (appended to TODO_LIST.md, dedup-checked):

1. **Run-gated queue tag** (`[ready:after <datetime>]` or a not-before field the tq harvester respects) — the premature-harvest class is structural and will recur for every "verify the nightly/weekly run" item. Owner decision (touches the harvester) → BLOCKED question.
2. **Tail-section legality convention** — are the dated `### … (harvest …)` sections legal forever or transitional? Decides the scope of the closing-footer guard. → BLOCKED question.
3. **No-op fire closure semantics** — close a fix ticket when the finding is verified already-healed, or hold until a guard fences the class? → BLOCKED question.
4. **Park the KNOWN_CACHE_ENTRIES parent ticket** (`000001a0f97e2c06…`, ~10 fires, fix-family churn exceeding the original work) until the re-fire sweep answers whether appended verification rows re-feed the pool. → BLOCKED question.

## g) QUESTIONS FOR THE OWNER (appended as BLOCKED items)

1. Should the tq queue format gain a run-gated / not-before tag the harvester respects, so time-gated verification items stop being dispatched hours before their subject event?
2. Are the dated `### … (harvest …)` tail sections in TODO_LIST.md legal forever (guard checks only post-footer text) or transitional (guard eventually flags them)?
3. Does a no-op fix fire close its ticket (verified-healed) or stay open until a regression guard lands? And should the ~10-fire KNOWN_CACHE_ENTRIES parent be deliberately parked?

## h) BAND DRIFT

**None recorded.** `tq facts` contains zero `task.reprioritized` events (grep count 0 across the whole journal, hence none in the window's timespan 2026-10-03 → 2026-10-05). No priority moved via marker, ai, unblock, or importance; the only queue churn was lifecycle events (claims, requeues, completions) on this window's items.

---

*Point-in-time snapshot. Sources: the seven per-task reports cited in §a, TODO_LIST.md @ HEAD `c6aaa6c5`, `git log` lineage `86a38abe`/`15168c12`/`07533607`/`e24afb09`/`83501f42`/`8eb8ece6`/`90cb3434`/`f9652db3`/`92e31273`, `tq facts` (reprioritized = 0).*
