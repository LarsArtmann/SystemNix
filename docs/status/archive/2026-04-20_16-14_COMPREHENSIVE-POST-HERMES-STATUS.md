# SystemNix Comprehensive Status Report

**Date:** 2026-04-20 16:14 CEST
**Branch:** master @ `36418e1`
**Platform:** NixOS (evo-x2) + macOS (Lars-MacBook-Air)
**All checks:** `nix flake check --no-build` PASS, `statix` PASS, `deadnix` PASS, `alejandra` PASS

---

## A) FULLY DONE

### Hermes AI Agent Gateway — Full Declarative Integration

- **Flake input** (`hermes-agent` from `github:NousResearch/hermes-agent`) locked in `flake.lock`
- **NixOS module** (`modules/nixos/services/hermes.nix`): options (`enable`, `user`, `home`, `restartSec`, `timeoutStopSec`), system packages (`hermesPkg` + `libopus`), tmpfiles rules for `~/.hermes/` directory structure
- **Home Manager systemd service**: declarative `hermes-gateway` user service with `ExecStartPre` merge script that merges sops-rendered secrets into writable `~/.hermes/.env` (Hermes needs write access for `save_env_value()`)
- **Sops secrets**: 5 keys encrypted in `platforms/nixos/secrets/hermes.yaml` (discord_bot_token, glm_api_key, minimax_api_key, fal_key, firecrawl_api_key). Template `hermes-env` renders `.env`. All secrets trigger `hermes-gateway.service` restart.
- **Systemd hardening**: `WatchdogSec=60`, `MemoryMax=4G`, `PrivateTmp=true`, `NoNewPrivileges=true`, `ProtectClock=true`, `ProtectHostname=true`, `ProtectKernelLogs=true`, `RestrictNamespaces=true`, `LockPersonality=true`
- **Config hardening** (`~/.hermes/config.yaml`): `key_env: GLM_API_KEY` instead of plaintext, `timezone: Europe/Warsaw`, `redact_pii: true`, logging WARNING/10MB/7 backups
- **Security**: `SUDO_PASSWORD` removed from `.env`, `OLLAMA_API_KEY=ollama` added, credential files set to mode 600
- **AGENTS.md**: Full Hermes section with architecture, options, commands, sops reference
- **Justfile**: `hermes-status`, `hermes-restart`, `hermes-logs`
- **Status**: Module committed and pushed. NOT YET DEPLOYED (`just switch` not run).

### Statix W20 Fixes — All Clean

- **`signoz.nix`**: Merged repeated `environment.etc` keys into single attribute set. Merged repeated `systemd.*` keys (`tmpfiles.rules`, `services.amdgpu-metrics`, `timers.amdgpu-metrics`) into single `systemd = { ... }` block. Zero statix warnings.
- **`snapshots.nix`**: Merged 4 separate `systemd.*` blocks (`timers.timeshift-backup`, `services.timeshift-backup`, `services.timeshift-verify`, `timers.timeshift-verify`) into single `systemd = { ... }` block. Preserved BTRFS autoScrub. Zero statix warnings.
- **Project-wide**: `statix check` passes on all Nix files.

### SigNoz Observability Pipeline

- Full stack: node_exporter, cAdvisor, OTel Collector, ClickHouse, Query Service
- Alert rules: disk-full, cpu-sustained, memory-critical, service-down, gpu-thermal, dnsblockd-down, emeet-pixyd-down
- Dashboard: signoz-overview.json
- AMD GPU metrics via textfile collector (busy%, mem%, temp, VRAM)
- Journald log ingestion for key services
- All components enabled by default, individually toggleable

### SigNoz Alert Rules

- 7 alert rules covering: disk space, CPU, memory, systemd failures, GPU thermal, dnsblockd health, emeet-pixyd health
- Provisioned declaratively via `signoz-provision` oneshot service

### EMEET PIXY Daemon — UI Resilience (Uncommitted)

- `app.js`: offline banner with animated dot, exponential backoff stream reconnect (3s→30s), PTZ slider revert-on-failure, button loading states, request dedup, timeout handling
- `style.css`: `.offline-banner`, `.offline-dot` (pulsing), `.btn-loading` styles
- `handlers.go`: CSP header relaxed with `unsafe-eval` for htmx
- `templates.templ`: removed redundant `hx-on::do-action` body attribute
- **Status**: Working locally, NOT committed

### CI/CD

- `nix-check.yml`: builds both platforms, runs statix/deadnix/alejandra, Go tests for emeet-pixyd
- `flake-update.yml`: weekly auto flake.lock update PRs
- Pre-commit hooks: gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check

---

## B) PARTIALLY DONE

### Hermes Deployment

- Module is 100% coded and committed. Needs `just switch` to deploy.
- Old imperative `nix profile install` still active (`hermes-agent 0.10.0` at `/nix/store/jay476c1...`). Needs `nix profile remove hermes-agent` after deploy.
- Only `key_env` migrated for ZAI provider. Other providers in `config.yaml` may still use inline `api_key` instead of `key_env`.

### EMEET PIXY UI Improvements

- Code changes are done and working but uncommitted. 4 files modified: `handlers.go`, `app.js`, `style.css`, `templates.templ`.

---

## C) NOT STARTED

1. **Hermes `just switch` deployment** — the declarative module has never been activated
2. **Hermes key_env migration** — only ZAI provider uses `key_env`, others still have inline API keys
3. **Hermes `nix profile remove`** cleanup of old imperative install
4. **Old `~/.config/systemd/user/hermes-gateway.service`** — already deleted, but HM-generated replacement needs deploy to confirm
5. **Full `just switch` smoke test** — verify all services come up clean after Hermes integration
6. **Hermes cron job audit** — verify cron jobs run correctly with new declarative service
7. **SigNoz hermes-gateway log ingestion** — add `hermes-gateway.service` to journald receiver units in signoz collector config
8. **SigNoz hermes alert rule** — add alert for hermes-gateway being down
9. **SigNoz dashboard widget** — add Hermes gateway status to overview dashboard
10. **macOS cross-platform validation** — `just test-fast` only runs nixosConfigurations; darwin config needs separate check

---

## D) TOTALLY FUCKED UP / ISSUES

1. **Hermes still running imperatively** — the old `nix profile install` binary is live while the declarative module sits unactivated. Any config drift between the two is invisible until deploy.
2. **No rollback plan documented** — if `just switch` breaks hermes, the old profile service is already deleted. Need to know how to fall back.
3. **Sops template race condition** — the `ExecStartPre` merge script reads from the sops-rendered template. If sops hasn't rendered yet (first boot), the script will fail. No ordering dependency declared between sops-nix activation and the HM user service.
4. **emeet-pixyd CSP `unsafe-eval`** — the CSP was relaxed to allow `unsafe-eval` for htmx. This weakens XSS protection. Should investigate if htmx can work without eval.

---

## E) WHAT WE SHOULD IMPROVE

1. **Service dependency ordering**: Hermes HM service should have `After=sops-nix.service` equivalent. Currently no explicit dependency.
2. **Key migration**: All Hermes API keys should use `key_env` instead of inline plaintext in `config.yaml`.
3. **Monitoring coverage**: Hermes is a critical gateway but has no alert rule, no log ingestion, no dashboard widget in SigNoz.
4. **CSP hardening**: Remove `unsafe-eval` from emeet-pixyd CSP if possible.
5. **Deployment validation**: After `just switch`, need automated smoke test (healthcheck endpoint, service status check).
6. **Old profile cleanup**: Document the exact cleanup steps in AGENTS.md.
7. **Status report bloat**: `docs/status/archive/` has 80+ reports. Consider auto-pruning reports older than 30 days.
8. **Flake lock staleness**: No alerting when flake.lock inputs get too old. The weekly auto-update PRs exist but no notification if they fail.
9. **Hermes config in repo**: `~/.hermes/config.yaml` is not managed by Nix. Consider making it declarative via HM `home.file`.
10. **Secrets audit**: Verify all 5 hermes sops secrets are actually used and none are stale.

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Task                                                                          | Effort  |
| --- | -------- | ----------------------------------------------------------------------------- | ------- |
| 1   | **P0**   | `just switch` to deploy Hermes declarative module                             | 5 min   |
| 2   | **P0**   | `nix profile remove hermes-agent` cleanup                                     | 1 min   |
| 3   | **P0**   | Smoke test: verify hermes-gateway starts, Discord bot connects, cron jobs run | 10 min  |
| 4   | **P1**   | Commit emeet-pixyd UI resilience changes (4 files)                            | 2 min   |
| 5   | **P1**   | Add `hermes-gateway.service` to SigNoz journald receiver units                | 5 min   |
| 6   | **P1**   | Add Hermes-down alert rule to SigNoz                                          | 5 min   |
| 7   | **P1**   | Migrate remaining Hermes providers to `key_env` in config.yaml                | 10 min  |
| 8   | **P1**   | Add sops-nix ordering dependency to Hermes HM service                         | 5 min   |
| 9   | **P2**   | Make `~/.hermes/config.yaml` declarative via Home Manager                     | 15 min  |
| 10  | **P2**   | Add Hermes status to SigNoz overview dashboard                                | 10 min  |
| 11  | **P2**   | Investigate removing `unsafe-eval` from emeet-pixyd CSP                       | 20 min  |
| 12  | **P2**   | Add Hermes healthcheck endpoint monitoring (if available)                     | 10 min  |
| 13  | **P2**   | Run full `just test` (slow build validation) to verify everything             | 30 min  |
| 14  | **P2**   | Prune old status reports from `docs/status/archive/`                          | 5 min   |
| 15  | **P2**   | Add flake.lock staleness alert (CI check or systemd timer)                    | 15 min  |
| 16  | **P3**   | Audit Hermes cron jobs for correctness with declarative service               | 10 min  |
| 17  | **P3**   | Validate darwin config builds (`just test-fast` equivalent for macOS)         | 10 min  |
| 18  | **P3**   | Add deployment rollback procedure to AGENTS.md                                | 10 min  |
| 19  | **P3**   | Document Hermes cleanup steps in AGENTS.md                                    | 5 min   |
| 20  | **P3**   | Secrets audit: verify all 5 hermes sops keys are active                       | 10 min  |
| 21  | **P3**   | Add `just hermes-health` command for quick status check                       | 5 min   |
| 22  | **P3**   | Consider adding Hermes to Homepage dashboard                                  | 10 min  |
| 23  | **P4**   | Review Hermes `MemoryMax=4G` — is 4GB appropriate? Monitor actual usage       | ongoing |
| 24  | **P4**   | Add WatchdogSec handler — what should Hermes do on watchdog timeout?          | 10 min  |
| 25  | **P4**   | Consider adding Hermes metrics endpoint for SigNoz scraping                   | 30 min  |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Does the Hermes gateway have a healthcheck or status endpoint we can monitor?**

The current health check is "is the systemd service running?" — but the Discord bot could be disconnected, API keys could be invalid, or cron jobs could be silently failing. If Hermes exposes `GET /health` or similar, we should add a SigNoz alert rule and Prometheus scrape target for it. If not, we should at minimum monitor the journald logs for error patterns.

I cannot determine this without access to the Hermes documentation or testing the deployed binary. This should be the first thing checked after `just switch`.

---

## Uncommitted Changes

| File                                | Status   | Description                                                                          |
| ----------------------------------- | -------- | ------------------------------------------------------------------------------------ |
| `pkgs/emeet-pixyd/handlers.go`      | Modified | CSP header: added `unsafe-eval` for htmx                                             |
| `pkgs/emeet-pixyd/static/app.js`    | Modified | Offline banner, stream reconnect, PTZ revert, button loading, request dedup, timeout |
| `pkgs/emeet-pixyd/static/style.css` | Modified | `.offline-banner`, `.offline-dot`, `.btn-loading` styles                             |
| `pkgs/emeet-pixyd/templates.templ`  | Modified | Removed redundant `hx-on::do-action` body attribute                                  |

## Recent Commits (Today)

```
36418e1 fix(nixos): statix W20 — merge repeated attribute keys + harden hermes
632bdb0 fix(twenty): wrap pg_dump backup ExecStart in bash to enable shell variable expansion
b3a2687 docs(status): comprehensive hermes integration status report — 2026-04-20 13:46
36b5205 docs(status): comprehensive security and observability status report — 2026-04-20 11:00
9dc5f21 docs(hermes): add AGENTS.md section and justfile commands
a20c662 fix(hermes): replace .env symlink with sops merge script
b5ba48f feat(signoz): add GPU thermal, dnsblockd, and emeet-pixyd alert rules; fix dnsblockd CSS gradient
3033750 fix(security): harden dnsblockd against XSS, fix node_exporter systemd collector, improve CI
05c862e feat(hermes): declarative NixOS integration — flake input, HM service, sops secrets
```
