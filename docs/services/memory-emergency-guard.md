# Memory-Emergency-Guard — Zone 6 Runbook

**Module:** `modules/nixos/services/memory-emergency-guard.nix`
**Companion module:** `modules/nixos/services/sev1-escalation.nix` (desktop tier)
**VM test:** `tests/test-memory-emergency-guard.nix`

---

## What the guard does

A 30-second oneshot (`memory-emergency-guard.timer` → `memory-emergency-guard.service`) evaluates six trip zones. On ANY trip it stops FastFlowLM, its activation socket, and the resumable I/O churn units (btrbk root/data/pool, both balances, all three scrubs). The socket is restored automatically once memory margins recover AND the daily restore budget (default 3) is unspent.

| Zone | Signal | Class |
| ---- | ------ | ----- |
| 1 | MemAvailable < 5% | absolute floor |
| 2 | MemAvailable < 10% AND zram ≥ 92% | shmem-unevictable trap |
| 3 | PSI mem avg10 ≥ 40% AND zram ≥ 80% | refault-thrash |
| 4 | PSI mem avg60 ≥ 50% alone | slow-burn stall |
| 5 | episodic avg10 leaky bucket ≥ 8 | the calibrated 2026-08-31 freeze |
| 6 | **io PSI some avg60 ≥ 40% AND max per-disk busy ≥ 20%** | **crash #3: stacked full-disk readers livelock the scheduler while memory looks healthy** |

## Zone 6 semantics (what stops, what never auto-restarts)

On a Zone 6 trip the guard stops:

- `fastflowlm.socket` + `fastflowlm.service` — restored automatically by the guard (budget permitting).
- `btrbk-root.service`, `btrbk-data.service`, `btrbk-pool.service`, `btrfs-balance-metadata.service`, `btrfs-balance-data.service`, `btrfs-scrub--.service`, `btrfs-scrub-data.service`, `btrfs-scrub-mnt-pool.service` — **NEVER restarted by the guard.** Their own timers re-fire them once I/O drains. btrbk resumes incrementally from the newest common snapshot (no manual re-seed ever needed — the DAS-outage semantics); an interrupted receive is healed by `btrbk-pool-clean`.

**How to re-arm btrbk early** (before its next timer window):

```bash
sudo systemctl start btrbk-root.service btrbk-data.service btrbk-pool.service
```

Only do this once io PSI has actually drained (`cat /proc/pressure/io` — some avg60 < 40), otherwise the restart just re-stacks full-disk readers and the next guard tick stops them again. Check what the guard stopped at the last trip via the metrics (below) instead of the journal.

## Post-trip forensics is a prom read (2026-09-15)

`/var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom`:

- `memory_emergency_guard_zone6_trips_total` — Zone 6 trips since first deploy (counters persist in `/var/lib/memory-emergency-guard/zone-counts` across guard restarts AND reboots; no Gatus condition depends on counter monotonicity — the trip check keys on `last_trip_recent`).
- `memory_emergency_guard_io_psi_some_avg60_percent` + `memory_emergency_guard_io_disk_busy_percent_max` — the Zone 6 pair (busy is the phantom-PSI filter: D-state on dead automounts saturates io PSI with IDLE disks).
- `memory_emergency_guard_churn_units_stopped{unit="..."}` + `memory_emergency_guard_churn_stopped_timestamp_seconds` — WHICH units the guard actually stopped (were active pre-stop) and WHEN. Present only while the churn window is open; vanishes on the first run where io PSI avg60 falls back under the trip threshold.
- `memory_emergency_guard_last_run_timestamp_seconds` — freshness stamp. A frozen value means the guard is DEAD.
- Full attribution bundle per trip: `/var/tmp/io-psi-forensics-<ts>/` (cgroup io.stat, top offenders, D-state stacks) via the transient `io-psi-forensics` unit.

## Guard-death detection — the two layers

`node_exporter` serves a textfile's LAST content forever, so the "Memory Emergency Guard" Gatus check's presence pats CANNOT see a dead guard (the original check comment claimed "absent metrics" — wrong for textfile collectors). Two layers close the gap (2026-09-15):

1. **Desktop:** sev1 bridge `MEMORY GUARD DEAD` (guard .prom mtime older than `staleGuardSeconds` = 300s; notify tier after boot grace).
2. **Discord/Gatus:** the "Memory Guard Collector Fresh" check (system-health emits `system_memory_guard_metrics_fresh` from the .prom mtime; 0 = protection DOWN).

A Zone-6-shaped wedge (guard killed mid-trip with churn units stopped) is therefore visible: frozen textfile → fresh composite 0 → Gatus red, plus the stopped churn units are named by the churn metrics' last emission.

## Deploy gate vs guard Zone 6 — division of labor (no double-fixing)

Two different mechanisms cover the same IO-storm class — do not conflate them:

| | `scripts/pre-deploy-check.sh` pressure gate | guard Zone 6 |
| --- | --- | --- |
| When | deploy time only (`nh os switch` blocked, exit 12) | continuous, every 30 s |
| Action | REFUSES to deploy under pressure (some avg10 ≥ 20%, zram ≥ 90%, MemAvailable < 10%) | STOPS the churn sources + sacrifices flm |
| Escape hatch | `DEPLOY_FORCE_PRESSURE=1` | none by design (sacrifice is the mitigation) |

A deploy blocked by the pressure gate is NOT a guard bug; a Zone 6 trip during a deploy is not a gate bug. The gate protects the ACTIVATION window; the guard protects the KERNEL.

## Threshold calibration evidence (2026-09-15, first real trips)

Zone 6 deployed 2026-09-14 with first-value thresholds (40% avg60 / 20% busy). Live telemetry from the first ~1.5 days (99 Zone 6 trips):

- Trips corroborate REAL stalls, not phantoms: observed io PSI some avg60 up to ~80-90% with `io_disk_busy_percent_max` at 100% — far above both thresholds. The disk-busy corroboration filter correctly passes these (real disk activity).
- The forensics bundle from a representative trip (2026-09-15T16:01Z, io avg60 79.87%, load 84): D-state tasks in `blk_mq_get_tag` on the DAS USB disk flush thread, `usb-storage` wedged in `usb_sg_wait`, user-session crush processes dominating cumulative cgroup io.stat. The driver is the known debt: crush session DBs on the QLC root + a stalling single USB DAS link — NOT the churn units the guard stops (those are victims/multipliers, not the root driver).
- Verdict: **thresholds unchanged.** 40/20 fire only on genuinely dangerous sustained states; raising them would delay protection against the exact crash #3 signature they were built for. The structural fix is the crush-DBs-off-QLC migration (`services.crush-hot-db`, gated on the /nix soak ~2026-09-17) and the owed reboot clearing the DAS USB state — both tracked in TODO_LIST.
- Trip cadence 6/hour during storms is the expected shape: each trip stops the churn units, io recovers, timers re-fire them, storm rebuilds. `restore_capped 1` bounds the flm side of that loop. If trips persist across days AFTER the crush-hot-db deploy, revisit this calibration with fresh forensics.
