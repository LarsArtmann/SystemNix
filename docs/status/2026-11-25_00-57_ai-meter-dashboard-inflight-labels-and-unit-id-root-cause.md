# AI Meter dashboard: labeled in-flight gauge + unit-id root cause (status 2026-11-25 00:57)

**Scope line.** Session task: "make the AI Meter SigNoz dashboard better: In-flight per provider/model, `{percentage}` should be `%`, plus everything else". Report at `f4d4f8596` (`git rev-parse --short HEAD`, 2026-11-25 00:57:24 CET), session started at `c9c662d5c`.

**Verified here (command or artifact named):**

- Go: `cd pkgs/ai-meter && go build ./... && go vet ./...` exit OK; `go test -race -count=1 ./...` reported `ok github.com/larsartmann/systemnix/ai-meter 1.065s` at `f4d4f8596` (tail only). The run before the foreign commit `f4d4f8596` listed 23/23 PASS (`-v`, ~00:51).
- Live, read-only: `GET 127.0.0.1:8080/api/v2/dashboards?limit=100` (10 dashboards) and `GET /api/v2/dashboards/<id>` per dashboard; `GET 127.0.0.1:8108/metrics` twice (00:45 and 00:52), saved as `~/.cache/aimeter/metrics-live.prom` and `metrics-live-2.prom`.
- Source read: SigNoz `da35d997` (the locked `signoz-src` rev) at `/nix/store/hk3kq36v4c2lnn3bsj5l9ircq4skrf41-signoz-da35d99-patched` (`pkg/types/dashboardtypes/*.go`, `pkg/types/querybuildertypes/querybuildertypesv5/*.go`, `pkg/querier/promql_query*.go`, `frontend/src/components/YAxisUnitSelector/*`, `frontend/src/components/Graph/yAxisConfig.ts`, `frontend/src/pages/DashboardPage/DashboardContainer/VariablesBar/*`). Grafana `@grafana/data@11.6.15` formatters were extracted from the deployed bundle's source map `/nix/store/k7ldflypkw9n3sdg3mc7bf08qhp8g6hq-signoz-frontend-da35d99/share/signoz/web/assets/index-DZX7Gw7n.js.map` (copies: `~/.cache/aimeter/grafana-*.mjs`).
- Git attribution: `git log c9c662d5c..HEAD -- pkgs/ai-meter/` and `git show --stat` per commit.

**NOT verified here (and why):**

- The dashboard is unchanged. `modules/nixos/services/dashboards/ai-meter.json` was not edited, and no panel query was executed against the query API (the helper `~/.cache/aimeter/probe.py` exists but its `promql()` was never called).
- Unit rendering was derived from source, not observed in a browser (no browser access). The reading matches the owner's report of a literal `{percentage}`.
- Builder-query JSON for Table/Pie/TopList panels and the variable value sources (DYNAMIC vs QUERY) were read from Go types and bundled example dashboards, never executed against the live API.
- No `buildflow` run, no `nix flake check`, no VM test (`ai-meter-vm`), no deploy.
- Whether CI or any flake check compiles `pkgs/ai-meter` tests. A non-compiling test file sat on `master` for 4 minutes (see d1).
- Consumers of `ai_meter_active_requests` or of the `model=""` label outside this repo (other hosts, exports).
- The concurrent session's replay/cost work (commits `8abb7e9be`, `f4d4f8596`) was not reviewed, only confirmed to compile and pass tests alongside mine.

## TL;DR

1. The user-visible deliverable is at 0 %: the live dashboard still shows `{percent}`-style units and one unlabeled in-flight number.
2. The exporter side of "in-flight per provider/model" is coded and green under `-race`: `ai_meter_active_requests{client,upstream,model}`. It is committed only through heuristic daemon commits and is not deployed.
3. Root cause of the unit bug is nailed from source: five unit ids in `ai-meter.json` are not known ids, and Grafana's formatter prints an unknown id verbatim as a suffix.
4. Flag: a second session edited `pkgs/ai-meter/metrics.go` and `proxy.go` minutes after me. The tree is green at `f4d4f8596`.
5. Observed: 31 % of routed calls since the last restart are non-2xx (587 of 1900 are HTTP 429), and `cv-tailor` is 5/5 failing with 429 on `synthetic`.

## a) FULLY DONE

Research only. No code or config of this session is deployed.

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | Unit-id root cause. SigNoz formats a panel value with `getYAxisFormattedValue`: literal `none` is plain, a member of the `UniversalYAxisUnit` enum goes through `formatUniversalUnit`, everything else goes to Grafana `getValueFormat(id)`. Grafana 11.6.15 returns `toFixedUnit(id)` for an unknown id, which appends `" " + id` verbatim. | `components/Graph/yAxisConfig.ts` lines 55-100; `grafana-valueFormats.mjs` `getValueFormat`; `isUniversalUnit` in `YAxisUnitSelector/utils.tsx` |
| a2 | The five broken ids, all in `ai-meter.json`: `{percent}` (1 panel), `{req/min}` (4), `{USD}` (1), `{USD/h}` (2), `{tokens/min}` (1). `{count}` (3 panels) and `s` (4) are valid. | `rg '"unit"' modules/nixos/services/dashboards/*.json` counts |
| a3 | Valid replacements, from source: `percent` renders `68.9%`; `currencyUSD` renders `$2.15` with K/M scaling; `reqpm` renders `12.3 req/m`; custom forms `suffix:<text>`, `count:<symbol>`, `prefix:<text>`, `si:`, `currency:`, `bool:` are parsed by `getValueFormat` (for example `suffix:USD/h`, `count:tokens/min`). | `grafana-valueFormats.mjs`, `grafana-categories.mjs` (271 ids) |
| a4 | The other nine dashboards carry no id of this class. Their ids are `none`, `percent`, `{count}`, `{count}/s`, `By/s`, `s`, `ms`, `reqps`, `bytes`, `celsius`, and `req` in `gcp.json`, which is not a known id but prints `12 req`, which is the intended text. Caveat: source-derived, not browser-observed. | same survey |
| a5 | Panel and query compatibility. Table and Pie accept builder, AI builder, composite, formula and trace-operator queries but no PromQL and no ClickHouseSQL. TopList accepts no PromQL. Text takes no query. Every other panel takes exactly one query. | `allowedQueryKinds`, `pkg/types/dashboardtypes/perses_plugin_wrappers.go` |
| a6 | The v2 API decodes every panel spec with `DisallowUnknownFields` plus validation. One unknown field is HTTP 400, which the provisioner turns into a hard deploy failure. | `decodeSpec` in the same file; `_signoz-scripts.nix` lines 404-529 |
| a7 | Dashboard schema facts: `spec.variables` must be an array; `ListVariable` takes `name`, `display`, `allowMultiple`, `allowAllValue`, `sort`, and a plugin of kind `signoz/DynamicVariable` (`name`, `signal`), `signoz/QueryVariable` (`queryValue`, ClickHouse SQL) or `signoz/CustomVariable` (`customValue`). References are `$name`, `{{name}}`, `[[name]]`. A multi-select with `allowAllValue` defaults to ALL. Sections are extra `layouts` Grid entries with `spec.display.title`. `refreshInterval` is stored but not applied by the UI. `duration` sets the default time range. | `perses_replicas.go`, `perses_dashboard_data.go`, `resolveVariableSelection.ts`, `buildVariablesPayload.ts`, `pkg/types/dashboardtypes/testdata/perses_with_sections.json` |
| a8 | Live dashboard state: slug `systemnix-ai-meter`, id `01a148a8-81c0-7605-9028-fe0d8ca11832` (pinned as `dashboardId` at `modules/nixos/services/ai-meter.nix:86`), 13 panels, 1 layout, 0 variables. The provisioner updates in place by slug, so the id survives as long as the slug is kept. | `probe.py` run; `_signoz-scripts.nix` |
| a9 | Live exporter state: `ai_meter_active_requests` is one unlabeled scalar (5 at 00:45, 6 at 00:52), so no PromQL can split it by provider or model today. | both metric snapshots |

## b) PARTIALLY DONE

| # | Item | Works now (evidence) | Open | Blocker | Effort |
| - | ---- | -------------------- | ---- | ------- | ------ |
| b1 | Labeled in-flight gauge | `pkgs/ai-meter/metrics.go`: `Call` type with `BeginCall`, `SetModel`, `End`; `Registry.inflight` keyed by client, upstream, model; the old scalar, `Begin()` and `End()` are gone. `pkgs/ai-meter/proxy.go` calls `BeginCall` after auth, `SetModel` once the body names a model, and normalizes an empty model to `"none"` in `record()`. Tests: `metrics_test.go` (2), `proxy_test.go` (+2). Build, vet and `go test -race` green at `f4d4f8596`. | Not deployed. Commit messages are the daemon's heuristic ones. My file views predate the foreign edits to the same two files. | Deploy decision (question 1) | S to finish code, M to deploy |
| b2 | Dashboard design knowledge | Items a1-a9. | Builder-query and variable payloads untested live. PromQL join behavior for multi-value variables in the v5 path not read (the v3 path joins with `\|`). | none | S |
| b3 | Step plan | Todo list with 9 steps, 1 completed. | 7 steps open. | none | n/a |

Behavior changes I introduced on purpose, for the owner to veto:

- A bare `ai_meter_active_requests` selector now returns one series per client, upstream and model. A total needs `sum(ai_meter_active_requests)`. In-repo consumers: only the dashboard (`rg 'ai_meter_active_requests'`, no alert rule, no test).
- Records that carry no model are now labeled `model="none"` in every metric family and in the ledger. Before, a non-JSON body on a metered path produced `model=""`, which contradicted the runbook line "parse failures degrade to request-counting (`model="none"`)".
- Idle in-flight series stay exposed at 0 (keys are never removed), so lines do not blink out between scrapes.

## c) NOT STARTED

| # | Item | Why not | Priority |
| - | ---- | ------- | -------- |
| c1 | Rewrite `ai-meter.json` (units, in-flight split, more panels) | Research came first; the session was interrupted for this report. | Critical |
| c2 | Verify every panel query against the live query API | Depends on c1. | Critical |
| c3 | Dry-run validation of the dashboard JSON against the live v2 API | Depends on c1. Mandatory per a6. | Critical |
| c4 | Unit-id leg in `signoz-query-lint` plus negative test | Prevention layer for the a1 bug class. | High |
| c5 | Docs: `docs/services/ai-meter.md` (metric semantics, dashboard layout), `docs/agents/monitoring.md` (unit rule, panel/query matrix), CHANGELOG, TODO rows | Depends on c1. | High |
| c6 | `buildflow -s test-race`, `nix flake check --no-build`, `ai-meter-vm` | Canonical gates, not run. | High |
| c7 | Deploy and live verification | See question 1. | Critical |
| c8 | Proper commit message for the daemon-swept ai-meter commits | Shared batches, see d5. | Medium |

## d) TOTALLY FUCKED UP

| # | What | Severity | Root cause | Mitigation or state |
| - | ---- | -------- | ---------- | ------------------- |
| d1 | A non-compiling test file was on `master` from 00:42:30 to 00:46:28 (`3fce8cab8`): I wrote `req.Header().Set` in `proxy_test.go`. `go build ./...` still passed (the chain reached `go vet`, which failed), so the production derivation was unaffected. | Low for prod, real for anyone running `go test` in that window. | Typo, plus I did not compile before the daemon swept the file. | Fixed in `267d5a8d1`. Unverified whether CI ran in that window. |
| d2 | The same commit carried a wrong assertion (`TestCallMovesItsInFlightMark` asserted the pre-`SetModel("")` state after calling it), so one test was red. | Low. | I wrote the expectation before tracing my own sequence. | Fixed in `267d5a8d1`, 23/23 PASS afterwards. |
| d3 | Neither explicit ask is visible: the live dashboard still prints `{percent}`, `{req/min}`, `{USD}`, `{USD/h}`, `{tokens/min}` and one unlabeled in-flight number. | User-facing. | I went deep into SigNoz and Grafana source before making the one-line `%` fix. | c1, c7. |
| d4 | 31 % of routed calls since the last restart are non-2xx: 591 of 1900 (00:52 snapshot). zai: 1309 x 200, 582 x 429, 3 x 502. By model, non-2xx share: glm-5.3 43.7 %, glm-5.3-flash 31.6 %, glm-5.4 29.0 %. | High if sustained. | Unknown. Rate or concurrency limits on the zai coding plan are the likely cause, per the runbook. | Not investigated. Existing rows: "Tame concurrency at the source", "Bounded retry-with-jitter for 429s at the proxy". |
| d5 | `cv-tailor` on `synthetic` / `syn:large:text`: 5 of 5 calls HTTP 429 (client appeared between the 00:45 and 00:52 snapshots). | Potentially high for CV cover-letter drafting. | Unknown. | Not investigated. |
| d6 | My work sits only in heuristic daemon commits: `b93e4b289` (my `metrics.go`, `proxy.go`), `3fce8cab8` (my two test files plus three foreign `docs/todo/*` edits), `267d5a8d1` (my test fixes). `3fce8cab8` cannot be amended without absorbing foreign files, and HEAD has moved. | Cosmetic, but history is unattributable. | Daemon cadence versus my edit-to-test gap. | Needs a pathspec-safe repair or a forward commit message (c8). |
| d7 | Concurrent session on the same files: `8abb7e9be` and `f4d4f8596` (another session) added `replay.go`, `cost_test.go`, `replay_test.go`, changed `config.go`, `ledger.go`, `main.go`, and edited `metrics.go` and `proxy.go` after me. | No breakage found: build, vet and tests green at `f4d4f8596`. | Two sessions, one package. | My in-context views of `metrics.go` and `proxy.go` are stale: re-read before any edit. |
| d8 | `gemini` / `gemini-3.5-flash`: 1 call, HTTP 402. | Low. | Already queued as "crush gemini upstream returned a 402". | Still a single occurrence at 00:52. |

Self-review, what I forgot or could have done better:

- I did not run the tests right after writing them. The first compile happened only when this report forced it.
- I ran `gofmt -l` in a BuildFlow-covered repo after loading the skill that says formatting belongs to `buildflow format`. Nothing was rewritten. The listing flagged two files I never touched (`config.go`, `usage_test.go`), so it says nothing about my edits.
- I did not re-pin the tree right before each write. Ten foreign daemon commits landed during the session. No collision occurred.
- I did not ship the trivial `%` fix first.
- I read the v3 PromQL variable join but not the v5 `formatValueForProm` body, then nearly relied on it.

## e) WHAT WE SHOULD IMPROVE

| # | Pattern | Impact | Fix |
| - | ------- | ------ | --- |
| e1 | Nothing checks dashboard unit ids, so a wrong id renders verbatim forever. | The owner found this by eye after five weeks. | Unit-id leg in `signoz-query-lint`: a braced id must be one of the SigNoz universal units. Negative test in `scripts/negative-test-lints.sh`. |
| e2 | Dashboard JSON is validated only by the lint's one-query and overlap legs. Unknown panel fields fail inside `signoz-provision`, during the deploy. | A typo costs a full build and switch cycle. | Dry-run the rendered dashboards against the live v2 API as a pre-deploy check. |
| e3 | Dashboards are written by hand against a strict, typed schema. | Slow and error-prone. | Record the panel/query matrix and the strict-decoding rule in `docs/agents/monitoring.md`. |
| e4 | The dashboard has no variables and no sections. | Every panel is fleet-wide. | Variables (upstream, model, client) and titled sections, starting with ai-meter. All ten systemnix dashboards have 0 variables today. |
| e5 | Only averages exist for latency and TTFT. | No p95. | Histogram families in ai-meter (rows 1623 and 2569 in `TODO_LIST.md`). |
| e6 | `refreshInterval` is ignored by the UI. | The embedded viewer at `ai-meter.home.lan` never auto-refreshes. | Check whether a URL parameter or a viewer-side reload works. |
| e7 | Quick wins were sequenced after research. | Delayed feedback. | Ship the smallest visible fix first, then iterate. |
| e8 | Two sessions changed `metrics.go` and `proxy.go` within 20 minutes without knowing of each other. | Silent semantic collisions are possible (mine: in-flight and model label; theirs: cost replay). | Whoever finishes last re-reads and updates `docs/services/ai-meter.md`. |
| e9 | Daemon commits mix sessions' files under one heuristic message. | History is unattributable, and a broken file lands on `master` within minutes. | Keep the edit-to-green gap minimal. Run `go build ./... && go vet ./...` before pausing. |

## f) Things to get done next

Items 1-12 resume this task. Items 13-16 are new observations from the live data. Items 17-24 are wider improvements. None is harvested into `TODO_LIST.md` (see the harvest note).

| # | Task | Impact | Effort | Category |
| - | ---- | ------ | ------ | -------- |
| 1 | Re-read `pkgs/ai-meter/metrics.go` and `proxy.go` at HEAD and confirm the in-flight gauge and the model normalization survived the foreign edits intact. | Critical | S | Quality |
| 2 | Run the canonical Go gate for the module (`buildflow -s test-race`) and record the output. | Critical | S | Quality |
| 3 | Fix the five literal unit ids in `ai-meter.json` per a3. | Critical | S | Bug |
| 4 | In-flight: total stat on `sum(ai_meter_active_requests)`, a time series by upstream and model, and a current-breakdown table. | Critical | M | Feature |
| 5 | Verify every PromQL panel query against `/api/v1/query` before the JSON is committed. | Critical | M | Quality |
| 6 | Execute one builder query (metric name, filter, group by, `scalar` request) against `/api/v5/query_range` to pin the shape needed by Table and Pie panels. | Critical | M | Quality |
| 7 | Add variables for upstream, model and client, and test the value source live. The attribute key `upstream` is also a Caddy label, so a DYNAMIC variable may list Caddy values. | High | M | Feature |
| 8 | Dry-run the complete dashboard JSON against the live v2 API before deploy (create and delete a throwaway dashboard tagged `owner=systemnix`, or a validate endpoint if one exists). | Critical | S | Quality |
| 9 | Add error attribution: non-2xx share by upstream and model, failures by upstream and code. Today's "Failures by Code" hides which provider returns the 429s. | High | S | Feature |
| 10 | Add latency panels: average duration by model (stream and non-stream), average TTFT by upstream and model, derived output tokens per second. | High | S | Feature |
| 11 | Add token and cost panels: tokens by model, cache hit ratio (cached / prompt), average tokens per request, spend in the selected range per model and per client. | Medium | S | Feature |
| 12 | Stat thresholds, sections, per-client panels (`cv-tailor` is now a second client), proxy-health section (uptime, metering errors, unauthorized), default time range. | High | M | Feature |
| 13 | Investigate `cv-tailor` on `synthetic`: 5 of 5 calls return HTTP 429. Check the synthetic.new plan or quota. | Critical if it persists | S | Bug |
| 14 | Quantify the zai 429 share over 24 h from the ledger (`/var/lib/ai-meter/usage.jsonl`) and tie it to the existing concurrency and retry rows. | High | M | Bug |
| 15 | Identify the driver of the burst: 977 routed calls in 7 minutes (00:45 to 00:52) against 923 in the preceding 1.2 h. | Medium | M | Investigation |
| 16 | Confirm the gemini HTTP 402 is still a single occurrence. | Low | S | Bug |
| 17 | Add the unit-id leg to `signoz-query-lint` with a negative test. | High | S | Quality |
| 18 | Document in `docs/agents/monitoring.md`: unit rule, panel/query matrix, strict decoding, variable syntax and the ALL sentinel. | High | S | Documentation |
| 19 | Update `docs/services/ai-meter.md` for `ai_meter_active_requests{client,upstream,model}`, `model="none"`, and the new dashboard layout. | High | S | Documentation |
| 20 | CHANGELOG entry and TODO row updates (per-client breakdown becomes deliverable, sustained-in-flight rule becomes per model). | Medium | S | Documentation |
| 21 | Align the NumberPanel query kind: current dashboards send `time_series`, the bundled system dashboard sends `scalar`. Verify which is correct. | Medium | S | Quality |
| 22 | Run `nix flake check --no-build` and the `signoz-query-lint` check, then the VM test `ai-meter-vm`. | High | M | Quality |
| 23 | Deploy and verify live: labeled series on `:8108/metrics`, `signoz-provision` updated the dashboard in place, viewer renders. | Critical | M | Feature |
| 24 | Give the ai-meter work a real commit message, pathspec only, without amending foreign files in shared batches. | Medium | S | Cleanup |
| 25 | Pre-deploy dry-run of rendered dashboards against the v2 API (productize item 8). | High | M | Quality |
| 26 | Sustained-in-flight alert rule, per model: `sum by (upstream, model) (ai_meter_active_requests) > N`. | Medium | S | Feature |
| 27 | Histogram latency and TTFT families in ai-meter, then p95 panels. | Medium | L | Feature |
| 28 | Auto-refresh for the embedded viewer (`refreshInterval` is ignored by the UI). | Low | S | Research |
| 29 | Variables and sections for the other nine dashboards once the ai-meter pattern holds. | Low | L | Feature |
| 30 | Reconcile `docs/services/ai-meter.md` with the concurrent replay/cost session in one pass (one owner of the runbook section). | Medium | S | Documentation |

## g) Questions I can not answer myself

1. **Deploy.** When the dashboard and the metric are verified, should this session run `nix run .#deploy` itself, or stage it for a window you pick? A deploy restarts `ai-meter`, which drops the 6 calls in flight at the time (live sessions on this box route through it), and a deploy now would also carry the other session's replay/cost work in the same package.
2. **External consumers.** Is anything outside this repo reading a bare `ai_meter_active_requests` or the empty `model` label (another host, an export, a script)? I grepped this repo and found only the dashboard, but I can not see other machines.
3. **Load or incident.** Is the 429 share on zai (582 of 1894 calls since the restart, 31 %) and the 5 of 5 failures on `synthetic` accepted load from parallel agent sessions, or should I treat either as an incident and investigate?

## Harvest note

Section (f) is deliberately not harvested into `TODO_LIST.md` or the domain libraries: items 1-12 and 17-24 are this task's remaining steps and are owned by this session, and items 13-16 are unverified observations that would become `[ready]` rows the pool could execute in parallel with the running work. If this session is not resumed, harvest items 13-16 into `docs/todo/ai-stack.md` and `docs/todo/monitoring.md`, and items 17-25 into `docs/todo/pipeline.md` and `docs/todo/monitoring.md`.

## Appendix: metric snapshots (live, read-only)

| Snapshot | Routed calls | 2xx | Non-2xx | In-flight | Notes |
| -------- | ------------ | --- | ------- | --------- | ----- |
| 00:45 | 923 | 651 (70.5 %) | 272 (268 x 429, 3 x 502, 1 x 402) | 5, unlabeled | one client (`crush`), upstreams zai and gemini |
| 00:52 | 1900 | 1309 (68.9 %) | 591 (587 x 429, 3 x 502, 1 x 402) | 6, unlabeled | second client `cv-tailor` on `synthetic`, 5 x 429; uptime 1.3 h (`ai_meter_start_time_seconds` 1795559662) |
