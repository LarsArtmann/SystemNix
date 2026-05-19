# Session 59 — Comprehensive Status Report

**Date:** 2026-05-19 18:13
**Branch:** master
**Host:** evo-x2 (NixOS 26.05, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)
**Companion:** Lars-MacBook-Air (macOS, aarch64-darwin)

---

## Executive Summary

Forgejo is **DOWN** since the last `just switch` due to a `.admin-password` file ownership bug. The fix is ready but not yet deployed. All other services are healthy except the Forgejo Actions runner (which depends on Forgejo being up). The system has been running stable otherwise with dual-WAN in degraded mode (ISP down, no WiFi fallback).

---

## a) FULLY DONE

### Forgejo Password File Ownership Fix (this session)

**Problem:** Forgejo preStart fails with `Permission denied` reading `/var/lib/forgejo/.admin-password` because the file was owned by `root:root`. The nixpkgs Forgejo module runs `preStart` as the `forgejo` user — if the password file exists with wrong ownership, Forgejo can't read it.

**Root cause chain:**
1. `preStart` script creates `.admin-password` as forgejo user (correct)
2. BUT if the file was previously created by root (e.g., during initial setup or tmpfiles), it stays `root:root`
3. The `tmpfiles.rules` `z` entry was a band-aid that only runs during activation, not service restarts
4. Forgejo preStart fails → Forgejo crashes → runner gets `connection refused`

**Fix applied:**
- Removed `tmpfiles.rules` `z` entry (unreliable timing)
- Added root-level `ExecStartPre` with `+` prefix (runs as root regardless of service User=)
- Script: creates password file if missing, then `chown forgejo:forgejo` + `chmod 600`
- Uses `lib.mkBefore` to run before the nixpkgs module's own `ExecStartPre`
- `just test-fast` passes — awaiting `just switch` to deploy

### Session 58 — Complete Gitea→Forgejo Migration (previous)

- All subdomain references renamed from `gitea.home.lan` → `forgejo.home.lan`
- DNS records, Caddy vhost, Forgejo ROOT_URL/DOMAIN, Authelia client_id/callback, Homepage all updated
- Deprecated `gitea_token` sops secret removed
- jq variable mismatch fixed in mirror scripts

### Session 58 — Service Startup Fixes (previous)

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Caddy killed by systemd | `WatchdogSec=30` set but Caddy only sends `READY=1`, not `WATCHDOG=1` | Removed `WatchdogSec` |
| nvme-metrics exit 1 | `harden {}` drops all capabilities; `nvme smart-log` needs `CAP_SYS_ADMIN` | Added `CapabilityBoundingSet = "CAP_SYS_ADMIN"` |

### Session 57 — DNS Config Drift Fix

- Created shared `dns-resolver.nix` module to prevent `nameservers` / `do-ip6` divergence
- Both evo-x2 and rpi3-dns import the same module now

### Session 57 — Unsloth Removal

- Removed all Unsloth AI references from the codebase

### Session 56 — art-dupl Migration + BDD Tests

- Migrated art-dupl from fork branch to master
- 253/253 BDD tests passing

### Core Infrastructure (long-standing, stable)

- **Nix flake** — 47 inputs, 112 .nix files, 36 service modules, 19 shell scripts
- **Cross-platform** — macOS + NixOS via shared `platforms/common/` (~80% shared)
- **DNS blocking** — Unbound + dnsblockd, 2.5M+ domains blocked, Quad9 DoT upstream
- **SigNoz observability** — Full stack: traces, metrics, logs via OTel pipeline
- **Gatus health checks** — 26+ endpoints monitored with Discord alerting
- **AI model storage** — Centralized `/data/ai/` with per-service path derivation
- **GPU defense** — `OLLAMA_MAX_LOADED_MODELS=1`, per-service memory fractions, OOM protection
- **Niri DRM healthcheck** — Automatic GPU recovery with auto-reboot on failure
- **Dual-WAN ECMP+MPTCP** — Active-active routing with route health monitor
- **Taskwarrior sync** — Zero-config cross-platform via TaskChampion + deterministic client IDs
- **EMEET PIXY webcam** — Auto-activation, call detection, privacy mode
- **Wallpaper self-healing** — `PartOf` restart propagation, no `BindsTo`
- **Lockfile hygiene** — 93 nodes, deduplicated with proper follows chains
- **Nix evaluation memory** — ~10-16 GB saved from deduplication work

---

## b) PARTIALLY DONE

### Forgejo Actions Runner

- **Status:** Config is correct but **non-functional** because Forgejo is down
- Runner tries to connect to `[::1]:3000` every 2s, fails with `connection refused`
- Has been restarting continuously (restart counter at 29+)
- Fix: deploying the Forgejo password file fix will restore the runner automatically

### Dual-WAN

- **Status:** Route health monitor detects ISP down but no WiFi fallback available
- ISP has been down with no WiFi hotspot to fall back to
- Architecture is correct — just needs WiFi availability

### rpi3-dns Backup DNS Node

- **Status:** Config written (`platforms/nixos/rpi3/`) but Pi 3 hardware **not yet provisioned**
- VRRP password still in **plaintext** in Nix store (the only TODO in the codebase)
- DNS failover cluster module written but untested
- Blocked on: physical Pi 3 setup + sops-nix age identity provisioning

### Hermes AI Agent Gateway

- **Status:** Running but hitting **HTTP 429 rate limits** from upstream AI providers
- Cron scheduler functional but some jobs fail on rate limits
- `npmDepsHash` workaround in place — fragile on upstream updates

---

## c) NOT STARTED

### ClickHouse Backup Strategy

- **Risk:** P0 data loss. Single-node ClickHouse with NO backups. If NVMe fails, ALL observability data is gone.
- SigNoz traces, metrics, and logs would be irrecoverable.

### Pi 3 Physical Provisioning

- Hardware not set up yet
- Needs: sops-nix age identity from SSH host key, VRRP password migration to sops
- SanDisk USB stick verified (docs exist) but not deployed

### Darwin Disk Management

- MacBook Air at 90-95% disk usage chronically
- `nix-collect-garbage` hangs on Darwin
- Consider distributed builds to evo-x2

### Forgejo Push Mirror Security

- `GITHUB_TOKEN` embedded in push mirror remote URLs (stored in Forgejo DB)
- Should use a dedicated PAT with minimal scope

### ComfyUI Service

- Condition check fails — service is skipped on startup
- Not critical (on-demand AI image generation) but should be fixed

### Photomap Service

- No journal entries — may not be running or configured

---

## d) TOTALLY FUCKED UP

### Forgejo DOWN (active incident)

- **Impact:** Git forge completely unavailable, Actions runner dead, GitHub sync stopped
- **Root cause:** `.admin-password` owned by `root:root`, forgejo user can't read it in preStart
- **Fix ready:** Root-level `ExecStartPre` with `+` prefix to chown the file
- **Action needed:** `just switch` to deploy
- **Duration:** Since `just switch` at 17:59 today

### ISP Down — No Internet Failover

- Route health monitor shows ISP down with no WiFi fallback
- Dual-WAN is architecturally sound but useless without a second path
- All internet-dependent services affected (GitHub sync, AI APIs, DNS upstream)

### Immich Service Not Running

- No journal entries for `immich.service` — the main service may not be configured
- ML and server components appear to run via Docker but the systemd wrapper has no entries
- Database backups ARE running (last successful backup at 02:00 today)

---

## e) WHAT WE SHOULD IMPROVE

### 1. Service Hardening Audit

The `nvme-metrics` incident revealed that `harden {}` drops ALL capabilities by default. Any service that needs special kernel access (ioctl, raw sockets, etc.) will silently break. We need a systematic audit of all 36 service modules for missing capabilities.

### 2. WatchdogSec Audit

Caddy was killed by WatchdogSec because it only sends `READY=1` not `WATCHDOG=1`. We need to verify NO other service has this misconfiguration. Currently only Forgejo has verified `sd_notify` with watchdog support.

### 3. Password/File Ownership Pattern

The `.admin-password` pattern is fragile. Consider:
- Using sops-nix for the admin password instead of generating it in preStart
- Or at minimum, add the `+ExecStartPre` pattern to all services that create files in preStart

### 4. ClickHouse Resilience

Single-node ClickHouse is the biggest unaddressed risk. Even periodic dumps to `/data` would be better than nothing.

### 5. Service Dependency Ordering

The runner depends on Forgejo via `requires` and `after`, but Forgejo's start-limit-hit means the runner keeps trying forever. Consider adding `PartOf=forgejo.service` to the runner so it stops retrying when Forgejo is down.

### 6. Darwin Build Reliability

MacBook Air disk exhaustion causes regular build failures. Need either disk cleanup automation or distributed builds to evo-x2.

### 7. Lockfile Freshness

47 flake inputs need periodic updates. Consider automated flake.lock updates via Forgejo Actions (once runner is working).

### 8. ComfyUI Startup

The service is condition-checked and skipped. Needs investigation.

---

## f) Top 25 Things We Should Get Done Next

| # | Priority | Task | Effort | Impact |
|---|----------|------|--------|--------|
| 1 | **P0** | Deploy Forgejo fix (`just switch`) | 5 min | Restores git forge |
| 2 | **P0** | Verify Forgejo + runner come up healthy | 5 min | Confirms fix |
| 3 | **P0** | ClickHouse backup — even a daily `pg_dump` equivalent | 2h | Prevents catastrophic data loss |
| 4 | **P1** | Service capability audit — check all 36 modules for missing `CapabilityBoundingSet` overrides | 4h | Prevents silent service failures |
| 5 | **P1** | WatchdogSec audit — verify no other service has Caddy-style misconfig | 1h | Prevents mystery service kills |
| 6 | **P1** | Fix ComfyUI startup (condition check fails) | 1h | Restores AI image generation |
| 7 | **P1** | Investigate Photomap service (no journal entries) | 30min | Determine if it's configured |
| 8 | **P1** | Investigate Immich main service (no journal entries for systemd wrapper) | 30min | Ensure photo management works |
| 9 | **P2** | Migrate Forgejo admin password to sops-nix | 2h | Eliminates fragile password file pattern |
| 10 | **P2** | Add `PartOf=forgejo.service` to runner to stop infinite retries | 15min | Cleaner failure mode |
| 11 | **P2** | Provision Pi 3 hardware + sops-nix age identity | 4h | Enables DNS failover cluster |
| 12 | **P2** | Migrate VRRP password from plaintext to sops (the only TODO in codebase) | 1h | Security fix |
| 13 | **P2** | Set up Forgejo Actions CI for automated flake.lock updates | 3h | Automates dependency management |
| 14 | **P2** | Forgejo push mirror — use dedicated GitHub PAT with minimal scope | 30min | Security improvement |
| 15 | **P2** | Hermes HTTP 429 rate limit handling — add retry/backoff | 2h | Reduces cron job failures |
| 16 | **P2** | Darwin distributed builds to evo-x2 | 3h | Fixes MacBook Air disk exhaustion |
| 17 | **P2** | Darwin automated disk cleanup | 2h | Prevents build failures |
| 18 | **P3** | Add DNSSEC validation to Unbound config | 1h | DNS security improvement |
| 19 | **P3** | Automate Forgejo repo push mirror setup (currently manual) | 3h | Reduces manual work |
| 20 | **P3** | Add Gatus endpoint for Forgejo Actions runner health | 15min | Observability gap |
| 21 | **P3** | Investigate dnsblockd TLS handshake errors from 192.168.1.62 | 30min | Reduce log noise |
| 22 | **P3** | Review all `mkForce` usage for correctness (esp. in harden overrides) | 2h | Prevents subtle config conflicts |
| 23 | **P3** | Add `nix flake check` CI via Forgejo Actions | 2h | Catches build issues before merge |
| 24 | **P3** | Document the `_local_deps` overlay pattern in a guide for new repos | 1h | Developer experience |
| 25 | **P3** | Audit all services for `BindsTo` misuse (wallpaper-style bugs) | 1h | Prevents cascade failures |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why does the `.admin-password` file end up owned by `root:root` in the first place?**

The preStart script runs as `User=forgejo` and creates the file with `head -c 32 /dev/urandom | base64 > "$PASS_FILE"`. Under normal circumstances, this should create it as `forgejo:forgejo`. Possible explanations:

1. During initial Forgejo setup or migration, something ran as root that created the file
2. The `tmpfiles.rules` `z` entry ran at activation time but the file didn't exist yet, then later the file was created by a different process
3. A previous version of the config had the file created differently

I can fix the symptom (root ExecStartPre to chown), but I cannot determine the original cause without access to historical file creation events. This is worth investigating to understand if there's a systemic pattern affecting other services.

---

## Service Health Dashboard

| Service | Status | Notes |
|---------|--------|-------|
| **Forgejo** | **DOWN** | `.admin-password` ownership bug — fix ready |
| **Forgejo Runner** | **DOWN** | Depends on Forgejo (connection refused) |
| **Caddy** | Running | Fixed WatchdogSec in Session 58 |
| **Authelia** | Running | Healthy |
| **Unbound DNS** | Running | Resolving correctly |
| **dnsblockd** | Running | TLS handshake errors from 192.168.1.62 |
| **SigNoz** | Running | v0.117.1, query service + collector healthy |
| **Gatus** | Running | 26+ endpoints monitored |
| **Homepage** | Running | No journal entries (expected for static) |
| **Ollama** | Running | GPU healthy |
| **ComfyUI** | **SKIPPED** | Condition check fails at startup |
| **Twenty CRM** | Running | Workers + server healthy |
| **OpenSEO** | Running | Docker container healthy |
| **Hermes** | Running | HTTP 429 rate limits on some cron jobs |
| **Immich ML** | Running | ML server healthy |
| **Immich Server** | Running | DB backups working (02:00 daily) |
| **Immich systemd** | **UNKNOWN** | No journal entries for main service |
| **Photomap** | **UNKNOWN** | No journal entries |
| **TaskChampion** | Running | No journal entries (expected) |
| **monitor365** | Running | No journal entries (expected) |
| **NVMe Health** | Running | Checks passing |
| **Disk Monitor** | Running | Root 91% used, /data 81% used |
| **Dual-WAN** | Degraded | ISP down, no WiFi fallback |
| **EMEET PIXY** | **UNKNOWN** | User service, no system journal |
| **Niri Health** | Running | Metrics timer active |

## System Resources

| Resource | Value | Status |
|----------|-------|--------|
| Root disk | 450G / 512G (91%) | **Warning** — approaching capacity |
| /data disk | 827G / 1.0T (81%) | OK |
| RAM | 48G / 62G used (77%) | OK |
| Swap | 9G / 25G used (36%) | OK |

## Codebase Stats

| Metric | Value |
|--------|-------|
| Total .nix files | 112 |
| Service modules | 36 |
| Shell scripts | 19 |
| Overlay files | 3 |
| Lib helpers | 7 |
| Platform configs | 60 |
| Flake inputs | 47 |
| flake.nix lines | 811 |
| Lock nodes | 93 |

---

*Report generated: 2026-05-19 18:13*
