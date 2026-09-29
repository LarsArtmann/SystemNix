# SigNoz "Grafana Level" Gap Analysis + Journald Alternatives Landscape

**Date:** 2026-09-29
**Status:** Analysis complete. Keep-SigNoz decision REAFFIRMED (consistent with [observability-signoz-to-victoriametrics.md](./observability-signoz-to-victoriametrics.md), 2026-08-18 — no migration). Two concrete improvement items identified (retention, trace coverage); NOT yet harvested into TODO_LIST.
**Trigger:** Two-session question chain — "modern journald alternatives?" → "what makes sense for our setup?" → "what blocks SigNoz from being superb / Grafana-level?"

---

## TL;DR verdict

1. **journald stays.** There is no true drop-in replacement (it is the systemd-coupled capture sink: service stdout, kernel messages, early boot). The modern pattern is `journald → shipper → store`, and evo-x2 ALREADY runs it (OTel Collector journald receiver → SigNoz/ClickHouse).
2. **SigNoz cannot reach Grafana's ecosystem breadth** (plugins, multi-source federation, dashboard variables, on-call) — and does not need to. For a single-host homelab the real gaps are exactly two: **unbounded telemetry retention** and **sparse trace coverage**. Both are fixable locally in ~2 sessions of work.
3. **Do NOT migrate to Grafana/Loki/Tempo/VM now** — it means more daemons + re-instrumentation on a QLC-IO-constrained box for the same data. The 2026-08-18 VM migration doc's keep-SigNoz decision still holds.

---

## Part 1 — journald alternatives landscape (2025-26 web sweep)

No project replaces journald under systemd; everything is a shipper or store layered on top:

| Role | Projects | 2025-26 notes |
| --- | --- | --- |
| Shipper | Grafana **Alloy**, **OTel Collector** (journald receiver), **Fluent Bit v5**, **Vector** | Grafana Agent EOL Nov 2025 → Alloy (now "Grafana's OTel Collector distribution"); Promtail deprecated; Fluent Bit v5 went OTLP-native; Vector (Datadog-owned, still OSS) has journald source + VRL |
| Store/query | **Loki 3.x**, **VictoriaLogs**, OpenObserve, SigNoz | Loki 3.x: native OTLP ingestion + structured metadata; VictoriaLogs is the fastest-growing low-cost store |
| Avoid for new deploys | **Quickwit** | Acquired by Datadog (Jan 2025); OSS momentum effectively over |
| Classic syslog | rsyslog, syslog-ng 4.x | Closest to *partial* journald displacement (network syslog, /var/log) — cannot capture service stdout under systemd |

True journald removal only happens when leaving systemd entirely (runit/OpenRC + syslog-ng) — an init-system decision, not a logging one.

## Part 2 — what makes sense for THIS setup: already implemented

Verified in-tree this session; nothing to adopt:

- **journald hardened + bounded**: `SystemMaxUse = 8G` (`platforms/nixos/system/boot.nix:564`), `OOMScoreAdjust = -500` (boot.nix:373), journal lives on the Samsung TLC hot tier as an unsnapshotted doctrine-C subvol (`platforms/nixos/system/journal-hot.nix`, VM-tested `tests/test-journal-hot.nix`) — the QLC-churn/snapshot-pinning problem is solved.
- **The "modern stack" already runs**: OTel Collector journald receiver → SigNoz/ClickHouse with the full OTTL transform pipeline (`modules/nixos/services/signoz.nix:1129-1191`), Docker on the journald log-driver (`default-services.nix:40`), pipeline staleness monitored by Gatus + the "SigNoz journald logs pipeline stale" alert.
- **Redundancy anti-recommendations**: adding Alloy/Fluent Bit/Vector = a second shipper next to a working OTel collector; adding Loki/VictoriaLogs = a second store next to ClickHouse. Extra daemons + IO on the freeze-prone QLC box for zero new data.

Only future-trigger: remote hosts (macOS agent, rpi3-dns) → `systemd-journal-remote` forwards native journal format to evo-x2 with no new stack.

## Part 3 — SigNoz → "Grafana level": ranked blockers

### P0 — Telemetry retention is unmanaged (operational survival)

ClickHouse *internal* self-logs have converged 14d TTLs (`signoz.nix:85-611`), but the **ingested** `signoz_logs` / `signoz_traces` / `signoz_metrics` databases grow unboundedly. Our own alert names this (`signoz.nix:1331`, XFS 85%: "telemetry retention grows unboundedly … tighten TTLs in signoz.nix"). The ClickHouse data dir sits on a ~100 GiB XFS partition that **cannot shrink** — the end state of inaction is the observability stack dying with the partition. Fix: per-signal retention (SigNoz data-retention setting and/or ClickHouse TTLs on the signoz_* tables), sized so metrics keep long horizons while traces/logs are bounded.

### P1 — Traces are SigNoz's differentiator, and they are mostly dark

The Services page is trace-driven; only a handful of services emit spans (cv, crush-daily, browser-history, discordsync, dnsblockd, bank-sync, renamer/gotenberg as event-driven). Two levers:

1. **Instrument the four registry'd gaps** — overview, projects-management-automation, papdashboard, hermes (all `wiring = "upstream"` in `signoz-coverage.nix`). These are our own repos; the coverage registry already ratchets them visible. Each needs a real OTel trace SDK upstream (the overview/PMA lesson: an initialized TracerProvider with zero span sites is invisible).
2. **Add spanmetrics + servicegraph connectors** to the OTel collector — generates RED metrics (rate/errors/duration) + a service dependency graph from EXISTING spans, zero new instrumentation. This is the Grafana-Tempo-style service map without Grafana.

### Blocked upstream — metric→trace drilldown (exemplars)

Scraped Prometheus exemplars are dropped at ClickHouse export (SigNoz's schema has no exemplar columns; verified live 2026-09-14 — see dnsblockd repo `docs/research/2026-09-14_signoz-exemplar-chain-verification.md`). Spike→trace drilldown stays manual (Traces page, service + time window) until upstream ships exemplar persistence. Do not work around locally.

### Already solved — do not re-litigate

| Grafana capability | Our state |
| --- | --- |
| Alert routing/grouping | Route policies converge per ruleId (`_signoz-scripts.nix` v7 pattern); custom Discord templates with `{{$value}}` semantics understood |
| Phantom-query alert bugs | `signoz-query-lint` flake check rejects `job=` matchers, `metric_sum` suffixes, bare `up{}`, dead metrics, dashboard layout overlaps |
| Alert lifecycle (silences/acks) | PapDashboard hub + Gatus raw fast-path; adequate for a single operator |
| Availability / synthetic checks | Gatus owns ALL of it (doctrine) — never SigNoz |
| Alert coverage of the monitor | `signoz_logs_pipeline_stale` + traces-coverage collector + three self-watch rules |
| Backup / DR | `clickhouse-db-backup.timer` (daily native BACKUP, 3-run retention, pool-side) |

### Nice-to-have (skip unless bored)

- **SLOs / error budgets**: SigNoz ships SLO support in newer versions; Gatus already pages on availability, so this is cosmetic until we want error-budget dashboards.
- **Dashboard variables/annotations** (Perses v6 lacks Grafana's): our uuid5-generated static dashboards (`modules/nixos/services/dashboards/*.json`, one-query-per-panel, 5m refresh) are fine for a homelab.

## Part 4 — anti-recommendation: why not Grafana

Migrating means Grafana + Loki + Tempo (or VM/VMLogs per the 2026-08-18 doc) + re-wiring every consumer, on a host whose documented freeze class is IO saturation — for data ClickHouse already holds. The 2026-08-18 VM doc remains the correct fallback ONLY on its stated triggers (retention/IO pain that SigNoz cannot meet). Item P0 above is precisely the thing that would otherwise become that trigger — fix it in place.

## Follow-ups (not yet harvested — deliberately, research doc)

1. **[P0]** Configure SigNoz/ClickHouse retention for signoz_logs / signoz_traces / signoz_metrics (owner decision on windows, e.g. logs 14d, traces 7-14d, metrics 30-90d).
2. **[P1]** spanmetrics + servicegraph connectors in `signoz.nix` collector config + a service-map/R dashboard.
3. **[P1]** OTel trace instrumentation upstream in overview, projects-management-automation, papdashboard, hermes (flip `wiring` in `signoz-coverage.nix` as each lands).
