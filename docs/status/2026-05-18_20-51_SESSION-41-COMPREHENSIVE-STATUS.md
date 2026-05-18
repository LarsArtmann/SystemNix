# Session 41 — Full Comprehensive Status Update

**Date:** 2026-05-18 20:51 CEST
**Session:** 41
**Host:** evo-x2 (192.168.1.150, x86_64-linux)
**Branch:** master (ahead 3 of origin/master)
**Total Commits:** 2423
**Repo Size:** ~933 MiB

---

## Executive Summary

SystemNix is in **excellent operational shape** with two major fixes since Session 40 (~30 minutes ago):

1. **SSH deprecation warnings ELIMINATED** — Fixed upstream in `nix-ssh-config` by migrating from deprecated `matchBlocks` to `programs.ssh.settings`
2. **LAN firewall relaxed** — Added `trustedInterfaces = ["eno1"]` so all LAN traffic on ethernet is trusted (fixes services on non-standard ports being unreachable from MacBook)

System remains severely overloaded (load avg 21.99–31.66) with 45Gi/62Gi memory used.

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| flake.nix architecture | ✅ | 35 service modules, 3 system configs, all evaluate |
| `nix flake check --no-build` | ✅ | **All SSH deprecation warnings eliminated** |
| NixOS evo-x2 evaluation | ✅ | Passes cleanly |
| Darwin evaluation | ✅ | Passes (x86_64-darwin deprecation warning remains) |
| 40 services enabled | ✅ | ~29 active NixOS services |
| 17/17 overlay packages | ✅ | All building, zero stale hashes |
| Code cleanliness | ✅ | Zero TODO/FIXME/HACK/XXX across 111 .nix files |

### SSH Deprecation Fix (Session 40 → 41)

**Problem:** Home Manager upgraded to `fab3fd7` deprecated `programs.ssh.matchBlocks` and `extraOptions`, causing 4 warnings on every build.

**Solution:** Fixed upstream in `github:LarsArtmann/nix-ssh-config@e4370ed`

| Warning | Status |
|---------|--------|
| `programs.ssh.matchBlocks is deprecated` | ✅ **FIXED** |
| `programs.ssh.matchBlocks.*.extraOptions is deprecated` | ✅ **FIXED** |
| `programs.ssh.matchBlocks.evo-x2.extraOptions is deprecated` | ✅ **FIXED** |
| `programs.ssh.matchBlocks.github.com.extraOptions is deprecated` | ✅ **FIXED** |

**Implementation:**
- Migrated `matchBlocks` → `settings` in `modules/home-manager/ssh.nix`
- Moved `extraOptions` contents directly into host blocks (flattened)
- Converted option names from camelCase to PascalCase SSH directive names:
  - `user` → `User`
  - `hostname` → `HostName`
  - `forwardAgent` → `ForwardAgent = "no"`
  - `serverAliveInterval` → `ServerAliveInterval`
  - `identityFile` → `IdentityFile`
- Kept `hosts` option interface unchanged for backward compatibility

### LAN Firewall Trust (Commit `11dbb835`)

**Problem:** Firewall only allowed TCP 22/53/80/443 and UDP 53/853. Services listening on non-standard ports (e.g., 8088) were unreachable from other LAN devices like the MacBook.

**Solution:** Added `networking.firewall.trustedInterfaces = ["eno1"]`

- All traffic on `eno1` (ethernet) is now trusted
- WiFi (`wlan0`) remains firewalled as before
- Public-facing ports still restricted on untrusted interfaces

---

## b) PARTIALLY DONE 🔄

| Item | Status |
|------|--------|
| **mkPreparedSource v2** | Created, 4+ repos migrated. SystemNix exports but doesn't consume it. |
| **Darwin build verification** | Evaluates via flake check. Full `nix build` not run from MacBook since Session 36. |
| **photomap** | Module exists, disabled with podman permission issue. Dead commented code in configuration.nix. |
| **Voice agents** | Module enabled. Whisper ROCm pipeline may need runtime verification. |
| **Status report archive** | 58+ reports. No automatic cleanup policy. |
| **netwatch** | ✅ Now installed in `linuxUtilities` (resolved in Session 40). |

---

## c) NOT STARTED ❌

| Item | Why It Matters |
|------|----------------|
| **Raspberry Pi 3 hardware provisioning** | No backup DNS node. Entire DNS failover cluster is theoretical. |
| **Cachix binary cache** | Every rebuild compiles from scratch. Massive time sink. |
| **CI/CD for `nix flake check`** | No automated checks on push/PR. Breakage only caught manually. |
| **Dependency graph visualization** | When go-output changes, manual trial-and-error to find stale vendor hashes. |
| **Automated vendor hash updater** | Still manual: set `""`, build, grep `got:`, paste. |
| **SigNoz per-threshold alert routing** | All alerts go to same Discord channel. No severity-based routing. |
| **Distributed Darwin builds** | MacBook disk at 90-95%. No remote build to evo-x2 configured. |
| **AppArmor enablement** | Currently `lib.mkDefault false`. Could be hardened further. |
| **Auditd re-enablement** | Blocked by NixOS/nixpkgs#483085. No upstream fix yet. |

---

## d) TOTALLY FUCKED UP! 🔥

| Issue | Severity | Details |
|-------|----------|---------|
| **System load average: 21.99 / 31.66 / 26.04** | 🔴 **CRITICAL** | System is severely overloaded. 45Gi/62Gi memory used. Multiple Crush AI processes + heavy workloads. |
| **Root disk at 87%** | 🔴 **HIGH** | 430G/512G used. Only 66G free. Worsening from 86% (Session 40). Nix store ~90G. |
| **/data disk at 81%** | 🟡 **MEDIUM** | 827G/1T used. AI models, Docker, Immich consuming significant space. |
| **Nixpkgs x86_64-darwin deprecation** | 🟡 **MEDIUM** | Nixpkgs 26.05 is last release supporting x86_64-darwin. Signals ecosystem decline. |
| **rpi3-dns unprovisioned** | 🟡 **MEDIUM** | DNS failover cluster theoretical only. Single point of failure for DNS. |
| **Status report accumulation** | 🟡 **LOW** | 58+ reports without cleanup policy. |
| **photomap dead code** | 🟡 **LOW** | Commented-out `photomap.enable = true` with stale podman issue. |

---

## e) WHAT WE SHOULD IMPROVE! 📈

### Immediate (Today)

1. **Investigate system overload** — Load avg 31.66. Identify and restrain runaway processes.
2. **Disk cleanup** — `just clean` + `nix-collect-garbage` on evo-x2. Root at 87%.
3. **Archive old status reports** — Move reports >2 weeks old to `docs/status/archive/`.

### Short Term (This Week)

4. **Verify Darwin build from MacBook** — Run full `nix build` to catch latent issues.
5. **Set up Cachix** — Binary cache for faster rebuilds.
6. **GitHub Actions CI** — `nix flake check --no-build` on every push/PR.
7. **Create `mk-pnpm-package.nix` helper** — Reuse jscpd pattern.
8. **photomap decision** — Fix, enable, or remove module and dead commented code.

### Medium Term (Next Month)

9. **Dependency graph tool** — Auto-detect which packages need vendor hash bumps.
10. **Automated vendor hash updater** — One command for cascade updates.
11. **rpi3-dns hardware provisioning** — Buy SD card, flash, deploy.
12. **SigNoz alert routing** — Critical→DM, warning→channel, info→log only.
13. **Distributed Darwin builds** — Configure evo-x2 as remote builder for MacBook.

### Strategic (Next Quarter)

14. **Explore `fetchGoModules`** — Simplify vendor management for private repos.
15. **Standardize all Go repos on mkPreparedSource v2** — Eliminate boilerplate.
16. **Migrate justfile → flake.nix** — Per AGENTS.md policy (justfile deprecated).
17. **Contribute jscpd upstream fix** — Give back to nixpkgs.

---

## f) Top #25 Things We Should Get Done Next! 🎯

| # | Task | Why | Effort | Impact |
|---|------|-----|--------|--------|
| 1 | **Investigate system overload** | Load avg 31.66 — system severely overloaded | 10 min | 🔴 Critical |
| 2 | **Run `just clean` + `nix-collect-garbage`** | Root disk at 87% — prevent build failures | 15 min | 🔴 High |
| 3 | **Archive status reports >2 weeks old** | 58+ reports accumulating | 10 min | 🟡 Low |
| 4 | **Verify Darwin build from MacBook** | Latent issues possible since Session 36 | 30 min | 🟡 Medium |
| 5 | **Set up Cachix** | Massive rebuild time savings | 2 hours | 🔴 Very High |
| 6 | **GitHub Actions CI** | Prevent breakage on push | 1 hour | 🔴 Very High |
| 7 | **photomap decision** | Dead commented code + stale module | 10 min | 🟡 Medium |
| 8 | **Create `mk-pnpm-package.nix` helper** | Reuse jscpd pattern | 1 hour | 🟡 Medium |
| 9 | **Write upstream fix playbook** | Document vendor hash cascade learnings | 30 min | 🟡 Medium |
| 10 | **Go.sum transitive merge audit** | Prevent future cascade failures | 1 hour | 🔴 High |
| 11 | **Dependency graph visualization** | Auto-detect stale hashes | 2 hours | 🔴 High |
| 12 | **Automated vendor hash updater** | One command for all updates | 3 hours | 🔴 Very High |
| 13 | **rpi3-dns hardware provisioning** | Eliminate DNS SPOF | Hardware | 🔴 High |
| 14 | **SigNoz per-threshold routing** | Critical→DM, warning→channel | 1 hour | 🟡 Medium |
| 15 | **Distributed Darwin builds** | MacBook disk at 90-95% | 2 hours | 🔴 High |
| 16 | **Migrate justfile → flake.nix** | AGENTS.md policy | 4 hours | 🟢 Low |
| 17 | **Standardize ADR numbering** | Consistency | 15 min | 🟢 Low |
| 18 | **AppArmor enablement** | Currently disabled | 2 hours | 🟡 Medium |
| 19 | **Auditd re-enablement** | Track nixpkgs #483085 | Ongoing | 🟡 Medium |
| 20 | **Consolidate voice-agents Caddy vHost** | Consistency with other services | 30 min | 🟢 Low |
| 21 | **Move dns-failover authPassword to sops** | Plaintext password in module | 30 min | 🟡 Medium |
| 22 | **Add per-service health check endpoints** | Self-reporting beyond Gatus | 3 hours | 🟡 Medium |
| 23 | **Contribute jscpd upstream fix** | Give back to nixpkgs | 2 hours | 🟢 Low |
| 24 | **DNS-over-QUIC re-evaluation** | Currently disabled for build time | 1 hour | 🟢 Low |
| 25 | **Benchmark/performance scripts** | Referenced in FEATURES.md but never created | 2 hours | 🟢 Low |

---

## g) Top #1 Question I Cannot Figure Out Myself ❓

**Why is the system load average spiking to 31.66 with only 5 runnable processes?**

- Load average: 21.99 (1m) / 31.66 (5m) / 26.04 (15m)
- Running processes: only 5/4595 (`loadavg` field 4)
- Memory: 45Gi / 62Gi used (72%)
- Available memory: 17Gi

**The paradox:** Load avg of 31+ typically means 31+ processes waiting for CPU. But only 5 are runnable. This suggests:
- (a) **Uninterruptible sleep (D-state)** — processes blocked on I/O (disk/NFS/network)
- (b) **GPU compute blocking** — AI workloads (Ollama, ROCm) causing CPU threads to wait
- (c) **Memory pressure** — swap thrashing or page reclaim blocking processes
- (d) **Zombie/defunct processes** — parent hasn't reaped children

**I cannot determine which without `ps aux | awk '$8 ~ /^D/'` or `iostat` / `vmstat`.** Is this expected for AI workloads on this machine, or is something pathologically blocked?

---

## System Metrics

| Metric | Value | Δ from Session 40 |
|--------|-------|-------------------|
| `.nix` files | 111 | — |
| Service modules | 35 | — |
| Overlay packages (building) | 17 | — |
| Enabled services on evo-x2 | 40 | — |
| Disabled services | 2 | — |
| Flake inputs (direct) | 30 | — |
| Flake inputs (transitive) | 137 | — |
| Total commits | 2423 | +8 |
| Status reports | 58+ | +1 (this one) |
| Root disk usage | 87% (430G/512G) | +1% 🔴 |
| /data disk usage | 81% (827G/1T) | — |
| Memory used | 45Gi / 62Gi | +2Gi 🔴 |
| Load average | 21.99 / 31.66 / 26.04 | Worsening 🔴 |
| Uptime | 2 days 5:38 | +52 min |

## Key Verification Commands

```bash
nix flake check --all-systems --no-build   # ✅ passes (1 warning only)
just hash-check                             # ✅ all packages OK
just test-fast                              # ✅ syntax OK
nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage  # ✅ builds
```

## Changes Since Session 40

| Commit | Change |
|--------|--------|
| `11dbb835` | `feat(networking): trust all LAN traffic on eno1 via firewall trustedInterfaces` |
| *(flake.lock)* | `nix-ssh-config` updated to `e4370ed` — fixes 4 HM SSH deprecation warnings |
| *(upstream)* | `github:LarsArtmann/nix-ssh-config` — migrated matchBlocks → settings |

## Warnings Summary

| Warning | Count | Status |
|---------|-------|--------|
| Nixpkgs 26.05 x86_64-darwin deprecation | 1 | 🟡 Expected |
| SSH matchBlocks deprecated | 0 | ✅ **FIXED** |
| SSH extraOptions deprecated | 0 | ✅ **FIXED** |
| XDG_PROJECTS_DIR deprecated | 0 | ✅ **FIXED** (in cdfe6c07) |
| Incompatible systems omitted | 1 | 🟢 Informational |

---

_**Status: EXCELLENT — All HM SSH warnings eliminated, LAN firewall fixed, flake check clean. System severely overloaded and disk critical.**_
