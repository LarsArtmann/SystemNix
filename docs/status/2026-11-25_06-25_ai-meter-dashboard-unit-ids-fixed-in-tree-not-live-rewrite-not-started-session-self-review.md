# AI Meter dashboard: unit ids fixed in tree (not live), root cause proven by running the real formatter, rewrite still not started (2026-11-25, 06:25)

**2026-11-25 06:25 CET, Crush agent (glm-5.4). Trigger: fourth sending of the loop instruction ("execute and verify one step at a time, repeat until done"), then "full status report, then WAIT FOR INSTRUCTIONS".**

**Harvest status: NOT HARVESTED, deliberately.** Every dashboard item in section (f) is in flight in this session. The plan now executing in a sibling session says so too (T07.4 of `docs/planning/2026-11-25_06-04_SUPERB-ai-meter-rate-limit-relief-and-forgejo-extraction.md`: "do not edit the dashboard JSON, another session owns it"). A `[ready]` queue row would start a second rewrite in parallel with this one. Two foreign observations in section (d) are not queued either, because I did not investigate them (the owner asked for a report only); they are listed for the owner to route.

## Scope line

**Pin:** `git rev-parse --short HEAD` = `5db2bdb7e` at 06:25:29 CET, tree clean (`git status --short` prints nothing).

**Verified fresh in this stretch (05:36 to 06:25), all read-only unless named:**

- `date` run at 06:22:16, 06:25:20 and 06:25:29.
- Unit fix present at HEAD: the template loaded with `json.load`, unit ids counted per panel.
- Commit that carries it: `git show --stat ba2536b48` (05:44:33, "chore: auto-commit 2 changed file(s) (heuristic)": `modules/nixos/services/dashboards/ai-meter.json` 18 lines, plus a foreign 2-line edit of `pkgs/ai-meter/proxy.go`).
- How each unit id renders: the real formatter sources run in node (`~/.cache/aimeter/render-units.test.mjs`, output quoted in section (a)). The sources are `@grafana/data@11.6.15` `dist/esm/valueFormats/*.mjs`, extracted from `/nix/store/kh6ay8kzbr4qk0s8bg0xnhw9bb30cjbq-signoz-frontend-pnpm-deps/pnpm-store.tar.zst`, the dependency input of the SigNoz build.
- Allowlist built from source and run over all 10 dashboards in `modules/nixos/services/dashboards/`.
- Live dashboard: `GET /api/v2/dashboards/01a148a8-81c0-7605-9028-fe0d8ca11832` at about 06:23.
- Running system's dashboard file: `json.load(open("/etc/signoz/dashboards/ai-meter.json"))`.
- Provisioner: `journalctl -u signoz-provision --since '2026-11-25 05:30'`.
- ai-meter live state: `GET http://127.0.0.1:8108/metrics` at about 06:23; epochs decoded with python `zoneinfo`.
- Deploy outcome of a foreign deploy: grep of `/var/log/systemnix-deploys/2026-11-25_04-59-27.log` (lines 541 to 573).
- Plan state: header and lines 1 to 200 of the plan file named above; `git log` for `pkgs/ai-meter/admission.go`.
- Metric family names at HEAD: `rg -o 'HELP ai_meter_\w+' pkgs/ai-meter/metrics.go`.
- Source read in the locked SigNoz tree (`/nix/store/hk3kq36v4c2lnn3bsj5l9ircq4skrf41-signoz-da35d99-patched`): `pkg/types/dashboardtypes/perses_signoz_plugins.go`, `pkg/types/querybuildertypes/querybuildertypesv5/{builder_query,builder_elements,request_type}.go`, `frontend/src/components/Graph/yAxisConfig.ts`, `frontend/src/components/YAxisUnitSelector/{types.ts,constants.ts,formatter.ts,utils.tsx}`, `frontend/src/lib/getConvertedValue.ts`, `frontend/src/pages/DashboardPage/DashboardContainer/queryV5/persesQueryAdapters.ts`, plus the bundled `signoz---ai-o11y-overview` dashboard.
- Repo files read: `flake/parts/checks/lint-static.nix` lines 380 to 640, `flake/parts/checks/ai-meter-guards.nix`, `modules/nixos/services/_ai-meter-dashboard.nix`, `_signoz-scripts.nix` lines 396 to 531, `_signoz-alerts.nix` lines 1 to 150, `pkgs/ai-meter/metrics.go` (as of 03:39), the dashboard template in full, `docs/agents/monitoring.md` head and the unit, escape and delta gotchas.

**NOT verified here:**

- No gate ran after the unit edit: `signoz-query-lint`, `ai-meter-spend-promql`, the `nix eval` of the rendered dashboard, `nix flake check --no-build`, buildflow and the Go tests were all skipped. The JSON was only parsed by python.
- The fixed unit strings were never sent to the live dashboard API. The server type is a free string by source reading (`PanelFormatting.Unit string`), not by a live request.
- Nobody looked at the rendered UI. The "renders as" strings come from running the formatter library, not from a browser.
- A metrics builder query was never executed against `/api/v5/query_range`. No variable value request was executed. `resolveVariableSelection.ts` was not read.
- The three alert rules created at 05:09 were not executed against the live API in this stretch.
- The foreign deploy's bootloader state was not checked (`bootctl` not run). Its four failed units were not investigated. Why the provisioner also "updated in place" the caddy and gcp dashboards at 06:09:24 was not investigated.
- The sibling report `2026-11-25_05-46_ai-meter-cost-restatement-live-session-status-and-self-review.md` was noticed at report time; only its first 12 lines were read. Lines 200 to 311 of the plan were not read.

## Self-review: what did I forget, what could be better

**Forgotten:**

1. To ship. The unit fix sat in the tree for the daemon to sweep. It is committed but not live, and its commit message says nothing about it.
2. To re-scan `docs/status/` and `docs/planning/` mid-session. The sibling report (05:46) and the plan (06:04) were both unread until this report.
3. To write the root cause into `docs/agents/monitoring.md` when I found it. It lives only in scratch and in this report.
4. To run the gates next to the edit.
5. The metrics admin port is 8108, not the proxy port 8107 (first scrape was a 404).

**Could have been better:** a small vertical slice per loop instruction (fix, gate, get it live), instead of 50 minutes of research before the first edit; time-boxing the schema research once the unit root cause was proven; handing the schema research to a zai subagent while writing the generator.

**Can still improve:** the lint legs (unit ids, every Grid layout), a dashboard dry-run script in the repo, and the monitoring.md gotcha, all listed in section (f).

## a) FULLY DONE

| # | What | Evidence | Scope |
| --- | --- | --- | --- |
| 1 | Broken unit ids fixed in the dashboard template: `{percent}` to `percent`, `{req/min}` to `reqpm` (4 panels), `{USD}` to `currencyUSD`, `{USD/h}` to `suffix:USD/h` (2 panels), `{tokens/min}` to `count:tokens/min`. 9 strings, 9 panels. | In `ba2536b48`, present at `5db2bdb7e`: `{'percent': 1, 'reqpm': 4, '{count}': 3, 'suffix:USD/h': 2, 'currencyUSD': 1, 'count:tokens/min': 1, 's': 1}` | `modules/nixos/services/dashboards/ai-meter.json`. Not live, not gated. |
| 2 | Root cause of the literal units proven by execution. A SigNoz panel formats through `getYAxisFormattedValue` into `@grafana/data` `getValueFormat`; an unknown id falls back to `toFixedUnit(id)`, which prints the id as a literal suffix. | Real formatter run: `95.3 {percent}`, `13 {req/min}`, `13805.7 {USD}`, `0.85 {USD/h}`, `42 {tokens/min}`. Fixed ids: `95.3%`, `13 req/m`, `$13.81K`, `0.85 USD/h`, `123K tokens/min`. | Explains every broken panel. |
| 3 | The valid unit id space is known from source: 272 Grafana catalog ids, 273 SigNoz "universal" values (the braced ones included: `{count}`, `{count}/s`, `{count}/min`, `{ops}/s`, `{ops}/min`, `{req}/s`, `{req}/min`, `{read}/s`, `{read}/min`, `{write}/s`, `{write}/min`, `{iops}/s`, `{bool}`, `{bool_yn}`, plus `%` and `1`), and the custom prefixes `prefix:`, `suffix:`, `time:`, `si:`, `count:`, `currency:`, `bool:`. | `getValueFormats()` run in node; regex extract of the enum in `YAxisUnitSelector/types.ts`. | Input for the lint leg. |
| 4 | All 10 dashboards validated against that allowlist. One more broken id found: `req` in `gcp.json`. | Validation script output, see section (d). | Not fixed. |
| 5 | Schema facts for the rewrite, source-verified at the locked rev. | Files listed in the scope line. | Appendix A. |

## b) PARTIALLY DONE

| # | What works now | What is open | Blocker | Effort |
| --- | --- | --- | --- | --- |
| 1 | Unit fix committed (`ba2536b48`). | Not live: the running system (gen 1030) was built from the 04:59 tree, before the fix. Not gated. Not dry-run on the API. | A deploy. | S |
| 2 | Dashboard schema research: panel query shapes, sections, variables, thresholds, metrics builder spec. | Two live probes never executed: a metrics `builder_query` and a dynamic variable value request. | None. | S |
| 3 | Lint design decided: unit-id allowlist leg; overlap check over every Grid layout. | Not written, no negative legs. | None. | M |
| 4 | Live state of the exporter and of span export captured twice (05:45 and 06:23). | Nothing else. | None. | done |

## c) NOT STARTED

All of it is the owner's original ask. After four loop instructions the user-visible delta is zero, because the one change made is not deployed.

1. In-flight per provider, per model, per client, per upstream and model. Not written.
2. Dashboard sections, variables, tables, thresholds, the other panels. Not written.
3. Verification of every panel query against the live API. Not started.
4. Dry-run of the rendered dashboard on the live API (throwaway create and delete). Not started.
5. Unit-id lint leg and its negative test. Not started.
6. Overlap lint over every Grid layout. Not started.
7. `gcp.json` unit fix. Not started.
8. Gates after the edit. Not run.
9. Executing the three alert rules' PromQL against the live API. Not done.
10. Docs: `docs/services/ai-meter.md`, `docs/agents/monitoring.md`, `docs/DOMAIN_LANGUAGE.md`, CHANGELOG, TODO rows. Nothing written in this stretch.
11. Deploy and live verification. Not done.

## d) TOTALLY FUCKED UP

**Mine:**

1. **The dashboard the owner looks at is unchanged.** Live at 06:23: 13 panels, 1 layout, 0 variables, units `{percent}`, `{req/min}` (4), `{USD}`, `{USD/h}` (2), `{tokens/min}`, three `{count}` and one `s`. The provisioner even re-PUT it at 06:09:24 with the broken units, because gen 1030 carries the 04:59 snapshot. Severity: the task itself. Root cause: I researched instead of shipping.
2. **Attribution of the unit fix is buried.** `ba2536b48` is a heuristic auto-commit that also carries another session's `proxy.go` line. HEAD has moved, so no amend; only this report names it.
3. **Process misses.** No mid-session scan of `docs/status/` and `docs/planning/`. No gate next to the edit. Root cause not written to `monitoring.md` at discovery.
4. **Tool fumbles in this stretch:** an `ls` on an empty variable printed the whole `/nix/store` listing (17,000+ lines) into the session; a 404 from scraping 8107; four failed throwaway python one-liners before writing a proper script; one `rg -r` call blocked by the hook (the documented replace trap).

**Found, not mine, not fixed:**

5. **`gcp.json` "Cloud Run — Active Containers" uses unit `req`.** Not in the catalog and not universal, so it renders literally: "42 req" on a panel about containers. Fix: `none`.
6. **`signoz-query-lint` check 5 reads `layouts[0]` only** (`lint-static.nix` line 568). A dashboard with several Grid sections gets only its first section checked for overlaps, and the SigNoz API rejects an overlap with HTTP 400, which fails the deploy. Must be closed before any sectioned dashboard ships.
7. **Small rates collapse to zero.** `suffix:USD/h` at precision 2 renders `0.0042` as "0 USD/h". Precision 4 gives "0.0042 USD/h" and "12.3 USD/h".
8. **The `locale` unit truncates thousands in SigNoz** (13805.7 renders as "13"). Avoid it.
9. **`reqpm` at precision 0 rounds 1234.5 to "1K req/m".** Use precision 1 or 2.

**Foreign observations, not investigated:**

10. **The deploy started 04:59:27 ended in exit code 4.** Its log reads: "switching to system configuration …hggzirywc… failed (status 4)", "Activation failed; the new generation will not be added to the bootloader", "nh os switch: activation completed with failed units (exit code 4)", "New profile generation: system-1030 (was system-1029)". Failed units in that log: `post-crash-calm-gate` ("REFUSE: still storming after 60 min / 241 probe(s)"), `inboxclean-sync` (75, Gmail 429), `forgejo-github-sync` (1), `service-health-check` (1). The profile is anchored: `/run/current-system` equals the newest link, `system-1030-link`. The bootloader entry was not checked.
11. **The provisioner "updated in place" the caddy and gcp dashboards at 06:09:24**, although their files have not changed in weeks. The live copies had drifted from the tree. Cause unknown.
12. **z.ai rejections:** 123 of 357 calls in the current ai-meter process (06:09:56 to 06:23) were answered 429. The executing plan addresses this with admission control; the three new families are in tree, not deployed.

## e) WHAT WE SHOULD IMPROVE

| # | Pattern | Impact | Fix |
| --- | --- | --- | --- |
| 1 | Long research phases before the first edit. | Four loop instructions, no visible change. | One vertical slice per instruction: edit, gate, live, verify. Research in a zai subagent, in parallel. |
| 2 | Dashboard unit ids are free text that the API accepts and the UI renders literally. | Broken units were provisioned without complaint and read as broken for five weeks. | Unit-id lint leg with a negative test (f3). |
| 3 | The overlap lint assumes one layout. | A sectioned dashboard can pass the lint and fail the deploy. | Iterate every Grid layout (f4). |
| 4 | No in-repo way to validate a dashboard against the strict live decoder before a deploy. | Every new shape is a guess until `signoz-provision` runs. | `scripts/signoz-dashboard-dryrun.sh`: create a throwaway slug tagged `owner=systemnix` (the orphan pass cleans it if the delete is lost), read it back, delete it (f5). |
| 5 | A hand-written JSON template with two placeholders. | Fine while the dashboard is small; error-prone at 30 panels. | Keep the JSON canonical and lint it. Do not add a generator unless the panel count makes hand editing worse than maintaining a script. |
| 6 | Root causes stay in session context. | The next session re-derives them. | Write the `monitoring.md` gotcha when the cause is proven (f14). |
| 7 | Sessions do not re-scan `docs/status/` and `docs/planning/` during long runs. | Two sibling documents about the same surface went unread for 40 minutes. | Re-scan before each new step, not only at session start. |
| 8 | Harness rule "never commit" plus daemon sweeps. | Fixes land in mixed heuristic commits. | Owner decision, see question 1. |

## f) Next things

Owner: **this session** (in flight, deliberately not harvested), **plan executor** (the session running the 06:04 plan), **owner** (decision).

| # | Task | Impact | Effort | Category | Owner |
| --- | --- | --- | --- | --- | --- |
| 1 | Get the unit fix live: a deploy from any tree at or after `ba2536b48`, then read the units back from the live dashboard API. | High | S | Bug | this session, or rides the plan's T04 deploy |
| 2 | Execute a metrics `builder_query` against `/api/v5/query_range` (gauge `ai_meter_active_requests`, group by `upstream`) and record the exact working envelope. | High | S | Feature | this session |
| 3 | Read `resolveVariableSelection.ts`; execute a dynamic variable value request for `upstream`, `model` and `client` on the metrics signal. | High | S | Feature | this session |
| 4 | Write the dashboard spec: sections (now, traffic, spend, latency, health, AI traces, admission), variables, panel list, unit and precision per panel. | High | M | Feature | this session |
| 5 | Build the in-flight panels from `ai_meter_active_requests{client,upstream,model}`: one table per provider, one per model, one per client, one per upstream and model; the stat tile keeps the total. This is the owner's first ask. | Critical | M | Feature | this session |
| 6 | Rewrite the template: sections as several Grid layouts, variables, tables, thresholds. Keep exactly one panel named `Spend Rate` and one named `Spend Rate by Model` with their placeholders (the guard in `ai-meter-guards.nix` requires it). | Critical | L | Feature | this session |
| 7 | Add stat thresholds (success rate, error rate, metering errors, unauthorized) and span export health (ok, failed, dropped). | Medium | S | Feature | this session |
| 8 | Add a native AI observability section from the exported spans: calls, tokens, cost, errors, p95 TTFT per provider and model, with variables on `gen_ai.request.model` and `gen_ai.provider.name`. | Medium | M | Feature | this session |
| 9 | Add admission panels for `ai_meter_admission_outcomes_total`, `ai_meter_admission_wait_seconds_sum` and `_count`, `ai_meter_upstream_rejections_total`, after the plan's T07.4 hand-off note names them and T04 deploys them. | Medium | S | Feature | this session, after the plan executor |
| 10 | Set precision 4 on the two spend-rate panels and precision 1 or 2 on request-rate panels. | Low | S | Bug | this session |
| 11 | Verify every PromQL panel against the live `/api/v1/query`; no single backslash in any regex. | High | M | Quality | this session |
| 12 | Verify every builder panel against the live `/api/v5/query_range`. | High | M | Quality | this session |
| 13 | Dry-run the rendered dashboard on the live API with a throwaway dashboard, then delete it. | High | S | Quality | this session |
| 14 | Write the `monitoring.md` gotcha: unknown unit ids render literally; the universal units; avoid `locale`; the small-rate precision trap. | Medium | S | Documentation | this session |
| 15 | Unit-id lint leg with the allowlist and a negative leg under a new group in `scripts/negative-test-lints.sh`. | Medium | M | Quality | this session |
| 16 | Overlap lint over every Grid layout, with a negative leg. | Medium | S | Quality | this session |
| 17 | Fix `gcp.json` unit `req` to `none`. | Low | S | Bug | this session (with item 15, which would otherwise fail) |
| 18 | Run the gates: `signoz-query-lint`, `ai-meter-spend-promql`, `ai-meter-vm`, `nix fmt -- --fail-on-change` on touched nix files, `nix flake check --no-build`, `buildflow -s test-race`. | High | M | Quality | this session |
| 19 | Deploy the rewritten dashboard and verify: units in the live JSON, panels render, `journalctl -u signoz-provision`, the gatus "ai-meter dashboard" drift check. | Critical | M | Feature | this session, needs question 2 |
| 20 | Execute the three alert rules' PromQL once against the live API. | Medium | S | Quality | this session |
| 21 | Update `docs/services/ai-meter.md`: span export, config keys, metric families, cost and no-content decisions, dashboard sections, the unit rule. | Medium | M | Documentation | this session |
| 22 | Update `docs/DOMAIN_LANGUAGE.md`: span export, AI observability, dashboard sections and variables. | Low | S | Documentation | this session |
| 23 | CHANGELOG entries for the span export, the three alert rules, the coverage entry, the unit fix and the rewrite. | Low | S | Documentation | this session |
| 24 | Re-read and annotate TODO rows 3952 (llama-embeddings dark), 2531 (per-client panels), 2529 and 1625. | Low | S | Cleanup | this session |
| 25 | Decide whether the formatter harness becomes a repo tool or a documented recipe in `monitoring.md`. | Low | S | Cleanup | this session |
| 26 | Read the rest of the sibling report (05:46) and of the plan (lines 200 to 311) and drop any item here that they already cover. | Medium | S | Cleanup | this session |
| 27 | Check the bootloader entry after the exit-4 deploy: `nix run .#pre-reboot-check` before any reboot. | High | S | Bug | owner to route (foreign deploy, unverified by me) |
| 28 | Find out why the live caddy and gcp dashboards differ from the tree (edited in the UI, or server-side defaulting). | Low | S | Bug | owner to route |
| 29 | File the `locale` truncation upstream only after a source-level verification (`verify-before-filing`). | Low | S | Upstream | owner to route |
| 30 | Landing note for `ba2536b48`: nothing to rewrite, HEAD moved. This report is the record. | Low | done | Cleanup | this session |

## g) Questions I can not answer myself

1. **May I commit my own files with descriptive messages?** The harness forbids commits unless you say so. Without it every fix lands only through the daemon's heuristic sweeps, mixed with other sessions' files (`ba2536b48`).
2. **May this session deploy on its own** (`scripts/deploy-when-quiescent.sh --fire`) to take the rewritten dashboard live, or must it ride the plan executor's T04 deploy? I held back both times because the tree is shared with sessions that are deploying.
3. **Carried over from the 05:26 report:** should ai-meter optionally export prompts and completions with each span so the AI Explorer shows content? My default stays no for privacy; nothing is exported today.

Decided by default, object if you disagree: the proxy stays the cost authority and stamps cost on spans; broken-unit, native trace and admission panels go into the one existing dashboard as sections.

## Appendix A: schema facts for the rewrite (source-verified)

- A panel has exactly one top-level query. It is either a bare plugin (`signoz/PromQLQuery`, what this repo uses) or `signoz/CompositeQuery` with `spec.queries[]`, each an envelope of type `builder_query`, `builder_ai_query`, `promql`, `formula`, `clickhouse_sql` or `trace_operator`. The bundled AI overview dashboard puts up to four builder queries (A to D) inside one CompositeQuery.
- Sections are several `layouts` entries of kind `Grid`. Each has an optional `spec.display.title` and its own coordinates starting at (0, 0). The reference has 5 Grids.
- Variables: `ListVariable` with `spec{name, display{name, description}, allowMultiple, allowAllValue, sort, plugin}`. Plugin kinds: `signoz/DynamicVariable` (`spec{name, signal}`), `signoz/QueryVariable` (`queryValue`, ClickHouse SQL), `signoz/CustomVariable` (`customValue`).
- Panel kinds: TimeSeries, BarChart, AreaChart, Number, PieChart, Table, Histogram, List, Text, Heatmap, ScatterPlot, GeoMap, TopList.
- `PanelFormatting{unit, decimalPrecision}` with precision `0` to `4` or `full`. `TableFormatting{columnUnits, decimalPrecision}`.
- Thresholds: `ComparisonThreshold{value, operator, unit, color, format}` for Number and TopList; `ThresholdWithLabel{value, unit, color, label}` for TimeSeries, BarChart, AreaChart; `TableThreshold` adds `columnName`.
- `TextPanelSpec{mode: "markdown", text, presentation{textAlign, verticalAlign, background}, headerOptions{hide}}`. A Text panel has no query; the lint's "one query per panel" check needs an exemption for it.
- `Axes{softMin, softMax, isLogScale}` with nullable bounds. `TimePreference`: `global_time`, `last_5_min` to `last_1_month`.
- Metrics builder: `name`, `stepInterval`, `signal: "metrics"`, `aggregations[{metricName, timeAggregation, spaceAggregation, reduceTo}]`, `filter{expression}`, `groupBy[{name, fieldContext, fieldDataType}]`, `order[]`, `limit`, `legend`. Unknown fields are rejected.
- The provisioner converges dashboards by slug: unchanged ones are skipped, changed ones are PUT in place with the uuid preserved, owned dashboards that are no longer desired are deleted. A dry-run dashboard tagged `owner=systemnix` is therefore cleaned up by the next provisioner run even if its own delete is lost.

## Appendix B: live state at report time

| Fact | Value | Read at |
| --- | --- | --- |
| Live dashboard | 13 panels, 1 layout, 0 variables, broken units, `updatedAt` 2026-11-25T05:09:24Z (06:09:24 CET) | 06:23 |
| Provisioner | "Updating in place: systemnix-ai-meter", "OK dashboard updated (HTTP 200)" | 06:09:24 |
| ai-meter process start | `ai_meter_start_time_seconds 1795583396` = 06:09:56 CET (previous process: 05:09:14) | 06:23 |
| Calls in this process | 357: 234 with 200, 123 with 429 | 06:23 |
| Spans exported | ok 357, failed 0, dropped 0 (previous process: ok 1027, failed 0, dropped 0) | 06:23 |
| In flight | crush/zai/glm-5.4 = 3, cvagent/zai/glm-5.3-flash = 1 | 06:23 |
| Metric families live | 12. In tree at HEAD: 16 (plus the three admission families). | 06:25 |
| System | `/run/current-system` equals `system-1030-link` | 06:23 |

## Appendix C: scratch (not volatile, `~/.cache/aimeter/`)

`render-units.mjs` (faithful port of the panel formatting path), `render-units.test.mjs` (the run quoted above), `grafana/` (the extracted formatter sources with stubs), `grafana-unit-ids.txt` (272 ids), `signoz-universal-unit-ids.txt` (273 values), `inspect.py` (prints layouts, variables and one panel per kind of a v6 dashboard), `probe.py` (`get`, `post`, `promql` against `http://127.0.0.1:8080`), `metrics-live-3.prom` (scrape of 05:45), `ref-ai-o11y-overview.json`.
