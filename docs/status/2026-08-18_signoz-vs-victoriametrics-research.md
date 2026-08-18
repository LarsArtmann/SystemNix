# SigNoz vs VictoriaMetrics — Research & Homelab Rating

**Date:** 2026-08-18
**Context:** Evaluation whether migrating evo-x2 observability from SigNoz (ClickHouse-based, all-in-one) to the VictoriaMetrics ecosystem (VM + VictoriaLogs + VictoriaTraces + Grafana) is worthwhile.
**Method:** Live measurements on evo-x2, nixpkgs availability checks against the pinned nixpkgs, and upstream source verification (VM/VictoriaLogs/VictoriaTraces READMEs and docs). No vendor-brochure numbers accepted without a source.

---

## Measured reality (evo-x2, 2026-08-18)

| Fact | Value |
|---|---|
| SigNoz stack live RAM | **~2.5 GiB** total: clickhouse 1933 MiB + signoz-collector 386 MiB + signoz query service 174 MiB (cgroup `memory.current`) |
| ClickHouse data dir | Historically ballooned to **52 GiB** (pre-TTL-fix; 90% was unbounded internal log tables). Zombie `<log>_N` tables still hold ~10 GiB awaiting manual DROP |
| SystemNix maintenance surface | **2,194 lines** across `signoz.nix` (955) + `_signoz-alerts.nix` (290) + `_signoz-metrics.nix` (345) + `_signoz-packages.nix` (147) + `_signoz-scripts.nix` (457), plus 5 provisioned dashboards and the v7 provisioner |
| Documented SigNoz incident classes (see AGENTS.md) | Route-policy wipe-on-restart (alerts silently dropped ~30 min), 251 zombie dashboards from pre-v2 provisioner, log-table bloat (1 Hz samplers, no TTLs), migrator skipping gap migrations forever (traces 1010), `{{$value}}` zero-spaces template quirk, `background_pool_size` sanity-check traps |
| Traces | Actively wired into **10+ services** via `OTEL_EXPORTER_OTLP_ENDPOINT`; `otel-endpoint-audit.nix` *enforces* the endpoint contract at eval time |
| Gatus | Already owns synthetic checks + Discord alerting (85 alert refs in `gatus-config.nix`) — independent of either backend |
| Disk headroom at research time | `/` at 92% (62G free), `/data` at 82% (188G free) |

## VictoriaMetrics ecosystem state (verified 2026-08-18)

All versions verified against the SystemNix-pinned nixpkgs; NixOS module availability verified by evaluating `.#nixosConfigurations.evo-x2.options.services.<name>`:

| Component | nixpkgs version | NixOS module | License | State |
|---|---|---|---|---|
| `victoriametrics` | 1.149.0 | `services.victoriametrics` ✓ | Apache-2.0 (single-node AND cluster open-source) | Mature |
| `victorialogs` | 1.52.0 | `services.victorialogs` ✓ | Open source (both single + cluster) | Mature, schema-free log DB with built-in web UI |
| `victoriatraces` | 0.10.0 | `services.victoriatraces` ✓ | Open source | **WIP** — upstream README: "on-disk data structures and API endpoints may change and may not be backward compatible" |
| `vmalert` / Grafana | present | modules available ✓ | — | Mature |

Vendor-claimed benchmarks (self-reported, source: VictoriaMetrics README benchmark links):
- Up to **7x less RAM** and **7x less storage** than Prometheus/Thanos/Cortex on node-exporter metrics
- Up to 70x more data points per storage unit vs TimescaleDB
- **Explicitly optimized for high-latency IO / low IOPS** (HDD, network storage) — directly relevant to the QLC NVMe + USB DAS topology
- Single-node VM can replace medium Thanos/Cortex/M3DB clusters

Treat self-benchmarks as directional; the low-IOPS design goal is architectural ( LSM-ish parts, aggressive compression), not just marketing.

## Rating for this homelab

| Dimension | SigNoz (as deployed) | VM + VictoriaLogs (+Grafana) |
|---|---|---|
| RAM footprint | 5/10 (2.5 GiB) | 9/10 (<500M at this scale) |
| Disk & QLC-IO friendliness | 4/10 (ClickHouse merges/mutations are the worst IO citizen on this box) | 9/10 (low-IOPS design goal, ~7x compression claims) |
| Nix-native ops | 3/10 — not in nixpkgs; 2,194 hand-rolled lines with a proven silent-failure history | 9/10 — stock nixpkgs modules, ~100 lines total expected |
| Traces | 8/10 (built-in, OTLP-native, used by 10+ services) | 2/10 — VictoriaTraces is WIP v0.x with unstable on-disk format; Tempo/Jaeger reintroduce the heavy-component problem VM was supposed to remove |
| Logs | 7/10 (works, after the TTL + journald-pipeline saga) | 9/10 (purpose-built; this host's ~5 MB/h journal volume is trivial for it) |
| Dashboards/UI | 7/10 (single UI, 5 provisioned dashboards, converging provisioner) | 8/10 (Grafana ecosystem, but 3 UIs to stitch: VM UI, VictoriaLogs UI, Grafana) |
| Migration cost | — | One-time rewrite of 5 dashboards + alert rules + journald OTTL pipeline; re-point 10+ services' OTLP endpoints; Gatus unaffected |

## Verdict

**Keep SigNoz (≈6.5/10 as deployed today). The VM stack is ≈8/10 potential for this machine — blocked entirely by traces.**

Three reasons not to migrate now:

1. **Traces are load-bearing.** 10+ services ship OTLP endpoints and `otel-endpoint-audit.nix` enforces the contract at eval time. VictoriaTraces v0.10 with breaking on-disk format changes is not a bet to take on telemetry data that can't be regenerated.
2. **The ClickHouse pain is already paid.** TTLs converge, provisioner v7 converges (no delete+recreate), restartTriggers wired on all three config surfaces, schema-drift 1010 fixed. The remaining ops burden is low; the sunk cost here is real value, not a fallacy — the bug classes are fixed and documented in AGENTS.md.
3. **RAM is not the binding constraint.** 2.5 GiB of 94 GiB. The QLC-IO argument is the only genuinely compelling one, and it is now bounded by the TTL fixes and daily fstrim.

## Re-evaluation trigger

**VictoriaTraces reaching v1.0 with a stable on-disk format.** At that point the full VM trio becomes strictly better for this machine: single binaries, low-IOPS-optimized, nixpkgs-native modules, deletes 2,194 lines of maintenance surface and the entire provisioner-silent-failure bug class. Track as a standing TODO, not a migration this quarter.

---

## Traces deep-dive (follow-up research, 2026-08-18)

Sources: web research (Tempo 3.0/Jaeger v2 release notes, jaegertracing.io docs, VictoriaMetrics blog/changelog), GitHub repo stats via API (stars/last-push/license), nixpkgs eval against the pinned nixpkgs, and nixpkgs issue tracker.

### Ingestion is already standardized

All ~10 instrumented services speak OTLP to `localhost:4317/4318`; `otel-endpoint-audit.nix` enforces the contract. Any OTLP-native backend = zero app changes; only the audit registry + collector exporters change. Volume is trivial (100% head-sampling, weeks retention, sub-GB) — throughput benchmarks are irrelevant; **format stability and query UX are everything**.

### Candidate matrix (all fields verified)

| Rank | Option | GitHub health (verified) | nixpkgs (pinned) | Storage | License | Rating |
|---|---|---|---|---|---|---|
| 1 | **Tempo 3.0.2** monolith + local disk | 5.4k★, pushed 2026-08-17 | ✅ pkg 3.0.2 + `services.tempo` module | Parquet vParquet5 (prod-ready, stable) | AGPL-3.0 | 9/10 |
| 2 | **Jaeger v2.20** + embedded Badger | 23.1k★, CNCF graduated, pushed 2026-08-17; v1 EOL 2025-12-31 | ❌ absent — no package, **no open packaging PR/issue** | Badger (embedded, mature; CH backend alpha) | Apache-2.0 | 7/10 |
| 3 | **VictoriaTraces** 0.10.0 (v0.11.0 pre 2026-08-14) | 456★, very active | ✅ pkg + module | logstorage engine (VictoriaLogs-derived) | Apache-2.0 | 6/10 |
| 4 | Quickwit 0.8.2 | 11.5k★, **acquired by Datadog (Jan 2025)** | ✅ pkg (stale; config gap nixpkgs#289000) | object-storage Tantivy | Apache-2.0 | 4/10 |
| — | HyperDX 2.35 / Uptrace 2.0 | mature, active | ❌ neither packaged | ClickHouse + Mongo / PG+Redis | AGPL | 2/10 |
| — | SigNoz traces-only hybrid | — | ❌ | ClickHouse | AGPL | worst of both worlds |

### Per-option notes

- **Tempo**: monolithic mode = one process, no Kafka, `local` filesystem backend is fine at this scale (docs: "suitable for small installations"). Sequential Parquet block writes = QLC-friendly; retention = block deletion; backup = rsync a directory (fits the pool pattern). `metrics-generator` remote-writes span-metrics into VictoriaMetrics, preserving metrics-from-traces dashboards. Trace↔log correlation with VictoriaLogs via `trace_id`. Needs Grafana as UI (~300M RAM, nixpkgs-native). License AGPL (same class as SigNoz — irrelevant for personal use).
- **Jaeger v2**: functionally the *ideal* homelab design — single Apache-2.0 binary, embedded Badger storage ("only suitable for single-node deployment" per docs = exactly this case), built-in UI (no Grafana), OTel-Collector-based. Sole sin: absent from nixpkgs. Packaging is one bounded `buildGoModule` (~150 lines, upstreamable — a high-leverage weekend project if ever wanted).
- **VictoriaTraces**: best resource claims (vendor: 3.7x less RAM / 2.6x less CPU vs Tempo), no external deps, but pre-1.0 with explicit on-disk-format breakage warnings; Tempo API support (Grafana Traces Drilldown) still experimental. Watchlist — if it reaches v1 stable before a migration happens, it drops the Grafana dependency and becomes the cleanest endpoint.
- **Quickwit**: Datadog acquisition makes long-term OSS commitment a risk factor; nixpkgs package lags and lacks config-file wiring.
- **HyperDX/Uptrace**: full-platform ClickHouse stacks (4-8 GB RAM) — reintroduce exactly the engine class the migration would remove.

### Trace decision

- **Today:** keep SigNoz (all three signals, already paid for).
- **On VM migration:** traces land on **Tempo monolithic + local backend + Grafana**, span-metrics → VM, VictoriaLogs ↔ Tempo via `trace_id`. Jaeger v2 is the runner-up contingent on packaging effort; VictoriaTraces is the future wildcard.
