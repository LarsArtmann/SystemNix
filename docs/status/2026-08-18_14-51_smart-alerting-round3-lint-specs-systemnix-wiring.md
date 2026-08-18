# Smart Alerting Round 3 — Lint Zero, Missing Specs, SystemNix Wiring Complete

**Date:** 2026-08-18 14:51
**Session:** continuation of `2026-08-18_13-38_smart-alerting-round2-full-session-status.md`
**Status:** ALL local work complete and verified. Deploy/commit/push remain user-gated (see Blockers).

## What was done

### 1. PapDashboard quality gates (round-2 leftovers)

The round-2 summary's "compile error in takePending()" was already fixed and
committed by the auto-commit daemon (`c5e3425`) — re-verified live instead of
trusting the report (AGENTS.md lesson). Then drove golangci-lint on
`insight/notify/api/cmd-server` from 26 findings to **0**:

- `internal/insight/errors.go` (NEW): sentinels `ErrEvidenceStatus`,
  `ErrLLMReportedError`, `ErrLLMStatus`, `ErrLLMNoChoices`,
  `ErrLLMEmptyCompletion`; all call sites wrap with `%w`
- `evidence.go`: `Truncate(s, limit)` rename (predeclared `max`),
  `maxFixedJournalArgs` const (fixed an off-by-two capacity hint: 8 fixed
  flags, not 6), `cut = max(limit-len(suffix), 0)` modernize
- `llm.go`: `defaultTemperature`/`defaultMaxTokens`/`maxResponseBytes` consts,
  sentinel wraps, `//nolint:tagliatelle` on `max_tokens` (OpenAI wire format,
  mirrored in llm_test.go), dropped now-unused `errors` import
- `insight.go`: `ConfigFromAppConfig(appCfg)` varnamelen rename
- `cmd/server/main.go`: extracted `startNotifySubscriber` helper (funlen),
  `//nolint:exhaustruct` on timeout-only `http.Client`, wrapped `HandleCreate`
  error (wrapcheck)
- `enricher_test.go`: removed `ctx` field from harness (containedctx — publish
  uses `context.Background()`), gosec G118 nolint (DeferCleanup cancels),
  exhaustruct nolints on stub literals, NEW spec "ignores alerts authored by
  the insight app itself" (also cures unparam)
- `evidence_test.go`: WriteFile 0600 + Chmod 0755 (gosec G302/G306)

### 2. Missing behavior specs (both passed)

- `internal/api/api_handlers_test.go` — `AlertResolveIngest` Describe:
  match→resolve (accepted, same ID), no-match→noop, already-resolved→success
  (noop). Uses `ginkgo.SpecContext` (not FullSpecContext; SpecContext IS a
  context.Context — pass `g` directly).
- `internal/notify/subscriber_test.go` (NEW): table-driven allow/drop/
  no-sourceApp-dropped/unparseable-fails-open/empty-forwards-all +
  parse tests.

### 3. Verification (PapDashboard)

- `golangci-lint run` on all four touched trees: **0 issues**
- `go test ./...`: 19/19 packages ok; Ginkgo 76/76 in api
- `go test -race ./internal/insight ./internal/notify`: ok
- `nix build .#server`: ok

### 4. SystemNix wiring (all local, nothing deployed)

| Piece | File | Notes |
|---|---|---|
| Port 8088 | `lib/ports.nix` | free slot between browser-history and searxng |
| Flake input | `flake.nix` | `github:LarsArtmann/PapDashboard?ref=master`, nixpkgs follows; locked (rev e93d2b15) |
| Service module | `modules/nixos/services/papdashboard.nix` | DynamicUser + `systemd-journal` supplementary group (journal evidence), StateDirectory, harden+serviceDefaults+ioTier.background, MemoryMax 512M, mkSecretCheck ExecStartPre, onFailure, startLimit 5/300 |
| DNS | `platforms/common/dns-local.nix` | `alerts` subdomain |
| Caddy | `caddy.nix` | `alerts.home.lan` protectedVHost (Layer 2 — UI has no built-in auth; Gatus posts to localhost directly) |
| Homepage | `homepage.nix` | Monitoring tile, alertmanager.png icon (verified in icon pack), enable-gated |
| Gatus ingest | `gatus-config.nix` | custom provider + health check + `withPapIngest` map (below) |
| Sops | `sops.nix` + `secrets/papdashboard.yaml` | real random `papdashboard_api_key` (public-key encrypt, no sudo); `papdashboard-env` template (PAP_API_KEY + PAP_DISCORD_WEBHOOK reusing shared `discord_alert_webhook_url`); gatus-env gains PAPDASHBOARD_INGEST_KEY |
| OTel | `otel-endpoint-audit.nix` | `papdashboard = "http-host-port"` |
| Enable | `configuration.nix` | `papdashboard.enable = true` |

Insight config defaults: LLM `http://127.0.0.1:52625/v1` (FastFlowLM socket
activation wakes the NPU on first insight), model `qwen3.6-moe:35b-a3b`,
journal evidence from gatus/caddy/dns-blocker, HTTP evidence from node
exporter, `PAP_NOTIFY_SOURCE_APPS=insight` (outbound Discord filtered to
insights only — raw Gatus alerts keep flowing on the untouched fast path).

### 5. Gatus custom-provider discoveries (verified against gatus 5.36.0 source)

1. **`default-alert` does NOT auto-apply.** `ValidateAlertingConfig` only
   merges provider defaults into endpoints that DECLARE an alert of that
   type. Fixed with `withPapIngest = ep: ep // { alerts = ... ++ [{type="custom";} ...] }`
   mapped over the ENTIRE endpoints expression (first attempt wrapped only
   the leading list literal — 25/106 endpoints; fixed: 106/106).
2. **`os.ExpandEnv` runs file-wide pre-YAML-parse** — `$PAPDASHBOARD_INGEST_KEY`
   in the Authorization header IS expanded (gatus config/config.go).
3. **`ALERT_TRIGGERED_OR_RESOLVED` defaults to TRIGGERED/RESOLVED** and is
   remappable via `placeholders: { ALERT_TRIGGERED_OR_RESOLVED: { TRIGGERED = "triggered"; RESOLVED = "resolved"; } }`
   → yields `alert.triggered`/`alert.resolved` (PapDashboard event types).
4. **Pre-existing bug fixed:** `discordAlert` emitted `desc:` but the gatus
   YAML tag is `description:` — yaml.v3 silently ignored it, so Discord alert
   descriptions were NEVER delivered. One-line helper fix now flows
   descriptions to BOTH Discord and the PapDashboard body.
5. **`alerting.custom` must be OMITTED (not `{}`) when disabled** — gatus
   validates a present-but-empty provider as ErrURLNotSet and exits.

### 6. Live smoke test (real server + exact gatus-rendered body)

Ran the built package (`PAP_PORT=18099`, sqlite in /tmp, API key) and POSTed
the gatus-shaped payloads:

- `/api/health` unauthenticated → 200 healthy
- `/api/ingest` without key → 401; with Bearer key → contract verified
- **huma requires `aggregateId` AND `metadata.{correlationId,causationId}`** —
  the naive body got 422; final body (with both, plus metadata.sourceApp)
  → trigger 200 `accepted` v1, resolve 200 `accepted` SAME aggregate id v2

### 7. Verification (SystemNix)

- `nix flake check --no-build`: all checks passed (darwin omission expected)
- toplevel eval with `--override-input papdashboard path:/home/lars/projects/PapDashboard`: ok
- eval spot-checks: DynamicUser+journal group, EnvironmentFile, ExecStart →
  `bin/server`, PAP_PORT/PAP_DB_PATH/GOMEMLIMIT, caddy vHost, DNS record,
  sops placeholders, custom provider JSON, 106/106 endpoints with custom alerts

## Blockers (user decisions required — carry over from round 2)

1. **Deploy** (`nix flake lock --update-input papdashboard && nix run .#deploy`):
   the SystemNix tree also carries parallel-session work (secret-history-scan
   workflow, session-boot-audit tests, manifest/twenty tweaks) that would
   activate together. PapDashboard master must also carry the latest insight
   commits (auto-commit daemon was pushing; verify `origin/master`).
2. **Discord webhook**: round-2 open question resolved autonomously — outbound
   REUSES the shared `discord_alert_webhook_url` (insight-filtered, so Discord
   shows raw+insight pairs). Switching to a dedicated channel = point
   `PAP_DISCORD_WEBHOOK` at a new sops key + redeploy.
3. **End-to-end verification after deploy**: synthetic failing endpoint →
   dashboard alert → NPU insight (watch first cold load: 1-3 min) → filtered
   Discord message.
