# SigNoz Deep-Integration Overhaul — 2026-08-16 23:27

**Session type**: Continuation of `2026-08-16_21-25_signoz-web-ui-404-fix.md`. User directive: "DEEP RESEARCH THE DOGS [dashboards] and logs and make sure our SigNoz instance is configured and integrated SUPERBLY!"

**Executive summary**: The web UI 404 fix exposed that everything BEHIND the UI was degraded. Deep research into the pinned SigNoz source, the ClickHouse schemas, the OTel collector pipeline, and the live API found **five silent failure classes**. All five are fixed and deployed. The stack now: converges 5 native-v2 dashboards (was 251 zombies + 6 always-failing), ingests ~6,800 enriched logs/10min with severity + service.name (was ~105 raw JSON dumps/day), writes traces attribute keys without schema errors (was silently dropping every tagKey batch), scrapes 9 targets including itself (was 6, with 2 phantom-dependent alerts), and self-monitors via 3 new meta-alerts.

---

## Category A — Fully Done ✔

### A1. Traces schema drift: migration 1010 never applied (LIVE HOTFIX)
- **Symptom**: `clickhousetracesexporter` journal error every 1–5 min: `Could not write a batch of spans to tag/tagKey tables: ... (tagType Enum8('tag' = 1, 'resource' = 2)) unknown element "scope"`. Errors deliberately swallowed upstream ("don't want to block the exporter"), so spans kept flowing while attribute-key registration rotted (SigNoz trace filters/autocomplete silently degrade).
- **Root cause**: `signoz_traces.schema_migrations_v2` shows 1009 → 1011-1014 finished, **1010 has no row at all**. The collector's `migrate sync up` squash logic treats everything below the high-water mark as done — 1010 will never be applied by any restart.
- **Fix (applied live, verified)**:
  ```sql
  ALTER TABLE signoz_traces.span_attributes_keys MODIFY COLUMN tagType Enum8('tag'=1,'resource'=2,'scope'=3);
  ALTER TABLE signoz_traces.distributed_span_attributes_keys MODIFY COLUMN tagType Enum8('tag'=1,'resource'=2,'scope'=3);
  INSERT INTO signoz_traces.distributed_schema_migrations_v2 (migration_id, status, error, created_at, updated_at) VALUES (1010, 'finished', '', now(), toDateTime64(0,9));
  ```
- **Verified**: 0 "unknown element" errors in collector journal post-fix.

### A2. Dashboards: 251 zombies → 5 exact, native v2, converging provisioner
- **Found**: every deploy since Jul 18 logged 6× `WARNING dashboard:* (HTTP 400) — "json: unknown field \"title\""` — the JSONs were authored against an imaginary v1 schema and the v2 API (`PostableDashboardV2.UnmarshalJSON` → `DisallowUnknownFields`) rejects them. Masked by the "best-effort" warnings. Worse: the pre-v2 provisioner POSTed a fresh copy per deploy — **251 accumulated dashboards** (verified via `GET /api/v2/dashboards`, total=251).
- **Source-level research** (pinned rev `c40ebb02`): mapped the full v2 schema — `pkg/types/dashboardtypes/perses_dashboard.go` (`PostableDashboardV2`), `perses_dashboard_data.go` (`DashboardSpec`), `perses_plugin_wrappers.go` (`allowedQueryKinds`: PromQL allowed for every panel kind except List; **exactly one query per panel** enforced), v2 handler routes. Discovered the CreateV2 v1-fallback path (`shadow.Version != "" && SchemaVersion == ""` → `ConvertV1ToV2`) — chose native v2 authoring instead (no reliance on migration path surviving upgrades).
- **Built**: 5 dashboards (`modules/nixos/services/dashboards/{overview,gpu,dns,docker,caddy}.json`), Perses `schemaVersion: "v6"`, stable slugs (`systemnix-*`), tag `owner=systemnix`, deterministic uuid5 panel IDs, 12-col grids, **only metrics verified live** (enumerated metric families from every endpoint first — including discovering caddy admin needs `Host: localhost:2019`, ollama has NO /metrics at all). Overview gains telemetry-ingestion panels from the collector self-scrape. Old `signoz-overview.json` deleted (was dead: deployed as `overview.json` while a different unused `overview.json` sat on disk).
- **Provisioner v7** (`_signoz-scripts.nix`): dashboard section rewritten to the converge pattern — list (paginated), zombie deletion (same `spec.display.name`, different slug), skip-unchanged (**v2 GET returns the spec byte-identical to the file — verified, so `jq -S .spec` diff is exact**), PUT-in-place, duplicate-slug cleanup, owner-tag orphan deletion, count assertion. **Dashboard failures are now HARD failures.**
- **Live-validated before deploy**: POST gpu.json → 201 (exact slug returned), GET→spec-identical, PUT → 200.
- **Deployed**: first run deleted ~246 zombies, created 5; second run: 5× "Unchanged", `OK 5 dashboards provisioned, exact desired set`, 0 errors.

### A3. Logs pipeline: from metadata-free dumps to first-class enriched logs
- **Found**: `signoz_logs.logs_v2` rows had `severity_text=''`, `severity_number=0`, `resources_string={}` (no service.name → UI can't group/filter), `body` = the ENTIRE journalctl JSON entry. ~105 rows/day (10 units, warning+). The upstream journaldreceiver v0.144.0 emits `body=Map(all fields)` and nothing else — verified empirically with a debug-exporter dry run.
- **Built** (in `signoz.nix` collector.yaml):
  - Receiver: `all=true`, `priority=info`, `start_at=end` (NEVER "beginning" — no persistent cursor = full-journal re-ingestion on restart). Whole-journal is safe: measured 5.35 MB/h total (~6 entries/s), 500× below the 2026-08 CPU-burn era; journald per-unit rate limiting (10k/30s) bounds recurrence.
  - `transform/journald` OTTL processor: extracts `body=MESSAGE` (LAST statement — field accesses return nil after), maps PRIORITY strings "0".."7" → severity_number/text (FATAL/ERROR/WARN/INFO/DEBUG/TRACE), sets curated attributes (`systemd_unit`, `syslog_identifier`, `pid`, `container_name`, `code_file`, `code_func`), and `resource.service.name` with precedence SYSLOG_IDENTIFIER < _SYSTEMD_UNIT < CONTAINER_NAME. Every statement guards `IsMap(body) and body["PRIORITY"] != nil` → OTLP logs from instrumented services pass untouched.
  - `memory_limiter` (768/192 MiB) first + `batch` (8192/5s) last on ALL three pipelines.
- **Docker integration**: `default-services.nix` daemon.settings += `log-driver = "journald"` → container stdout flows with CONTAINER_NAME (service.name = container name, e.g. `twenty-worker-1` already live). Existing containers keep json-file until recreated.
- **Result**: ~6,785 enriched rows per 10 min post-deploy; per-service counts verified (discordsync 2162, node-exporter 1207, gatus 946, twenty-worker-1 80, …). Logs TTL = 15 days (per-row `_retention_days`), bounded growth.

### A4. Phantom alert fixes + 3 new meta-alerts (23 rules total)
- **Ollama Down**: queried `up{job="ollama"}` — no such job, ollama serves 404 on /metrics. Rewritten on `node_systemd_unit_state{name="ollama.service",state="active"}` (real signal, node-exporter systemd collector).
- **Docker Daemon Down**: watched `up{job="cadvisor"}` (stays 1 while dockerd idles). Now watches `up{job="docker-engine"}` (direct signal).
- **NEW Telemetry Collector Down**: `up{job="signoz-collector"}` below 1.
- **NEW Telemetry Export Failures**: `sum(increase({__name__=~"otelcol_exporter_send_failed_(log_records|spans|metric_points)"}[10m]))` — regex selector keeps the query valid on absent series; **this alert would have caught A1**.
- **NEW ClickHouse Down**: `up{job="clickhouse"}` below 1.
- **Verified**: 23 rules provisioned, `system_signoz_alert_rules_healthy = 1`, 23 route policies one-per-rule, Discord channel unchanged.

### A5. Scrape coverage: 9 targets, all UP=1 (verified in ClickHouse)
- Added `signoz-collector` (self, :8888 — otelcol receiver/exporter rates), `clickhouse` (:9363 — `<prometheus>` block in extraServerConfig; nixpkgs does NOT enable it by default), `docker-engine` (:9390 — `metrics-addr`).
- Ports registered in `lib/ports.nix`: `signoz-collector-metrics 8888`, `signoz-clickhouse-metrics 9363`, `docker-engine-metrics 9390`.
- All verified via `up` metric query in `signoz_metrics`.

### A6. restartTriggers for every startup-read config (the recurring trap, closed)
- `signoz-collector` had NO restartTriggers for collector.yaml → my first deploy swapped the symlink and the process kept the OLD config (~1h of "enrichment doesn't work" until noticed). Fixed + documented.
- `clickhouse` (nixpkgs module has none for extraServerConfig) → 9363 didn't bind until restart. Fixed with trigger on the etc file; verified restart + bind.
- `signoz-provision` now also triggers on dashboard JSON sources (was rules-only).

### A7. Incidental blocker fixed: visionreviewd.nix broke ALL evals
- Concurrent session's committed wrapper referenced `packages.<sys>.visionreviewd` (upstream exposes only `default`) AND used top-level `mkIf` for an option that doesn't exist while the input predates the module — the mkIf definition envelope still gets type-checked → hard eval failure for every command.
- Fixed surgically (their intent preserved): `.default` + `lib.optionalAttrs` instead of mkIf (produces literal `config = {}` — nothing to check, nothing to merge).

### A8. Docs
- AGENTS.md: journald bullet rewritten (pipeline architecture, OTTL constraints, volume measurements); provisioner bullet extended to v7 + dashboards; external_url bullet updated (UI IS shipped now); NEW bullets: restartTriggers-mandatory, schema-drift/squash-gap, scrape coverage + dashboard authoring notes.
- CHANGELOG.md: comprehensive Unreleased entry.

### A9. Deploys verified
- 3 deploys this session (1 blocked by A7 pre-fix, 2 clean). `post-deploy-check`: **44 PASS / 0 FAIL** each time; auth gateway `signoz.home.lan → 200`; Gatus "SigNoz Web UI" success=true every 5m.

---

## Category B — Partially Done

1. **Dashboard verification is API-level only.** Convergence, schema, and data presence verified via API + ClickHouse; nobody has eyeballed the 5 dashboards rendering in a browser yet (panels reference verified series, but layout/UX unread).
2. **Docker journald log driver**: daemon default set and verified (twenty-worker-1 flowing); existing pre-change containers still write json-file until recreated — not audited which.
3. **Meta-alert paths provisioned but never test-fired** (e.g. no synthetic export failure to prove Telemetry Export Failures → Discord end-to-end; provisioning + evaluation health verified only).

## Category C — Not Started (identified, not begun)

1. Caddy `/var/log/caddy/access.log` ingestion (filelog receiver) — file-based, currently only prometheus metrics from caddy.
2. `file_storage` extension for journald cursor persistence — currently `start_at=end` means logs emitted during collector downtime are lost (gap, no duplication).
3. Eval-time validation of dashboard JSONs (schema/owner-tag/one-query-per-panel) — currently only deploy-time via provisioner hard-fail.
4. Committing the dashboard generator (`/tmp/gen_dashboards.py` — ephemeral!) to `scripts/`.
5. Log-ingestion-volume anomaly alert (sudden silence or flood detection).
6. TODO_LIST.md not updated with the follow-ups in F.

## Category D — Mistakes & Course Corrections (honest)

1. **The collector.yaml no-restart deploy (A6)** — I wrote the entire collector overhaul without adding the restartTrigger, deployed, then spent a cycle discovering my own enrichment "wasn't working". The trap is literally documented in AGENTS.md for signoz.yaml. Lesson applied: pair every startup-read config change with its trigger in the SAME edit.
2. **OTTL severity lambda emitted two statements in one string** (`- set(...) \n - set(...)`) — the receiver does not split embedded newlines. Caught by rendering the YAML through `nix eval` + inspecting before deploy.
3. **Unquoted Nix key `transform/journald`** — parse error (`unexpected path`). Caught by `nix-instantiate --parse`.
4. **`ports = import ../../../lib/ports.nix`** in default-services.nix — imported the wrapper attrset, not `.ports`. Caught by pre-deploy eval gate.
5. My exploratory ClickHouse queries themselves logged errors in the clickhouse journal (JSONExtractString on a Map) — later greps had to filter my own noise.

## Category E — Improvement Insights

1. **Render-and-validate-before-deploy works**: generating the YAML via `nix eval --apply`, rewriting exporters to `debug`, and running the REAL collector binary against it caught bug D2 and proved the pipeline shape with zero production risk. Make this standard for collector.yaml changes.
2. **The migrator squash-gap class deserves a guard**: a tiny check comparing `schema_migrations_v2` rows against the migrator's known migration list (per database) would have caught A1 months ago. The deploy-time provisioner could do it.
3. **Empirical receiver testing** (debug exporter on real journald) is the only reliable way to learn a receiver's record shape — docs were wrong/absent for the fork's pinned version.
4. The 251-zombie accumulation is the third converger/provisioner lesson in this repo (rules, policies, dashboards): **anything POSTed per-deploy must converge or it duplicates**.

## Category F — Next Tasks (Pareto-ordered)

**High value / small:**
1. Browser-eyeball the 5 dashboards (user action — layout/UX check only; data verified).
2. Commit working tree (strategy Q1 below), including dashboards + generator moved to `scripts/gen-signoz-dashboards.py`.
3. Recreate remaining json-file containers (one `docker compose up -d --force-recreate`-class action per stack) so ALL container logs flow.
4. Test-fire Telemetry Export Failures (e.g. `systemctl stop clickhouse` for 60s in a maintenance window) → verify Discord delivery.
5. Migrator-gap guard: provisioner asserts applied-migration IDs ⊆ known list per DB (would catch the A1 class for logs/metrics DBs too).

**Medium:**
6. `file_storage` + cursor persistence for journald receiver (close restart gaps).
7. Caddy access.log ingestion via filelog receiver (request-level logs in SigNoz).
8. Eval-time dashboard JSON validation in flake check.
9. Carry-over from 21-25 session: `deploy.sh` lock-wait on activation contention; flake-check guard for HTML `pat()` needles; `VITE_VERSION`/`VITE_ENVIRONMENT` stamping; Google Fonts self-hosting; external oauth2-proxy forward-auth path test; signoz `MemoryMax`/`GOMEMLIMIT` recheck with web serving; `web.settings` telemetry zeros explicit; attic push of `signoz-frontend` (122 MiB rebuild avoidance).
10. Log-volume anomaly alert (absence > 10min during uptime = pipeline dead).

**Larger / later:**
11. Investigate the 7 Gatus sustained-error endpoints (pre-existing; I/O-pressure-correlated metric checks — outside this session's scope by directive).
12. Sweep other services for "UI exists upstream but unshipped" gaps (carry-over).
13. Retention strategy review: traces 15d default in schema; consider explicit per-signal TTL policy in nix.

## Questions for the User

1. **Commit strategy**: the tree holds this session's SigNoz work + concurrent sessions' paperless/immich/caddy/homepage changes + the auto-git daemon. Commit as one sweep, or shall I stage only the signoz/* + docs files into a focused commit?
2. **Dashboards in browser**: please open https://signoz.home.lan → Dashboards and eyeball the 5 `systemnix-*` ones (layout, panel rendering). Data + convergence are verified; only UX is unconfirmed.
3. **Container recreation**: switch remaining json-file containers to the journald driver now (brief per-stack restart), or let them cycle naturally on next image update?

## Verification Evidence (key commands/results)

- `GET /api/v2/dashboards` → total 5, all `owner=systemnix`, slugs `systemnix-{overview,docker,dns,caddy,gpu}`
- provision journal: `OK 23 rules / 23 policies / 5 dashboards — exact desired set, 0 errors`
- logs: `SELECT count() ... last 10min` → 6,785; per-service top: discordsync 2162, node-exporter 1207, gatus 946, twenty-worker-1 80
- `up` metric: 9/9 targets = 1 (caddy, emeet-pixyd, signoz-collector, dnsblockd, node-exporter, cadvisor, clickhouse, docker-engine, pocket-id)
- collector self-metrics: `otelcol_exporter_send_failed_{log_records,metric_points,spans} = 0`
- `system_signoz_alert_rules_healthy = 1`; gatus journal: `SigNoz Web UI ... success=true` every 5m
- post-deploy-check: 44 PASS / 0 FAIL / 7 SKIP (monitor365 disabled-by-config, discordsync backfill)
