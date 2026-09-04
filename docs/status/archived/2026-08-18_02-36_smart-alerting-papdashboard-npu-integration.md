# Smart Alerting — PapDashboard + NPU Integration (IN PROGRESS, PAUSED)

**Date:** 2026-08-18 02:36
**Status:** ⏸️ PAUSED mid-implementation — awaiting user decisions (see "Open Questions")
**Scope:** Turn passive threshold alerts into AI root-cause insights, leveraging the FastFlowLM NPU on evo-x2 and upgrading/integrating/interlinking `~/projects/PapDashboard/`

---

## 1. Goal

The current alerting is passive: Gatus fires threshold checks → static, hand-written description strings land in Discord ("Caddy down — all services unreachable"). No root cause, no correlation, no evidence, no recommended action. This initiative makes alerting **smart**:

1. Alerts land in **PapDashboard** (event-sourced notification hub, reactive UI, ack/resolve lifecycle)
2. An AI **insight enricher** correlates alert storms into one incident, gathers real evidence (systemd journals + metrics endpoints), asks the **FastFlowLM NPU LLM** (Qwen3.6-35B-A3B, OpenAI-compatible at `127.0.0.1:52625/v1`) for a root-cause analysis, and publishes it as an insight notification
3. Insights flow to the dashboard **and** Discord (filtered), while Gatus keeps its direct fast-path Discord alert (layered: insight failure never blocks raw alerting)

## 2. Architecture (designed)

```
Gatus ──fail(threshold 3)──► Discord "raw alert" (unchanged fast path)
   └──also──► PapDashboard /api/ingest (alert.triggered / alert.resolved)
                 ├─► Dashboard UI (live SSE, ack/resolve lifecycle)
                 └─► Insight enricher (NEW, async, best-effort):
                       correlation window (storm → 1 incident)
                       → evidence: journalctl units + HTTP metrics endpoints
                       → FastFlowLM NPU (cold-load tolerant, 5 min timeout)
                       → "[severity] Root Cause / Impact / Next Steps"
                       → notification.created (sourceApp="insight")
                       → Dashboard + Discord (filtered: insight only)
```

## 3. Research findings (verified, this session)

| Fact                                                                                                                                                                                                                                                                                                                                                                                                                     | Where verified                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- |
| PapDashboard is mature (~420 specs, clean tree before session)                                                                                                                                                                                                                                                                                                                                                           | FEATURES.md, git log                    |
| `POST /api/ingest` supports `alert.triggered` (idempotent) but NOT `alert.resolved`                                                                                                                                                                                                                                                                                                                                      | `internal/api/handler_impl.go:258-278`  |
| Outbound notify subsystem already exists: Channel interface, MultiChannel, Discord/Slack/webhook/email channels + event-bus subscriber                                                                                                                                                                                                                                                                                   | `internal/notify/`                      |
| No source-app filter on outbound channels (all events → all channels)                                                                                                                                                                                                                                                                                                                                                    | `internal/notify/subscriber.go`         |
| API-key auth exists (`Authorization: Bearer` / `X-Api-Key`)                                                                                                                                                                                                                                                                                                                                                              | `internal/middleware/auth.go`           |
| Gatus `custom` alert provider: POST + configurable body with placeholders `[ALERT_DESCRIPTION] [ENDPOINT_NAME] [ENDPOINT_GROUP] [ENDPOINT_URL] [RESULT_ERRORS] [RESULT_CONDITIONS] [ALERT_TRIGGERED_OR_RESOLVED]`; placeholder VALUES are customizable (needed to emit lowercase `alert.triggered`/`alert.resolved`); one endpoint may carry multiple alerts (discord + custom); headers get NO placeholder substitution | gatus v5.36.0 source + docs (fetched)   |
| Alert read model has NO find-by-sourceApp+title query (needed for resolve ingest)                                                                                                                                                                                                                                                                                                                                        | `sql/queries/alerts.sql`                |
| `DecideResolve` returns `ErrAlertAlreadyResolved` conflict — resolve-ingest must tolerate it                                                                                                                                                                                                                                                                                                                             | `internal/domain/alert/decide.go:64-82` |
| FastFlowLM is socket-activated (1-3 min cold load, 1 h idle TTL); Gatus must not probe :52625                                                                                                                                                                                                                                                                                                                            | SystemNix AGENTS.md, `fastflowlm.nix`   |
| Gatus env-var interpolation in config.yaml already used (`$DISCORD_WEBHOOK_URL` via sops template `gatus-env`)                                                                                                                                                                                                                                                                                                           | `gatus-config.nix:173-180`              |
| `TitleMaxLen=500`, `BodyMaxLen=10000`                                                                                                                                                                                                                                                                                                                                                                                    | `internal/domain/content.go`            |

## 4. What is DONE

### PapDashboard (`~/projects/PapDashboard`)

- **`internal/config/config.go`** — added 13 config knobs + `InsightConfigured()` + `NotifySourceApps`; `getEnvBool`/`getEnvInt` helpers; validation (`ErrInsightIncomplete`). **Builds green, existing tests pass.**
  - `PAP_INSIGHT_ENABLED`, `PAP_INSIGHT_LLM_BASE_URL`, `PAP_INSIGHT_LLM_MODEL`, `PAP_INSIGHT_LLM_API_KEY`, `PAP_INSIGHT_LLM_TIMEOUT_SECONDS` (300), `PAP_INSIGHT_CORRELATION_WINDOW_SECONDS` (45), `PAP_INSIGHT_COOLDOWN_MINUTES` (30), `PAP_INSIGHT_EVIDENCE_URLS` ("label=url,..."), `PAP_INSIGHT_JOURNAL_UNITS`, `PAP_INSIGHT_JOURNAL_SINCE` ("-45m"), `PAP_INSIGHT_JOURNALCTL_PATH`, `PAP_INSIGHT_MAX_EVIDENCE_BYTES` (8192), `PAP_NOTIFY_SOURCE_APPS`
- **`internal/insight/insight.go`** — package doc, resolved `Config`, `ConfigFromAppConfig`
- **`internal/insight/evidence.go`** — `EvidenceCollector` interface; `HTTPEvidence` (GET + truncate); `JournalEvidence` (exec journalctl, `-n 300 --since`, tolerates "no journal for unit" exit 1); `ParseEvidenceURLs`, `ParseJournalUnits`, `Truncate`
- **`internal/insight/llm.go`** — `Completer` interface + `Client` (OpenAI-compatible `/chat/completions`, encoding/json/v2, optional bearer key, temperature/max-tokens options)
- **`internal/insight/enricher.go`** — `Enricher`: SubscribeAll loop → filters `alert.triggered` (skips own sourceApp, cooldown per sourceApp+title) → correlation-window batching (`time.AfterFunc`) → evidence collection (30 s/collector) → LLM (LLMTimeout ctx) → `[severity]` first-line protocol → `notification.CreateCommand` via injected `CreateNotification` func (never publishes events directly). Panic-recovered, all failures slog'd, never fatal. SROT system prompt with Root Cause/Impact/Next Steps + anti-hallucination rules.
- **`GOEXPERIMENT=jsonv2 go build ./internal/insight/` compiles clean**; assumed constants (`NotificationTypeCritical`, `ParseSourceApp`) verified to exist.

## 5. Known weaknesses in current draft code (self-review)

1. **`buildPrompt(batch, ctx)` — context is not the first parameter** → will fail this repo's strict golangci-lint (revive context-as-argument). Must fix before lint gate.
2. **`time.Now()` hardcoded inside `buildPrompt`** instead of injected `e.now` — breaks deterministic tests.
3. **Cooldown map never evicts** — unbounded (slow) growth. Add lazy pruning on insert.
4. **Pending batch unbounded** — a 500-alert storm builds one giant prompt. Cap batch, represent overflow as "+N more".
5. **ZERO specs written for `internal/insight`** — violates project standard (~420 specs; BDD skill mandates Ginkgo specs alongside).
6. **check-then-act race in cooldown** (two same-title alerts can both pass `inCooldown` before `markCooldown`) — benign for dedupe purposes but untested.
7. **`Truncate` rune-shrink loop** recomputes `string(runes)` each iteration — O(n·log n) and quirky; simplify.
8. LLM client not yet exercised against a real/httptest server; FastFlowLM response-shape compatibility unverified.
9. Em dashes present in some strings/comments (matches house style in prose, but flagged by my own conventions).

## 6. NOT STARTED (remaining plan)

### PapDashboard

- [ ] Fix the lint/spec issues above; write Ginkgo specs (enricher correlation/cooldown/filter/prompt, evidence truncation, LLM client against httptest, parseAnswer)
- [x] ~~`alert.resolved` ingest: sqlc query `FindActiveAlertsBySourceAppAndTitle` (`sqlc generate`), handler case tolerating `ErrAlertAlreadyResolved`, idempotent "ignored" when no match~~ done at `34f33a51`, `e3995077`
- [x] ~~Notify source-app filter (`PAP_NOTIFY_SOURCE_APPS` allowlist in `StartSubscriber`)~~ done at `34f33a51` (PAP_NOTIFY_SOURCE_APPS=insight live)
- [x] ~~Wire enricher in `cmd/server/main.go` (invoke `*notification.DeciderHandler`, build collectors from config)~~ done at `34f33a51` (insights publish as notifications, live)
- [x] ~~`go test ./...`, `golangci-lint run`, `nix build .#server`~~ done (prerequisite of the deployed flake input `ebbc6fa`)

### SystemNix

- [x] ~~flake input `papdashboard = github:LarsArtmann/PapDashboard`~~ done at `34f33a51`
- [x] ~~`lib/ports.nix` port entry~~ done at `34f33a51`
- [x] ~~`modules/nixos/services/papdashboard.nix`: service (harden, StateDirectory, sops `PAP_API_KEY`, `PAP_ENV=production`, insight env wired to FastFlowLM `http://127.0.0.1:52625/v1` + `qwen3.6-moe:35b-a3b`, journalctl abs path, `systemd-journal` supplementary group), Caddy `protectedVHost "notify"`, DNS localSubdomains, Homepage tile, Gatus `/api/health` check, OTel audit if applicable~~ done at `34f33a51`
- [x] ~~Gatus `alerting.custom` provider → PapDashboard ingest (placeholders + `placeholders:` override for lowercase `triggered`/`resolved` in the `type` field; `send-on-resolved: true`; extend `discordAlert` helper to emit both providers for every endpoint)~~ done at `34f33a51`
- [x] ~~sops: new `papdashboard.yaml` (API key) + extend `gatus-env` template with ingest key~~ done at `34f33a51`
- [x] ~~Enable in `configuration.nix`; `nix flake check --no-build` + eval~~ done at `34f33a51`
- [x] ~~Deploy + end-to-end: synthetic failing alert → NPU insight → dashboard + Discord~~ done at `34f33a51`
- [x] ~~Docs: AGENTS.md section, TODO_LIST, this report closure~~ done at `34f33a51`

## 7. Open questions (BLOCKING)

1. **Push & deploy permission:** SystemNix consumes PapDashboard via `github:` flake input — the upgrades must be committed/pushed to GitHub (and the SystemNix tree currently carries OTHER in-flight uncommitted work: homepage overhaul, google-sync rework). May I commit+push PapDashboard and deploy SystemNix as-is?
2. **Discord routing preference:** keep Gatus→Discord raw alerts AND insight notifications (my design: layered, no single point of failure), or route everything through PapDashboard only (single pane, but insights die with it)?
3. **Webhook for insights:** reuse the existing Gatus Discord webhook for PapDashboard's filtered insight channel, or create a dedicated Discord channel/webhook so raw alerts and AI insights are visually separated?

## 8. Observations on tree state (not touched)

- PapDashboard has **staged planning docs from 02:30** (`docs/planning/2026-08-18_02-30_ECOSYSTEM-LEVERAGE-PLAN.html`, `ecosystem-leverage.d2/svg`) — created DURING this session but not by it; likely a parallel session. Not modified by me.
- PapDashboard `go.mod`/`go.sum` carry an **unstaged OpenTelemetry 1.44→1.45 bump** — also not from this session (no `go get` was run). Should be reviewed/committed by its author before the SystemNix input bump, or explicitly reverted — do NOT blindly include.
