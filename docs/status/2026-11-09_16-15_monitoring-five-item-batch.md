# Monitoring five-item batch (task 000001a1bf60aa5348fa309ba6f300000000) — close-out

2026-11-09 ~16:1x CET · evo-x2 · HEAD lineage: e49f069ae → 4228b08d0 (item 1) → 372bf9371 (item 3) → this report (items 2/4/5 + ticks).

## What landed

### Item 1 — PapDashboard ingest freshness observability (4228b08d0)

The 11-07 ingest-REFUSED window was invisible to the existing journal-count gauges: with papdashboard dead, `path=/api/ingest` lines vanish, so ok_1h=0/total=0 reads as "quiet hour", not "dead service" — and the alerting channel that could have said so (gatus→papdashboard custom provider) is exactly what died.

Landed (modules/nixos/services/system-health.nix + gatus-config.nix):

- `system_papdashboard_ingest_reachable` — direct TCP connect to 127.0.0.1:8088 per scrape (dead ≠ quiet, the signal journal counts structurally cannot give).
- `system_papdashboard_ingest_last_ok_timestamp` — unix seconds of the NEWEST status=200 ingest line, unbounded window (a fixed lookback would fake staleness on quiet days).
- Gated gatus "PapDashboard Ingest" check (papIngestEnabled-only) on reachable=1 + scrape_errors=0 + presence of the timestamp line. Discord-only alerts by design: when this fires the papdashboard provider is down and every custom-provider send fails with it.
- README gatus endpoint count re-stamped 285→286 (caught by the doc-counts gate; the re-stamp history line appended).
- Verified: `nix flake check` green inside the pre-commit hook; eval green (`nix eval ...toplevel.drvPath` rc=0). NOT yet deployed — the gauges go live with the next deploy.

### Item 2 — drop time_series_v2 [decision] — PARKED on owner

`tq ask` question 55a39b9a3a3088f1 recorded (options drop/keep, expires 2026-11-12). `DROP TABLE signoz_metrics.time_series_v2` + `distributed_time_series_v2` needs a human hand (agent shells cannot sudo). The enforcement half did NOT wait: both table names are now in the signoz-query-lint deadMetrics blocklist (see item 3), so the drop decision only decides disk reclaim, never query safety.

### Item 3 — residual time_series_v2 sweep + blocklist (372bf9371)

Full-tree sweep: ZERO live references in dashboards JSON (`modules/nixos/services/dashboards/*.json`), `_signoz-alerts.nix`, or scripts — only historical status/planning narratives, which stay as history. `time_series_v2` + `distributed_time_series_v2` added to `signoz-query-lint` deadMetrics with the 2026-11-09 live-probe provenance; the check builds green.

### Item 4 — k10temp 99.8 °C 24h-max provenance — premise REFUTED

ClickHouse probe (`samples_v4` ⋈ `time_series_v4` labels, chip-filtered): the 24h-max k10temp (`pci0000:00_0000:00:18_3`/temp1) sample is **99.75 °C at 2026-11-08 17:49:32 CET**. `journalctl --list-boots`: current boot 0 (309f2cb8) started 2026-11-07 01:06:40 and runs continuously through 11-09 — the peak sits INSIDE a fully recorded, still-running boot. Not a freeze-era boot, not unrecorded: the thermal-pstate-guard journal shows repeated `THERMAL THROTTLE ENTER` (guided) / `DEEP THROTTLE ENTER` (freq capped) / `DEEP THROTTLE DROP` cycles at k10temp 98–99 °C through the 11-08 16:00–17:5x window — a live guard-absorbed ceiling excursion with no cut. The hwmon fingerprint table row in docs/agents/monitoring.md now carries this verdict so the "99.8 = crash-era max" phrasing stops implying the 24h-window hits are crash-adjacent.

### Item 5 — vendorHash-wave post-deploy-check on a wave-carrying generation

Ran `scripts/post-deploy-check.sh` against live (2026-11-09 ~15:58): generation system-992 == /run/current-system (anchored, drv `p85gcdknj19…`). Wave units PID-exe-verified at/past their wave revs: dnsblockd 696c73e, bank-sync fab93068, inboxclean e553c51, tq 0.4.1 (go-taskqueue) — all descendants of the wave revs (ab2c9dcd / b514bda / 36f9d64b / b90b306).

Result: **PASS 169 / FAIL 4 / SKIP 4 / WARN 15 / STORM-SUSPECT 0** at io avg10 71% (storm-building band). The 4 FAILs ALL match the previous run's baseline (advisory exit 1): Health Hub /readyz 503 (remote dark), Offsite Borg tripwire binary not executable, tq-agent-pool 256% CPU (harvest burst), node-exporter journal 505/min. The batch's requested legs are green: SigNoz impersonation PASS (Pocket ID sole auth boundary), auth-gateway vHost 200s across the wave (banksync/tq/etc.), SigNoz coverage traces_missing 0. Log preserved at ~/.cache/pdc-1558.log (volatile — contents narrated here).

## f. Follow-ups (deliberately NOT harvested as queue rows beyond what TODO_LIST already carries)

1. The new ingest gauges need a post-deploy probe (`system_papdashboard_ingest_reachable 1` + timestamp in the textfile) once the deploy lands — existing row at docs/todo/monitoring.md line 37 (the 2026-10-28 ingest-probe batch verify) covers the family; folded there rather than duplicated.
2. README line 18 "52 alert rules" vs the gatus-286 stamp: rule-count stamping is enforced by doc-counts already; no action.
3. Health Hub /readyz 503 FAIL (baseline-advisory) deserves its own triage row if it persists — not harvested here (pre-existing, outside batch scope).
