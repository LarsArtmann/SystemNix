# signoz (self-hosted observability platform)

**Service:** `services.signoz` — `modules/nixos/services/signoz.nix` (SigNoz CE from the pinned `signoz-src` fork + patched otel-collector; packages in `_signoz-packages.nix`, alerts/dashboards in `_signoz-alerts.nix` + `dashboards/*.json`, provisioner scripts in `_signoz-scripts.nix`). URL: `signoz.<domain>` (**Layer 2 protected** vHost via the registry — the app itself runs in impersonation mode with NO internal auth). Ports (`lib/ports.nix`): query service **8080** (`signoz`), OTLP gRPC **4317** / HTTP **4318** (collector ingest), collector self-metrics **8888**, ClickHouse **9000** / metrics **9363**, cAdvisor **9193**.

Fleet telemetry backbone: traces/metrics/logs from every OTel-instrumented service, the journald log pipeline, node/cAdvisor/caddy/docker scrapes, alert rules → Discord. The deep API gotcha library (alert routing, `{{$value}}` templating, query lint traps, dashboards) lives in [docs/agents/monitoring.md](../agents/monitoring.md#signoz) — this runbook covers service operation.

## What it serves

| Route / port           | Auth            | What                                                                   |
| ---------------------- | --------------- | ---------------------------------------------------------------------- |
| `:8080/` + `/api/v1/*` | impersonation   | Web UI + query/rules/dashboards API — every request acts as root admin |
| `:4317` / `:4318`      | none (loopback) | OTLP ingest (traces + metrics + logs from fleet services)              |
| `:8888/metrics`        | none (loopback) | Collector self-metrics (export failures, receiver liveness incl. GCP)  |
| `:9363/metrics`        | none (loopback) | ClickHouse prometheus endpoint (parts, merges, memory)                 |
| `:9193`                | none (loopback) | cAdvisor (`--docker_only`, docker-engine container metrics)            |
| `:8080/api/v3/rules`   | impersonation   | Alert rules + states (used by probes; see monitoring.md). **`/api/v1/rules` now serves the SPA's index.html** (package move, live-verified 2026-11-13) — the v3 endpoint is the data path: paginated (default page = 20, pass `limit=100`), and `data.total` = the exact rule count for parity checks |

## Ops

- **Impersonation mode** — SigNoz CE OIDC/SAML is Enterprise-only; the wrapper exports `SIGNOZ_IDENTN_IMPERSONATION_ENABLED=true` + root user env. The root password is an openssl-generated 48-byte value in `/var/lib/signoz/root-password` (0400, created once). External auth is Caddy's job (protected vHost); LAN access is open by design.
- **Configs are read at STARTUP ONLY — restartTriggers are mandatory and wired** — `signoz.yaml` + web dist (query service), `collector.yaml` (collector), clickhouse `extraServerConfig` all carry restartTriggers. A config deploy without them is silently inert (the 2026-08-16 `ruleSource=localhost` bug was exactly this: external_url baked into every rule at construction).
- **otelcol config validation is fail-fast per receiver at startup (2026-10-12)** — otelcol v0.144 rejected `hostmetrics.filesystem.exclude_fs_types` with an empty `match_type` (`unrecognized match_type: ''`, valid: `strict|regexp`) → the WHOLE collector crash-looped to start-limit-hit (fleet telemetry blind until the fix deploy). Fix: explicit `match_type = "strict"`. Class rule: every new receiver/scraper knob gets boot-tested against the real binary BEFORE deploy — the signoz fork has no `validate` subcommand, so render the yaml (`nix eval --raw .#nixosConfigurations.evo-x2.config --apply 'c: c.environment.etc."signoz/collector.yaml".text'`) and run `timeout 25 <collector-bin> --config <rendered>`: exit 124 after `Everything is ready` = healthy, fast `fatal` = config bug enumerated in the log. CAVEAT (2026-10-12 session): the boot test binds the REAL ports (4317/4318/8888) and exports to the real ClickHouse — only safe while the prod collector is DOWN (else the bind failure reads as a false config negative AND telemetry dual-writes); to validate while alive, rewrite the rendered yaml's endpoints to throwaway ports first.
- **Provisioner CONVERGES, never delete+recreate** — `signoz-provision` (oneshot, restartTriggers on script + every rule/dashboard source) deploys the Discord channel ("Discord Alerts", webhook from sops `discord_alert_webhook_url`), alert rules (canonical-projection diff → PUT preserves ruleIds), route policies (API-created ones are WIPED by signoz restarts — the provisioner re-runs on every deploy), and dashboards via the v2 API. Delete+recreate mints fresh ruleIds ⇒ fake RESOLVED/FIRING Discord pair per rule per deploy; zombie copies are tag-filtered and swept. **Alert ROUTING is exclusively route policies** (`name == ruleId`), never `preferredChannels` — see monitoring.md.
- **Evaluator deadman (`signoz-evaluator-deadman.nix`, 2026-10-20)** — the rule evaluator can go SILENT while the unit stays "active" (2026-10-12: 13.5 min, no stop/fail/error line, mechanism unknown, clickhouse-storm correlated) — in that state EVERY SigNoz rule is blind and none can self-report. The collector (2-min timer, own `signoz-evaluator-deadman.prom` — deliberately NOT system_health.prom and its whole-file-rejection history) measures journal recency of `evaluating promql query` lines in signoz.service: `system_signoz_evaluator_alive` (0 when newest line older than 600s or journal query failed — fail-closed), `..._log_age_seconds`, `..._scrape_errors`. The paging leg is the gatus check "SigNoz Evaluator Deadman" (independent process + independent Discord path — it fires exactly when the evaluator cannot). Detection latency ~10-12 min (threshold 600s + 2min collector + 2min gatus). Deliberately does NOT watch gatus (that's the Gatus Down unit-state rule) and does NOT cover both-dying-together (owner decision row, docs/todo/monitoring.md).
- **ClickHouse lives on a dedicated XFS partition and is fail-closed on it** — `/var/lib/clickhouse` is XFS (label `clickhouse`); when the host declares the mount, clickhouse.service gets `RequiresMountsFor` + `ConditionPathIsMountPoint` (belt AND suspenders) — the mount absent ⇒ server refuses to start (never writes telemetry to the root fs under the mount). A `+`-privileged ownership heal runs at ExecStartPre (interrupted-migration mis-owned inodes crash-loop CH with EACCES). Migration runbook: `scripts/migrate-clickhouse-xfs.sh` (prepare BEFORE first deploy, finalize after). Monitoring: `clickhouse-xfs-metrics` (5-min, real-I/O gated, fail-closed) + Gatus "ClickHouse Data Mount" / "ClickHouse Data Usage" (85%).
- **Internal log retention = 14d TTLs** — every ClickHouse internal log family (trace_log, query_log, metric_log, …) carries a TTL in extraServerConfig; `signoz-clickhouse-log-ttl` (daily 04:20, `partOf clickhouse.service`) ALTERs tables that predate it incl. zombie `<name>_N` copies from unclean restarts. **`metric_log` is WIDE** (~274KB column metadata): `MODIFY TTL` fails `QUERY_IS_TOO_LARGE` → the script falls back to monthly partition drops (that table's recurring retention mechanism). Permanently read-only tables (crash leftovers) are reported for a human DROP, never auto-dropped.
- **Backup: the ONLY leg is `clickhouse-db-backup`** (03:00 nightly) — native server-side `BACKUP ALL EXCEPT DATABASES system, INFORMATION_SCHEMA` → `/mnt/pool/backups/clickhouse` (3-run retention, `.last_success` → backup-coordination; the pool leaf dir is created by `clickhouse-db-backup-dir`, mount-gated). XFS is invisible to btrbk by design — restore means `RESTORE` from these dirs, and the recovery point must PREDATE any schema migration you are rolling back past. `File()` destinations are refused unless listed in `<backups><allowed_path>` (extraServerConfig).
- **ClickHouse package is version-pinned via `clickhouseVersionPinOverlay` (`overlays/linux.nix:252`)** — the 2026-10-02 nixpkgs bump (`b4fd65b1`→`c59305ba`) changed the clickhouse DERIVATION while the version string stayed 26.8.7.19-lts; cache.nixos.org carries no clickhouse binary, so every deploy rebuilt it from source (~1h16m measured, 2026-10-03). The overlay imports the pre-bump nixpkgs `7a0f122f` for clickhouse ONLY, reproducing the already-built store derivation (`1rb0ambr…-clickhouse-26.8.7.19-lts`) bit-for-bit. Live-verified 2026-10-04: gen-821 unit `ExecStart` and the running process both on `1rb0…` across 7 deploys + 4 reboots. **Drop condition:** `nix path-info --store https://cache.nixos.org <current-drv>^out` (or successors) starts hitting — drop the overlay in one edit. **Caveat:** the version string does NOT identify the derivation — always compare `.drvPath`, not the version, when deciding whether a bump is free.
- **Journald pipeline** — receiver `all=true, priority=info, start_at=end` (**NEVER "beginning"**: no persistent cursor — a restart would re-ingest the whole journal); the `transform/journald` OTTL processor extracts `body=MESSAGE`, severity from PRIORITY, `service.name` (SYSLOG_IDENTIFIER < _SYSTEMD_UNIT < CONTAINER_NAME); OTLP logs from instrumented services pass untouched. Docker containers log via journald driver → container name becomes the service.
- **Collector pipelines** — traces: `memory_limiter → signozspanmetrics/delta → batch → clickhousetraces + servicegraph` (RED metrics + service dependency graph, both added 2026-09-29); metrics: OTLP + prometheus scrapes (node-exporter, cadvisor, caddy :2019, pocket-id :9464, dnsblockd, emeet-pixyd, signoz-collector self :8888, clickhouse :9363, docker-engine) + GCP receivers; logs: OTLP + journald. Scrapes run 30s interval / 25s timeout (node_exporter textfile churn).
- **GCP Cloud Monitoring integration** — `services.signoz.gcpMonitoring` (see [signoz-gcp-monitoring.md](./signoz-gcp-monitoring.md)): `googlecloudmonitoring/<project>` receivers on the EXISTING collector. **Currently containment-disabled** — `google.FindDefaultCredentials` runs at receiver Start() and an unparseable/invalid key is FATAL for the whole collector (no safe inert state); flip only with the real key in sops. Gatus "GCP Metrics Receiver" checks receiver liveness.
- **Eval assertion** — `background_pool_size` must never be set to 2 (ClickHouse sanity-check cascade; keep default 16 — details in monitoring.md ClickHouse traps).

## Live-probe cheat-sheet (verify capabilities, never doc-parrot)

The 2026-10-09 self-review's #1 finding was asserting capability from docs without probes. Copy-paste battery (all loopback, no auth):

```bash
# Spans/h per service (are traces flowing, for whom?)
clickhouse-client --query "SELECT serviceName, round(count()/24,1) AS spans_per_h, max(timestamp) FROM signoz_traces.distributed_signoz_index_v3 WHERE timestamp > now() - INTERVAL 24 HOUR GROUP BY serviceName ORDER BY spans_per_h DESC"

# Does a metric EXIST at all (phantom-metric sweep)? Swap metric_name.
clickhouse-client --query "SELECT metric_name, temporality, count() FROM signoz_metrics.distributed_time_series_v4 WHERE metric_name LIKE 'PREFIX%' GROUP BY metric_name, temporality"
# Same probe wrapped with type + verdict (exit 1 = phantom): use this before
# writing ANY query name — the dotted-vs-underscore form is decided by the
# exporter's TYPE declaration, never by name shape (2026-10-18 regression).
scripts/metric-exists.sh 'PREFIX%'

# Whole-tree store-truth sweep: every dashboard+alert metric reference vs the
# store in one batched probe; fails on any zero-series name off the allowlist
# (scripts/metric-sweep-expected-absent.txt). Harness legs: CASES=metricnames.
scripts/metric-sweep.sh

# Is a series PromQL-visible? (DELTA-blindness: delta-temporality metrics
# return 0 series via the v1 API despite fresh samples — see below)
python3 -c "import urllib.request,json,urllib.parse; print(len(json.load(urllib.request.urlopen('http://localhost:8080/api/v1/query?'+urllib.parse.urlencode({'query':'count(METRIC_NAME')})))['data']['result']))"

# Log→trace pivot health (lines carrying trace_id vs total, 7d)
# `trace_id != ''` is the zero-trace form — the journald fleet stores
# unlinked lines' trace_id as the EMPTY string, so never compare against
# the 32-zeros literal (it false-positives every journald line as traced,
# 2026-11-12). length(trace_id)=32 is the strict real-W3C-id form.
clickhouse-client --query "SELECT countIf(length(trace_id) = 32), countIf(trace_id != ''), count() FROM signoz_logs.distributed_logs_v2 WHERE timestamp >= toUnixTimestamp64Nano(now64(9) - INTERVAL 7 DAY)"

# Rule/policy parity (live vs _signoz-alerts.nix; policies keyed by rule UUID)
# /api/v1/rules serves SPA HTML since the package move — use v3 + limit=100
# (default page is 20); data.total is the exact parity count.
python3 -c "import urllib.request,json; d=json.load(urllib.request.urlopen('http://localhost:8080/api/v3/rules?limit=100',timeout=15))['data']; print(d['total'], [x['alert'] for x in d['rules'] if x['state']!='inactive'])"

# Historical/instant queries through the v3 dashboard-panel path (query_range).
# The v3 payload shape the dashboard panels actually speak (derived 2026-11-12
# after ~6 failed probes; start/end are epoch MILLISECONDS, step is INT64
# SECONDS — a string step fails `cannot unmarshal string into ... step of
# type int64`):
#   compositeQuery: {panelType: "graph", queryType: "promql",
#                    promQueries: {"a": {query: "...", legend: "..."}}}
# Results land under data.result[<i>].series[] keyed by queryName (not the
# v1-style flat result set). The v1-era `Queries []QueryEnvelope` list form
# still parses as a field but routes NOWHERE (400 `unknown field "query"` on
# the inner payload, live-verified 2026-11-13) — only promQueries works.
python3 - <<'PYEOF'
import urllib.request, json, time
now = int(time.time()*1000)
p = {"start": now-15*60*1000, "end": now, "step": 60,
     "compositeQuery": {"panelType": "graph", "queryType": "promql",
       "promQueries": {"a": {"query": "system_service_memory_throttle_designed"}}}}
req = urllib.request.Request('http://localhost:8080/api/v3/query_range',
    data=json.dumps(p).encode(), headers={'Content-Type': 'application/json'})
r = json.load(urllib.request.urlopen(req, timeout=20))
print(sum(len(x.get('series', [])) for x in r['data']['result']), 'series')
PYEOF
```

**PromQL is DELTA-BLIND — engine-level, not an API-version artifact (live-verified 2026-10-10; scope widened 2026-11-13):** Delta-temporality metrics return 0 series through EVERY PromQL path — the v1 instant API AND the v3 `query_range` dashboard-panel path (A/B-probed: gauge 8 series vs Delta families 0 on the same payload). `signoz_calls_total`, `signoz_latency.*` (the `signozspanmetrics/delta` connector output) and receiver-ingested DELTA-only families (GCP counters/latencies) are unreachable from PromQL dashboards/alerts despite fresh samples (check `temporality` in `distributed_time_series_v4`). Only **Cumulative** metrics (`traces_service_graph_*`, node_exporter, all scraped prometheus metrics) are PromQL-reachable. **The one exception is the query-BUILDER path (live-verified 2026-11-13):** a `builderQueries` panel (`queryType:"builder"`, `aggregateOperator:"sum_rate"`, `temporality:"Delta"`) over a DELTA-only counter returns series — the native Services page's route, and the only way to render DELTA-only families (GCP request-rate/latency panels). Consequence: dashboards/alerts must otherwise consume the cumulative family or scraped metrics — `dashboards/traces.json` is built entirely on `traces_service_graph_*` for this reason.

## Related

- [docs/agents/monitoring.md#signoz](../agents/monitoring.md#signoz) — the deep gotcha library: route policies, `{{$value}}` zero-spaces rule, job= label traps, dashboards one-query rule, exemplar drop, schema-drift migration gaps
- [signoz-coverage.md](./signoz-coverage.md) — the OTel traces coverage registry + collector (which services actually emit spans)
- [signoz-gcp-monitoring.md](./signoz-gcp-monitoring.md) — GCP integration runbook (SA keys, presets, DELTA-only constraint)
- [docs/agents/storage.md](../agents/storage.md) — the XFS partition decision + snapshot doctrine
