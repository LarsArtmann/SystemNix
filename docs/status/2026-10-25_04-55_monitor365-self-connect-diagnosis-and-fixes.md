# Monitor365 self-connection failure — agent↔server diagnosis + in-tree fixes (2026-10-25 ~04:00–05:00)

Question: "Why can't Monitor365 connect to itself? Agent/Server?" — answered live; two
independent repo bugs found and fixed in-tree (deploy pending). No unit state was touched
(agent re-enable remains owner-gated per docs/todo/services.md).

## a. The answer (evidence chain)

**The agent IS running and the server IS listening** — the failure is the server's DuckDB
connection pool wedging under sustained io PSI, not networking:

1. Server: active, LISTEN 0.0.0.0:3001; agent: active, metrics LISTEN 127.0.0.1:9191.
2. Agent POSTs `http://localhost:3001/api/v1/events/upload/binary` → mix of **request
   timed out** and **HTTP 500 after exactly ~10s** (`pool acquire failed: timed out
   waiting for connection`, monitor365-server journal 03:52–04:01, known class =
   docs/todo/services.md row 720).
3. → agent circuit breaker opens ("7 consecutive failures", re-opened 8× in 15 min),
   SSE drops ("Agent SSE disconnected device_id=evo-x2" 03:51:59), Cloud sync fails
   persistently; the server+agent watchdogs restart both (03:52/03:56) → brief green →
   re-wedge. /health itself hung >10s at 03:55 (needs a pool conn), 200 OK at 04:04 —
   intermittent starvation, not binary down.
4. Box-wide io PSI: some avg10 42–51% through the window (ghostty-scope storm class,
   monitoring.md row).

**Amplifiers found tonight (each verified):**

- **407,761,140 events** sitting in the agent's disk-backed segment buffer
  (`cloud_sync_upload_backlog_size` live :9191) — the NEXT 597M-class drain bomb, held
  back only by the server rejecting uploads; tenant cap still 1B/day (no IO governor;
  runbook says 250k, owner-gated).
- **Nightly backup FAILED 2026-10-25 03:01** — DuckDB OOM inside the backup COPY:
  "could not allocate block of size 256.0 KiB (1.8 GiB/1.8 GiB used)" = the config
  default `memory_limit="2GB"` (decimal = 1.86 GiB) vs the 25 GB DB. No rollback export
  exists from last night. The 03:50–03:57 unit restarts were the backup script +
  watchdogs, not a deploy.
- **node_exporter /metrics has been BROKEN since the 2026-10-18 re-enable** — every
  scrape fails with 26 × "collected metric … was collected before with the same name and
  label values": `monitoredServices` default list (kept for the disabled era) AND the
  registry fan-out (`extraMonitoredServices`, both entries `monitored = true` since
  re-enable) BOTH contain monitor365 + monitor365-server → each `system_service_*` row
  emitted 2× into system_health.prom (live-verified: 2 and 2) → whole-scrape rejection.
  Host metrics blind for 7 days. ~4,350 ESTABLISHED conns piled onto 127.0.0.1:9100
  (listen backlog 4096) under the failing-scrape churn — attribution of the holder needs
  sudo (queued).

**Separate bugs found while tracing (not the connect failure):**

- **gen_app Binder Error** (fast analytics loop, every cycle): server queries
  `e.gen_app` (app_usage.rs) but the live events table lacks the column — upstream
  migration 020 uses `ALTER TABLE … ADD COLUMN … GENERATED ALWAYS AS`, and DuckDB 1.5.5
  refuses: "Adding generated columns after table creation is not supported yet"
  (scratch-DB verified). The best-effort migration runner logs failures at DEBUG and
  continues (db/src/lib.rs:366-374 — same masking class as its own NOT NULL comment
  admits). Every pre-Aug-2026 DB is affected; queued upstream.
- Agent-side `Store channel full, dropping process event (backpressure)` continues even
  after the collector cuts (agent restarted 03:52/03:56 so cuts are live) — its local
  store writes are IO-starved too.
- `window_focused` collector fails forever on Wayland (xdotool, "DISPLAY … is empty",
  73+ consecutive) — pure noise + wasted cycles; queued as decision (disable vs wait
  for Wayland upstream).

## b. Fixed in-tree (HEAD 5555a89ec + 8b52d0bba's parallel work)

1. **system-health.nix**: `allMonitoredServices = lib.unique (…)`. Verified: option
   evals show the overlap; live .prom showed the 2× rows; post-fix render can only emit
   once (pure dedupe).
2. **monitor365.nix** backup invocation: `MONITOR365_SERVER__MEMORY_LIMIT="6G"` env
   (figment env pattern verified upstream: MONITOR365_SERVER__*); 6G fits under the
   unit's MemoryHigh 8G with process headroom.
3. **scripts/monitor365-retention.sh**: every duckdb session now
   `SET memory_limit='6G'; SET threads=4` (`DUCK_SESSION`, env-overridable) — the CLI
   default (80% of system RAM) could blow the backup unit's 12G cap on the first real
   DELETE/VACUUM. Fixture: ALL LEGS GREEN (twice, after edit).

Verification: `nix eval .#nixosConfigurations.evo-x2…toplevel.drvPath` green;
shellcheck OK; statix clean on both touched .nix files; `nix fmt` canonical.
Deploy rides the PSI-calm batch (services.md [watch] row).

## c. Owner-gated (unchanged tonight)

- Agent re-enable confirmation (masked/unmasked decision) — existing [blocked:user] row.
- Tenant event-cap restore 1B → 250k before the next big drain — owner, admin API/sudo.
- `sudo du -s /mnt/pool/services/monitor365` backlog-size ground truth — existing row,
  now with the live gauge number.
- Tonight's backup FAILED → the DB has no export newer than 2026-10-24 03:00-era; if a
  pre-fix backup is needed, the 2026-10-22 owner NVMe safety copy remains the snapshot.

## d. Not done (deliberate)

- No unit restarts/re-enables under ~50% io PSI (would re-wedge instantly).
- No upstream pushes; no event-cap changes (owner-only).
- Did not chase the ~1–5s node_exporter scrapers' identity (gatus vs otel cadences) —
  moot once the dup-metric fix deploys; the conn-pile row tracks the residue.
