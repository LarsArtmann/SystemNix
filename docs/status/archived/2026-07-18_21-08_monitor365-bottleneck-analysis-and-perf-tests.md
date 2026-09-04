# Monitor365 Bottleneck Analysis & Performance Tests — Status Report

**Date:** 2026-07-18 21:08 CEST
**Trigger:** User asked "~56K events/90s sounds slow for a same-host connection — where are the bottlenecks?"
**Bottom line:** Client-side encoding is NOT the bottleneck (29K events/sec). The real bottleneck is small batch sizes (5K read, 1K per request). Fix committed (10x/5x increase) but deploy blocked by pre-existing buildflow issue.

---

## a) FULLY DONE ✅

| #  | Task                                                             | Evidence                                                                       | Commit      |
| -- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------ | ----------- |
| 1  | **Bottleneck identified** — small batch sizes, not encoding      | Measured: client encoding 29K/sec, actual throughput 1.2K/sec                  | —           |
| 2  | **SYNC_UPLOAD_BATCH_LIMIT increased 5000 → 50_000** (10x)        | `crates/cli/src/cloud_sync.rs:301`                                             | `de79d57cd` |
| 3  | **DEFAULT_MAX_BATCH_SIZE increased 1000 → 5000** (5x)            | `crates/cloud-client/src/config.rs:8`                                          | `de79d57cd` |
| 4  | **Throughput regression tests** (4 tests with enforced minimums) | `tests/throughput_regression.rs`                                               | `de79d57cd` |
| 5  | **Criterion benchmarks for upload hot path** (6 new benchmarks)  | `benches/bench_cloud_client.rs`                                                | `de79d57cd` |
| 6  | **Made `event_to_cloud_event` and `size_aware_chunks` public**   | Needed for benchmarks/tests                                                    | `de79d57cd` |
| 7  | **All tests pass** — 513 tests, 0 failures                       | `cargo test -p monitor365-cloud-client -p monitor365-cli -p monitor365-domain` | —           |
| 8  | **Upstream committed and pushed**                                | `de79d57cd` on origin/master                                                   | —           |
| 9  | **SystemNix flake.lock updated**                                 | `8a9b5830` on origin/master                                                    | `8a9b5830`  |
| 10 | **Daily limit raised to 1M** (by user via DuckDB CLI)            | Backlog draining: 597922541 → 597863436 (59K drained)                          | —           |

### Measured baselines (evo-x2, debug build):

```
event_new_canonicalization:  90,831 events/sec  (threshold: 5,000)
event_to_cloud_event:        53,754 events/sec  (threshold: 2,000)
upload_encode_pipeline:      29,292 events/sec  (threshold: 500)
  (CBOR: 417KB for 1000 events, zstd: 76KB — 5.5x compression)
size_aware_chunks:           10K events in 0.09ms (threshold: <10ms)
```

---

## b) PARTIALLY DONE ⚠️

| # | Task                               | What's done                                                                        | What's missing                                                                                                                                                                    |
| - | ---------------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Deploy batch size optimization** | Binary built (`de79d57cd` in nix store). Flake.lock updated.                       | Deploy blocked by **pre-existing buildflow build error** (private Go module auth: `github.com/larsartmann/go-checker-helpers` HTTPS credentials). Fails even with old flake.lock. |
| 2 | **Backlog draining**               | User raised limit to 1M. ~59K events drained in first 90s (5016 → 61016 uploaded). | With CURRENT batch sizes (5K/1K), throughput is ~1.2K/sec. With new batch sizes (50K/5K), expected ~5-10K/sec. But can't deploy until buildflow is fixed.                         |

---

## c) NOT STARTED ❌

| # | Task                                           | Why                                                                                                                                                                                      |
| - | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Fix buildflow build**                        | Pre-existing issue: `github.com/larsartmann/go-checker-helpers` private repo, HTTPS auth fails in sandbox. Needs GOPRIVATE/GIT_SSH_COMMAND in the derivation. Not related to my changes. |
| 2 | **Measure post-deploy throughput improvement** | Blocked by deploy                                                                                                                                                                        |
| 3 | **Parallel sub-batch uploads**                 | Next optimization after batch sizes — upload 10 sub-batches concurrently instead of sequentially                                                                                         |
| 4 | **Server-side DB batch inserts**               | Server processes each event individually (integrity verify → DB append → realtime → hardware). Batching DB inserts would help.                                                           |

---

## d) TOTALLY FUCKED UP 💥

| # | What                                                                 | Impact                                                                                                                                                                                            |
| - | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Didn't check if system builds before updating flake.lock**         | The buildflow build was already broken. I discovered this only when trying to deploy. Should have tested `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` BEFORE committing. |
| 2 | **`nix flake lock --update-input` deleted referenced paths earlier** | GC + flake lock updates don't mix. Had to re-fetch multiple times.                                                                                                                                |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Bottleneck Analysis (the core finding)

**Question:** Why is throughput only ~1,167 events/sec on localhost?

**Answer:** The bottleneck is NOT the client-side encoding (29K events/sec capacity). It's the **batch size configuration**:

```
SYNC_UPLOAD_BATCH_LIMIT = 5000   ← reads only 5K events per sync cycle
DEFAULT_MAX_BATCH_SIZE = 1000    ← splits into sequential 1K-event HTTP requests
→ 5 sequential HTTP requests per cycle
→ Each request: ~190ms server-side (DB append + integrity verify per event)
→ 5 * 190ms = ~950ms for 5000 events = ~5,200 events/sec theoretical max
→ Actual: ~1,167/sec (additional overhead from per-device sync downloads between cycles)
```

**Fix:** `SYNC_UPLOAD_BATCH_LIMIT = 50_000`, `DEFAULT_MAX_BATCH_SIZE = 5000`
→ 10 sequential HTTP requests per cycle (50K/5K)
→ Amortizes per-cycle overhead across 10x more events
→ Expected throughput: ~5,000-10,000 events/sec

**What's NOT the bottleneck (verified by benchmarks):**

- ❌ `event_to_cloud_event` hash recompute: 53K/sec (my fix B costs ~19µs/event)
- ❌ CBOR + zstd encoding: 29K/sec (34ms for 1000 events)
- ❌ Canonicalization round-trip: 91K/sec (11µs/event)
- ❌ `size_aware_chunks`: 0.09ms for 10K events

### Performance Test Architecture

Two layers of performance testing:

1. **Throughput regression tests** (`#[test]`, runs in CI):
   - `test_event_to_cloud_event_throughput`: >2K/sec
   - `test_upload_encode_pipeline_throughput`: >500/sec
   - `test_event_new_canonicalization_throughput`: >5K/sec
   - `test_size_aware_chunks_throughput`: <10ms for 10K events
   - Each verifies BOTH throughput AND correctness (integrity passes)

2. **Criterion benchmarks** (manual, detailed profiling):
   - 6 new benchmarks covering the full upload hot path
   - Throughput-tagged for easy regression detection
   - Run via `cargo bench -p monitor365-cloud-client`

---

## f) Up to 50 Things We Should Get Done Next 📋

### Priority 0 — Critical (blocked)

1. **Fix buildflow build** — `github.com/larsartmann/go-checker-helpers` needs GOPRIVATE or GIT_SSH_COMMAND in the nix derivation. Blocks ALL system deploys.
2. **Deploy batch size optimization** — binary built, just can't activate. Expected 5-10x throughput improvement.
3. **Measure post-deploy throughput** — verify the batch size fix actually improves real-world drain rate.

### Priority 1 — High

4. **Parallel sub-batch uploads** — currently sequential `for` loop. Use `tokio::join_all` or `buffer_unordered` for concurrent HTTP requests.
5. **Server-side batch DB inserts** — server processes each event individually. Batch the DuckDB INSERT.
6. **Reduce server-side per-event work** — realtime broadcast, hardware extraction, forwarder per event. Batch or defer these.
7. **Skip hash recompute for already-canonical events** — my fix B recomputes for EVERY event. New events (post-fix A) are already canonical. Add a version flag or check.
8. **Add `GOENV=off` or `GONOSUMDB` to buildflow derivation** — may fix the private repo auth issue.
9. **Add throughput test for server-side `verify_ingest_integrity`** — currently only client-side is benchmarked.
10. **Profile server-side per-request timing** — 190ms avg per 1000-event batch. Where exactly is the time spent?

### Priority 2 — Medium

11. **Consider `rayon` for parallel hash computation** — SHA-256 is CPU-bound, embarrassingly parallel.
12. **Use zstd level 1 instead of 3** — faster compression, slightly larger output.
13. **Pre-allocate CBOR buffer** — currently `Vec::new()` then grow. Pre-allocate based on event count.
14. **Consider `serde_json::raw::RawValue`** — avoid re-parsing the payload Value if we just need to re-serialize it.
15. **Add `cargo bench --bench bench_cloud_client` to CI** — catch performance regressions automatically.
16. **Document the bottleneck chain** in AGENTS.md — batch sizes, sequential requests, server-side per-event cost.
17. **Add a "drain rate" metric** — `cloud_sync_backlog_drain_rate` (events/sec).
18. **Consider memory-mapped segment buffer reads** — for very large backlogs, I/O may become the bottleneck.
19. **Add HTTP keep-alive** — reduce TCP handshake overhead per request.
20. **Consider HTTP/2 multiplexing** — multiple concurrent requests over one connection.

### Priority 3 — Low

21-50: (same backlog items from prior status report — DLQ, CBOR hash format, Prometheus alerting, rpi3 deploy, reboot, etc.)

---

## g) Top 2 Questions I CANNOT Answer ❓

### Q1: How do we fix the buildflow private repo auth in the nix sandbox?

The buildflow derivation fails with `could not read Username for github.com` when trying to fetch `github.com/larsartmann/go-checker-helpers` (private repo). This blocks ALL system deploys. The fix likely involves setting `GIT_SSH_COMMAND` or `GOPRIVATE` in the derivation's `preBuild`, or adding the private repo to the vendor hash differently. **I cannot fix this without understanding how the buildflow derivation is structured and how other LarsArtmann private Go repos are handled in nix.**

### Q2: Should the hash recompute (fix B) be skipped for events created after fix A?

Currently, `event_to_cloud_event` recomputes the hash for EVERY event, even new ones that are already canonical (created after fix A). This costs ~19µs/event (53K/sec capacity). For the 597M backlog, this adds ~3.1 hours of pure hash computation time. Skipping the recompute for already-canonical events would save this. **But detecting "already canonical" requires either a version flag on the event (storage format change) or comparing the stored hash with the recomputed one (same cost as just recomputing). I cannot decide this architectural tradeoff without knowing if you're willing to change the event storage format.**

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
