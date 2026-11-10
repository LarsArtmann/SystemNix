# SUPERB execution: deploy chain, CI triage, pin bump — status & self-review

**Session:** continuation, 2026-11-10 00:12 → 01:11 CET (same agent session as the 00:01 report + the 00:12 SUPERB plan)
**Written:** 2026-11-10 01:11 CET
**Plan:** docs/planning/2026-11-10_00-12_SUPERB-offline-banner-legs-deploy.md (execution marker in header)
**Previous report:** docs/status/2026-11-10_00-01_offline-banner-independent-legs-phase-ladder-status.md

---

## 0. TL;DR

The offline-banner fix is **pushed** (`432fbaa` + CI fix `ade9779` + CI-caught stale-binding fix `7949237`), **workflow-lint is green for the first time ever** (the job shipped without a nix installer and has been exit-127 since its 2026-11-05 birth — my push's run proves the fix), the **SystemNix pin is bumped and fully eval-gated** (toplevel drv + full `nix flake check --no-build` rc=0 with the parallel lock-float sweep riding). **Deployment is correctly GATED**: (1) the parallel session is editing eval-relevant files RIGHT NOW (`system-health.nix` mtime <5 min at 01:11), and (2) CI's emulated-aarch64 `probe-transitions` leg is red — a CI-timing hazard (exact-count asserts on a 10× slower runner), x86_64 fully green. Two background gates finished green this hour: the SystemNix syntax walk and the offline-banner workflow-lint.

---

## a) FULLY DONE

1. **SUPERB plan written, committed, pushed** — `docs/planning/2026-11-10_00-12_SUPERB-offline-banner-legs-deploy.md`: Pareto 1/4/20/100 breakdown, 12 tasks (30–100 min) + 36 micro-tasks (≤12 min) in tables, mermaid execution graph, execution marker, six explicit Verschlimmbesser guards (no deploy mid-sweep; no config-hack mitigation; no reverts of the parallel session's bumps; drv-equality probe; anchor check). SystemNix `2bda05264` (with the 00:01 status report, pathspec-commit clean despite the foreign dirty tree).
2. **offline-banner feature pushed to GitHub** — `d9f6d6f..432fbaa` (the deploy chain's prerequisite; branch-protection push accepted).
3. **`workflow-lint` CI job FIXED** — diagnosed `nix: command not found` (exit 127): the job ran `nix shell` with **no nix installer step**, red since its first run (2026-11-05 wiring → red 11-06, red on every push since; the "immediately caught two findings" in the wiring notes were LOCAL runs — the CI job never executed its lint). Fix: added the SAME pinned `DeterminateSystems/nix-installer-action@v23` the nix-check job uses (minus the aarch64 binfmt conf this job doesn't need). **Proven green in CI**: ✓ installer, ✓ actionlint, ✓ zizmor in 20 s on my run — first green ever. `ade9779` pushed.
4. **CI caught a real production bug pre-deploy** (the gates have teeth, second round): the state write at the phase flip carried `phase:"degraded"` with `degradedVisible:false` — the computed-binding staleness again, this time in `emitState` where a single-shot state write does NOT self-heal until the next probe. Fixed properly: new `rawDownLegs()` helper; `onPhaseChanged` + `emitState` now compute legs/`degradedVisible` from RAW counters, never bindings (documented in the code with the CI provenance). Local probe-transitions green after the fix; pushed (`7949237`, daemon-swept message).
5. **Assert made race-proof**: the main-sequence `degradedVisible` assert now polls (state write is a spawned sh process that can lag the journal line — CI-proven).
6. **SystemNix pin bumped and double-gated**: `nix flake update offline-banner` → `ade9779` + `flake/expected-locks.nix` line updated; **toplevel eval green** (`nix eval …toplevel.drvPath` rc=0, drv `8j7sfw366x…`); **full `nix flake check --no-build` rc=0** with the pin riding the parallel session's committed lock sweep (`1242387e8`).
7. **Parallel-session choreography handled cleanly**: lock-float sweep detected live at 00:12 (12+ input bumps dirty), waited out, saw them commit (`1242387e8` ~00:25, then `1815374e1`, `96c2116d1`, `6bf36ca6f` continuing); my git index.lock collision (their process at 00:3x) handled by waiting, not deleting; my bump committed by the daemon into `4395859d9` — contents verified line-exact (my one-line pin + flake.lock node + their cv.nix, three files exactly as expected).
8. **CI failure archaeology**: prior master CI red (2026-11-06) triaged to the same workflow-lint 127 — infra, not code; my run then reproduced it, then my fix turned it green.
9. **Background gates disciplined**: capture-once-then-grep for the heavy flake check; quiescence poll loops logged per-round with timestamps.
10. **Plan discipline**: plan committed BEFORE execution (step 6 of the user template), execution marker written into the plan header, M-numbers tracked against the micro-task table.

## b) PARTIALLY DONE

1. **THE DEPLOY (Phase D, T1) is NOT done** — correctly gated twice over: (a) the parallel session is editing `modules/nixos/services/system-health.nix` with mtime <5 min at 01:11 (eval-relevant → quiescence fails; a deploy now would ride their mid-edit state — the exact gen-949 class the plan's guard #1 forbids); (b) CI aarch64 red (below). The fix is one quiescence window + one command away.
2. **CI aarch64 `probe-transitions` red** — x86_64 100 % green (all checks), `aarch64-linux.probe-transitions` fails on the emulated runner: the log tail shows the link-cue instance with leg counters already at 23–26 (`reason=link failures=24/2`…) — the fresh-instance exact-count asserts (`failures=1/2`, `failures=2/2`, `leg down leg=tcp failures=1/2`) violate the repo's OWN CI-timing doctrine (exact counter matches only at deterministic positions from a controlled start; a slow emulated runner crosses 1/2 before the harness greps). Diagnosis ~90 % (the exact FAIL line extraction from the CI log API kept coming up empty — the last-25-lines dump shows the climbing counters, the FAIL line itself sits above the cut). Fix designed, not yet applied: convert fresh-instance exact-count asserts to transition regexes per doctrine.
3. **Live verification battery (Phase E, M13–M18) not started** — blocked by the deploy.
4. **Post-deploy close-out + `docs/agents/desktop.md` sync (M19–M20)** — blocked by E.
5. **Hardening lane (M21–M30)** — untouched so far: rendered-netProbe execution gate, vm-smoke legs/phase assert, waybar fabricated-state tests, sticky-dwell test, link-scenario re-anchor, FEATURES rows 65/68, AGENTS lessons, upstream TODO_LIST harvest, upstream status snapshot, website sync.
6. **offline-banner master still CI-red on aarch64** (work: b2) — everything else green including the never-before-green workflow-lint.

## c) NOT STARTED

1. Deploy + anchor check + live evening-flap observation (the actual user-visible payoff).
2. Gateway-side new-flow ICMP policing diagnosis (owner/router-gated, `[watch]` row).
3. IPv6 legs design note; ledger `phase` field decision; downgrade-compat sweep; SystemNix state-file consumer sweep (M32–M35).
4. Post-green-days closure of the monitoring `[watch]` row (M36).
5. The three owner questions from the 00:01 report remain unanswered (bump-staging preference, dwell stickiness, commit-sanctioning) — the SUPERB template answered the commit/push one implicitly (pushes executed).

## d) TOTALLY FUCKED UP (own errors this stretch)

1. **My probe-transitions scenarios violate the CI-timing doctrine they were written under** — I used exact-count asserts (`failures=1/2`) for fresh instances that are only deterministic on a FAST runner; the emulated aarch64 CI crosses 1/2 before the harness greps. The repo's own AGENTS documents this exact class ("exact counter matches only at deterministic positions — a clean start is one, regex transitions past that") and I still wrote three such asserts. x86_64 green masked it until push. Fix designed (transition regexes), not yet applied. This is the difference between "tested where I sit" and "tested where it runs".
2. **The stale-binding bug needed CI to catch what my local runs could not** — the `emitState` mid-cascade inconsistent write (phase fresh, degradedVisible stale in the SAME JSON) passed locally twice (write-lag window too narrow locally) and failed on CI. My earlier decision to leave `emitState` binding-based ("self-heals on next probe") was wrong for single-shot consumers reading between probes — the waybar consumer polls at 5 s and would have read the lie. Root-fixed now, but the initial call was a judged-risk that turned out wrong.
3. **My pin bump got daemon-swept into a heuristic commit** (`4395859d9`) because the other session's git process collided with my commit (index.lock) and the daemon committed my staged files while I waited. Contents verified correct, but the detailed commit message I wrote is now stranded in this session's history instead of the repo's. An amend was impossible (the other session had committed on top; no rebases without need). Lesson: in this repo, commit the moment staging is done — the daemon's 10-minute clock is shorter than a multi-gate verification arc.
4. **`gh` API log extraction fumbled** — three different invocations (`--log-failed`, `--log | grep`, `jobs/<id>/logs`) to find one FAIL line; the first two returned truncated/empty views of the aarch64 dump. Should have gone straight to the jobs API log endpoint pattern that worked.
5. **A wasted CI cycle**: pushed the stale-binding fix BEFORE running render-smoke locally on the same edit (it passed, but the order was verification-after-push — the exact "launch background jobs only after the edit pass is final" discipline inverted for CI).
6. **Missed pre-reading the upstream repo's CI workflow state**: the workflow-lint job has been red since 2026-11-05 and I only noticed via the run list AFTER pushing — a pre-push `gh run list` would have surfaced a red master pipeline before I added to it.

## e) WHAT WE SHOULD IMPROVE

1. **CI-timing doctrine enforcement**: add a self-check to the probe-transitions harness itself — no exact `failures=N/2` greps outside the controlled-start positions; convert to `assert_journal_re` transitions. Or: gate a marker comment per assert declaring "deterministic position" and grep-check THAT in shell-content.
2. **State-file writes: raw counters everywhere** (done for legs/visibility; `phase`/`active`/`since` still read bindings — one more audit pass to finish the raw sweep so NO single-shot reader can ever see a mixed-generation snapshot).
3. **Pre-push ritual for this repo**: `gh run list --limit 3` before every push — a red master pipeline must be triaged before adding commits to it.
4. **Commit-the-moment-you-stage** in daemon-swept repos: staging + long verification arcs = guaranteed sweep. The message quality lives in the plan doc when the sweep wins.
5. **The parallel-session playbook worked and should be codified**: detect (dirty lock files) → plan around it (gates in the graph) → wait for their commit → re-read + content-pin → pathspec-commit only own files. It is currently spread across AGENTS + my plan; one runbook section would make it repeatable.
6. **CI log archaeology**: the jobs-API log endpoint was the working pattern; note it (or a tiny `scripts/ci-failed-log.sh` wrapper) to stop re-deriving it under pressure.
7. **The workflow-lint class**: a job that "wired and immediately caught findings" but never ran green in CI — the findings were local. Gate: every new CI job's FIRST run must be verified green (or red-for-the-right-reason) before its wiring note claims success.

## f) NEXT (ordered; ≤50)

1. Fix aarch64 `probe-transitions`: exact-count fresh-instance asserts → transition regexes (M03-completion; blocks green CI) `[ready]`.
2. Push + verify CI fully green (both jobs, both systems) `[ready after 1]`.
3. Quiescence window for the deploy: parallel session idle + tree clean ≥4×60 s + eval-relevant mtimes >5 min `[blocked:parallel-session]`.
4. `scripts/pre-deploy-check.sh` → `nix run .#deploy` (background, nh) `[ready after 3]`.
5. Process-tree-empty wait → anchor check (`readlink /run/current-system` == newest `system-N-link`) `[ready after 4]`.
6. Live banner battery: journal tokens (`banner phase=`, `leg down/ok`), state-file shape, `niri msg layers`, degraded strip during the evening-flap window, sound silence `[ready after 5]`.
7. Close-out: monitoring `[watch]` row + `docs/agents/desktop.md` §Offline banner contract sync `[ready after 6]`.
8. SystemNix CHANGELOG row for the bump (the sweep commit carries the change; the doc row is owed) `[ready]`.
9. Rendered-netProbe execution gate in offline-banner checks (sh -n + stubbed-env deterministic run) `[ready]`.
10. vm-smoke: state-file `phase`/`legs` asserts + local `nix build .#vm-smoke` run `[ready]`.
11. Waybar fabricated-state tests for degraded/`degradedVisible`/pre-`phase` files `[ready]`.
12. Sticky-dwell (`degradedDwellSeconds=0`) probe-transitions scenario `[ready]`.
13. Link-cue scenario re-anchor (control-net ok before the link instance — premise currently drifted) `[ready]`.
14. Finish the raw-counter sweep in `emitState` (`phase`/`active`/`since` bindings → raw) `[ready]`.
15. FEATURES rows 65/68 + ledger `probeFailures` semantics sentence `[ready]`.
16. offline-banner AGENTS.md: binding-staleness hard rule + capture-then-assert pixel rule + "verify a new CI job's first run" `[ready]`.
17. offline-banner TODO_LIST harvest (owed rows from the plan) `[ready]`.
18. offline-banner docs/status snapshot for the 2026-11-09/10 arc `[ready]`.
19. Website phase-ladder + options sync `[ready]`.
20. Check the dprint.json zombie resurrected by the 29-file docs sweep (commit `6d044c9`) — delete again or adopt `.buildflow.yml` (D4, owner) `[blocked:decision]`.
21. Verify the 29-file docs sweep (another session's docs-health pass?) contents & intent — attribute before any docs rework `[blocked:attribution]`.
22. CI: watch the emulated-aarch64 run times after the regex fix; tighten poll budgets if still flaky `[watch]`.
23. Ledger `phase` field decision row `[decision]`.
24. IPv6 legs design note (v6 literals, ahostsv6; now spans 3 legs) `[decision]`.
25. Downgrade-compat: waybar contrib on pre-`phase` state files `[ready]`.
26. SystemNix consumer sweep: grep for state-file consumers before relying on new keys `[ready]`.
27. Per-leg timeout option (`probeTimeoutSeconds` shared today) `[decision]`.
28. tcpProbePort fallback chain (53 → 443) `[decision]`.
29. README comparison-table row "Says which leg is down" `[ready]`.
30. Demo-mode phase semantics assert (demo reports offline phase — intended?) `[decision]`.
31. module-contract: `OFFLINE_BANNER_DEGRADED_DWELL` ≥0 eval assertion `[nice-to-have]`.
32. probe-transitions: `failuresToShow=1` scenario `[nice-to-have]`.
33. render-smoke: degraded-slimmer-than-offline height ratio assert `[nice-to-have]`.
34. Gateway-side ICMP capture runbook (router access; OpenWrt plan linkage) `[blocked:owner]`.
35. Evening-window re-verification AFTER deploy: flap continues but banner stays hidden/degraded `[ready after deploy]`.
36. Post-green-days: close the monitoring `[watch]` row with evidence `[watch]`.
37. Attribution of `modules/nixos/services/cv.nix` + `system-health.nix` edits (other session's CV work riding the tree) — flag remains open `[watch]`.
38. SystemNix TODO_LIST: my §f items were deliberately not harvested (push-gated/upstream) — revisit after deploy for the now-`[ready]` ones `[ready after deploy]`.
39. Codify the parallel-session playbook as a CONTRIBUTING section `[ready]`.
40. scripts/ci-failed-log.sh wrapper (jobs-API log endpoint pattern) `[nice-to-have]`.
41. Consider required-check implications: branch protection expects "Checks" — confirm the aarch64 red does not block future owner pushes `[ready]`.
42. Add push-safety note to offline-banner AGENTS: `gh run list` pre-push ritual `[ready]`.
43. Probe-transitions: assert the degraded strip text token (`DEGRADED`) reaches the journal via a debug line or accept pixel-only `[nice-to-have]`.
44. Document `probeFailures` (all-leg events) in README observability section `[ready]`.
45. vm-smoke promotion into `checks` (D1 decision) — rides owner `[decision]`.
46. Consider bumping `failuresToShow` eval ceiling docs (≤10) for ladder interactions `[nice-to-have]`.
47. Audit other SystemNix Quickshell second-instance services for the same binding-staleness pattern (wifi-failover QML shares the exclusion-list mirror) `[ready]`.
48. Sync the exclusion-list mirror comment (offline-banner module.nix ↔ wifi-failover.nix) — verify still true after legs refactor `[ready]`.
49. CHANGELOG: reference the CI-proven rawDownLegs incident as a Fixed entry `[ready]`.
50. Retire `~/.cache/ob-debug` harness or promote it to `scripts/` as the local pixel-capture helper `[nice-to-have]`.

**Harvest disposition:** none queued into SystemNix `TODO_LIST.md` yet — 3–7 are deploy-gated (blocked:deploy), 1–2 + 9–29 are upstream-side (offline-banner's queue owns them; the harvest is item 17), 34/36 owner-gated. Deliberate, recorded here per house rule.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy timing & ride-along:** the parallel session is mid-edit on eval-relevant files right now (01:11), and my deploy would CARRY their committed lock sweep (sops-nix, home-manager, homebrew-cask, nur, signoz-src, go-* bumps) in one generation jump. Do you want the banner deploy fired in the next quiescence window tonight (carrying their sweep), or shall I hold Phase D until you've blessed the sweep-riding generation?
2. **aarch64 CI policy:** relax the fresh-instance exact-count asserts to transition regexes (doctrine-consistent, slightly weaker guarantees, green CI) — or keep strict counts and mark emulated-aarch64 `probe-transitions` as an allowed-flake gate? My recommendation: relax to regexes; say the word if you want strictness preserved.
3. **The 29-file docs sweep + dprint.json zombie** in offline-banner (commit `6d044c9`, daemon-authored, includes the BuildFlow-generated `dprint.json` your AGENTS says must not persist): re-delete `dprint.json` and treat the sweep as noise, or finally adopt the `.buildflow.yml` that stops the resurrection permanently (D4 decision)?

---

**Evidence anchors:** offline-banner runs 42719228872 (workflow-lint 127 reproduced), 42721014377 (workflow-lint ✓ 20 s post-fix; nix-check aarch64 ✗), 42721634091 (same split; zizmor clean on the workflow incl. my installer step); pushes `432fbaa`, `ade9779`, `7949237`; SystemNix pushes `2bda05264`; pin bump swept `4395859d9` (verified line-exact); eval `8j7sfw366x…-nixos-system-evo-x2-26.11.20261105.f9a75f4.drv` rc=0; full `nix flake check --no-build` rc=0 (~01:0x); quiescence: sweep committed `1242387e8` 00:25, but `system-health.nix` mtime <5 min at 01:11 (gate open); parallel session commits `1242387e8`/`1815374e1`/`96c2116d1`/`6bf36ca6f`; local pixel harness `~/.cache/ob-debug/`.
