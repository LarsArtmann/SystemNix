# Status Report: Crush Daily Cross-Project Insights Backfill + Upstream Resilience Fixes

**Date:** 2026-07-29 15:51
**Session scope:** Retry 31 failed cross-project insights (Synthetic API rate limit exhaustion from previous session)

---

## A) FULLY DONE

### 1. Root Cause Analysis: 31 Dates Had ZERO Per-Project Insights (Not Just Missing Cross-Project)

The previous session's status report (`2026-07-29_07-18`) claimed the 31 dates had "per-project insights only (cross-project failed)". **This was wrong.** Investigation of the SQLite event store revealed:

```
ProjectInsightsGenerated events by date:
  2026-07-11: 118 events    ← the 14 "successful" dates
  2026-07-13: 37 events
  ...
  2026-06-11: 0 events      ← the 31 "failed" dates
  2026-06-12: 0 events
  ...
```

**ALL 31 dates had ZERO `ProjectInsightsGenerated` events.** Not just missing cross-project. The previous session's report was misleading — it assumed Round 1 succeeded because `insights` returned "non-fatal" errors, but no events were ever persisted.

### 2. Two Upstream Bugs Fixed in crush-daily (`internal/insights/insights.go` + `internal/app/insights_service.go`)

**Bug #1 — `errgroup.WithContext` cancels ALL goroutines on first error:**

The `GenerateAllProjectInsights` method used `errgroup.WithContext(ctx)`, which creates a derived context that is cancelled when the first goroutine returns an error. With 83-259 active projects per date (pool size 5), a single transient API failure (503, rate limit, timeout) cancelled all in-flight and pending project insight calls. Result: **partial results were returned but empty** — the error short-circuited the group before most projects could complete.

**Fix:** Replaced with a plain `errgroup.Group` (no context cancellation). Errors are collected per-project in a mutex-guarded slice. All goroutines run to completion. The final error wraps ALL collected errors via `wrapSomeProjectInsightsFailed`.

**Bug #2 — `round1ProjectInsights` discarded partial results on error:**

```go
// BEFORE (buggy):
projectInsights, err := generator.GenerateAllProjectInsights(...)
if err != nil {
    return projectInsights, fmt.Errorf(...)  // ← returns BEFORE storing any results
}
for i, insight := range projectInsights {     // ← storage loop NEVER reached on error
    ...
}
```

Even though the generator returned partial results alongside the error, the storage loop was placed AFTER the error check. A single failure meant **zero insights were persisted** — hundreds of successful LLM calls thrown away.

**Fix:** Moved the storage loop BEFORE the error return. Partial results are always persisted. The error is still propagated (caller can decide whether to proceed to Round 2).

**Bug #3 — No reuse of existing per-project insights:**

Added a reuse path: if `result.ProjectInsights` already has entries (from the read model projection), Round 1 skips all LLM calls and reuses them. This is critical for backfill scenarios where Round 1 succeeded but Round 2 failed. A helper `alignInsightsToProjects` maps stored insights back into project-index space (stored events are a subset — inactive projects with SessionCount==0 are skipped, so the slice is shorter than the projects slice).

*Note: Bug #3 was implemented but turned out to be unnecessary for THIS backfill (the 31 dates had zero stored insights due to Bugs #1+#2). It will help future partial-failure backfills.*

### 3. All 20 crush-daily Test Packages Pass

```
ok  github.com/larsartmann/crush-daily/cmd/crush-daily           2.546s
ok  github.com/larsartmann/crush-daily/internal/app              0.056s
ok  github.com/larsartmann/crush-daily/internal/insights         0.006s
... (20 packages total, all pass)
```

### 4. Batch Backfill Script Created and Running

Wrote `/tmp/run-insights-batch.sh` — a throttled batch runner that:
- Processes dates from **fewest-to-most active projects** (maximizes dates completed before any rate limit)
- Detects rate limit errors and stops early with a summary
- 5-second delay between dates
- Logs per-date success/failure

### 5. Auto-Commit Captured Upstream Changes Correctly

The auto-commit daemon in crush-daily committed the 2 changed files (67 insertions, 10 deletions across `insights_service.go` and `insights.go`) and pushed to GitHub master. The changes are at commits `dab8c19` + `868fe33`.

---

## B) PARTIALLY DONE

### Cross-Project Insights Backfill — IN PROGRESS (4/31 complete as of report time)

The batch job is running in the background. Current state:

| Metric | Value |
|--------|-------|
| Dates completed (with cross-project insights) | 4 of 31 |
| Dates remaining | 27 |
| Current date processing | 2026-07-12 (5th, 29 active projects) |
| New ProjectInsightsGenerated events | 68 (14+13+13+28 across 4 dates) |
| Total CrossProjectInsightsGenerated events | 19 (15 old + 4 new) |
| Rate limit hit | No |

**Completed dates so far:**
1. `2026-06-25` (14 projects) — OK
2. `2026-06-26` (13 projects) — OK
3. `2026-07-27` (14 projects) — OK
4. `2026-06-21` (28 projects) — OK

**Estimated time remaining:** Each date takes 2-8 minutes depending on project count. 27 remaining dates with average ~83 projects each. At pool size 5, that's ~17 calls per batch × ~10 seconds per call = ~3 minutes per date. Total: ~80-120 minutes.

**Risk:** Synthetic API rate limit may hit partway through. The batch is ordered fewest-projects-first to maximize completion count before any limit.

---

## C) NOT STARTED

1. **TODO_LIST.md update** — The checkbox `[ ] Crush Daily: retry 31 failed cross-project insights` has not been updated yet. Should be marked `[x]` once the batch completes.

2. **SystemNix flake.lock bump** — The crush-daily flake input in SystemNix still points to the OLD commit (`1eb5154`). After the batch completes, SystemNix's flake.lock needs updating to point to the new crush-daily commit (`868fe33`) so the deployed service includes the resilience fixes.

3. **Deploy to evo-x2** — Neither the resilience fixes nor any other pending changes have been deployed. The running `crush-daily.service` uses the OLD binary without the errgroup fix.

4. **AGENTS.md gotcha documentation** — The `errgroup.WithContext` cancellation bug and the partial-results-discarded bug should be documented as upstream resilience patterns. Not yet added.

5. **Restart crush-daily.service** — After the batch completes, the service's in-memory read model needs rehydration (`systemctl restart crush-daily.service`) to serve the new insights via the HTTP API.

6. **Report regeneration** — The 31 dates have HTML reports generated from the PREVIOUS run (without cross-project insights). Reports should be regenerated to include the new cross-project synthesis. The `crush-daily report --date <DATE>` command does this, but it hasn't been run for the backfilled dates.

7. **Status report for the batch completion** — Once the batch finishes (or hits rate limit), a follow-up status report should document the final count.

8. **The `--collect-only` flag suggestion in the TODO was wrong for this task** — The TODO said "throttle with `--collect-only` first", but collect-only skips insights entirely. It would have done nothing useful since the data was already collected correctly. The TODO instruction was based on the incorrect assumption that only cross-project insights were missing.

---

## D) TOTALLY FUCKED UP

### 1. Trusted the Previous Session's Diagnosis Without Verifying

The previous session's status report (`2026-07-29_07-18`) stated the 31 dates had "per-project insights only (cross-project failed)". I designed an optimization (Bug #3: reuse existing insights) based on this assumption. When I tested it on 2026-06-11, Round 1 ran anyway (259 projects, 5 minutes) — because there were NO stored insights to reuse. The previous session's diagnosis was wrong: ALL 31 dates had zero per-project insights, not just missing cross-project.

**Lesson:** Always verify claims from previous sessions against the actual database state before designing solutions based on them. The previous session saw `ProjectInsightsGenerated: 683` in the event store and assumed they spanned all 45 dates — they actually only covered 9 dates (the ones that completed before the rate limit).

### 2. First Test Run Wasted 5 Minutes of API Quota

My first test (`crush-daily insights --date 2026-06-11`) ran the full Round 1 (259 projects, ~5 minutes, ~250+ API calls) before I discovered there were no stored insights to reuse. This consumed Synthetic API quota unnecessarily. I should have checked the event store for ProjectInsightsGenerated events BEFORE running any insights command.

### 3. Didn't Check That the Backfill Script Was Applicable

The TODO said to use `nix run .#crush-daily-backfill -- --from 2026-06-11 --to 2026-07-10`. I read the backfill script and discovered it only targets **zero-data events** (events with `session_count == 0`). These 31 dates have valid data — they're only missing insights. The backfill script would have found zero zero-data events and done nothing. I had to write a custom batch runner instead.

### 4. Built and Tested Against Wrong Config File Initially

My first `insights` command used the wrong nix store config file (`i2d6r2s8d5...`, 1147 bytes — a sops-encrypted secrets file) instead of the app config (`cc8bz4bmr1...`, 355 bytes — the actual YAML config). This produced a confusing "no data collected" error because the binary tried to parse a sops ciphertext as YAML.

### 5. The `alignInsightsToProjects` Helper Is Currently Dead Code

Bug #3 (reuse existing insights) was implemented and tested but is effectively dead code for THIS backfill — none of the 31 dates have stored insights. It will only activate for FUTURE partial-failure scenarios. This isn't harmful (it's correct and tested), but it was unnecessary work driven by the wrong diagnosis.

---

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Verify previous session claims before acting** — "Trust but verify" applies to AI session handoffs. The 15-minute DB query to check event counts would have saved the 5-minute wasted API call.

2. **Check API quota before batch LLM operations** — STILL not done (this was flagged in the previous session too). The Synthetic API has no documented quota/billing endpoint, but we could at least do a single test call and check for rate-limit headers before committing to a 31-date batch.

3. **The backfill script needs an `--insights-only` mode** — The current `crush-daily-backfill.py` only handles zero-data events. It should also support "regenerate insights for dates that have data but missing cross-project insights" — the exact scenario this task required. A custom shell script was needed instead.

4. **Per-project insight persistence should be idempotent** — Currently, re-running insights for a date that already has `ProjectInsightsGenerated` events APPENDS new events (the fold uses `append`, not replace). This means re-running the same date creates duplicate events. Not a correctness bug today (the read model takes the latest), but it bloats the event store over time. Consider a deduplication key or a "clear existing insights before regenerating" command.

5. **The insights pipeline should checkpoint progress** — If the batch hits a rate limit at date 15/31, there's no way to resume from date 16. The batch script would need to be re-run with a manual `--from` adjustment. A checkpoint file or DB marker would make resumption trivial.

6. **Test the errgroup fix more thoroughly** — The fix changes fundamental concurrency behavior (from cancel-on-first-error to collect-all-errors). The existing tests pass, but a dedicated test that simulates partial API failures (e.g., 3/5 projects fail, verify 2/5 results stored) would provide stronger confidence. Currently relying on the integration test suite which uses real LLM calls.

### Architectural Observations

7. **294 projects discovered, 14-229 active per date** — The collector discovers ALL crush project databases on the system. Many are tiny (1-2 sessions). The insights pipeline generates an LLM call for EACH active project. For a date with 229 active projects at pool size 5, that's ~46 sequential batches × ~10s per call = ~8 minutes per date. Consider a `min_session_threshold` config option to skip projects with <3 sessions (they contribute almost no signal to cross-project synthesis).

8. **The event store is append-only with no compaction** — 46 collected events + 751 project insight events + 19 cross-project events + 45 report events = 861 events for 46 dates. At this rate, a year of data would be ~7000 events. SQLite handles this fine, but the read model projection replays ALL events on startup (`bus.SubscribeAll`). Consider snapshotting or event pruning for long-running deployments.

---

## F) Up to 50 Things to Get Done Next

### Immediate (block completing this task)
1. **Wait for batch to complete or hit rate limit** — monitor background shell `0BA`
2. **Write final batch results** — update this report or write a follow-up with the final count
3. **Mark TODO_LIST.md checkbox `[x]`** for the crush-daily insights backfill item
4. **Regenerate HTML reports** for the 31 backfilled dates (`crush-daily report --date <DATE>`)
5. **Restart crush-daily.service** to rehydrate the read model with new insights
6. **Verify via HTTP API** — `curl localhost:8081/api/reports` should show the new dates with cross-project insights

### SystemNix Integration
7. **Update SystemNix flake.lock** — bump crush-daily input to commit `868fe33` (includes resilience fixes)
8. **Deploy to evo-x2** — `nix run .#deploy` to activate the updated crush-daily with errgroup fix
9. **Verify post-deploy** — `nix run .#post-deploy-check` should still pass (asserts `session_count > 0`)
10. **Document errgroup cancellation gotcha in AGENTS.md** — under crush-daily section
11. **Document partial-results-storage pattern in AGENTS.md** — the "store before error return" pattern

### crush-daily Upstream Improvements
12. **Add `--insights-only` flag to backfill script** — for dates with data but missing insights
13. **Add `min_session_threshold` config option** — skip projects with <N sessions in insights pipeline
14. **Add dedicated test for partial-failure resilience** — simulate 3/5 projects failing, verify 2/5 stored
15. **Add checkpoint/resume to batch runner** — write progress to a file or DB marker
16. **Consider event deduplication** — prevent duplicate ProjectInsightsGenerated on re-runs
17. **Add Synthetic API quota check** — probe with a single call before batch operations
18. **Add retry-with-backoff for transient API failures** — 503/502 should retry after delay, not fail
19. **Add rate-limit-aware throttling** — detect 429/rate-limit responses and pause automatically
20. **Log per-project insight generation progress** — currently just "round 1: 259 projects" with no progress bar
21. **Add Prometheus metrics for insight success/failure rates** — `insights_project_total{status=ok|fail}`
22. **Consider OpenRouter as fallback provider** — when Synthetic rate-limits, fall back to OpenRouter
23. **Add `crush-daily insights --from X --to Y` batch mode** — built into the CLI, not external scripts

### Monitoring & Alerting
24. **Add Gatus check for cross-project insight freshness** — alert if latest report has no cross-project insight
25. **Add alert for insight failure rate** — if >50% of projects fail in a single run, alert
26. **Add Synthetic API quota monitoring** — track remaining quota if API exposes it
27. **Add crush-daily dashboard to Homepage** — show insight coverage %, last success, failure count

### Data Quality
28. **Investigate 2026-06-24 gap** — no DailyDataCollected event exists for this date (service was down or collection failed)
29. **Audit all 46 dates for data completeness** — verify session_count > 0 for all, not just the 45 backfilled
30. **Check for duplicate events** — re-running collect/insights may have created duplicates
31. **Verify report HTML renders correctly** — open a few reports and confirm cross-project sections appear
32. **Add data validation to post-deploy-check** — assert cross-project insight exists for the latest report

### Documentation
33. **Update AGENTS.md crush-daily section** — document the errgroup fix, partial storage pattern, reuse logic
34. **Write runbook for insight backfill** — step-by-step for future operators
35. **Document Synthetic API rate limit behavior** — how it manifests, how to detect, how to throttle
36. **Update CHANGELOG.md** — entry for the resilience fixes

### Technical Debt
37. **The `HOME_DIR = "/home/lars"` hardcoded in backfill script** — should derive from config or primaryUser
38. **Backfill script wrapping Python as shell text** — should use `buildPythonApplication` or `writeScriptBin`
39. **`find_binary()` uses `sorted(glob)[-1]`** — non-deterministic if multiple store paths exist
40. **The backfill script deletes events by ID** — should use a domain command, not raw SQL DELETE
41. **`verify_event()` has a fragile SQL query** — noted in previous session, still unfixed
42. **Consolidate 4 go-cqrs-lite lock nodes** — carried over from cqrs-lint task, still pending

### Future Enhancements
43. **Weekly/monthly insight rollups** — synthesize across multiple days for trend analysis
44. **Project grouping/clustering** — group sub-projects (e.g., all SystemNix/* as one)
45. **Cost tracking and budgeting** — alert when daily LLM cost exceeds threshold
46. **Comparative insights** — "this day vs same day last week" delta analysis
47. **Export insights to external format** — Markdown, PDF, or Obsidian-compatible
48. **Integration with calendar/scheduling** — correlate insight themes with calendar events
49. **Team insights** — if multiple developers use Crush, aggregate across users
50. **Historical trend visualization** — charts for complexity, context switches, burnout signals over time

---

## G) Questions (3)

### 1. Should I let the batch run to completion, or is there a time/API-cost budget I should respect?

The batch is processing 31 dates with ~2573 total active projects. At ~10s per LLM call (pool size 5), this will take ~80-120 minutes and consume significant Synthetic API quota. Should I let it run, or would you prefer I stop after N dates and let the nightly scheduler handle the rest over the coming weeks?

### 2. Should I deploy SystemNix now (with the cqrs-lint fix from the previous session) and separately bump crush-daily later, or wait and deploy both together?

The crush-daily resilience fix is committed upstream but SystemNix's flake.lock still points to the old commit. Deploying now would activate cqrs-lint but NOT the errgroup fix. Deploying later (after bumping the crush-daily input) would include both but delays the cqrs-lint activation.

### 3. The crush-daily insights pipeline generates ~250 LLM calls per date (one per active project). Should I add a `min_session_threshold` config to skip low-activity projects?

Many discovered projects have only 1-2 sessions per day. These contribute almost no signal to the cross-project synthesis but each costs an API call. Skipping projects with <3 sessions would reduce API usage by ~40-60% per date. This is an upstream change — should I implement it?
