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

1. Writing the 5 v2 dashboard JSONs (0/5).
2. Making the provisioner dashboard loop idempotent (currently POSTs create duplicates — the root cause of 251 garbage dashboards).
3. Cleanup of the 251 legacy/duplicate dashboards in the live DB.
4. Eval/build/lint verification (`nix flake check --no-build`, `nix fmt`).
5. End-to-end verification against the live API (POST a migrated dashboard, GET it back, confirm panels/layouts persist).
6. AGENTS.md gotcha update (v2 schema notes, duplication trap).

## What is TOTALLY FUCKED UP — discovered during research (pre-existing, unfixed)

1. **251 duplicated dashboards in production.** `signoz-provision` POSTs (create) on every run with no delete/update guard — 5 new dashboards per deploy for ~50 runs. The dashboard UI is unusable garbage. This is a worse bug than the schema warnings.
2. **The "auto-migrated" dashboards are empty.** The v6 (`legacy:false`) entries created from v1 POSTs have `panels: {}` and `layouts: []` — SigNoz's create-time migration only kept `spec.display`. So the current dashboards show *nothing* even where POST succeeded with 2xx.
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

1. Enumerate live metric names once: scrape `:9100` (node), `:9193`/cadvisor, caddy, `dnsblockd /metrics` — one command, save to `/tmp`.
2. Fix provisioner first (`_signoz-scripts.nix`): for each dashboard file, resolve existing by fixed `name` → `PUT /api/v2/dashboards/<id>` update, else POST; count as FAILED (not warning) on failure; add rule-count-style verification for dashboard count. Decide idempotency contract.
3. One-time cleanup script/step: delete ALL existing `legacy:true` v5 dashboards and all empty v6 duplicates (the 251).
4. Write a shared v2 builder in Nix? — No: keep dashboards as plain JSON files (repo convention), but template the boilerplate (Grid layout, full panel specs) by hand in file 1, then clone the pattern for the remaining 4.
5. Rewrite `signoz-overview.json` → v2 (`evo-x2-overview`): 4 Number panels (CPU/mem/disk/GPU temp, scalar + thresholds), 2 Number (load1, uptime), 7 TimeSeries panels; fix CPU-temp metric to `node_amdgpu_gpu_temp_celsius`.
6. Rewrite `gpu.json` → v2 (`gpu-metrics-amd-radeon-8060s`): 4 TimeSeries + 1 Number (VRAM total, scalar).
7. Rewrite `caddy.json` → v2 (`caddy-reverse-proxy`): 4 TimeSeries; verify `status_code`/`host` label names against live `/metrics`.
8. Rewrite `docker.json` → v2 (`docker-containers-resource-usage`): 5 panels; replace/verify `container_restart_total`.
9. Rewrite `dns.json` → v2 (`dns-blocking`): rebuild around real `dnsblockd_*` metrics (crashes, blocked/allowed counters if present), drop the `"0"` placeholder panel and all `unbound_*` queries.
10. Validate each JSON locally: `jq` parse + a small check script for required v2 fields (schemaVersion v6, exactly 1 query per panel, every layout `$ref` resolves, 12-col geometry).
11. `nix flake check --no-build` + `nix fmt`.
12. Deploy provisioner fix + dashboards: `nix run .#deploy`, run `signoz-provision`, watch logs for OK dashboard lines.
13. Verify live: GET each dashboard by name/id — panels map non-empty, layouts non-empty; open UI and eyeball.
14. Re-run provision to prove idempotency (count stays 5, no duplicates).
15. Run the cleanup for the 251 legacy entries (if not folded into step 3's script run).
16. `trash` the unused Grafana-format `overview.json`.
17. Update AGENTS.md: v2 schema summary pointer, the dashboard-duplication trap, "v1 dashboard POSTs produce empty dashboards", metric-name verification rule.
18. Consider a Gatus/eval-time guard: script-side JSON schema lint in pre-commit (gatus-pattern-lint precedent) so a v1-format regression fails CI instead of warning at deploy.
19. Update `_signoz-scripts.nix` header comment ("Rewrite in v2 format later" TODO → done).
20. Check `docs/gotchas-archive.md` for whether the 501-on-legacy-GET behavior deserves an entry.
21. Confirm whether SigNoz UI's default threshold colors are hex (`#10b981` etc.) and use those for Number-panel thresholds.
22. Decide `duration`/`refreshInterval` per dashboard (v1 had 6h/1h + 30s refresh — carry over as `"6h"`/`"30s"`).
23. Panel keys: use semantic slugs (`cpu-usage`, `vram-usage`) — must match `[a-zA-Z0-9_-]+`.
24. Post-deploy-check: does `scripts/post-deploy-check.sh` need a SigNoz dashboard-count assertion? (Gatus owns liveness; dashboards are content, arguably in scope for silent-zero regression checks.)
25. ~~Record outcome in a new status report / close the TODO in `TODO_LIST` if tracked there.~~ done — this report IS the record; the full migration (provisioner fix → purge → 5 rewrites → lint) is tracked in `TODO_LIST.md:52` and the schema lint in `TODO_LIST.md:53`. Live re-verification 2026-08-14 20:15: **251 duplicates still in the DB** (count unchanged), dashboard JSONs still v1, `overview.json` leftover still present — every other next-step remains open.
26. If PUT-by-name turns out unsupported (name immutability: update requires same name — verify route shape `PUT /api/v2/dashboards/{id}` with `UpdatableDashboardV2`), fall back to delete-by-name-then-create (mirrors rules loop) — decide after reading `pkg/apiserver/signozapiserver/dashboard.go` routes.
27. Verify `links: []` omission tolerance (`omitzero`) — omit where allowed to minimize payload, include where Go round-trip emits it.
28. Double-check `variables: []` vs null handling in the final files (null → hard reject).
29. Sanity-check that `step` as number (seconds) is accepted by the running build (schema says number-or-string; runtime `Step.UnmarshalJSON` — confirm).
30. Confirm tag shape `[{"key":"tag","value":…}]` matches what the UI expects for filtering (the auto-migrated v6 overview used exactly this — good precedent).

## Questions for the human (max 3)

1. **Cleanup mandate:** the live SigNoz DB has 251 broken duplicate dashboards (and grows by 5 per deploy). OK to purge ALL current dashboards matching our 5 display names plus every `legacy:true` entry as part of this work — or do you want to inspect/keep any first (e.g. anything you created by hand in the UI)?
2. **Idempotency contract for dashboards:** fixed DNS-1123 names + PUT-update-in-place (my recommendation), or delete-by-name-then-recreate each run (matches the alert-rules loop)? Both stop the duplication; PUT preserves dashboard IDs/links.
3. **Scope of metric fixes:** `dns.json` targets dead `unbound_*` metrics and other panels likely reference non-existent metrics (`node_hwmon_temp_celsius`, `container_restart_total`). Rewrite these queries against verified live metrics as part of this migration (recommended), or migrate schema 1:1 and fix queries in a follow-up?
