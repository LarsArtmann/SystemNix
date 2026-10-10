# Status: memory-throttle runtime sweep (§17) + watermark-audit HM scope + negative-test CI leg

**Stamp:** 2026-10-10 05:24 CEST · **Session:** continuation of the 2026-10-09 22:20 watermark-trap audit report (explicit WAIT state) — the owner's "break into steps / execute / verify / keep going" mandate lifted the wait; the three open decision points (§g of that report) were resolved by documented defaults.
**Surfaces touched:** `scripts/lib/memory-throttle-sweep.sh` (new), `scripts/test-post-deploy-memory-throttle.sh` (new), `scripts/post-deploy-check.sh` (§17 leg + source), `modules/nixos/services/memory-watermark-audit.nix` (HM scope), `scripts/negative-test-lints.sh` (new `memory/hm-user-trap` case), `.github/workflows/negative-tests.yml` (new), `flake/parts/apps.nix` + `flake/parts/checks/selftests.nix` (packaging/selftest), TODO_LIST.md, docs/todo/{monitoring,stability,pipeline}.md, AGENTS.md, CHANGELOG.md. All daemon-swept (last verified HEAD `fe866b0c`; tree clean at `57fa3452`).
**Verification state at close:** full negative-test suite **33/33 PASS** (was 32; +1 new case) · `nix flake check --no-build` **green** · packaged post-deploy-check app **builds** (writeShellApplication shellcheck included) · selftest check derivation **green** · env-override functional probe **green** · my todo rows **gate-clean** (the gate's FAIL is entirely the parallel session's in-flight rows — see §d/§e).

---

## a) FULLY DONE

1. **f.1 — Runtime memory-throttle sweep (post-deploy §17), WARN-advisory.** New fixture-testable lib (`scripts/lib/memory-throttle-sweep.sh`, parameterized slice-dir + threshold, sourced like pressure-report.sh), wired as `=== §17 Runtime memory throttle sweep ===` after §16, packaged into the app's lib staging (`apps.nix`), fixture selftest (6 cases: calm→PASS, loud→per-unit WARN, small→compact advisory line, ≥-boundary, mixed, missing-dir→SKIP) wired as the `post-deploy-memory-throttle-selftest` flake check. Standalone shellcheck + writeShellApplication shellcheck + `bash -n` + packaged-app build all clean. Decision: **WARN not FAIL** — counters reset on unit restart, so a hard gate is blind to exactly the units a deploy just changed, and a pre-existing throttle is not the deploy's regression (recorded on docs/todo/monitoring.md; owner-flippable).
2. **THE LIVE DISCOVERY — the sweep's first run answered the owner's original question beyond llama-chat: 10 units are actively throttling right now.** mr-sync-dashboard 149k · inboxclean-web 136k · clickhouse 94k · papdashboard 44k · discordsync 25k · geometrikks 11k · project-discovery-daemon 11.9k · nix-daemon 7.5k · bank-sync 5.2k · signoz-collector 3.1k (events since unit start). ALL have coherent High/Max pairs — the eval audit correctly passed them; this is the **budget-insufficiency / designed-throttle class** the eval gate structurally cannot see. Triage queued `[ready]`.
3. **f.2 — Watermark audit extended to home-manager user services.** Third assertion over `config.home-manager.users.*.systemd.user.services` via a dedicated `trapHM` (HM carries unit settings under `Service`, not `serviceConfig`; `or { }` keeps the audit importable on HM-less rpi3-dns — **both hosts' toplevel evals green**, so zero false positives); offenders prefixed `user:unit`. Pinned by the new `memory/hm-user-trap` harness case: an incoherent pair injected into the REAL HM config (`platforms/nixos/users/home.nix`, go-cqrs-nightly-bench) throws the audit marker — with zero live HM knobs, a mutation was the only way to prove the leg fires. Memory group 3/3.
4. **f.3 — negative-test harness wired into CI.** `.github/workflows/negative-tests.yml`: FULL unfiltered suite, nightly 05:15 UTC (offset after go-deps-audit 04:30) + paths-gated pushes (harness + scripts/lib + modules/lib/systems/platforms/tests + flake.nix/lock), 90m timeout, action pins + the 5-key private-input auth block copied verbatim from go-deps-audit.yml (the harness's toplevel evals force every private git+ssh input). YAML-valid + **actionlint-clean**; pins are the only two used repo-wide (verified by sort -u across all workflows).
5. **Decision defaults recorded (owner-flippable)** — monitoring.md: WARN-advisory for the sweep; stability.md: single 50% tripwire + allowUnits kept (per-class budgets = YAGNI until a real KV-growth class exists).
6. **Docs sync, no drift:** 3 queue rows `[x]`-closed with evidence (TODO_LIST 229/282/741), 4 library rows closed/updated (monitoring 101-102, stability 190-191, pipeline 431), new triage row + 2 self-harvested rows (below), AGENTS.md prevention table (CI row + Post-deploy row), CHANGELOG entry.
7. **Threshold env plumbing** — `SYSTEMNIX_THROTTLE_WARN_THRESHOLD` genuinely works now (functional probe: threshold 10000 → count 5000 correctly lands on the advisory line), documented in the lib header, selftest + shellcheck + check derivation re-verified after the fix.
8. **Full suite 33/33** — the `apply_mutations`/`eval_case` refactor from last session still holds; 9 pristine controls green including the evo-x2 toplevel eval with the HM extension live.

## b) PARTIALLY DONE

1. **Throttle observability is deploy-time only.** §17 fires during post-deploy checks; between deploys a chronic throttler (the mr-sync-dashboard 149k class) is invisible AGAIN — the exact "never know" window the owner complained about. Continuous textfile metric + SigNoz rule = queued `[ready]`, not built (system-health.nix's collector already loops `allMonitoredServices` over memory.events, so the wiring cost is small).
2. **CI leg is actionlint-clean but has ZERO real GitHub-runner runs.** First run may surface: cold-store suite timing vs the 90m timeout, secret wiring (`NIX_GITHUB_RO_TOKEN` exists for the other workflows), rsync availability (present on ubuntu-latest), private-input eval flakiness. Should be `workflow_dispatch`-ed right after the next push and watched once end-to-end.
3. **Throttle triage (the 10 units) is queued, not started.** Also open: the counts are cumulative-since-unit-start and the overnight 2026-10-09→10 IO storm is baked in — discordsync's documented hot loop (121% CPU, 640 journal-lines/min) may inflate its 25k; attribution needs per-unit memory.current-vs-Max-vs-working-set work, not just the counters.
4. **§17 coexists with the parallel session's storm-mode rewrite of post-deploy-check.sh** (their 03:53 pass) — edits compose (build green) but a live full-smoke run carrying BOTH changes hasn't happened yet (deploy-gated).
5. **Sweep scope symmetry is open:** the eval gate now covers HM user-unit CONFIG, but the runtime sweep reads system.slice only — HM units throttle under user.slice cgroups and §17 never sees them. Queued `[ready]`.

## c) NOT STARTED (noticed this session, deliberately queued)

1. Triage of the 10 throttled units (queued, see b.3).
2. Continuous `high`-counter textfile metric + SigNoz rule (queued, see b.1).
3. HM runtime sweep leg — user.slice glob in the sweep lib (queued, see b.5).
4. Fix the mislabeled `system_service_memory_events_high` gauge (system-health.nix:1122 is a MAX-counter threshold wearing a throttle-class name; rename needs a SigNoz consumer check first). Queued.
5. Data-driven validation of the 1000 threshold (currently a judgment call: llama-chat 46k vs startup blips in the tens).
6. SigNoz rule on `system_service_memory_events_max` (the OOM-class counter has a metric but no rule owner decision).
7. Storm-aware wording for §17 WARNs (a throttled unit under an IO storm may be victim, not cause — triage guidance belongs in the message).
8. Everything in the parallel sessions' active queues (storm-mode closeout rows, storage watch-row batch, crm OIDC deploy chain) — **not mine to touch**; the todo gate's current FAIL is entirely theirs.

## d) TOTALLY FUCKED UP

1. **Fabricated-claim bug, mine, caught in this self-review:** I wrote "threshold 1000 env-overridable (`SYSTEMNIX_THROTTLE_WARN_THRESHOLD`)" into TWO queue rows while the function's default was a hardcoded `1000` that never read the env var. The exact class this repo documents (2026-09-13 commit-message evidence rule; verify-external-claims). **Fixed + verified** (lib default now `${2:-${SYSTEMNIX_THROTTLE_WARN_THRESHOLD:-1000}}`, functional probe proves the override, header documents it, selftest + shellcheck + check derivation re-run green). The queue-row claims are now true.
2. **First sweep version stripped `.service` from unit names** — caught by my own fixture test before anything shipped (which is the fixture test doing its job), but it shows the first draft was written before thinking about what grep-targets the WARN line needs.
3. **One mangled edit on TODO_LIST.md during self-harvest:** a prefix anchor split the triage row's title from its body and produced a duplicate title line. Caught immediately by re-reading, repaired, dedup-verified (1× each row). No other surface affected.
4. **Near-miss, not shipped:** the 10-unit discovery came from an *ad-hoc* live probe I ran "while I was there" — it was NOT a planned verification step. Without it, §17 ships unproven and the session's headline finding doesn't exist. That's luck, not process.
5. Nothing broken in prod, no deploy executed, no foreign work touched (the crm.nix vendorHash re-pin and the storm-mode script pass were correctly left to their owner session and are swept/committed).

## e) WHAT WE SHOULD IMPROVE

1. **Claims about code must be grep-verified against the code AT WRITING TIME**, not remembered from intent — the env-var bug cost a post-hoc fix cycle and would have cost a dispatch cycle if a queue harvester had picked it up. This is the repo's own rule; I re-violated it in miniature.
2. **Live probes should be a PLANNED verification step for any runtime check** — "run the thing against the real box" earned the session's most important output; make it a named step in the implementation order, not an afterthought.
3. **Design eval gates and runtime nets together** — f.2 (HM config) and f.1 (system-slice runtime) shipped as separate scopes and the coverage asymmetry (HM runtime units) only surfaced in self-review. One scope-table (config-layer × runtime-layer × unit-class) at design time would have caught it.
4. **Prefix-anchored edits on fast-moving shared files are dangerous** — the TODO_LIST mangling happened because I anchored on a row title instead of the full unique row text. Full-row anchors only, especially in this tree.
5. **The fixture test caught the unit-name bug on its first run** — this validates the repo's lib+fixture+selftest pattern; keep extracting legs into libs even when the logic looks trivial.
6. **Cross-session awareness:** the 03:53 storm-mode pass on the same script I was editing was invisible until a tool rejection forced a re-read. A cheap `git log --since` on target files before editing (content-pin discipline) would surface it proactively instead of reactively.

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT (brainstorm, sorted by impact; `[H]` = harvested into TODO_LIST + library this session, `[Q]` = already queued from earlier sessions, `[R]` = report-only)

1. `[H]` Triage the 10 runtime-throttled units (memory.current vs MemoryMax vs working set; fix undersized, justify designed).
2. `[H]` Continuous throttle observability: `high`-counter textfile metric + SigNoz rule + allowlist for designed throttle-only units.
3. `[H]` HM runtime sweep leg (user.slice) so the runtime net matches the eval gate's scope.
4. `[H]` Fix the mislabeled `system_service_memory_events_high` gauge (rename or emit a real `high` alongside).
5. `[R]` Watch negative-tests.yml' first real CI run end-to-end (workflow_dispatch after next push).
6. `[R]` Validate/retune the 1000 WARN threshold with counter-age data.
7. `[Q]` Owner decisions standing: sweep hard-gate vs WARN (default WARN); 50% tripwire vs per-class budgets (default kept).
8. `[Q]` catalog eval warning: 19 integration subdomains without catalog entries (f.4 of the 22-20 report).
9. `[R]` §17 storm-aware WARN wording (victim-vs-cause note under IO storms).
10. `[Q]` §11 tree-mutation tripwire + shim-drop lock-rev stamp (pipeline, from the cqrs-lint FOD session).
11. `[Q]` go-cqrs-lite upstream paste→push→re-lock→drop (upstream).
12. `[Q]` dead-guard-lint v2: cover `[[ "$var" == ... ]]` guard forms.
13. `[Q]` Add or de-reference the nonexistent `caddy-mutant` negative-test case.
14. `[Q]` deploy-restart-audit extendModules sweep (provisioner-loop members, tq-bootstrap first).
15. `[Q]` Fix `\x2d` label escaping in the system-health textfile writer (whole-prom rejection class).
16. `[Q]` Gatus canary: system_health series presence (phantom-metric pattern).
17. `[Q]` Log→trace correlation for the span-emitting Go fleet (4 of 12.16M lines carry trace_id).
18. `[Q]` GCP dashboard disposition (re-arm receiver vs delete 10 dead panels).
19. `[Q]` Fix tq-agent-pool post-deploy-check detection (pool active but check says NOT).
20. `[Q]` Confirm gatus shows forgejo red (designed-down must be loud).
21. `[Q]` Attribute the sustained overnight IO storm (~50% some avg10 for 4+ h).
22. `[Q]` Identify the consumer re-waking FastFlowLM after every guard restore (13 trips/hr).
23. `[Q]` tq-agent-pool guard coverage (ioChurnUnits membership or IO tier — owner policy).
24. `[Q]` thermal-pstate-guard second throttle rung + measurable post-deploy criteria.
25. `[Q]` Smoke guard: per-service journal-rate + sustained-CPU sanity (the discordsync hot-loop class).
26. `[Q]` Physical cooling inspection — STILL gates all heavy builds (8 freezes taken on it).
27. `[Q]` `/data/docker` (~15.5 GB) owner reclaim decision (live du reads 0 — reconcile the claim).
28. `[Q]` `/data` usage alarm at ~85% + trim the dual watch rows.
29. `[Q]` `/data/gcs-staging` (24G) still-needed owner decision.
30. `[Q]` buildcache-gc observability (`_last_success` metric + Discord alert on watermark nukes).
31. `[Q]` Eval audit: reject Exec/redirects into secret-looking paths without UMask 0077 (restic 0644 class).
32. `[Q]` `/data/ai` 459G breakdown + `/data/tmp-crush-test`, `/data/tmp-bench`, `/data/cache` residue verification.
33. `[R]` negative-tests.yml: split into `CASES=` lanes (controls+memory fast lane) if 90m proves tight.
34. `[R]` Nix store caching for the CI harness (cold runs currently re-fetch every input).
35. `[R]` Verify the 5 `NIX_DEPLOY_KEY_*` secrets + `NIX_GITHUB_RO_TOKEN` are actually exposed to the new workflow (repo settings check — owner-gated).
36. `[R]` Add `memory.peak` to the triage toolbox (working-set evidence without restart).
37. `[R]` Post-triage: runbook entries for units with deliberately tight budgets (docs/services/*).
38. `[R]` One-line §17 pointer in docs/agents/monitoring.md (textfile-collector routing).
39. `[R]` Consider a WARN-baseline analog to the fail-baseline (chronic WARNs currently reprint every deploy — by design, but noisy once triage lands).
40. `[R]` SigNoz rule on `system_service_memory_events_max` (OOM-class has a metric, no alert owner).
41. `[R]` Prune `[x]` DONE rows from TODO_LIST to CHANGELOG on the next docs-health pass (queue is accreting strikethrough rows).
42. `[R]` Watch the parallel session close its storm-mode + storage watch-row todo-gate FAILs (not mine).
43. `[R]` `user@1000.service` app.slice glob edge cases when the HM sweep leg lands (nested cgroup depth).
44. `[R]` Consider surfacing §17 results as a textfile metric instead of only smoke output (bridges 2 ↔ 4).
45. `[R]` Flake-check skip reason for aarch64-darwin is documented — nothing to do; drop from list if stale next pass.
46. `[R]` Post-deploy smoke full co-run carrying §17 + storm-mode together (first deploy after this lands).
47. `[R]` CHANGELOG: link the §17 entry to the triage outcome once it lands (close the loop).
48. `[R]` Sweep lib: unit→cgroup path printed in WARNs already absolute — consider adding `systemctl show -p MemoryMax` one-liner to the message for instant context.
49. `[R]` Route the "coherent-but-thrashing" class into docs/agents/stability.md's gotcha list (config-coherent ≠ budget-sufficient).
50. `[R]` Re-check counter semantics for oneshot units (dead-cgroup GC resets) so triage doesn't misread short-lived units.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Do the two defaulted decisions stand?** Sweep = WARN-advisory (not a hard deploy gate), and watermark policy = single 50% tripwire (not per-class budgets). If you want either flipped, it's a small diff — but I won't know a hard gate is wanted until the first false-blocked deploy annoys you.
2. **Which of the 10 throttled units have budgets you set DELIBERATELY?** I can measure which are undersized (memory.current pinned at MemoryMax + high counter growth), but I can't know intent — e.g., is clickhouse's 94k on a ~4G ceiling "designed squeeze" or "forgot to raise it with the data growth"? A "these N are deliberate" list turns the triage from investigation into a fix batch.
3. **Priority: continuous throttle observability now, or only after the triage?** Building the textfile metric + SigNoz rule before triage means alerting on 10 known-noisy units (alarm fatigue until allowlisted); after triage it's clean but the blind window persists meanwhile. Your call on which pain to prefer.

---

*Self-harvest at authoring time: §f items 1-4 landed in TODO_LIST.md + docs/todo/monitoring.md during this session (triage, continuous observability, HM runtime sweep, mislabeled gauge); §g = the standing decision rows. Everything else `[R]` is deliberately report-only (ROADMAP fuel / gated on items 1-2 / owner-gated), per the harvest contract.*
*Report format: `.md` at the user's explicit path instruction — overrides the status-report skill's HTML default for this report only (same as the 2026-10-09 22-20 report).*
