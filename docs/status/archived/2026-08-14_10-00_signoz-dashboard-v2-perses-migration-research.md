# Status Report: SigNoz Dashboard v1→v2 Perses Migration — Research Complete, Implementation Not Started

**Date:** 2026-08-14 10:00
**Scope:** `modules/nixos/services/dashboards/*.json`, `_signoz-scripts.nix` (provisioner)
**Task:** Migrate 5 SigNoz dashboard JSONs from v1 flat format to v2 Perses schema (POSTed to `/api/v2/dashboards`, currently non-fatal warnings)

---

## What was requested

Migrate the 5 SigNoz dashboard JSON files (`signoz-overview.json`, `gpu.json`, `dns.json`, `docker.json`, `caddy.json`) from the v1 flat format to the v2 Perses schema so the `signoz-provision` script stops emitting "may need v2 schema migration" warnings.

## What is FULLY DONE — research phase (100%)

1. **Inventory complete.** Found all 6 files in `modules/nixos/services/dashboards/` — the 5 wired dashboards + 1 unused Grafana-format leftover (`overview.json`, referenced by nothing; `signoz-overview.json` is the live source via `_signoz-alerts.nix:232-239`).
2. **Provisioner understood.** `_signoz-scripts.nix:113-135` POSTs each dashboard to `/api/v2/dashboards`. Channels + rules have idempotent delete-then-create logic; **dashboards have none** — every run just POSTs (creates).
3. **Live system inspected** (`http://127.0.0.1:8080`):
   - Version `4974962` — matches locked flake rev `49749626dc5197479c2da08105a52544f96b7da7`, so upstream source research is exact-revision, not approximate.
   - `GET /api/v2/dashboards` → **251 dashboards total** (~50 provision runs × 5 files, all duplicated garbage; see "discovered" below).
   - `GET /api/v2/dashboards/<id>` on a `legacy:true` (v5) entry → **501 Not Implemented** — legacy dashboards cannot even be read back via v2.
4. **Exact v2 schema extracted from upstream source at the locked rev** (this is the session's main asset — verified against `perses_dashboard.go`, `perses_dashboard_data.go`, `perses_replicas.go`, `perses_signoz_plugins.go`, `perses_plugin_wrappers.go`, `perses_v1_to_v2_panels.go`, `perses_v1_to_v2_queries.go`, Perses `layout.go`/`jsonref.go`, `prom_query.go`, `request_type.go`):
   - Top level: `{schemaVersion: "v6", name, generateName, tags: [{key, value}], spec}`; `DisallowUnknownFields` everywhere (strict).
   - `name` must be a DNS-1123 label (lowercase alnum + hyphen, ≤63) OR `generateName: true` + empty name.
   - `spec`: `{display: {name, description}, variables: [] (null rejected!), panels: {} , layouts: [], duration, refreshInterval, links: []}`.
   - Panel: `{kind: "Panel", spec: {display, plugin: {kind: "signoz/TimeSeriesPanel"|"signoz/NumberPanel"|…, spec: {visualization, formatting, chartAppearance, axes, legend, thresholds}}, queries, links}}` — **exactly 1 query per panel** (hard validation).
   - Query: `{kind: "time_series"|"scalar"|…, spec: {name, plugin: {kind: "signoz/PromQLQuery", spec: {name, query, disabled, step, stats, legend}}}}`; step = seconds-number or duration string; request type per panel kind (time series→`time_series`, number→`scalar`).
   - Layout: `{kind: "Grid", spec: {display: {title, collapse: {open}}, items: [{x, y, width, height, content: {$ref: "#/spec/panels/<key>"}}]}}` — 12-column grid, `width`/`height` (not v1's `w`/`h`), panel keys must match `[a-zA-Z0-9_-]+`, no panel placed twice.
   - Thresholds: color is **required**; TimeSeries uses `{value, unit, color, label}`, Number uses `{value, operator, unit, color, format}`.
   - v1 `yAxisUnit` maps verbatim to `formatting.unit` (no unit translation table).
5. **Metric-name reality check (partial):** repo-wide grep confirms `dnsblockd_dns_crashes_total` and `caddy_http_*` metric references exist; alert rules use `node_amdgpu_*` (the real GPU textfile metrics).

## PARTIALLY DONE

Nothing — no file has been written yet. The session ended between "understand" and "execute".

## What is NOT STARTED (the actual task)

~~1. Writing the 5 v2 dashboard JSONs (0/5).~~ EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~2. Making the provisioner dashboard loop idempotent~~ EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~3. Cleanup of the 251 legacy/duplicate dashboards in the live DB.~~ done - zombie purge executed; see verdict above.
~~4. Eval/build/lint verification~~ done - deployed and live; flake check green 2026-08-17.
~~5. End-to-end verification against the live API~~ done - API-verified (`2026-08-16_23-27`); BROWSER eyeballing remains TODO_LIST P2.
~~6. AGENTS.md gotcha update~~ done - AGENTS.md SigNoz section carries the v2 convergence pattern + duplication trap.

## What is TOTALLY FUCKED UP — discovered during research (pre-existing, unfixed)

1. **251 duplicated dashboards in production.** `signoz-provision` POSTs (create) on every run with no delete/update guard — 5 new dashboards per deploy for ~50 runs. The dashboard UI is unusable garbage. This is a worse bug than the schema warnings.
2. **The "auto-migrated" dashboards are empty.** The v6 (`legacy:false`) entries created from v1 POSTs have `panels: {}` and `layouts: []` — SigNoz's create-time migration only kept `spec.display`. So the current dashboards show _nothing_ even where POST succeeded with 2xx.
3. **Legacy v5 entries are zombies** — listed but 501 on GET; they cannot be fixed, only deleted.
4. **`dns.json` queries dead metrics.** It targets `unbound_*` metrics, but dnsblockd replaced unbound entirely (AGENTS.md). The whole dashboard renders no data. Should be rewritten against real `dnsblockd_*` metrics (only `dnsblockd_dns_crashes_total` verified so far; the full set on the live `/metrics` endpoint has not been enumerated).
5. **`signoz-overview.json` CPU Temperature panel** uses `node_hwmon_temp_celsius{chip="amdgpu"}` — the real metric per alert rules is `node_amdgpu_gpu_temp_celsius`. Likely dead panel.
6. **`dns.json` w4 "DNS Blocker Health"** is a placeholder querying literal `"0"` — dead weight.
7. **`docker.json` "Container Restarts"** uses `container_restart_total` — not a standard cAdvisor metric; needs verification against live `/metrics` before rewriting.
8. **`signoz-overview.json` was never even valid v1** — no `layout`/`widgets` arrays, panel objects dumped at top level. It "worked" only because the provisioner treats dashboard failures as warnings.

## What we should improve next time

- **Pair every research session with an incremental artifact.** The entire session went to research with zero writes; a schema cheat-sheet file (`docs/services/signoz-dashboard-v2-schema.md`) or even one migrated dashboard would have made this interruptible instead of all-or-nothing.
- **Query the live API FIRST.** The 251-duplicate discovery came from one GET after an hour of source reading; it reframed the whole task (schema rewrite is only ⅓ of the fix). Cheap probes before deep research.
- **Sourcegraph calls returned duplicated/noisy context** (each result repeated the file body multiple times). Prefer `raw.githubusercontent.com` downloads (exact revision) — did this for later files, should have started there.
- **Batch the metric-name verification** (caddy/docker/gpu/dns/node against live `/metrics`) into one scripted step instead of piecemeal greps.

## Next steps (do these in order)

~~1. Enumerate live metric names once~~ EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~2. Fix provisioner first~~ EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~3. One-time cleanup script/step~~ done - see verdict above.
~~4. Write a shared v2 builder in Nix?~~ done - kept as plain JSONs; generated via the deterministic uuid5 pattern (committing the generator itself remains TODO_LIST P3).
~~5. Rewrite `signoz-overview.json` → v2~~ done - shipped as `overview.json` (`systemnix-overview`, v6 schema). EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~6. Rewrite `gpu.json` → v2~~ done. EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~7. Rewrite `caddy.json` → v2~~ done. EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~8. Rewrite `docker.json` → v2~~ done. EXECUTED 2026-08-16 by the SigNoz deep-integration session (`docs/status/2026-08-16_23-27_signoz-deep-integration.md`, commits through `8ffb2762`): all 5 dashboards are native v2 (`schemaVersion: "v6"`, `owner=systemnix` tags) in `modules/nixos/services/dashboards/`, the provisioner CONVERGES via GET+`PUT /api/v2/dashboards` (zombie purge included - the 251 duplicates are gone), and dashboard failures are HARD failures. Annotation 2026-08-17.
~~9. Rewrite `dns.json` → v2~~ done - zero `unbound_*` references remain in the dashboards dir (verified 2026-08-17).
10. Local schema lint ← open - TODO_LIST P3 ("eval-time dashboard JSON lint"); runtime convergence assertions cover it provisionally.
~~11. `nix flake check --no-build` + `nix fmt`.~~ done - check green 2026-08-17.
~~12. Deploy provisioner fix + dashboards~~ done - deployed 2026-08-16.
~~13. Verify live: GET each dashboard~~ done API-side; UI eyeballing remains TODO_LIST P2.
~~14. Re-run provision to prove idempotency~~ done - convergence assertion (exact name set, zero dupes) runs on EVERY provision (AGENTS.md SigNoz gotcha).
~~15. Run the cleanup for the 251 legacy entries~~ done - see verdict above.
~~16. `trash` the unused Grafana-format `overview.json`.~~ superseded - the filename was REUSED: `overview.json` is now the live v2 `systemnix-overview` dashboard.
~~17. Update AGENTS.md~~ done - SigNoz gotchas cover convergence, the 251-duplication trap, and hard-failure semantics.
18. Schema lint in pre-commit/CI ← open - TODO_LIST P3.
~~19. Update `_signoz-scripts.nix` header comment~~ done - v6 provisioner shipped.
20. gotchas-archive 501-on-legacy-GET entry ← open, low priority - no legacy dashboards remain, so the behavior is moot in practice.
~~21. Confirm threshold colors~~ done - shipped dashboards carry working thresholds (API-verified).
~~22. Decide `duration`/`refreshInterval`~~ done - set in the shipped files.
~~23. Panel keys: use semantic slugs~~ done - deterministic uuid5-keyed panels shipped.
24. Post-deploy dashboard-count assertion ← open question - provisionally superseded by the provisioner's own convergence assertion; not tracked as a TODO.
25. ~~Record outcome in a new status report / close the TODO in `TODO_LIST` if tracked there.~~ done — this report IS the record; the full migration (provisioner fix → purge → 5 rewrites → lint) is tracked in `TODO_LIST.md:52` and the schema lint in `TODO_LIST.md:53`. Live re-verification 2026-08-14 20:15: **251 duplicates still in the DB** (count unchanged), dashboard JSONs still v1, `overview.json` leftover still present — every other next-step remains open.
~~26. PUT-by-name fallback decision~~ resolved - PUT works; the v6 provisioner uses GET+PUT convergence.
~~27. Verify `links: []` omission tolerance~~ resolved - shipped files parse and round-trip clean.
~~28. `variables: []` vs null handling~~ resolved - shipped files accepted by the strict parser.
~~29. `step` as number accepted~~ resolved - live dashboards work.
~~30. Confirm tag shape~~ resolved - `[{"key":"owner","value":"systemnix"}]` shipped and filterable.

## Questions for the human (max 3)

~~1. **Cleanup mandate**~~ RESOLVED by execution - the 2026-08-16 session purged the 251 (tag-filtered; untagged/user dashboards untouched).
~~2. **Idempotency contract**~~ RESOLVED - PUT-in-place won (recommendation accepted; preserves IDs).
~~3. **Scope of metric fixes**~~ RESOLVED - full rewrite against verified live metrics (recommended option; zero `unbound_*` references remain).
