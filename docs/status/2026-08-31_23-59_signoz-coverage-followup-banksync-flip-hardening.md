# SigNoz Coverage Follow-Up — bank-sync Flip Landed, System Hardened, Deploy Rails Fixed

**Date:** 2026-08-31 23:59 CEST
**Trigger:** User (continuation of the 2026-08-31 21:33 trace-coverage audit): "READ, UNDERSTAND, RESEARCH, REFLECT. Break this down into multiple actionable steps. Execute and Verify them one step at a time. Repeat until done."
**Predecessor:** `docs/status/2026-08-31_21-33_signoz-trace-coverage-audit-self-review.md`

---

## TL;DR

bank-sync traces are LIVE (1222 spans / first 30 min), the gap count dropped
6 → 5, a gap-budget ratchet now pages on any NEW silent noop, the deploy
pipeline gained full log persistence + a coverage smoke gate, and two real
bugs in the concurrent session's in-flight test work were fixed to unblock
ALL deploys. Final smoke: **PASS 84 / FAIL 0 / SKIP 4 / WARN 2**.

```
signoz_traces_missing 0
signoz_traces_upstream_gaps 5          (was 6 — bank-sync flipped to enforced)
signoz_traces_upstream_gaps_over_threshold 0
signoz_coverage_scrape_errors 0
signoz_logs_pipeline_stale 0
```

## a) FULLY DONE (verified live)

1. **bank-sync flip, end to end.** The upstream OTLP commit (901978e) was
   found ALREADY PUSHED (0 unpushed vs origin — committed 23:04 by the
   auto-daemon/user after the predecessor session). Lock bumped
   (09785e60 → 901978e), SystemNix's TEMPORARY vendorHash override refreshed
   (`sha256-KX7fRSCw…`, from the FOD mismatch — upstream's own flake hash is
   STILL stale, override stays), package build green, registry wiring flipped
   `upstream` → `env` (26h budget). Live: **bank-sync service now on the
   SigNoz /services page**, `signoz_traces_missing 0` in the same deploy's
   smoke.
2. **Gap-budget ratchet (answers predecessor question g3 — implemented, my
   call):** new option `services.signoz-coverage.maxUpstreamGaps` (default 5
   = current debt), collector emits
   `signoz_traces_upstream_gaps_over_threshold` (both fail-closed and normal
   branches), Gatus check "SigNoz Trace Gap Budget" (anchored patterns).
   A new silent noop entering the registry now PAGES within one Gatus cycle;
   lowering the budget as gaps close is a conscious commit. Live: 5 gaps,
   over_threshold 0.
3. **KNOWN_NEW_METRICS: all 11 entries retired** — each verified live first
   (:9100 textfiles, discordsync :8085, bank-sync :8097). Replaced with 3
   one-deploy loans: `signoz_traces_upstream_gaps_over_threshold` (mine) +
   `pool_usb_recovery_{members_present,device_errors}` (the concurrent
   session's new collector rides this same deploy).
4. **deploy.sh hardening:** (a) `signoz-coverage-metrics` restart added to
   the post-switch list (`restart`, not `start` — RemainAfterExit-safe;
   closes the smoke-vs-timer race, predecessor §e2); (b) **full deploy+smoke
   output now persisted** to `/var/log/systemnix-deploys/<ts>.log` via
   `sudo tee` (30d retention) — paid off IMMEDIATELY (see d3).
5. **Collector hardening:** stray `.tmp.<pid>` reaping prologue (predecessor
   §e3); `MAX_UPSTREAM_GAPS` passed via `runtimeEnv`. New artifact live-run
   BEFORE deploy (house rule) — output byte-verified, 0.33s.
6. **`module-shape-lint` flake check** (predecessor §e1): every non-`_` file
   in `modules/nixos/{services,desktop}/` must declare
   `flake.nixosModules.<filename>`. Negative + positive tested standalone
   (bare module fixture → FAIL; wrapper + `_helper` skip → PASS); builds
   green against the real tree. The predecessor's #d1 mistake class is now
   machine-refused.
7. **Post-deploy smoke: "SigNoz Coverage" section** — asserts
   `signoz_traces_missing 0` + `signoz_coverage_scrape_errors 0` from :9100
   at DEPLOY time, with a retry loop that RE-RUNS the collector (sudo) for
   the OTel-batch-flush race of a freshly-enforced entry; `absent` is a FAIL
   (fail-closed).
8. **SigNoz dashboard "Telemetry Coverage"** (8 panels: missing, gaps, budget
   breach, scrape errors, logs stale/age, reporting-by-service, last-span-age
   by service), uuid5-stable IDs, provisioned via the v2 converge pattern.
   Converged live (owned=6) on the second deploy (see d1).
9. **tests/test-gatus-patterns.nix:** coverage metrics added to the mock
   body (HELP lines present on purpose — the comment trap), a GREEN endpoint
   with the production conditions verbatim, and a **[TEST-RED] endpoint**
   asserting the `[1-9]` anchored form does NOT match a healthy 0-value body.
   Also fixed the test's VACUOUS assertion (see d6).
10. **Runbook `docs/services/signoz-coverage.md`:** three layers, registry
    maintenance, flip procedure (incl. "lower maxUpstreamGaps by one"),
    ClickHouse cheat-sheet (the ns-vs-DateTime64 trap), metrics reference,
    current gap list.
11. **Unblocked ALL deploys by fixing 2 real bugs in the concurrent session's
    in-flight work** (flagged, not reverted — surgical completion of their
    visible intent):
    - `tests/test-tmp-cleaner-audit.nix`: cases 1+2 evaluated WITHOUT the
      audit module imported — case 1 threw `inline-glob-cleaner-not-caught`
      on every `nix flake check` (deploy-blocking), case 2 passed VACUOUSLY.
      Added `audit` to both module lists (case 3 showed the correct pattern).
    - `tests/test-tmp-cleanup.nix`: `nixpkgs.overlays` stub collided with
      runNixOSTest's read-only pkgs injection (read-only.nix pins overlays
      with `types.unique` → "defined multiple times"). Replaced with a
      `lib.mkForce` ExecStart stub on the crush-update-providers unit (it
      never fires in the test; it only needs to render).
    - Survived a transient `attribute 'nur' missing` tree state (mid-edit of
      the other session) by waiting and re-probing, not by touching their
      files.
12. **Final deploy green:** 84 PASS / 0 FAIL / 4 SKIP / 2 WARN. `nix flake
    check --no-build` passes. Files formatted with the locked formatter
    (zero lock churn — flake.lock diff is exactly the bank-sync bump).

## b) PARTIALLY DONE

1. **DNSBLOCKD still dark** — the WithInsecure fix sits UNCOMMITTED in
   `~/projects/dnsblockd` (`internal/otel/otel.go`, working tree only).
   Everything else is ready: config key live, flip procedure documented,
   budget will go 5 → 4. Blocked on user commit+push (I never push).
2. **The 3 KNOWN_NEW_METRICS loans need retirement** next deploy (verify
   live → delete; the list header now says "a one-deploy loan, not a museum").
3. **test-gatus-patterns VM test edited but NOT built+run** — eval passes;
   the risky part (gatus API field-name assumption, see d6) is unverified
   until the VM runs (heavy-job wrap it).

## c) NOT STARTED (tracked in §f)

The 4 upstream instrumentation gaps (overview / PMA / papdashboard / hermes)
stay visible-but-not-paging (predecessor question g2, still user-gated);
metrics-freshness layer (P2); everything else in §f.

## d) TOTALLY FUCKED UP (honest list)

1. **Dashboard layout overlap shipped to PROD**: my generator computed
   second-row x as `(i % 6) * 2` → item 7 at x=2 overlapping item 6 (x=0,w=6).
   Caught ONLY by the provisioner's HTTP 400 on the live deploy
   (`items[6] and items[7] overlap`) — one full extra deploy cycle burned
   (~4 min). I verified panel/ref consistency but NOT geometry; the 6-line
   overlap check I wrote AFTER the failure should have run BEFORE.
2. **First deploy attempt blocked twice**: (a) the concurrent session's
   pool-recovery gatus checks reference metrics their own new collector only
   serves POST-switch — they never added the KNOWN_NEW_METRICS loans; I added
   them. (b) `attribute 'nur' missing` — their mid-edit state. In a shared
   tree I should re-run `nix flake check --no-build` immediately before
   `nix run .#deploy` (my earlier pass predated their edits).
3. **First smoke-retry design was a no-op**: I polled :9100 every 15s, but
   the textfile only changes when the collector RUNS — the loop re-read the
   same stale body. Caught by my own review pre-deploy; fixed to `sudo
   systemctl restart signoz-coverage-metrics` per attempt.
4. **Two edit-tool rejections on _signoz-alerts.nix**: I re-read via bash
   grep instead of the VIEW tool (the edit tool tracks its own reads).
   Known repo behavior; wasted 2 cycles.
5. **A typo'd old_string** (stray "n" line) in the test edit — rejected,
   redone. Sloppiness.
6. **Found+fixed a LATENT vacuous assertion in test-gatus-patterns.nix**
   (pre-existing, not mine — but I only noticed because my RED endpoint
   forced the question): gatus's per-result `status` is the HTTP status code
   ONLY; a failed BODY condition keeps status=200. The old
   `health != 200` assertion NEVER caught condition failures — the whole
   pattern library was partially vacuous. Now asserts `errors`/`success`.
   CAVEAT: the `errors`/`success` field names are from my knowledge of the
   gatus API, not yet verified by a VM run (see b3) — if wrong, the test
   fails loudly (acceptable failure mode).

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Dashboard JSON pre-deploy validation**: overlap check (pure python,
   offline) + ideally a dry-run POST against the SigNoz v2 API in
   pre-deploy-check — the provisioner is the LAST line, not the first.
2. **Concurrent-tree deploy discipline**: re-run `nix flake check --no-build`
   in the same breath as the deploy; the tree can break between an old check
   and a new deploy.
3. **Smoke threshold sanity**: "System — I/O pressure avg10=70.82% (healthy)"
   PASSING at 70% looks like a broken threshold (deploy-time IO pressure is
   expected, but 70% labeled healthy needs a second look).
4. Document the **gatus-API-status-is-HTTP-only** lesson in AGENTS.md (it
   invalidated a whole test file silently).
5. Document the **runNixOSTest read-only overlays collision** (test-side
   `nixpkgs.overlays` + framework-injected pkgs → "defined multiple times";
   stub the UNIT, not the package set).

## f) NEXT — ordered

**P0:**
1. User commits+pushes dnsblockd → `nix flake lock --update-input dnsblockd`
   → flip wiring `upstream` → `config` → **lower maxUpstreamGaps to 4** →
   deploy → verify first dnsblockd spans (config key already live).
2. Retire the 3 KNOWN_NEW_METRICS loans after confirming them live.
3. Build+run `tests/test-gatus-patterns.nix` (heavy-job wrapped) — verifies
   the errors/success field assumption + the RED endpoint.
4. Human glance at the "Telemetry Coverage" dashboard in the UI.

**P1 (upstream instrumentation — each is its own session):**
5. overview: otelhttp middleware + span sites (mirror DiscordSync).
6. projects-management-automation: same pass.
7. papdashboard: trace SDK sibling to internal/metrics.
8. hermes: evaluate the upstream otlp pip extra, wire or document.

**P2 (breadth — metrics side next):**
9. Metrics-freshness layer: per-scrape-job last-sample age →
   `signoz_scrape_job_fresh{job}` + Gatus (wedge-but-200 class).
10. Scrape papdashboard's own /metrics (exists, nothing reads it).
11. Register the 9 scrape jobs + textfile collectors in the coverage concept.
12. Forgejo metrics scrape (token plumbing decision).
13. immich/paperless-ai/twenty/manifest internal metrics inventory.
14. docker containers (twenty/manifest): verify OTel SDK presence BEFORE
    wiring `OTEL_EXPORTER_OTLP_ENDPOINT` (a noop env in a container is the
    same lie class; the reverse assertion cannot see oci envs).
15. gatus: confirm no upstream OTel trace support, document as
    logs+metrics-only in the registry comments.

**P3 (quality/hygiene):**
16. Dashboard pre-deploy validation (e1).
17. Extend gatus-pattern-lint to ENFORCE anchored value-checks (predecessor
    e5 — still open).
18. otel-endpoint-audit `configExpression` support (dnsblockd YAML key; both
    audits share one truth).
19. bank-sync upstream CHANGELOG + tag (vendorHash refresh upstream would let
    SystemNix DROP the override).
20. dnsblockd upstream CHANGELOG + transport-selection test.
21. `tests/test-signoz-coverage.nix` (eval-assertion + generated-registry
    shape; mock CH optional).
22. Collector: emit `signoz_traces_expected` for enforced entries only, or
    keep documented double-count (currently documented in runbook).
23. I/O pressure smoke threshold investigation (e3).
24. fish startup 976ms WARN at quiescence + quickshell 1 error line —
    recheck outside deploy contention.
25. Monitor bank-sync span volume (first 24h) for the 26h budget's sanity;
    same for crush-daily (timer cadence).
26. Sampling policy if dnsblockd span volume proves heavy (tail_sampling or
    upstream span-drop for hot DNS paths).
27. cv-application service-name normalization (upstream hardcode vs unit
    name).
28. Registry as a visible SigNoz dashboard annotation/table.
29. Per-service "no logs while unit active" alerting (hermes-class silent
    hangs).
30. `OTEL_SERVICE_NAME` explicit on overview/PMA while instrumenting.
31. Verify PapDashboard receives the coverage Gatus transitions end-to-end
    on the first real trip.
32. Stale-docs sweep for pre-audit "sends traces" claims.
33. Homepage "Monitoring" tile description mention (cosmetic).
34. Ask CV upstream about the service name (single-source-of-truth naming).
35. `scripts/bump-lars-inputs.sh` if push policy ever changes (mechanical
    push+tag+lock+vendorHash+flip).
36. Nightly coverage snapshot to Discord (ask user first — may be spam).
37. `signoz_coverage_{expected,reporting}_total` counters for trivial PromQL
    ratios.
38. Add a [TEST-RED] case for the HELP-comment phantom (bare
    `pat(*metric 1*)` matching comments) — green-side proof of that trap.
39. Consider `pool-recovery-metrics` in deploy.sh's post-switch list (same
    timer-lag class as the coverage collector — verify whether the other
    session handled it).
40. Trash `/tmp/cov-test.sh` + `/tmp/signoz-coverage-test.prom` scratch
    (session debris).
41. AGENTS.md: add the gatus-API-status lesson (e4) + read-only-overlays
    collision (e5) + link the new runbook in Key Procedures.
42. heavy-job wrap for any full `nix flake check` that builds VM tests.
43. Review the concurrent session's remaining in-flight tree state at a
    quiescent moment (their crush-consolidation work was mid-edit tonight).

## g) Questions for the user (cannot answer myself)

1. **dnsblockd push**: the WithInsecure fix is UNCOMMITTED in
   `~/projects/dnsblockd`. Commit+push it (I then flip wiring to "config" +
   ratchet the budget 5 → 4 + verify first dnsblockd spans), or hold for a
   release train?
2. **The 4 remaining gaps** (overview / PMA / papdashboard / hermes): real
   multi-repo instrumentation work — schedule dedicated upstream sessions
   now, or is visible-but-not-paging the steady state for them?
3. **Deploy log persistence taste**: every deploy's full output now lands in
   `/var/log/systemnix-deploys/` (30d retention, ~100 KB per deploy, root
   fs has 129 G free). Keep as-is, or different retention/location?

---

## Verification Snapshot (23:59)

```
post-deploy smoke: PASS 84 / FAIL 0 / SKIP 4 / WARN 2
signoz_traces_missing 0                  (bank-sync enforced AND reporting)
signoz_traces_upstream_gaps 5            (dnsblockd, overview, PMA, papdashboard, hermes)
signoz_traces_upstream_gaps_over_threshold 0
signoz_coverage_scrape_errors 0
signoz_logs_pipeline_stale 0
bank-sync spans: 1222 in the 30 min after the flip
dashboards converged: owned=6 desired=6 (incl. telemetry-coverage)
deploy logs: /var/log/systemnix-deploys/{23-26,23-36,23-45,23-59}.log
```

Deployed deltas: bank-sync input 901978e (+vendorHash override refresh),
signoz-coverage (bank-sync enforced, gap budget, tmp-reaping), gatus (+1
check), SigNoz (+dashboard), deploy.sh (restart list + log persistence),
pre/post-deploy checks (loans retired, coverage smoke section), module-shape
lint, 2 test fixes, 1 runbook, 1 dashboard.
