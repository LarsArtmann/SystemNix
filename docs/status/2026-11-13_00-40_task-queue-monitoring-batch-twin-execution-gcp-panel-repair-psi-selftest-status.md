# Task-Queue Monitoring Batch (5 items) — Twin-Executor Convergence, GCP Panel Repair, PSI Fixture Selftest

**Authored:** 2026-11-13 00:40 CET (`date` CLI)
**Author:** Crush (glm-5.3-flash), task-queue batch `000001a1d151e4a4fec167c93dcb00000000` (5 monitoring items, one session)
**Session span:** ~22:05 → 00:40 CET. **A SECOND instance of the same queue ran the same batch in parallel** — detected mid-flight (item 1's commit landed with my footer grep clean at session start), and by close BOTH strands had converged: every item ticked, every item footer-covered, tree green.
**Verdict:** All 5 items LANDED + verified (shared between the twin strands; my unique content: the GCP panel engine-verified rewrite, the linkage-probe fix, the PSI fixture script, the cvagent/forgejo follow-up row). `nix flake check --no-build` **all checks passed** at close; working tree clean; verdict recorded via `tq verdict`.

---

## a) FULLY DONE

### Item 3 (GCP dashboard disposition → re-arm won) — MY main work, complete end-to-end

The [decision] resolved itself by events (receiver re-armed + fixed + deployed; series fresh to the minute), but the twin session's close-out carried a FALSE implication — "every gcp.json panel metric family present with live series" — which I falsified and repaired:

1. **The mangling premise was dead wrong (live-verified):** all 10 shipped panel queries consumed underscore forms (`run_googleapis_com_request_count`) that match **ZERO series** — the store holds GCP's dotted names verbatim (`run.googleapis.com/request_count`). And bare dotted identifiers **fail PromQL parsing outright** (`unexpected character: '.'`). The renderable form is the `{__name__="..."}` selector.
2. **Delta temporality = PromQL-blind, engine-verified by A/B through the ACTUAL dashboard path** (v3 `query_range`, correct `promQueries` payload): gauge `container/containers` → **8 series**; Delta `request_count` → **0**; `request_latencies.bucket` → 0; `function/execution_count` → 0; underscore → 0. Since the receiver is DELTA-only (runbook), every counter/latency panel is **unrenderable, not just misnamed**.
3. **gcp.json rewritten 10 → 4 live panels** (Cloud Run active containers, Functions active instances, Storage bytes, Storage objects — each query pre-verified: 8/1/43/44 series). Layout pruned consistently (the layout-references-unknown-panel HTTP-400 trap avoided).
4. **Live dashboard converged via the provisioner's own PUT path** (`/api/v2/dashboards/<id>`): re-GET diff = API-injected defaults only (`duration`/`links`/`refreshInterval`). Also fixed the dashboard's own top-level description, which still taught the falsified "dot→underscore" contract.
5. **Runbook query-notes section rewritten** (`docs/services/signoz-gcp-monitoring.md`): verbatim-dotted names, `__name__` selector requirement, the DELTA-blind panel rule, live label keys (`service_name`/`bucket_name`/`function_name`/`project_id`/`response_code`…), per-panel series counts.
6. **Query-lint exemption widened** to `googleapis[._]com` (the old exemption only covered the underscore spelling; my dotted store names ending `_count` tripped the histogram-suffix trap). All **8/8 signoz negative-test legs stay green**; `signoz-query-lint` green.
7. Fleet-wide mangling-class sweep: **no other dashboard carries underscore googleapis queries** (grep at close — clean).
8. Row 101 + TODO_LIST:391 correction addenda appended on both surfaces.

### Item 4 (PSI kernel-percent fixture selftest) — my script, twin's registration

- `scripts/test-psi-percent-semantics.sh`: extracts the REAL psi-metrics collector body from the staged module (pool-smart extraction pattern), unescapes Nix string forms, seams OUT-dir/PSI-paths//sys/block-glob to fixtures, then drives **9 dynamic cases + 5 static legs = 24 assertions**: calm 0.63% (the exact T4 trap value → alert must stay 0), strict-`>` boundary at 50.00, storm 63.5 → alert 1, strict-`>` boundary at full 10.00, full-stall 12.4 → alert 1, `>=` warning boundary at 20.00, io-calm, io-phantom (45.2% PSI + empty block dir → phantom 1 / alert 0 / busy 0.0), plus static fraction-form rejection + the 50/10/20/40 percent-literal presence pins.
- **Mutation-verified**: reintroducing `> 0.50` fails 5 legs (3 dynamic + the static tripwire) — the fixture is non-vacuous.
- shellcheck clean (standalone run — the script rode a daemon commit that bypasses staged-.sh legs).
- Flake check `psi-percent-semantics-selftest` **GREEN** (registered by the twin session on my script; my duplicate registration removed after the "already defined" eval collision — see §d.5).

### Item 2 (log→trace correlation) — probe-form fix (the twin closed the item itself)

- **Discovered the documented linkage probe is broken**: `countIf(trace_id != '000…0')` false-positives the ENTIRE journald fleet — those rows store trace_id as the **empty string** `''`, so the 32-zeros comparison counted every journald line as trace-linked (70.4M false-positive rows/h vs **31,797 real** in the same hour, `length(trace_id)=32`).
- Fixed in BOTH surfaces (`docs/agents/monitoring.md` gotcha + `docs/services/signoz.md` cheat-sheet): strict form pinned, false-positive class named.
- Real census for the record: the pivot is **alive** for the OTLP-logs emitters (dnsblockd ~19.3k/h traced, stalwart ~9.8k/h, gotenberg 217/h — sampled ids resolve in `signoz_index_v3`); the journald fleet (discordsync, browser-history, cv-application, bank-sync, overview) is empty-string = uncorrelated by construction.
- Verified upstream OTTL capability for a future text-extraction path: `TraceID()` (hex → pcommon.TraceID) exists in contrib's ottlfuncs — cited in the row.

### Item 1 (throttle triage) — verification re-read + follow-up minted

- The twin session closed the 10-unit triage (`542c63e26`, footer verified): papdashboard 512M→640M + project-discovery-daemon explicit 7G High fixed; nix-daemon/clickhouse/signoz-collector/bank-sync/geometrikks/inboxclean/mr-sync/discordsync justified designed.
- **My live re-read found 2 units OUTSIDE their sweep** (cvagent landed 2026-11-08, post-dating the 10-unit list): **cvagent.service 1.38M MemoryHigh events in ~2.5h (~10-13k/min ACTIVE, cur 428MB pinned at the derived 429MB high of harden-default 512M max, oom_kill 0)** and **forgejo.service grazing at 95% of the same default high** (21k events/52min, cur 389MB). Both budget fixes queued as a NEW agent-executable row (TODO_LIST:389-insert + monitoring.md:328-insert, evidence-backed) per the already-ticked-means-skip queue rule.

### Item 5 (P0-batch battery) — re-verified live (the twin closed it)

- Independently re-ran every §f.3–f.10 leg before noticing the twin's CHANGELOG close-out (see §d.12): PSI alert 0 at calm with percent HELP text (T4 live), io two-tier live, ratchet gaps 4 / over_threshold 0 (the documented conscious 3→4 raise), `systemnix_git_ahead_by` fresh, traces dashboard provisioned, §18 sweep wired.
- **All P0 rules provisioned in the live 61-rule set** (exact total parity with the tree): CPU Thermal Ceiling, Thermal Guard Trip Rate, Git Push Lag, Git Head Stale, Chronic Memory Throttle — the last **FIRING** (true positive on the live cvagent thrash).
- **Found the rules-API contract move independently** (before reading their note): `/api/v1/rules` now serves the SPA HTML; `/api/v3/rules` carries the data — with a pagination gotcha (default page = 20; pass `limit=100`).

### Session hygiene

- Re-dispatch check at start; content-pins before every edit; pathspec commits; concurrent-session races handled (index.lock waits ×3, mid-edit re-read ×1, duplicate-registration reconciliation); final `nix flake check --no-build` **all checks passed**.

---

## b) PARTIALLY DONE

1. **cvagent + forgejo budget fix — queued, NOT fixed** (TODO_LIST:389-insert). The evidence is complete and the fix is 2 lines + eval + deploy; it now waits for a dispatch cycle. Queue discipline (already-ticked = skip) says this is correct; §e.7 argues the tradeoff.
2. **Item 2's fleet enablement — upstream-queued, not started**: cv/discordsync/crm-server OTLP-logs slog bridges live in their repos (TODO_LIST:3524, minted by the twin). SystemNix-side surface complete.
3. **GCP Delta panels — deleted, not replaced**: 6 panels removed because Delta families cannot render via PromQL. A potential restoral path exists (**BuilderQuery.Temporality** — the query-builder can request Delta explicitly, which is how the native Services page reads delta) — unexplored (§f.4).
4. **Quantile refinement (row 64's ask) — impossible now**: `run.googleapis.com/request_latencies.sum` has ZERO series in the store (only `.bucket`/`.count` land), so `histogram_quantile` cannot compute. Documented in the runbook; revisit when/if the receiver exports sum.
5. **My item-2 footer commit intent — never fulfilled**: the index.lock hit + my moving on meant the probe fixes rode daemon sweeps (footless). Item credit is intact via the twin's marker commit; my contribution is attributed only here.
6. **io-corroborated psi path — fixture-uncovered by design** (needs a mid-run-mutating stat file; documented in the script header). io boundary at 40.00 and io-threshold mutation legs also unpinned.

---

## c) NOT STARTED (noticed this session, not done)

1. **Cheat-sheet API-probe surfaces are now stale in 3 spots**: (a) "Rule/policy parity" still teaches `/api/v1/rules` (serves HTML since the package move); (b) no pagination note (`limit` param, default 20); (c) the v3 `query_range` payload shape (`promQueries` map + `panelType:"graph"` + `queryType:"promql"`) — which cost me ~6 failed attempts — is documented nowhere.
2. **DELTA-blindness gotcha scope wording**: monitoring.md row 63 attributes it to "the v1 query API" — my A/B proves it engine-level through v3 `query_range` (the dashboard path). The row's scope needs widening; the builder-Temporality exception deserves a sentence.
3. **PSI emitter missing-PSI fail-visible**: the emitter `exit 0`s silently when `/proc/pressure/*` is absent — a missing-PSI host reads phantom-calm. Freshness canary / fail-visible class, unqueued until this report.
4. **Browser-eyeball of the rewritten GCP dashboard** (blocked:user — API-verified only, the standing class).
5. **Gatus verdict probe for the two-tier PSI checks post-deploy** (io_warning=1 on the chronic band live; the check pins `node_psi_io_alert 0` so it SHOULD be green — but the recorded verdict is root-only, unprobed).
6. **OTTL `TraceID()` extraction vs the pinned fork's config surface** — upstream capability verified; the fork's rendered-config leg is not.
7. **A twin-executor prevention mechanism for the tq queue** (see §g.3).

---

## d) TOTALLY FUCKED UP (own goals, all recovered — one nearly not)

1. **The awk rate-math column slip**: my first throttle-rate computation used `$4-$2` (s2's UNIT name minus s1's counter) producing impossible negative rates — caught only because negative event-rates are physically absurd. The quote-scrutiny rule exists for exactly this; I applied it AFTER shipping the garbage to stdout, not before.
2. **The trace_id probe confusion — nearly encoded a FALSE census**: my first ClickHouse linkage probe said 100% of lines carry trace_id (the empty-string ≠ 32-zeros artifact); I then misread a follow-up result (0 vs 70.4M) before landing the truth via `length()=32`. Three probes to measure one number. The 2026-10-23 wrong-data lesson (plausible-looking output from a mangled read) applies verbatim to SQL comparisons.
3. **Forgot to retry the item-2 commit**: the index.lock hit → I moved to item 4 → the commit never happened until a status check ~40 min later surfaced it. The probe fixes rode daemon sweeps instead (footless, unattributed). A "planned-commits-not-yet-landed" ledger would have caught it.
4. **Two slice-boundary off-by-ones in the selftest extraction**: the end bound included the `'';` terminator (bash EOF error) and the start bound skipped the OUT line (`mv "$TMP" "$OUT"` with empty OUT). I cloned pool-smart's extractor and STILL got the arithmetic wrong twice despite the working reference being open in front of me — `tail -n +K` is 1-based FROM K; I derived it, stated it wrong once, fixed it, then fixed the start a second time.
5. **Duplicate flake-check registration**: the twin registered `psi-percent-semantics-selftest` on my script while my own registration was mid-flight → "attribute already defined" eval failure. Reconciled by removing mine. The footer-grep re-dispatch check (run at session START) cannot catch a twin that commits AFTER your check — there is no in-flight claim mechanism.
6. **Commit-subject length gate**: 76 > 72 — the house rule was in AGENTS.md the whole time. Cost one full pre-commit hook run (~4 min) to learn.
7. **v3 payload fumbling**: ~6 failed request shapes (string vs int64 start, `composite query is required`, `TIME_SERIES` vs `graph`, `unknown field "kind"`, `stepInterval`) before reading the Go source that answered everything in one page. Trial-and-error cost ~15 minutes a single `sourcegraph` read would have saved.
8. **Instant-query oracle flakiness nearly became a verdict**: gauges read "2 series" via v1 instant, then 0 minutes later (GCP collection lag vs the staleness lookback). I almost encoded render/no-render verdicts from a flapping oracle — the control-test (run a known-live metric through the SAME probe) caught it, but I ran the control only after the contradiction, not before the first conclusion.
9. **Doc-stamp provenance written BEFORE verification**: I stamped "rode the mail-relay-verdicts wave" into README/FEATURES, then verified the mechanism afterward (the rename moved the module INTO the auto-discovered tree → +1). It held — but shipping-then-checking an attribution is the commit-message-evidence-rule class inverted.
10. **Transcription-from-memory traps**: mistyped panel UUIDs into the rewrite script (the assert caught it pre-write), and the FEATURES "files total" edit assumed the basis before computing it (146+13=159 confirmed only after).
11. **`ensure_ascii` churn**: my first `json.dump` escaped every em-dash in gcp.json, churning the whole diff; the original file convention (raw UTF-8) was checked only after seeing the diff. Re-dumped correctly — should have diffed one line before the first write.
12. **Battery work done BEFORE reading the adjacent close-out**: I re-derived the rules-API break and re-ran battery legs while the twin session's CHANGELOG entry — already on disk — documented the same break and the same verification legs. The 2026-10-23 status-report pre-read discipline (`rg` the error signature BEFORE diagnosing) would have saved the duplicated probes. This is the session's most avoidable cost.

---

## e) WHAT WE SHOULD IMPROVE

1. **Adjacent-close-out pre-read as step ZERO of any battery/verification pass** — `ls -t docs/status/ | head` + CHANGELOG head BEFORE probing. (§d.12 — the single biggest time sink this session.)
2. **Control-oracle-first**: before trusting ANY new probe shape, run a known-live metric through it. One control probe converts "is this broken or is my probe wrong?" into a decidable question.
3. **Source-read before payload-guessing**: the v3 API shapes are in the pinned repo; one fetch beats six 400s. (§d.7.)
4. **Never transcribe identifiers from earlier terminal output** — key rewrites by name/content anchors, or re-extract programmatically. (§d.10; the AGENTS.md edit-transcription lesson, API-payload edition.)
5. **Match generated-file conventions before first write** (escaping, indent, trailing newline): read 3 lines of the target, then write. (§d.11.)
6. **A commit ledger for interrupted commits**: after ANY failed/retried git operation, write the intent down (even in the todo list) until the commit lands — the daemon sweep is always waiting to absorb the orphan.
7. **Queue-rule tradeoff, stated plainly**: already-ticked-means-skip protected me from re-doing item 1, but it also deferred a live 13k-events/min thrash fix into a future dispatch. Rules over harm this time; the follow-up row carries full evidence so the next session pays ~10 minutes. Consider whether evidence-backed adjacent fixes to an ALREADY-OPEN defect class (the row's own domain, pre-deploy-gated anyway) should be allowed to ride the discovering session — an owner call.
8. **Probe-recipe bugs must be caught by a known-value check BEFORE the number enters a report** — the negative-rates case (§d.1) and the 100%-traced case (§d.2) were both one-known-value-check failures.
9. **The twin-executor overlap was ~50% wasted motion at the batch level** (both strands triaged, both ran batteries, one registration collided). Per-session uniqueness needs a queue mechanism, not session etiquette (§g.3).
10. **Mutation-test in the same breath as first-green** — the RED-leg came one step late this session (§a item 4). Cheap to do immediately; easy to skip.

---

## f) NEXT (ranked, ≤50 — session-fresh items first; already-queued rows cited not duplicated)

1. **Fix cvagent MemoryMax 512M→1G** (serve unit's `harden` call, cvagent.nix ~:205) — queued row TODO_LIST:389-insert; 1.38M events and climbing at last read.
2. **Fix forgejo.service MemoryMax→1G** (main web unit's `harden`, forgejo.nix ~:546) — same row.
3. **Repoint signoz-provisioner at `/api/v3/rules` (+ pagination) and verify its dashboard phase against `/api/v2/dashboards`** — tracked by the twin's queue row; until it lands, rules convergence is dead and ANY provisioned-rule change cannot deploy.
4. **Update the 3 stale cheat-sheet probe surfaces** (rules-parity v1→v3, pagination note, v3 payload shape) — NEW row minted at authoring time.
5. **Widen the DELTA-blindness gotcha scope** (v1 wording → engine-level via v3; name the builder-Temporality exception) — NEW row minted.
6. **PSI emitter: fail-visible on missing `/proc/pressure` + a psi.prom freshness canary** (the silent `exit 0` = phantom-calm class) — NEW row minted.
7. **Evaluate BuilderQuery `Temporality` as a Delta-panel restoral path** (query-builder-formatted dashboards may render request-rate panels the PromQL path cannot) — NEW row minted.
8. **psi selftest coverage gaps: io boundary at 40.00 exactly + io-threshold mutation leg + the corroborated-path timed fixture** — NEW row minted.
9. Browser-test the rewritten GCP dashboard (blocked:user, standing class) — verify the 4 panels actually render in the UI.
10. Gatus verdict probe for "Memory Pressure" + "I/O Stall Rate" checks on gen-1004 (recorded-verdict surface still missing — row 330's sanctioned-surface ask is the durable fix).
11. Post-deploy re-read of papdashboard + project-discovery-daemon counters once the twin's 640M/7G bumps deploy (counters reset on restart — their row's own leg).
12. Execute the queued cvagent/forgejo row's post-fix leg: re-read counters post-restart to confirm the thrash died (and that 1G was the right size).
13. Sweep ALL `docs/services/*.md` + cheat-sheets for other probes keyed to the dead v1 rules route (only signoz.md verified so far).
14. When the provisioner is repointed (f.3): verify it sees the rewritten gcp.json as "Unchanged: skipping" (my PUT convergence assumed the canonical projection matches — unproven until the provisioner runs again).
15. `metric-sweep.sh` run over the fleet after the GCP rewrite (the sweep's allowlist may reference the deleted underscore names — they were already phantom, but the sweep's expected-absent list should now be checked against the 4 new dotted names).
16. Consider a `request_latencies.bucket`-only panel IF a cumulative bucket view is ever wanted (currently dropped; no renderable latency surface exists at all — flag to owner if Cloud Run latency visibility matters).
17. The `no .sum series` finding — check whether the googlecloudmonitoring receiver CAN export histogram sums (config knob?) — if yes, quantiles become possible and row 64's refinement unblocks.
18. Watch: does `Chronic Memory Throttle` FIRING actually page Discord (log line ≠ delivery — the standing class)? One >256-rune alertname probe or a channel glance.
19. Sweep `docs/agents/monitoring.md` row 63's "check `temporality`" advice against the new v3 probe recipe (cross-reference f.5's wording fix).
20. cvagent-scan oneshot + forgejo-census oneshot share the 512M default-derived budget — no throttle evidence yet; keep on the watch list (do NOT bump without evidence — anti-flinch).
21. geometrikks at ~87% of High — watch; bump only on sustained-rate evidence.
22. crm-server's 183k-event startup burst (rate 0 after settle, cur 15% of High) — benign; note as accepted shape or size a startup grace if it ever re-fires post-deploy.
23. `system_service_memory_throttle_designed` (row 98's metric) — verify cvagent/forgejo/nix-daemon designed-flags render correctly in gen-1004's textfile (nix-daemon designed=1 was verified; spot-check the others).
24. The psi selftest's block-glob seam (`for d in $2/block/*`) — confirm sandbox determinism held in CI (the nix build was green locally; CI runs `nix-check.yml` on push).
25. `negative-test-lints.sh`: consider adding a POSITIVE case asserting the widened googleapis[._]com exemption (dotted form stays green) so the exemption can't silently regress to underscore-only again.
26. `doc-counts` gate UX: it reported README first, then FEATURES on a SECOND full hook run — make one failure enumerate ALL stale stamps (saves a ~4-min hook cycle per extra doc).
27. The status-report pre-read discipline needs a mechanical trigger: when a batch item's verification legs overlap a prior report's §f list, grep the prior report FIRST (this session's §d.12, generalized).
28. Twin-executor: draft the tq claim/lease proposal for the owner (§g.3) — a `tq claim <task-id>` marker written at batch start would have made my session-start footer grep conclusive.
29. Push state: the branch went to ahead_by 0 during the session (someone pushed) — confirm the push included the twin's + my commits (the queue derives via local git; a push audit is owner-side).
30. `scripts/metric-exists.sh` + `scripts/metric-sweep.sh` — both probe ClickHouse directly (unaffected by the API move); confirm the sweep's expected-absent list has no googleapis entries that flipped live (they were 0-series phantom names at stamp time).
31. Row 97 (mislabeled `system_service_memory_events_high` gauge rename) — still open, adjacent to this batch's domain; the row-98 metric (throttle_high) now exists alongside, so the rename's "check consumers first" leg is cheap now.
32. Row 328's twin (§17 triage) — fully closed, but its Source report (2026-10-26 §f.43) predates the gen-1004 numbers; no action needed, noted for provenance.
33. The `memory.peak` probe recipe error in MY session notes (I awk'd memory.events for a `peak` line; it's a separate cgroup file) — nothing committed with the error, but future triage rows should read `cat memory.peak` (the twin's commit messages model the correct read).
34. Signoz package move follow-ups beyond the provisioner: the UI/API move may have shifted MORE documented endpoints (the signoz.md ops notes reference several v1 paths) — one sweep row once f.4's cheat-sheet pass lands.
35. `todo` hygiene: my inserted rows (389-insert queue/library pair) rode the twin's batch commit — verify `check-todo-system.sh` stays green on the INSERTED lines (it ran during their successful commits, so ✓; note only).
36. If Cloud Run request visibility matters to the owner: the ONLY renderable path today is the query-builder Delta path (f.7) — otherwise GCP request metrics stay dashboard-invisible by design.
37. Re-check `system.columns` for exemplar columns on the next signoz/collector lock bump (standing watch-note, unchanged).
38. Row 100's dnsblockd census numbers move daily — the row is closed with 11-12 numbers; no re-probe needed unless the fleet changes.
39. `gcp.json` panel IDs: 4 surviving panels keep their original uuid5 ids; IF the dashboard is ever regenerated wholesale, the generator's slug scheme (`uuid5(NAMESPACE_URL, "systemnix-gcp/<slug>")`) is documented in the runbook.
40. The `strip_allow`/exemption structure in signoz-query-lint now has TWO exemption mechanisms (allowNames list + googleapis regex) — a comment-level note distinguishing them exists; fine.
41. Watch for a SigNoz lock bump that changes panelType/API shapes again — the payload shapes I derived are pinned only in this report + (soon) the cheat-sheet row (f.4).
42. The `psi.prom` io_warning=1 on the chronic band means the "I/O Stall Rate" gatus check sits in its observability tier permanently on this box — expected by the 2026-11-08 retune design; the f.10 verdict probe should confirm green (alert tier), not "no warning".
43. Item-2's per-service trace coverage — once ANY fleet service lands OTLP logs upstream, flip its signoz-coverage registry wiring + re-run the length-32 census (the probe fix makes that census honest now).
44. `stalwart` + `gotenberg` carry real trace ids but were outside every coverage discussion — a one-line coverage-registry note would prevent "who are these OTLP-log emitters?" archaeology.
45. The 6 deleted GCP panels' QUESTIONS (request volume, latency, billable time) have no monitoring surface anywhere now — if the owner wants ANY of them, f.7 is the only path; otherwise this is a documented blind spot, not a defect.
46. `check-todo-system.sh` gate: my inserted queue row is one physical line ✓; future editors must keep full-line-match discipline on it (the standing 2026-10-23 trap).
47. The batch's CHANGELOG entry (twin's, bcb764044) + this report now double-document the API break — the plan-file §1 sync (f.13 of the old report) may want the v3-contract fact added when someone next touches the pareto plan.
48. `io-psi-crosscheck.sh` selftest owns the timed-mutation fixture pattern — if the psi io-corroborated leg (b.6) ever gets built, steal that harness rather than inventing one.
49. Session-economics note for the queue: this batch consumed 2 full sessions for 5 items with ~50% overlap; f.28's claim mechanism is the leverage point.
50. Housekeeping: `/tmp` scratch from this session (s1/s2 cgroup snapshots, mktemp fixture dirs) is ephemeral by design — verified no repo residue beyond the committed work.

---

## g) QUESTIONS FOR THE OWNER (cannot resolve myself)

1. **cvagent is thrashing at ~13k reclaim events/min RIGHT NOW** (working set 428MB vs its 429MB derived high; fix = 2-line MemoryMax bump, queued, deploy-gated). Do you want the fix expedited into the next deploy window as its own item, or does it ride the normal queue cadence? (The thrash is pure CPU/latency waste on an idle-capable host — no data risk.)
2. **The tq queue dispatched this same batch to TWO concurrent sessions** — we converged, but ~half the work was duplicated and the collision produced a broken intermediate eval (duplicate check definition). Do you want a claim/lease mechanism (`tq claim <task-id>` written at batch start, footer-checked at dispatch) so a second session sees "claimed" at its re-dispatch check — or is the duplicate-tolerant behavior acceptable given it also buys redundancy?
3. **GCP request/latency visibility**: with the DELTA-only receiver, those panels CANNOT render via PromQL and I deleted them. The only restoral path is the query-builder Temporality route (unproven) or an upstream cumulative-conversion change. Is Cloud Run request/latency visibility on the dashboard actually wanted (→ I evaluate the builder path), or are the 4 gauge panels the right permanent shape?

---

**Self-harvest compliance:** genuinely-new §f items landed at authoring time — cheat-sheet API-contract row (f.4), DELTA-scope wording + builder-Temporality eval (f.5+7, one row), PSI fail-visible/canary row (f.6), psi fixture-coverage legs row (f.8) — appended to TODO_LIST monitoring section + monitoring.md library. f.9/f.10 map to existing blocked:user/standing rows (no duplicates); f.1/f.2/f.3 already queued (cited, not re-minted). The underscore-sweep (f-adjacent) was EXECUTED at authoring time: clean — no row needed.
