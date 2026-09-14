# SystemNix Comprehensive Status Report

**Date:** 2026-04-22 03:36 CEST
**Author:** Crush (AI Agent) + Lars
**Trigger:** `nh os switch` caused DNS outage + infinite activation hang

---

## Executive Summary

A routine `nh os switch` caused a complete DNS outage and hung the activation process for an extended period. Root cause analysis identified **5 oneshot services** blocking `multi-user.target` and a **hard dependency** (`Requires`) in dnsblockd that could cascade into DNS failure. All issues have been fixed and committed (commits `cd6aba0` and `4144b42`).

**The fixes are committed but NOT YET APPLIED** — the current running system still has the old configuration. The next `just switch` will apply the fixes.

---

## a) FULLY DONE

### 1. Root Cause Analysis — Complete

Identified the full causal chain of the DNS outage and activation hang:

**Activation hang chain:**

```
unsloth-setup.service (oneshot, wantedBy=multi-user.target)
  → blocks multi-user.target
  → blocks graphical.target
  → desktop unavailable

signoz-provision.service (oneshot, partOf=signoz.service)
  → re-runs on every signoz.service restart (partOf triggers it)
  → has 120s preStart wait loop for signoz API
  → blocks multi-user.target

signoz.service was restarted during activation → signoz-provision re-ran → blocked everything
```

**DNS failure chain:**

```
dnsblockd.service has requires=["unbound.service"]
  → During activation, dnsblockd was stopped (unit changed)
  → dnsblockd restart wrapper polls for sops secrets (60s loop)
  → If restart fails repeatedly, Restart=on-failure with RestartSec=3s = restart storm
  → No StartLimitBurst protection = infinite restart loop
  → Meanwhile, unbound (the actual DNS resolver) was fine, but:
    - dnsblockd being in a restart loop could consume resources
    - The activation itself was blocked by unsloth-setup/signoz-provision
    - Race conditions between sops secret decryption and service restarts
```

### 2. DNS Blocker Hardening — Complete (commit `cd6aba0`)

- **`dnsblockd.service`**: Changed `requires = ["unbound.service"]` → `wants = ["unbound.service"]`
  - If unbound restarts or fails, dnsblockd is NOT killed (with Requires, unbound stopping would cascade to dnsblockd stopping)
  - dnsblockd is just the block page server — DNS resolution (unbound) works independently
- **Added restart rate limiting**: `StartLimitBurst = 5` / `StartLimitIntervalSec = 60`
  - Prevents infinite restart storms during activation
  - After 5 restarts in 60s, systemd stops retrying
- **File**: `platforms/nixos/modules/dns-blocker.nix`

### 3. Service Dependency Decoupling — Complete (commit `4144b42`)

All 5 blocking oneshot services decoupled from `multi-user.target`:

| Service                | File               | Old wantedBy        | New wantedBy             | Impact                                                                    |
| ---------------------- | ------------------ | ------------------- | ------------------------ | ------------------------------------------------------------------------- |
| `unsloth-setup`        | `ai-stack.nix`     | `multi-user.target` | `unsloth-studio.service` | No longer blocks boot/activation                                          |
| `signoz-provision`     | `signoz.nix`       | `multi-user.target` | `signoz.service`         | No longer blocks; removed `partOf` so it doesn't re-run on signoz restart |
| `whisper-asr-pull`     | `voice-agents.nix` | `multi-user.target` | `whisper-asr.service`    | No longer blocks; was `TimeoutStartSec=0` (infinite!)                     |
| `gitea-generate-token` | `gitea.nix`        | `multi-user.target` | `gitea.service`          | No longer blocks; short-circuits if token exists                          |
| `gitea-runner-token`   | `gitea.nix`        | `multi-user.target` | `gitea.service`          | No longer blocks; short-circuits if token exists                          |

### 4. Validation — Complete

- `just test-fast` passes (Nix syntax + flake check)
- All 4 modified files verified with `grep` for correct dependency changes

---

## b) PARTIALLY DONE

### 1. Changes Committed But Not Applied

The two commits (`cd6aba0` and `4144b42`) are on master but **not yet switched** to the running system. The currently running config is the OLD one with the bugs.

### 2. `graphical.target` Currently Blocked

Right now (03:36 CEST), the system has:

```
JOB UNIT                     TYPE  STATE
146 graphical.target         start waiting
147 multi-user.target        start waiting
319 signoz-provision.service start running
```

`signoz-provision` is stuck in its `preStart` (120s curl loop waiting for signoz API). This is from the OLD config. It will eventually timeout or succeed, but it's blocking the entire desktop.

---

## c) NOT STARTED

### 1. Apply the Fix

Need to run `just switch` to activate the new configuration. This will fix:

- The activation hang (no more oneshots blocking multi-user.target)
- The DNS outage risk (dnsblockd no longer requires unbound)

### 2. `service-health-check.service` Fix

This service has been failing every 15 minutes. It's a oneshot timer that checks critical services and notifies on failure. Currently failed. Root cause unknown — likely checking for a service that's in a failed state (unsloth-studio?).

### 3. `unsloth-studio.service` Fix

Currently crash-looping with `ModuleNotFoundError: No module named 'structlog'`. The Python venv at `/data/unsloth/venv` is missing the `structlog` package. This is a pre-existing bug unrelated to our changes. Restart counter is at 162+.

### 4. SigNoz JWT Secret Warning

```
ERROR: CRITICAL SECURITY ISSUE: No JWT secret key specified!
SIGNOZ_TOKENIZER_JWT_SECRET environment variable is not set.
```

SigNoz is running without JWT authentication. Sessions are vulnerable to tampering.

---

## d) TOTALLY FUCKED UP

### 1. `unsloth-studio.service` — Crash Loop (162+ restarts)

```
ModuleNotFoundError: No module named 'structlog'
```

The Python venv is broken — missing a core dependency. `structlog` should have been installed by the setup script. The setup script marked itself complete (`/data/unsloth/.studio-setup-done` exists) but the installation is incomplete. The service will restart forever (Restart=on-failure, RestartSec=10s) until fixed.

### 2. `service-health-check.service` — Failing Every 15 Minutes

This timer-driven health check has failed on every run since at least 02:30. No output/logs beyond exit code 1. Likely checking for services that are in failed state.

### 3. `signoz-provision.service` — Currently Blocking Boot

As of 03:36, still in `preStart` waiting for signoz API to respond. This is the exact problem we fixed in the committed code, but the fix hasn't been applied yet.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Never put oneshot services in `wantedBy = ["multi-user.target"]`** — they block the entire boot/activation path. Use a custom target or wire them to their dependent service.
2. **Never use `partOf` on provisioning services** — `partOf` causes them to restart when the parent restarts, which is exactly wrong for idempotent setup tasks.
3. **Never use `Requires` for soft dependencies** — dnsblockd doesn't _need_ unbound to run; it just needs it for its own functionality. `Wants` + `After` is correct.
4. **Always set `StartLimitBurst`/`StartLimitIntervalSec`** on services with `Restart=on-failure` — prevents infinite restart storms.
5. **Always set `TimeoutStartSec`** — `whisper-asr-pull` had `TimeoutStartSec = 0` (infinite), which could block activation forever.

### Observability

6. **`service-health-check` needs better logging** — currently exits with code 1 but no output, making diagnosis impossible.
7. **SigNoz JWT secret** — should be set via sops-nix, not left empty.

### Service Health

8. **Unsloth venv validation** — the setup script should verify all required modules are importable before writing `.studio-setup-done`.
9. **Unsloth crash loop protection** — should have `StartLimitBurst` to stop after N failures instead of restarting forever.

---

## f) Top 25 Things To Do Next

### Critical (Do Immediately)

1. **`just switch`** — Apply the committed fixes to stop the bleeding
2. **Fix `unsloth-studio` crash loop** — `pip install structlog` in the venv, or re-run setup
3. **Investigate `service-health-check`** failures — add verbose logging, fix whatever it's checking
4. **Set `SIGNOZ_TOKENIZER_JWT_SECRET`** via sops-nix — critical security issue

### High Priority (This Week)

5. **Add `StartLimitBurst`/`StartLimitIntervalSec`** to ALL services with `Restart=on-failure` across the repo
6. **Audit ALL remaining services** for `wantedBy = ["multi-user.target"]` with `Type = "oneshot"` — we got the main ones but there may be more
7. **Add `TimeoutStartSec`** to `whisper-asr-pull` (currently infinite)
8. **Add venv validation** to `unsloth-setup` — verify modules before marking done
9. **Improve `service-health-check`** — add verbose output, log which services failed
10. **Add systemd service restart limits** to `unsloth-studio` to prevent infinite crash loops

### Medium Priority (Next Two Weeks)

11. **Review `signoz-collector` `preStart` migrations** — these run on every start and could be slow
12. **Consider `ReloadPropagatedFrom`** for dnsblockd ← unbound relationship instead of just `After`
13. **Add `systemd-analyze verify`** to CI/test pipeline to catch dependency issues
14. **Review Docker-based services** (`twenty`, `whisper-asr`) for `ExecStop` reliability
15. **Add `Wants=` instead of hard deps** for all services that depend on `docker.service`
16. **Review `networking.localCommands`** for the blockIP — should it be a separate oneshot service?
17. **Consider `ExecReload`** for dnsblockd to reload config without restarting
18. **Add health check endpoints** to custom services (dnsblockd already has one at :9090/metrics)

### Lower Priority (Backlog)

19. **NixOS test** for the DNS blocker stack (unit test that verifies DNS works when dnsblockd is down)
20. **Unified service dependency graph** — generate and visualize with `systemd-analyze dot`
21. **Review `earlyoom` configuration** — ensure it doesn't kill DNS services under memory pressure
22. **Consider moving `signoz-provision` to a timer** instead of running on every signoz start
23. **Add `FailureAction`/`SuccessAction`** to critical services for automated recovery
24. **Document the systemd dependency patterns** in AGENTS.md for future service additions
25. **Review `hermes-wait-online`** (new service from activation diff) — ensure it's not blocking

---

## g) Top #1 Question I Cannot Answer

**Why did `service-health-check` start failing, and what exactly is it checking?**

The service runs as user `lars` every 15 minutes via a timer. It fails with exit code 1 but produces **zero output** — no stdout, no stderr beyond the systemd status messages. I cannot see the script contents (it's a Nix store path `/nix/store/l3di2zvnzqazv33ipj7aild92zxrr0gr-service-health-check`) and I cannot find its definition in the repo. It may be defined in a Home Manager config or generated dynamically. The question is: **what is it checking, why is it failing, and where is it defined?**

---

## Current System State Snapshot

### Running Services (42 total)

All core services running: unbound, dnsblockd, caddy, docker, gitea, immich, signoz, clickhouse, ollama, postgresql, redis, authelia, homepage, cadvisor, twenty, taskchampion, minecraft-server

### Failed Services (1)

- `service-health-check.service` — failing every 15 min timer

### Crash-Looping Services (1)

- `unsloth-studio.service` — 162+ restarts, missing `structlog` module

### Blocked Targets (2)

- `graphical.target` — waiting for signoz-provision to complete
- `multi-user.target` — waiting for signoz-provision to complete

### DNS Status

- `unbound.service` — **active (running)** since 03:09:58
- `dnsblockd.service` — **active (running)** since 03:10:11
- DNS is currently **working** (was restored after reboot)

### Commits (unapplied)

```
4144b42 feat(nixos): soften systemd service dependencies and refine target activation
cd6aba0 feat(nixos/dns-blocker): enhance dnsblockd systemd service reliability and dependency management
```

---

## Files Modified

| File                                      | Change                                                                         | Commit    |
| ----------------------------------------- | ------------------------------------------------------------------------------ | --------- |
| `platforms/nixos/modules/dns-blocker.nix` | `requires` → `wants` for unbound; added StartLimitBurst                        | `cd6aba0` |
| `modules/nixos/services/signoz.nix`       | Removed `partOf`/`requires` from signoz-provision; `wantedBy` → signoz.service | `4144b42` |
| `modules/nixos/services/gitea.nix`        | Both token services: `requires` → `wants`, `wantedBy` → gitea.service          | `4144b42` |
| `modules/nixos/services/voice-agents.nix` | whisper-asr-pull: `wantedBy` → whisper-asr.service                             | `4144b42` |
| `platforms/nixos/desktop/ai-stack.nix`    | unsloth-setup: `wantedBy` → unsloth-studio.service                             | `4144b42` |
