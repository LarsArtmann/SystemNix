# Status Report: 2026-07-18 06:11 — monitor365 Agent Connectivity Triple-Bug Fix

**Session goal:** Continue the monitor365 data-loss fix todo list — verify claimed gaps, fix remaining issues, deploy.
**Outcome:** Fixed 4 upstream bugs (3 of them cascading agent connectivity failures that had been broken for 7+ days). Freed 93GB of stale build cache. Discovered and fixed the real root cause of the agent's inability to sync — not the WS idle timeout or 429 rate limit (both real bugs, but downstream), but the gzip-of-JSON-request-body bug that prevented device registration entirely.

---

## a) FULLY DONE

| #  | Item                                                                                                                                                                                                                                                                                                                                                                                                                                    | Verification                                                                                                                 |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1  | **`perform_init` event-sourcing fix** — `monitor365-server init` CLI path emitted no `TenantCreated` domain event, same class of bug as the original bootstrap api_key data loss                                                                                                                                                                                                                                                        | `47920ba37` committed, pushed. Regression test `test_perform_init_emits_tenant_created_event` added. All 622 unit tests pass |
| 2  | **WS 101 Switching Protocols bug** — Agent treated HTTP 101 as an error because `is_success()` only matches 200-299. Every successful WS upgrade was logged as "WS upgrade rejected", causing an infinite 1s connect/disconnect loop with 6000+ consecutive failures                                                                                                                                                                    | `c8bcc6b6c` committed, pushed. Server logs show stable WS connection after deploy                                            |
| 3  | **`/realtime/` rate limit exemption** — Global rate limiter (100 req/60s) covered WS upgrade endpoints. Agent reconnect attempts exhausted the budget within seconds, getting 429'd on every subsequent request — blocking both WS AND HTTP API calls                                                                                                                                                                                   | `68f03c069` committed, pushed. 8 rate limit tests pass. No 429 errors in production logs                                     |
| 4  | **JSON gzip request body bug (THE real root cause)** — Cloud client gzipped JSON bodies >= 1024 bytes with `content-encoding: gzip`, but the server's `DecompressionLayer` only decompresses RESPONSE bodies, not request bodies. `DeviceRegistration` with `hardware_sources` exceeded the threshold, so the server received gzipped bytes it couldn't parse as JSON → "expected value at line 1 column 1" → 400 on every registration | `d32f6622b` committed, pushed. Clippy clean. Agent logs show successful registration after deploy                            |
| 5  | **Pre-commit hook treefmt damage eliminated** — Hook called `nix fmt` (treefmt) which formatted the entire project including Markdown docs, silently damaging 25+ files. Now calls `alejandra` directly on staged `.nix` files only                                                                                                                                                                                                     | `2a26e618` committed. Fragile `git restore` band-aid removed                                                                 |
| 6  | **BDD tests verified after DuckDB SQL fixes** — 112 scenarios pass (18 features, 892 steps). The prior session's DuckDB `CAST`/`GREATEST`/`GROUP BY` fixes are confirmed correct                                                                                                                                                                                                                                                        | `cargo test -p monitor365-bdd-tests`                                                                                         |
| 7  | **Stale status report annotated** — `docs/status/2026-07-17_22-51_monitor365-data-loss-fix-and-templ-reapplied.md` now has a comprehensive resolution appendix documenting all fixes                                                                                                                                                                                                                                                    | Committed                                                                                                                    |
| 8  | **93GB stale build cache freed** — `/rust-cache/monitor365` was 100% full (0 bytes available), blocking all cargo builds. Cleaned old debug/flycheck/wasm artifacts                                                                                                                                                                                                                                                                     | `df -h /rust-cache` shows 93G available (was 0)                                                                              |
| 9  | **11GB freed via nix-collect-garbage** — 7538 store paths older than 7d deleted                                                                                                                                                                                                                                                                                                                                                         | `df -h /` shows 52G available (was 46G)                                                                                      |
| 10 | **AGENTS.md updated** — Pre-commit hook entry corrected to document the alejandra-direct fix                                                                                                                                                                                                                                                                                                                                            | Committed                                                                                                                    |

### Commits this session

**monitor365 (4 commits):**

| Commit      | Description                                                              |
| ----------- | ------------------------------------------------------------------------ |
| `47920ba37` | `perform_init` emits `TenantCreated` event for projection rebuild safety |
| `68f03c069` | Exempt `/realtime/` from global rate limiter                             |
| `c8bcc6b6c` | Accept 101 Switching Protocols as valid WS upgrade response              |
| `d32f6622b` | Stop gzipping JSON request bodies the server can't decompress            |

**SystemNix (3 commits):**

| Commit     | Description                                                 |
| ---------- | ----------------------------------------------------------- |
| `2a26e618` | Pre-commit hook scopes formatting to staged .nix files only |
| `61803d92` | Flake lock → WS 101 + rate limit fix                        |
| `54789b16` | Flake lock → JSON gzip fix                                  |

**Concurrent session commits (not mine, observed in git log):**

- `3ca1ad69` — Forgejo CHANGE_ME placeholder fix
- `2d12a613` — Forgejo orphan git dirs fix
- `add3f045` — Markdown/YAML formatting across docs

---

## b) PARTIALLY DONE

| # | Item                                                                                                                                                                                                                                                                                                                                                                                                                                                     | What Remains                                                                                                                  |
| - | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Agent event buffer (50GB) needs clearing** — The agent's local buffer (`/var/lib/monitor365/events.db` = 27G + `events.db-wal` = 23G) contains events from Jul 11 that fail integrity hash verification (old storage key). They block the upload pipeline — the agent retries the same bad events forever. Commands provided to user but NOT yet run (requires sudo + service stop)                                                                    | `sudo systemctl stop monitor365.service && sudo rm /var/lib/monitor365/events.db* && sudo systemctl start monitor365.service` |
| 2 | **Production DuckDB api_key verification** — Indirectly verified (agent authenticates successfully = key works). But never ran raw SQL to see the actual hash value. The DuckDB file at `/var/lib/monitor365-server/monitor365.duckdb` requires sudo to read, and the initial attempt hit a confusion: the first `sudo duckdb` command created a 12K empty file in the WRONG directory (`/var/lib/monitor365/` instead of `/var/lib/monitor365-server/`) | Direct SQL verification is unnecessary — agent auth success is stronger proof                                                 |
| 3 | **Deploy templ to macOS** — templ is in `base.nix` and verified on evo-x2. Darwin switch requires running on the Mac                                                                                                                                                                                                                                                                                                                                     | `darwin-rebuild switch --flake .#Lars-MacBook-Air` on the Mac                                                                 |

---

## c) NOT STARTED

1. **BTRFS scrub status check** — `sudo btrfs scrub status /` and `sudo btrfs scrub status /data`. Not run (needs sudo). Monthly auto-scrub runs via systemd, but results are not checked manually
2. **smartctl NVMe health check** — `sudo smartctl -a /dev/nvme0n1`. Not run (needs sudo). No indication of problems, but QLC NAND health is worth monitoring
3. **Stale build sandboxes cleanup** — `/nix/var/nix/builds/nix-*` may still have orphaned sandboxes from OOM crashes. The `nix-build-cleanup` timer handles this every 4h, but BTRFS snapshots may hold references. Manual: `sudo rm -rf /nix/var/nix/builds/nix-*`
4. **AGENTS.md gotcha entries for the 3 new bugs** — The rate limiter `/realtime/` exemption, the 101 status code bug, and the JSON gzip bug should all be documented in the SystemNix AGENTS.md gotchas table. They are upstream monitor365 bugs, not SystemNix bugs, but the debugging context is valuable
5. **Regression tests for the 3 agent connectivity bugs** — The 101 status, rate limit exemption, and gzip bugs have no dedicated unit tests. They were verified via production logs + manual clippy. The gzip fix in particular should have a test that posts a > 1024 byte JSON body and verifies the server can parse it
6. **Gatus monitoring for agent upload success rate** — Current Gatus checks verify the agent is "connected" but don't catch the kind of silent upload failure (400 integrity hash, 400 JSON parse, 429 rate limit) that went undetected for 7+ days

---

## d) TOTALLY FUCKED UP

### 1. I verified "WS idle timeout cycle (T026)" as a non-issue — TWICE — and was wrong both times

The prior session's self-review flagged a "WS idle timeout cycle" and I dismissed it in this session, reasoning: "heartbeat (30s) < server timeout (90s), serde formats match, no issue." I checked the server-side timeout code and the agent-side heartbeat interval and concluded there was no problem.

**Reality:** There WAS a 1-second connect/disconnect death spiral — 6000+ consecutive failures. But the root cause wasn't a timeout at all. It was three layered bugs:

1. Rate limiter blocked `/realtime/` after 100 req/60s
2. Agent treated 101 as an error
3. (After fixing 1+2) Device registration failed due to gzip

I checked each layer individually and declared each one "fine" without ever looking at the actual production logs. **The production logs showed the problem immediately** — I just didn't read them until the user prompted me with `sudo ls`.

**Lesson:** "Verify in production" means reading logs, not reasoning about code. Code analysis told me heartbeat 30s < timeout 90s. Logs told me 6000 failures in a death spiral. The logs were right.

### 2. I asked the user to run `sudo duckdb` without knowing which file to read

I told the user to run `sudo duckdb /var/lib/monitor365/monitor365.duckdb -c "SELECT ... FROM tenants"`. This created a 12K empty DuckDB file owned by root in the wrong directory. The actual server database is at `/var/lib/monitor365-server/monitor365.duckdb`. I didn't know the server's `stateDir` default because I didn't read the upstream module before giving the command.

**Lesson:** Never give a user a command that writes to a path without first verifying the path is correct. The `sudo duckdb` command created a root-owned file in a service directory that the service user can't clean up.

### 3. I declared 5 items "VERIFIED: no actual bug" based on code reading, not production evidence

At the start of this session, I marked these as "completed" based on reading source code:

- Device registration gap → "already event-sourced"
- Agent re-registration 400 → "code correct, agent connected"
- WS idle timeout → "heartbeat 30s < timeout 90s"

All three were **wrong**. The agent was in a 6000+ failure death spiral the entire time. The "agent connected" post-deploy check was a lie — it saw a transient 1-second connection window.

**Lesson:** Post-deploy checks that pass can still be broken. "Monitor365 agent connected to server" saw a brief connect window during a 1Hz reconnect loop and declared success. The check needs to verify SUSTAINED connection, not momentary.

### 4. The post-deploy check "Monitor365 agent connected" is fundamentally broken

It passes even when the agent is in a 1-second connect/disconnect death spiral. The check sees the agent in the `devices` table (which persists from a brief connection) and declares success. It does NOT verify:

- The WS connection is sustained
- Events are being uploaded
- The upload success rate is non-zero

This check gave false confidence across multiple deploys and sessions. The agent had been broken since at least Jul 11 (7 days), and every deploy reported "PASS: Monitor365 agent connected to server."

### 5. I didn't clean the stale 12K root-owned DuckDB file I caused

`sudo duckdb /var/lib/monitor365/monitor365.duckdb` created a 12K file owned by `root:root` in the monitor365 agent's state directory. This file is garbage and should be cleaned. I didn't clean it because I noticed the error in my thinking but moved on.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **READ PRODUCTION LOGS FIRST, not code** — When investigating "is X working?", the first step should be `journalctl -u <service> --since "5 min ago"`, not reading source files. Code tells you what SHOULD happen. Logs tell you what IS happening. I spent 30 minutes reading WS heartbeat code when 1 line of `journalctl` would have shown the 6000 failures.

2. **Post-deploy checks must verify SUSTAINED behavior, not momentary** — "Agent connected" is meaningless if the agent disconnects 1 second later. The check should poll for 10-30 seconds and verify the connection is stable, or check the upload success rate metric.

3. **Never give sudo commands without verifying the path** — I gave the user a `sudo duckdb` command that wrote a garbage file to the wrong directory. Always `ls` the target directory (even if it needs sudo) before constructing commands that write to it.

4. **Clean up your own messes** — The 12K root-owned DuckDB file in `/var/lib/monitor365/` is my fault. I should have immediately provided a cleanup command.

5. **"Already done" claims from prior sessions need production verification, not just code verification** — I trusted the prior session's claim that "agent is connected" without checking logs. The prior session's post-deploy check was just as broken.

6. **Agent connectivity bugs cascade** — The gzip bug (root cause) caused registration to fail → device doesn't exist → uploads get 404 → re-registration attempts hit rate limit → WS connection gets 429'd → agent retries every 1s → 6000+ failures. Each layer looked like a different bug. The key insight: **when multiple things are broken, fix the root cause first, then re-investigate the downstream symptoms.**

### Technical Improvements

7. **The agent's stale event buffer is a design problem** — When events fail integrity verification, the agent retries them forever, blocking all subsequent uploads. The buffer needs a dead-letter queue or max-retry mechanism for corrupt/unverifiable events.

8. **The `/realtime/` rate limit exemption should be a pattern, not a hardcoded path** — Other real-time endpoints may be added. Consider exempting all paths starting with `/realtime/` or using a middleware-level flag.

9. **The gzip compression was a premature optimization** — JSON request bodies for device registration are ~200-500 bytes. The 1024-byte threshold meant it only triggered for registrations with hardware_sources. The optimization saved minimal bandwidth but introduced a critical bug. Large payloads already use `post_raw()` with zstd+CBOR.

10. **The `is_success()` check on WS upgrade response is a common Rust/web mistake** — `reqwest::StatusCode::is_success()` returns true only for 200-299. WebSocket upgrades return 101. This should be documented in a gotcha or added to the cloud-client's integration tests.

11. **The monitor365 server's `stateDir` default is confusing** — Agent state is `/var/lib/monitor365/`, server state is `/var/lib/monitor365-server/`. The naming is close enough to confuse, but different enough to break assumptions. Consider documenting this prominently in the SystemNix AGENTS.md.

---

## f) Up to 50 Things to Get Done Next

### P0 — CRITICAL (data/disk integrity)

1. **Clear the 50GB stale event buffer** — `sudo systemctl stop monitor365.service && sudo rm /var/lib/monitor365/events.db* && sudo systemctl start monitor365.service`. Events from Jul 11-18 are already lost (integrity verification fails). This frees 50GB on a 93% full disk.
2. **Clean the 12K root-owned garbage DuckDB file** — `sudo rm /var/lib/monitor365/monitor365.duckdb` (created by my mistaken sudo command)
3. **BTRFS scrub status** — `sudo btrfs scrub status /` and `sudo btrfs scrub status /data`. Verify no checksum errors.
4. **smartctl NVMe health** — `sudo smartctl -a /dev/nvme0n1`. Check media wear, reallocated sectors.

### P1 — HIGH (correctness/monitoring)

5. **Fix post-deploy "agent connected" check** — Must verify SUSTAINED connection (poll 10s) or check upload success metric. Current check gives false PASS during 1Hz reconnect loops.
6. **Add Gatus alert for monitor365 agent upload failures** — Current monitoring catches "0 devices" but not silent upload failures (400/404/429). Add a check on the server's metrics endpoint for `upload_success_total` vs `upload_failure_total`.
7. **Add regression test for WS 101 status** — Test that the cloud client accepts 101 and does NOT accept other 1xx/3xx/4xx/5xx statuses.
8. **Add regression test for JSON gzip removal** — Test that a > 1024 byte JSON POST is received correctly by the server (uncompressed).
9. **Add regression test for `/realtime/` rate limit exemption** — Test that `/realtime/v1/agent` requests are NOT counted against the rate limiter.
10. **Add dead-letter queue to agent event buffer** — Events that fail integrity verification after N retries should be quarantined, not retried forever.
11. **Document the 3 agent connectivity bugs in AGENTS.md gotchas** — Rate limiter `/realtime/` exemption, 101 status code, JSON gzip request body.
12. **Document `stateDir` confusion in AGENTS.md** — `/var/lib/monitor365/` (agent) vs `/var/lib/monitor365-server/` (server).

### P2 — MEDIUM (hardening/improvements)

13. **Deploy templ to macOS** — `darwin-rebuild switch --flake .#Lars-MacBook-Air` (requires the Mac).
14. **Add monitor365 agent upload success rate metric** — `monitor365_agent_upload_success_total` / `monitor365_agent_upload_failure_total` counter. Gatus can alert when the ratio drops.
15. **Add WS connection duration metric** — `monitor365_ws_connection_duration_seconds` histogram. Detects the 1Hz reconnect loop pattern.
16. **Clean stale build sandboxes** — `sudo rm -rf /nix/var/nix/builds/nix-*` (if the timer hasn't already).
17. **Run `nix-collect-garbage` again after clearing the 50GB buffer** — The buffer files are NOT in the nix store, but clearing them changes BTRFS extent references.
18. **Consider increasing rate limit to 200/60s** — Even with the `/realtime/` exemption, 100/60s is tight for an agent that polls every 60s and uploads events. A single sync cycle can hit 5-10 API calls.
19. **Add `restartTriggers` for monitor365 agent on flake lock change** — Currently only the server has restartTriggers on the sops secret. The agent should restart when its package changes.
20. **Verify the Forgejo OIDC fix from the concurrent session** — `3ca1ad69` and `2d12a613` were committed by another session. Verify they work.
21. **Review the `add3f045` doc formatting commit** — Concurrent session reformatted Markdown/YAML across the project. Verify it didn't damage anything.
22. **Add monitor365 server backup verification** — The backup module exists (`monitor365-server backup`) but restore is never tested. A backup you can't restore is just as bad as no backup.

### P3 — LOWER (polish/convenience)

23. **Add `templ lsp` to neovim config** — templ LSP for Go templ files.
24. **Add templ to docs/CONTRIBUTING.md** — Go toolchain section.
25. **Consider `templ fmt` in pre-commit hook** — Format .templ files.
26. **Audit `base.nix` `with pkgs;` usage** — Silent fallthrough gotcha.
27. **Split `base.nix` into category files** — It's getting large.
28. **Add a `monitor365-server doctor` CLI command** — Checks api_key health, projection state, event store integrity, WS connections, upload success rate.
29. **Add structured logging for monitor365 WS events** — Connection, disconnection, heartbeat, with durations and reasons.
30. **Review all projection `reset()` implementations** — Device, user, alert projections all do `DELETE FROM`. Same data-loss class as the tenant bug that started all this.
31. **Consider making bootstrap use the command handler** — Instead of direct CRUD + manual event emission, bootstrap could go through `tenant_command_handler::execute` to emit events naturally.
32. **Add a monitor365 integration test** — Boot server + agent in a Nix VM, verify auth survives restart, events upload successfully.
33. **Consider WS ping/pong at the protocol level** — Currently heartbeats are application-level JSON messages. WebSocket protocol-level pings (control frames) are more robust and don't require JSON parsing.
34. **Document the event sourcing "flip"** — Bootstrap is CRUD-then-event, API is event-sourced, perform_init is CRUD-then-event. This duality is confusing.
35. **Add `api_key` health metric** — `monitor365_bootstrap_api_key_nonempty` gauge (1 = healthy, 0 = wiped). Alert if it drops to 0.
36. **Consider centralizing WS reconnection backoff** — The agent has separate reconnection logic in `ws_client.rs` and `cloud_sync.rs`. They should share a backoff strategy.
37. **Add circuit breaker status to metrics** — The cloud client has a circuit breaker but its state isn't exposed as a metric.
38. **Review the `events.db` SQLite buffer design** — 50GB growth indicates no effective size limit. The `max_size_mb` config applies to the segment buffer, not the SQLite persistence DB.
39. **Consider SQLite WAL checkpointing for the agent buffer** — The 23GB WAL file suggests checkpointing isn't happening. `PRAGMA wal_autocheckpoint` may need tuning.
40. **Add disk usage monitoring for service state directories** — `/var/lib/monitor365/` grew to 50GB undetected. Gatus or node exporter should alert on per-directory disk usage.
41. **Verify sops `cloud_auth_token` is non-empty** — The original desync was caused by an initially-empty secret. Worth a one-time check.
42. **Add Homepage tile for monitor365 agent health** — Show agent connection status, last upload time, event buffer size.
43. **Consider a monitor365 maintenance window CLI** — `monitor365-server maintenance --clear-buffer --restart-agent` to safely clear stale buffers.
44. **Review the `COMPRESSION_THRESHOLD` removal** — The constant is now `_COMPRESSION_THRESHOLD` (unused). If no other code uses flate2, remove the dependency.
45. **Add a changelog entry for the 4 monitor365 fixes** — These are significant user-facing fixes.
46. **Consider adding `#[cfg(test)]` helpers for WS integration testing** — The current tests can't easily test the full WS connect → heartbeat → disconnect lifecycle.
47. **Review the `build_headers_from_config` function** — It may be setting headers that interfere with WS upgrades.
48. **Add a pre-deploy check for monitor365 buffer size** — Warn if `/var/lib/monitor365/events.db*` exceeds 1GB before deploying.
49. **Consider BTRFS quota for service state directories** — Prevent any single service from consuming more than N GB.
50. **Celebrate** — The agent has been broken for 7+ days. Three cascading root causes are fixed. The monitoring system can finally collect data again.

---

## g) Questions I CANNOT Figure Out Myself

### 1. Should the stale 50GB event buffer be cleared, or is there value in preserving those events?

The events from Jul 11-18 are in the agent's local buffer (`events.db`) but fail integrity hash verification on the server. The error is: `"integrity hash verification failed for event 01KXAZDTZ4FA0S7ZFAHFCR0A36: expected 05a0..., computed 86de..."`. This suggests the events were encrypted with a different `storage_key` than the current one. **Is it acceptable to delete these 7 days of monitoring data, or should I investigate whether the storage key changed and whether the events can be re-encrypted?**

### 2. The `storage_key` file at `/var/lib/monitor365/storage_key` is 44 bytes and dates from Jul 9 (first boot). Has it ever been rotated?

If the storage key was regenerated at some point (e.g., during a config change or redeploy), all events encrypted with the old key would fail integrity verification with the exact error we're seeing. **Has the monitor365 agent's `storage_key` ever been regenerated, or has it been stable since first boot?**

### 3. Should I add the 3 new bug fixes to the SystemNix AGENTS.md gotchas table, even though they're upstream monitor365 bugs?

The gotchas table is primarily for SystemNix-specific issues. These 3 bugs (101 status, rate limit `/realtime/`, JSON gzip) are all in the monitor365 codebase, not SystemNix. However, the debugging context (how to identify them, what logs to look for) would be valuable for future SystemNix debugging sessions. **Should I document upstream monitor365 bugs in the SystemNix AGENTS.md, or keep that file strictly for SystemNix-specific issues?**

---

## Summary

This session started with a todo list of 11 items from the prior session's self-review. 5 of those items turned out to be non-issues (device registration, T012, agent 400, WS timeout — all verified incorrectly). But investigating them led to discovering **three cascading root-cause bugs** that had broken the monitor365 agent for 7+ days:

1. **JSON gzip** — prevented device registration (root cause)
2. **101 status** — caused WS death spiral after registration was fixed
3. **Rate limit `/realtime/`** — blocked WS upgrades after the 101 fix kicked in

All three are now fixed, committed, pushed, and deployed. The agent connects and registers successfully. The remaining issue is the 50GB stale event buffer that needs manual clearing (requires sudo).

**Key lesson:** The prior session's self-review correctly identified that something was wrong with the WS connection, but I dismissed it based on code analysis. Production logs showed the problem instantly. **Read logs first, reason about code second.**

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
