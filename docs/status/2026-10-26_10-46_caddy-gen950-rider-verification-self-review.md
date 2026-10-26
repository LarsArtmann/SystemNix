# Caddy gen-950 Rider Verification — Session Status & Self-Review

**Point-in-time:** 2026-10-26 10:46 CET
**Session scope:** the resumed verification turn only ("Is caddy superbly setup now?" + this report). The prior session's run is documented in `2026-10-26_08-56_caddy-edge-live-battery-full-status.md` (+ its 10:4x addendum, appended this session). Nothing outside this session's own work is re-researched, per instruction.

**Context in one line:** a parallel session deployed **gen-950 at 09:36** (opencloud NATS batch, lineage after `706659d05`), carrying the prior session's three riders; this session ran the §e live-verification, closed the todo rows, and corrected three pieces of drift it found on the way.

---

## a) FULLY DONE (this session)

| # | Item | Live evidence |
| --- | --- | --- |
| a1 | **`:4318` span fix verified live** | 2,685 `caddy` spans in 30 min in `signoz_traces.distributed_signoz_index_v3`; journal flood dead — last `malformed HTTP response` 09:35:53, zero since the 09:37 restart (was ~100 lines/s / 381k rows/h) |
| a2 | **Coverage gauge green** | `signoz_traces_reporting{service="caddy"} 1`, `signoz_traces_last_span_age_seconds 9` — tonight's ~23:05 false-page risk from the 26h budget is gone (spans live ~14h before expiry) |
| a3 | **Branded static 404 verified live** | `timers.home.lan` unknown path → `404` + branded `<title>404 - Nothing here</title>` page (1633 B static); `/` stays 200 (no SPA-index leak) |
| a4 | **`/dex/healthz` log_skip rider live** | `@probe path … /dex/healthz` + `log_skip @probe` confirmed rendered in live `/etc/caddy/caddy_config` (matcher present in all site blocks) |
| a5 | **Sampling-policy row closed** | No tail/probabilistic sampler anywhere in the traces pipeline (`memory_limiter → signozspanmetrics/delta → batch → clickhousetraces + servicegraph`) — 100% span policy, confirmed by config grep + live volume; documented in `docs/services/caddy.md` §Edge tracing |
| a6 | **Todo rows closed** | `docs/todo/monitoring.md`: edge-tracing deploy row `[blocked:deploy]`→`[x]` with receipt; sampling row `[ready]`→`[x]`; span UX pass `[blocked:deploy]`→`[ready]` (blocker gone) |
| a7 | **Runbook receipts + query correction** | `docs/services/caddy.md` §Edge tracing: fix-live receipt, no-sampler note, and **corrected the verify query** (see d1) |
| a8 | **Own stale comment fixed** | `caddy.nix:291` still said "Exporter: gRPC … grpc-url" after the `7adaabf04` HTTP fix — corrected; parse-checked (`nix-instantiate --parse` OK), `nix fmt` 0 changes |
| a9 | **Addendum appended** to the 08-56 report | Post-deploy verification table + "owner Q2 moot" note |
| a10 | **Sampling-question false-premise risk closed** | Row 175's feared failure mode (silently-dropped spans → false coverage page) is disproven live; the 26h budget is trustworthy for caddy |

## b) PARTIALLY DONE

| # | Item | What's missing |
| --- | --- | --- |
| b1 | `/dex/healthz` end-to-end | Config-presence verified locally; the actual gatus check targets the **pbx host** (`netbird.larsartmann.cloud`) — its green state was NOT verified (out of this host's reach this session; my probe against evo-x2's caddy with that SNI correctly 404'd — wrong target, no vHost here) |
| b2 | Span-volume baseline | One 30-min sample (2,685 spans, ~10:40, human/probe traffic). No quiet-window baseline yet — row 176 (coverage budget semantics) still lacks the data to decide `env`-vs-`event`-vs-warm-probe |
| b3 | Access-log noise audit for `@probe` | The `log_skip` matcher is rendered (a4) but its *effect* (no access-log lines for gatus probe paths) wasn't observed directly — cheap one-read check, folded into the UX pass (f1) |

## c) NOT STARTED (time-gated or owner-gated, not begun)

- **Span UX pass** (monitoring.md row 177, now `[ready]`): spanmetrics cardinality audit (assert series set ≈ vHost count), per-vHost span panels in SigNoz, attribute-completeness check, `forward_auth` subrequest span sanity on auth.<domain>, Services-page grouping probe.
- **G3 FP-window review** (per-host 5xx rule at 0.1 req/s): needs 24–48h of live alert data; watch rows already queued from the 08-56 report.
- **Eval-rail hardening** (see e3): audit protocol↔port agreement, not just URL shape.
- Owner questions 1–3 from the 08-56 report: Q1 (deploy ownership) answered by events; **Q2 moot** (a2); **Q3 still open** (g).

## d) TOTALLY FUCKED UP (all owned, all corrected this session — zero unrecovered damage)

| # | Fuckup | Correction |
| --- | --- | --- |
| d1 | **The shipped §e verify-recipe query was WRONG from authoring time** (prior session, same operator-me): `…distributed_signoz_index_v3 WHERE serviceName = 'caddy'` — `serviceName` is NOT a column in v3 (it lives in `resources_string['service.name']`); the documented probe would ERROR, and my first probe this session (`distributed_signoz_spans`, the dead pre-v3 view) returned a misleading **0** that, taken at face value, said "fix still broken." Two wrong probes before the right one. A documented verification recipe that was never executed once. | Query corrected in caddy.md with the schema trap explained (legacy view is dead; column is a map access) |
| d2 | **My `7adaabf04` fix corrected 2 of 3 surfaces**: env endpoint + audit expectation, but not the adjacent tracing-block comment (`caddy.nix:291`) still asserting gRPC/grpc-url. It survived a full closeout report and only surfaced when the owner asked a follow-up. Direct repeat of the "correction must NAME all corrected surfaces" class. | Comment fixed (a8); lesson recorded here |
| d3 | **Wrong-IP live probe**: first TLS probe hit `192.168.1.200:443` = **dnsblockd's block page** ("Domain Blocked · timers.home.lan", HTTP 200!) — on a different framing that's a false "404s broken" verdict from a 200-on-unknown-path. Caddy edge is `192.168.1.150` on this box right now. | Retried on .150 → correct verdicts (a3); IP map queued for the runbook (f8) |
| d4 | **`rg -rn` typed** — the REPLACE-flag trap, third strike host-wide per the hook's own counter. Blocked by hook, no damage, but it's a documented AGENTS.md rule and I typed it anyway. | Hook caught it; `rg -n` used after |
| d5 | **Two stale-read edit attempts** ("file modified since read" on monitoring.md and the 08-56 report) — parallel sessions (fast-todo wave `d5cd73e98`, daemon) were KNOWN active; the content-pin rule says re-read before edit, and I edited first, re-read second. Both retries landed clean on unchanged content. | Re-read then edit; no window where I overwrote anyone |

## e) WHAT WE SHOULD IMPROVE (the self-review, answered)

1. **What did you forget?** The comment surface (d2), and that a "recipe" in a runbook is a *claim* — it must be RUN once before it's documented (d1). I also forgot the probe-IP map exists nowhere (d3/f8).
2. **What is stupid that we do anyway?** Shipping verification queries against schemas we never introspected; probing by IP without confirming which listener owns the IP; letting "0 rows" from a possibly-dead view stand as evidence of absence.
3. **What could you have done better?** DESCRIBE the table (`DESCRIBE`) before querying it — the v3-vs-legacy-view confusion was one command away. Same for listeners: `ss -ltnp` output was in front of me before the first probe; resolving owner-IP first costs nothing.
4. **What could you still improve?** The audit rail (e3): `otel-endpoint-audit` validated URL shape, not exporter-protocol↔port-kind agreement — that's WHY the :4317 bug passed eval. Make the rail assert the pairing (exporter kind ↔ port registry kind).
5. **Did you lie to you?** No claim in this session's outputs was unsupported; but the prior session's "ClickHouse serviceName='caddy' = 0/6h" dark-spans evidence was anecdote-adjacent (the flood journal was the real evidence; the query itself was broken per d1). Conclusion was right, probe was not. Noted so it isn't repeated as a pattern.
6. **Ghost systems / split brains?** None created this session. Found one schema trap (dead `distributed_signoz_spans` view still queryable, silently 0) — not a ghost system, but a landmine; sweep queued (f4). No split brains: queue and library rows were edited together, report addendum points at row closures.
7. **Scope creep?** No — this stayed inside verify-and-closeout. The one reach (IP-map doc line) is queued, not improvised into AGENTS.md mid-report.
8. **Tests?** Nothing this session needed a new test (comment/doc edits only). The VM-pin debt from the prior session's riders is already landed (`7adaabf04`). The rail-hardening item (f5) should carry a negative-test leg in `scripts/negative-test-lints.sh` like its siblings.

## f) NEXT — up to 50, session-scoped (NEW = harvested this pass; rest = pointers, not re-queued)

**New from this session (harvested to TODO_LIST.md + domain libraries at authoring time):**

1. **[NEW, ready]** Sweep all runbooks/docs for dead-view ClickHouse queries (`distributed_signoz_spans`, bare `serviceName =` predicates) — the d1 trap likely replicates (signoz.md, other §-verify recipes). → monitoring.md
2. **[NEW, ready]** Harden `otel-endpoint-audit`: assert exporter-protocol↔port-kind agreement (otlp-http exporter must point at the HTTP port), not just URL shape; negative-test leg alongside. → monitoring.md (rail)
3. **[NEW, ready]** Verify the netbird `/dex/healthz` gatus check green end-to-end (pbx-side dex; probe via gatus API or owner) — b1. → services.md
4. **[NEW, watch]** Quiet-window caddy span-volume baseline (one full quiet day) → feeds row 176's coverage-budget semantics decision. → monitoring.md
5. **[NEW, ready]** Document the live 443-listener map in caddy.md (`.150` caddy edge, `.200` dnsblockd block page — resolve via `ss -ltnp`, note as perishable) — d3. → services.md

**Existing backlog surfaced/touched by this session (already queued — do NOT duplicate):**

6. Span UX pass (monitoring.md row 177, now `[ready]`): cardinality audit, per-vHost panels, attribute completeness, forward_auth subrequest spans, Services-page grouping.
7. G3 per-host 5xx FP-window review at 24–48h (watch rows from 08-56 report).
8. Row 176: coverage budget semantics (env/event/warm-probe) — owner decision, informed by f4.
9. Prune pass for the two new `[x]` rows in monitoring.md (`scripts/prune-done-todos.sh`, dry-run first; expect WARN-count rise per the unmasking rule).
10. The 08-56 report's §f backlog (≈50 ranked items) remains the dispatch source; this session closed 2 of them and unblocked 1.

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **G3 (carried from 08-56 Q3):** keep the per-host 5xx defaults (0.1 req/s, 5m, warning) through the 24–48h FP window — my recommendation — or retune now?
2. **Dispatch priority:** next caddy-adjacent dispatch = span UX pass (f6, now `[ready]`), the audit-rail hardening (f2), or hold both until the G3 FP-window data lands?
3. **Coverage budget philosophy (row 176):** decide caddy's `env`-vs-`event`-vs-warm-probe semantics NOW on principle, or wait for the f4 quiet-window baseline? (Determines whether f4 stays a watch row or gets promoted.)

---

*Report scope: this session's run only. Self-review answers embedded in §e per the brutal-honesty contract. Format: `.md` at explicit owner demand (skill-canonical is HTML; override honored).*
