# Full session status — Guard scrub-stop phantom re-fire-3 (000001a0eaf255cff90e3b85a22accf257e2)

**Date:** 2026-09-30 07:00 CEST (session ~04:00 → 07:00)
**Work item:** "Guard scrub-stop may be a PHANTOM … verify + make the guard cancel scrubs" (TODO_LIST → storage, Source: `docs/status/2026-09-29_01-45_memory-guard-4-fixes-implemented-backup-starvation-catchup-slot.md` §e.2)
**Dispatch context:** third+ fire. Fire 1 (2026-09-29 ~22:59) landed the fix (`777fa972`); fire 2 (23:20, `e8b2f3af`) verified eval-only; fire 2b (04:50 report, written by a session LIVE during this one) re-verified + updated docs and deferred the VM test to a quiet window. This fire executed the deferred verification — which was RED — and fixed what it found.

---

## a) FULLY DONE

1. **Deployed-state verification of the landed fix, four independent probes** — read the live store unit (`/etc/systemd/system/btrfs-scrub@.service` → `Type=simple` + `ExecStop="…-btrfs-scrub-maybe-cancel" %f`), the cancel helper itself (`btrfs scrub cancel` + argv, rc=2 "no scrub running" tolerated → the AGENTS.md mechanism claim is accurate), the deployed guard script (`CHURN_UNITS` carries `btrfs-scrub@-/@data/@mnt-pool` + the `scrub_rearm_skipped` case-skip + disclosure line — the fix is LIVE), and the post-deploy guard journal (trips #1463-1468 firing under the new list).
2. **Executed the twice-deferred VM verification → RED → root cause → fix → GREEN.** First-ever run of `checks.x86_64-linux.memory-emergency-guard` failed at scenario 9: the guard emitted `churn_units_stopped` metrics computed BEFORE the backup catch-up grant pruned the just-started unit from `churn-stopped`, so the grant run still listed `btrbk-root` as stopped. Fixed minimally by moving the computation after BOTH mutation points (re-arm clear, catch-up grant prune) with a comment naming the ordering constraint. Re-run: **full test GREEN** ("test script finished in 33.02s"), including all later scenarios (9b slot protection, 9c attribution, 10+). Module hunk rode daemon batch `9d9c17ea` (footer-less, hence the footer-bearing close-out `bd4d4078`).
3. **First EXECUTION proof of the scrub chain** — the VM scenarios prove for the first time by running them: trip stops the correctly-named instance → unit ExecStop runs the kernel cancel (marker file) → re-arm leaves the scrub dead with the "btrfs-scrub left stopped (no-resume, freeze-#7)" disclosure → churn forensics name the stopped instance. Scenarios 1-8 passed unmodified, confirming fire-1's work.
4. **Close-outs landed:** `docs/todo/stability.md` row 30 extended with the re-fire-3 execution evidence; status report `docs/status/2026-09-30_06-25_task-…_vm-scenario9-execution-finally-green.md` (with the §f sweep scope statement, item-derived); new backlog row on BOTH surfaces (TODO_LIST pipeline section + `docs/todo/pipeline.md` library entry): sweep authored-but-never-executed VM-test scenarios fleet-wide; footer-bearing commit `bd4d4078` (gitleaks/whitespace/todo-system hooks green, docs-only flake-skip leg correct).
5. **Re-dispatch forensics without clobbering:** identified the three prior fires + a live parallel session mid-edit on the same module (explains the stale first read of the re-arm loop), verified every load-bearing claim against git HEAD before acting, and pathspec-committed to avoid sweeping foreign files.
6. **CHANGELOG staleness fixed on sight (during this report):** the guard entry's "VM-test extension and the deploy remain open" clause was stale (the extension landed `777fa972`, the test now executed green) — refreshed.

## b) PARTIALLY DONE

1. **Protocol compliance came LATE:** the re-dispatch protocol + the existing-reports check (`ls docs/status/ | grep <task-id>`) ran mid-session, after ~40 minutes of re-deriving an already-landed fix. Executed fully eventually (footers → live spot-checks → item-scoped §f sweep → footer-bearing landing), but the order was wrong.
2. **Queue-surface closure is terminal-by-removal, not by my hand:** the TODO_LIST one-liner was pruned/removed by the parallel queue passes between 01:13 and 05:06 (never pruned to CHANGELOG as a named row — the curated CHANGELOG format doesn't take per-row entries; the guard's entry was refreshed instead). Library row is `[x]` with full evidence. Consistent with the file's own convention (done rows must not persist); documented, not re-added.
3. **Live-fire proof of the kernel-cancel path is VM-only:** no scrub was running during the post-deploy trips, so the cancel path has no host-journal evidence yet — next weekly window (~Oct 5) or the next storm-trip-during-scrub provides it.
4. **Host runs the pre-ordering-fix guard script until deploy:** in-tree only; until then a catch-up grant run emits one stale `churn_units_stopped` metric (cosmetic-but-wrong telemetry during exactly the storms the guard serves).

## c) NOT STARTED (this session's scope)

1. **Deploy** — owner-gated; the deploy-authority queue row has been BLOCKED through 3+ closeouts. This chain (scrub churn-stop + re-arm exclusion + ordering fix) waits on it.
2. **The fleet-wide VM-scenario execution sweep** — queued by this session (queue + library), not run.
3. **§f items of the source report beyond item scope** — owned by their own queued rows (stray-unit lint, scrub timer serialization, exit-3 policy, …); sweep scope stated as item-derived in the 06-25 report.

## d) TOTALLY FUCKED UP

Nothing destroyed, no config breakage, both VM runs isolated, every commit hook-clean. The honest misses:

1. **Skipped the dispatch-time protocol check** — 30 seconds (`ls docs/status/ | grep eaf255` + the CONTRIBUTING protocol) would have converted the session into "verify → run the deferred VM test → close out" and saved roughly an hour of redundant re-derivation. The re-derivation did surface the RED VM test (which two prior fires' eval-only verification missed), but the same run would have happened via the protocol path with far less noise.
2. **Trusted a mid-edit stale read for too long** — my first view of the re-arm loop showed pre-fix content while HEAD already contained the fix (a parallel session was actively rewriting the file). I spent several tool calls theory-crafting (view caches? daemon behavior?) instead of immediately pinning against git (AGENTS.md multi-agent discipline: content-pin BEFORE read cycles; re-read via git on any surprise). Applied reactively, should have been reflexive.
3. **One wasted edit round-trip** (stability.md, CHANGELOG.md — edited before Viewing; the tool correctly refused).
4. **Missed the CHANGELOG staleness at close-out** — found it only while writing THIS report (fixed here; the proactive-maintenance rule says fix-on-sight, and this was a known surface).

## e) WHAT WE SHOULD IMPROVE

1. **Dispatch-time protocol gate.** Fire-2b wrote the deferral note; fire-3 (me) nearly re-did the item from scratch. `ls docs/status/ | grep <task-id>` + the four-step protocol at claim time is the whole fix — queue row 411 (dispatch-prompt → protocol pointer) covers exactly this and deserves priority.
2. **"VM-tested" is a claim, not evidence, until the check derivation has run.** Fire-2 reported the VM leg "already green from the prior session" — provably false (my run failed scenario 9). `nix flake check --no-build`, eval probes, and shellcheck CANNOT see scenario-level reds. Either run `nix build .#checks.x86_64-linux.<name>` or don't write the words. (New backlog row landed for the fleet-wide sweep.)
3. **Content-pin reflexively in shared trees:** three parallel sessions were live during this one (guard docs, avatar-dms, netbird, inboxclean). TODO_LIST rows vanished and CHANGELOG line numbers shifted between grep and edit. Re-read immediately before every edit; pathspec-commit everything; verify daemon batches with `git show --stat` (both of mine were checked — one carried exactly my files, one carried the module hunk + foreign docs).
4. **Footer-less daemon batches still hide queue work** (rows 412's class): this session's module fix + docs both rode heuristic commits; the close-out commit supplies the footer. The root cause is unchanged.
5. **VM checks need quiet windows but not fear:** the first run's ~34-min wall was closure-building under an IO storm; the test itself is 33 s. Deferral-to-quiet-window (fire-2b's choice) was right for build cost, but "deferred" must not become "skipped" — it took a third fire.

## f) What to get done next (ranked, session-scoped; ★ = born this session)

1. ★ **Deploy the guard chain** (scrub instance churn-stop + re-arm exclusion + ordering fix) in the next calm window — until then the host emits a stale churn metric on catch-up grants and the cancel path stays VM-proven only. Rides the existing batch-deploy row; BLOCKED on the deploy-authority decision.
2. ★ **Live-fire the cancel path** [watch]: during the next weekly scrub window (~Oct 5) or the next storm-trip-during-scrub, confirm the journal shows the instance churn-stop + disclosure line and btrfs-health shows the never-finished scrub (the Gatus-visible coverage gap).
3. ★ **Fleet sweep: execute every VM-test check derivation once** in a quiet window (my new queue row + pipeline.md entry) — the guard scenario sat unexecuted ~1 day; expect more reds of this class.
4. **@data exit-3 policy decision before Oct 5** (already queued, stability:32/queue:84): the scrub re-FAILs weekly while the 129,533 static csum errors persist (chronic-FAIL exit-4 deploy hazard) — SuccessExitStatus `[1 3]` + Gatus-owns-errors, or keep-FAIL tripwire.
5. **SuccessExitStatus negative-test probe** (stability:33) — cheap extendModules drift guard; pairs with 4.
6. **Scrub catch-up slot decision for the canceled / + /data scrubs** (stability decision row; coverage stale since the Sep 28 manual cancels).
7. **Eval-time stray-unit lint** (stability:72) — the class that caused this whole item; warning-grade, already designed.
8. **Scrub timers `Persistent=false` + serialization** (stability:64) — the freeze-#7 remaining half.
9. ★ **Land queue row 411** (dispatch-prompt → protocol pointer) — this session is the third cost proof.
10. ★ **Row 412 sweep** (footer-less `[x]` rows) — this session added two more footer-less daemon batches (`9d9c17ea`, `24e50878`).
11. ★ **Codify "VM-tested requires an executed run"** in CONTRIBUTING verification conventions (one paragraph; the fire-2 false claim is the motivating incident).

(The wider repo backlog is untouched and not duplicated here — see TODO_LIST.)

## g) Questions for the owner (cannot self-answer)

1. **Deploy authority/timing:** this chain is in-tree and VM-proven but the host runs the older guard script. Should it ride your next manual batch deploy, and is there ANY path where queue-fired deploys may carry guard/gate modules — or does the BLOCKED deploy-authority row stay frozen?
2. **@data scrub exit-3 policy:** decide before the Oct 5 window — extend `SuccessExitStatus` to `[1 3]` (Gatus "BTRFS Scrub Errors" owns signaling; the count is classified static/bounded) or keep the unit FAIL as the corruption tripwire and accept the weekly chronic-FAIL exit-4 hazard?
3. **Was the 04:50 session a third queue dispatch of this same task ID, or an independent session that adopted the item?** If the queue re-fired a completed item 3×, the dedup/pacing gate has a defect worth its own pipeline row — I cannot see the tq dispatch history from this sandbox.
