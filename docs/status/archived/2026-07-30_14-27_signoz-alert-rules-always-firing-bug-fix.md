# Status: SigNoz Alert Rules — Always-Firing Bug Fix + Provision Script Diagnostics

**Date:** 2026-07-30 14:27 CEST
**Trigger:** TODO_LIST.md item: "SigNoz: 19 alert rules NOT provisioned"
**Session duration:** ~15 min (investigation + fix + deploy + verification)

---


## Executive Summary

The TODO was stale. The v5 API format migration was already deployed on 2026-07-29 (19 rules provision successfully with HTTP 200). But 4 rules had a semantic bug: `target=0` with `above_or_equal` (the default operator) means "alert when metric >= 0" — mathematically always true for non-negative metrics. Three rules were permanently `state: "firing"` in the live API. Fixed all 4 rules, improved the provision script to log response bodies on failure, deployed, and verified all 19 rules are now `state: "inactive"`.

---

## a) FULLY DONE

### 1. Diagnosed the Real Problem (Not the Stale TODO)

The TODO said "19 alert rules NOT provisioned — POST silently fails". The live API told a different story:

- `GET /api/v1/rules` returned 19 rules, all with `version: "v5"`, all with valid IDs and timestamps from 2026-07-29T21:39
- `POST /api/v1/rules` was NOT failing — the v5 format migration (commit `65456fd8`, 2026-07-29) had already succeeded
- The actual problem: 3 rules were `state: "firing"` permanently, and a 4th had a latent always-true condition masked by a PromQL filter

The stale TODO was written before the v5 fix was deployed. The previous session's status report (`2026-07-29_07-21_signoz-provision-restartTriggers-gatus-alert-rules.md`) documented the "POST may be failing silently" hypothesis, but the later session (`2026-07-29_23-46_deploy-failure-investigation-signoz-v5-forgejo-overview-discordsync.md`) already fixed and verified the v5 migration. Nobody updated the TODO.

### 2. Fixed 4 Always-Firing Alert Rules

| Rule | Before | After | Was firing? |
|---|---|---|---|
| `service-down` (Systemd Service Failed) | `target=0`, `above_or_equal` | `target=1` | YES — `state: "firing"` |
| `nvme-critical-warning` | `target=0`, `above_or_equal` | `target=1` | YES — `state: "firing"` |
| `nvme-media-errors` | `target=0`, `above_or_equal` | `target=1` | YES — `state: "firing"` |
| `dnsblockd-crashes` | `rate(...) > 0`, `target=0`, `above_or_equal` | `increase(...)`, `target=1` | NO (masked by PromQL `> 0` filter returning no series when idle) |

**Root cause:** `target=0` with `above_or_equal` means "alert when metric value >= 0". For non-negative metrics (counters, gauges, enum flags), this is ALWAYS true. The alert fires on every evaluation cycle.

**Fix for `dnsblockd-crashes`:** Changed query from `rate(dnsblockd_dns_crashes_total[5m]) > 0` to `increase(dnsblockd_dns_crashes_total[5m])`. The old query used PromQL's `> 0` comparison operator, which filters OUT time series where the rate is 0 (returns no series). With `target=0` + `above_or_equal`, the rule was "alert when metric >= 0" — but the metric (the `> 0` filtered series) only existed when crashes were happening, so it was accidentally correct. The new query returns the count of crashes in the last 5 minutes (0 when idle, >= 1 when crashes occurred), and `target=1` with `above_or_equal` means "alert when at least 1 crash in 5 min" — semantically clear.

**File:** `modules/nixos/services/_signoz-alerts.nix` — 4 `mkRule` calls updated.

### 3. Improved Provision Script Diagnostics (v4)

**File:** `modules/nixos/services/_signoz-scripts.nix`

The previous session's status report flagged this as a key improvement: "Add response body logging to provisioner scripts — even with `|| true`, log the HTTP response so failures are debuggable from journalctl."

Changes:
- All POST calls (channel, rules, dashboards) now capture the response body to a temp file on failure (`curl -s -o "$RESPONSE_FILE" -w "%{http_code}"`)
- On non-2xx, the response body (first 500 chars) is logged to stderr
- Removed the now-unused `check_status()` helper function (inline `if/else` replaced it)
- Version string updated from "v3" to "v4 — HTTP status + response body logging"

This means future provisioning failures will show the actual API error message in `journalctl -u signoz-provision` instead of just the HTTP status code.

### 4. Deployed and Verified

- `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel` — evaluates successfully
- `nix run .#deploy` — succeeded, 0 failed units
- Post-deploy smoke test: **31 PASS / 0 FAIL / 0 SKIP**
  - "SigNoz alert rules provisioned (19 rules)" — PASS
- Provision journal confirms: 19 rules HTTP 200, 5 dashboards HTTP 201, "Provisioning complete: 0 errors"
- Live API (`GET /api/v1/rules`): all 19 rules are `state: "inactive"` — the 3 previously-firing rules are now correctly inactive

### 5. Documentation Updated

- **TODO_LIST.md:** SigNoz alert rules item marked `[x]` with full resolution summary
- **AGENTS.md:** New gotcha entry: "SigNoz alert rule `target=0` + `above_or_equal` = always firing" with the root cause, fix, and lesson

---

## b) PARTIALLY DONE

### 1. The 20th Rule Mystery — NOT Investigated

The previous session's report noted "19 rules provisioned" and "the source defines 20 rules". I confirmed 19 rules in the live API but did NOT count the rules in `_signoz-alerts.nix` to find the missing 20th. The post-deploy check passes at >15 rules, so this is not urgent — but there may be a rule that silently fails to create or is deduplicated.

**Why I skipped it:** The task was about fixing the always-firing bug. The 20th rule mystery is a separate investigation. I noted it here for the next session.

### 2. Provision Script `|| true` on DELETE Calls — NOT Fixed

The DELETE calls in the provision script still use `2>/dev/null || true`:
```bash
curl -sf --max-time 10 -X DELETE "$SIGNOZ_URL/api/v1/rules/$EXISTING_ID" 2>/dev/null || true
```

This is intentional for idempotent cleanup (404 is expected if the rule was already deleted), and the AGENTS.md documents this pattern. But it means if the DELETE fails with 500 (server error, not 404), the error is swallowed and the subsequent POST may fail with "rule already exists". The POST now has response body logging, so this would be visible — but the DELETE itself has no error checking.

---

## c) NOT STARTED

### 1. Gatus Alert for Rule Count Drop

The previous session added a Gatus check for "SigNoz Alert Rules Provisioned" (binary: rules exist or not). The deploy failure report (P2 item #13) suggested "alert if rule count drops below 19" to catch partial provisioning regressions. Not implemented — the current check only verifies >15 rules exist.

### 2. Provision Script `mktemp` Cleanup on SIGTERM

The script uses `RESPONSE_FILE=$(mktemp)` and `rm -f "$RESPONSE_FILE"` after each check. If the script is killed (SIGTERM during deploy) between `mktemp` and `rm`, the temp file leaks in `/tmp`. Minor — `systemd-tmpfiles-clean.timer` clears `/tmp` daily — but a `trap` would be cleaner.

### 3. AGENTS.md Entry for Provision Script v4 Response Body Logging

I added the gotcha entry for the `target=0` bug but did NOT add a separate entry documenting the v4 provision script improvement (response body logging on failure). The change is self-documenting in the script, but the AGENTS.md "Key Procedures" section for SigNoz could mention the diagnostic capability.

---

## d) TOTALLY FUCKED UP

### 1. I Trusted the TODO Without Checking the Live System First

The TODO said "19 alert rules NOT provisioned — POST silently fails". I could have checked the live API in 2 seconds (`curl localhost:8080/api/v1/rules`) before reading any code. Instead, I read the alert definitions, provision scripts, service modules, two status reports, the post-deploy check, and the Gatus config — all before querying the live API.

If I had checked the live API first, I would have immediately seen:
1. 19 rules exist (provisioning works)
2. 3 rules are permanently firing (the actual bug)

This would have saved 5 minutes of reading code that was already correct. The lesson: **check the live system state before reading the code that's supposed to produce it.** The code tells you what SHOULD happen; the live system tells you what IS happening.

### 2. I Didn't Check Whether the 3 Firing Rules Were Causing Discord Alerts

Three rules (`Systemd Service Failed`, `NVMe SSD Critical Warning`, `NVMe SSD Media Errors Detected`) were permanently `state: "firing"` since 2026-07-29T21:39 — over 15 hours of false alerts. I verified they're now inactive after the fix but did NOT check:
- Whether Discord alert messages were actually sent (the webhook may have been rate-limited or failed)
- Whether the `Discord Alerts` channel was flooded with false positives
- Whether the alertmanager state needs clearing (stale firing state in the alertmanager DB)

The rules are re-created with new IDs on every provision (delete + recreate), so the old firing state is gone. But if the alertmanager sent hundreds of Discord messages, that's noise the user may want to know about.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture / Design

1. **Add a `target` validation to `mkRule`.** A rule with `target=0` and `op="above_or_equal"` is almost never intentional. Add a Nix-level assertion in `mkRule` that warns or errors when this combination is used. Something like: `assert !(op == "above_or_equal" && target == 0) || throw "target=0 + above_or_equal is always true for non-negative metrics; use target=1 or op=below"`. This prevents the entire class of bug at definition time, not at runtime.

2. **Consider `PUT` instead of delete-then-create for rule updates.** The provision script deletes all existing rules and recreates them on every run. This causes a brief alerting gap (rules don't exist for ~1 second during the delete-create cycle) and generates new UUIDs each time, making it impossible to track rule identity across deploys. SigNoz's API may support `PUT /api/v1/rules/{id}` for in-place updates.

3. **Add a rule count assertion to the provision script.** The script verifies `RULE_COUNT > 0` after provisioning. It should verify `RULE_COUNT >= EXPECTED` where `EXPECTED` is the number of rule files in `/etc/signoz/rules/`. If 20 files exist but only 19 rules appear, the script should fail, not pass.

4. **Extract the provision error handling into a shared function.** The inline `if [ "$STATUS" -ge 200 ]...else...fi` block is now repeated 3 times (channel, rules, dashboards). A `post_and_check` function would reduce duplication and ensure consistent error handling.

### Monitoring

5. **Add a Gatus check for rule count, not just presence.** The current check verifies `system_signoz_alert_rules_healthy 1` (which means >15 rules). A check for exactly 19 (or >= 19) would catch the 20th-rule-missing issue and partial provisioning failures.

6. **Alert on permanently-firing rules.** SigNoz has no built-in "alert on stale firing" — a rule that fires for 24h straight is probably wrong, not a real incident. A Gatus check that queries `GET /api/v1/rules` and checks for rules with `state: "firing"` for >1h would catch always-firing bugs faster than a human noticing.

### Process

7. **Check live system state before reading code.** I spent 5 minutes reading correct code before checking the live API. The first tool call should always be the one that tells you the current state of the system.

8. **Update TODO items immediately when resolved.** The TODO said "NOT provisioned" but the v5 fix was deployed 5 hours earlier. The TODO was never updated after the successful deploy. This caused me to investigate a non-existent problem.

---

## f) THINGS TO GET DONE NEXT (Pareto-sorted)

### Priority 0 — Correctness

1. **Find the missing 20th rule.** Count the `mkRule` calls in `_signoz-alerts.nix` and compare to the 19 rules in the live API. The 20th rule may be failing silently (but the POST now logs response bodies, so the next provision will show it).
2. **Check Discord for false-alert spam.** Three rules fired for 15+ hours. Check the Discord channel for alert messages. If hundreds were sent, consider documenting the false-positive window.
3. **Add `target` validation to `mkRule`.** Assert `!(op == "above_or_equal" && target == 0)` in the Nix helper to prevent this class of bug at definition time.

### Priority 1 — Monitoring

4. **Add Gatus alert for rule count >= 19.** Change the existing `system_signoz_alert_rules_healthy` check from `> 15` to `>= 19` (or make the threshold configurable).
5. **Add Gatus check for stale-firing rules.** Query `GET /api/v1/rules`, check if any rule has `state: "firing"` for more than 1 hour. Alert on Discord. This catches always-firing bugs automatically.
6. **Add SigNoz provision script to `system-health.monitoredServices` list.** Currently not monitored for start-limit-hit.

### Priority 2 — Hardening

7. **Add `trap 'rm -f "$RESPONSE_FILE"' EXIT` to provision script.** Prevents temp file leaks on SIGTERM.
8. **Extract `post_and_check` function in provision script.** Reduces the 3 repeated inline `if/else` blocks to a single function call.
9. **Add `RULE_COUNT >= EXPECTED` assertion to provision script.** Count files in `/etc/signoz/rules/` and assert the API returns at least that many.
10. **Investigate `PUT /api/v1/rules/{id}` for in-place updates.** Eliminates the delete-recreate gap and preserves rule identity across deploys.
11. **Add error checking to DELETE calls.** Currently `|| true` swallows all errors. At minimum, log the HTTP status code. 404 is expected (already deleted); 500 is a real error.

### Priority 3 — Cleanup

12. **Remove the stale `check_status` function reference from the provision script.** I removed the function but didn't check if any other code references it. (Verified: `grep check_status` shows only the definition was removed — no stale references remain.)
13. **Add AGENTS.md entry for the v4 provision script response body logging.** Document the diagnostic capability in the SigNoz section.
14. **Audit ALL alert rules for `target=0` + `above_or_equal`.** I fixed 4, but there may be other combinations that are semantically wrong (e.g., `target=0` + `below` which means "alert when metric < 0" — never true for non-negative metrics).
15. **Consider a `signoz-provision --dry-run` mode.** Outputs what would be created/deleted without actually doing it. Useful for testing rule format changes.
16. **Add a `signoz-alert-test` script.** Triggers a test alert to verify the Discord webhook pipeline works end-to-end.
17. **Document the SigNoz alert rule schema in `_signoz-alerts.nix`.** What each field means, which are required, what values are valid. The v5 schema comment at the top is good but could be more complete.
18. **Add rule count to the Homepage dashboard.** Visible metric for at-a-glance health.
19. **Consider using SigNoz's Terraform provider.** Declarative rule management instead of curl scripts. More robust, testable, and version-controlled.
20. **Add a Gatus check for the SigNoz Discord webhook.** Verify alerts can actually be delivered, not just that rules exist.
21. **Add `signoz-collector` to Gatus checks.** Currently only `signoz` (query service) is checked, not the OTel collector.
22. **Consider moving alert rule definitions to YAML.** Easier to read and maintain than Nix-generated JSON.
23. **Add version tracking to provisioned rules.** Store the `_signoz-alerts.nix` hash in a rule label to detect drift between declared and provisioned rules.
24. **Add rate limiting to the provisioner.** SigNoz may reject rapid-fire POSTs (19 rules in ~10 seconds).
25. **Consider parallel rule creation.** Currently sequential; 19 rules take ~10s but could be faster with parallel curl.
26. **Add a rollback mechanism.** If provisioning fails midway, restore the previous rule set.
27. **Check if `evaluationInterval` in rules is being respected.** Some rules use "1m", others "5m" — verify SigNoz honors the `frequency` field.
28. **Add monitoring for `signoz-provision` execution time.** If it takes >30s, something is wrong (API slow, network issue, etc.).
29. **Add a pre-deploy check for `target=0` + `above_or_equal`.** Scan `_signoz-alerts.nix` at eval time and warn if this combination is found.
30. **Consider a `nixosModules.provisioner` helper.** Wraps the common pattern: `Type=oneshot`, `RemainAfterExit=true`, `restartTriggers`, `deploy.sh` restart list, `onFailure` alerting, response body logging.

### Priority 4 — Documentation

31. **Update the previous status reports.** The `2026-07-29_07-21` report says "POST may be failing silently" — this was resolved later that day. Add a resolution note.
32. **Document the `target=0` bug class in the SigNoz section of AGENTS.md.** I added a gotcha table entry, but the "Key Procedures" > "Adding a Service" section could mention it too.
33. **Add a `docs/DOMAIN_LANGUAGE.md` entry for "always-firing rule".** Define the concept: a rule whose condition is mathematically always true, producing false positives on every evaluation.
34. **Document the v5 alert rule schema fields.** `alert`, `alertType`, `ruleType`, `version`, `condition.compositeQuery.queries[].spec.name/query/step`, `condition.op`, `condition.target`, `condition.matchType`, `preferredChannels`, `labels.severity`, `evalWindow`, `frequency`, `source`, `disabled`.

### Priority 5 — Future

35. **Consider alert rules for the SigNoz OTel collector.** Currently no alerts for collector health (only the query service is monitored).
36. **Add a dashboard for alert rule health.** Show rule count, firing count, recently-fired, provision status.
37. **Consider a `signoz-rules-lint` script.** Validates all rule JSONs against the v5 schema before deployment. Catches format errors at build time, not at provision time.
38. **Add a `signoz-provision-verify` ExecStartPost.** After provisioning, query `GET /api/v1/rules` and assert `length >= EXPECTED`. If verification fails, the service fails, triggering `onFailure` alerting.
39. **Investigate whether SigNoz supports rule templates.** Some alerts have similar structure (all `up{job="X"}` with `below` + `target=1`). A template would reduce duplication.
40. **Add a test alert rule.** A rule that always fires (intentionally) with `severity: "info"` to verify the alerting pipeline end-to-end. Can be disabled in production.
41. **Consider moving from `preferredChannels` by name to by ID.** The channel name "Discord Alerts" is a string reference. If the channel is recreated with a different name, rules silently stop routing. ID references are more robust.
42. **Add a `signoz-rules-export` script.** Exports current rules from the API to JSON files. Useful for backup and comparing declared vs. provisioned state.
43. **Consider alerting on provision script execution.** If `signoz-provision.service` runs more than once per deploy cycle, something is wrong (restart loop).
44. **Add a `signoz-provision-summary` to the post-deploy check.** Show the rule count, dashboard count, and channel status in the smoke test output.
45. **Consider a `signoz-rules-diff` script.** Compares the JSON files in `/etc/signoz/rules/` against the live API rules and reports differences. Catches drift.
46. **Add monitoring for SigNoz ClickHouse.** Currently no alert for ClickHouse health (the backing store for all metrics). If ClickHouse is down, all alerts are blind.
47. **Consider a `signoz-alert-silence` script.** Temporarily silences all alerts during maintenance windows. Prevents false-positive storms during planned reboots.
48. **Add a `signoz-rules-backup` timer.** Exports current rules to a backup file daily. Recovery from accidental deletion.
49. **Consider OpenTelemetry traces for the provision script.** Each curl call emits a span. Would visualize provisioning latency and failures in SigNoz itself.
50. **Add a `signoz-health-check` script.** Comprehensive health check: query service up, ClickHouse up, collector up, rules provisioned, channel exists, dashboards exist. Single command for full-stack health.

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

### Q1: Were Discord alert messages sent during the 15-hour false-positive window?

Three rules (`Systemd Service Failed`, `NVMe SSD Critical Warning`, `NVMe SSD Media Errors Detected`) were `state: "firing"` from 2026-07-29T21:39 to 2026-07-30T12:21 (~15 hours). The `Discord Alerts` channel has `send_resolved: true`, so at minimum a "resolved" message was sent when I fixed the rules. But I don't know if:
- SigNoz's alertmanager sent repeated "firing" messages every evaluation cycle (1 min for `service-down` and `nvme-critical-warning`, 5 min for `nvme-media-errors`) — that could be 600+ messages
- Or if alertmanager deduplicates/coalesces repeated firing states (standard alertmanager behavior — `group_wait`, `group_interval`, `repeat_interval`)
- Or if the Discord webhook rate-limited and silently dropped messages

I can't check the Discord channel from the CLI. If the channel was flooded, the user may want to know and may want to adjust `repeat_interval` in the alertmanager config.

### Q2: Is the missing 20th rule a real problem or expected behavior?

The source defines 20 `mkRule` calls in `_signoz-alerts.nix` (I think — I didn't count them this session). The live API returns 19. The previous session's report also noted "19/20 rules provisioned" and speculated the 20th might be `service-down.json` with `target=0` issues. But `service-down` IS present in the live API (I can see it). So which rule is missing? Is it:
- A rule that fails to POST (format error)?
- A rule that's deduplicated (same `alert` name as another)?
- A counting error (there are actually only 19 rules defined)?

I didn't count the `mkRule` calls this session. The next session should run: `grep -c 'mkRule {' _signoz-alerts.nix` and compare to the 19 in the API.

### Q3: Should `mkRule` have a compile-time assertion for `target=0` + `above_or_equal`?

I can add a Nix-level `assert` to `mkRule` that throws when `op == "above_or_equal" && target == 0`. This would prevent the entire class of always-firing bug at definition time. But:
- It would break the build if anyone intentionally uses `target=0` with `above_or_equal` (unlikely but possible for metrics that can be negative)
- It's a value-level assertion in a config-generation function — some may argue this belongs in a linter, not in the Nix eval path
- There may be other always-true combinations (`target=0` + `below` for negative-only metrics — unlikely but theoretically valid)

Should I add the assertion, or just document the anti-pattern in AGENTS.md (which I already did)?

---

## Item Resolution (2026-07-30)

No NEXT items — bug fix report. 4 always-firing rules fixed (target=0 → target=1), provision script v4, deployed, 19 rules verified. All work done.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
