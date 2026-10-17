# ai-meter — transparent metering proxy for all OpenAI-compatible AI calls

> Layer: `modules/nixos/services/ai-meter.nix` · Binary: `pkgs/ai-meter/` (in-tree Go, stdlib only, vendorHash = null) · Enabled: evo-x2 (`configuration.nix`)

## What it is

Every OpenAI-compatible AI call on the host flows through one loopback proxy that meters **tokens, cost, latency, TTFT and per-client attribution** without changing any model name or request shape. Born from the 2026-10-16 [Agent Router evaluation](../research/2026-10-16_agent-router-deep-dive.html): the owner wants metrics + metering for ALL AI calls; Agent Router's packaging cost buys governance this single-user host doesn't need, so the exact-scope replacement is ~700 lines of owned Go.

| Surface | Port | Purpose |
| --- | --- | --- |
| Proxy | `ai-meter` (8107) | `/v1/<upstream>/<path>` — per-client Bearer key required; `/health` unauthenticated |
| Admin | `ai-meter-metrics` (8108) | Prometheus `/metrics` (scraped by SigNoz), `/health` |

Both loopback-only. No vHost — deliberately: the proxy is infrastructure, not a user surface.

## Routing

Path-based, so client model vocabularies stay identical everywhere:

```
crush provider zai        → http://127.0.0.1:8107/v1/zai/chat/completions        → https://api.z.ai/api/paas/v4
crush provider kimi-coding → http://127.0.0.1:8107/v1/kimi/chat/completions       → https://api.moonshot.ai/v1
crush provider gemini      → http://127.0.0.1:8107/v1/gemini/v1beta/models/<m>:streamGenerateContent
                           → https://generativelanguage.googleapis.com (NATIVE genai protocol, X-Goog-Api-Key)
paperless-gpt             → http://127.0.0.1:8107/v1/fastflowlm/chat/completions  → 127.0.0.1:52625 (FastFlowLM)
inboxclean chat           → http://127.0.0.1:8107/v1/llama-chat/chat/completions  → 127.0.0.1:8850 (llama.cpp)
(+ llama-embeddings upstream declared; unused ones cost nothing; openrouter dropped 2026-10-17 — `openrouter_api_key` was never set in sops)
```

The proxy is TRANSPARENT: bodies pass through untouched except one opt-in injection — `stream_options.include_usage: true` on streaming requests that lack it, so the final SSE chunk carries the usage block the metering needs. `inject_stream_usage: false` in the rendered config disables it. Native genai traffic is exempt from the injection (genai bodies would reject the foreign field); its usage comes from `usageMetadata` instead (genai.go adapter, 2026-10-17).

## Secrets & clients

- **Upstream provider keys**: sops COPIES owned by the `ai-meter` user (`ai-meter-{zai,kimi,gemini}-key` → crush.yaml keys). Independent of the source blocks' enablement. The openrouter copy was dropped 2026-10-17: `openrouter_api_key` was never set in `openseo.yaml`, which made sops manifest validation refuse the whole deploy — re-add only after setting that key.
- **Client keys**: RUNTIME-MINTED by the `ai-meter-keys` oneshot (`openssl rand -hex 24` → `/run/ai-meter-keys/<client>`, 0400, owned by the consumer's user). Never in the repo, never in sops. Keys live for the boot; existing keys are NEVER regenerated (a silent rotation would 401 running consumers).
- **Two-copy mint (2026-10-17)**: the daemon (`ai-meter` user) cannot read consumer-owned 0400 files — the first VM run start-looped on exactly that. Each key therefore ALSO exists as an `ai-meter`-owned 0400 mirror at `/run/ai-meter-keys/config/<client>` (dir 0700); the proxy config points ONLY at the mirrors, and the mint re-syncs each mirror (`install`) on every run so the pair can never diverge.

| Client | Key consumption | Routed via |
| --- | --- | --- |
| `crush` | raw file, `$(cat /run/ai-meter-keys/crush)` in the crushrc `extraRc` (home.nix) — overrides `zai` + `kimi-coding` + `gemini` base URLs; later provider-add statements win | zai, kimi, gemini (native) |
| `paperless-gpt` | env file `OPENAI_API_KEY=…` on the daemon unit | fastflowlm |
| `inboxclean` | env file on `inboxclean-web` | llama-chat |

Adding a consumer = add a `services.ai-meter.clients.<name>` entry (user + optional `envKey`) + point the app's base URL at `/v1/<upstream>`. The deploy.sh provisioner loop re-runs `ai-meter-keys` so the key exists before the restarted daemon references it.

## Metrics & ledger

Prometheus families on :8108 (job `ai-meter`, SigNoz collector):

- `ai_meter_requests_total{client,upstream,model,code}`
- `ai_meter_tokens_total{client,upstream,model,kind=prompt|completion|cached}`
- `ai_meter_cost_usd_total{client,upstream,model}` — from `services.ai-meter.costs` (USD per 1M tokens; `glm-5.3-flash` mirrors the crushrc prices; unknown/local models cost $0 but meter tokens exactly)
- `ai_meter_request_seconds_{sum,count}`, `ai_meter_ttft_seconds_{sum,count}` (streaming only), `ai_meter_active_requests`, `ai_meter_unauthorized_total`, `ai_meter_metering_errors_total` (recording failures that did NOT fail live traffic — watch this: nonzero means usage blocks are going missing)

Durable ledger: `/var/lib/ai-meter/usage.jsonl` — one JSON object per call (the true-up source; Prometheus counters reset on restart, the ledger does not).

## Traps

- **gemini rides the NATIVE genai protocol** (probe 2026-10-17: crush v0.98.1's gemini provider = google-genai-sdk transport, `v1beta/models/<model>:streamGenerateContent?alt=sse`, `X-Goog-Api-Key` auth — even with a custom `--base-url`). The genai.go adapter handles all of it: client auth via the X-Goog-Api-Key channel, upstream auth via `auth_style = "x-goog-api-key"`, model-from-URL metering, `usageMetadata` extraction (thoughtsTokenCount folds into completion tokens), query-string preservation (`?alt=sse` is REQUIRED — dropping it silently changes the response format). No gemini models are declared in crushrc yet, so nothing routes there until one is `model add`-ed; gemini tokens meter exactly, cost $0 until a cost entry exists (no invented prices).
- **Key rotation**: delete `/run/ai-meter-keys/*` + restart `ai-meter-keys` + restart consumers — or just reboot (fresh mint at boot).
- **Metering must never break a call**: parse failures degrade to request-counting (`model="none"`, `usage_missing`) and increment `ai_meter_metering_errors_total` — check it before trusting dashboards.
- **hermes** calls GLM/MiniMax from its own app config — wiring it needs a hermes-repo change (open row in docs/todo/ai-stack.md).

## Checks

Gatus: "ai-meter" (:8107/health, 200 + <500ms) and "ai-meter metrics" (:8108/metrics, 200 + `pat(*ai_meter_requests_total*)`). Eval gates: ports registered, port-registry audit (no literals), gatus coverage (both ports probed), deploy-restart-audit (ai-meter-keys in the deploy.sh provisioner loop).

## Tests

- Go: `buildflow -s test-race` (auth, routing, streaming usage capture, injection, cost math, ledger, label escaping, e2e vs a fake upstream; genai.go adapter: native path/auth/usage/query-preservation e2e vs a fake gemini upstream)
- VM: `nix build .#checks.x86_64-linux.ai-meter-vm` — unit boot, key mint ownership/perms (consumer copies + ai-meter mirrors + non-root chown path), health, unauthorized 401, unknown-upstream 404, metrics exposition
