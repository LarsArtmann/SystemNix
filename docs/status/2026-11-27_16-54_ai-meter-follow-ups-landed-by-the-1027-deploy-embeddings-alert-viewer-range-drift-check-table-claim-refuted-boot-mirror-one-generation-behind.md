# Status 2026-11-27 16:54: the ai-meter follow-ups landed with the 10:27 deploy; the boot mirror is one generation behind; the "inaccurate failed column" was a mis-measurement

**Written:** 2026-11-27 16:54 CET (`date`), boot `0737ecd7`, HEAD `3a66b194e` (tree clean: the auto-commit daemon committed everything of this stretch), running generation 1033 (`zp0384i8b7bm…`) since 10:27.
**Previous report of this work:** [2026-11-26 23-28](./2026-11-26_23-28_ai-meter-dashboard-v4-live-delay-vs-failure-alert-repaired-in-tree-tile-title-lint-native-ai-views-opened.md). **One of its claims is refuted here (§d 1): the `failed` column of the models table is not inaccurate. The number it rested on came from a comparison whose time windows I cannot show were aligned.**
**Session window with tool activity:** 2026-11-27 00:59 to about 10:07 CET, then this report at 16:54. Between 10:07 and 16:54 this session ran nothing.

## Scope line

**Verified here (command and artifact, run 2026-11-27 00:59 to 16:58 CET):** every claim in §a names its command or file. Logs are under `~/.cache/aimeter/r2/gates/`, captures and scripts under `~/.cache/aimeter/r2/`. The report describes `3a66b194e`.

**NOT verified here:**

- **The seven negative legs written this session were not run** (five for the embeddings rule in group `aimeter`, two for the drift check in group `signozdash`). `scripts/negative-test-lints.sh` was only syntax-checked (`bash -n`).
- **No formatter, no shellcheck, no deadnix/statix and no `nix flake check --no-build --all-systems` on the final tree.** The five checks below were built green at about 10:05 (`gates/v5-checks-1.log`, rc=0); nothing after that was built by me.
- **The post-deploy line "SigNoz dashboards" has never run on the live host.** Generation 1033 was installed by a raw `nh os switch` (sudo journal 10:25:49, no `deploy.sh` log), so no post-deploy battery ran after it. It is proven only by its fixtures.
- **The gatus check "ai-meter viewer" with its new pattern.** The gatus API answers 401. I fetched the page body by hand instead: iframe and link carry `?relativeTime=3h`.
- **The live dashboard page in a browser after the update.** The kept copy (the same document) was rendered before the update; after it only the API read-back was compared (spec equal, `updatedAt 2026-11-27T09:28:01Z`).
- **The off-LAN path, and what the owner sees in the owner's own browser.**
- **Why the boot mirror sync's copy stopped** (§d 2). I read the unit's journal and its diff output, not the script.
- **The `doc-counts` failure that blocks today's deploys** (§d 3): read from the 16:45 deploy log, not reproduced by me.
- CI: nothing observed.

## TL;DR

1. **A reboot now would boot yesterday's generation.** The boot loader runs from the Samsung ESP (it is the mirror), and the mirror still prefers generation 1032's entry: the sync at 10:28:28 copied the new entry only as a leftover `.tmp` and then failed its own diff gate (exit 1, 10:29:06). The running generation 1033 has no boot entry on the disk the firmware boots from. One command repairs it; I did not run it because the instruction was report, then wait (§g 1).
2. **A deploy at 10:27 (not mine) carried everything the last report left "in tree":** v4's follow-ups, the repaired failure-rate rule, the new quota rule, the new embeddings rule, the 270 s wait budget and the viewer range. Verified live at 16:55: provisioner lines, three rule states, `max_wait 4m30s`, dashboard equal to the file.
3. **The "inaccurate `failed` column" was my mis-measurement.** With aligned windows the builder table reads failed 592 against a ledger count of 614 over 24 hours with five proxy starts inside (−3.6 %), and 38 against 37 over three hours with two starts. The column stays; its description now states the real precision.
4. **New, in tree and live since 10:28:** a warning rule that pages when llama-embeddings fails its calls (387 of 424 failed in the ledger day; every other layer was quiet), and a post-deploy line that compares every live dashboard with its file.
5. **Still open from the last report and not touched:** the TODO rows, the report annotations, the documentation of this stretch, the scratch cleanup.

## a) FULLY DONE

| # | What | Evidence |
| --- | --- | --- |
| 1 | **The models table measured against the ledger on aligned windows** | `python3 ~/.cache/aimeter/r2/xcheck-table.py v4-target.json --hours=24 --end=1795683600 --steps=300 --promql` and the same for three hours; log `gates/table-xcheck-aligned.log`. Window 09:00 to 09:00 UTC (five proxy starts inside), glm-5.4: calls 15,948 against 16,123 (−1.1 %), not admitted 6,153 against 6,262 (−1.7 %), failed 592 against 614 (−3.6 %), success 94 against 93.8 %. Window 18:00 to 21:00 UTC on 11-25 (two starts inside), step 60: calls −0.2 %, failed 38 against 37. PromQL on the same windows: failed −0.9 % and −6.5 % |
| 2 | **Why the builder reads low, read from its source and measured** | `pkg/query-service/app/metrics/v4/cumulative/timeseries.go` at rev `da35d997` (fetched): per series and step bucket the maximum sample, minus the previous bucket; a negative difference (a counter reset) and each series' first row become NaN. Measured step floor by range (query API, `meta.stepIntervals`): 60 s up to 6 h, 120 s at 12 h, 300 s at 24 h, 600 s at 48 h, 900 s at 72 h, 1800 s at 7 d; a smaller authored step is raised to it |
| 3 | **Tables refuse PromQL at the dashboard validator** | `POST /api/v2/dashboards` with a PromQL table answers 400 `sub-query type "promql" is not supported by panel kind "signoz/TablePanel"`. The query API itself takes PromQL for a table request and joins several queries on the group-by labels. No throwaway dashboard was left behind (list read back at 10:02 and 16:55: the ten known) |
| 4 | **Red-tile census over 48, 24 and 6 hours** | `python3 ~/.cache/aimeter/r2/red-census.py v4-target.json --hours=N`, logs `gates/red-census-{48,24,6}h.log`; live page colors read from the DOM (`v4live-red.json`). Last 24 h: Success Rate red 48.3 % of the points, Quota Exhausted red 44.6 %, Not Admitted (5m) red 49.0 %, Avg TTFT red 27.1 % and orange 32.6 %; Failures / min, Not Metered, Export Failures, Reachable and Metrics Freshness never red |
| 5 | **The red Success Rate is one provider** | Ledger, 24 h to 01:20 UTC, 242 five-minute points with decided calls: red in 48.3 % of them with every provider, in 2.1 % without llama-embeddings. llama-embeddings failed 387 of 424 calls, z.ai 103 of 11,662 |
| 6 | **Explorer link that filters to ai-meter** | Frontend source read (`useGetCompositeQueryParam.ts`, `normalizeCompositeQuery.ts`): `?compositeQuery=` with the builder's JSON, missing blocks filled in. Rendered headlessly: the explorer opens with the filter `serviceName = 'ai-meter'` and lists ai-meter traces (`exp-filtered.json`, `v5explorer.json`) |
| 7 | **Dashboard rebuilt and installed** | Three lines changed in `modules/nixos/services/dashboards/ai-meter.json` (commit `8d843a001`, 10:05): the table and pie descriptions state the precision, the notes panel links the filtered explorer. Every query ran against the live engine (`verify.py`: `ALL OK 0`); round trip identical three times; a kept copy rendered first (`v5kept-tail.jpg`: four paragraphs complete, both links). Five checks green: `signoz-query-lint`, `signoz-dashboard-lint-selftest`, `ai-meter-spend-promql`, `ai-meter-alert-promql`, `post-deploy-signoz-dashboards-selftest` (`gates/v5-checks-1.log`) |
| 8 | **Viewer page opens on one fixed range** | `modules/nixos/services/ai-meter.nix` (commit `8aa26dbc3`): `dashboardRange` is read from the dashboard file's `duration`, so the file stays the one source; the iframe, the "open in SigNoz" link and the gatus body pattern carry it. Eval of the page and the check: `gates/viewer-eval.json`. Live at 16:55: both URLs carry `?relativeTime=3h` |
| 9 | **Warning rule "AI Embeddings Calls Failing (ai-meter)"** | `modules/nixos/services/_signoz-alerts.nix` (commit `de738beae`): 100 × failed calls over 30 minutes ÷ calls clamped at four, at 49.5 % (two failed calls at least, and at least half of them; `or (calls * 0)` so a proxy without a failure reads 0). Replayed on the live engine over 48 h (`gates/embed-rule-probe.log`): fires at 97.5 % of 558 points, longest streak 1,570 minutes. promtool guard with eight fixtures in `checks.ai-meter-alert-promql`, build rc=0 (`gates/embed-alert-check-2.log`) |
| 10 | **Post-deploy line "SigNoz dashboards"** | `scripts/lib/signoz-dashboards-drift.sh` (commit `497bad814`), sourced and called by `scripts/post-deploy-check.sh` (commit `c6f9a4320`) after the provisioner's Result check. It compares every file in `/etc/signoz/dashboards` with the live document, as the provisioner does before it skips one. Selftest `scripts/test-post-deploy-signoz-dashboards.sh`: 9 passed 0 failed, locally and as `checks.post-deploy-signoz-dashboards-selftest` |
| 11 | **The 10:27 deploy verified, item by item** (the five points of the last report's §f 1) | Provisioner 10:28:00 to 10:28:03 (journal): "Creating policy: AI Quota Window Spent (ai-meter)" and "Creating policy: AI Embeddings Calls Failing (ai-meter)", both HTTP 201; "Updating in place: systemnix-ai-meter … OK dashboard updated (HTTP 200)"; "Unchanged: systemnix-gcp — skipping", "Unchanged: systemnix-telemetry-coverage — skipping", "OK 10 dashboards provisioned, exact desired set". Rules at 16:55: "AI Upstream Failure Rate High (>30%)" `inactive`, same id `01a148a8-7c44-7eb0-8036-ea2d6e02d2e8`; quota rule `firing` since 13:06:32 UTC; embeddings rule `inactive` (0 calls to llama-embeddings in the last 30 minutes). Proxy 10:27:52: `"max_wait":"4m30s"`. `python3 ~/.cache/aimeter/r2/put.py v4-target.json --check-only`: "live spec already equals the sent spec" |

## b) PARTIALLY DONE

1. **The embeddings rule and the drift check are live without their negative legs run.** Seven `run_case` lines are written in `scripts/negative-test-lints.sh` (commit `8d843a001`); `CASES=aimeter,signozdash bash scripts/negative-test-lints.sh` has not been run since. Effort: S (one run, 30 to 60 minutes on this box).
2. **Nothing of this stretch is documented.** The runbook (`docs/services/ai-meter.md`: table precision, viewer range, explorer link, the embeddings rule, the post-deploy line), `docs/agents/monitoring.md` (builder precision and the step floor; the validator, not the query API, refuses PromQL on tables), `CHANGELOG.md` and `docs/agents/shell-devtools.md` still describe the state of the 23-28 report. Effort: S to M.
3. **The TODO bookkeeping of the 23-28 report is still not written** (its §h: three library rows, one tick on two surfaces, one retitle on two surfaces), and this report adds its own. Effort: S.
4. **The 17-59 and 05-39 reports are still not annotated**, and the 06-25 report still points at stale next steps. Effort: S.
5. **The next provisioner run must skip ai-meter.** It updated the dashboard at 10:28:01 because the file had changed; the skip for this file has not been observed yet (gcp and telemetry-coverage were skipped). It shows at the next deploy.
6. **The llama-embeddings outage is unresolved.** The rule for it exists; the server does not answer. Since about 16:25 there are no calls at all (0 in the trailing 30 minutes at 16:55), so the rule is silent for lack of traffic, not because the server recovered.

## c) NOT STARTED

From the 23-28 report's list, in its numbering:

- 6: the 06-25 report's stale "exact next steps".
- 10: read "Not Admitted (5m)", "Avg Admission Wait" and "Avg TTFT" again now that the 270 s budget is live (since 10:27), and decide the gate's limit.
- 11, 12, 13, 15: repo tooling for the dashboard pipeline, an alert replay, a red-tile census, a pre-deploy dashboard round trip. The census and the replay exist as scratch scripts and were run by hand this session (`red-census.py`, `embed-rule-probe.py`, `xcheck-table.py`); the post-deploy drift line is the read-only half of 15.
- 14: the decision "builder as Nix, or hand edits under the lint" is not written down.
- 17: a 24-hour spend per model.
- 18: the tile-title limit at a second width (1280 px).
- 20: whether the nightly negative-test workflow log names `signozdash` and `aimeter`.
- 24: the seven glm-5.4 streaming calls that returned 200 without a usage block.
- 25: one line in `docs/agents/shell-devtools.md` about the Edit tool's "modified since it was last read".
- Scratch cleanup: `~/.cache/aimeter/r2/sandbox` and `helium-profile` are still on disk (`helium-profile` is in use by every headless render).
- Owner decisions carried over unchanged: sustained gate saturation paging (7), llama-embeddings repair or retire (8), a price for `syn:large:text` (23).

## d) TOTALLY FUCKED UP

1. **The last report's "inaccurate `failed` column" was wrong (mine).** I compared a table reading with a ledger count without aligning the two time windows, got 363 against 226, wrote "builder formulas that subtract large numbers are inaccurate", and queued the column for removal. Aligned windows give −3.6 %. The wrong claim sits in the 23-28 report (§d 3, §f 2, its scope line) and in the summary I resumed from. Not yet corrected there.
2. **The boot mirror is one generation behind (not mine; live).** Facts read at 16:57: `/boot/loader/loader.conf` prefers `nixos-dca0a736…` (generation 1033, entry file `+3.conf` written 10:28); `/boot-mirror/loader/loader.conf` prefers `nixos-f594b564…` (generation 1032), the mirror has no entry for 1033 and a leftover `nixos-dca0a736…+3.conftugyc86n.tmp`; `boot-mirror-sync.service` ran 10:28:28 to 10:29:06 and failed its own diff gate ("mirror diverges from /boot — refusing to call the 2nd boot disk current", exit 1, `OnFailure` triggered). `LoaderDevicePartUUID` reads `023f66c0-3677-4c15-9ce7-f9e1f1457edb`, the Samsung ESP: the loader boots from the mirror. A reset now boots generation 1032: the 270 s budget, both new rules, the repaired failure-rate rule and the siblings' work of today are gone until someone switches again. The generation was installed outside `deploy.sh`, which is the case the runbook names: restart `boot-mirror-sync` by hand. The restart seems to have happened (the sync ran four minutes after the switch) and to have failed.
3. **Every deploy since 11:58 is blocked (not mine).** `/var/log/systemnix-deploys/2026-11-27_16-45-21.log`: "155 passed, 4 warnings, 1 failed"; the one is `nix flake check --no-build`: `doc-counts: FEATURES packages asserts 55, eval truth is 54`. The same log shows IO PSI some 35.6 % with the disk 99 % busy and 15 guard trips in the hour; the 16:49 attempt hit another session's lock (exit 13).
4. **llama-embeddings failed a day of calls with no page (not mine, now covered).** The unit is `active`, the port listens, the model loaded at 06:58 on 11-26; every call hung (ledger: `duration_ms` 327,932 to 480,101) until the client left and ai-meter answered 502. "llama.cpp Embeddings Down" watches the unit; the repaired failure-rate rule keeps a provider this quiet below its floor on purpose; the old HTTP-level rule paged for the wrong reason.
5. **My first aligned experiment was wrong too (mine).** I shifted the builder's window back by one bucket to "give it a baseline", which added five minutes of real traffic and produced a +56 % phantom for bge-m3. Caught by dumping the per-step series; about 40 minutes lost.
6. **The first versions of the drift library and its selftest were broken (mine).** The fixture reader built `live/id-1.json` where the file was `liveid-1.json`, the list fixture was not JSON, and the library read a silent API as "zero dashboards" and FAILED instead of skipping. The selftest's own run found all three; they were fixed before 10:00. The daemon committed two intermediate states (`c6f9a4320` at 09:56 carries the earlier test).
7. **I misread the clock for most of the session (mine).** I assumed it was about 02:00 while it was 09:40: the journal windows I read were eight hours old. Caught when a timestamp looked future-dated. No decision rested on it: the embeddings finding came from ledger lines of the night and was then confirmed over 48 hours by replay.
8. **One parse check ran in a background batch (mine).** After the `or (calls * 0)` edit to `_signoz-alerts.nix` the parse result arrived minutes later. A parse error there breaks every eval for every session; I re-ran it at once (rc=0), but for that moment the fuse was open. The rule says the parse step is synchronous and restores the file.

## e) WHAT WE SHOULD IMPROVE

1. **Align before comparing.** A "dashboard versus ledger" number is worth nothing unless both windows start and end on the engine's bucket boundaries and the ledger is cut by end time. Rule to add to `docs/agents/monitoring.md`, with `xcheck-table.py` as the recipe.
2. **Keep the builder's limits where they are measured.** Tables and pies read a busy model within one to four percent; a model with a few calls an hour reads several percent low, and a sparse token column can read 18 % low in a window with proxy starts (bge-m3 prompt tokens: 18,024 against 22,070). PromQL is two to five times closer. Where a small number matters, it must not come from a builder remainder.
3. **Page on calls, not on unit state, for anything behind ai-meter.** The proxy counts every routed call by upstream and status; that is the signal that saw the embeddings outage. The same shape fits llama-chat and fastflowlm when they carry traffic.
4. **Replay an alert over history before and after changing it.** Done by hand twice now (`alert_rules.py`, `embed-rule-probe.py`); it is what turned both rule changes into facts. Make it a repo command (Go, or shell against the v5 query API: `scripts/` carries no Python).
5. **The proxy could count outcomes itself.** `ai_meter_request_outcomes_total{upstream, model, outcome="served|not_admitted|failed"}` would remove every remainder subtraction from the dashboards and the rules, and window counters rebuilt from the ledger at start would make the 24-hour table exact. A change in the ai-meter repository; worth a decision row.
6. **A ratio tile mixes providers.** Success Rate was red half the day for a provider with 424 calls while z.ai served 99.1 %. The per-provider chart exists; the tile could say which provider drags it.
7. **Avg TTFT is colored by the queue.** Red 27 % and orange 33 % of the last 24 hours, the same contention the Not Admitted tiles show; with the 270 s budget the queue's share grows. Either it names the provider's own first-token time (needs a proxy metric) or its colors follow the user-felt wait deliberately.
8. **Raw switches skip the battery.** Two generations in two days were installed with `nh os switch` outside `deploy.sh`: no post-deploy lines ran after them, and today's left the boot mirror behind. The anchor discipline has two legs; a raw switch guards neither.
9. **SigNoz's AI explorer shows cost 0 for ai-meter traces** (`estimated_total_cost 0` in the explorer while the overview shows a cost by service): its model pricing is not configured. Noticed while testing the link, not researched.

## f) NEXT (ordered, up to 50)

**Not harvested at authoring time:** the owner asked for this report and a wait. The rows of the 23-28 report §h and of this list are written into `TODO_LIST.md` and the domain libraries when work resumes, under the intake rules (close as many as are minted, at most three new queue rows a session).

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | **Boot mirror:** restart `boot-mirror-sync`, then read the mirror's `loader.conf` and entries, run `nix run .#pre-reboot-check`, and find out why the 10:28 copy stopped (§g 1) | Critical | S | Bug |
| 2 | **Unblock deploys:** `doc-counts: FEATURES packages asserts 55, eval truth is 54` (§g 3) | Critical | S | Bug |
| 3 | **Run the negative legs:** `CASES=aimeter,signozdash bash scripts/negative-test-lints.sh` (seven new legs, 36 older ones) | High | S | Quality |
| 4 | **Gates on the final tree:** `nix fmt -- <touched files>`, shellcheck on the two new scripts, deadnix, statix, `nix flake check --no-build --all-systems` | High | S | Quality |
| 5 | **Docs of this stretch:** runbook (table precision, viewer range, explorer link, embeddings rule, post-deploy line), `monitoring.md` (builder precision, step floor, validator wording, align-before-compare), CHANGELOG, `shell-devtools.md` | High | S | Documentation |
| 6 | **Correct the 23-28 report** where it calls the `failed` column inaccurate, by annotation | High | S | Documentation |
| 7 | **TODO rows of the 23-28 report §h** (three library rows, the idempotency tick on both surfaces, the visual-check retitle on both surfaces) | Medium | S | Documentation |
| 8 | **TODO rows of this report** (the SigNoz-upgrade watch row gains the explorer link; the proxy outcome-counter proposal in `docs/todo/ai-stack.md`) | Medium | S | Documentation |
| 9 | **Annotate the 17-59 and 05-39 reports** with the docs-health writer; point the 06-25 report at the 17-59 report | Medium | S | Documentation |
| 10 | **llama-embeddings: repair or retire** (§g 2); if repaired, find why a call hangs for minutes with the model loaded | High | M | Decision |
| 11 | **Read the dashboard after the 270 s budget:** Not Admitted (5m), Avg Admission Wait, Avg TTFT since 10:27; then the gate's limit | High | S | Feature |
| 12 | **Observe the provisioner skip `systemnix-ai-meter`** on the next deploy, and read the new post-deploy line there | Medium | S | Verification |
| 13 | **Gatus "ai-meter viewer" with the new body pattern:** confirm the check is green | Medium | S | Verification |
| 14 | **Decision: the dashboard builder.** Nix data in the repo, a Go generator, or hand edits under the lint; write it down with the zero-Python rule in mind | Medium | M | Quality |
| 15 | **Repo command for the dashboard pipeline** (build, render, round trip, verify every query, keep a copy, render, delete, PUT), in Go or shell | Medium | M | Quality |
| 16 | **Repo command to replay an alert expression over history** (what `alert_rules.py` and `embed-rule-probe.py` do by hand) | Medium | S | Quality |
| 17 | **Repo command for the red-tile census**, and a weekly run against alarm fatigue | Medium | S | Quality |
| 18 | **Pre-deploy: every dashboard query answers HTTP 200 on the live engine** (read-only half of a dashboard round trip) | Medium | S | Quality |
| 19 | **Proxy: a counter by outcome** (`served`, `not admitted`, `failed`), proposed in the ai-meter repository | High | M | Feature |
| 20 | **Proxy: window counters rebuilt from the ledger at start**, so the 24-hour table stops depending on the builder's buckets | Medium | M | Feature |
| 21 | **Success Rate tile names the provider** that fails, or is split per provider | Medium | S | Feature |
| 22 | **Avg TTFT: provider time and queue time apart**, or colors chosen for the user-felt wait | Medium | M | Feature |
| 23 | **SigNoz model pricing for ai-meter's models**, from `services.ai-meter.costs`, so the explorer's cost column stops reading 0 | Low | M | Feature |
| 24 | **Tile-title limit at 1280 px:** measure with `title-probe.py`, then keep or tighten the lint's 22 | Low | S | Quality |
| 25 | **Nightly negative-test workflow:** confirm its log names `signozdash` and `aimeter` | Low | S | Quality |
| 26 | **Seven glm-5.4 streaming 200s without a usage block** (0.03 % of a day): find the response shape | Low | M | Bug |
| 27 | **A lint for the notes panel's links:** each relative link answers 200 | Low | S | Quality |
| 28 | **Scratch cleanup:** `sandbox`, then `helium-profile` after the last render; keep the scripts and logs named in §a | Low | S | Cleanup |
| 29 | **Sustained gate saturation: page or not** (carried, unanswered) | Medium | S | Decision |
| 30 | **`syn:large:text`: a reference price or none** (carried, unanswered) | Low | S | Decision |
| 31 | **A 24-hour spend per model** (carried) | Low | M | Feature |
| 32 | **Red census again in a week**, with the embeddings decision made | Low | S | Quality |

## g) QUESTIONS

1. **The boot mirror.** May I run `sudo systemctl restart boot-mirror-sync` now and verify the mirror (its `loader.conf`, the entry for generation 1033, `nix run .#pre-reboot-check`)? It is the step the runbook names after a generation install outside `deploy.sh`, and deploy.sh runs it after every switch. I did not run it because the instruction was report, then wait. Until it is done, a reset boots generation 1032.
2. **llama-embeddings.** It failed 387 of 424 calls in a day and nothing was paged; since about 16:25 nothing calls it. Repair it (the server is up with its model loaded and lets every call hang), or retire it and the bge-m3 route? If repair: may I investigate the hang, which probably means the GPU shared with llama-chat?
3. **The deploy block.** `FEATURES.md` asserts 55 packages and the tree has 54, which fails `nix flake check --no-build` and so every deploy. The count moved with the ai-meter extraction, not with my work. Do you want me to re-derive and re-stamp it, or is the session that moved ai-meter to its own repository owning it?

---

## Appendix A: the three measurements behind §d 1

| Window (UTC) | Proxy starts inside | Builder step | glm-5.4 calls | not admitted | failed | success |
| --- | --- | --- | --- | --- | --- | --- |
| 11-25 09:00 to 11-26 09:00 | 5 | 300 s | 15,948 (ledger 16,123) | 6,153 (6,262) | 592 (614) | 94 % (93.8 %) |
| the same, PromQL | | | −0.1 % | −0.0 % | 608.8 (−0.9 %) | 93.8 % |
| 11-25 18:00 to 21:00 | 2 | 60 s | 5,968 (5,977) | 2,529 (2,534) | 38 (37) | 99 % (98.9 %) |
| 11-26 00:10 to 11-27 00:10 | 0 | 300 s | −0.0 % | 7,894 (7,894) | 96 (98) | 99.1 % (99.1 %) |

The last report's reading: 23,903 calls, 363 failed, against a ledger count of 226. Windows of that comparison: not recorded.

## Appendix B: commands that worked here

```bash
cd ~/.cache/aimeter/r2
python3 xcheck-table.py v4-target.json --hours=24 --end=1795683600 --steps=300 --promql   # builder vs ledger vs PromQL, edges on bucket boundaries
python3 red-census.py v4-target.json --hours=24                                             # color of every number tile over time
python3 embed-rule-probe.py hours=48                                                         # the embeddings rule over live history
python3 build.py ./v4-raw.json && REPO_ROOT=/home/lars/projects/SystemNix ./render.sh "$PWD/v4-raw.json" "$PWD/v4-rendered.json"
python3 verify.py v4-rendered.json && python3 normalize.py fetch v4-rendered.json v4-dump.json && python3 normalize.py emit v4-dump.json v4-normalized.json
REPO_ROOT=/home/lars/projects/SystemNix ./render.sh "$PWD/v4-normalized.json" "$PWD/v4-target.json"
python3 dryrun.py v4-target.json --keep && node shot.mjs "https://signoz.home.lan/dashboard/<kept id>" v5kept --width 1500 --height 7600 --settle-ms 9000 --expr kept-expr.js
cd /home/lars/projects/SystemNix && bash scripts/test-post-deploy-signoz-dashboards.sh
nix build .#checks.x86_64-linux.signoz-query-lint .#checks.x86_64-linux.signoz-dashboard-lint-selftest .#checks.x86_64-linux.ai-meter-spend-promql .#checks.x86_64-linux.ai-meter-alert-promql .#checks.x86_64-linux.post-deploy-signoz-dashboards-selftest --no-link -L
```

## Appendix C: what changed in the tree (all daemon-committed, 461 lines added, 19 removed in eight files)

| File | Change | Commit |
| --- | --- | --- |
| `modules/nixos/services/ai-meter.nix` | `dashboardFile`, `dashboardRange` (read from the file's `duration`), `dashboardUrl` on the iframe and the link, the gatus pattern | `8aa26dbc3` |
| `modules/nixos/services/_signoz-alerts.nix` | rule "AI Embeddings Calls Failing (ai-meter)" | `de738beae` |
| `modules/nixos/services/dashboards/ai-meter.json` | table and pie descriptions, the explorer link in the notes panel | `8d843a001` |
| `flake/parts/checks/ai-meter-guards.nix` | `readRule`/`firesOf`, eight fixtures and a second promtool run for the embeddings rule | `de738beae` |
| `flake/parts/checks/selftests.nix` | `post-deploy-signoz-dashboards-selftest` | `8d843a001` |
| `scripts/post-deploy-check.sh` | sources the library, calls it after the provisioner check | `c6f9a4320` |
| `scripts/lib/signoz-dashboards-drift.sh` | new | `497bad814` |
| `scripts/test-post-deploy-signoz-dashboards.sh` | new | `497bad814` |
| `scripts/negative-test-lints.sh` | five `aimeter` legs (`embeddings-*`), two `signozdash` legs (`selftest-dashboards-*`) | `8d843a001` |
