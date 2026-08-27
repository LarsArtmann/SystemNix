# 2026-08-27 15:50 — SigNoz phantom-alert purge: 6 dead rules + 1 false-positive + 4 phantom dashboard panels

Session prompt: "Can you find any bugs??" — systematic sweep of every monitoring
query (SigNoz rules, SigNoz dashboards, Gatus pat() checks) against the actual
metrics store. Found 3 distinct bug classes, fixed all of them, deployed,
verified end-to-end.

## The headline bug: `up{job="..."}` NEVER matches anything

The OTel prometheus receiver (SigNoz's scrape path) stores the scrape job as
the resource attribute `service.name`. **No series in the metrics store ever
carries a `job` label.** PromQL cannot reference dotted label keys
(`up{service.name=...}` → 400 parser error), and the underscore form
(`up{service_name=...}`) only exists on series where the scraped binary
self-reports it via its own OTel bridge (dnsblockd, pocket-id do; docker,
clickhouse, signoz-collector, emeet don't).

Six critical/warning rules queried `up{job="..."}` and returned EMPTY on every
evaluation — permanently phantom-green since provisioning (2026-08-16):

| Rule | Severity | Consequence of the phantom |
| --- | --- | --- |
| DNS Blocker Down | critical | SILENT through the live 2026-08-27 :9090 stats-API wedge (`up=0` for hours) |
| Docker Daemon Down | critical | daemon death unalerted |
| ClickHouse Down | critical | telemetry-store death unalerted |
| Telemetry Collector Down | critical | ALL ingestion loss unalerted |
| EMEET PIXY Daemon Down | warning | dead daemon unalerted |
| GPU Thermal Throttling | critical | queried `node_amdgpu_gpu_temp_celsius` — a metric with ZERO series (different trap, same effect) |

Meanwhile the **inverse bug** lived next door: "Niri Compositor Down"
(`niri_running < 1`, critical) was **actively FIRING as a false positive** the
entire time the machine was headless (SSH-only, no graphical session) — the
exact trap the Gatus layer documents and solved
(`niri_desktop_died`/`niri_graphical_session` design) but the SigNoz rule
never adopted. It fired for the whole session.

The repo had already learned this class once: the ollama rule carries the
comment "up{job=\"ollama\"} was a phantom series that could never fire" — but
only that one rule was ever converted.

## The up-series label flip (why endpoint rules need `count() or vector(0)`)

ClickHouse label forensics on the dnsblockd `up` series showed the mechanism
that makes even correct-looking selectors fail MID-OUTAGE:

- scrape SUCCESS → up=1 series carries the binary's self-reported labels
  (`service_name`, `service_version`)
- scrape FAILURE → the receiver emits a BARE-label up=0 series (no scraped
  labels — there was no scrape)
- so `up{service_name="dnsblockd"}` goes STALE (empty) exactly when the
  endpoint dies → a "below 1" rule resolves instead of firing

Fix pattern: `count(up{service_name="dnsblockd"}) or vector(0)` — absence
becomes a fireable 0. Live-tested: returned 0 during the wedge, 1 after
recovery.

## Fixes (all live-verified against `:8080/api/v1/query` before deploying)

`modules/nixos/services/_signoz-alerts.nix`:

1. **DNS Blocker Down** → `node_systemd_unit_state{name="dnsblockd.service",state="active"}` (process death, critical)
2. **NEW: DNS Blocker Stats API Wedged** → `count(up{service_name="dnsblockd"}) or vector(0)` below 1 (warning; catches the process-alive-but-API-wedged class — would have caught the 2026-08-27 incident within minutes)
3. **EMEET PIXY Daemon Down** → `system_emeet_pixyd_expected_down` ≥ 1 (session-aware gate, mirrors Gatus)
4. **Niri Compositor Down** → `niri_desktop_died` ≥ 1 (session-aware; false-positive critical resolved)
5. **Docker Daemon Down** → unit-state `docker.service`
6. **Telemetry Collector Down** → unit-state `signoz-collector.service`
7. **ClickHouse Down** → unit-state `clickhouse.service`
8. **GPU Thermal Throttling** → `max(node_hwmon_temp_celsius{chip=~".*c5:00_0"} or ClickHouseAsyncMetrics_Temperature_amdgpu_edge)` — two-source OR: hwmon chip labels are PCI-address-keyed (fragile to this box's documented post-crash bus renumbering); the ClickHouse async metric name is stable but CH-dependent; together they cover each other's blind spot. Both read 42°C live.

Dashboards:

- `gpu.json`: 2 temp panels queried the nonexistent `node_amdgpu_gpu_temp_celsius` → combined OR query; "Memory Controller Busy" panel (`node_amdgpu_mem_busy_percent`, also zero-series) removed — **including its layout `$ref` item** (first deploy failed provisioning with `references unknown panel` — panel removals must touch `spec.layouts` too; provisioner correctly hard-fails)
- `caddy.json`: `caddy_http_response_duration_seconds_sum`/`_count` and `_size_bytes_sum` → SigNoz stores histogram suffixes DOTTED (`metric.sum`); fixed to the `{__name__="..."}` selector form (avg-latency panel now returns 1.3ms; response-size panel 12 B/s — both were empty forever)
- `dns.json`: `dnsblockd_dns_resolve_duration_ms_sum`/`_count` → same dotted-name fix (verified against pre-wedge history: 38978ms cumulative)

## Sweep methodology (reusable)

1. `GET :8080/api/v1/rules` → every rule's query + live state (the journal only logs eval, not state)
2. `:8080/api/v1/query?query=...` → instant-query every selector; EMPTY ≠ healthy for always-present gauges
3. ClickHouse `signoz_metrics.distributed_time_series_v4`: `SELECT count() WHERE metric_name='X'` → phantom-metric sweep (found the GPU temp + mem-busy + histogram-suffix phantoms)
4. Gatus pat() metrics cross-checked the same way — all clean (the discordsync/bank-sync checks probe service-local `/metrics` endpoints directly and are enable-gated; their metrics correctly don't appear in the SigNoz store)

## Verification (post-deploy, system-729)

- Provisioner: `OK 26 rules, exact desired set, zero duplicates`, `OK 26 route policies one-per-rule`, `OK 5 dashboards`, `Provisioning complete: 0 errors`
- Rules API: all 7 rewritten rules `updateAt 13:23Z`; **Niri Compositor Down now inactive** (was firing); wedge rule created and inactive
- `node_systemd_unit_state{state="failed"} == 1` → empty (the two transient deploy-window failures — service-health-check caught dnsblockd mid-restart, signoz-provision hit the layout bug — both resolved)
- Side effect: the 15:32 deploy restart **healed the dnsblockd :9090 wedge** (177KB /metrics answering) — root cause still unknown, needs a SIGQUIT goroutine dump on the NEXT wedged instance; AGENTS.md forensic note updated
- post-deploy-check: 62 PASS / 9 FAIL — all 9 are the known DAS-outage class (Immich/Bank-Sync 502s awaiting physical recovery) + one Bank-Sync sync-errors WARN (same class)

## Not fixed (documented, with reasons)

- `system_signoz_alert_rules_healthy` (Gatus) only counts rules (>15) — it structurally CANNOT catch phantom queries (absence-based rules legitimately return empty when healthy). A generic detector needs per-rule expectations; noted in AGENTS.md as a known limitation.
- dnsblockd `service_version` label churn: every deploy mints a new fingerprint for all dnsblockd series (20+ historical `up` variants in CH). Bounded cardinality growth; dropping the label would need a `metric_relabel_configs` decision upstream. Left as-is.
- emeet-pixyd ":8090 scrape failing" from the previous session's report: NOT a bug — headless machine, daemon legitimately absent, Gatus's session-aware check correctly green. The SigNoz `up=0` was real but the (phantom) alert never fired; now the alert uses the gated metric and stays correctly green headless.

Files: `modules/nixos/services/_signoz-alerts.nix`, `modules/nixos/services/dashboards/{gpu,caddy,dns}.json`, `AGENTS.md` (2 new gotchas + wedge-note update).
