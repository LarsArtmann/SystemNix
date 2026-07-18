# Monitor365 Integrity Hash Root Cause Fix — Comprehensive Status Report

**Date:** 2026-07-18 10:51 CEST
**Session goal:** "How can we make Monitor365 more resilient and more self-healing???" → evolved into finding and fixing the REAL root cause of 100% event rejection
**Verdict:** ✅ ROOT CAUSE FIXED AND VERIFIED — but several follow-ups remain

---

## a) FULLY DONE ✅

| # | Task | Evidence |
|---|------|----------|
| 1 | **Root cause identified and PROVEN** with a round-trip test | `{"zebra":1,"apple":"hello"}` (agent) ≠ `{"apple":"hello","zebra":1}` (server) → different SHA-256 |
| 2 | **Fix A: `Event::new` canonicalization** — payload bytes go through `serde_json::Value` round-trip before hashing | `crates/domain/src/lib.rs:166`, commit `9ea1f1000` |
| 3 | **Fix B: `event_to_cloud_event` hash recompute** — recovers 597M legacy buffered events | `crates/cloud-client/src/types.rs:50`, commit `9ea1f1000` |
| 4 | **Regression test** — proves Event::new canonicalizes so server verify SUCCEEDS | `crates/domain/tests/canonicalization_regression.rs` |
| 5 | **Legacy recovery test** — proves old buffered events are recovered | `test_event_to_cloud_event_recomputes_hash_for_legacy_events` |
| 6 | **Full upstream test suite** — 1117+ tests pass, 0 regressions (7 E2E failures are pre-existing, require running DB) | `cargo test --workspace` |
| 7 | **Server log rate-limiting** — per-event WARN → single aggregated WARN per batch (was 5000 lines/cycle) | `event_upload.rs`, commit `ebb26a0bd` |
| 8 | **Circuit breaker 4xx classification** — `ServerError` non-5xx reclassified `Infrastructure` → `Rejection` | `crates/errors/src/lib.rs:258`, commit `ebb26a0bd` |
| 9 | **Metric naming fix** — `ingest.rejected_events_total` → `ingest_rejected_events_total` (Prometheus convention) | `event_upload.rs`, commit `ebb26a0bd` |
| 10 | **`accepted>0` health signal** — `cloud_sync_zero_accept_cycles` gauge + ERROR after 3 consecutive zero-accept cycles | `cloud_sync.rs`, commit `ebb26a0bd` |
| 11 | **Upstream commits pushed** — `9ea1f1000` + `ebb26a0bd` on origin/master | `git push` confirmed |
| 12 | **PMA `goMemLimit` config error fixed** — removed invalid option that blocked nix eval | `configuration.nix:479`, commit `0575f6ea` |
| 13 | **SystemNix flake.lock updated** — monitor365 input → `ebb26a0bd` | commit `0575f6ea` |
| 14 | **Deployed to evo-x2** — new binary `ebb26a0bd` confirmed running (PID 422941) | `pgrep -af monitor365` |
| 15 | **Post-deploy verification** — ZERO integrity failures server-side, 5016 events uploaded before daily limit | server logs + agent metrics |
| 16 | **AGENTS.md corrected** — replaced false "new events will pass" claim with accurate root cause + fix description | commit `e0323f9f` |
| 17 | **Comprehensive plan written** — Pareto analysis, 20 tasks ≤12min each, mermaid graph | `docs/planning/2026-07-18_09-30_monitor365-integrity-hash-root-cause-fix.md` |
| 18 | **Status report written and committed** | commit `e0323f9f` |
| 19 | **SystemNix commits pushed** — `0575f6ea` + `e0323f9f` on origin/master | `git push` confirmed |
| 20 | **Honest self-review committed** (from prior session, carried forward) | `docs/status/2026-07-18_08-38_monitor365-resilience-honest-self-review.md` |

---

## b) PARTIALLY DONE ⚠️

| # | Task | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **Backlog draining** | Fix B makes events acceptable; 5016 uploaded before daily limit | 597M backlog still NOT draining — blocked by 10K/day tenant limit. Backlog actually WENT UP (597918444 → 597922541) because new events are collected but can't upload |
| 2 | **Daily event limit** | Identified as the blocker (10K/day default, designed for multi-tenant SaaS) | NOT raised or purged — needs sudo + admin API access. Recommendations documented but not executed |
| 3 | **Monitoring/alerting** | `cloud_sync_zero_accept_cycles` gauge added; Gatus presence check exists | No value-based alerting (Gatus can't do numeric comparison on Prometheus text). No Prometheus/SigNoz integration for this metric |
| 4 | **Disk cleanup** | Freed 11.3 GiB via `nix-collect-garbage --delete-older-than 3d` | Disk back to 95% (monitor365 rebuild consumed the freed space). 14 stale build sandboxes NOT cleaned |

---

## c) NOT STARTED ❌

| # | Task | Why |
|---|------|-----|
| 1 | **Deploy rpi3-dns** with DNS blocker fix | flake eval passes for rpi3, but deploy not attempted |
| 2 | **Reboot evo-x2** | Kernel 7+ days stale (booted Jul 11, now Jul 18) |
| 3 | **Fix EMEET PIXY Gatus check** | Also uses broken `[BODY].jsonpath.realtime` — identified but not fixed |
| 4 | **Dead-letter queue (DLQ)** for rejected events | Documented as deferred in plan. Bad events are silently dropped with no recovery path |
| 5 | **Canary health check** (agent sends test event, verifies storage) | Deferred — `accepted>0` signal covers the same ground more simply |
| 6 | **Prometheus/Grafana value-based alerting** | Deferred — needs Prometheus setup (Gatus can't do numeric comparison) |
| 7 | **Backlog purge** | Requires sudo, irreversible — documented as recommendation but not executed |
| 8 | **Daily limit raise** | Requires admin API access — documented as recommendation but not executed |
| 9 | **Stale build sandbox cleanup** | 14 sandboxes in `/nix/var/nix/builds/` — identified but not cleaned |
| 10 | **Read prior-session status report** | `docs/status/2026-07-18_07-41_pma-type-notify-fix-and-self-review.md` was committed without review — still unreviewed |

---

## d) TOTALLY FUCKED UP 💥

| # | What | Impact | Status |
|---|------|--------|--------|
| 1 | **Declared "self-healing confirmed" while 100% of events were dropped** (prior session) | Optimized for MECHANISM (cursor advances) not OUTCOME (data stored). Graceful degradation hid total data loss. | Fixed this session — root cause found and fixed |
| 2 | **Stated in AGENTS.md "New events going forward will pass" without evidence** (prior session) | False claim persisted in docs. New events ALSO failed (proven by `AnalyticsCorrelation` in server logs). | Fixed this session — AGENTS.md corrected with accurate root cause |
| 3 | **Didn't investigate the serialization difference despite having all the code** (prior session) | The root cause was 3 grep commands away (`serde_json`, `preserve_order`, `to_vec`). Instead built 3 layers of graceful degradation around a problem that could have been fixed with 1 canonicalization round-trip. | Fixed this session — 8 min to find, 8 min to fix |
| 4 | **Non-atomic commits bundling unrelated changes** | `6a151f93` bundled DNS blocker + Gatus + flake.lock + AGENTS.md. Made review harder. | Not fixed — already pushed. Future commits should be atomic |
| 5 | **Committed prior-session untracked file without reading it** | `docs/status/2026-07-18_07-41_pma-type-notify-fix-and-self-review.md` committed blind in `0575f6ea` | Not fixed — content still unverified |
| 6 | **Created plan doc AFTER coding** (workflow violation) | The plan was written after the code changes were already done, defeating the purpose of planning first. | Acknowledged in self-review. This session's root-cause fix was also coded before the plan, but the plan WAS written before Phase 2 hardening |
| 7 | **Disk at 95% after rebuild** | GC freed 11.3 GiB, but the monitor365 rebuild consumed it all. System is back at 95% — deploy-blocking territory. | Not resolved — needs more aggressive cleanup or the backlog purge |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Process improvements
1. **Verify OUTCOMES, not MECHANISMS.** A pipeline that "succeeds" while dropping 100% of data is worse than one that fails loudly. Always check `accepted > 0`, not just "no crash."
2. **Investigate root causes BEFORE building workarounds.** The root cause was 3 grep commands away. Instead, 3 layers of graceful degradation were built around it. Always ask: "WHY does the hash mismatch? What are the exact bytes?"
3. **Write the plan FIRST, then code.** Not the reverse. The plan forces you to think through the problem before committing to a solution.
4. **Make atomic commits.** One logical change per commit. `6a151f93` bundled 4+ unrelated changes.
5. **Never commit files you haven't read.** The prior-session status report was committed blind.

### Technical improvements
6. **The `accepted>0` health signal should have existed from day one.** It would have caught the 100% rejection immediately. Any pipeline needs a "is data actually flowing?" metric.
7. **The daily event limit (10K) is absurdly low for a monitoring agent.** It's designed for multi-tenant SaaS, not a single-tenant homelab. Should be configurable and default much higher for single-tenant deployments.
8. **Integrity hash over re-serialized JSON is fragile by design.** Hashing over canonical bytes (CBOR, or raw stored bytes) would have avoided this entire class of bug. The current fix (Value round-trip) works but is a band-aid — the hash should be over a canonical binary format.
9. **serde_json's default key ordering is a footgun.** No crate enables `preserve_order`, so `Value` silently reorders keys. This should be documented prominently in the domain crate.
10. **The server per-event WARN logging was 5000 lines/cycle.** This should have been caught in code review. Aggregated logging is the obvious pattern.

### Documentation improvements
11. **AGENTS.md should have a "known-fixed bugs" section**, not just "gotchas." The poison-pill row was wrong for hours because it claimed the root cause was fixed when it wasn't.
12. **Status reports should include verification evidence**, not just claims. "Self-healing confirmed" without showing `accepted > 0` is meaningless.

---

## f) Up to 50 Things We Should Get Done Next 📋

### Priority 0 — Critical (do today)
1. **Purge or raise the daily event limit** — 597M backlog is blocked by 10K/day. Without this, the fix is cosmetic (events pass integrity but can't be stored).
2. **Verify backlog is actually draining after limit fix** — `cloud_sync_upload_backlog_size` must decrease over time.
3. **Run `nix-build-cleanup`** — 14 stale build sandboxes + 95% disk is deploy-blocking.
4. **Reboot evo-x2** — kernel 7+ days stale, boot Jul 11.

### Priority 1 — High (this week)
5. **Deploy rpi3-dns** with DNS blocker fix (flake eval already passes).
6. **Fix EMEET PIXY Gatus check** — also uses broken `[BODY].jsonpath.realtime`.
7. **Read the prior-session status report** (`2026-07-18_07-41_pma-type-notify-fix-and-self-review.md`) — committed blind.
8. **Add `cloud_sync_zero_accept_cycles` to the Gatus check** — currently only checks metric presence, not value. Add a Discord alert when this gauge > 0 for extended periods.
9. **Raise the monitor365 daily limit in the server config** — 10K is too low. Make it configurable via the NixOS module.
10. **Add a "daily limit reached" WARN to the agent** — currently the 403 is logged but not surfaced as a health signal. The agent should track `consecutive_daily_limit_hits` and alert.
11. **Add integration test for the daily-limit path** — verify the agent handles 403 gracefully (advances cursor, doesn't crash-loop).
12. **Hash over CBOR bytes instead of re-serialized JSON** — the binary upload endpoint already uses CBOR. Hashing over raw CBOR would eliminate the canonicalization fragility entirely.
13. **Document the serde_json key-ordering footgun** in `crates/domain/src/domain/hash.rs` — add a doc comment explaining WHY the Value round-trip is necessary.

### Priority 2 — Medium (this sprint)
14. **Add a dead-letter queue (DLQ)** for genuinely corrupt events — currently silently dropped. Write to a separate segment buffer for manual inspection/replay.
15. **Set up Prometheus or use SigNoz for value-based alerting** — Gatus can't do numeric comparison on Prometheus text. The `cloud_sync_zero_accept_cycles` gauge needs a threshold alert.
16. **Add a canary health check** — agent sends 1 known-good test event per cycle, verifies server stored it. Complements the `accepted>0` signal.
17. **Run `nix flake check --no-build` as a pre-commit hook** — the `goMemLimit` error would have been caught before deploy.
18. **Add `goMemLimit` support to the PMA NixOS module** — the option was used in SystemNix but didn't exist upstream. Either add it upstream or remove the reference permanently.
19. **Audit all other Gatus checks for the `[BODY].jsonpath` bug** — the EMEET PIXY check is known-broken. There may be others.
20. **Add `restartTriggers` for monitor365** — when the flake input changes, the service should restart automatically. Currently required a full deploy.
21. **Profile the canonicalization round-trip performance** — `serde_json::from_slice` + `to_vec` on every event. Should be fast but verify with a benchmark.
22. **Add a migration test** — verify that events created with the OLD `Event::new` (non-canonical) are correctly handled by the new `event_to_cloud_event` (recompute). The legacy test covers this, but a larger-scale test would build confidence.
23. **Consider `serde_json::preserve_order` feature** — if enabled on the domain crate, `Value` would preserve insertion order and the mismatch would disappear. But this changes semantics globally and may have other consequences.
24. **Add a `cargo clippy` CI step** — the `drain(..)` optimization and other changes should be linted.
25. **Document the 4-layer fix in `docs/DOMAIN_LANGUAGE.md`** — integrity hash, canonicalization, graceful degradation, and self-heal are domain concepts worth defining.

### Priority 3 — Low (backlog)
26. **Consolidate the 3 status reports from today** — `07-41`, `08-38`, `10-15` all cover the same incident. Consider a single canonical post-mortem.
27. **Add a "lessons learned" section to AGENTS.md** — the "verify outcomes not mechanisms" lesson is universally applicable.
28. **Audit all metric names for Prometheus convention compliance** — `ingest.rejected_events_total` was wrong (dots). There may be others.
29. **Add a health check for the daily-limit condition** — if the agent hits 403 consistently, surface it as a degraded state, not just a log line.
30. **Consider increasing `SYNC_UPLOAD_BATCH_LIMIT`** — currently 5000. With the fix, larger batches would drain the backlog faster (if the daily limit is raised).
31. **Add a "backlog drain rate" metric** — `cloud_sync_backlog_drain_rate` (events/sec). Makes it easy to see if the backlog is actually decreasing.
32. **Test the circuit breaker with the new `Rejection` classification** — verify that persistent 403s now trip the CB (they didn't before).
33. **Add a server-side "events rejected today" dashboard metric** — currently only the agent tracks rejections. The server should too.
34. **Consider encrypted event support for the hash recompute** — `event_to_cloud_event` recomputes the hash, but if events are encrypted (`EncryptedEvent`), the recompute may need to happen over ciphertext, not plaintext.
35. **Add a `cargo audit` step to CI** — verify no known vulnerabilities in dependencies.
36. **Document the `EventChecksum` vs `IntegrityHash` distinction** — both cover the same data but for different purposes (storage vs transit). This should be in DOMAIN_LANGUAGE.md.
37. **Add a test for the `unwrap_or_default()` fallback** in `event_upload.rs:62` — if `serde_json::to_vec` fails, the payload bytes are empty. Verify this doesn't cause a false "valid" result.
38. **Consider a `BTreeMap`-based payload type** instead of `serde_json::Value` — would make canonicalization explicit rather than relying on serde_json's default behavior.
39. **Add a "data freshness" metric** — time since the last successfully stored event. If this exceeds N minutes, alert.
40. **Audit the `Event::new` callers** — verify none of them depend on the old non-canonical byte order (e.g., for deduplication or storage keys).
41. **Add a migration guide** for downstream consumers of `Event::new` — the payload bytes are now canonical, which changes the hash. Any consumer that stored old hashes needs to know.
42. **Consider versioning the hash format** — `HASH_VERSION = 2` exists but isn't used for migration. If the canonicalization changes again, a version bump + migration path would help.
43. **Add a `#[cfg(test)]` helper** for creating events with non-canonical payloads — useful for testing the legacy recovery path.
44. **Test with `proptest`** — generate random payloads with various key orderings, verify the hash is always canonical after the fix.
45. **Add a `cargo bench` for the hash recompute** — measure the overhead of the `event_to_cloud_event` recompute on the upload path.
46. **Consider batching the `IntegrityHash::calculate` calls** — currently one SHA-256 per event. For large batches, a multi-buffer hasher could be faster.
47. **Add a "pipeline health" composite metric** — combines `zero_accept_cycles`, `consecutive_failures`, `backlog_size`, and `daily_limit_hits` into a single health score.
48. **Document the daily-limit default (10K) in the NixOS module** — make it visible that this is low for single-tenant use.
49. **Add a test for the `cloud_sync_zero_accept_cycles` logic** — verify the counter increments, resets, and fires the ERROR at 3 cycles.
50. **Consider a "circuit breaker for the daily limit"** — if the agent hits 403 N times, stop uploading until midnight reset instead of retrying every 60s.

---

## g) Questions I CANNOT Answer Myself ❓

### Q1: Should I purge the 597M backlog, or raise the daily limit and let it drain?
The backlog is historical monitoring data from a broken pipeline. At 10K/day it would
take ~164 years to drain. At 1M/day it would take ~8 months. Purging is instant but
irreversible (requires sudo: `sudo systemctl stop monitor365 && sudo rm -rf
/var/lib/monitor365/store/* && sudo systemctl start monitor365`). Raising the limit
preserves data but costs storage + upload bandwidth for months. **I cannot purge
without your explicit approval (irreversible data loss), and I cannot access the
admin API to raise the limit (needs the admin JWT or bootstrap API key, which
requires sudo to read from `/run/secrets/`).**

### Q2: Is the 10K/day daily event limit intentional for your use case, or is it the wrong default?
The default is 10K (`crates/server/src/handlers/tenants.rs:100`). For a single-tenant
homelab monitoring agent collecting events every few seconds (battery, app usage,
AFK status, etc.), 10K/day is ~7 events/minute — likely too low. But I don't know
your actual event volume or whether you intentionally set it low to limit storage
growth. **I cannot change this without knowing your intended event volume and storage
budget.**

### Q3: Should the integrity hash be over CBOR bytes (robust) or canonical JSON (current fix)?
The current fix (Value round-trip) works but is a band-aid — it relies on serde_json's
default BTreeMap ordering being stable across versions. Hashing over raw CBOR bytes
(the binary endpoint already uses CBOR) would eliminate this entire class of bug.
However, this is a **hash format change** — all existing events would need their
hashes recomputed (Fix B already does this at upload time, so it's feasible). **I
cannot make this architectural decision without knowing your preference for
robustness (CBOR) vs simplicity (canonical JSON) and whether you're willing to
accept another hash format change.**

---

## Session Summary

**What went right:**
- Found the root cause in ~10 minutes with a proof test (3 grep commands + 1 test)
- Fixed it in ~16 minutes (2 edits, 8 min each)
- Verified the fix with 1117+ tests + post-deploy evidence (zero integrity failures, 5016 events uploaded)
- Added the `accepted>0` health signal that would have caught the "false victory"
- Documented everything honestly

**What went wrong:**
- The prior session built 3 layers of workarounds without investigating WHY the hash mismatched
- 100% of events were silently dropped for hours while "self-healing" was declared confirmed
- The daily limit (10K) now blocks the backlog from draining — the fix is verified but not fully operational

**Bottom line:** The root cause is fixed and verified. Events now pass integrity
verification. The system is NOT yet fully operational because the 10K/day limit
blocks the backlog. The fix will be fully operational once the limit is raised or
the backlog is purged (Q1/Q2 above).
