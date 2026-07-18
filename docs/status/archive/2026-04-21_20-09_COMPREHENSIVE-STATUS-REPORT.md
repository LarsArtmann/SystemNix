# SystemNix Comprehensive Status Report

**Date:** 2026-04-21 20:09 CEST
**Branch:** master @ `adf5408`
**Platform:** NixOS (evo-x2) + macOS (Lars-MacBook-Air)
**Previous Report:** 2026-04-20_16-14_COMPREHENSIVE-POST-HERMES-STATUS.md

---

## A) FULLY DONE

### Hermes WatchdogSec Bug Fix (THIS SESSION)

- **Root cause:** `WatchdogSec=60` was set in `hermes.nix` but Hermes has **zero** `sd_notify` implementation — no `systemd.daemon` imports, no `WATCHDOG=1` keep-alives, no `NotifyAccess` config, service type is `simple` (not `notify`).
- **Effect:** Without keep-alive pings, systemd would kill the Hermes process every 60 seconds and restart it in an infinite loop via `Restart=on-failure`.
- **Fix:** Removed `WatchdogSec=60` from `modules/nixos/services/hermes.nix:102`. Hermes' own generated unit files confirm they don't include `WatchdogSec`.
- **`RestartForceExitStatus=75` validated:** Confirmed Hermes explicitly uses exit code 75 (`EX_TEMPFAIL` from `sysexits.h`) as an IPC mechanism to request systemd restart after graceful drain/reload. The constant is defined in `gateway/restart.py` and set in `gateway/run.py`. This directive is correct and essential.

### Hermes AI Agent Gateway — Full Declarative Integration (Prior Sessions)

- Flake input, NixOS module, HM systemd service, sops secrets, merge script, systemd hardening, AGENTS.md docs, justfile commands — all committed.
- **Status:** Still NOT deployed (`just switch` not yet run).

### Statix W20 Fixes — All Clean

- `signoz.nix`, `snapshots.nix` — merged repeated attribute keys. Project-wide `statix check` passes.

### SigNoz Observability Pipeline

- Full stack: node_exporter, cAdvisor, OTel Collector, ClickHouse, Query Service
- 7 alert rules (disk-full, cpu-sustained, memory-critical, service-down, gpu-thermal, dnsblockd-down, emeet-pixyd-down)
- AMD GPU metrics via textfile collector, journald log ingestion for key services

### Sops Cleanup (Uncommitted)

- Removed stale `restartUnits` from dnsblockd TLS secrets that referenced services incorrectly:
  - `dnsblockd_ca_cert`: removed `restartUnits = ["dnsblockd.service"]` (cert is a CA cert, not directly consumed by dnsblockd service restart)
  - `dnsblockd_ca_key`: removed `restartUnits = ["dnsblockd.service"]`
  - `dnsblockd_server_cert`: removed `restartUnits = ["caddy.service"]`
  - `dnsblockd_server_key`: removed `restartUnits = ["caddy.service"]`
- Refactored `livekit_keys` to use `mkSecrets` helper instead of inline block — consistent with other secret definitions.

### DNS Blocker IP Deletion Safety (Uncommitted)

- `dnsblockd-del-ip` script now checks if the block IP is the only address on the interface before deleting it, preventing accidental removal of the primary/static IP.
- Counts matching addresses with `ip -4 addr show` + grep; only deletes if count > 1.

### CI/CD

- `nix-check.yml`: builds both platforms, statix/deadnix/alejandra, Go tests
- `flake-update.yml`: weekly auto flake.lock update PRs
- Pre-commit hooks: gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check

---

## B) PARTIALLY DONE

### Hermes Deployment

- Module is 100% coded and committed (with WatchdogSec fix now). Needs `just switch` to deploy.
- Old imperative `nix profile install` still active. Needs `nix profile remove hermes-agent` after deploy.
- Only ZAI provider migrated to `key_env`. Other providers in `config.yaml` may still use inline `api_key`.

### EMEET PIXY UI Improvements

- Code changes done and working but uncommitted: `handlers.go` (CSP `unsafe-eval` for htmx), `app.js` (offline banner, reconnect, PTZ revert, loading states), `style.css` (offline/loading styles), `templates.templ` (removed redundant hx-on attribute).

### Sops + DNS Blocker Changes

- Fixes are coded but uncommitted (see diffs above).

---

## C) NOT STARTED

1. **Hermes `just switch` deployment** — the declarative module has never been activated
2. **Hermes key_env migration** — only ZAI provider uses `key_env`, others still have inline API keys
3. **Hermes `nix profile remove`** cleanup of old imperative install
4. **Sops-nix ordering dependency** — Hermes HM service has no `After=` for sops secret activation; race on first boot
5. **SigNoz hermes-gateway log ingestion** — add to journald receiver units in signoz collector config
6. **SigNoz hermes alert rule** — add alert for hermes-gateway being down
7. **SigNoz hermes dashboard widget** — add Hermes gateway status to overview dashboard
8. **macOS cross-platform validation** — darwin config needs separate check
9. **Hermes config.yaml as declarative** — `~/.hermes/config.yaml` is not managed by Nix
10. **Secrets audit** — verify all 5 hermes sops keys are actively used and none are stale
11. **Hermes healthcheck endpoint monitoring** — unknown if Hermes exposes `/health` or similar
12. **EMEET PIXY CSP hardening** — investigate removing `unsafe-eval` for htmx
13. **Deployment rollback procedure** — document in AGENTS.md
14. **Flake lock staleness alerting** — no notification when auto-update PRs fail

---

## D) TOTALLY FUCKED UP / ISSUES

1. **~~Hermes WatchdogSec=60~~** — **FIXED THIS SESSION.** Was causing kill-restart loop every 60s because Hermes has no `sd_notify` implementation.
2. **Hermes still running imperatively** — old `nix profile install` binary is live while declarative module sits unactivated. Config drift between the two is invisible until deploy.
3. **No rollback plan documented** — if `just switch` breaks hermes, the old profile service is already deleted.
4. **Sops template race condition** — `ExecStartPre` merge script reads from sops-rendered template. If sops hasn't rendered yet (first boot), script fails. No ordering dependency declared.
5. **EMEET PIXY CSP `unsafe-eval`** — relaxed for htmx, weakens XSS protection. Should investigate if htmx can work without eval.
6. **Stale git stashes** — 3 stashes exist from prior work (emeet-pixyd vendorHash, line ending normalization, Hyprland window rules). Likely outdated.

---

## E) WHAT WE SHOULD IMPROVE

1. **Remove WatchdogSec entirely** ✅ DONE — no point adding it back until Hermes implements `sd_notify`.
2. **Service dependency ordering**: Hermes HM service should have `After=` for sops-nix secret activation.
3. **Key migration**: All Hermes API keys should use `key_env` instead of inline plaintext in `config.yaml`.
4. **Monitoring coverage**: Hermes is a critical gateway but has no alert rule, no log ingestion, no dashboard widget in SigNoz.
5. **CSP hardening**: Remove `unsafe-eval` from emeet-pixyd CSP if possible.
6. **Deployment validation**: After `just switch`, need automated smoke test.
7. **Old profile cleanup**: Document exact steps in AGENTS.md.
8. **Status report bloat**: `docs/status/` has 30+ reports. Consider auto-pruning.
9. **Flake lock staleness**: No alerting when flake.lock inputs get too old.
10. **Hermes config in repo**: `~/.hermes/config.yaml` is not declarative. Consider HM `home.file`.
11. **Secrets audit**: Verify all 5 hermes sops secrets are actually used.
12. **WatchdogSec future**: If Hermes ever adds `sd_notify` support, re-add `WatchdogSec` with `Type=notify` and `NotifyAccess=all` for real hang detection.

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Task                                                                                     | Effort  |
| --- | -------- | ---------------------------------------------------------------------------------------- | ------- |
| 1   | **P0**   | `just switch` to deploy Hermes declarative module (with WatchdogSec fix)                 | 5 min   |
| 2   | **P0**   | `nix profile remove hermes-agent` cleanup                                                | 1 min   |
| 3   | **P0**   | Smoke test: verify hermes-gateway starts, Discord bot connects, cron jobs run            | 10 min  |
| 4   | **P1**   | Commit sops.nix + dns-blocker.nix + hermes.nix changes                                   | 2 min   |
| 5   | **P1**   | Commit emeet-pixyd UI resilience changes (4 files)                                       | 2 min   |
| 6   | **P1**   | Add `hermes-gateway.service` to SigNoz journald receiver units                           | 5 min   |
| 7   | **P1**   | Add Hermes-down alert rule to SigNoz                                                     | 5 min   |
| 8   | **P1**   | Migrate remaining Hermes providers to `key_env` in config.yaml                           | 10 min  |
| 9   | **P1**   | Add sops-nix ordering dependency to Hermes HM service (`After=` for sops secrets)        | 5 min   |
| 10  | **P2**   | Make `~/.hermes/config.yaml` declarative via Home Manager                                | 15 min  |
| 11  | **P2**   | Add Hermes status to SigNoz overview dashboard                                           | 10 min  |
| 12  | **P2**   | Investigate removing `unsafe-eval` from emeet-pixyd CSP                                  | 20 min  |
| 13  | **P2**   | Check if Hermes has a healthcheck/status endpoint we can monitor                         | 10 min  |
| 14  | **P2**   | Run full `just test` (slow build validation)                                             | 30 min  |
| 15  | **P2**   | Prune old status reports from `docs/status/`                                             | 5 min   |
| 16  | **P2**   | Add flake.lock staleness alert (CI check or systemd timer)                               | 15 min  |
| 17  | **P3**   | Audit Hermes cron jobs for correctness with declarative service                          | 10 min  |
| 18  | **P3**   | Validate darwin config builds                                                            | 10 min  |
| 19  | **P3**   | Add deployment rollback procedure to AGENTS.md                                           | 10 min  |
| 20  | **P3**   | Document Hermes cleanup steps in AGENTS.md                                               | 5 min   |
| 21  | **P3**   | Secrets audit: verify all 5 hermes sops keys are active                                  | 10 min  |
| 22  | **P3**   | Add `just hermes-health` command for quick status check                                  | 5 min   |
| 23  | **P3**   | Consider adding Hermes to Homepage dashboard                                             | 10 min  |
| 24  | **P4**   | Review Hermes `MemoryMax=4G` — monitor actual memory usage                               | ongoing |
| 25  | **P4**   | If Hermes adds `sd_notify`: re-add `WatchdogSec` with `Type=notify` + `NotifyAccess=all` | 10 min  |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Does the Hermes gateway expose a healthcheck or status endpoint?**

The current health check is "is the systemd service running?" — but the Discord bot could be disconnected, API keys could be invalid, or cron jobs could be silently failing. If Hermes exposes `GET /health` or similar, we should add a SigNoz alert rule and Prometheus scrape target. If not, we should at minimum monitor journald logs for error patterns.

This can only be answered after `just switch` deploys the service and we can test the running binary.

---

## Uncommitted Changes (Working Tree)

| File                                      | Change       | Description                                                                                     |
| ----------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------- |
| `modules/nixos/services/hermes.nix`       | -1 line      | Removed `WatchdogSec=60` (kill-restart loop bug)                                                |
| `modules/nixos/services/sops.nix`         | -14/+8 lines | Removed stale `restartUnits` from dnsblockd certs; refactored livekit to use `mkSecrets` helper |
| `platforms/nixos/modules/dns-blocker.nix` | +7/-1 lines  | Guard IP deletion against removing primary/static address                                       |

## Stashed Changes (Likely Stale)

| Stash       | Description                                         |
| ----------- | --------------------------------------------------- |
| `stash@{0}` | WIP: emeet-pixyd vendorHash after dependency fetch  |
| `stash@{1}` | WIP: line ending normalization in SSH status report |
| `stash@{2}` | WIP: Hyprland window rules 0.54 syntax update       |

## Recent Commits (Last 15)

```
adf5408 refactor(services): move SigNoz query service from port 8080 to 8081
e4a114c fix(niri): extend swayidle timeout from 5min to 12hrs and remove automatic screen lock
592d6c7 chore(deps): update flake lock and add taskwarrior TLS support
576e272 fix(services): relax systemd dependencies and remove stale restart trigger
bfa5c51 fix(minecraft): build custom minecraft-server-26 package with pinned version and modern JVM tuning
6a39b07 fix(hermes): update flake lock and fix package target system platform
4a8ea5a feat(monitor365): migrate from local path dependency to proper flake input
0a006f1 fix(monitor365): enable tests, scope to CLI package only
db6139c fix(monitor365): correct config generation to match actual TOML format
ea85586 refactor(monitor365): migrate from path-based flake input to local package derivation
2e25837 feat(systemnix): integrate Monitor365 device monitoring agent
15d59aa docs(emeet-pixyd): add SUPERB_ROADMAP.md — detailed improvement plan
53cce78 refine(emeet-pixyd): wrap errors, name constants, bump descendant depth, fix go.mod
6580e6e feat(nixos): add Minecraft server service module and enable on evo-x2
63595ac fix(emeet-pixyd): fix stream HTTP response, TOCTOU race, remove dead code
```
