# SigNoz Trace-Coverage Audit — Session Status & Brutal Self-Review

**Date:** 2026-08-31 21:33 CEST
**Trigger:** User: "Why does SigNoz ONLY know about 6 services over the last month!? Like we don't have a proper system to make sure we actually register ALL my Services FULLY with SigNoz!?!"
**State at report time:** deployed, smoke 83/0 green, collector live, 6 tracked upstream gaps.

---

## The Answer to the Original Question

SigNoz's **Services page is trace-driven**: a service appears there ONLY if its binary actively pushes OTLP spans. The journald logs pipeline covers 80+ services and the prometheus receiver scrapes 9 jobs — both invisible on `/services`. ClickHouse ground truth: exactly 6 services **ever** sent spans all-time (cv-application, crush-daily, browser-history, discordsync, file-and-image-renamer, gotenberg — `signoz_traces.distributed_signoz_index_v3`). The collector itself was healthy (0 failed/refused spans). Every other gap was per-binary:

| Service | Env var set? | Instrumentation reality | Class |
|---|---|---|---|
| dnsblockd | no (config-based) | FULL span instrumentation upstream, `otlp_endpoint` YAML key never set → dark. Enabling it exposed a **latent upstream bug**: exporter omits `WithInsecure()` → every export died `https://localhost:4318 … server gave HTTP response to HTTPS client` | config gap + upstream bug |
| bank-sync | no | `cqrsotel.Setup` wired for stdout/noop ONLY — no OTLP path | upstream gap (small) |
| overview | yes | `telemetry.SetupFromEnv` runs (journal: "OTel tracing enabled") but **ZERO `tracer.Start` sites** — perfect noop | upstream gap |
| projects-management-automation | yes | same class as overview | upstream gap |
| papdashboard | yes | OTel METRICS only (prometheus registry), no trace SDK | upstream gap |
| hermes | yes | Python; opentelemetry-sdk not wired into the agent runtime | upstream gap |
| fastflowlm | yes | prebuilt binary, no OTel at all — env var was a pure lie | removed |

---

## a) FULLY DONE (verified live)

1. **Forensics**: ClickHouse queries for traces (all-time per-service), logs (80+ service names, 7d), metrics store schema (`samples_v4` + `time_series_v4` + fingerprint join), collector self-metrics (`otelcol_*`: 0 failed spans → pipeline healthy, pushers missing).
2. **`modules/nixos/services/signoz-coverage.nix`** — the "proper system":
   - Registry `services.signoz-coverage.expected` keyed by systemd unit; `wiring = "env" | "config" | "upstream"`; `maxAgeHours` (26h dense, 720h event-driven).
   - **Eval-time assertions BOTH ways** (forward: wiring="env" ⇒ unit carries `OTEL_EXPORTER_OTLP_ENDPOINT` (non-empty, mkForce ""-proof); reverse: ANY unit with that var must be a registry key or in `untrackedOtelUnits`). Both **negative-tested live** via throwaway `extendModules` evals (tree untouched) — both fired with correct messages.
   - **Runtime collector** (`signoz-coverage-metrics`, 5-min timer): reads ClickHouse DIRECTLY (gatus-sqlite doctrine), emits `signoz_traces_expected/reporting/last_span_age_seconds/missing/upstream_gaps`, `signoz_logs_pipeline_age_seconds/stale`, `signoz_coverage_scrape_errors`. Fail-closed: query failure writes `scrape_errors 1` + `missing = enforced_total`. Boot retry (3×20s) for CH metadata loading. Live-tested manually pre-deploy (0.3s runtime, 288ms CPU).
3. **dnsblockd `otlp_endpoint`** config key set in dns-blocker.nix (live: "OTLP trace export enabled" in journal).
4. **fastflowlm noop env var removed** (documented in-module why).
5. **bank-sync**: env wired in SystemNix + **upstream OTLP support added** (`cmd/bank-sync/tracing.go`, DiscordSync pattern, endpoint > stdout > noop precedence) + **3 new tests** (`tracing_test.go`, all green, full suite green).
6. **dnsblockd upstream fix**: scheme-aware transport (`https://` keeps TLS, else `WithInsecure()`) in `internal/otel/otel.go`; builds + `internal/otel` tests green.
7. **Gatus checks**: "SigNoz Traces Coverage" + "SigNoz Logs Pipeline Fresh" — anchored `pat(*\n<metric> *)` forms, presence + nonzero-value checks.
8. **SigNoz alert rules** (self-watching): Trace Coverage Missing (critical), Coverage Collector Errors (warning), Logs Pipeline Stale — provisioned with route policies (journal-verified "Policy unchanged: SigNoz Trace Coverage Missing").
9. **otel-endpoint-audit.nix**: bank-sync (`http-host-port`) + gotenberg (`http-url`) expectations added.
10. **pre-deploy-check.sh §10**: extractor now catches the ANCHORED `pat(*\n<metric>)` form (was blind to it — my new checks AND the concurrent session's user-units check were invisible to phantom validation); KNOWN_NEW_METRICS extended.
11. **AGENTS.md**: new coverage-audit gotcha bullet (incl. the WithInsecure catch + the exit-in-redirect-block lesson); "Adding a Service" step 10 now mandates registry registration.
12. **TODO_LIST.md**: P1 entry tracking all 6 upstream gaps + flip instructions.
13. **3 deploys** (interleaved with a concurrent session): final state **PASS 83 / FAIL 0 / SKIP 4**, `signoz_traces_missing 0`, `upstream_gaps 6`, `scrape_errors 0`, `logs_pipeline_stale 0`, `system_signoz_alert_rules_healthy 1`.
14. **Concurrent-session cooperation**: unblocked the other session's deploy (their `discordsync_turso_local_only_mode` was the phantom-metric fail; metric verified to exist upstream → KNOWN_NEW_METRICS entry), waited out their activation lock instead of force-racing.

## b) PARTIALLY DONE

1. **dnsblockd traces**: config key LIVE, upstream fix APPLIED LOCALLY (builds+tests green) — but **not pushed/tagged** (I don't push without instruction), so the deployed binary still has the WithInsecure bug; registry temporarily `wiring = "upstream"` (gap-counted, not paging). Needs: push + tag + `nix flake lock --update-input dnsblockd` (+ possible vendorHash refresh) + flip to `"config"`.
2. **bank-sync traces**: env + upstream code + tests done — same push/tag/bump/flip gap (`wiring = "upstream"` until then).
3. **The transient "1 FAIL" in the first two post-deploy smokes was never root-caused** — it went green on the third run. Most plausible: post-switch timing (coverage `.prom` file not yet written when the smoke probed node-exporter, since the collector is timer-driven with up to 5-min first-run delay) or the flm cold-load timeout under 66-77% IO pressure. Treated as resolved-by-green, not as understood. (Improvement item below fixes the likely cause structurally.)
4. **Registry completeness**: 13 units registered. Not registered (deliberate, documented): monitor365-server (disabled; re-enabling will TRIP the reverse assertion — intended guardrail), docker containers (env not eval-visible, same known limitation as otel-endpoint-audit).

## c) NOT STARTED (known, tracked, deliberately deferred)

1. **overview span instrumentation** (HTTP middleware + core ops span sites) — upstream.
2. **projects-management-automation span instrumentation** — upstream, same class.
3. **papdashboard trace SDK + span sites** — upstream (metrics-only today).
4. **hermes Python OTel wiring** — upstream pip extra exists, not enabled.
5. **SigNoz dashboard panel** for `signoz_traces_*` metrics (alerting exists; visualization doesn't).
6. **Metrics-side coverage**: papdashboard's own `/metrics` is scraped by NOTHING (Gatus pats its health endpoint only); forgejo metrics unscraped (token-gated); paperless-ai/immich internal metrics unscraped. The coverage audit covers traces + logs pipeline, NOT per-job scrape freshness.
7. **VM test** for the coverage module (eval assertions are negative-tested via extendModules; a `tests/test-signoz-coverage.nix` with mock CH does not exist).
8. **docs/services/ runbook** for the coverage system (module header + AGENTS.md carry the knowledge; no dedicated doc).

## d) TOTALLY FUCKED UP (honest list)

1. **I wrote `signoz-coverage.nix` as a BARE NixOS module — the EXACT trap AGENTS.md documents** ("Auto-discovered modules are FLAKE-PARTS wrappers"; a bare module evaluates silently and contributes NOTHING; symptom: "options don't exist"). Every nix command failed at 19:35 until a **concurrent agent** wrapped it (commit d7237d6c). I've read that gotcha dozens of times this session. Inexcusable; the wrapper shape must be muscle memory in this repo.
2. **First collector script had `exit 0` inside the `{ … } > "$TMP"` redirect block** — exits the shell, skips the trailing `mv`, file never lands → collector "succeeds" writing nothing. Caught ONLY because I live-ran the real artifact pre-deploy.
3. **First logs query used `toUnixTimestamp64Milli(timestamp)` on logs_v2 — its `timestamp` is UInt64 NANOSECONDS, not DateTime64** (traces index is DateTime64(9)). Query threw ILLEGAL_TYPE_OF_ARGUMENT. Also caught by the live pre-deploy run. Lesson: schema-verify EVERY table before writing SQL against it, even "obvious" columns.
4. **AGENTS.md line 824 mangled**: my edit matched a text PREFIX and left a duplicated sentence tail (`(same binary).-sync's OTLP support landed…`). Detected by post-edit verification, fixed. Should have used the full line as old_string.
5. **`env` helper shipped `inherit serviceName wiring maxAgeHours` with `wiring` undefined** — caught on my own re-read before eval, but it was written broken.
6. **First negative test used a nonexistent nix flag (`--no-write-mode`) and an unbound `lib`** — two wasted eval cycles.
7. **`unitHasOtelEnv` initially counted `OTEL_EXPORTER_OTLP_ENDPOINT=""` as wired** — the negative test (mkForce "") exposed it; fixed with a `..*` regex. Without that negative test, a mkForce-"" override would have silently passed the audit forever.
8. **Three deploys where two would do**: the MemoryMax 128M→256M bump could have ridden the registry-flip deploy. I only noticed the 100.6M/128M peak-after-the-fact from the journal. Measured-then-tuned should have happened pre-deploy.
9. **Repeated edit-tool rejections from daemon mtime races** (5+ times) — each cost a re-read. Expected in this repo, but I could have batched my reads+edits tighter around the daemon's commit cadence.

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **A VM/eval test that catches the bare-module shape** — the repo has audits for everything else (start-limit, timeout, udev-letters, dynamic-user, otel-endpoints, gate-timeout…) but NOTHING refuses a bare NixOS module in `modules/nixos/{services,desktop}/`. A tiny flake check: every file in those dirs must match `flake.nixosModules.<filename>` at top level. Would have caught my #d1 mistake at `nix flake check` time AND catches the concurrent agent that apparently hit a similar wrapper issue (gate-timeout-audit.nix appeared mid-session).
2. **`signoz-coverage-metrics` is NOT in deploy.sh's post-switch restart list** — the collector is timer-only, so after a deploy its metrics lag up to 5 min (likely cause of the mystery smoke FAIL). Adding it to the restart list makes coverage data appear at smoke time and closes the race.
3. **The collector's `.tmp.$$` files can accumulate** on mid-run crashes (each run uses a fresh PID suffix, no cleanup of strays). Add `rm -f "$OUT".tmp.*` prologue (own file only — same-name collisions impossible across runs of the same unit... but stale strays from killed runs linger).
4. **otel-endpoint-audit can't see config-based wiring** (dnsblockd YAML key) — the coverage registry compensates manually. A future improvement: let the audit accept a `configExpression` per service so both audits share one truth.
5. **§10's extractor was blind to anchored patterns** — fixed this session, but the gatus-pattern-lint (flake check) still only rejects THREE trap classes; the `[1-9]`-unanchored-value form (e.g. `pat(*metric [1-9]*)` without leading `\n`) is neither rejected nor required. Standardizing on anchored + making the lint ENFORCE it would end the class permanently.
6. **No dashboard for coverage debt** — `signoz_traces_upstream_gaps 6` exists as a metric but nobody sees it daily. A panel on the overview dashboard (or the existing "SigNoz alert rules healthy" pattern) would keep the debt visible past the TODO list.
7. **Live-run-before-deploy for every new unit script** should be a written rule (it caught 2 of my 3 real bugs this session; the third was caught by negative eval tests). Consider adding to AGENTS "Adding a Service": "live-run the collector/script artifact via `nix build <drv>^out` before deploying".
8. **Post-deploy smoke flakiness budget**: the unexplained 1-FAIL-then-green pattern deserves a retry/log-persist rule (deploy.sh could `tee` the full post-deploy output to `/var/log/systemnix-deploys/<ts>.log` — we currently lose the middle of every smoke run; I could not identify the failed check from either deploy's output).

## f) NEXT — up to 50 things, ordered

**P0 — finish tonight's thread (all unblock the 2 flips):**
1. User pushes dnsblockd master (+ tag if versioned) → `nix flake lock --update-input dnsblockd` (+ vendorHash dance if FOD changes) → flip `dnsblockd` wiring `"upstream"`→`"config"` → deploy → verify first dnsblockd spans in ClickHouse + `missing 0` with dnsblockd ENFORCED.
2. Same for bank-sync (push + tag; `--update-input bank-sync`; vendorHash refresh expected — go.mod gained otlptracehttp) → flip to `"env"` → verify `bank-sync` service appears in `/services`.
3. Remove `signoz_traces_missing`/`signoz_coverage_scrape_errors`/`signoz_logs_pipeline_stale`/`signoz_traces_reporting` (+ `system_user_units_*`, `discordsync_turso_local_only_mode`) from KNOWN_NEW_METRICS once the textfile confirms them (verify: `grep signoz_traces /var/lib/prometheus-node-exporter/textfile_collectors/signoz-coverage.prom`).
4. Add `signoz-coverage-metrics` to deploy.sh's post-switch restart list.
5. Root-cause or instrument the transient smoke FAIL (persist deploy logs first — see #8).

**P1 — close the remaining silent-coverage classes:**
6. overview: add `otelhttp` middleware + span sites on core ops (upstream repo; mirror DiscordSync).
7. projects-management-automation: same instrumentation pass.
8. papdashboard: add otlptrace SDK (`internal/metrics` sibling `internal/tracing`), span the ingest + enricher paths.
9. hermes: evaluate upstream `otlp` pip extra (uv2nix rebuild cost, propagator wiring, what it actually traces) — then enable or document why not.
10. Add a `bare-module-shape` flake check (e-d1) + negative test with a fixture file.
11. Collector stray-tmp cleanup (e-d3).
12. SigNoz dashboard "Telemetry Coverage" panel: `signoz_traces_reporting` by service, `upstream_gaps`, `logs_pipeline_age_seconds` (v2 API, converge pattern).
13. Extend gatus-pattern-lint to enforce anchored value-checks (e-e5).
14. Persist full deploy+smoke logs to /var/log/systemnix-deploys/ (e-e8).
15. Post-deploy smoke section for the coverage system: assert `signoz_traces_missing 0` + `scrape_errors 0` from :9100 (gates regressions at deploy time, not 5 min later).
16. VM test `tests/test-signoz-coverage.nix` (mock CH via socket? or assert eval assertions + generated JSON registry shape in a minimal host).
17. `docs/services/signoz-coverage.md` runbook (registry maintenance, flip procedure, query cheat-sheet incl. the ns-vs-DateTime64 trap).

**P2 — breadth of coverage (traces was tonight; metrics next):**
18. Metrics-freshness layer: emit per-scrape-job last-sample age (query `time_series_v4` per job's sentinel metric) → `signoz_scrape_job_fresh{job=…}` + Gatus; catches a dead exporter that Gatus HTTP checks can't (wedge-but-200 class).
19. Scrape papdashboard `/metrics` in the collector's prometheus config (it exists, nothing reads it).
20. Forgejo metrics scrape (needs token plumbing — decide if worth it).
21. Register the 9 scrape jobs + textfile collectors in the coverage registry concept (single pane: traces + logs + metrics per service).
22. immich/paperless-ai/twenty/manifest internal metrics — inventory + decide scrape vs skip, document decisions in the registry.
23. docker containers (twenty, manifest): wire `OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318` IF the images carry OTel SDKs — verify per image, don't blind-set (a noop env var in a container is the same lie class we just eliminated; the reverse assertion can't see oci envs — extend it).
24. gatus itself: upstream has no OTel trace support — confirm + document as logs+metrics-only in registry comments.

**P3 — quality/hygiene from tonight's debris:**
25. bank-sync upstream: CHANGELOG entry + tag naming per repo convention before push.
26. dnsblockd upstream: CHANGELOG/AGENTS note for the WithInsecure fix (feature was never usable — worth recording upstream).
27. Consider upstream tests for dnsblockd otel Setup transport selection (TLS vs insecure branch) — I fixed without adding one (its otel package has tests; add a config-parsing test at minimum).
28. gatus-config.nix: the two new checks share the nodePort URL with three existing checks — consider a mkCoverageCheck helper if the family grows.
29. The `untrackedOtelUnits` option is currently empty — add a comment example showing intended use (with reason), so future users don't cargo-cult registry entries.
30. Collector: emit per-entry `signoz_traces_expected` ONLY for enforced entries? (currently expected=1 for gaps too, which double-counts in naive `sum()` queries — documented or changed).
31. SystemNix AGENTS.md: the "65536 limit" style numbers in my collector comments are absent — fine — but add the collector's exact query shapes to the runbook so a future session doesn't re-derive the ns/ms trap.
32. Review concurrent session's `gate-timeout-audit.nix` + `system_user_units_*` work for interplay with the coverage collector's explicit `TimeoutStartSec` (both address the phantom global timeout — make sure they don't fight).
33. `heavy-job` wrap the next full `nix flake check` (VM tests) — tonight's checks ran unwrapped during 66-77% IO pressure (against the workload-admission doctrine).

**P4 — bigger swings (from the gap analysis, not urgent):**
34. Sampling policy: if dnsblockd span volume turns out heavy once live (tracking.Dispatch per tracked query), consider a collector `tail_sampling` processor or upstream span-drop for high-frequency DNS paths — measure first (query spans/hour by service after a week).
35. Service-name normalization: `cv-server` reports as `cv-application` (upstream hardcode). Either upstream-rename to the unit name or add an alias panel in the dashboard; the registry maps it but humans grep SigNoz by unit name.
36. Consider exporting the registry as a SigNoz dashboard annotation/table (declarative list visible in the UI, not just in Nix).
37. Log-based service-level alerting for the 80+ journald services (currently only the pipeline freshness is asserted — a per-service "no logs for N hours while unit active" check would catch silent hung daemons; hermes-class).
38. The `overview`/`PMA` noops: while instrumenting, also add `OTEL_SERVICE_NAME` explicitly so future renames can't silently fork service identities.
39. PapDashboard insight: feed `signoz_traces_missing` into the alert lifecycle hub (it already ingests gatus transitions — nothing to do if gatus alerts flow; verify end-to-end once a real trip happens).
40. Kill the KNOWN_NEW_METRICS entries older than one deploy (the list has been accumulating since 2026-08-21 — several entries are stale).
41. `tests/test-gatus-patterns.nix` — add the anchored `[1-9]` form cases so the pattern library covers the new check style.
42. Consider `signoz_coverage_expected_total`/`reporting_total` counters for trivial PromQL ratios in dashboards.
43. bank-sync: while tagging, check whether the SCA transfers-fallback degradation (journal WARNs tonight) deserves its own alert — noticed in passing, not tonight's scope.
44. dnsblockd: after spans flow, watch its RSS (the module comment warns of OTEL cardinality growth in METRICS — spans add a new dimension; MemoryMax 4G already set).
45. Sweep ALL docs/status reports for "OTel" claims that predate tonight (e.g. anything asserting fastflowlm/hermes/overview "sends traces") and correct them — stale docs lie.
46. Add `signoz-coverage` to the Homepage "Monitoring" tile description (cosmetic discoverability).
47. Ask upstream CV repo whether `cv-application` service name should match the unit (single-source-of-truth naming).
48. If push access policy ever changes: a small `scripts/bump-lars-inputs.sh` that does push+tag+lock+vendorHash+flip mechanically for exactly this recurring propagate-then-flip dance.
49. Nightly coverage snapshot to Discord (low-noise summary of missing/gaps) — optional, may be spam; ask user first.
50. Revisit `maxAgeHours=26` for crush-daily after observing its real span cadence (timer-driven; if it can skip 26h legitimately, loosen before it false-pages).

## g) Questions I CANNOT answer myself

1. **Push authority for the two upstream fixes**: dnsblockd + bank-sync builds/tests are green in `~/projects` but unpushed (I never push). Do you want to push+tag them yourself now so I can do the lock bumps + registry flips + span verification in a follow-up, or should the flips wait for a regular release train?
2. **Depth of the remaining instrumentation work**: overview/PMA/papdashboard/hermes span instrumentation is real multi-repo upstream work (HTTP middleware + span sites + releases). Should that be scheduled as its own session(s) now that the audit makes the debt visible, or is visible-but-not-paging the steady state you want for those four?
3. **Alerting taste for the gap metric**: `signoz_traces_upstream_gaps 6` is deliberately non-paging. Once the two flips land it drops to 4 (overview, PMA, papdashboard, hermes). Do you want a LOW-severity (Discord warning, no sev1 overlay) alert when upstream_gaps INCREASES (a new silent noop entering the registry), or keep it dashboard-only until the backlog is zero?

---

## Verification Snapshot (21:33)

```
signoz_coverage_scrape_errors 0
signoz_traces_missing 0
signoz_traces_upstream_gaps 6
signoz_logs_pipeline_stale 0
system_signoz_alert_rules_healthy 1
post-deploy smoke: PASS 83 / FAIL 0 / SKIP 4 / WARN 1
```

Deployed units: `signoz-coverage-metrics.service/.timer` live (5-min cadence, ~0.3s/run, MemoryMax 256M). Gatus: 2 new checks green. SigNoz: 3 new rules + route policies converged. Upstream repos: 2 fixes + 3 tests awaiting push.
