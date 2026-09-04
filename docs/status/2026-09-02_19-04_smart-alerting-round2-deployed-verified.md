# Status: Smarter-Alerting Round 2 — Deployed + Live-Verified (2026-09-02 19:04 CEST)

**Session scope:** continuation of the MEMORY EMERGENCY overhaul — review pass over the whole guard/sev1/overlay alerting stack, closing every gap found (churn, restore cap, per-key cooldowns, page-duration measurement, zone attribution), extending both VM regression tests, deploying, and live-verifying. Includes what happened in the ~90 minutes after deploy.

---

## Executive Summary

Round 1 (17:29 report) fixed the three bugs that made a healthy machine fullscreen-page for hours. Round 2 asked the harder question: **what else in this alerting stack is stupid?** The review pass found five more gaps and closed all of them:

1. **Churn was invisible** — trip→restore→consumer-re-wakes-flm→re-trip (~40 min cycles, measured live this morning) looked identical to a single bounded trip. Now: `memory_emergency_guard_trips_last_hour` gauge + TRIP CHURN context appended to the trip page itself.
2. **Unlimited self-healing was an I/O churn engine** — every restore re-arms the 21.6 GB cold load. Now: `maxRestoresPerDay` (default 3) — past the cap the socket stays DOWN with `restore_capped 1`, and a new **FLM RESTORE CAPPED** notify carries the manual restart path (without it, flm would silently stay unusable after the trip page clears).
3. **One global notify epoch cross-suppressed unrelated conditions** — a ZRAM notify could silence a later SYSTEM MONITORING STALE notify within 30 min. Now: per-key epoch files (md5 of the alert-set key), pruned automatically.
4. **Page duration was never measured** — the incident's core complaint was duration, and no metric captured it. Now: `sev1_bridge_page_active_seconds` + `sev1_bridge_page_last_duration_seconds`.
5. **Forensics needed journal digging** — now: per-zone trip counters (`zone1..5_trips_total`), `restored_total`, zone attribution in the trip log line.

**Deployed at ~18:45, and the live system immediately validated the design.** At 19:04 the box shows: zram 97% fill + 25.8% avail → **zero memory alerts** (the morning's false-page class is now structurally silent); a genuinely stale system-health collector → **notify tier only, `page_alerts_active 0`, no fullscreen overlay** — the exact movie-night anti-pattern now degrades to one self-expiring notification. No trips, socket up, cap untouched.

Also verified during review (no change needed): overlay TTL is correctly 120 s in the unit; the Gatus "ZRAM Fill" check, system-health threshold, and the deploy pressure gate all already use combined zram+margin semantics — zram fill alone blocks/pages nothing anywhere in the stack.

---

## Timeline (this round)

| Time | Event |
|------|-------|
| 17:29 | Round-1 report committed; user ordered continued execution |
| 17:35-17:50 | Review pass: overlay TTL / Gatus / system-health / deploy gate — all already correct; gaps list produced (churn, cap, per-key, duration, zones) |
| 17:50-18:10 | Guard module: zone counters, trip history, restore budget; Bridge: per-key cooldown, churn context, capped condition, duration metrics |
| 18:10-18:30 | Test extensions; SC2050 shellcheck failure (constant `[ 2 -gt 0 ]`) found + fixed; guard test failed once on my own reset-vs-counter interaction → restructured the cap scenario to burn the budget realistically |
| 18:30-18:40 | Both VM tests green; `nix flake check --no-build` passed |
| ~18:45 | **Deployed.** Smoke: 84 PASS / 1 FAIL (Pocket ID SQLITE_BUSY — activation-storm transient) |
| 18:50-19:04 | Live verification: all new metrics flowing; alert file cleared; socket up; no trip. Pocket ID self-healed (0 errors in last 5 min, healthz 204). 19:04: a REAL stale-collector notify appeared — correctly notify-tier, no overlay |

---

## a) FULLY DONE

1. **Review pass over the entire alerting stack** (guard script, bridge script, overlay QML + unit, Gatus checks, system-health thresholds, deploy pressure gate) — every consumer of zram fill % and every page path audited; 5 gaps found, 3 already-correct surfaces confirmed correct with evidence.
2. **Guard: churn instrumentation** — `trip-history` state file (pruned to 1 h), `memory_emergency_guard_trips_last_hour` gauge, per-zone counters `zone1..5_trips_total`, `restored_total`, zone index in the action log line.
3. **Guard: daily restore budget** — `maxRestoresPerDay` option (default 3, 0 = unlimited), `restores-YYYYMMDD` state files, restore refused past cap with a loud journal line, `restore_capped` gauge, socket stays down by design.
4. **Bridge: FLM RESTORE CAPPED condition** (notify tier, manual `systemctl start fastflowlm.socket` path in the detail) — covers the post-trip-page window where flm would otherwise be silently unusable.
5. **Bridge: TRIP CHURN context** — trip page detail appends the re-wake-loop warning when trips_last_hour ≥ 2.
6. **Bridge: per-key notify cooldown** — md5(alert-set-key) epoch files, >2× cooldown pruning loop (pure bash, no new deps), cross-suppression impossible.
7. **Bridge: page-duration metrics** — page-start state file, running `page_active_seconds`, frozen `page_last_duration_seconds` on clear.
8. **Both VM tests extended and green** — guard: `maxRestoresPerDay = 2`, reset_state wipes new state files, post-reset counter asserts, a realistic cap-burn scenario (trip→restore→trip→restore→trip→REFUSED); sev1: churn fixture/scenario 9c, capped fixture/scenario 11, per-key delivery proof (zram notify after stale notify must NOT be suppressed), page-duration asserts, old global-epoch assertion migrated.
9. **Deployed + live-verified** — all new guard metrics present in the textfile prom (24 matching lines), bridge page-duration metrics live, no alert file, socket up, `last_trip_recent 0`, `trips_last_hour 0`, `restore_capped 0`.
10. **AGENTS.md** — smarter-alerting additions documented (per-key cooldown, duration metrics, churn, cap, capped condition).
11. **Post-deploy smoke triage** — the 1 FAIL (Pocket ID SQLITE_BUSY) root-attributed to the activation restart storm (6 errors in the 30-min window, 0 in the last 5 min, healthz answers 204) — the AGENTS-documented transient class, not a regression.

## b) PARTIALLY DONE

1. **Churn/capped visibility beyond the first notification** — the metrics exist but NO standing Gatus/Discord checks consume `trips_last_hour ≥ 2` or `restore_capped 1` yet. The in-page context and one-shot notify cover the acute moment; a persistent channel does not exist. (Deliberate scope cut this round — flagged, not forgotten.)
2. **zram 50% resize** — still pending the REBOOT (config deployed in round 1; the live device is still 28.2 GiB reading 97%).
3. **Page-duration consumers** — metrics emitted; no dashboard or alert threshold wired yet.
4. **The 19:04 stale system-health collector** — the notify correctly fired (new tier working), but the underlying staleness (1025 s old, likely the documented I/O-timeout collector class) is uninvestigated. It self-resolves or recurs; either way it is now visible withoutspamming.

## c) NOT STARTED

1. Reboot to activate zram `memoryPercent = 50` (~47 GiB) + post-reboot verification of the rendered device size.
2. Gatus checks for `trips_last_hour` and `restore_capped` (standing Discord channel for churn/capped — see b1).
3. Per-cgroup swap/zram attribution ("who is inside the 47 GiB") — still nothing attributes swapped pages to services.
4. Tonight's flm re-cold-load watch: the socket is up and the enricher/PMA WILL reconnect eventually — the first cold load tonight is the churn loop's first live test under the cap.
5. TODO_LIST harvest of either status report's (f) lists (parallel session owns TODO_LIST.md right now).
6. SigNoz dashboard panels for the new guard/bridge metrics.
7. Pure-script (non-QEMU) test runner for the guard/bridge bash logic — alert-logic iterations still cost full VM boots.

## d) TOTALLY FUCKED UP (this round, brutal)

1. **The JSON-backslash root cause.** My tool-call layer eats one backslash level, so every `"\\n"` I write in a patch script arrives as a real newline. I hit this class THREE times in round 1 and STILL wrote round-2 patches with raw backslash escapes — two more failed anchor attempts before I finally systematized the fix (build patterns with `chr(92)` placeholders). The correct move was obvious after the first failure; I paid for it six times total across the session.
2. **Anchors written from memory instead of grepped.** Two patch failures this round (`9b` anchor, `6b-cap` label) were both me "remembering" text I myself had written minutes earlier instead of copy-verifying. Grep-first costs 5 seconds; guessing costs a round trip.
3. **I broke my own test with my own helper.** Extending `reset_state()` to wipe the new state files invalidated the counter assertions that followed it — I added the wipe without re-deriving downstream expectations, and the VM test rightly caught it. The restructure (burn the budget across resets) is better than the original, but the original shouldn't have passed my review.
4. **A failed drv that later "builds" cost three tool calls of confusion.** The auto-commit daemon's pre-commit `nix flake check` had built and attic-pushed the same drv mid-session, so my failing build suddenly succeeded via substitution. I should have recognized the daemon-interplay immediately (documented pattern in this repo) instead of re-running builds blind.
5. **Deployed with 1 smoke FAIL accepted in-flight.** The switch had already landed when the smoke reported; I triaged the Pocket ID failure AFTER. Right call (it was the known transient class) but the honest sequencing is: I shipped first, verified after, and would have rolled forward either way — say that plainly rather than dress it up.

## e) WHAT WE SHOULD IMPROVE

1. **Alert-review doctrine**: every alerting condition needs three properties checked at authoring time — lifecycle (state-based vs window-based), tier (page/notify/Discord-only), and blast radius (what else pages for the same cliff). Rounds 1+2 were manual audits; this should be a checklist in docs/CONTRIBUTING.md for any new sev1/gatus condition.
2. **Write tooling for VM-test logic, not more VM tests.** The bridge/guard are bash; a pure-bash harness with fake prom fixtures would run in milliseconds instead of minutes and would have caught all three logic bugs this round without QEMU.
3. **Patch discipline on this box**: never compose multi-line patches with raw escapes through the tool layer — use the placeholder technique or the edit tool with a fresh view, always.
4. **The metric-emission convention is drifting**: guard/bridge/system-health each hand-roll prom parsing, state files, and emission blocks. A tiny shared bash lib would prevent the next divergence bug (e.g. one collector gaining per-key cooldowns while another keeps a global).
5. **Deploy-time awareness of the smoke's side effects**: the post-deploy flm probe cold-pins 21.6 GB into whatever RAM is free. Today it fit; at 10% avail it would trip the guard mid-smoke and fail the deploy noisily. The check should either skip when the guard metric says margins are thin, or the risk should be documented in the runbook.
6. **Verify daemon/parallel-session interplay by default**: any "it failed, now it works" in nix builds on this box should first suspect the attic substituter + the daemon's parallel flake check — make that the first hypothesis, not the fourth.

## Self-Review (the 11 questions, this round)

1. **Forgot?** Standing Gatus checks for the two new gauges; the reboot; TODO_LIST harvest; verification of whether the deploy smoke actually pinned flm's model (unverified — the idle TTL will unload it within the hour either way).
2. **Stupid things we do anyway?** QEMU-booting to test bash string handling; hand-rolled prom plumbing per collector; deploying into an activation storm and treating a red smoke as a footnote.
3. **Done better?** Grep anchors before every patch; design the test scenarios' counter arithmetic BEFORE extending shared helpers; triage smoke failures before the deploy summary prints.
4. **Still improve?** Section e, all six.
5. **Lied?** No. Uncertainty flagged: whether the smoke pinned flm's model (unverified); whether tonight's first consumer reconnect re-trips the churn loop (predicted likely, bounded by the cap if so).
6. **Less stupid?** The chr(92) placeholder + grep-first rules are now practiced habits; the next step is mechanizing them (e) 2-3.
7. **Ghost systems?** None created. One candidate flagged for integration: the page-duration metrics currently have zero consumers — they earn their keep the moment a dashboard or alert uses them, otherwise they are prom clutter (f-item 6).
8. **Scope creep trap?** Held: no new Gatus checks (flagged only), no dashboard work, no collector refactor — the five gaps plus tests, nothing else.
9. **Removed something useful?** The global notify epoch — replaced by per-key files; the VM test proves same-key flapping still suppresses while cross-key delivers.
10. **Split brains?** None new. Watch item: the guard's capped log line and the bridge's capped detail both hardcode the manual restart command — two places to update if the socket unit ever renames (cosmetic risk, noted).
11. **Tests?** Both VM suites green including the new scenarios; the one failure this round was a real bug (my reset interaction) caught exactly as designed. Remaining gap: iteration speed (e) 2.

---

## f) Next up to 50 (brainstorm for docs-health HARVEST — most are ROADMAP fuel)

**Activate & verify**
1. Reboot → verify zram device ≈ 46.9 GiB (`memoryPercent = 50` base = post-carveout MemTotal).
2. Post-reboot: confirm steady-state fill reads ~55-60% and nothing pages on it.
3. Tonight: watch the first flm consumer reconnect — confirm either no re-trip or the cap bounds the loop.
4. Verify the deploy smoke's model pin either drained via idle TTL or is pinned knowingly.
5. Re-run post-deploy-check in an hour: expect the Pocket ID FAIL gone.

**Standing visibility for the new gauges**
6. Gatus check: `memory_emergency_guard_trips_last_hour ≥ 2` → Discord (churn is a standing condition, not just in-page context).
7. Gatus check: `memory_emergency_guard_restore_capped 1` → Discord (persistent channel behind the one-shot notify).
8. SigNoz dashboard panels: guard zone counters, restored_total, trips_last_hour, page-duration.
9. Alert on `sev1_bridge_page_active_seconds` sustained > 15 min (a page that lives too long IS the fatigue complaint — measure the measure).
10. Wire the 19:04-class stale-collector condition into a recurrence counter (how often does system-health go stale under I/O pressure?).

**Root-cause follow-ups**
11. Investigate the 19:04 system-health staleness (1025 s old — collector timeout class or wedge?).
12. Investigate what consumed ~47 GB in the 16:35→17:15 window this afternoon (census metrics + journals).
13. Per-cgroup swap/zram attribution metric — answer "who is inside the 28/47 GiB" from a prom read.
14. Confirm PapDashboard enricher behavior during the capped state (flm down for hours: failure spam into ingest? alert storm?).
15. Confirm PMA Commit Health doesn't page during a multi-hour capped flm outage (heuristic fallback threshold vs outage length).

**Test & tooling**
16. Pure-bash test harness for guard/bridge scripts (fake proms, no QEMU) — minutes → milliseconds.
17. VM test: empty `socketUnits` → `sacrifice_socket_active 1` semantics (uncovered edge).
18. VM test: per-key notify pruning loop (old epoch files get deleted).
19. Property-style test for the alert-set key (title ordering must not matter).
20. Shared bash lib for prom_value/file_age/state-file helpers across the three collectors.
21. Add SC2050-style constant-comparison to the pre-commit grep guards (the shellcheck gate is build-time only).
22. Codify in AGENTS: never compose multi-line patches through raw backslash escapes — placeholder technique or fresh-view edit.
23. Codify in AGENTS: grep-verify every patch anchor before applying.
24. VM test: overlay QML behavior is untested by construction (no display in VM) — document the manual verification step for overlay changes.

**Threshold & sizing follow-ups**
25. Post-reboot: re-validate Zone 2/3 zram thresholds (92%/80%) against the 47 GiB device semantics.
26. Post-reboot: Gatus "ZRAM Fill" 90% → 42 GiB swapped — confirm that rarity is the intent.
27. Re-benchmark zstd L1 vs L3 at the observed 2.6x ratio (decision was calibrated at 3.2x).
28. Document the zram sizing doctrine (fill-% is only meaningful with headroom; generous sizing is free) in a stable doc beyond AGENTS.
29. Consider explicit `zramSwap.memoryMax` — make the physical-RAM bound a decision, not an accident.

**Docs**
30. CHANGELOG entry for round 2 (churn, cap, per-key cooldown, duration metrics).
31. Annotate both 2026-09-02 status reports after reboot + first-churn-cycle outcomes (docs-health ANNOTATE).
32. docs/services/ runbook: the full sev1 page lifecycle + guard state machine (AGENTS-only knowledge today).
33. docs/CONTRIBUTING.md: the alert-authoring checklist from e1.
34. HARVEST both reports' (f) lists into TODO_LIST.md once the parallel session releases it.
35. Update `system_zram_swap_fill_percent` docs to the new steady-state expectation (~55-60% post-reboot).

**Adjacent, noticed this session (not mine)**
36. Parallel session's InboxClean Paperless archiving landed (cd797970) — verify its opt-in gate doesn't interact with the paperless module's env wiring.
37. smart-audio.nix was modified + activated by my deploy (parallel session's work rode the switch) — confirm their change is intentional and stable.
38. Mail-relay backlog plan (parallel session's 17:20 planning doc) — coordinate the Resend key go-live, it is still a placeholder.
39. Samsung SSD role execution (parallel session) — the /nix migration will interact with the reboot in item 1; sequence them deliberately.
40. fish startup 362 ms WARN (smoke) — 80 ms over threshold, low priority but it regressed from somewhere.
41. quickshell journal has 1 error line in the last hour (smoke WARN) — identify which surface.

**Longer-term (roadmap fuel)**
42. flm v1.0.3 kernel-7.2.2 compatibility retest (AGENTS hold) — bundle with the item-1 reboot.
43. systemd-oomd MemoryPressureLimit re-evaluation under the new zram-heavy steady state.
44. PSI `full avg10` as an additional guard input.
45. Episodic-bucket (Zone 5) decay-rate review — is −1/run still right at 30 s cadence post-resize?
46. Consider a "quiet hours" tier for notify conditions (movie-night doctrine generalization).
47. Bridge: persist an alert-set history file (timestamped title sets) for fatigue analytics.
48. Early-warning integration: PapDashboard ingest of guard trip/restore/capped events for the lifecycle UI.
49. Evaluate moving the guard's 30 s cadence to a socket-activated or PSI-triggered model (30 s timer is blind-window compromise, not ideal).
50. Retrospective: annotate this report once items 1-7 have real outcomes (docs-health ANNOTATE).

---

## g) Questions I cannot answer myself

1. **Reboot window:** the zram 47 GiB resize (round-1 config) is still waiting on a reboot, and item 42 (flm/kernel retest) bundles naturally with it. When do you want it — tonight, and should I sequence it against the parallel session's Samsung-/nix-migration plans?
2. **Restore budget number:** is 3 restores/day the right ceiling for flm (each one is a 21.6 GB cold load), or do you want a different default — or 0 (unlimited) with the churn alert as the only control?
3. **Standing churn/capped alerts:** do you want the Gatus/Discord checks for `trips_last_hour ≥ 2` and `restore_capped 1` (items 6-7) now, or is the in-page context + one-shot notification enough visibility for you?

---

## Evidence

- VM tests: `vm-test-run-memory-emergency-guard` `/nix/store/0dxjsrbdvkiv1g29vy9qvkgsrddb7lda-...` ✅ (incl. cap-burn scenario), `vm-test-run-sev1-escalation` `/nix/store/q6j27qily8ca0dg9m3hqlwkkjyq9k5zk-...` ✅ (incl. churn, capped, per-key, page-metrics).
- `nix flake check --no-build`: all checks passed.
- Deploy: switch landed ~18:45; smoke 84 PASS / 1 FAIL (Pocket ID SQLITE_BUSY, activation-storm transient — self-healed, healthz 204 at 19:00).
- Live at 19:04: guard prom carries all new gauges; bridge page-duration metrics live; `sev1_bridge_page_alerts_active 0`; alert file = SYSTEM MONITORING STALE at **notify** tier (no overlay); guard: zram 97% fill + 25.8% avail + zero trips + cap untouched.
- Commits: daemon-heuristic batches `dedcaab9`, `b8a1a03f` carry this round's code (mixed with parallel sessions' InboxClean commit `cd797970` per the shared-tree convention).

**NEXT: WAITING FOR INSTRUCTIONS.**
