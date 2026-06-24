# Session 89: Post-Crash Forensics — OOM Cascade, Disk Full, System Hardening

**Date:** 2026-05-25 02:32 CEST
**Scope:** Full crash forensics after OOM cascade killed evo-x2, root cause fixes, system health audit
**System:** NixOS unstable 26.05 | Linux 6.x | niri-unstable | evo-x2 (x86_64-linux, 62 GB RAM + 16 GB swap)
**Uptime:** 47 minutes (crash recovery, 2 previous boots also crashed)

---

## Executive Summary

evo-x2 **hard-crashed** at 01:39 CEST on May 25 due to an OOM cascade triggered by Helium browser (Electron/Chromium). The browser spawned 42+ renderer processes that consumed all 64 GB RAM + 16 GB swap. Because `helium` wasn't in earlyoom's `--prefer` list (only `chrome|chromium` was), earlyoom killed system services (node, python, journald) first instead of the browser. When journald itself crashed, the system cascaded to death.

**Two crashes in 2 hours** before stabilizing. Root cause fixes have been applied but **NOT YET DEPLOYED** (`just switch` needed).

**Critical new finding:** Root disk is **100% full** — 2.7 GB free on 512 GB drive. `/var/lib/unsloth` alone uses **28 GB**. System is at risk of another crash from disk exhaustion.

---

## A) FULLY DONE ✅

### 1. OOM Crash Forensics — Complete

Full chain reconstructed from journal logs across 5 boots:

| Time | Event |
|------|-------|
| 00:22 | First OOM — `llama-server` killed by earlyoom |
| 01:32–01:33 | Massive OOM wave — 35 `node`, 10 `python3`, 2 `python` killed |
| 01:33–01:38 | **42 `helium` processes** finally killed (too late) |
| 01:37:39 | `systemd-journald` watchdog timeout (3 min limit) |
| 01:38:07 | **`systemd-journald` SIGABRT** — coredump (OOM during `manager_find_journal`) |
| 01:38:29–32 | Final OOM wave — earlyoom killing everything |
| 01:38:38 | niri detects DRM zombie, attempts restart |
| 01:39:36 | earlyoom: `"Failed to kill process"` — unrecoverable |
| 01:39:45 | **System death** — boot -1 ends |
| 01:42:36 | Next boot (boot 0) starts |
| 01:45:44 | `oauth2-proxy` fails again (pre-existing, not crash-related) |

**Root cause:** Helium binary name (`helium`) didn't match earlyoom's `--prefer` regex (`chrome|chromium`). Electron processes were invisible to earlyoom's priority targeting until it was too late.

### 2. earlyoom Prefer List Fix — Code Complete

| File | Change |
|------|--------|
| `platforms/nixos/system/boot.nix:177` | Added `helium\|electron` to `--prefer` regex |

Now earlyoom will kill browser processes first (highest RSS) instead of system services.

### 3. MemoryHigh Throttling — Code Complete

| File | Change |
|------|--------|
| `lib/systemd.nix:4,25` | Added `MemoryHigh = "80%"` default to `harden {}` function |

Services now get throttled at 80% of their MemoryMax before hitting the hard kill boundary. This gives them a chance to recover (GC, cache drop) instead of sudden termination.

### 4. Previous Session Fixes (Undeployed) — All Code Complete

From sessions 87-88, already committed but not yet deployed:

| Fix | File | Commit |
|-----|------|--------|
| Docker services → `multi-user.target` | `lib/docker.nix`, `modules/nixos/services/default.nix` | Uncommitted |
| All services → `multi-user.target` | `dns-blocker.nix`, `hermes.nix`, `homepage.nix`, `signoz.nix` | Uncommitted |
| sops GPG key import fix | `modules/nixos/services/sops.nix` | Uncommitted |
| GPU udev rule fix | `platforms/nixos/hardware/amd-gpu.nix` | Uncommitted |
| Signoz NVMe SMART null safety | `modules/nixos/services/signoz.nix` | Uncommitted |

### 5. mkPreparedSource Centralization — DONE (Previous Session)

`lib/prepared-source.nix` removed. All Go repos now use `go-nix-helpers` flake input. (Session 88, commits `ae6dec24`–`d1a0fa1c`)

### 6. BTRFS Snapshot System — Production Verified (Session 88)

Root snapshots running daily via btrbk. Pre-deploy hook working. Freshness verification active.

---

## B) PARTIALLY DONE 🔧

### 1. System Resilience — Fixes Coded, NOT DEPLOYED

All 12 modified files pass `just test-fast` but need `just switch` to apply:

- `AGENTS.md` — crash docs added
- `flake.lock` — input updates
- `lib/docker.nix` — target fix
- `lib/systemd.nix` — MemoryHigh
- `modules/nixos/services/default.nix` — docker target
- `modules/nixos/services/dns-blocker.nix` — target fix
- `modules/nixos/services/hermes.nix` — target fix
- `modules/nixos/services/homepage.nix` — target fix
- `modules/nixos/services/signoz.nix` — target fix + null safety
- `modules/nixos/services/sops.nix` — GPG fix
- `platforms/nixos/hardware/amd-gpu.nix` — udev fix
- `platforms/nixos/system/boot.nix` — earlyoom fix

### 2. /data BTRFS Snapshots — Migration Ready, NOT EXECUTED

827 GB with zero snapshot protection. Recipe ready (`just snapshot-migrate-data`).

### 3. Gatus Health Checks — Partial Coverage

25+ endpoints monitored. Still missing: Hermes, Monitor365, disk-monitor, nvme-health-monitor, dual-WAN.

---

## C) NOT STARTED 📋

### Critical Infrastructure

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Free root disk space (28 GB unsloth, 4 GB journal) | 30 min | **IMMINENT RISK** — 2.7 GB free on 512 GB |
| 2 | Execute /data BTRFS migration | 30 min | 827 GB unprotected |
| 3 | Add btrbk instance for /data | 10 min | Complete snapshot coverage |
| 4 | Add `just verify-packages` recipe | 15 min | Defense against stale vendor hashes |
| 5 | GitHub Actions CI for Go repos | 1-2 hrs | Catch breakage at source |

### Service Fixes

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | Fix oauth2-proxy (cookie_secret wrong size — 21 bytes, needs 16/24/32) | 30 min | Forward auth down |
| 7 | Fix dnsblockd CA cert import (exit 127 — missing tool) | 15 min | HTTPS block page |
| 8 | Fix photomap podman permissions | 1 hr | Disabled service |
| 9 | Fix file-and-image-renamer (Go 1.26.3 blocked) | 30 min | Disabled service |
| 10 | Investigate Jan AI llama-server respawn loop | 30 min | Spawns ~1.2 GB process every 1-3 min |

### Housekeeping

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | Archive `docs/status/` — 120 files | 10 min | Clutter |
| 12 | Clean 3 stale Timeshift doc refs | 5 min | Stale docs |
| 13 | Automate vendor hash updates | 15 min | DX improvement |
| 14 | Commit upstream repo dirty states | 10 min | Repo hygiene |
| 15 | D2 architecture diagram | 20 min | Visualization |

---

## D) TOTALLY FUCKED UP 💥

### 1. OOM Cascade — CRASHED THE ENTIRE MACHINE

**Impact:** Hard crash requiring reboot. journald corrupted. PostgreSQL dirty recovery. Docker containers uncleanly stopped. Two boots crashed in 2 hours.

**Cause chain:**
1. Helium browser (Electron) spawns dozens of renderer processes
2. earlyoom `--prefer` regex didn't include `helium` or `electron`
3. earlyoom killed `node`, `python3`, `python` first (they're in prefer list)
4. Memory pressure escalated — journald itself OOM'd and crashed
5. Without journald, systemd event loop degraded
6. niri detected DRM zombie, tried restart → no recovery possible
7. System died at 01:39:45

**Fix applied:** `helium` and `electron` added to `--prefer`. `MemoryHigh` added to `harden {}`.

### 2. Root Disk 100% Full — 2.7 GB Free

**This is the NEXT crash vector.** When root fills completely:
- Nix builds fail (no temp space)
- `nix-daemon` crashes (already happened in boot -1: `SIGABRT`)
- Journal can't write → same cascade as OOM crash
- earlyoom can't create notification processes

**Top consumers:**

| Path | Size | Actionable |
|------|------|-----------|
| `/var/lib/unsloth` | 28 GB | **DELETE** — unused AI training data |
| `/nix/store` | 101 GB | `nix-collect-garbage` after deploy |
| `/var/log/journal` | 4 GB | Already limited to 4 GB max (config correct) |
| `/var/lib/systemd` | 814 MB | Normal |
| `/home/lars/projects` | 161 GB | On root partition — major consumer |

### 3. Jan AI llama-server Memory Leak/Respawn Loop

Jan AI (`v0.7.5`) spawns a new `llama-server` process every 1-3 minutes, each consuming ~1.2 GB. In the current boot alone, **10 separate llama-server processes** have been started. This is NOT a systemd service — it's a user-level process with no cgroup limits. If left unchecked, this alone could trigger OOM.

### 4. oauth2-proxy — STILL BROKEN (Pre-existing)

`cookie_secret from file must be 16, 24, or 32 bytes to create an AES cipher, but is 21 bytes` — the sops secret is a placeholder that's the wrong size. Forward auth is down for ALL protected services.

### 5. swap Under Pressure — 8.3 GB of 16 GB Used

Currently 8.3 GB swap used with only 8 GB free RAM. System is running hot. Load average: 6.09, 13.60, 30.36 (declining from earlier peaks but still high).

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Immediate Survival

1. **Free root disk NOW** — Delete `/var/lib/unsloth` (28 GB), vacuum journal, `nix-collect-garbage`. This prevents the next crash.
2. **Deploy pending changes** — `just switch` to get earlyoom fix + MemoryHigh. Currently running WITHOUT the fix.
3. **Fix Jan AI llama-server loop** — Either configure Jan to reuse the server or limit process memory. This is a latent OOM bomb.

### Architecture

4. **Move `/home` off root partition** — 161 GB of projects on a 512 GB root partition alongside 101 GB `/nix/store` is unsustainable. Either expand root or move `/home` to `/data`.
5. **Cgroup limits for user processes** — Helium and Jan have no memory caps. systemd user slices with `MemoryHigh`/`MemoryMax` would prevent user processes from crashing the system.
6. **Unbound DNS watchdog** — DNS failures (`[::1]:53: connection refused`) take down everything: provider API, MCP servers, telemetry. Need a health check or automatic restart.
7. **statix LSP** — Has been failing to initialize for the entire session. Every 30s timeout + retry cycle. Should be disabled or fixed.

### Resilience Patterns

8. **earlyoom `--prefer` should be auto-generated** — Read service MemoryMax values and prefer processes exceeding their limits.
9. **Journal corruption resilience** — journald should be in the `--avoid` list (it is), but it still crashed. Consider `WatchdogSec` for journald or separate journal partition.
10. **Graceful degradation** — When OOM is imminent, auto-close browser tabs, stop AI services, notify user before killing.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical — Prevent Next Crash

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | **Free root disk**: delete `/var/lib/unsloth` (28 GB), `nix-collect-garbage` | 30 min | 2.7 GB free = imminent disk-full crash |
| 2 | **Deploy all pending changes**: `just switch` | 5 min | OOM fix + MemoryHigh not yet active |
| 3 | Fix Jan AI llama-server respawn loop | 30 min | ~1.2 GB per spawn, potential OOM trigger |
| 4 | Fix oauth2-proxy cookie_secret (21 bytes → 32 bytes) | 15 min | Forward auth down for all services |

### High — Close Open Gaps

| # | Task | Effort | Why |
|---|------|--------|-----|
| 5 | Execute /data BTRFS migration | 30 min | 827 GB with zero snapshots |
| 6 | Add btrbk instance for /data | 10 min | Complete snapshot coverage |
| 7 | Add `just verify-packages` recipe | 15 min | #1 defense against vendor hash cascade |
| 8 | Fix dnsblockd CA cert import (exit 127) | 15 min | HTTPS block page broken |
| 9 | GitHub Actions CI for Go repos | 1-2 hrs | Catch stale hashes at source |
| 10 | Automate vendor hash updates | 15 min | Reduce 5-min manual cycle |

### Medium — Upstream & Polish

| # | Task | Effort | Why |
|---|------|--------|-----|
| 11 | Clean `docs/status/` — archive old reports | 10 min | 120 files is noise |
| 12 | Fix 3 stale Timeshift doc references | 5 min | Stale information |
| 13 | Add user-level cgroup memory limits (helium, jan) | 30 min | Prevent user OOM |
| 14 | Unbound DNS health check / auto-restart | 15 min | DNS failures cascade to everything |
| 15 | Disable or fix statix LSP | 5 min | Constant 30s timeout cycles |
| 16 | Complete Gatus coverage (Hermes, Monitor365, disk/nvme) | 15 min | Observability gaps |
| 17 | Commit library-policy test refactoring | 5 min | 18 dirty files |
| 18 | Fix photomap podman permissions | 1 hr | Disabled service |
| 19 | Fix file-and-image-renamer Go 1.26.3 issue | 30 min | Disabled service |
| 20 | Update go-filewatcher flake.lock | 2 min | nixpkgs drift |

### Lower — Future-proofing

| # | Task | Effort | Why |
|---|------|--------|-----|
| 21 | Move `/home` to `/data` partition | 1 hr | Root disk pressure (161 GB projects) |
| 22 | D2 architecture diagram of Go dependency graph | 20 min | Visualize cascade chain |
| 23 | Port-centric test (all `ports.*` unique) | 15 min | Prevent port conflicts |
| 24 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 25 | Reduce flake inputs from 48 | 1-2 hrs | Simplify maintenance |

---

## G) TOP QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**#1: What is `/var/lib/unsloth` (28 GB) and is it safe to delete?**

This directory consumes **more space than the entire `/nix/store` delta** and is the single biggest contributor to root disk exhaustion. But I cannot determine:

- Is it actively used by any running service? (No systemd unit references it)
- Is it a training artifact from a one-off ML experiment?
- Does anything in `/home/lars/projects/` depend on it at runtime?
- The `unsloth` Python package is a fine-tuning/ML library — was this from an AI-Speed-Test or anime-comic-pipeline experiment?

The system has **2.7 GB free** and this directory holds **28 GB**. Deleting it would give us breathing room, but I need confirmation it's not production data.

---

## System Health Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| RAM | 46 GB / 62 GB (74%) | ⚠️ High |
| Swap | 8.3 GB / 16 GB (52%) | ⚠️ Under pressure |
| Root disk | 504 GB / 512 GB (100%) | 🔴 **CRITICAL** |
| /data disk | 854 GB / 1.0 TB (84%) | ⚠️ Watch |
| Load avg | 6.09 / 13.60 / 30.36 | ⚠️ Declining |
| Uptime | 47 min | ✅ Recovered |
| Docker containers | 11 running | ✅ All healthy |
| BTRFS snapshots (root) | Daily via btrbk | ✅ Active |
| BTRFS snapshots (/data) | None | ❌ Unprotected |
| earlyoom prefer fix | Code ready, NOT deployed | ⚠️ |
| MemoryHigh throttling | Code ready, NOT deployed | ⚠️ |
| oauth2-proxy | Down (cookie_secret wrong size) | ❌ |
| dnsblockd cert import | Exit 127 | ❌ |
| Jan AI version | 0.7.5 (current) | ✅ Up to date |
| Helium browser | 0.12.4.1 | ✅ Running |
| Jan llama-server | Spawning every 1-3 min | ⚠️ Memory concern |

---

## Configuration Summary

| Aspect | Value |
|--------|-------|
| Flake inputs | 48 |
| Go package overlays | 21 |
| Service modules | 30 |
| Pre-commit hooks | 9 |
| Scripts | 23 |
| Status reports | 121 total (120 root + archive) |
| Disabled services | photomap, file-and-image-renamer, minecraft |
| Failed services | oauth2-proxy, dnsblockd-cert-import |
| Code TODOs | 1 (rpi3 sops-nix) |
| Uncommitted changes | 12 files (this session + session 87-88) |
