# forgejo backup close-out: seed landed + verified, stray cleaned, burn-in 2/2, shadow trashed; guard re-arm ROOT-CAUSED (is-active misses activating oneshots) + both defects fixed in-tree

Date: 2026-10-11 05:10–19:05 CEST (one session, three user pivots). Chain: "do we backup forgejo?" → the 0B-snapshot mystery → the storm-killed seed → manual re-seed + stray cleanup → burn-in → shadow trash → root-cause + fix both defects found on the way. Prior session context: `2026-10-11_05-05_*` (setup-forgejo CI classes) and `2026-10-11_02-17_*` (G1 window). This report supersedes the 06:10 interim report's open items.

## a) FULLY DONE

1. **0B-snapshot mystery closed (the original question):** all 25 pool snapshots (10-01..10-10) are received snapshots of the then-EMPTY `hot/forgejo` subvol — the pre-finalize phantom window (family condition-skipped by design; data safe on the QLC shadow). `[error opening dir]` = root-owned 0700 subvols vs a non-root tree walker (benign). Not corruption; the btrbk leg proved mount+schedule, never content — the exact phantom-backup class the repo's G1-gate-VOID row predicted.
2. **First seed attempt (05:40) root-caused to the second:** guard trip #2663 (Zone 6, io PSI some avg60 43.34%, disk busy 100%) TERMed `btrbk-forgejo` mid-receive at 2m33s (17G/67G streamed). NOT a timeout (`TimeoutStartSec=6h` confirmed in the live unit). Owner du later confirmed the partial on disk: Total 17.00GiB / Exclusive 17.00GiB — exactly the kill point.
3. **Freshness-metric phantom modes discovered (2, both live-observed):** (a) received-subvol root mtime is INHERITED from the source subvol (pre-seed age read 10.1 days off the frozen empty root); (b) the killed receive bumped the received-root mtime to the kill moment → `fresh=1` on an INCOMPLETE backup. mtime proves neither content nor completeness.
4. **Seed LANDED (attempt 2, owner-manual 07:06, calm window):** `forgejo.20261011T0706` received clean, **70.41GiB du-verified** (≈ the 71.75G finalize measure), 70.4G read / 70.6G written in 6m37s (~180 MB/s). Content-floor assertion CLOSED.
5. **Exit-10 + stray explained and cleaned:** the unit "failed" only because the killed attempt's 17G partial lingered as a stray (btrbk never auto-deletes received subvols). Owner ran `btrbk clean` 08:37 → stray deleted; `reset-failed` cleared the red state. Until then every run exit-10'd and paged OnFailure on a SUCCEEDED backup.
6. **Burn-in 2/2 COMPLETE:** leg 2 = 13:40:14 run Finished (14.7s, 242M), and btrbk back-filled the cleaned `0540` as a cheap incremental — pool chain complete `2140 → 0540 → 0706 → 1340`.
7. **QLC shadow trashed (owner, 18:35):** `/var/lib/forgejo.qlc-pre-subvol` gone from `/var/lib`; forgejo unaffected (process alive, pool chain + `fresh=1` intact). NUANCE verified live: the 67G moved into root's trash on the SAME QLC fs — the space frees only on `trash-empty`, not at trash time (root fs Used went 585.85G → 592G).
8. **Guard re-arm ROOT-CAUSED (the session's deepest find):** `systemctl is-active --quiet` exits NON-ZERO for Type=oneshot units mid-ExecStart (state `activating`). The trip action's recording loop therefore missed every oneshot kill — the churn-stopped file was NEVER written, so re-arm, the starvation clock, AND the catch-up-slot machinery were dead-on-arrival in production (`churn_rearms_total 0` ever, `backup_starved` never flipped, `catchup_slots_total 0`) — while VM scenarios passed green because the fixtures were simple-type (`active`). The fix is one state read: `systemctl show -p ActiveState` + case `active|activating|reloading`.
9. **BOTH defects fixed in-tree, `nix flake check --no-build` GREEN ×2:**
   - Guard: recording loop uses ActiveState (memory-emergency-guard.nix); test fixture `btrbk-root` flipped to the real oneshot shape (Type=oneshot + sleep 300) so scenario 9's existing `churn_units_stopped` assertion IS the regression test (fails under old code); the two post-grant `is-active` asserts updated to `= activating` (is-active cannot accept activating).
   - Metric: `forgejo_subvol_backup_fresh` now requires age < 12h AND ≥3 top-level entries (new `forgejo_subvol_backup_top_level_entries` gauge) — empty-tree/content classes fail closed.
   - Plus a daily `btrbk-forgejo-clean` service/timer (04:15, quiet by design) sweeping guard-killed partial receives so exit-10 noise cannot linger.
10. **Row/queue discipline held through 6 hostile-to-edit rounds:** every surface (TODO_LIST, docs/todo/services.md, docs/todo/stability.md, docs/services/forgejo.md, 2 status reports) kept in sync at each state transition; check-todo-system clean for this session's rows at every pass (rc=1 is the standing pre-existing backlog: 101 unharvested reports, 61 drifts, 3 time-gate FAILs — none authored here).

## b) PARTIALLY DONE

1. **Guard VM test NOT run** (`nix build .#checks.x86_64-linux.memory-emergency-guard`): the box stormed all day (48 trip-lines; avg60 41-68% at decision time) — stacking a qemu build onto it is the freeze-7 reader-stacking class. The change touches the recording path scenarios 8/9 exercise; landing without the run repeats the 2026-09-30 scenario-9 lesson, so it is queued as the FIRST action in the next quiet window (§f.1).
2. **Deploy pending (owner-gated):** both fixes + the parallel session's forgejo-restore-drill unit are in-tree, undeployed. Post-deploy watch list: `churn_rearms_total` increments on the first storm→drain cycle; `forgejo_subvol_backup_top_level_entries` gauge appears; `btrbk-forgejo-clean.timer` registers and first run exits 0.
3. **67G QLC reclaim:** pending `trash-empty` (owner call — irreversible).
4. **Metric boundary honesty:** the entry floor catches the empty-tree class; the partial-receive class is bounded by the daily clean sweep + the immediate OnFailure page at kill time, NOT by the 5-min metric. The Received-UUID completeness signal was explored and rejected (needs CAP_SYS_ADMIN in a deliberately hardened unit — a weakening the hardening doctrine exists to prevent). That rejected-alternative reasoning should be persisted (§e.5).

## c) NOT STARTED

1. **F24 restore drill first execution** — the parallel session's `forgejo-restore-drill` unit is in-tree but undeployed and never run: restore `forgejo.20261011T1340` (or newest) to scratch + diff. "Backups you have never restore-tested are hopes, not backups."
2. **Guard-runbook update for the activating-oneshot blind spot** (docs/services/memory-emergency-guard.md) — post-deploy, one paragraph.
3. **Cross-project lesson:** "is-active misses activating oneshots" + "btrbk receive presence ≠ completion" → `references/lessons.md` in the crush-config repo (committed THERE per the foreign-repo rule).

## d) TOTALLY FUCKED UP

1. **My first watcher (shell 005) shipped with a self-matching pgrep pattern** — `pgrep -f 'btrbk|btrfs send|btrfs receive'` matches the watcher's own cmdline, which would have stalled the workers-gone poll at its full 30-min cap. Caught and relaunched (shell 007, `[b]trbk` char-class) before damage, but it was broken on first attempt and only review-by-self saved it.
2. **The "Exclusive ≈0" prediction was wrong and I wrote it down before verifying:** I asserted (chat + status report §c.1) that a landed seed would read "Exclusive ≈0, shared with the live subvol" — btrfs fi du sharing only counts within the SCANNED pool filesystem, so Exclusive reads ≈Total. The user's 17G reading surfaced it; I corrected the report only then. du semantics are checkable in the man page — checking would have cost one minute.
3. **Verification theater nearly happened at 05:43:** the watcher reported "LOCAL OK / POOL DIR PRESENT" — which is the receive START, not completion. Only because the evidence dump included the journal tail (SIGTERM + Failed) did the failure surface. Had the dump not captured the journal, I'd have reported the seed landed while it was being killed. Lesson: for async transfers, presence of the target name is a start signal, never a done signal.
4. **Edit hygiene slips under speed:** a mangled old_string (duplicated path) on the report §c.1 edit; a read-before-edit refusal on the first services.md multiedit; a multiedit new_string that accidentally deleted two live assertion lines in the test (caught by re-viewing the region immediately, repaired same turn); two line-number collisions with the parallel session (fixed by exact-match re-reads). None landed broken — but four self-inflicted retries in one session is sloppiness, and each was preventable by re-pinning before the call.
5. **The `entries -ge 3` floor is reasoned, not measured:** I never counted the real forgejo tree's top-level entries; the floor's correctness rests on my layout assumption (data/, repositories/, custom/…). If the real count were ≤2, the fixed metric would false-fail fresh forever. Must be verified live post-deploy (§f.4) — and the VM/manual verification should have preceded writing the constant.
6. **Queue-discipline mistake:** the pending VM test + deploy are buried inside a `[x]` (closed) stability row — a closed row is prune-fodder and the pool harvests only [ready] rows, so the session's most actionable next step was nearly invisible to dispatch. Harvested as its own [ready] row at report time (§f.1) — but it should never have been folded into a closed row in the first place.

## e) WHAT WE SHOULD IMPROVE

1. **Async-completion verification doctrine:** for send/receive-style jobs, "target name appeared" must be explicitly distinguished from "worker exited 0" in every watcher — the probe set (journal tail + worker-process absence) worked; encode it as the default watcher shape.
2. **Fixture fidelity doctrine:** VM-test dummies must reproduce the REAL unit Type of what they stand in for (btrbk = oneshot). The simple-type fixture is what hid a production-dead subsystem behind green scenarios.
3. **Predictions written into reports must cite their source** (man page, prior artifact) or carry an UNVERIFIED marker — the Exclusive≈0 line would have been caught at authoring time.
4. **Watcher scripts get a self-match audit before launch** (char-class the pgrep patterns, always).
5. **Persist rejected alternatives with their tradeoff** (Received-UUID completeness vs CAP_SYS_ADMIN hardening) next to the chosen fix, so the next reader doesn't re-litigate.
6. **Closed rows must not carry open next-actions** — harvest them forward at authoring time (done this time, late).
7. **Threshold constants introduced in collectors get measured, not assumed** (count the real tree before shipping the floor — one `ls | wc -l` as the forgejo user pre-deploy would have settled it).

## f) NEXT (up to 50, ordered; harvested or already-queued as marked)

1. **[ready — queued at report time]** Run the guard VM test in the first sustained quiet window (io PSI some avg60 < 25 for ≥5 min): `nix build .#checks.x86_64-linux.memory-emergency-guard`; red = fix before deploy.
2. **[blocked:deploy]** Deploy both fixes (`nix run .#deploy`) — bundles the parallel session's forgejo-restore-drill unit.
3. **[watch]** Post-deploy: `churn_rearms_total` increments on the first storm→drain cycle (the counter's first-ever increment).
4. **[watch]** Post-deploy: `forgejo_subvol_backup_top_level_entries` gauge appears and `fresh=1` holds on the real tree (validates the assumed floor of 3 — measure the real count, adjust if wrong).
5. **[watch]** Post-deploy: `btrbk-forgejo-clean.timer` registers; first 04:15 run exits 0.
6. **[ready]** F24 restore drill first execution post-deploy (restore newest pool snapshot to scratch + diff) — the drill unit exists; run it once manually.
7. **[blocked:user]** `trash-empty` decision — frees the 67G on the QLC (irreversible).
8. **[watch]** Tonight's 21:40 btrbk slot (storm-contested; 12h freshness gate tolerates one miss).
9. **[watch]** Retention starts pruning the 24 empty phantoms (~Oct 17, target_preserve_min 7d).
10. **[ready]** Guard runbook: document the activating-oneshot blind spot + fix (post-deploy).
11. **[decision]** Persist the Received-UUID-vs-CAP_SYS_ADMIN rejected alternative (services.md row or runbook note).
12. **[decision]** Catch-up-slot protect-window calibration: should it cover a ~10-min 67G seed (config change), given no byte-resume.
13. **[ready]** Cross-project lessons to crush-config `references/lessons.md`: is-active/activating blind spot; receive presence ≠ completion; watcher self-match audit.
14. **[ready]** `setup-forgejo.sh` promotion decision (carried, failure-class 6).
15. **[blocked:user]** Architecture-catalog chain: sops-paste sync token, cancel stale runs 1-3, delete 4 orphan PATs, first green CI run + dist branch watch.
16. **[watch]** Runner pickup of the first post-sync push-event run (auto-dispatch class).
17. **[ready]** Storm-driver attribution for today's oscillation (48 trips; io-psi-forensics bundles exist on disk) — identify the daytime driver.
18. **[blocked:user]** flm socket manual restart when memory is healthy (restore-capped all day; pre-existing).
19. **[ready]** 101-report harvest backlog (standing; harvest checker glob-citation fix queued separately).
20. **[ready]** check-todo-system: 61 drift rows + 3 time-gate FAIL rows (pre-existing; scanner-side fixes per lint doctrine).
21. **[ready]** Harvest checker: accept basename-prefix globs (carried by the 05:05 report).
22. **[ready]** Label-drift eval selftest + stderr-suppression grep-guard leg (carried by the 05:05 report).
23. **[ready]** Runbook capture: v15 token-API auth semantics + forgejo.db-vs-gitea.db fossil + revoke-via-sqlite pattern (carried).
24. **[blocked:user]** Trash the `/var/lib/forgejo/data/gitea.db` fossil after sudo confirmation (carried).
25. **[decision]** Promote `setup-forgejo.sh` into SystemNix with fixtures (carried §g.2).
26. **[watch]** Forgejo dump-zip leg tonight 03:30 (post-deploy generation) + first zip content spot check.
27. **[watch]** `forgejo_mirror_*` live metric flow + Gatus checks verification (queued row, root-owned surfaces).
28. **[decision]** Offsite Borg go-live inputs (the 3-2-1 gap stands; forgejo now has 2 local copies only).
29. **[ready]** Dual-copy prune answer for DarkBlocks/DialogesWebInterface (carried from 02-17 §g2).
30. **[ready]** Frozen-archive 32-repo inventory persistence (journal-only today; queued row from the 02 session).

## g) QUESTIONS (cannot figure out myself)

1. **Deploy timing:** deploy the in-tree batch (guard fix + metric floor + clean timer + the parallel session's restore-drill unit) in the next calm window tonight, or hold for a bundle? (I will not deploy autonomously per contract.)
2. **Trash-empty appetite:** empty root's trash now to actually free the 67G, or defer to a retention pass? (Irreversible — the shadow is the pre-migration safety copy.)
3. **VM-test authorization:** if a sub-25-PSI window opens in the next hours, may I run the ~2-5 min qemu guard test autonomously, or do you want heavy builds to stay human-triggered regardless of window?

*Session closed in WAITING FOR INSTRUCTIONS state.*
