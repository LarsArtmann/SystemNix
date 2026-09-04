# Monitor365 Integrity Hash Root Cause Fix — Status Report

**Date:** 2026-07-18 10:15
**Status:** ✅ ROOT CAUSE FIXED AND VERIFIED
**Commits:** `9ea1f1000` (canonicalization fix) + `ebb26a0bd` (hardening) + SystemNix `zrsy8sx9`

---

## Executive Summary

The Monitor365 cloud sync pipeline was dropping **100% of events** since launch — not
just historical ones. The prior session's "self-healing" fix (graceful degradation)
correctly broke the poison-pill crash loop but hid the real problem as silent data loss.

This session found and fixed the **actual root cause**: a JSON serialization
canonicalization mismatch between the agent and server. Post-deploy verification
confirms **zero integrity failures** — events now flow correctly.

---

## The Root Cause (Confirmed with a Proof Test)

```
AGENT bytes:  {"zebra":1,"apple":"hello","mango":true}   (struct field-declaration order)
SERVER bytes: {"apple":"hello","mango":true,"zebra":1}   (BTreeMap alphabetical order)
→ Different bytes → Different SHA-256 → EVERY event rejected
```

- **Agent** (`Event::new`): `serde_json::to_vec::<P>(&struct)` → struct field order
- **Wire** (`event_to_cloud_event`): bytes → `serde_json::Value` → BTreeMap (alphabetical)
- **Server** (`verify_ingest_integrity`): `serde_json::to_vec(&Value)` → alphabetical
- No crate enables serde_json's `preserve_order` feature (verified across all Cargo.toml)
- Result: ANY event with non-alphabetical struct fields fails verification

---

## The Fix (4 Layers)

### Layer 1: Event::new Canonicalization (THE root cause fix)

`crates/domain/src/lib.rs:166` — payload bytes now go through a `serde_json::Value`
round-trip before hashing. Stored bytes match what the server re-serializes.

### Layer 2: event_to_cloud_event Hash Recompute (recovers 597M buffered events)

`crates/cloud-client/src/types.rs:50` — at upload time, recomputes the integrity hash
over canonical bytes. For new events (Layer 1) this is a no-op. For OLD buffered
events with non-canonical hashes, it produces the correct hash the server accepts.

### Layer 3: Server Graceful Degradation (prior commit `b40ed0c98`)

Skip-and-continue instead of fail-fast. One bad event never blocks the batch.

### Layer 4: Agent Self-Heal (prior commit `b40ed0c98`)

Unconditional cursor advance on server Ok. Breaks the infinite re-send loop.

---

## Quality Hardening (commit `ebb26a0bd`)

| Improvement                           | What It Does                                                                                                         |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `cloud_sync_zero_accept_cycles` gauge | Tracks consecutive cycles with ZERO accepted events. ERROR after 3 cycles — catches the "false victory" failure mode |
| Server log rate-limiting              | Per-event WARN → single aggregated WARN per batch (was 5000 lines/cycle, now 1)                                      |
| CB 4xx classification                 | `ServerError` non-5xx reclassified from `Infrastructure` → `Rejection` (semantically correct)                        |
| Metric naming                         | `ingest.rejected_events_total` → `ingest_rejected_events_total` (Prometheus convention)                              |
| `drain(..)` efficiency                | No more `.clone()` per event in the verification loop                                                                |

---

## Verification Results

### Tests

- **Regression test** (`canonicalization_regression.rs`): Proves Event::new canonicalizes payload so server verify SUCCEEDS
- **Legacy recovery test** (`test_event_to_cloud_event_recomputes_hash_for_legacy_events`): Proves old buffered events are recovered
- **Full workspace suite**: 1117+ tests pass, 0 failures (7 E2E failures are pre-existing — require running DB)
- **Proof test** (discarded): Originally asserted server verify FAILS — confirmed the bug before the fix

### Post-Deploy (10:09 CEST, 2026-07-18)

- **Running binary**: `ebb26a0bd` confirmed via `pgrep -af monitor365`
- **Server integrity logs**: **ZERO** "integrity hash mismatch" warnings after agent restart
- **Events uploaded**: `cloud_sync_events_uploaded_from_store` = 5016 (was 27)
- **Error shifted**: from `integrity hash mismatch` → `daily event limit reached` (HTTP 403) — a legitimate business rule, proving events now PASS integrity
- **Backlog**: drained ~10,000 events (597928444 → 597918444) before hitting daily cap

---

## Remaining Operational Issue: Backlog vs Daily Limit

The 597M backlog is now blocked by the 10K/day tenant limit (default). At 10K/day,
draining 597M events would take ~164 years. Options:

1. **Purge the backlog** (recommended): The events are historical monitoring data
   from a broken pipeline with minimal analytical value. Requires sudo:
   `sudo systemctl stop monitor365 && sudo rm -rf /var/lib/monitor365/store/* && sudo systemctl start monitor365`
2. **Raise the daily limit**: Via the server admin API/UI. 10K is too low for a
   monitoring agent collecting events every few seconds.
3. **Wait for midnight reset**: New events (collected after the fix) will flow
   normally once the daily counter resets. The backlog remains.

**Recommendation**: Purge the backlog (option 1) + raise the daily limit to at
least 1M (option 2). The 10K default is designed for multi-tenant SaaS, not a
single-tenant homelab monitoring agent.

---

## What Was Done Wrong (Honest Self-Critique)

The prior session's biggest mistake: **declaring "self-healing confirmed" while
100% of events were being dropped.** The mechanism (cursor advances) worked, but
the outcome (data reaches the server) failed completely. The `accepted>0` health
signal added in this session would have caught this immediately.

**Lesson**: Always verify the OUTCOME (data stored), not just the MECHANISM
(cursor moved). A pipeline that "succeeds" while dropping 100% of data is worse
than one that fails loudly.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
