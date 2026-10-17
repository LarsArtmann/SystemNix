# Status Report — Z.ai 1113 Outage Diagnosis, ai-meter Endpoint Fix, SigNoz Integration

- **Date**: 2026-10-17 08:58 CEST
- **Session started in**: `AI-von-Art-Bench` (cwd; none of that repo's code was touched — the entire session was host-level: ai-meter / Z.ai / SigNoz / SystemNix)
- **Scope of this report**: THIS session's run only, as instructed. No unrelated research.

## Incident summary (what this session was about)

New crush instances failed with `429 "Insufficient balance or no resource package. Please recharge."`
(Z.ai error code **1113**).

**Root cause (verified by direct A/B test, not inferred):**

1. `~/.config/crush/crushrc:62` overrides crush's built-in zai provider to route through the
   local ai-meter proxy (`127.0.0.1:8107/v1/zai`) — deployed 2026-10-16 with ai-meter itself.
2. ai-meter's zai upstream pointed at Z.ai's **general** endpoint
   (`https://api.z.ai/api/paas/v4`), while crush's built-in default is the **coding** endpoint
   (`https://api.z.ai/api/coding/paas/v4`).
3. The account bills via a **GLM Coding Plan resource package that only applies at the coding
   endpoint**. The general endpoint's pay-as-you-go balance hit zero ~03:30 on 2026-10-17 →
   every proxied request 1113'd.
4. A/B verification with the same key: general endpoint → 1113 on every request and model;
   coding endpoint → **200 OK for both glm-5.3 and glm-5.3-flash**, instantly.
5. "Old instances worked" was an illusion: crush's retry backoff (5/10/20s) occasionally landed
   a success (~7% success rate on glm-5.3 at peak failure).

Proxy metrics at diagnosis time (since 02:25 restart): glm-5.3 **3×200 vs 40×429**,
glm-5.3-flash **22×200 vs 100×429**.

## a) FULLY DONE

1. **Root-cause diagnosis** — reproduced live (3× tiny requests through the proxy → 3× 1113),
   isolated streaming vs non-streaming as a red herring, A/B-verified general vs coding
   endpoint with the same key, confirmed both crush models work on coding endpoint.
2. **Fix staged**: `SystemNix/modules/nixos/services/ai-meter.nix` zai upstream
   `base_url` → `https://api.z.ai/api/coding/paas/v4`, with an incident-rationale comment
   (verified date, endpoints, both models). Auto-committed as `2850715b`.
3. **WebUI question answered**: ai-meter has NO webui — admin plane `:8108` serves exactly
   `/metrics` (Prometheus text) and `/health` (JSON); `reports/` dir is empty; SigNoz is the
   intended visualization layer.
4. **SigNoz integration audit**: scrape job `ai-meter` (signoz.nix:1314, gated on
   `services.ai-meter.enable`) ✅; live ingestion verified — every `ai_meter_*` family present
   in ClickHouse with 0s-fresh samples via `:8080/api/v1/query` ✅; dashboards referencing
   `ai_meter` before this session: **zero of 9**; alert rules: **zero**.
5. **New dashboard** `modules/nixos/services/dashboards/ai-meter.json` — 13 panels (success
   rate, req/min, non-2xx/min, in-flight, spend rate + total, requests by model×code,
   failures by code, tokens by kind, avg TTFT, spend by model, metering errors, unauthorized).
   **Every PromQL expression was validated against the live SigNoz API before writing**
   (all returned `success`). `$ref` layout integrity asserted. v6 schema matched against the
   existing browser-history.json template. Wired into `_signoz-alerts.nix` dashboards attr.
6. **New alert rule** `ai-upstream-failure-rate.json` — critical, >30% routed-call failure
   over 10m, Discord channel via mkRule. Would have fired within minutes of this morning's
   outage (~85–93% failure for hours, zero signal). Wired into rules attr.
7. **Validation**: `nix-instantiate --parse` green on `_signoz-alerts.nix`; dashboard JSON
   parse + ref-resolution green. Auto-commit daemon captured everything (working tree clean:
   fix in `2850715b`, dashboard+alerts in `86316f73`).
8. **Cost-data question answered**: costs come from a hand-maintained static Nix table
   (`services.ai-meter.costs`, USD per 1M tokens) mirrored from the crushrc price flags —
   NOT from provider billing APIs. Tokens exact; unknown models cost $0.

## b) PARTIALLY DONE

1. **The fix is staged, NOT deployed.** The running ai-meter still points at the general
   endpoint. Needs `cd ~/projects/SystemNix && nix run .#deploy` (restart drops all in-flight
   AI calls: ~17 crush instances + tq agent-pool).
2. **The outage self-recovered ~05–08h** (live query showed ~96% success, 18.9 req/min at
   08:4x) — **why it recovered was never root-caused** (hypotheses: coding-plan window reset,
   residual balance trickle; unverified). Recurrence is expected until deploy.
3. **Dashboard + alert staged but never provisioned/rendered** — custom unit strings
   (`{percent}`, `{req/min}`, `{USD/h}`) are patterned on browser-history's `{count}` but
   untested against actual SigNoz rendering. Panels could render with odd or missing units.
4. **Cost metering blind spot known and left in place**: glm-5.3 — the PRIMARY model — has no
   cost entry → $0 forever; the new spend panels understate total spend by design until an
   entry exists.
5. **Module eval not verified** — only syntax parse ran; no `nix eval` / `nix flake check`
   (would have caught a typo in the new attr merges; parse cannot).

## c) NOT STARTED

1. Deploy of everything above.
2. `telemetry-coverage.json` extension for the ai-meter scrape job — the repo's own
   "scrape-coverage doctrine" (every scraped job appears in the coverage dashboard) was
   violated by ai-meter since 2026-10-16 and I repeated the violation by adding a separate
   dashboard instead of also extending coverage.
3. ~~`docs/services/ai-meter.md` runbook update~~ DONE 2026-10-17: coding endpoint in the
   routing table, billing/1113 semantics, incident cross-link, and plan specs added.
4. **Blast-radius check for other ai-meter clients**: paperless-gpt and inboxclean are
   documented consumers of the proxy. If any routes zai, they were silently 1113-failing all
   morning too. Never checked (metrics showed only `client="crush"` — suggestive but not
   proof of configuration, only of traffic).
5. Coding-plan concurrency tier fact-check — ANSWERED 2026-10-17: Max Yearly. Caps are
   officially unpublished ("Max > Pro > Lite", dynamically adjusted, higher off-peak;
   quota 28k credits/5h, 140k/week) → the real cap must be measured empirically from
   post-deploy "Rate limit reached" 429 rates under the ~17 concurrent instances.
6. SystemNix AGENTS.md/docs knowledge capture of this debugging session (admin :8108,
   ledger `/var/lib/ai-meter/usage.jsonl`, crushrc override location).

## d) TOTALLY FUCKED UP!

Nothing destructive: no wrong fix shipped, no data lost, no service broken by me. But honest
dirty laundry:

1. **Secrets hygiene slip**: during testing I passed the Z.ai API key as a **python argv
   argument** (`python3 - "$key"`) — briefly visible in `ps` output to any local user.
   Should have used stdin or an env var. Single-user host, low impact, still sloppy.
2. **Commit-message quality surrendered**: the outage fix and the SigNoz integration landed
   as `chore: auto-commit N changed file(s) (heuristic)` commits (`2850715b`, `86316f73`)
   because I left the working tree for the daemon. The most important host fix of the week is
   now buried under a junk message with no incident reference.
3. **Claimed line-precision I didn't have**: first-turn summary cited "ai-meter.nix:83" for
   the fix — the URL actually landed on a different line after the edit (the comment block
   shifted it). Minor, but it was stated as fact.
4. **"Old instances kept working" was asserted with ~7%-success-rate evidence** — the real
   mechanism (retry-lottery) was only pinned down later in the session; the early framing
   overstated stability.

## e) WHAT WE SHOULD IMPROVE!

1. **Deploy-and-verify loop**: fixes declared done at "file edited + parsed". The bar must be
   "deployed + behavior observed" (one proxy probe post-deploy would have closed it).
2. **Incident discipline**: root-cause fixes should carry a real commit message referencing
   the outage, and update the owning runbook in the same change — not rely on the heuristic
   daemon.
3. **Doctrine compliance reflex**: the codebase TOLD me about scrape-coverage (crowdsec
   comment) and I still shipped a parallel dashboard without extending coverage. Read the
   local doctrine, then follow it, in that order.
4. **Fail-fast in the proxy**: ai-meter passes upstream 1113 through verbatim, which
   masquerades as a crush-side failure and costs hours of misdiagnosis. A per-upstream
   health gate (circuit breaker, or at minimum a rewritten error naming the upstream and
   original code) would localize the next incident to seconds.
5. **Idle-host alerting gap**: my failure-rate rule needs traffic to fire. A dead account on
   an idle host stays silent. A tiny scheduled canary probe per upstream (1 token/min) closes
   this.
6. **Debuggability of the proxy for the primary user**: ledger is root-only, logs are 2 lines,
   admin has no recent-records view. Every future incident starts with "can't see the data".
7. **Cost table completeness**: every routed model should have an entry or an explicit
   plan-covered marker; "unknown = $0" silently corrupts every spend number downstream.

## f) Up to 50 things to get done next

**P0 — close out this incident (do today)**
1. Deploy: `cd ~/projects/SystemNix && nix run .#deploy` (ships endpoint fix + dashboard + alert).
2. Post-deploy probe: tiny request via `127.0.0.1:8107/v1/zai` → expect 200 off coding plan.
3. Eyeball the provisioned "AI Meter" dashboard in SigNoz — verify panels render, units sane.
4. Verify the alert rule appears enabled in SigNoz UI with the Discord channel attached.
5. Root-cause the self-recovery (ledger/journal timeline 03:00–09:00) — know WHY before
   trusting the fix.
6. Check paperless-gpt + inboxclean configs for zai routing; fix/notify if they 1113'd too.
7. Write a proper follow-up commit or tag referencing the incident on top of the heuristic
   auto-commits.

**P1 — hardening (this week)**
8. Extend `telemetry-coverage.json` with the ai-meter job (doctrine compliance).
9. Update `docs/services/ai-meter.md` runbook: coding vs general endpoint, 1113 semantics,
   incident timeline, verification commands.
10. ~~Add glm-5.3 cost-table entry~~ DONE 2026-10-17: glm-5.3 added at official PAYG
    reference prices (1.4/4.4/0.26, docs.z.ai/guides/overview/pricing); semantics per g3 —
    reference visibility, real marginal spend is plan-covered $0.
11. Canary probe per cloud upstream (cron/systemd timer → 1-token request; alert on non-200)
    so idle hosts still detect dead accounts.
12. ai-meter: per-upstream circuit breaker / error rewriting (fail fast, name the upstream).
13. Run `nix flake check` (or full module eval) on SystemNix — the session only parse-checked.
14. ~~Concurrency tier fact-check~~ DONE 2026-10-17: Max Yearly; caps officially
    unpublished (quota 28k credits/5h + 140k/week; concurrency only "Max > Pro > Lite") —
    documented in the runbook. Empirical cap measurement remains open via post-deploy 429s.
15. Consider taming concurrency at the source: tq agent-pool size / crush instance count vs
    plan caps.
16. Admin endpoint on :8108 serving recent ledger records (readable by primary user) —
    incident triage without root.
17. Add a `docs/status` cross-link in the ai-meter module header pointing at this report.

**P2 — quality of the observability layer**
18. Dashboard: add an "upstream error message" panel dimension if/when ai-meter exposes
    upstream error codes as labels (currently only HTTP status — 1113 vs RPM-limit are
    indistinguishable in metrics).
19. Dashboard: per-client breakdown panels once a second client (paperless-gpt/inboxclean)
    actually routes through the proxy.
20. TTFT: add p95 once histogram buckets exist (only sum/count today → mean only).
21. Alert: second-stage warning rule at 10% failure for early noise.
22. Alert: `ai_meter_unauthorized_total > 0` rule (key leakage/rotation botch detector).
23. Alert: `ai_meter_metering_errors_total` increasing (ledger write failures = data loss).
24. Alert: `ai_meter_active_requests` sustained high (stuck streams).
25. Review SigNoz retention/scrape interval for ai-meter (5m default may hide short bursts).

**P3 — ai-meter product improvements**
26. Multi-key support per upstream (rotation/pool) — would also mitigate plan concurrency.
27. Retry-with-jitter at the proxy for 429s (bounded), so single-user bursts self-heal.
28. Usage-quota awareness: track per-model monthly token totals; alert at 80% of plan quota.
29. Structured request logging (JSONL) with status + upstream error code, root-readable.
30. Config test: `ai-meter -check-config` mode for cheap pre-deploy validation.
31. Consider OpenTelemetry trace export for routed calls (correlate crush session → upstream).
32. Version the ledger schema; add rotation/compaction.
33. Unit tests for the cost table application (cached-input subset math).

**P4 — knowledge capture**
34. SystemNix AGENTS.md: ai-meter debugging cheat-sheet (admin :8108, metrics families,
    ledger path, crushrc override interplay).
35. crush-config repo: note that provider base-url overrides silently change billing
    semantics (the 2026-10-16 ai-meter rollout did this invisibly).
36. Add the "verify the delivering layer" lesson: staged-but-undeployed fixes are Schrödinger
    fixes — treat deploy as part of done.
37. Consider a host-level "AI provider matrix" doc: provider × endpoint × plan × key owner.

**P5 — backlog-adjacent (lower confidence, parked)**
38. Explore whether crush should get a provider-health hint (env or file) from ai-meter to
    fail over to fallback providers faster.
39. Evaluate exposing ai-meter as a systemd socket-activated service (idle = no exposed
    surface).
40. Track Z.ai status page/feed for provider-side incidents (dedupe with canary alerts).
41. Monthly cost report generation from the ledger (reports/ dir exists, is empty).
42. Dashboards as code linting: assert every dashboard JSON's refs resolve in CI (the check I
    ran manually).
43. golangci-lint pass over pkgs/ai-meter (stdlib-only, likely trivial findings).
44. Add a VM test asserting the coding-endpoint base_url (the class of bug this session hit).
45. Document why crush zai override exists at all (metering) IN the crushrc comment —
    currently the billing-semantics change is implicit.
46. Re-key rotation drill: verify ai-meter client key re-mint procedure works after reboot.
47. Review whether gemini/kimi upstreams in ai-meter have the same plan-vs-endpoint mismatch
    risk as zai did (same class, different providers).
48. Consider alerting on `ai_meter_cost_usd_total` rate vs a monthly budget.
49. Check SigNoz provisioning idempotency: re-running deploy must not duplicate dashboards.
50. Time-box a decision: keep tq agent-pool on zai or move to a dedicated cheaper provider.

## g) Questions I can NOT figure out myself

1. **Deploy timing**: OK to run `nix run .#deploy` right now? It restarts ai-meter and drops
   every in-flight AI call on the host (this session, ~17 crush instances, tq agent-pool) —
   or should it wait for a quiet window you pick?
2. **GLM coding plan tier — ANSWERED 2026-10-17: Max Yearly.** Concurrency is officially
   unpublished (docs.z.ai/devpack/usage-policy: "Max > Pro > Lite", dynamically adjusted,
   higher off-peak) — the real cap behind the "Rate limit reached" 429s stays an empirical
   question; watch post-deploy 429 rates. Quota is credit-based since 2026-07-30
   (docs.z.ai/devpack/overview: Max = 28,000 credits/5h, 140,000/week) and the plan covers
   exactly glm-5.3 + glm-5.3-flash (glm-4.7 auto-routes to flash) — both crush models, so
   ~17 instances is a concurrency question, not a model-coverage one.
3. **Cost semantics for glm-5.3 — DECIDED 2026-10-17: PAYG reference prices.** Owner
   chose reference-cost visibility over plan-covered $0: `services.ai-meter.costs` carries
   glm-5.3 1.4/4.4/0.26 and glm-5.3-flash 0.15/0.5/0.03 (official rate card:
   docs.z.ai/guides/overview/pricing). Spend panels show what the traffic WOULD cost
   pay-as-you-go — real marginal spend on Max Yearly is $0 (billed in credits, not
   tokens), so reference spend overstates by design.

---

*Point-in-time snapshot. Report format: `.md` at explicit user demand (skill default is HTML);
written to SystemNix (where all session work lives), not the session's cwd repo. Committed by
the auto-commit daemon per harness rules. **ALL THREE QUESTIONS RESOLVED 2026-10-17: g2 =
Max Yearly, g3 = PAYG reference prices, g1 = deploy approved and executed.***
