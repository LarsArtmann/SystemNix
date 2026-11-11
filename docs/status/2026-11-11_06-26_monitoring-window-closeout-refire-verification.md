# Window Close-Out — Monitoring Batch + Four Review-Finding Fix Tickets — RE-FIRE Verification (2026-11-11 06:26)

**Task:** `000001a1c2e674da8a550bf5f53000000000` (done-prompt for the five-task window 2026-11-09 ~06:30 → 2026-11-10 ~01:33).
**This is the 2ND fire of this done-prompt.** The first fire (earlier this morning) landed the complete close as two footer commits under THIS task id: the skeleton `61dded91d` and the fully-amended report at HEAD, `fcbb0e1c1` — `docs/status/2026-11-11_06-14_monitoring-window-five-task-closeout-recheck.md`. The queue re-claimed the task, the known class: a written-but-discarded verdict (lease expiry / verify-gate discard ordering, row TODO_LIST:1734) or a closeout-class budget park (row 1432). Per the 2026-10-15 re-fire precedent (row 1425) this fire verifies the prior close against HEAD rather than re-writing it.

## Pre-fire verification (what this run actually checked, live)

- `git log --grep 'Task-Queue-ID: 000001a1c2e674da8a550bf5f53000000000'` → exactly the two commits above; HEAD = `fcbb0e1c1` = the close itself; tree clean (`git status` empty).
- The 06-14 report is complete: all eight a–h sections present, every load-bearing claim carried its own verification pass (deployed guard grep in the gen-997 store path, ancestor check on `e5f0cd56a`, facts-table band-drift query).
- TODO_LIST carries the window's queue state: the four fix tickets' follow-ups (rows 374 post-deploy verify, 3416–3419 value-less-class gate / absence retro / meta-errors consumer audit / blip watch), the flap-absorption + fixture rows (monitoring section), and the three [decision]/blocked owner rows minted by the 06-14 report (GC WARN tier, chronic-red routing, absence-trip tolerance, line 3464 et al).
- CHANGELOG carries the batch entry (2026-11-09/10 monitoring-batch + guard-fix entry, added by `fcbb0e1c1`).
- `tq facts` → 0 rows; `tq facts --type task.reprioritized` → 0 rows (band drift, §h).
- Delta since `fcbb0e1c1`: **zero commits** — nothing landed between the first fire's close and this fire.

## a) FULLY DONE

The five window tasks, re-verified at HEAD (details + evidence in the 06-14 report §a, which this section summarizes by reference):

1. **Five-item monitoring batch** (`000001a1bdadc729…`, footers `e5f0cd56a`/`a8238f5d1`/`34bde0aec`/`05f523a43` + mirror `ef5bd5a0c`): /nix store usage check, chronic-red gauge + check, time_series_v2 dead-legacy verdict, hwmon table refresh, catch-all-404 green-with-caveat. Live since gen-997 (2026-11-10 19:12).
2. **Provenance marker fix** (`…c0aecfeb`, `badaf3c79`): footer-carrying marker for the detection-net code that had ridden footless `d1dcf96dc`.
3. **hwmon-row tick fix** (`…0844cefd`, footer `1815374e1`): both queue rows ticked with DONE close-outs; provenance split (footless carrier 35b69d475) documented.
4. **Value-less-line guard fix** (`…087d8a5c`, footer `87b2132dc`): chronic-red emission behind `[ -n "$GATUS_CHRONIC_RED" ]`; live-verified in the deployed gen-997 script by the first fire.
5. **This fire**: re-verification complete, verdict recorded (the artifact the queue re-fired for), footer-bearing evidence commit landed.

## b) PARTIALLY DONE

Nothing new this fire; carried state unchanged from the 06-14 report §b: fix ticket `…087e73f1` closed on a false-premise record with its disposition rows queued, not executed; post-deploy verify row 374 still unrun (~35h after its blocker dissolved at gen-997); fixture legs absent; hwmon-tick attribution split permanent absent owner ruling.

## c) NOT STARTED

Unchanged and correctly queued (not re-queued here — dedup held): A1 value-less-emission class gate (with the noted textfile-emission-lint regex blind spot), A2 absence retro, A3 meta-errors consumer audit, A4 blip watch, flap-absorption fleet pass, fixture legs + chronic-red SQL promotion, owner [decision]/[blocked:user] rows (Discord receipt glance, time_series_v2 drop, three threshold/tolerance/routing rulings, provenance-split rebase).

## d) TOTALLY FUCKED UP

1. **This re-fire itself is the finding.** The first fire completed every artifact of the close contract EXCEPT the verdict recording surviving to the queue — two paid fires for one closeout. The repo already rows the mechanism (TODO_LIST:1734 verdict-discard ordering; 1432 closeout-class budget park) and the re-fire guard proposal (1425) would have made THIS fire a self-serve no-op at claim time. No new damage; the pattern recurred exactly as documented.
2. **Carried from the window** (06-14 §d, unchanged): the `…087e73f1` false verification claim (working-tree grep presented as commit-anchor absence); the hwmon item's four-dispatch cost; two daemon races foreclosing amend repairs permanently; the textfile-emission-lint gate shipped with a regex blind spot to the very class it targeted.

## e) WHAT WE SHOULD IMPROVE

1. **Land row 1425's re-fire guard** — a done-prompt whose task IDs all carry footer commits plus an existing same-window closeout report should close as a verified no-op at claim time, not re-run. This fire is the 2nd confirmed instance (2026-10-15 the 1st).
2. **Verdict durability** (row 1734's agent-side complement): record the verdict IMMEDIATELY after the skeleton commit, then re-record after the final amend — a crash between amend and verdict is currently indistinguishable from a crash before any work.
3. Unchanged from the 06-14 report §e: per-item close-out hygiene as a session-exit step; git-log evidence for "anchor absent" verdicts; extend the emission lint to interpolated-var shapes; fixture-first for new gatus patterns; mint-and-poll post-deploy verify legs.

## f) NEXT THINGS

All candidates dedup-checked against TODO_LIST — every item this window surfaced is already queued (rows 374, 3416–3419, 1425, 1432, 1734, flap-absorption + fixture rows in the monitoring section, and the [decision] block). **No new items appended; nothing was worth minting a reworded duplicate for.** Highest-value pending executions: run row 374's post-deploy verify leg (overdue, cheapest probe in the queue); A1/A2/A3 class-defense rows; the flap-absorption pass.

## g) QUESTIONS FOR THE OWNER

All three live [decision] rows are already in TODO_LIST ending in BLOCKED (appended by the first fire; not duplicated here):
1. GC WARN tier before the /nix 90% page — 85% observability-only, or one threshold?
2. Chronic-red routing — shared Discord channel, or a quieter "patterns, not pages" channel?
3. Absence-trip tolerance for absence-tripped gatus checks — accept fail-closed blips, or authorize N-consecutive-failure tolerance?
Plus the parked time_series_v2 DROP ruling (expires 2026-11-12, tq question 55a39b9a) and the provenance-split rebase ruling.

## h) BAND DRIFT

**None recorded.** `tq facts` and `tq facts --type task.reprioritized` both returned 0 rows (queried 2026-11-11 06:2x against the production DB). No priority moved in this window; nothing to explain.

## Provenance

This report + its annotation to the 06-14 report ride the single footer-bearing commit of this fire (`Task-Queue-ID: 000001a1c2e674da8a550bf5f53000000000` as the final message line). Prior-instance commits: `61dded91d` (skeleton), `fcbb0e1c1` (amended full close). Verdict for this fire recorded via `tq verdict --file` immediately after commit.

Task-Queue-ID: 000001a1c2e674da8a550bf5f53000000000
