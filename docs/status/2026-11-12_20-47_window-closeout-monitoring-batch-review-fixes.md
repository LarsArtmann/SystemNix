# Window Close-Out (Fourth Fire) — Monitoring Batch + Four Review-Finding Fixes

**Done-prompt:** `000001a1c2e674da8a550bf5f53000000000` — **this is the THIRD re-fire (4th fire)**; first close landed 2026-11-11 06:14, verified no-op 06:26, re-claimed again 2026-11-12 20:47.
**Window under report:** five tq tasks completed 2026-11-09 ~06:30 → 2026-11-10 01:40 — the five-item monitoring batch (`000001a1bdadc7298c1342c6536a00000000`) plus reviewer-finding fix tickets `…c0aecfeb`, `…087e73f1`, `…0844cefd`, `…087d8a5c`.
**Predecessor reports (read first, per contract):** the four task closeouts under `docs/status/tasks/2026-11-09_08-38` / `2026-11-09_18-19` / `2026-11-10_00-42` / `2026-11-10_01-20`, plus the prior fires of this done-prompt: `docs/status/2026-11-11_00-01_task-window-status-monitoring-batch-closeouts.md`, `docs/status/2026-11-11_06-14_monitoring-window-five-task-closeout-recheck.md`, `docs/status/2026-11-11_06-26_monitoring-window-closeout-refire-verification.md`. This fire re-verifies their picture at HEAD (2026-11-12 ~21:00, post gen-1003 + today's deploy arc) and records deltas only.
**This fire's verification passes:** every window footer commit reachability-checked (`git merge-base --is-ancestor <c> master`, all nine REACHABLE); both new gatus checks + the value-less guard grep-verified in the tree; the production tq journal queried via the pool process's live store (see §h); TODO_LIST/library rows re-checked for tick state and dedup.

## a) FULLY DONE

Held at HEAD — nothing regressed since the 06-14 close:

1. **Batch item 1 — "Nix Store Usage" gatus check:** present at `modules/nixos/services/gatus-config.nix:1022`; footers `e5f0cd56a` (items 1+2 paired) + mirror rows `ef5bd5a0c`, both ancestors of master.
2. **Batch item 2 — chronic-red escalation:** `system_gatus_chronic_red_checks` gauge (collector SQL at `system-health.nix:629`) + "Gatus Chronic Red" check (`system-health.nix:3032`); SQL fixture-tested 3/3 against the deployed gatus 5.38.0 schema (per closeout; unchanged).
3. **Batch item 3 — time_series_v2 dead-legacy verdict:** recorded in docs/agents/monitoring.md; `deadMetrics` blocklist enforcement landed (`0bb953d24`, ticked row 380); DROP still parked on the owner ruling (§g.1 — its tq question expired today).
4. **Batch item 4 — hwmon fingerprint table refresh** (`34bde0aec`) with both queue rows ticked + provenance note (fix ticket `…0844cefd`, footer `1815374e1`).
5. **Batch item 5 — Catch-All 404 verification** (`05f523a43`): green-with-caveat verdict preserved; flap-absorption follow-up queued (row 373).
6. **Fix ticket `…c0aecfeb`** (`badaf3c79`): footer-carrying provenance marker for the detection-net code that had ridden footless `d1dcf96dc`.
7. **Fix ticket `…087d8a5c`** (`87b2132dc`): the chronic-red emission triple behind `if [ -n "$GATUS_CHRONIC_RED" ]` — verified at `system-health.nix:1609` this fire. LIVE since gen-997 (2026-11-10 19:12, deployed-guard grep by the 06-14 fire); the checks and guard are in-tree at HEAD, so every later generation (998…1003 + today's arc) carries them.
8. **Queue surfaces complete and drift-free:** batch rows 368–372 all ticked; follow-up rows present and mirrored (373–381, 3429–3432 watch/decision block, 3466–3481 disposition/decision block).
9. **Living docs current:** CHANGELOG carries the batch entry (added `fcbb0e1c1`); AGENTS.md carries the tick-race discipline; README's line-82 provenance chain is eval-anchored and current. **One drift found and fixed this fire:** README's line-18 overview table still said "52 alert rules / 286 health checks" against the eval-anchored 61 rules / 298 checks (endpoints re-derived live at HEAD this fire via the README-quoted eval — `cannot coerce an integer to a string: 298`); the table now matches. No stale window claims remain in README/FEATURES/ROADMAP.

## b) PARTIALLY DONE

1. **Post-deploy verify leg (row 374) is STILL unrun — now ~66 h after gen-997 dissolved its premise.** The 06-14 fire reported it 35 h overdue; the debt has grown 31 h since. Nobody has probed live gatus for: "Nix Store Usage" green at ~83%, "Gatus Chronic Red" green with the count line emitted, first-run chronic SQL against the real gatus.db (phantom-zero risk with scrape_errors 0).
2. **Fix ticket `…087e73f1` remains a queue-close with zero durable artifacts:** no closeout report, no footer commit, no awareness note anywhere. Its disposition rows (3466 pairing note, 3467 in-repo anchor-check fix, 3469 go-taskqueue [decision]) are queued, not executed.
3. **Fixture legs absent:** mutation legs for the two new patterns (row 375) and the chronic-red SQL promotion (row 376) — both still open; A2/A3 unrun; A4 blip watch mid-flight (watch window ends ~2026-11-17) with no observation recorded in the row yet.
4. **Attribution split permanent absent owner ruling:** the hwmon tick rides footless `35b69d475`; footer `1815374e1` is the marker; rebase-squash parked on §g.3.
5. **New this fire:** the three appended TODO rows (§f) carry no library mirrors in `docs/todo/{monitoring,services}.md` — this fire's hard scope excluded docs/todo edits; the mirror debt rides the rows' next touch.

## c) NOT STARTED

All pre-queued by the window's own closeouts and the prior fires; verified still open at HEAD; **deliberately not re-queued (dedup held)**:

- A1 value-less-emission class gate (row 3429) — including the known `textfile-emission-lint` regex blind spot to interpolated-var shapes (06-14 §c.1); A2 absence retro (3430); A3 meta-errors consumer audit (3431).
- Flap-absorption fleet pass (373); pattern fixture legs (375); chronic-red SQL promotion (376).
- Owner-gated/decision rows: Discord-receipt glance, time_series_v2 DROP (379, ruling expired today), GC WARN tier (3479), chronic-red channel, absence-trip tolerance (3481), provenance-split rebase, go-taskqueue preflight change (3469).
- Pipeline machinery: done-prompt re-fire guard (1438), verdict durability/discard-ordering (1734), lease renewal (1747), budget carve-out (1445).

## d) TOTALLY FUCKED UP

1. **This fire itself is the finding: the 06-26 fire recorded its verdict via `tq verdict --file` and the queue re-claimed the task anyway** (claimed 2026-11-12 20:47:45, attempts 1/3). That is the second confirmed "verdict recorded, re-fired regardless" instance (the 2026-10-30 8th-fire forensics documented the first). One window closeout has now cost four paid fires. The claim-time re-fire guard (row 1438) and the verdict-consumption audit (complements rows 1734/1747, pool-side fix lives in go-taskqueue) remain unlanded.
2. **The `…087e73f1` false-premise preflight close (carried, still unrepaired):** its "cured: SHA unreferenced and anchor text absent at HEAD" record is factually wrong on both legs — this fire re-verified `e5f0cd56a` IS an ancestor of master, and the anchor text IS that commit's subject in `git log`. A working-tree grep cannot see commit-message anchors; the preflight cured a real finding on bogus evidence. Fix rows queued (3467/3469), not executed.
3. **"Dangling commit" terminology debt in two closeout reports:** the `…0844cefd` closeout and the window header describe `ef5bd5a0cf` as "rejected dangling"; `git cat-file -e` proves object existence, not unreferenced-ness — this fire's `merge-base --is-ancestor` check shows ALL nine window commits reachable from master, including both commits those reports called dangling. No content impact (the work is all in history), but future forensics quoting that wording would mis-derive reachability.
4. **The daemon race hit this fire too:** the skeleton report rode footless daemon commit `3d775264a` (~20:49 sweep) before the footer commit `82646653f` landed at 21:01 — despite the single edit→commit motion the tick-race discipline mandates (the window is the ~20 s hook runtime + sweep timing, not agent round trips). Repair per the house remedy (`d283996ef` precedent): the fill-in rides this footer-bearing commit, restoring the file's queue attribution. No foreign content absorbed (daemon commit stat = exactly the one file, verified before proceeding).
5. **Carried from the window** (06-14 §d, unchanged): the hwmon item's four-dispatch cost for adjacent hygiene gaps; two daemon races permanently foreclosing amend repairs; the `textfile-emission-lint` gate shipped with a regex blind spot to the very class it targets.
6. **In-passing, not this window's damage:** `/run/current-system` flipped to an f4a03c0-based toplevel at 20:47 today — mid-session with this fire and with profiles 1001–1003 (2026-11-11) pointing at f9a75f4 builds. That is an active parallel deploy arc (today's 12-05/14-11/18-26 reports; HEAD commit `0b7ac0e46` names the f4a03c00 packaging issue). Anchor-state adjudication belongs to that session's own close-out per the deploy-vs-executor rule; this fire touched only docs and claims nothing about the outcome.

## e) WHAT WE SHOULD IMPROVE

1. **Land the claim-time re-fire guard (row 1438) — this is its third confirmed instance.** A done-prompt whose window IDs all carry footer commits + an existing same-window closeout should self-serve no-op at claim. The 06-26 report asked for exactly this; it is still open.
2. **Audit the verdict-consumption path pool-side:** a recorded verdict that does not suppress re-claim is functionally equivalent to no verdict. The repo rows the discard-ordering suspect (1734: verdict parsed only after `runVerify` passes); the 06-25 verify-gate failure in THIS task's own fact trail (`flake-input-pin-audit-selftest`, judged pre-existing/environmental) fits that ordering exactly — the verdict from a fire whose verify gate dies on an environmental failure may be discarded with the lease. Confirm in go-taskqueue, then fix or document.
3. **Fix "anchor absent" verdicts to grep `git log --format=%B --all`** (row 3467; upstream half rowed as 3469) — the only false-premise close in the window's history keeps waiting.
4. **Mint post-deploy verify legs with a due date, and let a harvest pass check "is this row's blocker gone?"** (06-14 §e.6, still true at 66 h): row 374 is the cheapest high-value probe in the queue and has been executable for nearly three days.
5. **Keep reachability claims honest in reports:** cite `git merge-base --is-ancestor`, never present `git cat-file -e` as "dangling" evidence (§d.3).
6. **Docs-commit daemon-race flow:** expect the first sweep to take a docs file (three of four fires lost their report to it); the fill-in-amend flow worked, keep it as the default rather than fighting the race.

## f) NEXT THINGS (up to 50 — the priority picture; dedup-checked against 3,260 open rows)

**Already queued, highest value first (do NOT re-dispatch — row numbers verified this fire):**
1. Run row 374's post-deploy verify leg — 66 h overdue, cheapest probe in the queue; tick it and ride the pattern-fixture rows (375/376) in the same session.
2. A1 value-less-emission class gate (3429) as a textfile-emission-lint extension + rendered fixture (06-14 §e.3: one change, not two gates).
3. A2 SigNoz absence retro (3430) — one ClickHouse query bounds whether the fail-dark path ever fired pre-guard.
4. A3 `system_gatus_meta_scrape_errors` consumer audit (3431) + the absence-vs-chronic alert-text split.
5. Flap-absorption fleet pass (373).
6. Pairing-awareness disposition note for `…087e73f1` (3466) + the anchor-check fix (3467).
7. Footer-vs-tick cross-check audit over recently-ticked rows (minted by the 00-42 closeout, still unrun).
8. A4 blip-watch observation: record the first post-gen-997 week's blip count into row 3432 (window closes ~11-17).
9. Owner [decision] block execution when rulings land: v2 DROP (379) + residual-reference sweep in the same session; GC WARN tier (3479); chronic-red channel; absence-trip tolerance (3481); provenance-split rebase; go-taskqueue preflight (3469).
10. Pipeline machinery: re-fire guard (1438), verdict durability (1734), lease renewal (1747), budget carve-out (1445).

**New this fire (appended to TODO_LIST as three rows):**
11. Gatus unit-log retention floor for alert-delivery auditability (from the 08-38 closeout §f.13 — never harvested by any prior fire; re-verified unqueued).
12. Three eval-warning hygiene fixes: `services.pipewire.jack.enable` deprecation, `borg-offsite-golive-check` missing `meta.mainProgram`, caddy dns-local ghost subdomains (`nsfw`, `llama`) (from §f.14, re-observed by 06-14 §f.10, never queued).
13. Pin WHICH SigNoz version/migration abandoned `time_series_v2` with a lock-rev citation (from §f.10, never queued; the dead-legacy verdict currently asserts its mechanism unreproducibly).

**In-passing observations owed elsewhere (not window work; no rows minted — existing rows own them):** the AGENTS.md size-budget question asked today 20:54 (ref `d898b111`, 27,125 B vs the 24,700 budget — terminal-policy ruling pending); the parallel deploy arc's anchor-state verification (§d.6); the expired v2 ruling re-ask (§g.1).

## g) OWNER QUESTIONS

(All already live as rows ending in BLOCKED — restated for visibility, not duplicated:)

1. **time_series_v2 DROP ruling — EXPIRED TODAY unanswered.** tq question `55a39b9a` (asked 2026-11-09 15:58, expiry 2026-11-12): drop `signoz_metrics.time_series_v2` + `distributed_time_series_v2` (0 rows, zero writers, live-probed) or keep as schema history? Row 379 stays blocked; the blocklist enforcement half already landed. Re-ask or decide.
2. **Three monitoring [decision] rows from this window:** GC WARN tier before the /nix 90 % page (3479); chronic-red routing to a quieter "patterns, not pages" channel; absence-trip tolerance for absence-tripped checks — accept single-sample fail-closed blips or authorize N-consecutive tolerance (3481; feeds A4's watch).
3. **Provenance-split history repair:** authorize the one-time rebase-squash of footless `35b69d475` into `1815374e1` once the CV wave is pushed, or leave the split permanently documented (current default: leave as-is)?

## h) BAND DRIFT

**None recorded.** This fire queried the production journal directly — the pool binary's live store at `/mnt/pool/services/tq/tq.db` (resolved from the running `tq agent-pool` process environment, PID 3729016, rather than guessed): the `facts` table schema has NO `task.reprioritized` type at all (types present: claimed, requeued, failed, enqueued, completed, dead-lettered, released, cancelled, question-asked, cancel-requested), zero rows of any priority-change class exist for the window (2026-11-09 00:00 → 11-10 06:00) or anywhere in the journal's 19k+ facts, and the `priority_scores` table is empty. No priority moved; nothing to explain after the fact — consistent with every prior fire's verdict. (Prior fires queried `~/projects/tasks.db`, an empty side DB; this fire's evidence is from the live store, the strongest confirmation yet.)

Window journal context: 36 tasks enqueued + completed, 106 claims, 66 requeues, 4 failures (all `context deadline exceeded` on other tasks), 1 question asked, **zero dead letters**.

---

**Provenance.** Skeleton + first-cut rows committed as `82646653f` (footer-bearing); the daemon swept the skeleton file into footless `3d775264a` before the footer commit landed (§d.4) — this fill-in rides the amended footer-bearing HEAD, restoring attribution per the `d283996ef` remedy. TODO_LIST appends this fire: 3 new rows (§f.11–13), zero ticks (nothing new proved done — the window's own ticks were all verified in place), zero reworded/deleted items. Prior-instance commits of this done-prompt: `61dded91d` (first-fire skeleton), `fcbb0e1c1` (first-fire amended close), plus the 06-26 fire's footer commit.

Task-Queue-ID: 000001a1c2e674da8a550bf5f53000000000
