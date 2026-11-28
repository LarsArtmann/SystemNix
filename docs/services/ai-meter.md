# ai-meter — transparent metering proxy for all OpenAI-compatible AI calls

> Layer: `modules/nixos/services/ai-meter.nix` · Binary: its own repository, `github:LarsArtmann/ai-meter`, consumed as flake input `ai-meter` (Go, standard library only; it was in-tree at `pkgs/ai-meter/` until 2026-11-26) · Enabled: evo-x2 (`configuration.nix`)

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

| Section | Panels | What to read off it |
| --- | --- | --- |
| In flight (top) | In Flight; In Flight: Provider x Model x Client; Calls (24h); In Flight by Provider, by Model, by Client | who is waiting on the proxy right now, and how much traffic the day had |
| Traffic | Requests / min; Success Rate (5m); Failures / min; Not Admitted/min; Reachable; Process Uptime; Requests by Provider; Requests by Client; Requests by Model x Code; Failures by Code; Error Rate by Provider | whether calls succeed once a provider answers them, which provider fails, and how many calls the gate sends back |
| Tokens & spend | Tokens / min; Cache Hit Rate; Prompt / Call; Spend Rate; Spend (24h); Spend (all-time); Spend Rate by Model; Spend Rate by Client; Tokens by Kind; Tokens by Client; Models: Last 24 Hours | what the traffic would cost at the reference price table, per model and per client |
| Latency | Avg TTFT; Avg Gate Wait; Avg Duration; Avg Output Speed; Avg TTFT by Model; Avg Duration by Model; Output Speed by Model | the wait before the first byte (what a user feels, counted from the call's arrival), how much of that wait is the gate's queue (Avg Gate Wait), and the generation speed behind the provider |
| Health | Starts (24h); Not Metered (24h); Bad Keys (24h); Spans Lost (24h); Traced Calls (1h); Metrics Freshness; Metering Errors / min; Span Export by Outcome | whether the metering itself can be trusted |
| Admission (z.ai rate limit) | Quota Exhausted; Limit (now); Waiting (now); Not Admitted (5m); Rate 429s (24h); Quota 429s (24h); Admission: In Flight, Waiting, Limit; Admission Outcomes (24h); Avg Admission Wait; 429 Answers From z.ai / min; 429 Answers From ai-meter / min | how admission control does against z.ai's unpublished concurrency: its allowance, its queue, and the demand it sends back |
| Notes & links | How to read this dashboard | the three outcomes of a request, what the colors mean, links to SigNoz's AI observability views |

**Three outcomes of a request.** Every request through the proxy ends *served* (the provider answered 2xx), *not admitted* (ai-meter itself answered 429: the call waited out its wait budget without a slot at the gated provider, or a usage window is spent; the client sends it again and it keeps its place) or *failed* (everything else). Success Rate, Failures / min, Failures by Code, Error Rate by Provider and the table's `success` column count not-admitted calls as neither success nor failure; they are in Not Admitted / min, Not Admitted (5m) and the table's `not admitted` column. Not admitted is `ai_meter_admission_outcomes_total{outcome=~"timeout|circuit"}`; `gave_up` is a failure, because the provider's own 429 is passed on. Without the split the page cried wolf on the gate's first night: the HTTP-level success rate read 48 % while 1.9 % of the requests failed and 47.5 % were sent back (ledger, 13,728 lines since the last start, 2026-11-26); over the following 12 hours the 429s clients saw (5,957) matched timeout plus circuit (5,928) within 0.5 %.

Read Health before any other number: Metrics Freshness past two minutes means every panel is stale, and Not Metered in orange means tokens are missing at a rate worth a look. **A tile is red only when a person should act on it now.** A 24-hour count that turns red at zero after one event (Spans Lost, Not Admitted) carries no color for that reason, and Bad Keys stays uncolored for a stray call or two a day (orange past 10, red past 100: a client retrying with a wrong key on every call): red all day is read no more. The colors of the 13 threshold tiles, read back over the 15 hours after the 270 s budget went live (2026-11-27 10:28 to 2026-11-28 01:35, every five minutes): Success Rate green 96 % of the time, Failures, Not Metered, Spans Lost, Reachable and Metrics Freshness never red, Avg TTFT red 53 % and Quota Exhausted red 51 % of the time, both from the gate (Avg Gate Wait below).

**The page loads once.** The dashboard's `refreshInterval` is stored but not applied by SigNoz's UI (the type's own description in the pinned source; measured 2026-11-26: no re-query in four minutes with `1m` stored). To keep it live, pick an interval in the top-right menu; SigNoz keeps that choice per browser. Only panels in the viewport query (11 for a 1200 px window, about 40 for the whole page). A first-time viewer opens the dashboard on its last three hours (`duration`); the URL or the viewer's last pick wins. The viewer page (`ai-meter.<domain>`) therefore loads the dashboard with `?relativeTime=<the file's duration>` on its iframe and on its "open in SigNoz" link: the parameter is applied when the page first mounts, over whatever range the browser remembered.

**The notes panel links to SigNoz's own AI views.** The explorer link carries the page's URL query form, `relativeTime=24h` and a `compositeQuery` filter `serviceName = "ai-meter"`, so it opens on ai-meter's calls alone; blocks left out of the query are filled in with the explorer's defaults (`normalizeCompositeQuery.ts` in the pinned frontend). Verified in a headless render on 2026-11-27; re-check it after a SigNoz upgrade.

### Where each number comes from

- **Priced panels come from the renderer, never from the cost counter's rate or increase.** `Spend Rate`, `Spend Rate by Model`, `Spend Rate by Client` and `Spend (24h)` are PromQL generated by `_ai-meter-dashboard.nix` from the token counters and `services.ai-meter.costs`; each panel keeps its placeholder as the query. `increase(ai_meter_cost_usd_total[...])` reports a price restatement as spend (live 2026-11-25: 2414 USD in 24 hours against about 48 USD a day).
- **Tables and the pie chart run builder queries**, because the dashboard API refuses PromQL on them. The builder's `increase` drops each series' first bucket and the first bucket after a counter reset, and the server raises a smaller step to its floor for the range (60 s to 6 h, 300 s at 24 h, 600 s at 48 h): within 3 % for dense counters (requests, tokens, admission outcomes), up to a third low for sparse ones (429 answers). Sparse counters are therefore PromQL panels: Rate 429s, Quota 429s, Not Admitted/min and both 429 Answers charts. A composite query joins its parts on the group-by columns and reads a missing part as zero (`n/a` is shown for a division by it).
- **Avg TTFT counts from the call's arrival, the gate's queue included.** It is one sample per served streaming call (`ai_meter_ttft_seconds`); Avg Gate Wait is the mean wait of the calls that waited at all (`ai_meter_admission_wait_seconds`). A provider's own first-token time is not a metric yet: the ledger has it per call as `ttft_ms` minus `queue_ms`. Measured over the 15.2 hours after the 270 s budget went live (10,758 calls, ledger): 73 % of the served calls waited at the gate, median gate wait 26.4 s, median time to first token 29.7 s, median provider time 2.4 s. So Avg TTFT sits red (over 10 s) whenever z.ai's usage window is spent, and Avg Gate Wait next to it says why; red Avg TTFT with a small Avg Gate Wait is the provider being slow.
- **Line charts break where two samples are more than 15 minutes apart** (`chartAppearance.spanGaps` in threshold mode). The chart's default spans every gap and drew a straight hour-long ramp for a model with a call at 00:25 and the next at 01:20 (headless render 2026-11-28, in every dashboard); the lint refuses the default. 15 minutes clears the largest query step up to a 72-hour range (900 s), so the lines do not fall apart into dots when a reader widens the range.
- **A two-column tile shows 17 characters of its title.** The viewer's iframe is the whole window, and at a 1280 px viewport 21 and more are cut while 18 fit only with narrow letters (headless renders 2026-11-26 at 1500 px and 2026-11-28 at 1280 px); the lint holds every dashboard to 17.
- **A 2xx answer without a usage block is a client that cancelled its stream** after its first token: the proxy logs `stream read error` with `context canceled`, the final chunk that carries the usage never arrives, and the call counts in Not Metered (2 of 10,458 served calls in those 15 hours; all 16 such lines of two days were `context canceled`). There is no 60-second wall in the proxy: served calls ran up to 952 s.
- **"24h" panels over the admission families count since those series exist** (19:06 on 2026-11-25, when admission control went live), so they show less than a day's worth until that time next day.

### Changing the dashboard

1. Edit the template. A spend panel keeps its placeholder as the query (`"query": "@@spendRateByClient@@"`); the renderer throws at eval unless every placeholder occurs exactly once, and `checks.ai-meter-spend-promql` refuses a dashboard without the four priced panels.
2. `nix build .#checks.x86_64-linux.signoz-query-lint .#checks.x86_64-linux.signoz-dashboard-lint-selftest .#checks.x86_64-linux.ai-meter-spend-promql .#checks.x86_64-linux.ai-meter-alert-promql`. The lint encodes the dashboard API's rules (layout, queries, unit ids, server-default keys) and four of our own (tile titles that fit at 1280 px, line charts that break at empty intervals); the guards hold the priced queries to the Go formula and the failure-rate and embeddings rules to their fixtures.
3. Render with the host's price table, round-trip the document through the API (create a copy under another slug, read it back, delete it: the server adds keys, and the file must carry them), run every panel query against the live engine, **then look at a kept copy of the page in a headless browser before the live dashboard is touched**. The 2026-11-26 render came before the update and caught three cut titles, a clipped text panel and a chart without its unit. Recipes: [monitoring.md](../agents/monitoring.md), "SigNoz dashboard authoring rules".
4. Go live with `PUT /api/v2/dashboards/<dashboardId>` and the rendered document, then read it back and compare `spec`. The provisioner makes the same PUT on the next deploy and skips the dashboard as unchanged from then on (2026-11-26: ai-meter was skipped on the first run after a hand-made update; caddy and gcp were updated once at 06:17 and skipped at 06:48). Until that deploy the RUNNING generation still carries the previous file, so a signoz restart or a reboot puts that one back: the change is durable only after its deploy. `scripts/post-deploy-check.sh` compares every live dashboard with the file the provisioner rendered (`/etc/signoz/dashboards`) after each deploy and FAILs on one that differs or is not served, so a hand-made PUT reads as drift there until the next deploy.

## Admission control

For z.ai the upstream names no concurrency limit and answers whatever
exceeds it with HTTP 429, so the module gives that upstream an
`admission` block: calls queue, the proxy retries "too much at once"
answers itself, the allowance follows the rejections, and a spent usage
window opens a circuit. The rules, the measurements behind them and the
traps are written where the code is: `docs/ADMISSION.md` in the ai-meter
repository.

- **Wait budget: `max_wait_seconds = 270`** (module default 30). One call
  may queue and retry for 270 s in total; then it gets `429` with
  `Retry-After: 1` and a message that names the limit and says how many
  calls are still waiting. Why 270: at 30 s, 42% of 10,535 z.ai ledger
  lines in the first 11 live hours (2026-11-25 18:36Z to 2026-11-26 05:54Z)
  were that answer; Crush abandons a stream without a first part after
  5 minutes and cvagent gives a call 300 s, so 270 s leaves 30 s for time
  to first token (p99 20 s). Change it only after measuring.
  **What the budget did**, read over the 15.2 hours after it went live
  (2026-11-27 10:28 to 2026-11-28 01:35, 10,758 calls, ledger and the
  proxy's own counters): no call ran out of budget (`timeout` 0, against
  42 % at 30 s); every not-admitted answer since was `circuit` (241,
  2.2 %: a spent usage window, three of them); 73 % of the served calls
  waited at the gate (median 26 s, ninth decile 50 s) while the provider
  itself answered the first token in 2.4 s at the median; the allowance
  moved between 5 and 8 (74 changes in those hours, 37 down and 37 up).
- **A re-sent call keeps its place** in the queue for as long as the client
  keeps sending it: the memory lasts five minutes from the call's latest
  arrival and ends when the call is answered with a status no client
  retries. The in-tree copy kept only the first arrival for a fixed five
  minutes; the live rule is the repository's from the first deploy that
  carries it.
- The ledger's `admission` field says how a gated call left:
  `admitted`, `absorbed`, `gave_up`, `timeout`, `circuit`, `cancelled`.
  A `gave_up` or `timeout` answer is the proxy's own 429 and counts as a
  delay, not a provider failure (the failure-rate rule ignores it).

## Traps

- **gemini rides the NATIVE genai protocol** (probe 2026-10-17: crush v0.98.1's gemini provider = google-genai-sdk transport, `v1beta/models/<model>:streamGenerateContent?alt=sse`, `X-Goog-Api-Key` auth — even with a custom `--base-url`). The genai.go adapter handles all of it: client auth via the X-Goog-Api-Key channel, upstream auth via `auth_style = "x-goog-api-key"`, model-from-URL metering, `usageMetadata` extraction (thoughtsTokenCount folds into completion tokens), query-string preservation (`?alt=sse` is REQUIRED — dropping it silently changes the response format). No gemini models are declared in crushrc yet, so nothing routes there until one is `model add`-ed; gemini tokens meter exactly, cost $0 until a cost entry exists (no invented prices).
- **Key rotation**: delete `/run/ai-meter-keys/*` + restart `ai-meter-keys` + restart consumers — or just reboot (fresh mint at boot).
- **Metering must never break a call**: parse failures degrade to request-counting (`model="none"`, `usage_missing`) and increment `ai_meter_metering_errors_total` — check it before trusting dashboards.
- **The source is the `ai-meter` flake input.** A change to the proxy is
  made in its repository, pushed to both remotes, then floated here with
  `nix flake update ai-meter` (never a pin: owner inputs float on
  `master`). The input's rev must be on both remotes, or a fresh clone
  cannot evaluate.
- **hermes** calls GLM/MiniMax from its own app config — wiring it needs a hermes-repo change (open row in docs/todo/ai-stack.md).

## Checks

SigNoz rules reading these metrics (`_signoz-alerts.nix`): "AI Upstream Failure Rate High (>30%)", "AI Quota Window Spent", "AI Embeddings Calls Failing (ai-meter)", "Local AI TTFT High / Critical" (llama-chat), "AI Trace Export Failing", "AI Trace Export Silent" and "AI Traces Not Landing In SigNoz". The failure-rate rule is per provider, counts only the calls a provider had to answer (the 429s ai-meter makes itself while a call waits for room are not failures) and needs 5 calls a minute before a ratio means anything. On the gate's first night its old HTTP-level form sat firing for 85 % of 30 hours; under the repaired form the same 30 hours hold 8 hours of firing for the z.ai 429 storm before the gate existed and nothing since. A spent usage window pages once, as a warning, from the quota rule. The embeddings rule is a warning that fires when half of the calls to `llama-embeddings` fail: 100 times the failed calls over the calls of the last 30 minutes, the denominator never below 4 so one failed call out of one is not 100 %, the numerator present as zero when none failed (a ratio over a missing series has no sample), evaluated every 5 minutes. It was replayed over 48 hours before it shipped (fires on 97.5 % of the points of the 2026-11-25 re-embedding backlog, where 387 of 424 calls failed) and has eight promtool fixtures plus five negative legs (`embeddings-*` in `CASES=aimeter`). Gatus: "ai-meter" (:8107/health, 200 + <500ms), "ai-meter metrics" (:8108/metrics, 200 + `pat(*ai_meter_requests_total*)`), "ai-meter viewer" (the page answers 200 and its body carries the pinned dashboard id followed by `relativeTime=3h`, the range read from the dashboard file's own `duration`) and "ai-meter dashboard" (the pinned id still resolves). Gatus's API answers only with authentication, so read that check's two conditions by hand: the page at `https://ai-meter.<domain>/` and `GET /api/v2/dashboards/<dashboardId>`. Eval gates: ports registered, port-registry audit (no literals), gatus coverage (both ports probed), deploy-restart-audit (ai-meter-keys in the deploy.sh provisioner loop), and the dashboard template must carry each of its four spend placeholders exactly once (`_ai-meter-dashboard.nix` throws at eval otherwise). `checks.signoz-query-lint` validates every dashboard file against the dashboard API's rules (`lib/signoz-dashboard-lint.nix`). After a deploy, `scripts/post-deploy-check.sh` reads every live dashboard through the API and compares its spec with the file the provisioner rendered: the line PASSes only when each one is equal ("N of N live dashboards equal their files"), and names every dashboard that differs, is not served, or whose file has no slug (`scripts/lib/signoz-dashboards-drift.sh`, fixtures in `scripts/test-post-deploy-signoz-dashboards.sh`).

`checks.x86_64-linux.ai-meter-spend-promql` (`flake/parts/checks/ai-meter-guards.nix`): the dashboard's spend-rate PromQL and the Go cost formula are two implementations of one formula, so the check evaluates what the generator REALLY emits with promtool's engine on a fixture, then holds the Go side (`TestEstimateCost` in the input's `internal/meter`) to the same number. Either formula moving alone fails it. A second fixture (two priced models, two clients) pins the per-client sum and the 24-hour window. promtool is more permissive than SigNoz: it accepted a `\.` escape that SigNoz's own parser rejects, so the check also refuses a lone backslash in any spend query, and a generated query should still be cross-checked against the live engine (`POST /api/v5/query_range`) before it ships. It also asserts that the dashboard evo-x2 provisions keeps the four priced panels, that each of their queries mentions every priced model, and that the rendered file carries no placeholder. Negative legs: `CASES=aimeter bash scripts/negative-test-lints.sh` (either formula drifting, the per-client grouping or the 24-hour scaling dropped, a renamed or dropped priced panel, a neutered ledger replay); the dashboard rules: `CASES=signozdash`.

`checks.x86_64-linux.ai-meter-alert-promql` (same file): promtool evaluates the query the failure-rate rule file REALLY carries on five fixtures: z.ai sending back 19 of 40 calls is silent, a provider failing 30 of 40 fires, 40 plain 429s with no admission outcome fire (a provider refusing is still a failure), one failed call per 5 minutes is silent, and of two providers only the failing one fires. Negative legs: the same group `aimeter` (the gate exclusion, the volume floor, the 429 class and the per-provider grouping each removed once).

## Tests

- Go: in the ai-meter repository (`go test -race ./...`, its flake check and CI; 104 test functions on 2026-11-26): auth, routing, streaming usage capture, injection, cost math, ledger, label escaping, e2e vs a fake upstream; genai.go adapter: native path/auth/usage/query-preservation e2e vs a fake gemini upstream; ledger replay: a price that lands, is withdrawn or stays across restarts, old-format lines that still carry a cost, unparseable lines, a torn tail line)
- VM: `nix build .#checks.x86_64-linux.ai-meter-vm` — unit boot, key mint ownership/perms (consumer copies + ai-meter mirrors + non-root chown path), health, unauthorized 401, unknown-upstream 404, metrics exposition, the hardened unit replaying the ledger at start (cost family only), and a price row that lands after a call restating it on the same ledger
