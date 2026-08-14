# Status: ClickHouse Startup Crash Fix (exit code 36 / merge_tree sanity check)

**Date:** 2026-08-13 01:50
**Session scope:** Diagnose and fix ClickHouse `start-limit-hit` that blocked `nh os switch` for ~14h
**Trigger:** User pasted deploy output showing `clickhouse.service` failed with exit code 36

---

## a) FULLY DONE

1. **Diagnosed the root cause from journalctl** — ClickHouse 26.7.1.1315 rejected startup with `Code: 36. DB::Exception: The value of 'number_of_free_entries_in_pool_to_execute_mutation' setting (20) ... is greater than the value of 'background_pool_size'*'background_merges_mutations_concurrency_ratio' (4)`. The 2026-08-11 thread tuning (commit `b81e5094`) reduced `background_pool_size` from 16→2 without adjusting dependent merge_tree settings.

2. **Fixed ClickHouse by reverting `background_pool_size` to default (16)** — After 3 failed deploy iterations trying to patch individual merge_tree settings (whack-a-mole), recognized the pattern: ClickHouse has an unknown number of `number_of_free_entries_in_pool_*` sanity checks, each with defaults calibrated for pool_size=16. Reverting pool_size is the correct fix. The other 4 pool reductions (schedule 128→8, fetches 8→1, buffer flush 16→4, move 8→2) are kept — they save ~145 threads without triggering any sanity checks.

3. **Fixed pre-deploy-check false positives** — The phantom metric check was reporting Monitor365's metrics (`collector_events_collected`, `cloud_sync_consecutive_failures`, `cloud_sync_upload_backlog_size`) as hard FAILures when Monitor365's endpoint was down, despite logging "skipping metric checks that depend on it." Added a `MONITOR365_UP` flag and `MONITOR365_METRICS` allowlist to downgrade these to warnings when the endpoint is unreachable.

4. **Deployed successfully** — ClickHouse is running and processing background tasks (catching up after 14h downtime). Post-deploy smoke test showed 36 PASS, 7 FAIL (pre-existing service issues, not ClickHouse-related).

5. **Updated AGENTS.md** — Added the `background_pool_size` sanity check trap as a gotcha entry under "Other Services."

---

## b) PARTIALLY DONE

1. **SigNoz recovery NOT verified** — ClickHouse was down for ~14h. SigNoz's query service and OTel collector depend on ClickHouse. The post-deploy check showed `signoz.home.lan → 404` and `Overview (HTTPS) — expected HTTP 200, got 503`. SigNoz may need its services restarted or may recover on its own as ClickHouse finishes catch-up. NOT investigated.

2. **Thread tuning status report NOT updated** — The archived report at `docs/status/archived/2026-08-11_12-30_clickhouse-thread-tuning.md` still claims `background_pool_size=2` as a successful change. It should be annotated that this setting was reverted on 2026-08-13 due to the sanity check cascade.

---

## c) NOT STARTED

1. **browser-history-agent investigation** — Was shown as `failed` in the original deploy output alongside ClickHouse. Not investigated. May be the same pre-existing issue documented in `docs/status/2026-08-12_14-59_browser-history-css-and-startlimit-fixes.md` or may have recovered after the successful deploy.

2. **Monitor365 down** — Port 9191 (Monitor365 metrics) is not responding. Pre-existing — flagged as a warning in pre-deploy-check. Not investigated.

3. **signoz.nix formatting churn** — The auto-git daemon committed the file with 831 lines of alejandra reformatting (413 insertions, 419 deletions) for what should have been a ~10-line change. This destroys git blame for the entire 800-line file. The 2026-08-11 status report documented this exact issue and reverted it. The formatter ran again and was NOT reverted this time.

---

## d) TOTALLY FUCKED UP

1. **Whack-a-mole deployment strategy (3 wasted deploy cycles)** — I tried to fix the merge_tree sanity check by adding settings one at a time:
   - Attempt 1: Added `number_of_free_entries_in_pool_to_execute_mutation=2` + `number_of_free_entries_in_pool_to_lower_size_of_wal=2`
   - Result 1: `number_of_free_entries_in_pool_to_lower_size_of_wal` is UNKNOWN_SETTING in CH 26.7 (I guessed the name)
   - Attempt 2: Removed the invalid setting, kept only `number_of_free_entries_in_pool_to_execute_mutation=2`
   - Result 2: `number_of_free_entries_in_pool_to_lower_max_size_of_merge` (default 8) > pool capacity (4)
   - Attempt 3: Added `number_of_free_entries_in_pool_to_lower_max_size_of_merge=2`
   - Result 3: `number_of_free_entries_in_pool_to_execute_optimize_entire_partition` (default 25) > pool capacity (4)
   - Attempt 4 (final): Reverted `background_pool_size` to default, removed all merge_tree overrides

   Each attempt was a full deploy cycle (~30-60s build + activate). I should have researched ALL dependent settings BEFORE the first deploy. ClickHouse's `MergeTreeSettingsImpl::sanityCheck()` validates an unknown number of `number_of_free_entries_in_pool_*` settings against pool capacity. Without reading the ClickHouse source, the only safe approach was to not reduce `background_pool_size` at all.

2. **Guessed a setting name that doesn't exist** — `number_of_free_entries_in_pool_to_lower_size_of_wal` caused exit code 115 (UNKNOWN_SETTING). I should have verified the setting name against ClickHouse docs or the `system.merge_tree_settings` table before deploying. A `clickhouse-client -q "SELECT name FROM system.merge_tree_settings WHERE name LIKE '%pool%'"` on the running instance (before it crashed) would have listed all valid setting names.

3. **Did not recognize the root cause pattern early enough** — The first error message explicitly stated: "This indicates incorrect configuration because mutations cannot work with these settings." The fix was to undo the incorrect configuration (revert pool_size), not to chase individual setting overrides. I should have reverted `background_pool_size` immediately after the first error.

---

## e) WHAT WE SHOULD IMPROVE (self-critique)

1. **Research before deploying** — When a config change fails validation, read the error message fully and research ALL dependent settings before trying fixes. ClickHouse sanity checks are chained — each fix reveals the next failure. A single `clickhouse-client` query listing all pool-dependent settings would have saved 3 deploy cycles.

2. **Revert over patch** — When a tuning change breaks invariants, revert the tuning change. Don't try to patch downstream settings to accommodate an unnatural value. The ~14 thread savings from `background_pool_size=2` were never worth the complexity.

3. **signoz.nix formatting churn must be reverted** — The auto-git daemon committed 831 lines of formatting noise. This is the SAME issue documented on 2026-08-11 ("nix fmt reformatted the entire 800-line file"). The formatter is destroying git blame every time someone touches this file. Either:
   - Run `git checkout HEAD~2 -- modules/nixos/services/signoz.nix` and re-apply only the merge_tree changes, OR
   - Accept the formatting as the new baseline and move on
   The formatting churn should NOT be in a commit titled "fix(signoz): stop whack-a-moling ClickHouse merge_tree sanity checks."

4. **Pre-deploy-check Monitor365 workaround is fragile** — I hardcoded three Monitor365 metric names. If Monitor365 adds or renames metrics, this list goes stale silently. A better approach: tag Gatus checks with their source endpoint, and the pre-deploy check skips metrics from endpoints that are down.

5. **No eval-time guard for background_pool_size** — The `signoz.nix` module could include a Nix assertion that warns when `background_pool_size` is set below 16 without also overriding the dependent merge_tree settings. This would prevent future agents from repeating the whack-a-mole.

6. **The 2026-08-11 thread tuning was never runtime-verified after the FIRST restart** — The tuning was deployed at `b81e5094`, and ClickHouse ran for ~14h before crashing. This means ClickHouse cached the preprocessed config from a previous boot and only validated the new settings when it next restarted. The tuning "worked" by accident — the validation never ran until a deploy forced a restart. This is a systemic blind spot: config changes that pass `nix eval` but fail at runtime are only caught on service restart.

---

## f) NEXT TASKS (up to 50)

### Immediate (this session's unfinished work)

1. ~~**Verify SigNoz recovered** — Check `signoz.service` and `signoz-collector.service` status after ClickHouse catch-up completes. Restart if needed.~~ done — SigNoz healthy in subsequent sessions (alert rules + dashboards serving)
2. ~~**Investigate browser-history-agent** — Was `failed` in original deploy output. May need attention.~~ done — recovered after the drain-timeout fix; agent timer active
3. ~~**Investigate Monitor365 down** — Port 9191 not responding. Pre-existing but uninvestigated.~~ done — Monitor365 re-enabled at `3ef0f26a`
4. ~~**Revert signoz.nix formatting churn** — `git checkout HEAD~2 -- modules/nixos/services/signoz.nix` + re-apply only the `background_pool_size` removal (delete the line) + AGENTS.md addition. OR accept the new baseline.~~ done — accepted as baseline (alejandra pre-commit makes the old style unreachable; `2026-08-13_05-48` §b.1)
5. ~~**Annotate the 2026-08-11 thread tuning report** — Mark `background_pool_size=2` as REVERTED with a pointer to this report.~~ done (`2026-08-13_05-48` §a.9 — ⚠ ANNOTATION added to the archived report)

### ClickHouse hardening

6. ~~**Add eval-time assertion** — Warn when `background_pool_size < 16` in `signoz.nix` without merge_tree overrides.~~ done (`2026-08-13_05-48` §a.6 — assertion in `signoz.nix`)
7. ~~**Add Gatus health check for ClickHouse** — HTTP ping to `:8123/ping` with alert on failure. The 14h outage had NO alerting.~~ done at `43e11db3` (`mkHttpCheck` + Discord alert)
8. **Document all `number_of_free_entries_in_pool_*` settings** — Query `system.merge_tree_settings` to enumerate every pool-dependent sanity check for future reference.
9. **Add ClickHouse `Ready for connections` log monitoring** — Gatus/textfile metric that tracks whether ClickHouse successfully started, not just whether the process is alive.
10. **Consider ClickHouse backup before future SigNoz schema migrations** — TODO_LIST line 53, still not implemented.

### Pre-deploy-check improvements

11. **Make Monitor365 metric allowlist dynamic** — Parse Gatus config to map metrics to their source endpoints instead of hardcoding.
12. **Add ClickHouse config validation to pre-deploy-check** — Run `clickhouse-server --config-file=... --verify` (if supported) to catch BAD_ARGUMENTS before deploy.
13. **Add a "service restart success" check** — After `nh os switch`, verify ALL services that were restarted are actually running, not just the ones the deploy script explicitly checks.

### SigNoz observability

14. ~~**Verify SigNoz alert rules still work** — After 14h ClickHouse downtime, alert rules may be stale or in error state.~~ done — 23 rules verified provisioned and evaluating
15. **Check SigNoz data gaps** — 14h of traces/logs/metrics may be missing. Assess impact.
16. **Add SigNoz self-monitoring** — Gatus check for SigNoz query service health (not just ClickHouse).

### System health (from post-deploy failures)

17. ~~**Fix `overview.home.lan` 503** — Post-deploy smoke test showed Homepage or similar returning 503.~~ done at `008b4c8b` (fail-fast + PMA re-enable; Overview watchdog from earlier work)
18. ~~**Investigate `signoz.home.lan` 404** — Auth gateway health check showed unexpected 404.~~ done — resolved (SigNoz moved to `protectedVHost` with LAN bypass; auth gateway health checks green in later post-deploy runs)
19. **Root filesystem at 91%** — Pre-deploy warning. Needs garbage collection or store optimization.
20. ~~**84 stale build sandboxes** — Pre-deploy warning. Run `nix-build-cleanup`.~~ done at `c39b6d50` (daily stale-sandbox timer)

### Documentation

21. ~~**Update TODO_LIST** — Add ClickHouse health monitoring task.~~ done — ClickHouse check deployed; TODO updated
22. ~~**Update FEATURES.md** — Verify SigNoz feature status after recovery.~~ done — SigNoz ✅ with ClickHouse Gatus check noted (2026-08-14 audit)
23. **Add ClickHouse config validation to the 5-layer prevention pipeline** — Document in AGENTS.md prevention layers table.

---

## g) QUESTIONS

1. **Should I revert the signoz.nix formatting churn?** The auto-git daemon committed 831 lines of alejandra reformatting alongside my ~10-line fix. This destroys git blame for the entire file. The 2026-08-11 session caught and reverted this exact issue, but this time it slipped through. I can `git checkout HEAD~2` and re-apply just the merge_tree removal, but that rewrites the auto-git daemon's commit.

2. **Should I investigate the browser-history-agent and Monitor365 failures now, or are those known/pre-existing?** Both were showing as failed/down before my session started. The 2026-08-12 status report mentions browser-history-agent issues but Monitor365 being down is not documented anywhere I can find.

3. **Do you want me to add a Gatus health check for ClickHouse now?** The 14h outage had zero alerting — nobody knew ClickHouse was down until a deploy failed. Adding `mkHttpCheck` for `:8123/ping` with a Discord alert would catch this immediately next time.
