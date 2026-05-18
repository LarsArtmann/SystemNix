# Session 42 — Full Comprehensive Status Update

**Date:** 2026-05-18 21:14 CEST
**Session:** 42
**Host:** evo-x2 (192.168.1.150, x86_64-linux)
**Branch:** master (ahead 3 of origin/master)
**Total Commits:** 2426
**Repo Size:** ~933 MiB

---

## Executive Summary

SystemNix is in **good operational shape** with two new commits since Session 41 (~23 minutes ago). The most significant development is a comprehensive security audit (`8dd67b6b`) that identified **5 security issues** across service modules — mostly plaintext secrets in `/nix/store` and missing hardening.

**System load reassessment:** The machine has **32 CPU cores**, so load avg of 36.78 is high (~115% utilization) but not the catastrophic overload we assumed. The gitleaks processes from Session 41 have completed; the sustained load is now 10+ Crush AI sessions.

**Disk continues to degrade:** Root at 88% (434G/512G), up from 87% in Session 41.

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| flake.nix architecture | ✅ | 35 service modules, 111 .nix files, all evaluate |
| `nix flake check --no-build` | ✅ | Passes cleanly (1 expected warning only) |
| NixOS evo-x2 evaluation | ✅ | Passes |
| Darwin evaluation | ✅ | Passes |
| 40 services enabled | ✅ | ~29 active NixOS services |
| 17/17 overlay packages | ✅ | All building, zero stale hashes |
| Code cleanliness | ✅ | Zero TODO/FIXME/HACK/XXX across all .nix files |

### Commits Since Session 41 (2 commits)

| Commit | Description | Impact |
|--------|-------------|--------|
| `05cbbbcb` | flake.lock update for `emeet-pixyd` and `file-and-image-renamer` | Latest upstream versions |
| `8dd67b6b` | Comprehensive ecosystem audit with security findings | Documented 5 security issues |

### Comprehensive Security Audit (Commit `8dd67b6b`)

A deep audit of all 111 .nix files, 17 scripts, 33 service modules identified the following security issues:

| # | Issue | Module | Severity | Details |
|---|-------|--------|----------|---------|
| 1 | **monitor365 plaintext secrets** | `monitor365.nix` | 🔴 **HIGH** | `authToken` and `jwtSecret` stored as plaintext Nix options → world-readable in `/nix/store`. Needs sops-nix migration. |
| 2 | **unsloth-studio zero hardening** | `ai-stack.nix` | 🟡 **MEDIUM** | Service has `PrivateTmp=false`, no `MemoryMax`, no `NoNewPrivileges`, no `ProtectSystem`. Runs PyTorch ROCm with full system access. |
| 3 | **Authelia OIDC client_secret as bcrypt hash** | `authelia.nix` | 🟡 **MEDIUM** | `client_secret` stored as bcrypt hash string in Nix config. Not sops-managed. If hash is cracked, all OIDC sessions compromised. |
| 4 | **Gitea admin password in plaintext** | `gitea.nix` | 🟡 **MEDIUM** | Admin password stored as plaintext string. Token generation silently fails on first run. |
| 5 | **Twenty CRM secrets outside sops.nix** | `twenty.nix` | 🟡 **MEDIUM** | Secrets (`ACCESS_TOKEN_SECRET`, `REFRESH_TOKEN_SECRET`) defined in module, not in central `sops.nix`. |

### SSH Deprecation Fix (Still Holding)

| Warning | Status |
|---------|--------|
| All 4 `programs.ssh.matchBlocks` deprecation warnings | ✅ **FIXED** (Session 41) |
| `XDG_PROJECTS_DIR` deprecation | ✅ **FIXED** (Session 40) |

---

## b) PARTIALLY DONE 🔄

| Item | Status |
|------|--------|
| **Security audit** | Findings documented but NOT remediated. 5 issues remain open. |
| **mkPreparedSource v2** | Created, 4+ repos migrated. SystemNix exports but doesn't consume it. |
| **Darwin build verification** | Evaluates via flake check. Full `nix build` not run from MacBook since Session 36. |
| **photomap** | Module exists, disabled with podman permission issue. Dead commented code in configuration.nix. |
| **Voice agents** | Module enabled. Whisper ROCm pipeline may need runtime verification. |
| **Status report archive** | 59+ reports. No automatic cleanup policy. |

---

## c) NOT STARTED ❌

| Item | Why It Matters |
|------|----------------|
| **Security issue remediation** (5 findings) | monitor365 plaintext secrets, unsloth hardening, Authelia hash, Gitea password, Twenty secrets |
| **Raspberry Pi 3 hardware provisioning** | No backup DNS node. Single point of failure. |
| **Cachix binary cache** | Every rebuild compiles from scratch. |
| **CI/CD for `nix flake check`** | No automated checks on push/PR. |
| **Dependency graph visualization** | Manual vendor hash updates when deps change. |
| **Automated vendor hash updater** | Still manual: set `""`, build, grep, paste. |
| **SigNoz per-threshold alert routing** | All alerts to same Discord channel. |
| **Distributed Darwin builds** | MacBook disk at 90-95%. |

---

## d) TOTALLY FUCKED UP! 🔥

| Issue | Severity | Details |
|-------|----------|---------|
| **5 security findings from audit** | 🔴 **HIGH** | Documented but NOT fixed. monitor365 authToken/jwtSecret are plaintext in `/nix/store`. |
| **Root disk at 88%** | 🔴 **HIGH** | 434G/512G used. Only 63G free. Worsening from 86% (Session 39) → 87% (Session 41) → 88% now. |
| **System load avg: 30.04 / 36.78 / 33.25** | 🟡 **MEDIUM** | **32 CPU cores** means ~115% utilization. Not catastrophic but sustained high load. 10+ Crush sessions consuming CPU. |
| **3 zombie processes** | 🟢 **LOW** | Defunct `[git]` processes. Harmless but messy. |
| **/data disk at 81%** | 🟡 **MEDIUM** | 827G/1T used. |
| **Nixpkgs x86_64-darwin deprecation** | 🟡 **MEDIUM** | Nixpkgs 26.05 is last release supporting x86_64-darwin. |
| **rpi3-dns unprovisioned** | 🟡 **MEDIUM** | DNS failover cluster theoretical only. |

### Load Reassessment

| Metric | Previous Assumption | Reality |
|--------|---------------------|---------|
| CPU cores | Assumed 16 | **32 cores** |
| Load avg 36.78 | Thought 230% overload | Actually ~115% utilization |
| Verdict | Catastrophic | **High but manageable** |

The sustained load is from 10+ Crush AI sessions running concurrently, not runaway build processes.

---

## e) WHAT WE SHOULD IMPROVE! 📈

### Immediate (Today)

1. **Fix security findings** — Start with monitor365 plaintext secrets (sops migration)
2. **Disk cleanup** — `just clean` + `nix-collect-garbage`. Root at 88%.
3. **Archive old status reports** — 59+ reports accumulating.

### Short Term (This Week)

4. **Harden unsloth-studio service** — Add `PrivateTmp`, `MemoryMax`, `NoNewPrivileges`
5. **Migrate Authelia/Twenty secrets to sops** — Centralize secret management
6. **Fix Gitea admin password handling** — sops-managed or runtime generation
7. **Verify Darwin build from MacBook** — Run full `nix build`
8. **Set up Cachix** — Binary cache for faster rebuilds
9. **GitHub Actions CI** — `nix flake check --no-build` on every push/PR

### Medium Term (Next Month)

10. **Dependency graph tool** — Auto-detect stale vendor hashes
11. **Automated vendor hash updater** — One command for cascade updates
12. **rpi3-dns hardware provisioning** — Buy SD card, flash, deploy
13. **SigNoz alert routing** — Severity-based channels
14. **Distributed Darwin builds** — evo-x2 as remote builder for MacBook

---

## f) Top #25 Things We Should Get Done Next! 🎯

| # | Task | Why | Effort | Impact |
|---|------|-----|--------|--------|
| 1 | **Fix monitor365 plaintext secrets** | authToken/jwtSecret in /nix/store | 1 hour | 🔴 Critical |
| 2 | **Harden unsloth-studio service** | Zero systemd hardening | 30 min | 🔴 High |
| 3 | **Migrate Authelia OIDC secret to sops** | bcrypt hash in plaintext | 30 min | 🔴 High |
| 4 | **Fix Gitea admin password** | Plaintext + token gen fails | 30 min | 🔴 High |
| 5 | **Migrate Twenty secrets to sops** | Secrets outside central module | 30 min | 🟡 Medium |
| 6 | **Run `just clean` + `nix-collect-garbage`** | Root disk at 88% | 15 min | 🔴 High |
| 7 | **Archive status reports >2 weeks old** | 59+ reports accumulating | 10 min | 🟢 Low |
| 8 | **Verify Darwin build from MacBook** | Latent issues since Session 36 | 30 min | 🟡 Medium |
| 9 | **Set up Cachix** | Massive rebuild time savings | 2 hours | 🔴 Very High |
| 10 | **GitHub Actions CI** | Prevent breakage on push | 1 hour | 🔴 Very High |
| 11 | **photomap decision** | Fix, enable, or remove | 10 min | 🟡 Medium |
| 12 | **Create `mk-pnpm-package.nix` helper** | Reuse jscpd pattern | 1 hour | 🟡 Medium |
| 13 | **Write upstream fix playbook** | Document vendor hash cascade | 30 min | 🟡 Medium |
| 14 | **Go.sum transitive merge audit** | Prevent future cascade failures | 1 hour | 🔴 High |
| 15 | **Dependency graph visualization** | Auto-detect stale hashes | 2 hours | 🔴 High |
| 16 | **Automated vendor hash updater** | One command for all updates | 3 hours | 🔴 Very High |
| 17 | **rpi3-dns hardware provisioning** | Eliminate DNS SPOF | Hardware | 🔴 High |
| 18 | **SigNoz per-threshold routing** | Critical→DM, warning→channel | 1 hour | 🟡 Medium |
| 19 | **Distributed Darwin builds** | MacBook disk at 90-95% | 2 hours | 🔴 High |
| 20 | **Migrate justfile → flake.nix** | AGENTS.md policy | 4 hours | 🟢 Low |
| 21 | **AppArmor enablement** | Currently disabled | 2 hours | 🟡 Medium |
| 22 | **Auditd re-enablement** | Track nixpkgs #483085 | Ongoing | 🟡 Medium |
| 23 | **Move dns-failover authPassword to sops** | Plaintext password | 30 min | 🟡 Medium |
| 24 | **Add per-service health check endpoints** | Self-reporting beyond Gatus | 3 hours | 🟡 Medium |
| 25 | **Contribute jscpd upstream fix** | Give back to nixpkgs | 2 hours | 🟢 Low |

---

## g) Top #1 Question I Cannot Figure Out Myself ❓

**Why are the 5 documented security issues from the ecosystem audit not being treated as urgent?**

The audit (`8dd67b6b`) identified critical findings:
- **monitor365**: `authToken` and `jwtSecret` are plaintext Nix options → world-readable in `/nix/store`
- **unsloth-studio**: Zero systemd hardening (`PrivateTmp=false`, no `MemoryMax`, no `NoNewPrivileges`)
- **Authelia**: `client_secret` is a bcrypt hash string in Nix config (not sops-managed)
- **Gitea**: Admin password in plaintext file, token generation silently fails
- **Twenty CRM**: Secrets defined outside central `sops.nix` module

**I cannot determine:**
- (a) Are these accepted risks? ("Secrets in `/nix/store` are standard practice for non-root users")
- (b) Are they planned fixes with lower priority than other work?
- (c) Is the threat model different than I assume? (e.g., `/nix/store` is only readable by root + users in `nixbld` group)
- (d) Should I fix them right now, or do they need design discussion first?

**The monitor365 issue seems most urgent** — an `authToken` in `/nix/store` means any user with Nix store access can read it. But `nix-ssh-config` and other modules store SSH keys in the store too, so this may be accepted practice.

---

## System Metrics

| Metric | Value | Δ from Session 41 |
|--------|-------|-------------------|
| `.nix` files | 111 | — |
| Service modules | 35 | — |
| Overlay packages (building) | 17 | — |
| Enabled services on evo-x2 | 40 | — |
| Disabled services | 2 | — |
| Flake inputs (direct) | 30 | — |
| Flake inputs (transitive) | 137 | — |
| Total commits | 2426 | +3 |
| Status reports | 59+ | +2 (this + ecosystem audit) |
| Root disk usage | 88% (434G/512G) | +1% 🔴 |
| /data disk usage | 81% (827G/1T) | — |
| Memory used | 41Gi / 62Gi | −4Gi |
| Memory available | 21Gi | +4Gi |
| Load average | 30.04 / 36.78 / 33.25 | Worsening 🔴 |
| CPU cores | 32 | **NEW INFO** |
| D-state processes | 0 | −1 ✅ |
| Zombie processes | 3 | — |
| Uptime | 2 days 5:58 | +1h 7min |

## Key Verification Commands

```bash
nix flake check --all-systems --no-build   # ✅ passes (1 warning only)
just hash-check                             # ✅ all packages OK
just test-fast                              # ✅ syntax OK
```

## Changes Since Session 41

| Commit | Change |
|--------|--------|
| `05cbbbcb` | flake.lock update for `emeet-pixyd` and `file-and-image-renamer` |
| `8dd67b6b` | Comprehensive ecosystem audit — 5 security findings documented |

## Warnings Summary

| Warning | Count | Status |
|---------|-------|--------|
| Nixpkgs 26.05 x86_64-darwin deprecation | 1 | 🟡 Expected |
| SSH matchBlocks deprecated | 0 | ✅ FIXED |
| SSH extraOptions deprecated | 0 | ✅ FIXED |
| XDG_PROJECTS_DIR deprecated | 0 | ✅ FIXED |
| Incompatible systems omitted | 1 | 🟢 Informational |

## Security Findings Summary

| Finding | Module | Severity | Status |
|---------|--------|----------|--------|
| monitor365 plaintext authToken/jwtSecret | `monitor365.nix` | 🔴 HIGH | **OPEN** |
| unsloth-studio zero hardening | `ai-stack.nix` | 🟡 MEDIUM | **OPEN** |
| Authelia OIDC client_secret as bcrypt hash | `authelia.nix` | 🟡 MEDIUM | **OPEN** |
| Gitea admin password in plaintext | `gitea.nix` | 🟡 MEDIUM | **OPEN** |
| Twenty CRM secrets outside sops.nix | `twenty.nix` | 🟡 MEDIUM | **OPEN** |

---

_**Status: GOOD — Flake check clean, SSH warnings fixed. 5 security findings documented but unremediated. Disk critical (88%). Load high but manageable on 32 cores.**_
