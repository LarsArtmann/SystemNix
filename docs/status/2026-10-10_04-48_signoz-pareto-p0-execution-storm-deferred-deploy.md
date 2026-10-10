# SigNoz Pareto P0 Execution — Ground Truth Battery Landed, Deploy Batch Storm-Deferred

**Authored:** 2026-10-10 04:48 CEST (`date` CLI)
**Author:** Crush, executing `docs/planning/2026-10-10_02-44_signoz-three-pillars-full-power-pareto-plan.md` (owner directive: READ → break down → execute+verify step-by-step, repeat)
**Session span:** ~03:20 → 04:48 CEST. Host state at close: io PSI some avg10 **26.6%** (storm peaked 81% mid-session), k10temp Tctl 30m-max hit **98.6°C** at ~04:15 (freeze-signature conditions from a parallel session's build battery — my builds were two small lint checks + evals).
**Verdict:** P0 (T1/T2/T3/T4/T26) fully executed with live evidence; T5/T6/T9/T10/T11/T12/T15 authored and lint/eval-green; **NOTHING deployed** — storm gate + a foreign eval blocker defer the single deploy. All close-out rows intentionally still open pending deploy verification (never claim fixed before verified).

---

## a) FULLY DONE (verified this session)

### T1 — Live ground-truth battery (the plan's #1 task; every D-row resolved)

| # | Micro | Result (live probe, timestamped) |
|---|-------|----------------------------------|
| 1.1 | Spans/h per service, 24h (`distributed_signoz_index_v3`) | **9 services emitting**: dnsblockd 16,556/h, discordsync 5,977, cv-application 2,293, bank-sync 1,482, browser-history 983, overview 163, crush-daily 123, indexer-web 35.5 (stale since 10-09 08:10), dnsblockd-test 0.1. Last spans at 03:37 = live. |
| 1.2 | `signoz_calls_total`/`signoz_latency` in store | 14,725 / 252,198 / 14,011 series; samples fresh to the minute (unix_milli 03:34). **All Delta temporality.** |
| 1.3 | `traces_service_graph_*` edges | All 8 metrics **Cumulative**, 2,820 edge series, rates compute live. |
| 1.4 | Config parity | Collector PID 1605988 healthy, **zero decode/invalid errors** since 10-09 12:00; spanmetrics flowing proves the deployed config carries the connector. D1 (blocked:deploy claim) is STALE — the batch IS deployed. |
| 1.5 | Services-page sufficiency | Delta spanmetrics (the page's RED input) fresh ⇒ native per-service RED available ⇒ per plan deferral (monitoring.md:75) a duplicating panel set is NOT built; custom dashboard rescoped to what the page LACKS (edges/dependency). |
| 1.6 | Verdict recorded | monitoring.md:75 row closed `[x]` with evidence + the delta-blindness discovery. |

**THE discovery of the session:** SigNoz PromQL (v1 `/api/v1/query`) is **DELTA-BLIND** — `count(signoz_calls_total)` returns 0 series despite fresh samples; only Cumulative-temporality metrics are PromQL-reachable. The native Services page reads delta via the query-builder fine. Consequence: dashboards/alerts must consume `traces_service_graph_*` or scraped metrics. Documented in signoz.md (ops note + cheat-sheet) and monitoring.md (gotcha bullet).

### T2 — Rule/policy/dashboard census: CLEAN on all three legs
- **2.1** 31 rules in `_signoz-alerts.nix` == 31 live, zero drift both directions.
- **2.2** 31 route policies == exactly-one per rule UUID (policies are name==ruleId), zero orphans, zero missing.
- **2.3** 7 live dashboards == 7 files, all owner=systemnix, **zero zombies**.
- Observation: the one firing rule is "Swap Usage Critical (>80%)" — plausible on this zram box, not phantom (triage queued as f#15).

### T4 — Memory-PSI rule: root cause WORSE than the queued premise
The D5 row guessed "reads the wrong PSI file". Live source read + kernel probe found the real bug: **units mismatch** — `/proc/pressure/*` reports PERCENT (kernel showed `some avg10=0.63` = 0.63%) but the emitter thresholds were FRACTIONS (`>0.50`, `>0.10`, `>=0.20`, `>0.10`) ⇒ `node_psi_memory_alert=1` at 0.5% pressure — **100× too sensitive, a standing red** (live proof: alert=1 while memory pressure was 0.63%). Fixed all four thresholds to percent semantics (50/10/20/10), HELP texts updated, gatus alert text sharpened to name the unreachable class (the 2026-10-08 storm misfire was "check failed" read as "PSI breach"). The emitter's file reads and atomic mv were CORRECT (no wrong-file bug).

### T26 — Probe cheat-sheet + hwmon table + exemplar watch
- signoz.md: new "Live-probe cheat-sheet" section (spans/h, series-existence + temporality, PromQL-visibility, log→trace ratio, rule parity — all copy-paste, loopback, no auth) + delta-blindness ops bullet.
- monitoring.md: hwmon chip **fingerprint table** live-derived 2026-10-10 (k10temp `pci0000:00_0000:00:18_3` Tctl; acpitz −2°C under Tctl; amdgpu edge on `0000:00:08_1_0000:c6:00_0`; nvme0/nvme1 sensor signatures; wifi) + the value-scan query pattern.
- Exemplar upstream-watch note appended to the existing exemplar bullet (recheck `system.columns` on lock bumps).

### T3 — GCP disposition (decision-leg)
T3.1 live-verified: **0** `monitoring_googleapis_com*` series, **10 dead panels** in the live UI. Decision brief written INTO the [decision] row: recommend re-arm (sunk SA/IAM/key, real key kills the falsified failure mode, delete throws away 10 built panels). Owner question outstanding (g#3).

### T9 (partial, rule-side) + a live phantom fix
- **CPU Thermal Ceiling rule authored**: `max_over_time(node_hwmon_temp_celsius{chip=~"pci0000:00_0000:00:18_.*"}[30m]) >= 95` — k10temp address is CPU-internal (stable across the GPU bus-renumber class). Query live-verified. **Would have fired DURING this session** (30m-max 98.6°C at ~04:15) — true-positive evidence recorded.
- **GPU Thermal rule phantom FIXED**: old selector `.*c5:00_0` returns **0 series live** (bus renumbered to c6:00_0 — the exact post-crash class the comment warned about); widened to `.*:c[0-9a-f]+:00_0` (uniquely matches discrete-GPU PCI chips; verified 47°C, and verified non-matching vs k10temp/nvme/wifi labels). Only the ClickHouse fallback had kept the rule alive.

### T10 — Service-sanity sweep (the DiscordSync hotloop class): BUILT + PROVEN
- `scripts/lib/service-sanity-sweep.sh`: CPU% leg from cgroup cpu.stat deltas (rate-shaped — no restart blindness), journal line-rate leg (one `journalctl -o json` walk + jq), fail-closed WARNs, exempt regex (clickhouse, signoz-otel-collector), `SANITY_JOURNAL_CMD` injection point for fixtures.
- `scripts/test-post-deploy-service-sanity.sh`: 7 fixtures incl. the DiscordSync shape (150% CPU; 640/min journal). **Green locally AND as flake check** `post-deploy-service-sanity-selftest` (built via nix; first attempt hit the tracked-files trap — see d).
- §18 wired into `post-deploy-check.sh` (sourced like §17; FAIL integrates with the existing fail-baseline/exit-3 machinery).

### T13 — discovered ALREADY IMPLEMENTED (stale row)
§17 sweep + `scripts/lib/memory-throttle-sweep.sh` + fixture selftest (flake check) + advisory semantics (decided 2026-10-09) all exist — monitoring.md:101 was stale at queueing time. Row close deferred to close-out (needs the "which surfaces" discipline: row + queue twin).

### T15 — Coverage ratchet (file-side)
`maxUpstreamGaps` 4→3 + the stale "4 gaps incl. overview" comment corrected (3 remain: pma, papdashboard, hermes — exactly matching live `signoz_traces_upstream_gaps`=3, `over_threshold`=0; comparison operator verified `>` so 3/3 stays healthy). T15.1 (dnsblockd flip) verified already-deployed via T1.

---

## b) PARTIALLY DONE

| Item | Done | Missing (why) |
|------|------|---------------|
| **Deploy batch** (T4 fix, T15 ratchet, T5/T6 dashboard, T9+T12+T11 rules, git-lag collector, §18) | All authored; signoz-query-lint GREEN (nix-built); service-sanity selftest check GREEN; eval green for MY files | **Not deployed.** Two blockers: io PSI avg10 26.6–81% all session (gate <20%, freeze doctrine — a toplevel build during the parallel battery is the freeze-#22 class), and a foreign eval red (below). |
| **T5/T6 dashboard** | `dashboards/traces.json` (6 panels: calls/p95/error-ratio per service + top edges/failing edges/edge-p95; every query pre-verified live; uuid5 IDs; disjoint grid; one-query-per-panel; etc entry wired in `_signoz-alerts.nix`) | Provisioner run ("OK 8 dashboards", no FAILED lines) + render eyeball — deploy-gated. |
| **T11 git-lag tripwire** | Collector (User=lars, ProtectHome=read-only, fail-closed scrape_error, ahead_by + head_age) + 2 absence-proof rules (`(X > N) or absent(X)` — collector death fires instead of phantom-green) | Deploy + live-metric verify + synthetic fire. |
| **T12 trip-rate rule** | Authored, query live-verified (increase[2h]=0 now), threshold 3 = incident arithmetic (#11 4.75/2h, #12 3.75/2h avg — target 4 would have MISSED #12; that correction is IN the rule description) | Deploy + eval-state verify. |
| **Close-out bookkeeping** | monitoring.md:75 closed; T3 brief; cheat-sheets | Rows 71/76/14/101 + TODO_LIST:166 twin, CHANGELOG, plan-file §1 sync — all deliberately deferred until deploy-verified (evidence rule). |
| **Commits** | All work committed (daemon heuristic commits swept it; tree clean at 04:48) | Not amended-forward into attributed commits yet (HEAD carries a foreign llama-rag edit — amend would absorb it, the exact 2026-09-14 fragmentation trap); not pushed. |

**Foreign blocker (not mine, tracked for awareness):** evo-x2 eval fails `memory-watermark-audit` on **llama-embeddings** (MemoryHigh < 50% MemoryMax). HEAD (8a3a027f) carries a parallel session's llama-rag.nix edit that is visibly the same fix class (moving MemoryMax INTO `harden{}`) — they are MID-FLIGHT on it. I did not touch their file. This blocks every deploy until their fix lands. Question g#1.

---

## c) NOT STARTED (plan remainder, deliberate)

T7 (trace alert rules — owner-gated), T8 (log→trace correlation — upstream Go-repo work), T14 (enabled-but-inactive net), T16–T19 (logs-pillar depth + flm composite), T20 (time_series_v2), T21 (zero-series sweep), T22 (collector-config live-fire lint), T23 (severity panels), T24 (migrator guard), T25 (dashboard generator promotion), T27 (browser pass — blocked:user), T13.2/13.3 (continuous metric branch — owner decision row 102).

## d) TOTALLY FUCKED UP (own goals, all recovered)

1. **`rg -rln` twice** — `-r` is REPLACE-in-display; mangled output showed phantom `ln_some_avg10` metrics and an `ln_alert` gatus check; I briefly chased a "second dead emitter" that doesn't exist. Caught by reading the actual file. Lesson burned in: file-listing is `rg -ln`, never `-rln`.
2. **`serviceConfig = [ … ]` list shape** in git-lag-metrics (psi-metrics uses `lib.mkMerge [ … ]`) — my first eval failed on exactly this; fixed by cloning the established form. Should have opened the reference block BEFORE writing.
3. **A careless edit deleted the `timers.git-lag-metrics = {` opening line** (old_string swallowed it); repaired immediately from the tail view. Cost: one round-trip.
4. **Tracked-files trap**: first nix build of the new selftest check failed `cp: cannot stat … test-post-deploy-service-sanity.sh` — new files must be `git add`ed before any flake-source build (documented doctrine; still stepped on it). Fixed with stage + rebuild.
5. `PIPESTATUS` under mvdan/sh didn't yield a code once — worked around with `&& echo GREEN`. Minor.

## e) WHAT WE SHOULD IMPROVE (session-level reflections)

1. **Threshold-semantics bugs aren't statically lintable** — the PSI percent-vs-fraction class survived 8 days and a queued "wrong file" misdiagnosis. A fixture selftest pinning the KERNEL format (calm `some avg10 < 1` while thresholds must be integers ≥1) would have caught it at build time. Queued (f#30).
2. **Queue premise-check discipline worked, twice** — D1 ("deploy blocked") and D5 ("wrong file") were both STALE/WRONG premises, disproven by 10-minute probes before any code changed. The 2026-10-05 doctrine (live-verify before building) paid for itself exactly as designed; keep doing this first, always.
3. **The delta-blindness finding reshaped T5 mid-flight** (dashboard built on servicegraph-cumulative instead of spanmetrics) — pre-verifying EVERY panel query before writing JSON is what surfaced it. That trap (#1 in the plan's constraint library) is now empirically justified; consider promoting "temporality check" into the cheat-sheet permanently (done).
4. **Deploy batching under storms**: six tasks' verification is serially blocked on ONE deploy because I (correctly) refused to build during the battery — but that means close-out bookkeeping piles up. A standing "deploy-pending batch" section in the todo files would make the deferred state visible to other sessions. (Partial: this report's §b is that surface for now.)
5. **Gatus new-metric canaries conflict with §10** (chicken-and-egg hard-fail): the absence-proof `(X > N) or absent(X)` SigNoz rule pattern is the better tool — worth a conventions note in monitoring.md when T7/T11 docs land.

## f) NEXT (ranked, ≤50)

1. Resolve the llama-embeddings eval red with the owning session (or fix-forward on owner authority) — unblocks ALL deploys (g#1).
2. Deploy the P0 batch at the first PSI-calm window; `--keep-going` discipline; then post-deploy battery (f3–f11).
3. Verify T4 live: `node_psi_memory_alert` = 0 at calm memory; gatus "Memory Pressure" check green.
4. Verify T15 live: `signoz_traces_upstream_gaps` = 3 with budget 3, `over_threshold` = 0.
5. Verify T9 live: CPU Thermal Ceiling rule ACTIVE — **expect a true-positive FIRING** (98.6°C 30m-max this session); confirm Discord delivery.
6. Verify GPU rule: hwmon half alive on the c6-widened regex (query returns a series).
7. Verify T5/T6: provisioner output "OK 8 dashboards", zero FAILED lines; eyeball `systemnix-traces`.
8. Verify T11: `systemnix_git_ahead_by` present, `scrape_error 0`; synthetic test-fire both rules (temporarily cannot — absence branch fires naturally if textfile removed; document instead).
9. Verify T12: rule inactive at calm (increase[2h]=0), would-have-fired arithmetic already in the description.
10. First live §18 sweep run (CPU + journal legs) — expect PASS; watch for surprise hotloops (that's the point).
11. Close-out rows: monitoring.md 71, 76, 14, 101 + TODO_LIST:166 twin (edit both surfaces; prune to CHANGELOG).
12. CHANGELOG entry for the P0 batch ( PSI units fix, ratchet, traces dashboard, thermal/trip/git rules, §18, cheat-sheets).
13. Plan file §1 D-rows + status header sync (T1 verdicts, execution state).
14. Amend-forward my daemon-swept files into attributed commits (verify each batch's contents first; NEVER absorb the foreign llama-rag lines); push on owner ok.
15. Triage "Swap Usage Critical" firing (zram >80%? real condition vs stale).
16. T7: owner decision (g#3) then build p95/error-rate trace rules via mkRule.
17. T8: upstream brief for discordsync/dnsblockd (OTLP logs or slog bridge; their repos) — the 4/12.16M trace_id ratio is the baseline to move.
18. T14.4: `\x2d` label-escaping prerequisite check (whole-file rejection risk) before the inactive-net work.
19. T14.1–14.3: enabled-but-inactive metric + gatus check + stranded sweep.
20. T16: Caddy access.log filelog receiver + OTTL parse.
21. T17: ingestion-silence anomaly rule + journald cursor persistence (`file_storage`).
22. T18: coverage `reason` split (never-seen vs went-dark) + 6h dense budgets.
23. T19: flm crash-trigger composite (PMA 30s-band × coredumps).
24. T20: time_series_v2 empty — retention root-cause + repopulation verify.
25. T21: zero-series sweep (rules+dashboards vs store) as a flake check; triage findings.
26. T22: `signoz-collector-config-lint` live-fire flake check + runbook section.
27. T23: log severity-distribution panels.
28. T24: SigNoz migrator-gap guard.
29. T25: commit the dashboard generator + eval-time dashboard JSON lint.
30. **PSI kernel-percent fixture selftest** (pin `/proc/pressure` percent semantics vs emitter thresholds — the T4 class, forever).
31. GCP re-arm execution path if approved: sops key + `gcpMonitoring.enable=true` + deploy + `docs/services/signoz-gcp-monitoring.md` checklist.
32. GCP delete branch if preferred: `git rm dashboards/gcp.json` + etc entry + provisioner converge.
33. indexer-web spans stale 16.5h (coverage budget 26h) — triage before it pages.
34. dnsblockd-test ghost emitter (0.1 spans/h) — registry note or upstream cleanup.
35. hermes/papdashboard/pma upstream instrumentation briefs — close the last 3 gaps, ratchet budget 3→0.
36. Delta-blindness re-probe on the next signoz-src/collector bump (cheat-sheet one-liner).
37. GPU dashboard: add a chip-label-canary panel (chip drift visible on the wall, not just in a rule).
38. telemetry-coverage dashboard: gap-budget row now pinned at 3/3 — verify panel reflects it post-deploy.
39. 48h alert-noise audit after the new rules live — tune NOTHING without incident-derived justification (anti-tuning doctrine).
40. monitoring.md: conventions note for the `(X > N) or absent(X)` absence-proof rule pattern + the §10/gatus-canary chicken-and-egg.
41. Run shellcheck standalone on my two new .sh files if the daemon-swept commit bypassed the pre-commit leg (daemon-race lint-skip class).
42. Post-deploy re-run `scripts/negative-test-lints.sh` (dashboard-overlap + query-lint fixtures still green with the 8th dashboard).
43. Check daemon-vs-queue: TODO_LIST [ready] rows for this batch close in the same edit as library rows (no drift).
44. After T8 prototype lands: verify the UI log→trace pivot on a real line (8.5).
45. Renamer/gotenberg event-cadence spans: verify on next real work event (event-wiring honesty).
46. Consider `services.signoz-coverage` registry comment refresh ("4 remaining flips" → 3 gaps; comment predates ratchet).
47. FEATURES.md/docs-health pass for the traces dashboard + new rules once deployed.
48. Watch-note: confirm the fired CPU-thermal Discord notify actually DELIVERED (log line ≠ delivery — the 2026-09-30 class).
49. If PSI stays elevated: coordinate deploy window with the parallel session instead of racing (the freeze-#22 deploy-battery collision).
50. Housekeeping: /tmp/live_rules.json + scratch fixtures from this session are ephemeral — no repo residue (verified none tracked).

## g) QUESTIONS FOR THE OWNER (cannot resolve myself)

1. **llama-embeddings eval red** (memory-watermark-audit; a parallel session is mid-fix — their llama-rag edit landed beside my file in HEAD 8a3a027f): it blocks EVERY deploy including my verified batch. Wait for their session, or authorize me to finish the fix-forward with clear attribution?
2. **Deploy timing**: the batch is authoring-complete and lint-green; io PSI avg10 is 26.6% and falling (gate <20%). Deploy at the first calm window autonomously, or hold for your go? (`DEPLOY_FORCE_PRESSURE=1` precedent exists from the 01:51 train.)
3. **Two standing owner-gates from the plan**: (a) T7 trace alerting — page (Discord) or observational-only? (b) GCP disposition — re-arm (my recommendation, brief in the row) or delete `gcp.json`?

---

**Self-harvest compliance:** §e/f genuinely-new items landed at authoring time — PSI-percent fixture (f30), deploy-pending-batch visibility (e4, this report §b), llama-embeddings coordination (g1, deliberately NOT queued: foreign in-flight work, owner question is the right surface), canary-vs-§10 note (f40). Items f1–f14 are THIS batch's close-out obligations, owned by me next session; the rest map to existing plan/tracked rows (no duplicate rows created).
