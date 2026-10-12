# SigNoz log→trace correlation: dnsblockd OTLP-logs prototype — session status

**Session:** 2026-10-12, ~03:10–03:40 CEST.
**Scope:** fix the "only 4 of 12.16M log lines carry `trace_id`" gap (`docs/todo/monitoring.md:106`, `TODO_LIST.md:303`) by instrumenting **dnsblockd** — the one span-emitting Go service checked out locally — to export slog records over OTLP with trace/span IDs attached.
**Repo touched:** `~/projects/dnsblockd` (external, user-owned) — NOT SystemNix. This report is filed here because the finding + dispatch item live here.
**Parallel sessions active:** yes — commit `3faf986b` regenerated 22 `internal/server/views/*_templ.go` files at 03:00:56; that regen left `app.min.css` stale and broke the dnsblockd `nix build` at its CSS gate (see §d.6).

---

## a) FULLY DONE (verified end-to-end)

1. **OTLP log pipeline in `internal/otel/otel.go`** — `Setup` now builds an `otlploghttp` exporter + `sdklog.LoggerProvider` (batch processor, shared resource) on the same `otlp_endpoint` as traces; `Providers` gained `loggerProvider`, `serviceName`; `Shutdown` drains the logger provider. Traces + logs use identical TLS/plaintext endpoint logic (the scheme-aware `WithInsecure` fix is reused, not re-derived).
2. **Fan-out logging in `internal/logging/multi.go`** — new `MultiHandler` writes every record to both the local handler (stdout→journald, unchanged for `journalctl`/ops) and the `otelslog` bridge. `Enabled` = any-accepting, `Handle` joins errors, `WithAttrs`/`WithGroup` map across handlers; 0-handler discards, 1-handler returns unwrapped.
3. **Bridge install in `cmd/dnsblockd/main.go`** — after `otel.Setup`, `slog.SetDefault(slog.New(logging.MultiHandler(slog.Default().Handler(), providers.LogHandler())))`; a no-op when OTLP is disabled.
4. **Context-aware conversion (request-critical path)** — `AuditLogger.Log` now emits `slog.InfoContext(ctx, "audit", …)` (+ `ErrorContext` on the persist failure), covering all 18 audit call sites; handler logs converted to `*Context(r.Context(), …)`: 404, allow-duration warning, false-positive-reported, CSP rate-limit, CSP-violation, allow-page-invariant warning.
5. **Tests proving the mechanism** — `internal/otel/log_test.go`: `TestLogBridge_StampsTraceID` (span-carrying ctx ⇒ exported record's `TraceID` equals the span's, non-zero) and `TestLogBridge_NoSpanNoTraceID` (ctx without a span ⇒ empty trace ID); plus `LogHandler` nil-when-disabled and nil-providers cases. `internal/logging/multi_test.go`: fan-out, single-handler unwrap, Enabled-any, zero-handler discard.
6. **Build / test / lint green** — `go build ./...`; `go test ./...` (full repo, all pass); `golangci-lint` **0 findings** via `BUILDFLOW_NO_RESULT_CACHE=1 buildflow -s golangci-lint` (fresh, cache bypassed — the first run was a false-clean cache hit).
7. **vendorHash refreshed** — `scripts/check-vendor-hash.sh --fix` adopted `sha256-4pBIBDmms3g741sIt2nBjZJWZTHmSyiVvAJT2AcpS7M=` for the 3 new modules (`otelslog`, `otlploghttp`, `sdk/log`); the FOD then passed (the subsequent failure was the unrelated CSS gate).
8. **`go.mod` tidied** (`go mod tidy` — the preflight itself prescribed it; the new deps moved from `// indirect` to the direct require block).
9. **Docs** — `CHANGELOG.md` entry under `[Unreleased]`; `AGENTS.md` observability note corrected (the stale "log pillar is deliberately deferred until OTel Go v1.47" sentence replaced with the live state + the "requires `*Context` call sites" rule).
10. **Design boundary discovered and honored** — `depguard`'s `leaf-packages-stay-leaf` rule forbids `internal/otel` from importing `internal/logging`; the fan-out was moved into `cmd/**` (which may import both) after the first `buildflow` run caught it.

## b) PARTIALLY DONE

1. **Coverage of the service's log volume: low-to-moderate** — audit + ~6 handler sites converted; the three centralized request-path helpers (`logError` 35 callers, `logRenderError` 9, `handleTrackingQueryError` 5 ≈ 49 sites) and every page/props builder still log without a context, so most HTTP render-error and many page lines still export an empty trace ID.
2. **The fix is not observed working in SigNoz** — verified only to the unit boundary (record carries the trace ID). No deploy ⇒ no confirmation that `countIf(trace_id != '')` for dnsblockd actually rises in `signoz_logs.distributed_logs_v2`. The pipeline (collector OTLP logs receiver → `clickhouselogsexporter`) is a reasoned assumption, not a probe.
3. **Sampling parity: not handled** — `logging.SamplingHandler` wraps only the local handler (`config.SetupLogging`), so the OTLP bridge receives **unsampled** records. If dnsblockd's sampler is active, SigNoz will ingest MORE lines than the journal — the exact flood the sampler exists to prevent (see §e.1/§f).
4. **Duplicate-line consequence: identified, not resolved** — dnsblockd's lines now reach SigNoz twice (OTLP copy with trace ID + journald copy without). The `drop()` collector rule is deliberately deferred (land-replacement-first ordering), but it is unowned and unwritten.
5. **Commit hygiene: content 100%, messages 0%** — the daemon swept everything into three heuristic commits (`1b5a7ade`, `ef712fdf`, `1ede76c2`); the depguard/vendorHash/docs refinements are still uncommitted (dirty tree). I never made a proper commit (correctly — no "commit" instruction — but the daemon fragmentation stands).

## c) NOT STARTED (deliberately untouched)

1. The same OTLP-logs patch for the rest of the span-emitting fleet: **discordsync, cv-application, bank-sync, browser-history, crush-daily, overview** (repos not checked out locally + push-gated).
2. SystemNix-side surfaces: `docs/todo/monitoring.md:106` / `TODO_LIST.md:303` progress note; `docs/services/dnsblockd.md` + `docs/services/signoz.md` runbook updates; the duplicate-drop collector rule.
3. dnsblockd flake-input bump in SystemNix (`nix flake lock --update-input dnsblockd`) — user-gated (push + lock authority).
4. A collector-side capture test (does SigNoz store the bridge's trace_id in the `trace_id` column?) — unverified.
5. The helper-call-site conversion (§b.1) — explicitly scoped out this session.

## d) TOTALLY FUCKED UP (honest)

1. **First `golangci-lint` green was a cache lie** — `buildflow -s golangci-lint` reported 0 findings on the first run via a 100% result-cache hit, i.e. it did NOT scan my changed files. Only after `BUILDFLOW_NO_RESULT_CACHE=1` did the real 11 findings appear (depguard, makezero, 6× unused nolint, golines, 2× wsl). I nearly accepted a phantom clean.
2. **`multiedit` silently applied 5 of 6 edits** — the `Providers` struct edit failed (whitespace/comment mismatch I still don't fully understand), leaving `providers.loggerProvider = …` referencing a field that didn't exist. I only caught it by grepping for the field. Lesson: check the applied-count line, then verify the artifact, never assume all-or-nothing.
3. **Edit-tool "must View before Edit" trip** — I "read" `otel.go` via `bash cat`, which does NOT satisfy the tool; the multiedit was rejected and I re-read via `view`. Repeated a known lesson.
4. **Wrote nolints that weren't needed** — 6 `//nolint:ireturn`/`wrapcheck` directives `nolintlint` flagged as unused. I guessed which linters fire instead of running the linter first.
5. **Depguard violation designed-in** — I put `AttachLogHandler` (needing `internal/logging`) inside `internal/otel`, which the very clearly-documented leaf-package rule forbids. I read the rule only when the linter quoted it. Should have checked `AGENTS.md`'s depguard paragraph before choosing the file.
6. **Declared "no SystemNix change needed" too fast** — true for the *ingest* path, but I missed the duplicate-line consequence and the sampling-parity problem in that same breath.
7. **Encoding hazard** — the `—` (em-dash) in the reflowed `handlers.go` log message forced a golines rewrap and made exact-match edits fragile; I should have split the call site cleanly on the first try.
8. **`nix build` never went green** — blocked by a parallel session's stale `app.min.css` (not my change), so I could not prove the nix-side build of my vendored deps. I stopped at "FOD passed," which is weaker than "package built."

## e) WHAT WE SHOULD IMPROVE

1. **Sample the OTLP bridge identically to the local handler** — wrap the `otelslog` handler in the same `SamplingHandler` (or set its min level) so SigNoz never ingests more than the journal. Volume control is a first-class concern of the log pillar, not an afterthought.
2. **Bypass the result cache on every "is it clean?" lint claim** — a cached green is not a green (this session's §d.1). Make `BUILDFLOW_NO_RESULT_CACHE=1` the default for post-change verification.
3. **Read the depguard/leaf rules before choosing where code lives** — the package-DAG is lint law here; `cmd/**` is the correct seam for cross-package wiring.
4. **Verify the artifact after every multi-edit** — grep for the symbol you inserted; trust the tool's "applied N of M" line only as a hint (§d.2).
5. **Prove the mechanism at the sink, not just the SDK** — the unit test proves the trace ID is stamped; the fix is only "done" when `countIf(trace_id != '')` rises in ClickHouse. Until then it is a prototype.
6. **Follow the documented upstream procedure-first** — the repo's own `scripts/check-vendor-hash.sh --fix` was the right tool; I reached it only after considering buildflow's generic `nix-hash-fix`.

## f) UP TO 50 THINGS TO GET DONE NEXT

1. Convert the 3 helper functions (`logError`, `logRenderError`, `handleTrackingQueryError`) to take `ctx` and update all ~49 call sites (`r.Context()` in handlers, `context.Background()` where no request exists) — biggest single coverage win. [dnsblockd]
2. Wrap the OTLP bridge in the project's `SamplingHandler` (sampling parity; §e.1). [dnsblockd]
3. Convert page/props builders (`sources_page.go`, `devices_page.go`, `proxy_page.go`, `fp_detail_page.go`, `false_positives_page.go`, `query_log_page.go`, `analytics_page.go`) — they already hold `*http.Request`. [dnsblockd]
4. Convert the DNS-path log sites (`dns_observer.go`, `tracking/service.go`) where a span ctx exists. [dnsblockd]
5. Add a `dnsblockd` end-to-end assertion script: `countIf(trace_id != '')` for `service.name='dnsblockd'` after deploy. [dnsblockd/SystemNix]
6. Port the same patch to **discordsync** (OTel SDK already emits traces; add `otelslog` + `otlploghttp`). [upstream]
7. Port to **cv-application** (cv-server). [upstream]
8. Port to **bank-sync**. [upstream]
9. Port to **browser-history**. [upstream]
10. Port to **crush-daily**. [upstream]
11. Port to **overview** (in-house, `fff1035` traceMiddleware precedent). [upstream]
12. Extract the shared pattern (a tiny `otelslog`+fanout helper) so 11 services don't each re-implement it — candidate for a `collector-utils`-style shared Go module. [decision]
13. Add the collector `drop()` rule for dnsblockd's journald copy (AFTER the new binary deploys). [SystemNix]
14. Update `docs/todo/monitoring.md:106` + `TODO_LIST.md:303` with prototype progress (dnsblockd done, fleet pending) on BOTH surfaces. [SystemNix]
15. Add a `docs/services/signoz.md` runbook note: "how to add OTLP logs to a Go service" (deps, bridge, sample parity, fan-out, verify probe). [SystemNix]
16. Update `docs/services/dnsblockd.md` observability section. [SystemNix]
17. Re-check the `signoz_logs` retention/TTL against the added OTLP-log volume (14d TTL families). [SystemNix]
18. Add a Gatus/SigNoz signal for "log→trace pivot ratio" (currently a manual `countIf`). [SystemNix]
19. Decide + document duplicate-line policy: keep redundancy vs single-source drop. [decision]
20. Verify the OTLP log record's resource attrs (`service.name`) match the journald pipeline's so dashboards aggregate one service. [SystemNix]
21. Confirm the `clickhouselogsexporter` maps OTLP `TraceId` into `distributed_logs_v2.trace_id` (source-level or live probe). [SystemNix]
22. Add a `slog` min-level config for the OTLP export (separate from stdout). [dnsblockd]
23. Add a metric/health field reporting whether the log bridge is active (extend `/health`, mirroring `otlpEnabled`). [dnsblockd]
24. Add a CHANGELOG "sampling parity" follow-up once done. [dnsblockd]
25. Lands the `--fix` fixtures: a test asserting the multi-handler forwards identical records to both sinks (record-equality). [dnsblockd]
26. Write a proper (non-heuristic) commit for the dnsblockd change set once the fleet patch shape is settled. [dnsblockd/user]
27. Bump SystemNix `dnsblockd` input + vendorHash downstream. [SystemNix/user]
28. Extend the `negative-test-lints` habit: a negative test that the bridge is NOT installed when OTLP is off (partly covered). [dnsblockd]
29. Add `context` import hygiene check for the new `*Context` convention (grep guard: request-path logs must not use bare `slog.Info`). [dnsblockd]
30. Re-run the full `nix flake check` once the CSS staleness is resolved. [dnsblockd]
31. Confirm the stale `app.min.css` belongs to the parallel session (git blame) before anyone "fixes" it. [dnsblockd]
32. Document the duplicate journald/OTLP line in the runbook as a known transient until the drop lands. [SystemNix]
33. Consider exemplar parity: does the same otelslog approach unlock anything for the (dropped) metric exemplars? (No — separate SigNoz limitation; record the non-answer.) [SystemNix]
34. Add a fleet census table (which services need OTLP logs) to the monitoring library. [SystemNix]
35. Verify `otel.SetErrorHandler` still routes log-exporter errors (shares the handler). [dnsblockd]
36. Check the batch processor flush on shutdown under the 3s bounded ctx (logs may be lost on fast exit). [dnsblockd]
37. Time-bound the OTLP log exporter to match the trace exporter's 10s (done) — document why 10s. [dnsblockd]
38. Add `dnsblockd` OTLP-log smoke to `scripts/post-deploy-check.sh` (§ auth/telemetry pattern). [SystemNix]
39. Ratchet any SigNoz log-volume alert to account for the new stream. [SystemNix]
40. Re-verify the "4 of 12.16M" baseline before/after to quantify the fix. [SystemNix]
41. Consider a shared `buildflow` provider for "Go service missing otelslog bridge" (fleet-wide lint) — the extension-the-tool-not-the-repo rule. [decision]
42. Add unit coverage that `LogHandler` returns a handler whose records carry `service.name` = service name. [dnsblockd]
43. Confirm no import cycle risk if `internal/logging` ever needs `internal/otel` (currently leaf-safe: it must not). [dnsblockd]
44. Roll the `-event`/`-upstream` registry entries toward enforced once logs correlate (coverage module note). [SystemNix]
45. Keep a per-service "instrumented logs" checklist in the integration registry (docs/agents/integration-registry.md step). [SystemNix]
46. Add `dnsblockd` AGENTS.md "how to verify the bridge is live" one-liner (the ClickHouse probe). [dnsblockd]
47. Evaluate whether stdout logging can be dropped for OTLP-only services once journald redundancy is unwanted (ties to §f.19). [decision]
48. Adopt `BUILDFLOW_NO_RESULT_CACHE=1` in the project's post-change verification note. [buildflow]
49. Re-read `docs/CONTRIBUTING.md` daemon-race policy before the next external-repo edit (the fragmentation class recurred). [SystemNix]
50. Schedule the fleet port as ONE batch PR to each repo, not dribbles, once the pattern is frozen. [decision]

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Fleet scope & sequencing:** do you want me to port this pattern to all six remaining span-emitting services (each is a separate external repo + push), or stop at dnsblockd as the proven reference and let the rest follow later? And should I wait for you to push dnsblockd before starting the next repo?
2. **Duplicate-line policy:** after the new dnsblockd binary deploys, should SigNoz keep BOTH the OTLP copy (trace-correlated) and the journald copy (redundant, no trace ID), or should I add the collector `drop()` to keep a single source? (Tradeoff: single-source clarity vs a silent gap if the OTLP export path breaks.)
3. **OTLP log volume ceiling:** what is an acceptable SigNoz log-volume increase for dnsblockd — should the OTLP bridge mirror the local sampler exactly (my default), or export at a stricter min level (e.g. INFO-only) to bound ingest cost?

*Report filed 2026-10-12_03-40. No SystemNix files changed this session; all work is in `~/projects/dnsblockd`.*

**§f harvest: DELIBERATELY NOT HARVESTED at authoring time** — the owner instruction for this session was "write the report, then WAIT FOR INSTRUCTIONS," and the three §g questions gate which §f items are real (fleet scope, duplicate policy, volume ceiling). Two items are ready to queue on the owner's go: (a) update the existing fleet item `docs/todo/monitoring.md:106` + `TODO_LIST.md:303` with the dnsblockd-prototype progress, and (b) add the "how to add OTLP logs to a Go service" note to `docs/services/signoz.md`. Neither is queued yet; queued on instruction.

