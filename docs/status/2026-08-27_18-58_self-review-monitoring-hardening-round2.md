# SELF-REVIEW + STATUS: Monitoring Hardening Round 2 (Lint Layer + Wedge Forensics)

**Date:** 2026-08-27 18:58 · **Session:** ~17:25–18:15 work + this review · **Predecessor:** `2026-08-27_17-25_signoz-lint-layer-wedge-forensics-round2.md`
**Mode:** self-review demanded post-completion. No new research beyond claim-verification noted inside.

---

## a) What was FULLY done and verified this session

1. **`signoz-query-lint` flake check** (`flake.nix`) — 4 eval-time trap classes (`job=` matchers, `metric_sum/_count/_bucket` underscore suffixes, bare `up{service_name=` without `count(...) or vector(0)`, dead-metric blocklist) over `_signoz-alerts.nix` (comment-stripped) + all 5 dashboards. Verified: green on tree via `nix build .#checks.x86_64-linux.signoz-query-lint` (exit code captured via redirect, not pipe); mutation-tested THROUGH nix stdenv (`writeText`/`linkFarm` store fixtures + `builtins.replaceStrings` path substitution via `--impure --expr`) — 5 correct FAILs on mutated fixtures, comment correctly ignored, correct forms pass.
2. **nullglob phantom-green in lint v1 — found, root-caused, fixed, documented.** stdenv `shopt -s nullglob` + unquoted `$strip` command-variable expansion silently deleted the quoted grep pattern → every trap read empty input → check passed guarding nothing. Fixed via function indirection (`stream() { ...; }`). AGENTS.md gotcha added (Nix & Nixpkgs section).
3. **post-deploy-check: `signoz-provision.service` Result assertion** — closes the rule-count phantom-green (stale rules count green while provisioner failed).
4. **post-deploy-check: >24h-firing alert surfacing** via `/api/v1/alerts` `startsAt`; jq filter unit-tested on synthetic ages; live PASS seen in deploy output ("no SigNoz alert firing longer than 24h" — correct: the current firing alert is <24h old).
5. **pre-deploy-check §1b: untracked-files warning** under `modules/`+`platforms/` (tracked-files trap); grep logic tested standalone.
6. **dnsblockd wedge forensics stack:** `scripts/dnsblockd-goroutine-dump.sh` runbook (bash -n + shellcheck-clean via writeShellApplication, binary preflight); `GOTRACEBACK=all` in dns-blocker.nix — **deployed-unit-verified** (`/etc/systemd/system/dnsblockd.service` contains it).
7. **`system_dnsblockd_metrics_fresh` textfile gauge** (5s curl probe, 200→1, emitted only when probed) + **Gatus "DNS Blocker Stats API Fresh"** (anchored pat forms). Live: metric=1; endpoint first cycle fail-closed (metric not yet scraped at 17:57), green at 18:02. **No spurious Discord alert** — mkHttpCheck `failure-threshold = 3`, one failure < threshold; journal confirms no dispatch for `infrastructure_dns-blocker-stats-api-fresh`.
8. **GPU dashboard:** duplicate "Temperature by Card" panel → "Temperature Sources (hwmon vs ClickHouse)" two-series overlay; query live-verified (both series 39°C) BEFORE deploy; provisioner converged: "OK 5 dashboards provisioned, exact desired set / 0 errors".
9. **Q1/Q2/Q3 decided + documented** (runbook=capture-then-restart; accept deploy-window transients; keep complementary layering).
10. **AGENTS.md 3 updates** (wedge-layering, lint reference in the phantom-class gotcha, nullglob lesson) + prior session report + this one.
11. **Deployed via `nix run .#deploy`** after two instructive aborts (SC2001 shellcheck; new-metric bootstrap window via `KNOWN_NEW_METRICS`, entry retired post-verification). flake check + fmt green.

## b) PARTIALLY done (honest scope edges)

1. **Runbook never executed** — syntax/shellcheck only (needs root). Wedge-confirm, SIGQUIT, recovery paths all untested in anger.
2. **Lint trap-3 is line-based** — a multi-line nix query string escapes it; `or vector(0)` anywhere-on-line is loose.
3. **CI coverage gap (verified during this review):** pre-commit runs FULL `nix flake check` (executes the lint), but **CI runs `--no-build`** (evaluates only) — a `--no-verify` commit or foreign-machine commit would pass CI with a dead-at-runtime lint. Pre-existing repo property (gatus-pattern-lint shares it), but my check inherits it.
4. **Long-firing WARN increments the SKIP counter** (post-deploy-check has a WARN counter; cosmetic miscount).
5. **Provisioner-check PASS line never seen with own eyes** — evidence is the provisioner journal (converged, 0 errors) + the check's presence in the deploy run; the specific PASS line scrolled above the captured tail.

## c) NOT started (from the ranked list; reasons logged)

1. Wedge-rule Discord delivery proof — needs controlled dnsblockd stats stop (root, live resolver); declined autonomously (risk/value).
2. emeet/niri gate metric flip verification — needs a graphical session.
3. DAS physical recovery, nixpkgs go_1_26 ≥ 1.26.6 override drop — external context.

## d) What I totally fucked up

1. **Lint v1 shipped as a phantom green and I initially TRUSTED it.** `nix build` exit 0 → "TREE EXIT=0" — measured through `| tail`, i.e. **tail's exit code, not nix's** (the exact anti-pattern this repo documents). Only the standalone-bash cross-check exposed it. Had I not been paranoid, a dead detector would be deployed and _documented as the cure for the class it can't catch_ — the deepest irony of the session.
2. **Sandbox /tmp trap hit TWICE** (sed-substituted /tmp fixture paths, then a `cp`-from-/tmp fixture derivation) before landing the store-fixture pattern. Same lesson, two rounds.
3. **SC2001 deploy abort** — shipped a `| sed` into a writeShellApplication without local shellcheck (none on PATH; noted it and deployed anyway). Pre-commit caught it; cost one deploy cycle.
4. Minor: claimed "deployed green" for the provisioner check without seeing its output line (see b.5).

## e) What I would do differently / could still improve

1. **CI step building the lint checks** (`nix build .#checks.x86_64-linux.gatus-pattern-lint signoz-query-lint …`) — closes the --no-build execution gap for ALL trap lints.
2. Lint should parse nix query strings properly (extract `query = "..."` values) — kills the line-based limitations.
3. Automated zero-series sweep: script diffing every metric name referenced in rules/dashboards vs `signoz_metrics.distributed_time_series_v4` (the blocklist then self-maintains).
4. Generalize the provisioner Result assertion to ALL deploy.sh provisioners (pocket-id-provision, forgejo-oidc-setup, … — same phantom-green class).
5. Runbook `--dry-run` mode + one controlled rehearsal.
6. WARN-counter fix; explicit dashboard-count assertion.
7. Deploy ordering: restart system-health collector before gatus's first post-deploy cycle (avoids the one fail-closed event).
8. Persist the nix-native negative-test harness as a repo script (currently only described in the round-2 report).
9. GOTRACEBACK=all for the other Go daemons (discordsync, monitor365, browser-history) — cheap crash forensics.

## f) FULL RANKED LIST — next 50 (NEW discoveries first)

1. CI: execute trap-lint derivations (e.1) — highest leverage, 15 min.
2. Diagnose `website-deploy-monitor.service` FAILED unit (critical firing since 14:43, other session's — see Q3).
3. DAS cable swap per `scripts/das-link-recovery-check.sh` — unblocks the 8 post-deploy FAILs (Immich/Bank-Sync/Attic/Paperless).
4. Wedge-rule Discord delivery proof (controlled stop, root) — see Q2.
5. emeet/niri gate verification on next graphical login.
6. GOTRACEBACK=all sweep over Go daemons (e.9).
7. Provisioner-Result assertion generalization (e.4).
8. Zero-series sweep automation (e.3).
9. Lint v2: proper string extraction (e.2).
10. nullglob audit: `grep -rn '\$[a-z]* "\?' flake.nix`-style scan for unquoted command-variable expansion in ALL runCommand checks.
11. Caddy deploy-restart Discord ping observed 17:59 — Q2 data point; revisit suppression if annoying (see Q1).
12. post-deploy-check WARN counter fix (b.4).
13. Dashboard-count assertion (e.6).
14. Collector-before-gatus deploy ordering (e.7).
15. Negative-test harness as repo script (e.8).
16. SigNoz-side rule for `system_dnsblockd_metrics_fresh` (currently Gatus-only).
17. Temp-source drift ALERT (hwmon vs ClickHouse >10°C) — the new panel is visual-only.
18. Dead-metric blocklist growth documented in CONTRIBUTING.md (verify command + when to add).
19. gatus-pattern-lint trailing-comment edge case (inline `# comment` after code defeats the line-strip; known 2026-08-07, still open).
20. KNOWN_NEW_METRICS churn: auto-derive "new metrics in this deploy" from the gatus-config diff instead of manual allowlist.
21. Post-deploy route-policy assertion (v1 API list non-empty per ruleId — the restart-wipes-policies class).
22. system-health gauge: age of oldest firing SigNoz alert (trend visibility beyond the WARN line).
23. Lint: cover `service_name` on non-up metrics (other self-reported labels — currently unlinted).
24. fish startup 1091 ms (WARN threshold 200 ms — seen in post-deploy output, degrading).
25. quickshell 1 error line/h (post-deploy WARN — triage).
26. Runbook dry-run (e.5).
27. VM/regression test for the freshness-gauge emission shape (consider — collector is simple).
28. docs/services/dnsblockd.md runbook page linking the dump script.
29. Read-only zombie ClickHouse tables: human DROP decision (~10 GiB, AGENTS-documented).
30. btrbk `/data` EIO inode repair (TODO_LIST P0, pre-existing).
31. nixpkgs go_1_26 ≥ 1.26.6 → drop CV tarball override (drop-list).
32. Attic 502s during builds (cache.home.lan down with DAS) — note or gate.
33. chown-vs-bind-audit promotion WARN→fail (its own comment says "after one clean cycle" — cycles passed).
34. Dashboard-panel-removal layout-$ref lesson → make the provisioner's failure message name the orphaned $ref explicitly (it failed unhelpfully once already).
35. Post-deploy: assert `system_signoz_alert_rules_total` equals the nix rule count (exact, not >15).
36. gatus-config: consider `client.timeout` audit vs the new 5s probe semantics (probe timeout < scrape interval hygiene).
37. Two-source panel UI check (legend rendering with two series) — cosmetic.
38. Deploy-window gatus "maintenance window" feasibility study (alternative to Q1 suppression).
39. website-deploy-monitor's own Gatus checks (other session) — overlap/triage review once landed.
40. Signoz `Telemetry Export Failures` regex-form suffixes: lint the `=~` dotted regex variant for typos too.
41. Lint: reject `job` in `by (job)` groupings too (same phantom class, unmatchable).
42. Commit-attribution check once the daemon batches this session with inboxclean (AGENTS concurrent rule).
43. docs-health sweep: annotate/retire stale items in the 08-22→08-27 status chain.
44. emeet gate HELP text vs SigNoz rule description drift check (cosmetic consistency).
45. Q2 noise ledger: count deploy-window TRIGGERED alerts per deploy in post-deploy-check output (one grep on the gatus journal).
46. Consider `RestartMinDelaySec`-style anti-churn for dnsblockd (restart-storm insurance) — evaluate against its SLA.
47. Pocket ID SMTP (Resend key still dead per incident table — verify current state, likely still broken).
48. `system_health.prom` size trend (adding gauges each session — cheap now, watch cardinality).
49. Pre-deploy-check §12 "binary not built yet" warnings for unit-script binaries — make them post-build re-verified (they warn every deploy).
50. Revisit Q1/Q2/Q3 decisions after one week of deploy noise data.

## g) Questions I cannot figure out myself (max 3)

1. **Deploy-window noise tolerance:** Caddy fired a real Discord "down" ping during tonight's deploy restart (17:59, self-resolved). I decided Q2 = accept. If these pings annoy you, say so and I'll build suppression (gatus maintenance window around `nh os switch`, or is-active-gated restart ordering) — I cannot know your noise tolerance.
2. **Wedge-rule delivery proof:** proving the "DNS Blocker Stats API Wedged" rule delivers to Discord requires deliberately stopping dnsblockd's stats listener on the LIVE resolver (root; DNS itself stays up; monitoring gap minutes). Approve a controlled test window, or leave it unproven until the next organic wedge?
3. **`website-deploy-monitor.service` ownership:** failed unit, critical firing since 14:43, shipped by the concurrent session (commit 6b6f0bbe). I left it untouched per concurrent-session rules. Should I take over diagnosis, or is the owning session active on it?

---

**WAITING for instructions.** No further work will be started until answers/direction arrive.
