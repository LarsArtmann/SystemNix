# ai-meter — transparent metering proxy for all OpenAI-compatible AI calls

> Layer: `modules/nixos/services/ai-meter.nix` · Binary: `pkgs/ai-meter/` (in-tree Go, stdlib only, vendorHash = null) · Enabled: evo-x2 (`configuration.nix`)

## What it is

Every OpenAI-compatible AI call on the host flows through one loopback proxy that meters **tokens, cost, latency, TTFT and per-client attribution** without changing any model name or request shape. Born from the 2026-10-16 [Agent Router evaluation](../research/2026-10-16_agent-router-deep-dive.html): the owner wants metrics + metering for ALL AI calls; Agent Router's packaging cost buys governance this single-user host doesn't need, so the exact-scope replacement is ~700 lines of owned Go.

| Surface | Port                      | Purpose                                                                             |
| ------- | ------------------------- | ----------------------------------------------------------------------------------- |
| Proxy   | `ai-meter` (8107)         | `/v1/<upstream>/<path>` — per-client Bearer key required; `/health` unauthenticated |
| Admin   | `ai-meter-metrics` (8108) | Prometheus `/metrics` (scraped by SigNoz), `/health`                                |
| Viewer  | — (`ai-meter.home.lan`)   | Static page embedding the SigNoz ai-meter dashboard (Layer 2 protected, LAN bypass) |

The proxy + admin planes are loopback-only (infrastructure, not a user surface).
"How to view the meter" = `https://ai-meter.home.lan` (embeds the SigNoz
"AI Meter — Routed AI Calls" dashboard in an iframe; the signoz registry entry
allows that origin via `vHost.frameAncestors`, which drops the global
X-Frame-Options for signoz only). The dashboard's SigNoz UUID is pinned as
`dashboardId` in `modules/nixos/services/ai-meter.nix`; the "ai-meter
dashboard" gatus check fails loud if a dashboard recreation mints a new id
(lookup command in that comment). What each panel shows, where its number
comes from and how to change the dashboard: [Dashboard](#dashboard).

## Routing

Path-based, so client model vocabularies stay identical everywhere:

```
crush provider zai        → http://127.0.0.1:8107/v1/zai/chat/completions        → https://api.z.ai/api/coding/paas/v4
crush provider gemini      → http://127.0.0.1:8107/v1/gemini/v1beta/models/<m>:streamGenerateContent
                           → https://generativelanguage.googleapis.com (NATIVE genai protocol, X-Goog-Api-Key)
paperless-gpt             → http://127.0.0.1:8107/v1/fastflowlm/chat/completions  → 127.0.0.1:52625 (FastFlowLM)
inboxclean chat           → http://127.0.0.1:8107/v1/llama-chat/chat/completions  → 127.0.0.1:8850 (llama.cpp)
browser-history AI        → http://127.0.0.1:8107/v1/llama-chat/chat/completions  → 127.0.0.1:8850 (llama.cpp)
cv coaching + tailor      → http://127.0.0.1:8107/v1/synthetic/chat/completions   → https://api.synthetic.new/openai/v1
                            (CV_COACHING_API_KEY / CV_TAILOR_API_KEY = minted client keys;
                             syn:large:text; chat stays on its DIRECT sops key — unmetered,
                             queued follow-up)
(+ llama-embeddings upstream declared; unused ones cost nothing; openrouter dropped 2026-10-17 — `openrouter_api_key` was never set in sops; kimi removed 2026-10-27, owner directive "do not use anymore" — zero traffic since the deploy; synthetic added 2026-11-12 — remapped sops copy of crush-daily.yaml `synthetic_api_key`, no costs entry: no verified pricing, tokens meter exactly at $0)
```

The proxy is TRANSPARENT: bodies pass through untouched except one opt-in injection — `stream_options.include_usage: true` on streaming requests that lack it, so the final SSE chunk carries the usage block the metering needs. `inject_stream_usage: false` in the rendered config disables it. Native genai traffic is exempt from the injection (genai bodies would reject the foreign field); its usage comes from `usageMetadata` instead (genai.go adapter, 2026-10-17).

zai routes to the **coding** endpoint (`/api/coding/paas/v4`), NOT the general one: the account bills via a GLM Coding Plan (**Max Yearly**) resource package that only applies there — the general endpoint has zero pay-as-you-go balance and 429s with code 1113 "Insufficient balance or no resource package" (2026-10-17 outage; incident report: `docs/status/2026-10-17_08-58_zai-1113-outage-ai-meter-fix-signoz-integration.md`). Per docs.z.ai the plan covers exactly glm-5.3 + glm-5.3-flash (older ids auto-route), quota is credit-based (Max: 28,000 credits/5h, 140,000/week), and concurrency is unpublished ("Max > Pro > Lite", dynamically adjusted, higher off-peak) — billing rejections and rate limits both arrive as HTTP 429, so watch the upstream error body, not just the status code.

## Secrets & clients

- **Upstream provider keys**: sops COPIES owned by the `ai-meter` user (`ai-meter-{zai,gemini}-key` → crush.yaml keys; `ai-meter-synthetic-key` → crush-daily.yaml `synthetic_api_key`, 2026-11-12). Independent of the source blocks' enablement. The openrouter copy was dropped 2026-10-17: `openrouter_api_key` was never set in `openseo.yaml`, which made sops manifest validation refuse the whole deploy — re-add only after setting that key. The kimi copy was removed 2026-10-27 with the kimi upstream (owner directive; zero traffic ever, so no consumers to break).
- **Client keys**: RUNTIME-MINTED by the `ai-meter-keys` oneshot (`openssl rand -hex 24` → `/run/ai-meter-keys/<client>`, 0400, owned by the consumer's user). Never in the repo, never in sops. Keys live for the boot; existing keys are NEVER regenerated (a silent rotation would 401 running consumers).
- **Two-copy mint (2026-10-17)**: the daemon (`ai-meter` user) cannot read consumer-owned 0400 files — the first VM run start-looped on exactly that. Each key therefore ALSO exists as an `ai-meter`-owned 0400 mirror at `/run/ai-meter-keys/config/<client>` (dir 0700); the proxy config points ONLY at the mirrors, and the mint re-syncs each mirror (`install`) on every run so the pair can never diverge.

| Client            | Key consumption                                                                                                                                                | Routed via           |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `crush`           | raw file, `$(cat /run/ai-meter-keys/crush)` in the crushrc `extraRc` (home.nix) — overrides `zai` + `gemini` base URLs; later provider-add statements win      | zai, gemini (native) |
| `paperless-gpt`   | env file `OPENAI_API_KEY=…` on the daemon unit                                                                                                                 | fastflowlm           |
| `inboxclean`      | env file on `inboxclean-web`                                                                                                                                   | llama-chat           |
| `browser-history` | env file `LLM_API_KEY=…` (root-owned mint copy — DynamicUser server has no stable uid; systemd reads the file as root) on the `browser-history` unit           | llama-chat           |
| `cv-coaching`     | env file `CV_COACHING_API_KEY=…` on `cv-server` (OPTIONAL `-` prefix: missing file = coaching/letters degrade to the 503/template shape, never a boot failure) | synthetic            |
| `cv-tailor`       | env file `CV_TAILOR_API_KEY=…` on `cv-server` (same optional shape)                                                                                            | synthetic            |

Adding a consumer = add a `services.ai-meter.clients.<name>` entry (user + optional `envKey`) + point the app's base URL at `/v1/<upstream>`. The deploy.sh provisioner loop re-runs `ai-meter-keys` so the key exists before the restarted daemon references it.

## Metrics & ledger

Prometheus families on :8108 (job `ai-meter`, SigNoz collector):

- `ai_meter_requests_total{client,upstream,model,code}`
- `ai_meter_tokens_total{client,upstream,model,kind=prompt|completion|cached}`
- `ai_meter_cost_usd_total{client,upstream,model}` — CUMULATIVE since the ledger began: replayed from it at every start at the CURRENT table in `services.ai-meter.costs` (USD per 1M tokens; zai entries are PAYG REFERENCE prices — docs.z.ai/guides/overview/pricing: glm-5.3 1.4/4.4/0.26, glm-5.3-flash 0.15/0.5/0.03, the latter mirroring the crushrc — even though the Max Yearly coding plan bills credits, not tokens, so real marginal spend is $0; owner chose reference visibility 2026-10-17, spend panels overstate by design; unknown/local models cost $0 but meter tokens exactly). The only family that is replayed; every other counter keeps its restart-reset semantics (see Restatement)
- `ai_meter_request_seconds_{sum,count}`, `ai_meter_ttft_seconds_{sum,count}` (streaming only: a non-streaming call meters tokens and duration but adds no TTFT sample), `ai_meter_active_requests{client,upstream,model}` (calls inside the proxy right now; `model="none"` until the request body names one), `ai_meter_start_time_seconds` (process start), `ai_meter_unauthorized_total`, `ai_meter_metering_errors_total` (recording failures that did NOT fail live traffic — watch this: nonzero means usage blocks are going missing)
- `ai_meter_spans_exported_total{outcome=ok|failed|dropped}` — one GenAI span per routed call handed to SigNoz's OTLP endpoint, which is what fills SigNoz's AI observability views (export added 2026-11-25)
- Admission families, since admission control went live on 2026-11-25: `ai_meter_admission_{inflight,waiting,limit}{upstream}`, `ai_meter_admission_outcomes_total{client,upstream,model,outcome}`, `ai_meter_admission_wait_seconds_{sum,count}`, `ai_meter_upstream_rejections_total{upstream,model,code,kind}`, `ai_meter_quota_exhausted`. The dashboard's Admission section reads them.

Durable ledger: `/var/lib/ai-meter/usage.jsonl` — one JSON object per call, FACTS ONLY (client, upstream, model, status, token counts, durations). It stores no cost on purpose: cost is a derivation (tokens x the price table), the table changes, and a stored cost would go stale the moment it does. The ledger is the true-up source; Prometheus counters reset on restart, the ledger does not.

### Restatement: a price row that lands late

A model is routinely used before its price is published (glm-5.4 from 2026-11-24: tokens metered exactly, cost $0). Adding its row to `services.ai-meter.costs` and deploying IS the whole backfill. There is no separate step:

| Surface | Where its number comes from | After the row ships |
| ------- | --------------------------- | ------------------ |
| Ledger | facts (tokens) | unchanged: nothing was ever wrong |
| `ai_meter_cost_usd_total` (the "Spend (all-time)" panel) | `Ledger.ReplayCosts` at every start, pricing each recorded call the ledger held when the replay began, at the current table | every earlier call of that model is priced; the counter steps up once, at the restart |
| "Spend Rate", "Spend Rate by Model", "Spend Rate by Client" and "Spend (24h)" panels | PromQL derived from the exact token counters x the current table (`_ai-meter-dashboard.nix`), recomputed at query time | the chart's whole history is restated at the true timestamps, with no spike |
| crush's own per-session cost | crush's `--price-*` flags on the model declaration, applied by crush itself | not an ai-meter surface; whether crush re-prices sessions it already recorded is unverified |

- The same mechanism restates a price that is CORRECTED or withdrawn, in either direction.
- The replay runs alongside serving, never ahead of it: the ledger grows without bound and its size must not decide how long routed calls fail after a restart (the real ledger's 866k calls replayed in 1.1 s on a calm box and in 12.6 s during an I/O storm, both measured 2026-11-25; serving started in under 0.2 s either way). The cost family is withheld from `/metrics` until the pass has ended, so the counter is only ever scraped whole; a call that lands meanwhile is added on top.
- Only the cost family is replayed. Re-baselining requests or tokens would read as one enormous spike in every rate() panel and in the "AI Upstream Failure Rate" ratio alert that consume them.
- A ledger line that does not parse (torn write, foreign content) is skipped at replay, counted in `ai_meter_metering_errors_total` and logged (`ledger has unparseable lines`); it never keeps the proxy from starting, because every routed call depends on it.
- `OpenLedger` terminates a final line that lacks its newline, so a torn write costs exactly one entry instead of two.

## Dashboard

`modules/nixos/services/dashboards/ai-meter.json` is the template. `services.ai-meter.dashboard` renders it through `_ai-meter-dashboard.nix`, and the signoz provisioner converges the result into the SigNoz dashboard `systemnix-ai-meter` (the UUID pinned as `dashboardId`). The live dashboard and the tree are the same document: a change to the template is not done until the rendered file was PUT to the pinned id and read back identical.

| Section                | Panels                                                                                                                                                                                                                                      | What to read off it                                                                                                                      |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| In flight (top)        | In Flight; In Flight: Provider x Model x Client; In Flight by Provider, by Model, by Client                                                                                                                                                 | who is waiting on the proxy right now; a provider pinned at its concurrency cliff is the shape behind the 429 storms                   |
| Traffic                | Requests / min; Success Rate (5m); Non-2xx / min; Calls (24h); Reachable; Process Uptime; Requests by Provider; Requests by Client; Requests by Model x Code; Failures by Code; Error Rate by Provider                                      | whether calls succeed, and which provider fails while the overall rate drops                                                            |
| Tokens & spend         | Tokens / min; Cache Hit Rate; Prompt / Call; Spend Rate; Spend (24h); Spend (all-time); Spend Rate by Model; Spend Rate by Client; Tokens by Kind; Tokens by Client; Models: Last 24 Hours                                                    | what the traffic would cost at the reference price table, per model and per client                                                     |
| Latency                | Avg TTFT; Avg Duration; Avg Output Speed; Avg TTFT by Model; Avg Duration by Model; Output Speed by Model                                                                                                                                   | the wait before the first byte (what a user feels) and the generation speed behind the provider                                        |
| Health                 | Starts (24h); Metering Errors (24h); Unauthorized (24h); Span Export Failures (24h); Traced Calls (24h); Metrics Freshness; Span Export by Outcome                                                                                          | whether the metering itself can be trusted                                                                                              |
| Admission (z.ai rate limit) | Quota Exhausted; Limit (now); Waiting (now); Rate-Limit Answers (24h); Quota Answers (24h); Calls Lost (24h); Admission: In Flight, Waiting, Limit; Admission Outcomes (24h); Avg Admission Wait; Provider 429 Answers / min        | how admission control does against z.ai's unpublished concurrency: its allowance, its queue, and the calls it could not save         |

Read Health before any other number: Metrics Freshness past two minutes means every panel is stale, and Metering Errors above zero means tokens are missing. The refresh is one minute, about 50 ClickHouse queries per minute while the dashboard is open (0.02 to 0.6 s each, measured 2026-11-25).

### Where each number comes from

- **Priced panels come from the renderer, never from the cost counter's rate or increase.** `Spend Rate`, `Spend Rate by Model`, `Spend Rate by Client` and `Spend (24h)` are PromQL generated by `_ai-meter-dashboard.nix` from the token counters and `services.ai-meter.costs`; each panel keeps its placeholder as the query. `increase(ai_meter_cost_usd_total[...])` reports a price restatement as spend (live 2026-11-25: 2414 USD in 24 hours against about 48 USD a day).
- **Tables and the pie chart run builder queries**, because the dashboard API refuses PromQL on them. The builder's `increase` drops each series' first bucket and the first bucket after a counter reset: within 3 % for dense counters (requests, tokens, admission outcomes), 32 % low for sparse ones (429 answers). Sparse counters are therefore PromQL panels: Rate-Limit Answers, Quota Answers, Calls Lost and Provider 429 Answers / min.
- **"24h" panels over the admission families count since those series exist** (19:06 on 2026-11-25, when admission control went live), so they show less than a day's worth until that time next day.

### Changing the dashboard

1. Edit the template. A spend panel keeps its placeholder as the query (`"query": "@@spendRateByClient@@"`); the renderer throws at eval unless every placeholder occurs exactly once, and `checks.ai-meter-spend-promql` refuses a dashboard without the four priced panels.
2. `nix build .#checks.x86_64-linux.signoz-query-lint .#checks.x86_64-linux.ai-meter-spend-promql`. The lint encodes the dashboard API's rules (layout, queries, unit ids, server-default keys), the guard holds the priced queries to the Go formula.
3. Render with the host's price table and run every panel query against the live engine, then look at the page in a headless browser. Both recipes: [monitoring.md](../agents/monitoring.md), "SigNoz dashboard authoring rules".
4. Go live with `PUT /api/v2/dashboards/<dashboardId>` and the rendered document, then read it back and compare `spec`. The provisioner makes the same PUT on the next deploy and skips the dashboard as unchanged from then on. Until that deploy the RUNNING generation still carries the previous file, so a signoz restart or a reboot puts that one back: the change is durable only after its deploy.

## Traps

- **gemini rides the NATIVE genai protocol** (probe 2026-10-17: crush v0.98.1's gemini provider = google-genai-sdk transport, `v1beta/models/<model>:streamGenerateContent?alt=sse`, `X-Goog-Api-Key` auth — even with a custom `--base-url`). The genai.go adapter handles all of it: client auth via the X-Goog-Api-Key channel, upstream auth via `auth_style = "x-goog-api-key"`, model-from-URL metering, `usageMetadata` extraction (thoughtsTokenCount folds into completion tokens), query-string preservation (`?alt=sse` is REQUIRED — dropping it silently changes the response format). No gemini models are declared in crushrc yet, so nothing routes there until one is `model add`-ed; gemini tokens meter exactly, cost $0 until a cost entry exists (no invented prices).
- **Key rotation**: delete `/run/ai-meter-keys/*` + restart `ai-meter-keys` + restart consumers — or just reboot (fresh mint at boot).
- **Metering must never break a call**: parse failures degrade to request-counting (`model="none"`, `usage_missing`) and increment `ai_meter_metering_errors_total` — check it before trusting dashboards.
- **hermes** calls GLM/MiniMax from its own app config — wiring it needs a hermes-repo change (open row in docs/todo/ai-stack.md).

## Checks

SigNoz rules reading these metrics (`_signoz-alerts.nix`): "AI Upstream Failure Rate High (>30%)", "Local AI TTFT High / Critical" (llama-chat), "AI Trace Export Failing", "AI Trace Export Silent" and "AI Traces Not Landing In SigNoz". Gatus: "ai-meter" (:8107/health, 200 + <500ms), "ai-meter metrics" (:8108/metrics, 200 + `pat(*ai_meter_requests_total*)`), "ai-meter viewer" and "ai-meter dashboard" (the pinned id still resolves). Eval gates: ports registered, port-registry audit (no literals), gatus coverage (both ports probed), deploy-restart-audit (ai-meter-keys in the deploy.sh provisioner loop), and the dashboard template must carry each of its four spend placeholders exactly once (`_ai-meter-dashboard.nix` throws at eval otherwise). `checks.signoz-query-lint` validates every dashboard file against the dashboard API's rules (`lib/signoz-dashboard-lint.nix`).

`checks.x86_64-linux.ai-meter-spend-promql` (`flake/parts/checks/ai-meter-guards.nix`): the dashboard's spend-rate PromQL and the Go cost formula are two implementations of one formula, so the check evaluates what the generator REALLY emits with promtool's engine on a fixture, then holds the Go side (`TestEstimateCostMatchesDashboardPromQL`) to the same number. Either formula moving alone fails it. A second fixture (two priced models, two clients) pins the per-client sum and the 24-hour window. promtool is more permissive than SigNoz: it accepted a `\.` escape that SigNoz's own parser rejects, so the check also refuses a lone backslash in any spend query, and a generated query should still be cross-checked against the live engine (`POST /api/v5/query_range`) before it ships. It also asserts that the dashboard evo-x2 provisions keeps the four priced panels, that each of their queries mentions every priced model, and that the rendered file carries no placeholder. Negative legs: `CASES=aimeter bash scripts/negative-test-lints.sh` (either formula drifting, the per-client grouping or the 24-hour scaling dropped, a renamed or dropped priced panel, a neutered ledger replay); the dashboard rules: `CASES=signozdash`.

## Tests

- Go: `buildflow -s test-race` (auth, routing, streaming usage capture, injection, cost math, ledger, label escaping, e2e vs a fake upstream; genai.go adapter: native path/auth/usage/query-preservation e2e vs a fake gemini upstream; ledger replay: a price that lands, is withdrawn or stays across restarts, old-format lines that still carry a cost, unparseable lines, a torn tail line)
- VM: `nix build .#checks.x86_64-linux.ai-meter-vm` — unit boot, key mint ownership/perms (consumer copies + ai-meter mirrors + non-root chown path), health, unauthorized 401, unknown-upstream 404, metrics exposition, the hardened unit replaying the ledger at start (cost family only), and a price row that lands after a call restating it on the same ledger
