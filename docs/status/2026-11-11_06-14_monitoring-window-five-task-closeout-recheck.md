# Task-Window Status — Monitoring Batch + Four Review-Finding Fix Tickets, Re-Verified (2026-11-11 06:14)

**Window:** five tq tasks completed 2026-11-09 ~06:30 → 2026-11-10 ~01:33: the five-item monitoring batch (`000001a1bdadc7298c1342c6536a00000000`) plus reviewer-finding fix tickets (`…c0aecfeb`, `…087e73f1`, `…0844cefd`, `…087d8a5c`).
**Relationship to the 00-01 report:** `docs/status/2026-11-11_00-01_task-window-status-monitoring-batch-closeouts.md` already covered this same window in depth at 00:01. This report re-verifies that picture against HEAD (06:14, post gen-998), records the deltas since 00:01, and routes the residue. The four available closeout reports were read first; every load-bearing claim below was re-verified against the tree and git history.

---

## a) FULLY DONE

All five original batch items landed AND are verified present at HEAD:

1. **/nix usage monitoring (batch item 1)** — gap confirmed then closed: the metric pre-existed (`storage_collector_fs_used_percent{mount_point="/nix"}`, live 83%); the missing threshold check landed as **"Nix Store Usage"** — verified in tree at `modules/nixos/services/gatus-config.nix:980`. Footer commits `e5f0cd56a` (items 1+2 paired — the pairing is the subject of fix ticket `…087e73f1`, see (d).1) + mirror rows `ef5bd5a0c`.
2. **Chronic-red escalation (batch item 2)** — `system_gatus_chronic_red_checks` gauge + **"Gatus Chronic Red"** check (system-health.nix; SQL at :629 verified). SQL fixture-tested 3/3 against the deployed gatus 5.38.0 sqlite schema. Retro-delivery of the vacuumed 09-16..10-01 journal window honestly reported unanswerable, not faked.
3. **time_series_v2 investigation (batch item 3)** — RESOLVED live against ClickHouse: v2 = 0 rows, no MV targets it; `time_series_v4` (15.5M rows) carries full fresh labels. Recorded permanently in docs/agents/monitoring.md (`a8238f5d1`), deadMetrics blocklist entry landed (`0bb953d24`), DROP decision parked as a [decision] queue row (`a0cef4fcb`).
4. **hwmon fingerprint table (batch item 4)** — refreshed by `34bde0aec` (25-line diff, v4 `JSONExtractString` label query as primary identification, Samsung=nvme0 post-2026-10-22-flip enumeration). Both queue rows ticked [x] with DONE close-outs (the subject of fix ticket `…0844cefd`).
5. **Catch-All 404 check (batch item 5)** — verified green-with-caveat by `05f523a43`: surfaces ✓, propagates ✓, live TLS green ✓; "no alert noise" honestly FAILED (8+ flap episodes 11-06/07, PapDashboard ingest refused through the window) — caveat recorded, not smoothed. Flap-absorption fleet pass queued.
6. **Provenance marker for the prior batch's item-4** (fix ticket `…c0aecfeb`, commit `badaf3c79`): narrates the footless carrier d1dcf96dc and the detection-net code surfaces; footer verified as final line. The queue↔git cross-reference for code that had shipped invisible to the footer contract is restored.
7. **hwmon-row ticks** (fix ticket `…0844cefd`, footer `1815374e1`): both rows ticked at HEAD; the tick's Provenance note names both the footless carrier (35b69d475) and the footer marker.
8. **Value-less-line guard** (fix ticket `…087d8a5c`, footer commit `87b2132dc`): the chronic-red HELP/TYPE/value triple is behind `if [ -n "$GATUS_CHRONIC_RED" ]` — verified at system-health.nix:1589–1592. **LIVE since gen-997 (2026-11-10 19:12):** the 00-01 session grep-verified the guard inside the deployed unit's store path — the fail-dark backdoor (one sqlite hiccup → value-less line → whole textfile rejected → all ~38 `system_*` metrics dark) is closed in production, not just in tree.
9. **Queue surfaces minted and mirrored:** 8 follow-up rows into docs/todo/monitoring.md (`ef5bd5a0c`), A1–A4 class-defense rows in TODO_LIST, the post-deploy verify row annotated in place with the guard-fix update, and the tick-race discipline codified into AGENTS.md TODO System section (verified present at AGENTS.md:76).
10. **Deltas since the 00-01 report (landed by other sessions, counted as window residue closed):** gatus endpoint-count claims reconciled to eval truth 286 (`64c124592`); the time_series_v2 library row closed with the dead-legacy verdict (`377a242f7` + closeout `81fc264dd`); count-drift fix closeout + 3-row harvest, tick 1619 (`4bdffca59`). CHANGELOG now carries the batch entry (added by this report; none existed before).

## b) PARTIALLY DONE

1. **Fix ticket `…087e73f1` (LOW finding: items 1+2 shared one commit) is queue-closed but landed NOTHING** — see (d).1. The disposition repair rows are queued (TODO_LIST pairing-awareness row + the two anchor-check rows), not executed.
2. **Post-deploy verify leg (TODO_LIST row ~374) is unblocked but still unrun at 06:14.** Gen-997 (and now gen-998) carry the entire batch + guard; the row's premise has been satisfied for ~35h. Nobody has probed the live gatus for "Nix Store Usage" green at ~83% / "Gatus Chronic Red" green with the count line emitted / first-run chronic SQL behavior against the real gatus.db.
3. **Fixture legs absent:** no mutation-test legs for the two new gatus patterns in tests/test-gatus-patterns.nix; the chronic-red SQL fixture still lives in ephemeral ~/.cache. Both queued (monitoring.md rows), neither built.
4. **Attribution integrity:** the hwmon tick still rides footless daemon commit 35b69d475; the rebase-squash repair is parked on an owner ruling ([decision] row queued by the 00-42 closeout).
5. **A2/A3/A4 class-defense rows** (absence retro, meta-errors consumer audit, blip watch) — queued, untouched; A4's watch window technically started at gen-997 but no observation has been recorded.

## c) NOT STARTED

All pre-queued by the window's own closeouts and verified still open at HEAD (no re-queueing performed — dedup held):

1. Value-less-emission class gate (A1) — static rendered-script scan + empty-value fixture. NOTE: partially covered by the existing `textfile-emission-lint` flake check (flake/parts/checks/lint-static.nix:375), but that lint's regex only catches the LITERAL value-less shape (`echo "metric"` with no interpolation); the interpolated-var-with-empty-on-error-path shape the reviewer found is invisible to it. A1's scope should explicitly name the lint extension.
2. SigNoz absence retro (did the chronic gauge vanish from samples pre-guard) — bounds real-world impact; may be zero.
3. `system_gatus_meta_scrape_errors` consumer audit — nothing verified alerts on the collector's in-band failure flag.
4. Flap-absorption fleet pass for cert-checking gatus endpoints.
5. Fixture legs + chronic-red SQL promotion to a flake-checked test.
6. Owner glance at one live gatus→Discord trigger [blocked:user].
7. `time_series_v2` drop-or-keep [decision]; distinct chronic-red channel [decision]; GC WARN tier [decision]; absence-trip tolerance [decision] (the last three newly queued by this report).
8. Footer-vs-tick cross-check audit over recently-ticked rows (docs/todo/pipeline.md row) — minted by the 00-42 closeout, not yet run.
9. Rebase-squash of the provenance-split pair [decision, owner].

## d) TOTALLY FUCKED UP

1. **A queue record contains a false verification claim, and the finding was closed without landing anything.** Fix ticket `…087e73f1` recorded "cured: SHA unreferenced and anchor text absent at HEAD" — both factually wrong (`git merge-base --is-ancestor e5f0cd56a HEAD` → ancestor; the anchor IS that commit's subject, present in `git log`). The run grepped the working TREE for a commit-subject anchor, which cannot match by construction. Outcome benign (the finding asked awareness-only and the batch closeout header records the pairing), but the close contract (report + footer) was skipped entirely — no closeout report, no footer commit anywhere in git history for this task id. Mitigations: disposition rows queued at TODO_LIST (pairing-awareness note + the two anchor-check fixes, one [decision] because the durable fix lives in go-taskqueue).
2. **One batch item (hwmon table) cost FOUR dispatches** — implement (34bde0aec) → provenance repair (…c0aecfeb) → tick repair (…0844cefd) → the false-premise close (…087e73f1) adjacent to it. Root cause each time: close-out hygiene (per-item footer + tick audit) skipped at authoring time. The discipline now exists in AGENTS.md; it took three paid repairs to codify two sentences.
3. **Daemon races foreclosed repairs permanently:** the hwmon tick rode footless 35b69d475 with the foreign CV wave 4395859d9 landing between it and the footer commit (amend-forward dead); the 01-20 chronic-red closeout report itself rode footless 915d75937, needing re-attribution `d283996ef`. The system survived on its repair protocols; the provenance split is permanent absent owner-approved history rewrite.
4. **The reviewer-found value-less-line class is the THIRD surface of the same bug** (2026-09-02 incidents ×2, then the chronic-red gauge) — and the standing `textfile-emission-lint` gate shipped for exactly that class does not cover the interpolated-var shape, i.e. the class was declared handled by a gate with a regex blind spot. Per-instance vigilance has a proven miss rate; the gate has one too.
5. **Drive-by flag (not this window, not judged broken):** /run/current-system points at the gen-998-era toplevel and system-998-link is the newest profile link — anchor state looks converged at 06:14 (current-system = system-998 target family); no UNANCHORED signature observed. Noted only because multiple deploys ran overnight around this window's residue.

## e) WHAT WE SHOULD IMPROVE

1. **Close-out hygiene as a per-item session-exit step** (grep footer per item + grep `[ ]` for the item's rows) — the entire cost structure of this window is that step not existing at authoring time. Already codified in AGENTS.md; keep enforcing it in reviews.
2. **"Anchor absent" verdicts must include git-log evidence** — a working-tree grep cannot see commit-message anchors. In-repo row queued; the durable preflight fix lives in go-taskqueue [decision].
3. **Extend `textfile-emission-lint` to interpolated-var echo lines** — the existing gate catches only the literal shape; A1 should be executed as a lint extension + rendered-script fixture, not a parallel new gate.
4. **When a finding says "awareness only", the sanctioned close is a cheap footer-carrying note commit** — skipping the close contract to save one commit produced the false-premise record (§d.1).
5. **Fixture-first for new gatus patterns** — `gatus validate` checks syntax, not semantics; the polarity bug the batch self-caught pre-commit is exactly what a mutation-test leg kills at authoring time.
6. **Deploy-pending items should mint AND poll their post-deploy verify leg** — row 374 sat unrun for 35h after its blocker silently dissolved at gen-997. A harvest pass that checks "is this row's blocker gone?" would have fired it.
7. **Report-window overlap:** two window-closeout sessions (00:01 and this one) covered the same five tasks within 7 hours — the 00-01 report's §f already queued the window's follow-ups; this report's value is re-verification + the deltas, not re-queueing. If the queue hands the same window twice, the second runner should open with a grep of docs/status/ for a same-window report (the 2026-10-23 stale-report pre-read rule applied to done-prompts).

## f) UP TO 50 NEXT THINGS

The top items are ALREADY QUEUED (verified present; listed for the priority picture — do NOT re-dispatch): post-deploy verify leg (row 374, now 35h overdue); A1 class gate (extend textfile-emission-lint + rendered fixture); A2 absence retro; A3 meta-errors consumer audit; A4 blip watch; fixture legs for the two new patterns; chronic-red SQL promotion to flake check; flap-absorption fleet pass; footer-vs-tick cross-check audit; …087e73f1 disposition note + anchor-check fixes (2 rows + 1 [decision]); time_series_v2 drop [decision]; Discord-receipt glance [blocked:user]; provenance-split rebase ruling [decision].

New from THIS report (the three [decision] rows are already appended to TODO_LIST):
1. Run row 374's verify leg NOW — the premise (gen-997 carries everything) has been true for ~35h; this is the cheapest high-value probe in the queue.
2. Fold the textfile-emission-lint regex extension into A1's execution scope (see (e).3) — one change, not two gates.
3. Record the "window handed twice" dedup rule for done-prompt tasks in CONTRIBUTING.md (second runner greps docs/status/ first).
4. After row 374 runs green, tick it and ride the two pattern-fixture rows in the same session (mutation legs are the natural companion probes).
5. A4 blip-watch: record the first post-gen-997 week's blip count into the watch row itself (zero blips → close; recurring → the tolerance [decision] gains evidence).
6. A2 absence retro needs only a ClickHouse query — bound whether the fail-dark path EVER fired in prod before the guard; if zero, note it in the close-out and lower the urgency of the whole class.
7. When dropping v2 (if approved): also grep dashboards/rules/scripts for residual v2 references (the blocklist is enforcement, not cleanup) — the sweep row already exists; execute it in the same session as the DROP.
8. Pin WHICH SigNoz version/migration abandoned v2 with a lock-rev citation (the batch closeout asserted "v4 writer replaced v2 wholesale" without one).
9. Sweep README/FEATURES for any OTHER stale counts with the doc-counts eval truth (52 rules / 10 dashboards deltas already rowed; 286 endpoint stamp is now eval-anchored — extend that anchoring to remaining prose counts).
10. Three cheap eval-warning hygiene fixes seen in passing by the batch session: pipewire.jack deprecation, borg-offsite-golive-check missing meta.mainProgram, caddy dns-local ghost subdomains (nsfw, llama).

## g) QUESTIONS FOR THE OWNER

(all three appended to TODO_LIST as [decision] rows ending in BLOCKED:)
1. **GC WARN tier:** do you want an 85% observability-only WARN tier before the /nix 90% page threshold, or is one threshold right?
2. **Chronic-red routing:** same Discord channel as everything else (current), or a quieter "patterns, not pages" channel for the 15m chronic-red check?
3. **Absence-trip tolerance:** accept single-sample fail-closed blips on absence-tripped checks (default, doctrine-consistent), or authorize an N-consecutive-failure tolerance as a deliberate deviation?

## h) BAND DRIFT

**None recorded.** The production tq journal (`/home/lars/projects/tasks.db`, `facts` table, queried 2026-11-11 06:2x via sqlite3) holds ZERO rows of any type — no `task.reprioritized` facts exist for this window or ever, consistent with every prior window report's finding. No priority moved; nothing to explain after the fact.

---

**RE-FIRE ANNOTATION (2026-11-11 06:2x):** this report IS the completed close of done-prompt `000001a1c2e674da8a550bf5f53000000000` (skeleton `61dded91d`, amended here as `fcbb0e1c1`). The queue re-fired the task; the 2nd fire verified this close unchanged against HEAD and recorded the verdict — see `docs/status/2026-11-11_06-26_monitoring-window-closeout-refire-verification.md`.
