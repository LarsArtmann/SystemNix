# Deploy-exit-4 wave session — Status Update 2 (continuation: report v1, self-harvest, checker triage)

**Date:** 2026-11-02, continuation 03:40→04:00 CEST (report written 04:00)
**Tree at write time:** HEAD `90758cdff` (daemon-swept, clean); my harvest batch = `d0a5e0e51` (03:44: TODO_LIST +2, services.md +4), my v1 report = `90758cdff` (03:47)
**Base:** docs/status/2026-11-02_03-40_nh-deploy-exit4-triage-opencloud-9100-bind-race-fix-session.md (the full mechanics live there — this update carries the a–g forward and covers the 20-minute continuation honestly)
**Live state at write time (04:00):** opencloud still FAILED (fix in tree, deploy still pressure-gated) · home-manager-lars ACTIVE (fix holding) · anchor ANCHORED (`system-968-link`) · PSI 57.35 (easing from 64, still > 20% gate) · NO new generation — nobody deployed

---

## Verdict (one line)

The wave-fix work is complete and self-harvested; the only live gap remains the pressure-gated deploy; this continuation's NEW own-goals are two quote-scrutiny slips in my closing message (a lines-vs-reports count conflation and a misattributed baseline time) — both caught while re-checking myself for this report.

## a) FULLY DONE (continuation work since v1)

1. **Status report v1 written** — `docs/status/2026-11-02_03-40_…` (116 lines, a–g complete, self-harvest section executed inline).
2. **Self-harvest executed at authoring time (no entombment)** — 4 rows landed and daemon-swept in `d0a5e0e51`: `[ready]` deploy-the-opencloud-fix+verify bundle (TODO_LIST + services.md), `[ready]` nh `stc test` profile-trap investigation (both surfaces), `[watch]` HM fleet-timer soak + `.backup` cleanup (services.md), `[watch]` `notify-failure@<unit>.service.service` double-suffix verify (services.md) — every row Source-cited to the v1 report.
3. **check-todo-system.sh FAIL triaged as NOT MINE** — the gate's failure is the known unharvested-§f-report drift (159 UNHARVESTED report lines + summary WARN + FAILED line); my v1 report is CITED by the new rows so it does not appear in the UNHARVESTED list (verified by filename grep against the checker output). This matches the pre-existing class the storm-night2 session also triaged as not-theirs.
4. **Carrier-state re-verified at 04:00** — HM fix still holding; anchor still consistent; no third party deployed; opencloud churn unchanged (unit still failed/start-limit, not retrying — its Restart= is exhausted; no journal noise).

## b) PARTIALLY DONE

1. **The opencloud 9500 fix still rides the undeployed generation** — PSI easing (92 → 57 over the session) but the gate needs < 20%; the pre-scripted one-shot remains `~/.cache/deploy-repair/pressure-wait-deploy3.sh` (wait → deploy → anchor-verify → listeners + fatal-count), or the owner's `DEPLOY_FORCE_PRESSURE=1`.
2. **Fleet-timer soak** — rows queued, first site-monitor tick has still not been observed (hourly boundary; now ~2 missed opportunities since 01:28 — if BOTH hourly ticks passed silently, that itself is a signal to check the timer's journal, folded into the existing watch row).
3. **post-deploy-check / pre-reboot-check** — still deferred behind the deploy (same as v1 §b3/§b4; owning it remains).

## c) NOT STARTED

1. Everything gated on the deploy (opencloud verification suite, §f bundle row).
2. bank-sync surgery staging — owner question outstanding (v1 §g1).
3. home-lars-tmp direction call — owner question outstanding (v1 §g3).
4. The 159-report harvest drift (docs-health HARVEST pass over docs/status/) — pre-existing debt, not this session's scope; flagged, not queued (the 2026-10-25 prune-pass machinery in AGENTS owns the pattern).

## d) TOTALLY FUCKED UP (continuation-specific; v1's §d stands)

1. **Quote-scrutiny slip #1: conflated checker LINES with REPORTS** — I reported "161 unharvested §f reports" from a `grep -c 'UNHARVESTED|WARN|ERROR'` that counts 159 report lines + the WARN summary + the FAILED line = 161 LINES. The true figure stayed 159 reports between runs; no new drift was added. The exact class AGENTS warns about ("the number must survive one known-value check") — the known-value check here would have been `grep -c UNHARVESTED` alone.
2. **Quote-scrutiny slip #2: misattributed the baseline time** — I wrote "count was already 159 at 02:13" in my closing message; the 159 reading is from MY OWN checker run at ~03:41, and the storm-night2 session at 02:13 never published a count. Invented precision — exactly the "commit-message evidence rule" class (a number/claim needs an actual run behind it, correctly time-stamped).
3. **v1's §f said "harvest decision inline" for 30 items, but only 4 were queued** — the inline decisions for f5–f30 are recorded only as a batch sentence ("proposals/owner-gated/other-session-owned") rather than per-item; acceptable under the batch-recording allowance but thinner than the discipline's letter ("recorded as 'deliberately not harvested because X'" per item). Noted so the next HARVEST pass doesn't treat v1 §f5-30 as unprocessed queue fuel blindly.

## e) WHAT WE SHOULD IMPROVE

1. **Numbers in closing messages get the same scrutiny as report numbers** — both slips above happened AFTER the report was done, in the chat handoff, where I relax. The rule is "would I quote this in a report? then sanity-check it" — chat IS a report surface.
2. **Close-out messages: cite the check run that produced every figure** (time + command), not remembered state.
3. **Re-run the state probes immediately before writing any status file** — state moved between my last probe (03:37) and the v1 write (03:40); luckily nothing shifted, but the report's "live state" line must come from a probe ≤ the write instant, not from memory.
4. Carry-over from v1 §e (unchanged, still true): pre-flight PSI before deploys; freeze failing services before iterating; /proc/net/tcp-first for EADDRINUSE; script+sudo from attempt one; mid-session co-session re-checks; the nh profile-trap mechanical guard.

## f) Things to get done next (updated; harvest state per item)

*Already queued from v1 (self-harvested, daemon-swept in `d0a5e0e51`) — unchanged, re-listed for completeness:*

1. Deploy the opencloud 9100→9500 fix + full post-deploy verify — `[ready]` (queued).
2. Investigate nh `os switch` → `stc test` profile trap — `[ready]` (queued).
3. Soak HM fleet timers (first real ticks) + trash the `.backup` files after green — `[watch]` (queued).
4. Verify the `notify-failure@<unit>.service.service` double-suffix — `[watch]` (queued).

*New/not-yet-queued:*

5. Observe the next site-monitor hourly tick NOW (two hourly boundaries may already have passed silently since the 01:28 fix — if so, pull the timer journal; fold into row 3). — part of row 3, no new row.
6. Fire the deploy the moment PSI < 20% (57.35 at 04:00 and falling — likely within the hour if the storm's cold-loads settle). — part of row 1.
7. Run `pre-reboot-check` standalone on the anchored gen-968 state (don't couple it to the deploy). — deliberately not re-queued: it rides inside row 1's verify bundle; standalone run is owner-optional.
8. bank-sync surgery staging — blocked on owner answer (v1 §g1).
9. home-lars-tmp direction — blocked on owner answer (v1 §g3).
10. The 159-report docs-health HARVEST pass — deliberately not queued: pre-existing fleet-wide debt with existing prune machinery (scripts/prune-done-todos.sh, AGENTS 2026-10-25 note); a dedicated session should own it, not this one.
11. v1 §f5–f30 (storms playbook, HM-clobber preflight audit, ocis-band eval assertion, opencloud upstream issue, deploy-when-calm timer app, etc.) — deliberately not harvested: proposals/ROADMAP fuel per v1's recording; owner picks.

## g) The 3 questions (unchanged — answers gate the biggest open items)

1. **bank-sync:** `migrate-journal` (folds/truncates journal history) or pre-migration snapshot restore — which, and may I stage it (stop daemon → read the bank-sync repo runbook → dry-run)?
2. **opencloud:** force the deploy now (`DEPLOY_FORCE_PRESSURE=1`, PSI 57 and easing) or wait for calm? Four days of outage vs storm discipline — your call by design.
3. **home-lars-tmp:** recreate `users/lars/tmp` + migrate (automount must be STOPPED before subvol creation — new hazard) or retire the fstab entry?

---

*Self-harvest: no NEW queue rows from this update (f1-f4 already queued in `d0a5e0e51`; f5-f11 recorded above as folded/blocked/deliberately-not-harvested).*
