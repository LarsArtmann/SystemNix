# SigNoz Telemetry Coverage (`services.signoz-coverage`)

The "register EVERY service FULLY with SigNoz" rail. SigNoz's Services page is
**trace-driven**: a service appears only if its binary actively pushes OTLP
spans. The journald logs pipeline (80+ services) and the prometheus receiver
(9 scrape jobs) are invisible there. Before this module, only 6 binaries ever
pushed spans and NOTHING noticed when a service went dark or never lit up.

Module: `modules/nixos/services/signoz-coverage.nix` (enabled in
`configuration.nix`). Status report: `docs/status/2026-08-31_21-33_signoz-trace-coverage-audit-self-review.md`.

## The three layers

1. **Eval-time assertions** (fail `nix flake check` / eval):
   - Forward: a registry entry with `wiring = "env"` whose unit exists MUST set
     a non-empty `OTEL_EXPORTER_OTLP_ENDPOINT` on that unit.
   - Reverse: EVERY systemd unit setting that env var MUST be a registry key
     (or listed in `untrackedOtelUnits` with a reason) — the structural
     "no silent noop" rule (the fastflowlm class: env var on a binary with no
     OTel SDK is a pure lie).
2. **Runtime collector** (`signoz-coverage-metrics.service`, 5-min timer):
   reads ClickHouse DIRECTLY (never the SigNoz API — gatus-sqlite doctrine)
   for last-span-per-service and logs-pipeline freshness. Fail-closed: query
   failure writes `scrape_errors 1` and forces `missing` to the full enforced
   count — never a phantom green.
3. **Alerting**: Gatus checks ("SigNoz Traces Coverage", "SigNoz Logs Pipeline
   Fresh", "SigNoz Trace Gap Budget") + SigNoz self-watch rules
   (`_signoz-alerts.nix`: traces-coverage-missing, coverage-collector-errors,
   logs-pipeline-stale).

## Registry maintenance

Register every service that pushes traces (mandatory per AGENTS.md "Adding a
Service" step 10):

```nix
services.signoz-coverage.expected.my-unit = {
  serviceName = "what-the-binary-reports";  # NOT necessarily the unit name (cv-server → cv-application)
  wiring = "env";       # "env" (unit carries OTEL env) | "config" (service-native config)
  maxAgeHours = 26;     # 26 dense, 720 event-driven (renamer, gotenberg)
};
```

- `wiring = "upstream"` = KNOWN GAP: binary cannot emit yet. Counted in
  `signoz_traces_upstream_gaps`, non-paging. **The gap budget ratchets**:
  `services.signoz-coverage.maxUpstreamGaps` (int, default tracks the current
  debt) — exceeding it emits `signoz_traces_upstream_gaps_over_threshold 1`
  and Gatus pages. Lower it as gaps close; raising it is a conscious commit.

## Flip procedure (upstream instrumentation lands)

1. Push + tag the upstream repo (user-owned step — agents never push).
2. `nix flake lock --update-input <repo>` (expect a go-modules FOD vendorHash
   mismatch — paste the `got:` hash; SystemNix-side overrides live in the
   service module when upstream's own hash is stale).
3. Flip the registry entry `wiring = "upstream"` → `"env"` (or `"config"` for
   service-native config like dnsblockd's `otlp_endpoint`).
4. **Lower `maxUpstreamGaps` by one.**
5. `nix flake check --no-build` → `nix run .#deploy`.
6. Verify spans + enforcement:
   ```bash
   clickhouse-client --query "SELECT serviceName, count() FROM signoz_traces.distributed_signoz_index_v3 WHERE serviceName = '<service>' AND timestamp > now() - INTERVAL 30 MINUTE GROUP BY serviceName"
   grep -E '<service>|missing' /var/lib/prometheus-node-exporter/textfile_collectors/signoz-coverage.prom
   ```
   The service must now appear at https://signoz.home.lan/services.

## ClickHouse query cheat-sheet (schema traps)

The two tables have INCOMPATIBLE timestamp types — schema-verify before
writing SQL:

| Table | timestamp column | Convert to epoch ms |
|---|---|---|
| `signoz_traces.distributed_signoz_index_v3` | `timestamp` DateTime64(9) | `toUnixTimestamp64Milli(timestamp)` |
| `signoz_logs.distributed_logs_v2` | `timestamp` **UInt64 NANOSECONDS** | `intDiv(max(timestamp), 1000000)` |
| `signoz_metrics.distributed_samples_v4` | `unix_milli` (already ms) | as-is; join `time_series_v4` on fingerprint for labels; `samples_v2` is EMPTY |

Service name columns: traces = `serviceName`; logs = `resources_string['service.name']`.

```sql
-- services that EVER sent spans (the /services page, all-time)
SELECT serviceName, count() FROM signoz_traces.distributed_signoz_index_v3 GROUP BY serviceName ORDER BY 2 DESC;

-- last span per service (last 40 days covers every maxAgeHours budget)
SELECT serviceName, max(toUnixTimestamp64Milli(timestamp)) FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp > now() - INTERVAL 40 DAY GROUP BY serviceName;

-- logs pipeline freshness (ns → ms!)
SELECT intDiv(max(timestamp), 1000000) FROM signoz_logs.distributed_logs_v2
WHERE timestamp > toUnixTimestamp(now() - INTERVAL 1 DAY) * 1000000000;
```

## Metrics reference

| Metric | Meaning |
|---|---|
| `signoz_traces_expected{service}` | 1 per registry entry |
| `signoz_traces_reporting{service}` | 1 = span within its freshness budget |
| `signoz_traces_last_span_age_seconds{service}` | -1 = never seen |
| `signoz_traces_missing` | enforced services dark RIGHT NOW (healthy: 0) |
| `signoz_traces_upstream_gaps` | instrumentation debt count |
| `signoz_traces_upstream_gaps_over_threshold` | budget breach (healthy: 0) — fires Gatus |
| `signoz_logs_pipeline_{age_seconds,stale}` | journald pipeline freshness (stale > 30 min) |
| `signoz_coverage_scrape_errors` | collector ClickHouse queries failed (fail-closed pair with forced-high missing) |

## Known gaps (2026-08-31, post bank-sync flip)

- **dnsblockd** — upstream fix (scheme-aware transport, `WithInsecure`) applied
  in the dnsblockd checkout but not pushed; `otlp_endpoint` config key already
  live. Flip to `wiring = "config"` after push + input bump.
- **overview, projects-management-automation** — TracerProvider initialized,
  zero `tracer.Start` sites upstream (perfect noops).
- **papdashboard** — OTel metrics only, no trace SDK.
- **hermes** — Python, opentelemetry-sdk not wired.

Docker containers (twenty, manifest) and config-wired services are invisible
to the reverse assertion (env not eval-visible) — extend `untrackedOtelUnits`
never, register always.
