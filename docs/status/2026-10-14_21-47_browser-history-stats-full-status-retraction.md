# Status: Browser-History Dashboard Question — Full Session Report, One Retraction

**Session:** 2026-10-14, ~20:19-21:55 CEST · **Owner question:** "Why can I STILL only see [the 9 stat cards] on `https://history.home.lan/`" (+ follow-up: "past reports said ~4500 browser history events instead") · **Scope discipline:** this report covers ONLY this session's run and what it directly observed.

---

## a) FULLY DONE

1. **The question answered with a verified verdict: nothing is missing.** The nine items the owner listed are the COMPLETE upstream stat-card set (template `statGrid` at the deployed rev renders exactly those 5 cards + 2 productivity cards + the 2 conditional notes). Every other section renders below them: Activity heatmap, Goals, Recent visits (per-visit dwell/intent table), Recent searches, Top-domains-by-duration leaderboard, 14-day trend, Machines, Agent Tokens, Top domains, Sessions, Domain Overrides.
2. **Rev parity proven:** deployed binary `browser-history-server-8900354` (read off the live unit's ExecStart) == upstream HEAD `8900354` (2026-10-13 21:12Z) == SystemNix `flake.lock` node. Nothing undeployed; the "STILL" cannot be a stale-binary problem.
3. **Server-side full render proven from prod:** the dashboard handler's errgroup fails the whole page if visits/domains/sessions loads fail; the owner's authenticated `GET /` returned 200 all evening with populated stats ⇒ every section load succeeded.
4. **The decisive probe — owner's exact data rendered locally:** ran the deployed `8900354` binary against a throwaway copy of tonight's 02:15 pool backup, registered a local user on a fresh DB, re-attributed the data-owner's read-model rows to it, fetched `/` with that session: **200, 463,185 B, ~0.1 s, ALL sections present** — including the visits table carrying the owner's real rows (tq.home.lan, yandex.com, catalog.home.lan, auth/crm/geo.home.lan, …).
5. **All nine stat values verified against the backup (per-user scoping confirmed):** visits 1727→1739 (+12 by evening), sessions 123→126, searches 100/100 user-scoped (225 total), downloads 56/56 user-scoped (114 total), domains 96 user-scoped (336 total), durations 704 granular vs 1023→1031 zero (the +8 zero-duration among the +12 new visits is normal early-visit behavior before dwell updates land).
6. **Data freshness proven:** owner's visits run Sep 4 22:24 → Oct 13 23:05 (backup boundary) and ingest keeps flowing (`accepted=1` on new data at 20:01, dedupe-empty batches every 5 min after).
7. **The "1031 visits without duration" note explained as permanent-by-design:** those visits predate granular duration capture; dwell time cannot be derived retroactively; Productivity (duration) 47% is computed only over the ~708 granular visits.
8. **The "~4500 events" reconciliation (owner follow-up):** three DIFFERENT surfaces — `events` table = **136,780 rows** (136,762 `visit_recorded` + 9 `UserRegistered` + 9 `ExternalAccountLinked`), `visits` read model = **4,906 rows** (3,179 zero-user pre-attribution era Jan 1→Sep 4 + 1,727 owner), **dashboard = 1,727→1,739 (owner-scoped slice only)**. Past reports' "~2,927 events" (Aug 7) / "~4500" ≈ read-model-era counts — consistent with 4,906 today. **No data was lost**; the dashboard intentionally shows only the logged-in user's slice.
9. **A wrong claim retracted same-session (see d):** the "13-19 s render latency" finding was a journal-unit misread; queue row replaced, both earlier surfaces corrected, retraction recorded in the 21-07 report §e and this report §d.

## b) PARTIALLY DONE

1. **Section-population spot-checks in the repro:** presence of ALL sections verified; the visits table and top-domains verified WITH data. NOT individually rendered: Recent searches (the repro's `search_queries` rows were not re-attributed to the throwaway user — empty by construction, prod scoping verified only via the SearchCount=100 stat), heatmap cells non-zero, Machines/Agent-Tokens row contents. High confidence, zero doubt on prod, but the literal pixel-level proof exists only for visits/domains.
2. **Slow-render history explained but not attributed:** the 10 genuine outliers (8 renders 10.7-37.7 s in a burst 2026-10-10 16:33-17:00, one 49.2 s at 2026-10-12 03:51 — both PRE-hot-tier; today post-cutover 0/106 over 10 s) correlate by TIME with known QLC IO-storm/backup windows but no per-burst PSI/journal correlation was pulled. Queued as [watch], not root-caused.
3. **crush.db session archaeology:** recovered the session title ("Still limited to basic stats on history dashboard") and confirmed no prior session promised specific new stats — but message `created_at` values are broken (display 1970-01-21), so recency had to be derived via rowid; the archaeology method cost several queries that a working timestamp column would have saved.

## c) NOT STARTED

1. **Upstream richer-stat work:** if the owner wants NEW summary cards (category breakdown, total dwell, week-over-week delta, intent mix, …), nothing exists yet — awaiting the owner's target list (question g1).
2. **Zero-user 3,179-visit fate:** re-attribution to the owner vs archive — no upstream-sanctioned tool exists (the runbook explicitly forbids raw `UPDATE visits SET user_id`); untouched pending owner decision (g2).
3. **The runbook/lock-note refresh** (deployed-rev note, stale flake.nix pin comment, registration-gate triage note, repro-harness codification, events/visits/dashboard reconciliation table) — identified, queued in §f, not written.
4. **Render-duration alerting:** no Gatus/post-deploy threshold on dashboard render time exists.

## d) TOTALLY FUCKED UP

1. **The unit misread (the big one):** I read the journal `duration` field as seconds — it is NANOSECONDS. Tonight's "13-19 s" renders were 13-19 **ms**; the "8.2 s empty /ingest" was 8.2 ms. I escalated a NONEXISTENT latency regression into a `[ready]` queue row in two surfaces plus a written report §e — all within an hour. Caught it only because the user demanded this status report and I re-pulled the journal for a pre/post-cutover baseline (pre-cutover renders are ALSO ms; the 10 real second-scale outliers were hiding in the same awk). This is exactly the project's evidence-rule class: I HAD the run, then misread it, then wrote prose from the misreading. Corrected surfaces: `TODO_LIST.md` row, `docs/todo/services.md` row, 21-07 report §e — all replaced/retracted with the post-state shown.
2. **Sloppy process management on the shared prod host:** the repro server was started three times with overlapping configs; the first instance (MAX_USERS=1, port 18087) survived a `pkill` whose pattern matched env-not-cmdline, silently served TWO subsequent 403 "registration_closed" responses that cost two full debug detours, and four stray processes piled up before the env-filtered kill loop cleaned them. Prod (systemd pid) was never touched — verified by env-read permission-denied on the real unit — but the failure mode (killing the wrong PID on a box running everyone's services) was one bad filter away.
3. **Self-referential crush.db queries:** searching `messages.parts LIKE '%history.home.lan%'` matched my own in-flight session rows, and one 6 GB full-scan integrity check ran long enough to need a background kill. The schema (rowid ordering, broken created_at) should have been mapped BEFORE querying.
4. **Attempted session forgery before reading the auth source:** inserted a row into `auth_sessions` and tried five cookie names against a locally started prod binary before reading `usermgmt/http.go` and learning sessions are event-sourced via the service layer. Pure luck that this was the throwaway copy and not prod.
5. **The 21-07 report shipped with the wrong §e** (consequence of d1) — caught and fixed 50 minutes later; had the daemon swept it and a future session quoted it, the fabricated latency number would have propagated.

## e) WHAT WE SHOULD IMPROVE

1. **Unit-check reflex for every journal field quoted in prose** — one awk with `/1e9` vs `/1e6` inverted a whole finding; the runbook's live-probe recipe should pin the journal schema (`duration` = ns) next to the exact awk.
2. **Never start a second instance while the first may still hold the port** — bind-fail is silent in background logs; verify ownership (port → pid → env) before any auth-facing probe.
3. **Read the gate's source before probing the endpoint** — `usermgmt.Register` checks `maxUsers > 0 && readModel.Count() >= maxUsers`; five minutes of reading beats two 403 detours.
4. **Repro harnesses deserve a recipe** — the fresh-DB-registration + read-model re-attribution trick unlocked the only pixel-level proof available without the owner's session; it currently lives only in this session's transcript.
5. **Status-report numbers get a re-read pass before writing** — the ms/s confusion would not have survived a 30-second self-check of "13 seconds for a dashboard that locally renders in 100 ms?" (the absurdity was visible: prod would be ~150× slower than local for no stated reason).

## f) NEXT (up to 50, harvested where actionable)

**Corrections/verification (from d/b):**
1. Correlate the 2026-10-10 16:33-17:00 slow-render burst (8 renders, ≤37.7 s) with io-PSI/journal storm evidence — [queued: watch, services.md].
2. Correlate the 2026-10-12 03:51 49.2 s render with the nightly backup window — [queued: watch, services.md].
3. If both bursts land in known storm windows, close as explained-context and add a Gatus render-duration threshold (>5 s authed) — folded into the same watch row.
4. Verify heatmap cells render non-zero with the owner's data (repro gap).
5. Verify Recent-searches section renders with the owner's queries (re-attributed repro copy).
6. Verify Machines/Agent-Tokens section contents in the repro.
7. Confirm tonight's (Oct 15, 02:15) browser-history backup through the hot mount — existing [watch] row, tomorrow morning.
8. Count current user rows vs the 9 `UserRegistered` events — did the zombie-dupes count move since Oct 4?

**Docs (browser-history runbook + repo):**
9. Update `docs/services/browser-history.md` lock-note to deployed-verified `8900354` (current note narrates the Sep-17 rollback).
10. Fix the stale `flake.nix` browser-history input comment ("lock still holds 0971fe9c" — false; pin-policy comment predates the lock move).
11. Document the registration gate (`MAX_USERS`, 403 `usermgmt.registration_closed`) in the runbook triage section.
12. Record "auth sessions are event-sourced; direct `auth_sessions` INSERT never authenticates" in the runbook.
13. Codify the local-repro harness (fresh-DB registration + read-model re-attribution + session fetch) as a runbook recipe or `scripts/` tool.
14. Add the events/visits/dashboard reconciliation table (136,780 / 4,906 / 1,739) to the runbook — kills the recurring "numbers differ" class (owner hit it again today).
15. docs-health VERIFY pass over browser-history.md's other entries (FOD-shim section references shims dropped in `f0442ea3`).
16. Record the crush.db forensics gotchas (created_at broken → order by rowid; LIKE queries match your own session) in the agent-forensics docs.
17. Pin the journal `duration` unit (ns) + a correct one-liner into the runbook live-probe recipe (unit-misread insurance).

**Upstream product ideas (noticed while reading the template/README; owner-gated, g1):**
18. Category-breakdown card ("where your time goes" beyond one %) — `/visits/grouped?groupBy=category` already exists.
19. Total dwell-time-in-period card.
20. Week-over-week delta card (visits/sessions/domains vs prior week).
21. Intent-mix card (typed vs clicked vs reload).
22. Most-active hour/day summary chip.
23. Toggle to exclude the pre-granular era from duration stats (cosmetic honesty).
24. Rename-drift check: "Productivity (dwell time)" (Oct 7 paste) vs "Productivity (duration)" (current) — update screenshots/docs.
25. Stats-only cheap partial for the 30 s live poll (full `dashboardContent` re-render every 30 s is ~20 queries for what is usually zero visible change).
26. Single-flight dedupe for concurrent identical partial renders (multi-tab).
27. `/metrics`: per-endpoint duration histogram.
28. Upstream pprof env flag for on-demand profiling.
29. Hero range label shows "Aug 14" although the owner's minimum visit is Sep 4 — range-source bug candidate (event-store min vs read-model min).
30. README claims "live SSE updates" for the dashboard; it is a 30 s poll (SSE exists only on /summary) — docs drift.

**Identity/data (owner-gated, g2):**
31. Decide the 3,179 zero-user visits' fate (upstream-sanctioned re-attribution tool vs archive marker).
32. Upstream: DeleteUser admin surface (zombie dupes — known since Oct 4, still the only cleanup path).

**Harvest record:** items 1-3 are the [watch] row already in `docs/todo/services.md` + `TODO_LIST.md` (self-harvested at authoring time, replacing the retracted row). Items 4-8, 9-17, 31-32: deliberately NOT queued this session — they are verification chores and doc polish that belong to a dedicated browser-history docs/verify dispatch, not to a question-answer session; this §f IS their inventory (cite this report when dispatching). Items 18-30 are upstream product decisions requiring the owner's answer to g1 first.

## g) QUESTIONS FOR THE OWNER

1. **What did you EXPECT the dashboard to show that it doesn't?** All existing sections render — so "STILL only basic stats" reads as either (a) you want NEW kinds of summary stats (then: which ones — category split? total hours? trends? — that list becomes the upstream work order), or (b) your browser genuinely shows nothing below the stat cards (then: a client-side problem I cannot see from the server). Which is it?
2. **Should the 3,179 pre-attribution visits (Jan 1 → Sep 4) become YOURS?** They are invisible to your dashboard by design. Re-attribution needs a small upstream-sanctioned tool (raw `UPDATE user_id` is documented-unsafe); archive-and-forget is the zero-work option. Which way?
3. **Is a full browsing history from Jan 1 onward even correct?** Your Firefox/Helium profiles only reach back so far — if the pre-attribution rows came from a stale/other profile (e.g., the Trash `helium-dp1/dp2` copies the Oct-7 session found), "re-attribute" would import history you may not consider yours. Do you know what was browsing Jan-Sep on this machine before the agent era?

**Waiting for instructions.**
