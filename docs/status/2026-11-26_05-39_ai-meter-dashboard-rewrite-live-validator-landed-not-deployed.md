# AI Meter dashboard v3 is live and verified in a real browser; validator, guard and docs landed; nothing is deployed

**Written:** 2026-11-26 05:39 CET (`date`), boot `0737ecd7`, HEAD `db2576666`, tree dirty with three files of this session (`TODO_LIST.md`, `docs/todo/ai-stack.md`, `docs/todo/pipeline.md`: two ticked rows).
**Previous report of this work:** [2026-11-25 17-59](./2026-11-25_17-59_ai-meter-dashboard-candidate-api-accepted-in-scratch-not-in-tree-not-live.md). Its "exact next steps" are all either done below or listed in §c.
**Session window with tool activity:** 2026-11-25 20:17 to 2026-11-26 02:05 CET. The session then waited; this report was written at 05:39 on the owner's request.

## Scope line

**Verified here (command and artifact, all run 2026-11-25 20:17 to 2026-11-26 02:05 CET):** every claim in §a has its command in the table. Logs are under `~/.cache/aimeter/r2/gates/`, screenshots under `~/.cache/aimeter/r2/` (`v3-shot-b.png`, `v3-slice-0..4.jpg`, `viewer-shot.png`).

**NOT verified here:**

- `nix flake check --no-build` on the real tree after the port. The last full eval of this tree was the sandbox copy's three checks plus `ai-meter-vm`.
- `buildflow -s test-race`. This session changed no Go file.
- A plain `deadnix` and `statix` run on `lib/signoz-dashboard-lint.nix`. It passed the flake's formatter only.
- The off-LAN path to `ai-meter.home.lan` (forward-auth). The headless browser sat on the LAN.
- What the owner sees in the owner's own browser. The render was checked with a scratch Helium profile on this host.
- The provisioner's "Unchanged: skipping" line for `systemnix-ai-meter`, `systemnix-caddy` and `systemnix-gcp`. It needs the deploy.
- The three span-export alert rules' PromQL against the live engine (not run, see §c).
- The pre-existing warning `integration subdomain(s) without catalog entries: ai-meter` that `nix build .#checks.x86_64-linux.ai-meter-vm` printed. Noticed, not touched (another session's DNS catalog migration).

## TL;DR

1. **The dashboard is live.** `systemnix-ai-meter` (id unchanged, `01a148a8-81c0-7605-9028-fe0d8ca11832`) carries 50 panels in six sections since 2026-11-26 01:40:28 CET. It opens with In Flight, a Provider x Model x Client table and in-flight charts by provider, model and client. Units read as units (`84 %`, `26.4 req/m`, `1.106 USD/h`, `$35.6`, `16.6M tokens/min`), counts are exact (`3,148` calls lost).
2. **It was checked in a real browser.** A headless Helium render of the dashboard page and of `ai-meter.home.lan` shows every section drawn and filled (six full-width stat rows, aligned chart rows, the pie and both tables).
3. **It is not durable yet.** The running generation (`6q9jp84a…`, still gen 1031) carries the old 13-panel file. Until the next deploy, a `signoz` restart or a reboot puts that file back.
4. **The tree matches the live dashboard byte for byte** (live `spec` equals the repo rendering; the dry-run create-read-delete round trip came back identical), so the provisioner will skip it once deployed.
5. **The rules that produced the defects are now code:** `lib/signoz-dashboard-lint.nix` (22-leg selftest, 11 negative legs), four priced queries held to the Go formula, caddy and gcp fixed (they were re-PUT on every deploy since September).
6. **Negative tests:** dashboard rules 19 of 19, `aimeter` group 9 of 9, `ai-meter-vm` green.
7. **Open for the owner (§g):** the deploy, commits, the one-minute refresh.

## a) FULLY DONE

| What | Evidence | Files |
| --- | --- | --- |
| Dashboard rewritten to 50 panels in six sections, live | `PUT /api/v2/dashboards/01a148a8-…` answered 200 at 01:40:28; read back 50 panels, 6 layouts, `refreshInterval` `1m`, id unchanged, `spec` identical to the sent document (`~/.cache/aimeter/r2/put.py`); at 05:39 the live `spec` still equals `v3-live-target.json` | `modules/nixos/services/dashboards/ai-meter.json` |
| Owner's ask: in flight per provider and per model | Panels "In Flight", "In Flight: Provider x Model x Client" (table, busiest first), "In Flight by Provider", "In Flight by Model", "In Flight by Client"; rendered values at 01:41: 18 in flight, `zai/glm-5.4/crush 15` | same |
| Owner's ask: units that are units | Units in use: `percent`, `reqpm`, `suffix:USD/h`, `currencyUSD`, `count:tokens/min`, `count:tokens`, `count:tokens/s`, `locale`, `{count}`, `cpm`, `bool`, `s`. The old file printed `{percent}`, `{req/min}`, `{USD}`, `{USD/h}`, `{tokens/min}` literally (real `@grafana/data` formatter: `96.5 {percent}`, `0.391 {USD/h}`) | same, `lib/signoz-unit-ids.txt` |
| Rendered in a real browser | `node ~/.cache/aimeter/r2/shot.mjs` (scratch profile, DevTools protocol, network quiet, 8 s settle): 40 of 40 `query_range` calls success on the dashboard page; viewer page `ai-meter.home.lan` draws the embedded dashboard | `~/.cache/aimeter/r2/shot.mjs` (scratch) |
| Every row spans all 12 columns | `check_layout()` in the builder refuses a row that does not; screenshots show aligned rows in all six sections | `ai-meter.json` |
| Four priced queries from the renderer | `spendRate`, `spendRateByModel` (byte-identical to before, same sha256), new `spendRateByClient`, `spendLast24h`; the two existing ones unchanged | `modules/nixos/services/_ai-meter-dashboard.nix` |
| Priced queries held to the Go formula | `nix build .#checks.x86_64-linux.ai-meter-spend-promql`: rc=0, three promtool fixtures (one model tied to Go, two models and two clients, empty price table) | `flake/parts/checks/ai-meter-guards.nix` |
| Live arithmetic of the priced queries | Independent re-computation from raw token increases x price table (`~/.cache/aimeter/r2/xcheck-spend.py`): 24 h spend ratio 1.0000, hourly rate ratio 1.0002, per client equal | scratch |
| Dashboard validator | `lib/signoz-dashboard-lint.nix`: layout bounds and overlap in every section, references resolve, placed once, no orphans, one query per panel, query kinds per panel kind, unit ids, server-default keys. On the real files: 3 findings before the fixes, 0 after | `lib/signoz-dashboard-lint.nix`, `lib/signoz-unit-ids.txt` (350 ids), `flake/parts/checks/lint-static.nix` |
| Validator selftest | `nix build .#checks.x86_64-linux.signoz-dashboard-lint-selftest`: "22 legs green" | `flake/parts/checks/lint-static.nix` |
| caddy and gcp dashboards fixed | Both lacked `duration`, `refreshInterval`, `links` (the keys SigNoz adds on store), so the provisioner re-PUT them on every deploy (journal 2026-11-25 19:33:43: "Updating in place" for both while seven others skipped). gcp's "Cloud Run" panel carried the unknown unit `req`. Both files now round-trip identically (`dryrun.py`) | `dashboards/caddy.json`, `dashboards/gcp.json` |
| Negative tests, dashboard rules | `CASES=signozdash,signoz bash scripts/negative-test-lints.sh`: 19 passed, 0 failed (8 existing, 11 new) | `scripts/negative-test-lints.sh` |
| Negative tests, aimeter group | `CASES=aimeter …`: 9 passed, 0 failed (second run; the first had 8 of 9, see §d) | same |
| VM test | `nix build .#checks.x86_64-linux.ai-meter-vm`: rc=0 | none |
| Trap-2 allowlist | `ai_meter_admission_wait_seconds_sum` and `_count` added (standalone counters, live `# TYPE … counter`) | `flake/parts/checks/lint-static.nix` |
| Atomic port of nine files | Built in a copy of the tracked tree first, ported in one command at 01:38:50, all nine `cmp`-identical to the verified copies, new files staged | the nine files above |
| Docs | Runbook section "Dashboard" (sections table, where each number comes from, how to change it), metrics list extended, Checks list extended; `docs/agents/monitoring.md` got the authoring rules (layout, query kinds, unit ids, builder `increase`, server-default keys, v5 query recipe, headless render, variables) and four stale claims corrected; DOMAIN_LANGUAGE terms "In flight" and "Priced query"; two CHANGELOG entries | `docs/services/ai-meter.md`, `docs/agents/monitoring.md`, `docs/DOMAIN_LANGUAGE.md`, `CHANGELOG.md` |
| Two TODO rows ticked on both surfaces | `scripts/tick-todo-rows.sh --apply`: "Dashboards-as-code ref lint in CI", "ai-meter.md runbook gaps: …" (uncommitted, see §b) | `TODO_LIST.md`, `docs/todo/pipeline.md`, `docs/todo/ai-stack.md` |
| Kept-arrival TYPE-line bug of the previous report | Already fixed by the admission session: live `# TYPE ai_meter_admission_kept_arrival_total counter` at 20:17 | none of mine |

## b) PARTIALLY DONE

1. ~~**Live versus tree.** The live dashboard equals the tree's rendering, but only because this session PUT it by hand. `/run/current-system/etc/signoz/dashboards/ai-meter.json` has 13 panels. Durable after the next deploy, not before.~~ done — durable since the deploys of 2026-11-26 and 2026-11-27 (v6 went live by hand on 2026-11-28 and is durable with the next deploy)
2. ~~**Gates after the port.** Done: `signoz-query-lint`, `signoz-dashboard-lint-selftest`, `ai-meter-spend-promql`, `ai-meter-vm`, both negative-test groups. Not done on the real tree: `nix flake check --no-build`, `buildflow -s test-race`, a standalone `deadnix`/`statix` on the new Nix file, `nix fmt -- --fail-on-change` on the three Markdown files and `CHANGELOG.md` (the four Nix files were formatted in the copy and ported after).~~ done — gates green on the final tree on 2026-11-28 (the all-systems flake check, nix fmt, deadnix and statix); buildflow test-race was not run by the dashboard sessions
3. ~~**TODO bookkeeping.** Two rows ticked (uncommitted). Not done: the "Owner visual check: ai-meter.home.lan …" row still asks for a LAN check that this session did (and its queue and library titles already differed before this session); no `[watch]` row for the SigNoz-upgrade re-derivation yet; the 17-59 report's 15 follow-ups are not annotated.~~ done at `7c28a543a`
4. ~~**caddy and gcp.** Fixed in the tree; live they still carry the old stored form until the deploy (then one PUT, then skip).~~ done — caddy and gcp were PUT once and skipped from then on (2026-11-26 06:17 and 06:48)

## c) NOT STARTED

1. ~~Deploy, and with it the provisioner's "Unchanged: … skipping" for ai-meter, caddy and gcp on the run after the first.~~ done — deployed on 2026-11-26: Updating in place at 06:17, Unchanged and skipping at 06:48
2. ~~The three span-export alert rules' PromQL ("AI Trace Export Failing", "AI Trace Export Silent", "AI Traces Not Landing In SigNoz") against `/api/v5/query_range`.~~ done — (23-28 report)
3. ~~`nix flake check --no-build` on the real tree.~~ done — the all-systems flake check is green on 2026-11-28 at 02:32
4. `buildflow -s test-race`.
5. ~~`nix fmt -- --fail-on-change -- docs/services/ai-meter.md docs/agents/monitoring.md docs/DOMAIN_LANGUAGE.md CHANGELOG.md`.~~ done — nix fmt on the touched files on 2026-11-28 (three files reformatted, 6f2dd16c7)
6. ~~Standalone `deadnix` and `statix` on `lib/signoz-dashboard-lint.nix`.~~ done — deadnix and statix silent on the six Nix files on 2026-11-28
7. ~~TODO: narrow the visual-check row to the off-LAN path on both surfaces, add the `[watch]` row, annotate the 17-59 report.~~ done at `7c28a543a`
8. ~~Scratch cleanup: `~/.cache/aimeter/r2/sandbox` (133 MB), `~/.cache/aimeter/r2/helium-profile` (252 MB), `/tmp/*.nix` and `/tmp/patch-*.py`.~~ done — sandbox (134 MB) and helium-profile (264 MB) went to the trash on 2026-11-28 after the last headless render; /tmp held no .nix or patch-*.py file
9. Optional, not started: the dashboard builder as Nix instead of a scratch Python script; a repo script for "verify live and render headless"; a pre-deploy round trip for dashboards; a 24-hour spend column per model (tables cannot run the priced queries); a traces link panel. **→ routed to docs/todo/monitoring.md "The dashboard builder: Nix data in the repo, a Go generator, or hand edits under the lint", "Dashboard round trip as a repo command: render, API round trip, every panel query on the live engine, a kept copy, the PUT" and "A 24-hour spend per model on the ai-meter dashboard"; the traces link exists since 0779937ac (the notes panel links to the AI views)**

## d) WHAT WENT WRONG

1. **The repo file carried the dry-run title twice.** `normalize.py` restored the display name from a copy that already had "AI Meter DRYRUN delete me". The auto-commit daemon captured that state as `fa1c23d1c` (2026-11-25 20:59:53); `27b7732d4` (21:05:02) corrected it. Nothing was deployed from it. Had a deploy or a provisioner run happened in those five minutes, the live dashboard would have been renamed.
2. **I read refused edits as done, twice.** An Edit result that only says "modified since it was last read" is a refusal, and one scripted patch did not write. Both times a later check caught it (a count of zero, a dry-run title in the output).
3. **The first live version (21:11 to 01:40, three and a half hours) had two real defects.** "Quota Exhausted" turned red only above 1, but the gauge is 0 or 1, so it never would. And SigNoz compacts every grid column upward: three sections had a row with free columns, so the tile below floated up and the page rendered misaligned. Both were found by re-reading and by the first settled headless capture, both fixed in v3.
4. **The first live version also trusted the builder with a sparse counter.** Its "Upstream Rejections" table read 19 where the truth was 28 (source: `increaseWithoutNegative` drops each series' first bucket and the first bucket after a reset). Replaced by PromQL panels.
5. **My hand-computed promtool expectations were wrong** (1016 and 1083 against 999 and 1065): this promtool does not extend an integer counter past its samples. The guard caught it on its first run.
6. **The validator took three drafts.** `lib.optionals` where `lib.optional` was meant, per-panel lists concatenated unflattened, accessors that crashed on a missing key, a function referenced outside its `let`, a list where `runCommand` needs an attrset, and a selftest fixture that passed a panel spec without its `{ kind = "Panel"; spec = … }` envelope. Every one was caught by a test, none reached the repo before the copy was green.
7. **One negative-test leg had a typo** (`scale ? 3600;` for `scale ? 3600,`). The harness's no-op detector caught it; the group was re-run.
8. **Seven throwaway dashboards were created and deleted on the live SigNoz** (dry runs and normalizations). Every run printed `remaining slugs containing ai-meter: ['systemnix-ai-meter']` afterwards. Prod mutations by this session: those, and two in-place updates of the real dashboard (21:11:27, 01:40:28). Backups of the previous documents: `~/.cache/aimeter/r2/live-backup-20261125-211127.json` (13 panels) and `live-backup-20261126-014028.json` (38 panels).
9. **Time.** First live result 54 minutes after the start (21:11). The complete version took until 01:40. The owner's request for this report arrived after a three-hour wait.
10. **`rm -f` was used once**, as a fallback on this session's own scratch debug copy inside the sandbox (`trash` was tried first). No repo file.

## e) WHAT WE SHOULD IMPROVE

1. **The dashboard builder lives in scratch** (`~/.cache/aimeter/r2/build.py`), the repo holds only the 3,450-line JSON. A future edit is hand editing with no row check. The builder could be Nix (the repo carries no Python): panels as data, the "every row spans 12" check at eval, the template generated.
2. **Dashboards have no pre-deploy round trip.** The API validates a whole document in one call; a check that creates, reads back and deletes a copy would catch at build time what the provisioner hits at deploy time. It mutates prod, so it belongs in a gated script, not in `nix flake check`.
3. **"Not verifiable from here: the UI" was false.** The headless render took 20 seconds to set up and found two defects that no API check could. It should be the first step of any dashboard change, and the recipe is now in `docs/agents/monitoring.md`.
4. **The builder's `increase` semantics should be known before a table is designed**, not after. They are documented now; a lint cannot see counter density.
5. **Server-normalized files are per SigNoz version.** After an upgrade every file is re-PUT once until re-normalized. A post-deploy line "provisioner printed Unchanged for all dashboards on a re-run" would make that visible.
6. **Edit results need a hard check**: "Content replaced" or the marker in the file. Two slips this session came from skipping it.
7. **The in-place PUT is the right first ship step for a dashboard** (reversible, seconds), but it leaves the running generation behind. The report that ships one should say so in its first line.
8. **Load of the one-minute refresh is estimated, not measured over time**: about 50 ClickHouse queries per minute while the page is open, 0.02 to 0.6 s each.

## f) NEXT (ordered)

**In flight in this session, deliberately not harvested into the queue** (`TODO_LIST.md` and the domain libraries): items 1 to 9 are this session's own remaining steps on files it already changed. A `[ready]` row would hand the same files to a parallel session. They become rows only if the owner wants them done elsewhere.

1. ~~Owner decision (§g): deploy. Then read `journalctl -u signoz-provision` for "Updating in place" x3 and, on the following run, "Unchanged: systemnix-ai-meter — skipping" (also caddy, gcp).~~ done — deployed on 2026-11-26: Updating in place at 06:17, Unchanged and skipping at 06:48
2. ~~`nix flake check --no-build 2>&1 | tee ~/.cache/aimeter/r2/gates/fc.log` on the real tree.~~ done — the all-systems flake check is green on 2026-11-28 at 02:32
3. ~~`nix fmt -- --fail-on-change -- docs/services/ai-meter.md docs/agents/monitoring.md docs/DOMAIN_LANGUAGE.md CHANGELOG.md TODO_LIST.md docs/todo/ai-stack.md docs/todo/pipeline.md`, then look at `git status` for unintended files.~~ done — nix fmt on the touched files on 2026-11-28 (6f2dd16c7)
4. `buildflow -s test-race` at a quiet moment.
5. ~~Standalone `deadnix` and `statix` on `lib/signoz-dashboard-lint.nix` and the changed parts of `flake/parts/checks/lint-static.nix`.~~ done — deadnix and statix silent on the six Nix files on 2026-11-28
6. ~~Run the three span-export rules' PromQL against `/api/v5/query_range` and record the values.~~ done — (23-28 report)
7. ~~TODO rows: retitle "Owner visual check: ai-meter.home.lan embedded dashboard renders (LAN + off-LAN forward-auth path)" to the off-LAN half on both surfaces (LAN verified 2026-11-26 01:59), add a `[watch]` row "after a SigNoz upgrade: re-derive `lib/signoz-unit-ids.txt` and re-normalize the dashboard files" to `docs/todo/monitoring.md`, annotate the 15 follow-ups of the 17-59 report.~~ done at `7c28a543a`
8. ~~Tick "SigNoz provisioning idempotency" only after item 1 shows the skip.~~ done at `7c28a543a`
9. ~~Clean the scratch (§c item 8).~~ done — on 2026-11-28 (section c, item 8)
10. ~~Second headless render after the deploy: dashboard page and viewer page.~~ done — headless renders followed the deploys of 2026-11-26, 2026-11-27 and 2026-11-28 (dashboard page and viewer page)
11. ~~For the admission session (their T04.5): the dashboard reads 3,148 calls lost to admission in 24 h, about 43 % of gated outcomes are timeouts, average wait 19 to 22 s, allowance 6 of 8, 4 quota answers (01:41 to 01:59). Their call, not mine.~~ **NOT-DO — the number was wrong (23-28 report, section d, item 1): the calls were sent back and sent again, nobody lost them.**
12. ~~Decide the refresh interval (§g).~~ **NOT-DO — moot: refreshInterval is stored and not applied by the UI (measured on 2026-11-26).**
13. Decide the commit policy (§g).
14. Builder as Nix (§e item 1). **→ routed to docs/todo/monitoring.md "The dashboard builder: Nix data in the repo, a Go generator, or hand edits under the lint"**
15. Repo script for "verify every panel live and render the page headless" (§e item 3). **→ routed to docs/todo/monitoring.md "Dashboard round trip as a repo command: render, API round trip, every panel query on the live engine, a kept copy, the PUT"**
16. Pre-deploy dashboard round trip (§e item 2). **→ routed to the same row, "Dashboard round trip as a repo command", in docs/todo/monitoring.md**
17. ~~Post-deploy "provisioner skipped everything on re-run" line (§e item 5).~~ done at `497bad814`
18. 24-hour spend per model as a table column (needs a route other than the builder; a time series of the rolling 24 h per model is possible today with a fifth placeholder). **→ routed to docs/todo/monitoring.md "A 24-hour spend per model on the ai-meter dashboard"**
19. ~~A traces link panel or a note in the viewer header to SigNoz's AI views.~~ done at `0779937ac`
20. `llama-embeddings` answers 502 for every `bge-m3` call of paperless (12,473 calls in 24 h, 0 % success on the table). Known and owner-gated ("Local-LLM decision row", 2026-11-24 21-07 report). The dashboard now shows it as a 100 % error rate. **→ answered by events: llama-embeddings serves again since the 2026-11-27 10:27 deploy (1,592 of 1,622 calls answered 200 in 15.2 hours); the keep-or-retire question → routed to docs/todo/ai-stack.md "llama-embeddings: keep, repair or retire the bge-m3 route"**
21. The `synthetic` upstream has no price row, so `syn:large:text` meters at $0 by doctrine. Owner decision if a reference price is wanted. **→ routed to docs/todo/ai-stack.md "syn:large:text: a reference price or none"**
22. ~~SigNoz answers `501` on `/api/v4/licenses/active` once per page load (cloud license check in the OSS build). Cosmetic; nothing to do.~~ **Won't implement — cosmetic, nothing to do (the cloud license check of the OSS build).**
23. ~~The queue row "ai-meter follow-ups: gemini-via-proxy verification, hermes wiring, SigNoz dashboard" has no library twin, and its dashboard part is done. Fix both in one edit.~~ done (docs-health pass 2026-11-28)
24. ~~The evaluation warning "integration subdomain(s) without catalog entries: ai-meter" (seen while building the VM check) belongs to the DNS catalog migration of another session. Tell that session.~~ done — answered by events: on 2026-11-28 the evaluation warning names paperless, ai-meter has its catalog entry
25. ~~Add "a settled headless capture before the first PUT" to the dashboard section of the runbook (one sentence).~~ done — the runbook carries it ("Changing the dashboard", step 3)
26. ~~`docs/agents/shell-devtools.md`: note that the Edit tool's "modified since last read" result is a refusal (a session trap worth a line).~~ done (docs-health pass 2026-11-28)
27. Re-run the full negative suite once in CI (the nightly workflow runs all groups; confirm `signozdash` appears in its log). **→ routed to docs/todo/pipeline.md "Negative-test harness: INFRA class, abort on a failed pristine fetch, live doc-count mutations, --check-mutations": the nightly workflow is red on authentication, so no log names any group**
28. ~~After the deploy: confirm the "ai-meter dashboard" and "ai-meter viewer" gatus checks stay green.~~ done — both gatus conditions read by hand on 2026-11-28 at 02:08 (the page answers 200 with the pinned id and relativeTime=3h, the dashboard API answers the slug); the verdict of gatus itself is behind authentication
29. Look at the dashboard once on the owner's screen (font sizes, the 1-minute refresh feel, the Admission section wording).
30. ~~If the owner wants the dashboard in PapDashboard with a direct tile: it exists as the viewer tile already; nothing to do unless the owner wants the SigNoz page itself linked.~~ **NOT-DO — nothing to do, the viewer tile exists; NOT-DO unless the owner wants the SigNoz page linked.**

## g) QUESTIONS

1. ~~**Deploy.** The tree carries the new dashboard file, caddy, gcp and the validator; the live dashboard exists only as a hand-made update, and a `signoz` restart or reboot before the next deploy puts the old 13-panel dashboard back. May I deploy HEAD myself (`scripts/deploy-when-quiescent.sh --fire`), or is another session's deploy carrying it? The tree also holds other sessions' in-flight edits, and the host was under IO pressure all night (PSI some 48 to 56 % at 05:39).~~ done — answered by events: the deploys of 2026-11-26 and 2026-11-27 carried it
2. **Commits.** May I commit this session's own files with descriptive messages? Today everything rides heuristic daemon commits, including `fa1c23d1c` with the dry-run title.
3. ~~**Refresh.** Keep the one-minute refresh (about 50 ClickHouse queries per minute while the dashboard is open; every other dashboard uses five minutes), or go to five minutes?~~ **NOT-DO — moot: refreshInterval is stored and not applied (measured on 2026-11-26).**

---

## Appendix A: panels (50)

| Section | Panels |
| --- | --- |
| In flight (top) | In Flight; In Flight: Provider x Model x Client (table); In Flight by Provider; In Flight by Model; In Flight by Client |
| Traffic | Requests / min; Success Rate (5m); Non-2xx / min; Calls (24h); Reachable; Process Uptime; Requests by Provider; Requests by Client; Requests by Model x Code; Failures by Code; Error Rate by Provider |
| Tokens & spend | Tokens / min; Cache Hit Rate; Prompt / Call; Spend Rate; Spend (24h); Spend (all-time); Spend Rate by Model; Spend Rate by Client; Tokens by Kind; Tokens by Client; Models: Last 24 Hours (table) |
| Latency | Avg TTFT; Avg Duration; Avg Output Speed; Avg TTFT by Model; Avg Duration by Model; Output Speed by Model |
| Health | Starts (24h); Metering Errors (24h); Unauthorized (24h); Span Export Failures (24h); Traced Calls (24h); Metrics Freshness; Span Export by Outcome |
| Admission (z.ai rate limit) | Quota Exhausted; Limit (now); Waiting (now); Rate-Limit Answers (24h); Quota Answers (24h); Calls Lost (24h); Admission: In Flight, Waiting, Limit; Admission Outcomes (24h) (pie); Avg Admission Wait; Provider 429 Answers / min |

## Appendix B: what the live page showed (01:41 to 01:59)

In Flight 17 to 18 (`zai/glm-5.4/crush 15`, `llama-embeddings/bge-m3/paperless 2`, `zai/glm-5.3-flash/crush 1`); Requests 26 to 32 req/m; Success Rate 83 to 85 % (red); Non-2xx 4 to 5 req/m (orange); Calls (24h) 31 K; uptime 6.1 to 6.4 h; Tokens 16.6M tokens/min; Cache Hit Rate 97.8 %; Prompt / Call 289.7K tokens; Spend Rate 1.106 USD/h; Spend (24h) $35.6; Spend (all-time) $13.83K; Avg TTFT 20.29 s (red); Avg Duration 34.88 s; Avg Output Speed 55.4 tokens/s; Starts 6; Metering Errors 11 (red); Traced Calls 39.2 % (orange); Metrics Freshness 21 s; Quota Exhausted False; Limit 6; Waiting 9; Rate-Limit Answers 43; Quota Answers 4 (red); Calls Lost 3,148 (red); Avg Admission Wait about 19 s.

## Appendix C: builder `increase` versus the truth (2026-11-26 00:40)

| Counter (24 h) | Reset-aware raw sum | PromQL `increase` | Builder |
| --- | --- | --- | --- |
| upstream rejections | 28.0 | 29.1 | 19.0 (68 %) |
| admission outcomes | 6115 | 6119 | 5955 (97 %) |
| requests | 34662 | 34641 | 34432 (99 %) |
| metering errors | 12 | 12 | 12 |

## Appendix D: commands that worked here

```bash
cd ~/.cache/aimeter/r2
python3 build.py ./v3-raw.json                                   # 50 panels, refuses a row that is not 12 columns wide
REPO_ROOT=/home/lars/projects/SystemNix ./render.sh "$PWD/v3-normalized.json" "$PWD/v3-target.json"
python3 verify.py v3-target.json                                 # every panel query against /api/v5/query_range
python3 dryrun.py v3-target.json                                 # create, read back, compare, delete
python3 put.py v3-target.json                                    # backup, PUT to the pinned id, read back
node shot.mjs "https://signoz.home.lan/dashboard/<id>" out --width 1500 --height 6600 --settle-ms 8000
magick out.png -crop 1500x1200+0+1200 +repage -quality 86 slice.jpg
python3 xcheck-spend.py                                          # independent re-computation of the priced figures
cd /home/lars/projects/SystemNix && CASES=signozdash,signoz bash scripts/negative-test-lints.sh
```
