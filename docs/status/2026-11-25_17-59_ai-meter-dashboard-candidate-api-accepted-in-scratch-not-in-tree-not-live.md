# AI Meter dashboard: rewritten candidate is API-accepted but lives only in scratch — not in the tree, not live; box runs gen-1029 after two crashes

**Session:** 2026-11-25 11:13 → 17:59 CET (own tool activity 11:13–11:38 and 17:31–17:59; the gaps were waiting on turns)
**HEAD at authoring:** `691e87d3b` (tree dirty with foreign edits: `CHANGELOG.md`, `FEATURES.md`, `README.md`, `docs/agents/desktop.md`, `docs/agents/integration-registry.md` — not mine, untouched)
**Predecessor:** [2026-11-25 06-25 self-review](./2026-11-25_06-25_ai-meter-dashboard-unit-ids-fixed-in-tree-not-live-rewrite-not-started-session-self-review.md)
**Trigger:** sixth "READ, UNDERSTAND, RESEARCH, REFLECT … keep going until everything works" after the pause; then this status request.

---

## Headline

1. **The owner-visible state did not change.** The live dashboard `systemnix-ai-meter` (id `01a148a8-81c0-7605-9028-fe0d8ca11832`) is the **gen-1029 version**: 13 panels, 1 layout, literal `{percent}` / `{req/min}` / `{USD}` units (read back 17:33, `updatedAt` 10:09:27Z). The unit fix (`ba2536b48`) is still only in the tree.
2. **A complete rewrite exists and is accepted by the live API**: 38 panels in 6 sections, in scratch (`~/.cache/aimeter/r2/`), not written to the repo. All 38 queries answer HTTP 200 on the live API; a throwaway copy was created (201), read back (38 panels, 6 layouts) and deleted (204, verified gone).
3. **The live system is not what the previous report assumed.** The box crashed twice (boot `-2` ended 08:57:47, boot `-1` 08:58:54 → 11:05:51, boot `0737ecd7` since 11:06:51) and booted **gen-1029** (`/run/booted-system` = `/run/current-system` = `gwfgxm1vy…`, built 11-24 23:33). A sibling session owns that ([11-20 report](./2026-11-25_11-20_library-policy-vendorhash-fixed-gen1030-never-bootable-crash-revert.md); I read only its first 12 lines). Consequence for this work: the running ai-meter is the **old binary** — 11 metric families, `ai_meter_active_requests` with no labels, no span export, no admission families.
4. **Prod mutations by me:** one throwaway dashboard, live 17:31:16 → ~17:32, deleted. Nothing else.

---

## a) FULLY DONE

1. **Re-pinned state and caught the rollback** before trusting the predecessor's "live" facts: boot list, `/run/booted-system`, `system-1029/1030-link` targets, `/etc/signoz/dashboards/ai-meter.json` symlink mtime (11:06:54), provisioner run at boot (dashboard `updatedAt` 10:09:27Z).
2. **Read the live dashboard** through `/api/v2/dashboards/<id>` (`/api/v1/…` on :8080 answers the frontend HTML).
3. **Research, each item verified against the locked SigNoz rev `da35d997` or the live API** (not recalled):
   - Panel/query shapes from `api/generated/services/sigNoz.schemas.ts`; backend rules from `pkg/types/dashboardtypes/perses_dashboard_data.go` + `perses_plugin_wrappers.go`: every panel has exactly one top-level query, a Text panel must have `queries: []`; **Table and Pie panels refuse `signoz/PromQLQuery`** (also inside a CompositeQuery) and take builder, formula, trace-operator or ClickHouse queries only.
   - Thresholds: `ComparisonThreshold{value, operator, color, format: text|background}`; **earliest-declared match wins** → most severe first; a threshold without `operator` never matches. Palette `RED #F1575F`, `ORANGE #F5B225`, `GREEN #2BB673`, `BLUE #4E74F8` (`Panels/types/threshold.ts`).
   - Legends: `{{label}}` is expanded client-side from series labels (`lib/getLabelName.ts`); an empty legend prints `{a="x",b="y"}`.
   - Number panel = first row's value column of the scalar result; the request type comes from the panel kind (`queryCapabilities.requestType`), not from the stored `kind`.
   - Table with several queries: the server joins them on the group-by columns (`/api/v5/query_range`, verified: `['model', '__result_0', …]`); column names come from each query's `legend`, units from `formatting.columnUnits[queryName]`.
   - Builder queries: valid `having` references are `__result`, `__result0`, `<agg>(<metric>)`; valid `order` keys are `0`, `__result`, group-by keys, aggregation expressions. Filter syntax `upstream in ["zai"]`, `code = "200"`. Formula envelope `{"type":"builder_formula","spec":{"name","expression","disabled","legend"}}`.
   - **Builder `increase` with a 24 h step is wrong** (`stepInterval: 86400` → glm-5.4 2728 calls); `stepInterval` 60 or 300 with `reduceTo: "sum"` matches PromQL `increase(...[24h])` (7603 vs 7666; glm-5.3-flash 11234 vs 11214; bge-m3 717 vs 743). Raw-sample check for glm-5.4/code 200: positive-delta sum 5824 vs PromQL 5864.
   - Variables are substituted **server-side** (`variables` map in the v5 request): `=~"$client"` works for one, many and the `__all__` sentinel; `="$client"` with many values and a missing selection both return **empty**. Dynamic variable options come from `/api/v1/fields/values?signal=metrics&name=<label>` and are a union over **every** metric carrying that label (`upstream` lists Caddy's `127.0.0.1:8112`, `model` lists 30+ names).
   - Units through the real `@grafana/data@11.6.15` formatter (`~/.cache/aimeter/r2/units-check.mjs`): `percent` → `96.5%`; `reqpm` → `1.23K req/m` (2 decimals); `suffix:USD/h` needs 4 decimals (`0.0042 USD/h`, 2 decimals print `0`); `count:tokens/s` → `42.1K tokens/s`; `currencyUSD` → `$13.81K`; `bool` → `True`; `s` self-scales (`18720` → `5.2 hours`); Grafana `h`/`d` are **not** hour/day of a seconds value (`18720` → `2.14 years`) — do not use.
   - Refresh keys: `off 5s 10s 30s 1m 5m 10m 30m 1h 2h 1d` (`container/TopNav/AutoRefreshV2/constants.ts`). Grid is 12 columns; sections are several `layouts` Grid entries with optional `spec.display.title`, each starting at (0,0).
4. **Tooling (scratch, non-volatile, `~/.cache/aimeter/r2/`):** `build.py` (declares the dashboard as data and writes the JSON), `render.sh` (runs the repo's real Nix renderer with evo-x2's live costs: 4.8 s), `verify.py` (sends every panel's query to `/api/v5/query_range` with the panel kind's request type), `dryrun.py` (create throwaway → read back → delete; create status 201 handled since 17:59), `probe5.py`, `probe_builder.py`, `schema.py` (prints named types from the generated schema), `dash.py` (panel table of a file or a live id).
5. **Candidate dashboard** (`candidate-raw.json` = template with both placeholders, `candidate-rendered.json` = rendered): 38 panels, 6 sections, 2678 lines raw. The two guarded panels keep their names and their bare-PromQL shape (`Spend Rate`, `Spend Rate by Model`, `@@spendRate@@` / `@@spendRateByModel@@`), so `checks.ai-meter-spend-promql` can still read them.
6. **Verification of the candidate against the live API:** 38/38 queries HTTP 200 (`verify-rendered.log`, 17:59; the two `last_1_day` tables were exercised over the verifier's 30-minute window, so their numbers in that log are 30-minute figures). API validation: `POST /api/v2/dashboards` → 201 at 17:31:16; read back 38 panels / 6 layouts / `refreshInterval` `1m`; `DELETE` → 204; the list holds only the real ai-meter dashboard afterwards.
7. **Caught a wrong number before it shipped:** `sum by (model) (increase(ai_meter_cost_usd_total[24h]))` returned $2414 for glm-5.3-flash while its tokens at the price table are about $48 a day — the counter steps when a price row lands (the restatement `_ai-meter-dashboard.nix` explains), and `increase` reports the step as spend. The column is not in the candidate; the table description says why.

## b) PARTIALLY DONE

1. **Dashboard rewrite** — complete as a candidate, **not in the tree, not live**. The template in the repo is still the 13-panel unit-fix version.
2. **Template form** — the read-back spec differs from the sent spec only by server-added defaults (`duration: ""`, `unit: ""` on group-by keys, `temporality: ""`, `signal: ""`, `fieldContext`/`fieldDataType: ""`, `source: ""`, `functions: null`, default `legend` on the Pie). The provisioner decides "unchanged → skip" by comparing canonical JSON of file vs live, so a file without those defaults is re-PUT on every run. Making the template the server-normalized form (placeholders put back) is designed, not done.
3. **Admission section** — built on the family names in `pkgs/ai-meter/metrics.go` as of 11:1x (`ai_meter_admission_inflight|waiting|limit`, `ai_meter_quota_exhausted`, `ai_meter_admission_wait_seconds_sum|count`, `ai_meter_admission_kept_arrival_total`, `ai_meter_upstream_rejections_total`, `ai_meter_admission_outcomes_total`). They are the sibling plan's in-flight names and none is live; queries parse (HTTP 200, empty) and nothing more is verified.

## c) NOT STARTED

- Writing the candidate into `modules/nixos/services/dashboards/ai-meter.json`.
- Lint legs: unit-id allowlist, overlap/bounds over **every** Grid layout, "tables and pies take builder queries only", `underscoreLive` + `ai_meter_admission_wait_seconds_sum|count` (as written, trap 2 of `signoz-query-lint` fails on the candidate); negative tests in `scripts/negative-test-lints.sh`.
- `modules/nixos/services/dashboards/gcp.json` unit `req` → `none`.
- Gates: `signoz-query-lint`, `ai-meter-spend-promql`, `ai-meter-vm`, `nix fmt -- --fail-on-change`, `nix flake check --no-build`, `buildflow -s test-race`.
- Live rollout (direct PUT and/or deploy), live verification, journal/gatus checks.
- Docs (`docs/services/ai-meter.md`, `docs/agents/monitoring.md`, `docs/DOMAIN_LANGUAGE.md`, `CHANGELOG.md`), TODO rows 3952 / 2531 / 2529 / 1625.
- Executing the three alert rules' PromQL against the live API.

## d) WHAT WENT WRONG

1. **Six loop instructions, still nothing visible.** This stretch spent its first 25 minutes of tool time reading SigNoz source before the first artifact. The unit fix and in-flight panels could have been live (direct PUT) inside the first ten minutes; the rewrite would have followed as a second PUT. The predecessor report said exactly this and I repeated the pattern.
2. **Left a throwaway dashboard on the live SigNoz for about a minute.** `dryrun.py` treated HTTP 201 as a failure and returned before its own cleanup, so `systemnix-ai-meter-dryrun` ("AI Meter DRYRUN delete me") stayed after the 17:31:16 create. Deleted at ~17:32 (204) and verified absent; script fixed at 17:59. My object, no other dashboard touched.
3. **Four scripting slips, each caught by a failing output:** wrong accessors three times (`panelSettings`, `data.result`, `query["spec"]["plugin"]`); a patch script for `build.py` raised midway and I read the unchanged output as the new version (caught by the column count); `time` wrote its timing lines into the rendered JSON.
4. **The predecessor's "exact next steps" rested on a live state that no longer existed** (it assumed gen 1030 and the new binary). I caught it at 11:14, but only because the content-pin is a habit, not because the plan had a "has the box rebooted?" step.
5. **Working clock:** my last `date` before the report was 11:14; the report-time `date` said 17:31. I never re-ran it, so timestamps in my scratch notes jump.

## e) WHAT WE SHOULD IMPROVE

1. **Ship order for dashboards:** PUT early, then deepen. The API validates the whole document in one call (0.02 s); a direct PUT is reversible (the previous JSON is saved) and the next deploy makes it durable.
2. **Template = server-normalized JSON.** Probable cause of the long-standing "provisioner re-PUTs caddy + gcp although the files did not change" observation (hypothesis: not checked against those two dashboards). One-time normalization per SigNoz upgrade.
3. **The lint must know the API's rules** before the provisioner does ("Dashboard failures are HARD failures"): a bare PromQL query on a Table/Pie panel is a 400 at deploy time; the lint's check-6 message ("multi-series via `{__name__=~"a|b"}`") points the wrong way for tables; overlap is checked in `layouts[0]` only.
4. **Never derive spend from `increase(ai_meter_cost_usd_total[...])`** — tokens × price at query time is the only sound source (restatement doctrine). Worth a line in `docs/agents/monitoring.md` and the ai-meter runbook.
5. **Builder step trap:** `increase`/`rate` in builder queries must use a small `stepInterval` (60–300) and `reduceTo: "sum"`; a day-sized step returns about a third of the truth.
6. **Foreign bug seen, not touched** (file under the sibling's active edit): `pkgs/ai-meter/metrics.go:452-453` writes `\\n` (a literal backslash-n) after the HELP text of `ai_meter_admission_kept_arrival_total`, so the following `# TYPE … counter` line becomes part of the HELP text and the family is exposed untyped.
7. **Seen on the live metrics at 11:3x–12:0x, not investigated:** `llama-embeddings` answered 502 for 100 % of paperless's `bge-m3` calls (≈25/min); z.ai error rate 12 %, overall success rate 36–38 % with `Non-2xx` ≈ 28/min (no admission control on the old binary); `Metering Errors (24h)` = 8; `Starts (24h)` = 7; at 17:59 the reference spend rate is 5.09 USD/h, all of it glm-5.3 (glm-5.4 is unpriced by doctrine).
8. **Not verifiable from here:** the UI. Legends, threshold colours, table headers, section titles, the Pie defaults and the 1-minute refresh are accepted by the API, not seen rendered.
9. **Rollback artefact:** while gen-1029 runs, the in-flight charts show one line with an `undefined` legend (`{{upstream}}` on an unlabeled series) and every admission/span panel is empty. That resolves with the deploy of HEAD, not with the dashboard.
10. **Load decision to confirm:** `refreshInterval: "1m"` means about 44 ClickHouse queries per minute while the dashboard is open (the viewer iframe on `ai-meter.home.lan`); measured 0.02–0.6 s per query.

## f) NEXT (ordered)

1. ~~Emit the candidate in server-normalized form (defaults included, the two spend placeholders restored, real display name) and write it to `modules/nixos/services/dashboards/ai-meter.json`.~~ done at `d774f5589`
2. ~~`signoz-query-lint`: overlap + bounds (`x + width ≤ 12`, `y ≥ 0`) over every Grid layout; unit ids must be Grafana ids, SigNoz universal ids or `prefix:`/`suffix:`/`time:`/`si:`/`count:`/`currency:`/`bool:` forms; Table/Pie panels carry no PromQL (top-level or inside a CompositeQuery); `underscoreLive` += `ai_meter_admission_wait_seconds_sum|count`; negative legs in `scripts/negative-test-lints.sh`.~~ done at `d774f5589`
3. ~~`gcp.json`: unit `req` → `none`.~~ done — as the unit short, not none (gcp.json at d774f5589)
4. ~~Gates on the touched files: `nix build .#checks.x86_64-linux.signoz-query-lint .#checks.x86_64-linux.ai-meter-spend-promql .#checks.x86_64-linux.ai-meter-vm`, `nix fmt -- --fail-on-change -- <files>`, `nix flake check --no-build`, `buildflow -s test-race`.~~ done — gates green on the final tree on 2026-11-28 (the five dashboard and ai-meter checks, 44 of 44 negative legs, the all-systems flake check at 02:32); buildflow test-race was not run by the dashboard sessions
5. ~~Rollout (question 2): direct `PUT /api/v2/dashboards/01a148a8-…` with the rendered file, or the deploy.~~ done — rolled out: v3 was PUT by hand on 2026-11-26 at 01:40 and carried by every deploy since (generation 1033 on 2026-11-27)
6. ~~Verify live: units on every panel, sections, tables, `journalctl -u signoz-provision` ("Unchanged … skipping" on the run after the first), gatus "ai-meter dashboard".~~ done — verified live 2026-11-26 to 2026-11-28: units on every panel, the provisioner skip lines (06:48 on 2026-11-26, 10:28 on 2026-11-27), both gatus conditions read by hand on 2026-11-28
7. Docs: `docs/services/ai-meter.md` (panel/query matrix, the Table/Pie rule, the spend-source rule), `docs/agents/monitoring.md` (unit ids, server-side variables, `/api/v5/query_range` envelope and `data.data.results`, builder step trap, provisioner skip vs server defaults), `docs/DOMAIN_LANGUAGE.md`, `CHANGELOG.md`, TODO rows 3952 / 2531 / 2529 / 1625. **→ the docs half is done at 7e04a5fa2 and e0913aef8; the four queue rows were cited by line number and cannot be resolved today (the queue moved), so they stay open**
8. ~~Run the three alert rules' PromQL once against the live API.~~ done — the rules PromQL ran against the live API (23-28 report)
9. Optional: spend per model over 24 h as a third renderer placeholder (`@@spend24hByModel@@`) with a promtool case in `ai-meter-guards.nix`. **→ routed to docs/todo/monitoring.md "A 24-hour spend per model on the ai-meter dashboard" (optional)**
10. ~~Optional: filter variables (decision below stands until you object).~~ **Won't implement — no filter variables (decided in this report; the dashboard carries none).**
11. ~~Optional: a traces panel (List or Text) linking the native AI trace explorer.~~ done at `0779937ac`
12. ~~Tell the admission session about `metrics.go:452` (`\\n`) and confirm the family names at their T07.4 hand-off.~~ done — verified: the TYPE line of ai_meter_admission_kept_arrival_total is a counter on the live endpoint (23-28 report)
13. ~~Queue the `llama-embeddings` 502 observation for the owner of that service.~~ **NOT-DO — a duplicate, the queue already carries rows on llama-embeddings.**
14. ~~Check the provisioner-skip hypothesis on `caddy.json` / `gcp.json` (read back, diff against the files).~~ done — verified: caddy and gcp lacked the server-default keys, were PUT once and skipped from then on (2026-11-26 06:17 and 06:48)
15. ~~Replace the stale "exact next steps" of the 06-25 report with a pointer to this one.~~ done (docs-health pass 2026-11-28)

**Harvest: deliberately not harvested** (`TODO_LIST.md` + domain libraries untouched) — items 1–8 are in flight in this session and a `[ready]` row would hand the same dashboard JSON to a parallel session.

**Decided by default (object if wrong):** no filter variables (the option lists mix in other exporters' label values, and a panel that references a variable is empty whenever its selection is missing); spend stays with the two guarded panels plus tokens; admission and health panels live inside the one existing dashboard as sections; English `x` instead of `×` in titles (the old `×` was an escaped code point in the file).

## g) QUESTIONS

1. **Commits:** may I commit my own files with descriptive messages? Without the word "commit" I leave everything to the heuristic daemon sweeps.
2. **Go-live path:** the box runs gen-1029 and HEAD carries the admission session's in-flight ai-meter code. Should I (a) PUT the dashboard straight to the live API once it is in the tree and the gates pass, and (b) leave the deploy to you / the admission plan's T04, or may I deploy myself (`scripts/deploy-when-quiescent.sh --fire`)?
3. **Refresh:** keep `1m` (live in-flight numbers, ≈44 ClickHouse queries/min while the dashboard is open) or go back to `5m`?

---

## Appendix A — candidate panels (38)

| Section | Panels |
| ------- | ------ |
| (untitled) In flight | In Flight (N); In Flight: Provider x Model x Client (Table, builder `latest`, busiest first, only > 0); In Flight by Provider / by Model / by Client (TS) |
| Traffic | Requests / min; Success Rate (5m) (red < 90 bg, orange < 98, green ≥ 98; empty while idle); Non-2xx / min (red > 10 bg, orange > 2); Reachable (True/False, red when False); Process Uptime; Requests by Provider; Requests by Model x Code; Failures by Code; Error Rate by Provider (10 % line) |
| Tokens & spend | Tokens / min; Cache Hit Rate; Spend Rate (placeholder, 4 decimals); Spend (all-time); Spend Rate by Model (placeholder, 4 decimals); Tokens by Kind; Models: Last 24 Hours (Table: builder A calls, B prompt, C cached, D output tokens, E hidden `code = "200"`, formula `F = (E / A) * 100`) |
| Latency | Avg TTFT (red > 10 s, orange > 5 s); Avg Duration; Avg TTFT by Model; Avg Duration by Model; Output Speed by Model (tokens/s of generation) |
| Health | Starts (24h); Metering Errors (24h) (red > 0); Unauthorized (24h) (orange > 0); Span Export Failures (24h) (red > 0); Traced Calls (24h) (green ≥ 99, orange < 99); Span Export by Outcome |
| Admission (z.ai rate limit) | Quota Exhausted (True/False, red); Calls Lost to Admission (24h) (red > 0); Admission: In Flight, Waiting, Limit (`label_replace` union); Admission Outcomes (24h) (Pie, builder); Upstream Rejections: Last 24 Hours (Table, builder); Avg Admission Wait |

N = Number, TS = TimeSeries. Every `or vector(0)` sits on a label-stripping `sum`/`count`/`max`: a bare `changes(...) or vector(0)` returns two rows because the labelled series does not match the empty label set of `vector(0)` (seen live, value 7 next to 0).

## Appendix B — live state at 17:33

- Booted and running: `gwfgxm1vy…` (gen-1029, built 11-24 23:33); profile link says `system-1030-link` → `hggzirywc…` (not booted).
- ai-meter: 11 families, `ai_meter_active_requests` unlabelled, process up since 11:07:01.
- Dashboards: 10, of which one ai-meter (`systemnix-ai-meter`, 13 panels, gen-1029 content).

## Appendix C — commands that worked here

```bash
cd ~/.cache/aimeter/r2
python3 build.py ./candidate-raw.json                 # writes the template form
./render.sh "$PWD/candidate-raw.json" "$PWD/candidate-rendered.json"
python3 verify.py candidate-rendered.json             # 38 queries against /api/v5/query_range
python3 dryrun.py candidate-rendered.json             # create → read back → delete
python3 schema.py --deps DashboardtypesTablePanelSpecDTO
node units-check.mjs
```

- The v5 response keeps results in `data.data.results[]` (`columns[]`, `data[][]`; time series under `results[].aggregations[].series[]`).
- `/api/v1/query` on :8080 returns HTML; use `/api/v5/query_range`.
- Guard variables before `ls "$dir"`; `rg -r` is replace.
