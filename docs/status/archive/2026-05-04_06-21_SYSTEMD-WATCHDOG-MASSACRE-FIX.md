# Full System Status Report — 2026-05-04 Systemd Watchdog Massacre Fix

**Generated:** 2026-05-04 06:21 CEST
**Author:** Crush (GLM-5.1)
**Commit:** 4a760da (pushed to origin/master)
**Platform:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)

---

## Executive Summary

**The problem:** Systemd `WatchdogSec` was set on 10+ long-running services that don't implement `sd_notify()`. This caused systemd to kill healthy services every 30s, creating crash loops that made Hermes, ComfyUI, and TaskChampion completely non-functional. The watchdog is a dead man's switch — the service must periodically call `sd_notify("WATCHDOG=1")` or systemd assumes it's hung and terminates it. Python, Node.js, and most Go/Rust services never call this function.

**The fix:** Removed `WatchdogSec` from all services that don't implement `sd_notify()`. Kept it only on Caddy and Gitea (both `Type=notify` Go services that support it). Also fixed Caddy config error, Caddy metrics deprecation, and `StartLimitBurst`/`StartLimitIntervalSec` placement in wrong systemd section.

---

## a) FULLY DONE

### 1. WatchdogSec Mass Fix — 10 Services Fixed

**Root cause:** `WatchdogSec` was set in `lib/systemd/service-defaults.nix` (default 30s, later 60s) and individually on services via `mkForce "30"`. None of these services implement `sd_notify()`.

**Services that were CRASH-LOOPING:**

- **Hermes** (Python) — Killed every 30s at epoll_wait event loop. Completely non-functional.
- **ComfyUI** (Python) — Killed every 60s after loading models. Crash-looping.
- **TaskChampion** (Rust/tokio) — Killed every 30s at epoll_wait. 80+ restarts logged.

**Services with LATENT time bomb (would crash under load):**

- SigNoz query service (Go, no sd_notify)
- SigNoz OTel collector (Go, no sd_notify)
- cadvisor (Go, no sd_notify)
- Homepage dashboard (Node.js)
- Immich server (Node.js)
- Immich ML (Python) — had 300s but still wrong
- Authelia (Go, no sd_notify)
- EMEET PIXY daemon (Go)

**Services correctly using WatchdogSec (KEPT):**

- Caddy (`Type=notify`, implements sd_notify)
- Gitea (`Type=notify`, implements sd_notify)

**Commits:** `2f68153`, `0909f06`, `2a7eac3`, `9198775`, `7056155`, `3d64bb6`

**Verified:** Zero watchdog timeouts after deploy. TaskChampion stable for 1d+ before clean restart.

### 2. Caddy Config Fix — Production Reverse Proxy Was DOWN

**Problem:** Caddy was failing to start with `unrecognized servers option 'bind'` error. The `bind` directive was never valid inside the `servers {}` block — it belongs as a global `default_bind` option or in site blocks.

**Fix:** Replaced `servers { bind 192.168.1.150 }` with top-level `default_bind 192.168.1.150`. Also moved `metrics` out of deprecated `servers {}` block to global `metrics` option.

**Commit:** `f43a28a`, `1e28690`

**Verified:** Caddy reloaded with no errors.

### 3. StartLimitBurst/StartLimitIntervalSec Section Fix

**Problem:** These directives were in `lib/systemd/service-defaults.nix` which gets merged into `serviceConfig` → `[Service]` section. They belong in `[Unit]`. Systemd was silently ignoring them with "Unknown key" warnings.

**Fix:** Removed from `service-defaults.nix`. Added as top-level service options (`startLimitBurst`, `startLimitIntervalSec`) in the 4 services that use `serviceDefaults` (ComfyUI, TaskChampion, photomap, voice-agents).

**Commit:** `d9109f1`

### 4. AGENTS.md Documentation

Added `WatchdogSec / sd_notify Rules` section to AGENTS.md documenting which services support sd_notify and the rule that `WatchdogSec` must NEVER be set on services that don't.

**Commit:** `d815a2c`

---

## b) PARTIALLY DONE

### 1. Service Health Audit — Found Issues Not Yet Fixed

The comprehensive audit revealed several pre-existing issues that are documented but not fixed:

| Issue                                            | Severity            | Status                        |
| ------------------------------------------------ | ------------------- | ----------------------------- |
| Hermes skill file PermissionError                | Medium              | Not investigated              |
| ComfyUI venv path missing                        | High (ComfyUI down) | Not investigated              |
| prometheus-node-exporter amdgpu.prom parse error | Low                 | Not investigated              |
| cadvisor containers.json missing                 | Low                 | Expected with podman          |
| Gitea mirror sync auth failure                   | Low                 | Expected (GitHub token issue) |

---

## c) NOT STARTED

### 1. serviceDefaults Consolidation

Only 4 of ~15 services use `serviceDefaults`. The rest inline `Restart`, `RestartSec`, etc. in `serviceConfig`. This creates inconsistency and was the source of the StartLimitBurst bug.

### 2. ComfyUI venv Path Fix

ComfyUI fails to start because `/home/lars/projects/anime-comic-pipeline/venv/bin/python` doesn't exist. The venv may have been deleted or moved.

### 3. Hermes Skill File Permissions

Hermes gets `PermissionError: [Errno 13] Permission denied: '/home/hermes/skills/github/github-auth/.SKILL.md.tmp.*'` every few minutes. The `/home/hermes` directory exists but is empty — skills appear to be at a different path or the tmpfiles rules don't cover the skills subdirectory correctly.

### 4. AMD GPU Metrics Prometheus Exporter

`amdgpu.prom` textfile collector has empty values, causing parse errors in node_exporter.

---

## d) TOTALLY FUCKED UP

### 1. lib/systemd/service-defaults.nix Was a Trap

The shared defaults function was designed to DRY up service config, but it included `WatchdogSec`, `StartLimitBurst`, and `StartLimitIntervalSec` — all of which were either:

- **Toxic** (WatchdogSec kills services without sd_notify)
- **Misplaced** (StartLimit* goes in [Unit] not [Service], was silently ignored)

This means the "best practice" shared helper was actually injecting bugs into every service that used it. The intention was good but the execution was dangerous because systemd silently ignores unknown keys in wrong sections instead of erroring.

### 2. Pre-commit Hook Git Ref Conflict

During the session, the pre-commit hook caused a `fatal: cannot lock ref 'HEAD'` error because concurrent commits changed the ref. This resulted in a caddy metrics fix being bundled with an unrelated justfile commit. Not data-loss, but messy history.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **serviceDefaults should be a NixOS module, not a function** — A function that returns attrsets is fragile (wrong section placement). A NixOS module that sets `systemd.services.<name>.serviceConfig` AND top-level options would be type-safe.

2. **Add CI validation for systemd service configs** — A check that greps generated `.service` files for `Unknown key` warnings would catch section placement bugs immediately.

3. **Never use `mkForce` for values that match defaults** — Many services had `WatchdogSec = lib.mkForce "30"` which is the same as the old default. This is copy-paste without thought.

### Process

4. **Always deploy after fixes** — I committed watchdog fixes in the first session but didn't deploy. Services stayed crashed until the next session.

5. **Audit before and after** — Should have run a comprehensive service health check before starting AND after deploying.

6. **Check existing code before creating shared helpers** — The `service-defaults.nix` was created without understanding systemd section requirements. Should have read systemd docs first.

### Documentation

7. **AGENTS.md should have warned about WatchdogSec** — The sd_notify rule was documented only AFTER the incident. Architecture rules should be documented proactively.

8. **service-defaults.nix should have had a header comment explaining sd_notify** — The file had usage examples but no warning about WatchdogSec requirements.

---

## f) Top 25 Things to Do Next

### Critical (Services Down or Degraded)

| #   | Task                                                                                 | Impact | Effort |
| --- | ------------------------------------------------------------------------------------ | ------ | ------ |
| 1   | Fix Hermes skill file PermissionError — investigate `/home/hermes/skills/` ownership | High   | Low    |
| 2   | Fix ComfyUI venv path — `/home/lars/projects/anime-comic-pipeline/venv/` missing     | High   | Low    |
| 3   | Fix prometheus-node-exporter amdgpu.prom empty values                                | Medium | Low    |

### High Priority (Architecture / Reliability)

| #   | Task                                                                                 | Impact | Effort |
| --- | ------------------------------------------------------------------------------------ | ------ | ------ |
| 4   | Refactor `serviceDefaults` into a proper NixOS module with correct section placement | High   | Medium |
| 5   | Consolidate all services to use `serviceDefaults` (14 services still inline)         | Medium | Medium |
| 6   | Add `just health` check that validates no systemd "Unknown key" warnings             | Medium | Low    |
| 7   | Add pre-commit check for WatchdogSec on non-notify services                          | Medium | Low    |
| 8   | Fix Gitea mirror sync authentication (GitHub token rotation)                         | Medium | Low    |

### Medium Priority (Tech Debt / Quality)

| #   | Task                                                                                                                               | Impact | Effort |
| --- | ---------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 9   | Remove `Restart = lib.mkForce "on-failure"` when it matches default — cleanup copy-paste                                           | Low    | Low    |
| 10  | Audit all `mkForce` uses — remove those that match defaults                                                                        | Low    | Low    |
| 11  | Standardize `startLimitBurst`/`startLimitIntervalSec` across all services (some have none, some have 3/60, some 5/300, some 5/600) | Low    | Low    |
| 12  | Add systemd service unit tests — verify generated .service files have no warnings                                                  | Low    | Medium |
| 13  | Move cadvisor `NoNewPrivileges = false` override to a comment explaining WHY                                                       | Low    | Low    |
| 14  | Fix Hermes deprecated MESSAGING_CWD .env warning                                                                                   | Low    | Low    |
| 15  | Fix Hermes `GATEWAY_ALLOW_ALL_USERS` — move from .env to Environment (already partially done)                                      | Low    | Low    |

### Lower Priority (Improvements / Nice-to-Have)

| #   | Task                                                                                           | Impact | Effort |
| --- | ---------------------------------------------------------------------------------------------- | ------ | ------ |
| 16  | Investigate cadvisor `containers.json` missing — podman socket vs docker socket                | Low    | Medium |
| 17  | Add SigNoz alert for services entering crash-loop (start-limit-hit)                            | Medium | Medium |
| 18  | Create `just services-health` command that checks all managed services                         | Medium | Low    |
| 19  | Document all services with their sd_notify status in AGENTS.md table                           | Low    | Low    |
| 20  | Add `Type = "notify"` comment to Caddy/Gitea serviceConfig for clarity                         | Low    | Low    |
| 21  | Review all hardened services for missing library paths (like Hermes opus issue pattern)        | Low    | Medium |
| 22  | Investigate Authelia Go service — does it support sd_notify? Could add WatchdogSec back if yes | Low    | Low    |
| 23  | Add `just watchdog-audit` command that checks all services for sd_notify compatibility         | Low    | Low    |
| 24  | Create service module template with correct section placement                                  | Low    | Low    |
| 25  | Update flake.nix overlays to use shared lib types for service config                           | Low    | Medium |

---

## g) Top Question I Cannot Figure Out Myself

**Why is Hermes writing to `/home/hermes/skills/` when `stateDir` is `/var/lib/hermes`?**

The module defines `stateDir = "/var/lib/hermes"` and sets `HOME = cfg.stateDir` in the Environment. But the PermissionError shows Hermes trying to write to `/home/hermes/skills/github/github-auth/.SKILL.md.tmp.*`. Neither `/home/hermes/` nor `/home/hermes/skills/` exist as real directories (`find` shows nothing inside them). The Hermes binary may have a hardcoded path or a separate config pointing to `/home/hermes`. I cannot determine this without:

1. Reading the Hermes source code to find where it resolves the skills directory
2. Checking if there's a `config.yaml` in the state dir that overrides paths
3. Understanding if `/home/hermes` is the system user's `$HOME` from `users.users.hermes.home`

---

## Session Commits

| Commit    | Description                                                                 |
| --------- | --------------------------------------------------------------------------- |
| `2f68153` | fix(systemd): remove WatchdogSec from service-defaults                      |
| `0909f06` | fix(hermes): remove WatchdogSec — service doesn't support sd_notify         |
| `2a7eac3` | fix(comfyui): remove WatchdogSec — Python app doesn't support sd_notify     |
| `9198775` | fix(taskchampion): remove WatchdogSec — crash-looping from watchdog timeout |
| `7056155` | fix(signoz): remove WatchdogSec from all SigNoz services                    |
| `3d64bb6` | fix: remove WatchdogSec from services without sd_notify support             |
| `f43a28a` | fix(caddy): use default_bind instead of servers block bind                  |
| `d815a2c` | docs: add WatchdogSec/sd_notify rules to AGENTS.md                          |
| `d9109f1` | fix(systemd): move StartLimitBurst/StartLimitIntervalSec to [Unit] section  |
| `1e28690` | fix(justfile): platform-aware file opener in dep-graph, trash for clean     |
| `3a4b1cd` | fix(justfile): replace remaining rm -rf with trash                          |
| `d147edd` | fix(caddy): use config.networking.local.subnet instead of hardcoded IP      |

---

_Report generated by Crush (GLM-5.1) — 2026-05-04 06:21 CEST_
