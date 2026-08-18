# Observability Migration: SigNoz → VictoriaMetrics Ecosystem

**Date:** 2026-08-18
**Status:** Researched, NOT scheduled. Keep-SigNoz decision made; revisit on the triggers below.
**Companion docs:** [status snapshot with measurements](../status/2026-08-18_signoz-vs-victoriametrics-research.md)

---

## Current state (verified on evo-x2, 2026-08-18)

- SigNoz stack: ~2.5 GiB RAM (clickhouse 1933M + collector 386M + query 174M), ClickHouse data dir historically 52 GiB (TTL-fixed), **2,194 lines** of SystemNix module code + provisioner + 5 dashboards
- Traces are load-bearing: 10+ services ship `OTEL_EXPORTER_OTLP_ENDPOINT`, enforced by `otel-endpoint-audit.nix`
- Gatus owns synthetic checks + Discord alerting — independent of any backend

## Recommended target stack (when migration is justified)

| Signal | Component | Why |
|---|---|---|
| Metrics | **VictoriaMetrics** `vmsingle` 1.149.0 | Single binary, Apache-2.0, ~7x compression claims, low-IOPS design (QLC-friendly), stock NixOS module (`services.victoriametrics`) |
| Logs | **VictoriaLogs** 1.52.0 | Built-in web UI, schema-free, single binary; this host's ~5 MB/h journal volume is trivial |
| Traces | **Tempo 3.0.2** monolithic + local-disk backend | Stable Parquet format (vParquet5 prod-ready), stock NixOS module (`services.tempo`), no Kafka/object-store needed at this scale, `metrics-generator` remote-writes span-metrics into VM |
| UI / dashboards | **Grafana** | One pane over all three; Tempo↔VictoriaLogs correlation via `trace_id`; nixpkgs-native |
| Alerting | **Keep Gatus + Discord** | Already proven; not coupled to the backend |

Net effect: ~2.5 GiB → well under 1 GiB; deletes the entire SigNoz/ClickHouse/provisioner maintenance surface and its documented silent-failure bug classes; every component becomes a stock nixpkgs module (~100 lines total). Only genuinely new component: Grafana (~300M RAM).

## Variant: VictoriaTraces replaces Tempo + Grafana

If **VictoriaTraces reaches v1.0 with a stable on-disk format before migration happens**, it becomes the cleaner endpoint: built-in UI (drops the Grafana dependency), same storage-engine family and vendor as VictoriaLogs, vendor claims 3.7x less RAM / 2.6x less CPU than Tempo. As of 2026-08-18 it is v0.10.0 (v0.11.0 pre-release) with an explicit upstream warning that the on-disk format may break between versions — do NOT store telemetry in it before v1.0. It is already packaged in nixpkgs with a NixOS module, so the watch check is just a version bump away.

## Rejected alternatives (why)

| Option | Reason |
|---|---|
| Jaeger v2 (Badger) | Functionally ideal (single Apache-2.0 binary, embedded storage, own UI, 23k★ CNCF) but **absent from nixpkgs** with no open packaging PR — requires a hand-rolled `buildGoModule`. High-leverage weekend packaging project if ever desired; otherwise loses to Tempo's zero-work |
| Quickwit | Datadog-acquired (Jan 2025) — long-term OSS commitment risk; nixpkgs package lags (0.8.2) with config wiring gap (nixpkgs#289000) |
| HyperDX / Uptrace | ClickHouse-backed full platforms (4-8 GB RAM) — reintroduce the exact engine class the migration removes; neither in nixpkgs |
| SigNoz traces-only hybrid | Keeps ClickHouse's RAM + ops burden while still adding VM components — worst of both |

## Revisit triggers

Revisit this doc when ANY of:

1. **VictoriaTraces v1.0** ships with stable on-disk format (primary trigger — check `nix eval nixpkgs#victoriatraces.version` or upstream releases)
2. A new **SigNoz/ClickHouse incident class** hits that isn't already documented-and-fixed in AGENTS.md
3. ClickHouse RAM/disk/IO pressure becomes a real constraint again (it isn't today: 2.5 GiB of 94 GiB)
4. Grafana is wanted for unrelated reasons (halves the marginal cost of this stack)

## Migration sketch (when triggered)

1. Deploy VM + VictoriaLogs + Tempo side-by-side (RAM headroom is ample); dual-write via the existing signoz-collector exporters (`otlp` + `prometheusremotewrite`)
2. Port the 5 dashboards to Grafana; port alert rules from `_signoz-alerts.nix` to `vmalert` or Gatus (most user-facing alerts already live in Gatus)
3. Port the journald OTTL pipeline (`signoz.nix` `transform/journald`) into an OTel collector config shipping to VictoriaLogs
4. Cut over services by flipping `OTEL_EXPORTER_OTLP_ENDPOINT` consumers (no app changes — endpoint is identical, only the audit registry target changes)
5. Decommission: `signoz.nix` + 4 helper modules + dashboards + provisioners; reclaim ClickHouse disk (incl. the ~10 GiB zombie tables noted 2026-08-17)
6. Verify with pre/post-deploy checks: update `scripts/post-deploy-check.sh` SigNoz impersonation section for the new stack
