# Pocket ID SQLITE_BUSY restart bursts — investigation close-out

**Task:** 000001a20c17084f0876b78f8c4000000000 (batch item 3) — 2026-11-24 08:3x
**Row:** docs/todo/services.md "Investigate Pocket ID SQLITE_BUSY restart bursts" (Source: 08-16 22-00 §c.4)

## Verdict

The dispatched failure class (BUSY → restart burst) no longer exists; the remaining
BUSY events are request-level degradation under evening pressure, monitored and
self-resolving. No SystemNix-side structural fix remains. "Investigate" completes
with this diagnosis; the monitoring loop already gates recurrence.

## Evidence (live census, 2026-11-24)

1. **30-day BUSY census:** 17 `database is locked (5) (SQLITE_BUSY)` journal lines,
   all request-level ("Failed to authorize request", "Rate limiter unavailable"),
   clustered on three evenings (Nov 17 ×6, Nov 18 ×5, Nov 22 ×6, 14:00–21:00).
   ZERO of them preceded or caused a unit restart.
2. **Restart attribution:** 9 "Started Pocket ID" in 30 days ≈ deploy/reboot cadence;
   the ONLY crash exit (Nov 16 01:46, `status=1/FAILURE`, self-healed on restart #1)
   was the unrelated `failed to update last health check: host is not registered`
   app error — not BUSY. The "restart bursts" framing came from the 2026-08 era.
3. **The crash-loop class is fixed upstream:** the BUSY→restart cascade was the
   francis health-check crash-loop in Pocket ID ≤2.10; fixed in 2.12.0
   (francis v0.1.0-beta.17+) — documented in the module comment above
   `clearStaleWal` (modules/nixos/services/pocket-id.nix), which stays as
   defense-in-depth against unclean-shutdown WAL staleness. Running version 2.19.1.
4. **Storage aggravator removed:** the DB rides the Samsung hot tier
   (`findmnt /var/lib/pocket-id` → `/dev/nvme0n1p2[/hot/pocket-id]`, hot-db wave,
   configuration.nix entries.pocket-id) — the slow-QLC-fsync era (fsync ~200 ms
   under load) predates the move; surviving BUSY events happen on the fast disk.
5. **Residual BUSY = pressure-era write-lock contention:** evening clustering
   matches the zram-full/pressure pattern the existing gatus alert already names
   ("Collateral of memory/IO pressure (zram-full evenings); resolves when pressure
   drains"). Pocket ID serializes writers (rate limiter + authz on every
   oauth2-proxy request); when the box is under memory/IO pressure, transactions
   exceed the app's busy timeout → transient BUSY, no crash.
6. **Monitoring loop closed:** textfile collector
   `system_pocket_id_busy_events_24h` (fail-closed journal scan, 10/24h threshold
   gauge, gatus alert naming the degradation) live and green — 0 events/24h at
   08:12 today, file mtime fresh.

## Disposition

- No fix to land: the crash class is upstream-fixed, storage is on the fast tier,
  degradation is alert-gated. Any remaining hardening (busy_timeout pragma audit)
  is upstream Pocket ID work and would need source verification before filing
  (verify-before-filing) — deliberately NOT queued while the 24h gauge reads 0.
- Queue row closes as investigated-with-verdict on both surfaces
  (TODO_LIST + docs/todo/services.md).
