# Task-Window Status — Monitoring Batch + Four Review-Finding Fix Tickets (2026-11-09 → 2026-11-10)

**Window:** five tq tasks completed 2026-11-09 ~06:30 → 2026-11-10 ~01:33: the five-item monitoring batch (`000001a1bdadc729…`) plus four reviewer-finding fix tickets (`…c0aecfeb`, `…0844cefd`, `…087d8a5c`, `…087e73f1`).
**Report written:** 2026-11-11 00:0x. **Scope rule:** this window only; drive-by observations flagged, not researched. **Method:** all four closeout reports read first; every load-bearing claim below re-verified against the tree, git history, the tq DB, and the deployed store paths. Nothing is taken from a report on faith.

---

## a) FULLY DONE

All five original batch items landed AND survived verification at HEAD:

1. **/nix usage monitoring (batch item 1)** — gap confirmed then closed: the metric pre-existed (`storage_collector_fs_used_percent{mount_point="/nix"}`, live 83%); the missing threshold check landed as **"Nix Store Usage"** (`modules/nixos/services/gatus-config.nix:980` — verified in tree), README stamp 283→284 (README.md:82 provenance chain verified). Footer commits `e5f0cd56a` (items 1+2 paired, see §d) + `ef5bd5a0c` (mirror rows).
2. **Chronic-red escalation (batch item 2)** — `system_gatus_chronic_red_checks` gauge (system-health.nix) + **"Gatus Chronic Red"** check (system-health.nix:3012 — verified in tree), README 284→285. SQL fixture-tested 3/3; gatus sqlite schema verified against the deployed 5.38.0 binary's embedded CREATE TABLE. The audit leg's retro-window (09-16..10-01) is journald-vacuumed — retro-delivery honestly reported unanswerable, not faked.
3. **time_series_v2 investigation (batch item 3)** — RESOLVED live against ClickHouse: v2 has 0 rows and no MV targets it; it is a dead-legacy table, not a retention victim; v4 (15.5M rows) carries full fresh labels. Recorded permanently in `docs/agents/monitoring.md:48` ("Never investigate v2 again") via `a8238f5d1` — verified.
4. **hwmon fingerprint table (batch item 4)** — refreshed by `34bde0aec` (verified: 25-line diff, v4 `JSONExtractString` label query as primary identification, Samsung=nvme0 post-flip enumeration).
5. **Catch-All 404 check (batch item 5)** — verified green-with-caveat by `05f523a43`: surfaces ✓, propagates ✓, live TLS green ✓; "no alert noise" honestly FAILED (8+ flap episodes, PapDashboard ingest refused through the window) — the caveat is recorded, not smoothed over. Queue row ticked [x] (monitoring.md:89).

All four fix tickets delivered their findings' letter:

6. **Provenance marker for the previous batch's item-4** (fix ticket `…c0aecfeb`, LOW→medium finding): `badaf3c79` landed 11-09 18:16 — narrates the footless carrier d1dcf96dc, the allowlist contents, and the llama-embeddings real stranding; footer verified as final line. This restored the queue↔git cross-reference for code that had shipped invisible to the footer contract.
7. **hwmon-row ticks** (fix ticket `…0844cefd`, HIGH finding): both rows ticked at HEAD — TODO_LIST.md:371 and docs/todo/monitoring.md:84 verified `[x]` with DONE close-outs citing 34bde0aec; the tick's Provenance note names both the footless carrier (35b69d475 — verified: touches exactly TODO_LIST.md, 1 line) and the footer marker (1815374e1).
8. **Value-less-line guard** (fix ticket `…087d8a5c`, medium finding): the chronic-red HELP/TYPE/value triple is now behind `if [ -n "$GATUS_CHRONIC_RED" ]` (system-health.nix:1589 — verified; rendered form at store line 4371). **LIVE since gen-997 (2026-11-10 19:12):** I resolved the deployed unit's ExecStart to `/nix/store/xh7qa5i0…-system-health-metrics/bin/system-health-metrics` and grep-verified the guard inside the running system's closure — the fail-dark backdoor this finding closed (one sqlite hiccup → value-less line → node_exporter rejects the whole textfile → all ~38 `system_*` metrics dark) is closed in production, not just in tree.
9. **Queue surfaces minted and mirrored:** 8 follow-up rows into docs/todo/monitoring.md (`ef5bd5a0c`, verified), A1–A4 class-defense rows (TODO_LIST:3416–3419 — verified), post-deploy verify row (TODO_LIST:374) annotated in place with the guard-fix UPDATE, and the tick-race discipline codified into AGENTS.md's TODO System section ("Tick-and-commit queue-file edits in ONE tool call" — verified present).

## b) PARTIALLY DONE

1. **Fix ticket `…087e73f1` (LOW finding: items 1+2 shared one commit) is queue-closed but landed NOTHING.** No closeout report, no footer commit, zero repo trace. Its recorded disposition — "fix ticket cured (SHA e5f0cd56 unreferenced and anchor text absent at HEAD)" — is **factually wrong on both counts**: `git merge-base --is-ancestor e5f0cd56a HEAD` → ancestor, and the anchor text IS that commit's subject, present in `git log`. The run almost certainly grepped the working TREE for a commit-subject anchor, which cannot match by construction. Mitigation: the finding demanded only awareness ("no rework needed beyond awareness — do not rewrite history"), and the batch close-out header already records the pairing ("Footer commits (authoritative): e5f0cd56a (items 1+2)"). So the OUTCOME is benign; the RECORDED REASON is false, and the close contract (report + footer) was skipped. Queued for repair (TODO_LIST rows from this report).
2. **Post-deploy verify leg (TODO_LIST:374) is unblocked but unrun.** Gen-997 already carries the entire batch (verified: gen-997's closure contains the same guarded `system-health-metrics` store path AND the new checks' config). The row's premise "once the next evo-x2 deploy carries them" has been satisfied since 19:12 last night; nothing has run the leg.
3. **Fixture legs absent:** no mutation-test legs for the two new gatus patterns in `tests/test-gatus-patterns.nix`, and the chronic-red SQL fixture still lives in ephemeral `~/.cache` — both queued, neither built.

## c) NOT STARTED (verified open; queued by the window's own closeouts, not re-queued here)

1. Value-less-emission class gate — static rendered-script scan + empty-value fixture (TODO_LIST:3416, A1).
2. SigNoz absence retro: did `system_gatus_chronic_red_checks` vanish from samples pre-guard (A2, TODO_LIST:3417) — bounds whether the fail-dark path ever fired in prod.
3. `system_gatus_meta_scrape_errors` consumer audit (A3) — nothing verified to alert on the collector's in-band failure flag.
4. Chronic-red blip watch (A4, TODO_LIST:3419) — observation window, cannot start before this report.
5. Flap-absorption fleet pass for cert-checking endpoints; owner Discord-receipt glance `[blocked:user]`; `time_series_v2` drop decision `[decision]`; distinct chronic-red channel `[decision]` — all pre-queued, untouched.
6. Footer-vs-tick cross-check audit over recently-ticked rows (docs/todo/pipeline.md:1090) —minted by the 00-42 closeout, not yet run.

## d) TOTALLY FUCKED UP

1. **One batch item cost FOUR dispatches and still isn't fully closed.** Item 4 (hwmon table) was implemented (34bde0aec), then needed a provenance repair (its code rode footless daemon d1dcf96dc — fix ticket `…c0aecfeb`), then a tick repair (fix ticket `…0844cefd`), and the window's fifth task (`…087e73f1`) closed on a false premise without landing anything (§b.1). Root cause every time: close-out hygiene (per-item footer + tick audit) skipped at authoring time. The discipline now exists in AGENTS.md; the pattern to fear is that it took three paid repairs to codify two sentences.
2. **A queue record now contains a false verification claim.** `…087e73f1`'s result field asserts anchor-absence that git disproves. Nothing consumes that field mechanically today, but the queue's "completed" verdict rests on it — the exact "assert WHICH question your evidence answers" failure (2026-09-18 rule) in miniature.
3. **Daemon races foreclosed repairs permanently (verified lineage):** the hwmon tick rode footless `35b69d475` (00:30); the foreign CV wave `4395859d9` (00:33 — flake.lock + expected-locks + cv.nix, verified) landed between it and the footer commit, so amend-forward died and the provenance split is permanent absent an owner-approved history rewrite. Worse, the 01-20 chronic-red closeout report ITSELF rode footless `915d75937` (01:25 — verified: 4 files, mixed ownership incl. a foreign SUPERB report + cv.yaml + configuration.nix), requiring the re-attribution commit `d283996ef`. The system survived on its repair protocols, but every repair was needed.
4. **Drive-by flag (NOT this window, NOT judged broken):** a parallel session's deploy (`nh os switch`, PID alive at report time, started 23:34) was mid-activation while this report was written — `/run/current-system` points at the new toplevel while the newest profile link (system-997) still holds the 19:12 target. Per the anchor discipline this is the EXPECTED mid-flight shape (the profile `nix-env --set` lands late); the next reader must re-check anchoring after the deploy tree goes quiet, not treat this snapshot as the UNANCHORED class.

## e) WHAT WE SHOULD IMPROVE

1. **Close-out hygiene must be a per-item session-exit step, not a reviewer discovery:** grep the footer per item + grep the `[ ]` for the item's rows, every batch, before ending. This window's entire cost structure is that step not existing at authoring time.
2. **"Anchor absent" verdicts must include git-log evidence.** A working-tree grep cannot see commit-message anchors; the fix-ticket preflight needs `git log --format=%B --all` in its absence test (queued; the test itself lives in go-taskqueue — see §g.3).
3. **When a finding says "awareness only", the sanctioned close is cheap and concrete:** a footer-carrying note commit. Skipping the close contract to "save" that commit is what produced the false-premise record — the cure costs less than the disease.
4. **Fixture-first for new gatus patterns** — `gatus validate` checks syntax, not semantics; the polarity bug the batch self-caught (§d of its own report) is exactly what a mutation-test leg kills at authoring time.
5. **The value-less-line class needs its mechanical gate (A1)** — third instance of the class (2026-09-02 ×2, now chronic-red). Per-instance vigilance has a proven miss rate; a flake-check leg over the rendered script makes the class unrepresentable.
6. **Deploy-pending items should mint their post-deploy verify leg at landing time** — row 374 existed but sat unrun for 34h after its premise silently became true. A harvest pass that checks "is this row's blocker gone?" would have fired it at 19:12.

## f) UP TO 50 NEXT THINGS (deduped; the top items are already queued — listed for the priority picture)

Already queued (verified present; do NOT re-dispatch):
1. Post-deploy verify leg for both new checks + the guard (TODO_LIST:374) — **now unblocked**, gen-997 carries everything.
2. Value-less-emission class gate (A1, TODO_LIST:3416).
3. SigNoz absence retro (A2, TODO_LIST:3417).
4. `system_gatus_meta_scrape_errors` consumer audit (A3, TODO_LIST:3418).
5. Chronic-red blip watch (A4, TODO_LIST:3419).
6. Fixture legs for the two new gatus patterns + chronic-red SQL → flake-checked test (monitoring.md mirrors).
7. Footer-vs-tick cross-check audit (pipeline.md:1090).
8. Flap-absorption fleet pass; owner Discord-receipt glance; time_series_v2 drop decision; distinct chronic-red channel — monitoring.md queue.
9. Blind-window bound + 93%-root-alert metric source (monitoring.md:79).

New from THIS pass (all queued to TODO_LIST except where noted):
10. Record the pairing-awareness disposition `…087e73f1` claimed but never landed — one footer commit, no history rewrite (TODO_LIST, appended by this report).
11. Preflight anchor-absence test must grep commit messages, not just the tree (TODO_LIST, appended by this report).
12. Owner ruling: authorize (or permanently decline) the rebase-squash of the provenance-split pair (35b69d475 → 1815374e1) once the CV wave is pushed — see §g.1.
13. Owner ruling: absence-trip blip tolerance (§g.2) — deliberately NOT re-queued; embedded in row 3419's escalation clause.
14. Owner authorization for the go-taskqueue preflight change (§g.3) — see the blocked TODO row.
15. When the post-deploy verify leg runs: also confirm the first chronic-count emission against the real gatus.db (the TIMESTAMP-format assumption is fixture-tested but never run live — phantom-zero risk with scrape_errors 0).
16. After the in-flight 23:34 deploy anchors: run the §17 memory sweep + confirm no new watermark throttles (drive-by from this report's §d.4, rides the existing post-deploy battery).
17. Retro-fit `**Provenance:**` markers on other footless-carrier rows as the pipeline.md:1090 audit finds them (folded into that row's scope).

(17 substantive items; the rest of the monitoring backlog is already rows — minting reworded duplicates is the failure mode the cap exists to prevent.)

## g) QUESTIONS FOR THE OWNER

1. **History repair ruling:** the hwmon tick rides footless daemon commit `35b69d475`, and the foreign CV wave `4395859d9` sits between it and footer commit `1815374e1`, permanently blocking amend-forward. Authorize a one-time rebase-squash of `35b69d475` into `1815374e1` once the CV wave is pushed, or leave the split permanently (current default: leave as-is; documented by the row's Provenance note)?
2. **Absence-trip tolerance:** "Gatus Chronic Red" flips red on a SINGLE missing sample — one transient sqlite hiccup pages a 15-min alert episode post-deploy. Accept the blips (strict fail-closed, current doctrine), or authorize an N-consecutive-failure tolerance for absence-tripped checks specifically? (Embedded in TODO_LIST:3419; asked here because the guard fix is now LIVE, so the first real blip — if any — lands this week.)
3. **Queue-tooling authorization:** the fix-ticket preflight's anchor-absence test lives in go-taskqueue (the pool binary), not this repo. Authorize the upstream change there (grep commit messages before declaring a finding cured), or should the repo only carry the awareness row and tolerate the false-premise closes?

## h) BAND DRIFT

**None recorded.** The queue journal (73,052 fact lines all-time) contains **zero `task.reprioritized` facts** — in this window or ever (`tq facts --type task.reprioritized` → 0 facts; the three grep hits for the string are earlier status-report agents' transcript text riding `task.requeued` payloads from 2026-10-11/15, not facts). Window journal volume for context: 122 claimed / 79 requeued / 37 completed / 4 failed / 2 cancelled / 1 question across all repos; the requeue bulk is zai rate-limiting (the documented saturation pattern), which is availability pressure, not priority drift. No ADR-0015 accountability entries are owed for this window.

---

## Docs-health pass outcomes (this report's own hygiene duties)

- **Closeout reports (docs/status/tasks/):** all four read in full and left unannotated — they are complete point-in-time records whose open follow-ups are live queue rows (verified above); nothing to strike.
- **README.md:** fresh — the endpoint-stamp chain at line 82 already carries the batch's 283→284→285 (with task IDs) and the later 285→286 wave; no edit.
- **FEATURES.md:** gate-maintained (doc-counts); the batch added no module, so no row changes; counts in the header match the eval-derived stamps. No edit.
- **AGENTS.md:** the tick-race codification (2026-11-10) is present in the TODO System section. No edit.
- **ROADMAP.md:** nothing from this window routes to long-term ideas. No edit.
- **CHANGELOG.md:** the batch + fixes had NO entry (flagged by two of the window's own closeouts) — entry appended by this pass.
- **Archives:** none moved. No 2026-* report in scope is fully resolved-and-unreferenced: every candidate carries open queue rows (that IS their routing), and a mass archive sweep without per-item verification is the 2026-11-04 blind-spot class. The four window closeouts stay until their A1–A4/verify rows resolve.
- **Live-deploy caveat:** §d.4's mid-activation snapshot means "deployed/live" claims above are anchored to gen-997's store paths (verified), not to whatever the in-flight switch lands.
