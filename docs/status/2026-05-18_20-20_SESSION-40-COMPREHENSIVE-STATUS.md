# Session 40 — Full Comprehensive Status Update

**Date:** 2026-05-18 20:20 CEST
**Session:** 40
**Host:** evo-x2 (192.168.1.150, x86_64-linux)
**Branch:** master (ahead 2 of origin/master)
**Total Commits:** 2420
**Repo Size:** ~933 MiB

---

## Executive Summary

SystemNix is in **good operational shape** with active development since Session 39 (~20 minutes ago). Four commits were made: flake.lock update (15 inputs), `XDG_PROJECTS_DIR` → `PROJECTS` rename, `lib.sh` inlining in scripts, and service dependency fixes for unbound/sops-nix. `nix flake check --no-build` passes.

**New issue discovered:** Home Manager `programs.ssh.matchBlocks` and `.extraOptions` are now deprecated in the upgraded home-manager input. Migration to `programs.ssh.settings` required.

**System under extreme load:** Load average 26.41 with 8+ Crush AI processes running simultaneously.

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| flake.nix architecture | ✅ | flake-parts modular, 35 service modules, 3 system configs |
| NixOS evo-x2 evaluation | ✅ | `nix flake check --no-build` passes cleanly |
| NixOS rpi3-dns build | ✅ | SD image evaluates and builds |
| Darwin evaluation | ✅ | `nix flake check --all-systems --no-build` passes |
| Cross-platform Home Manager | ✅ | 15 shared program modules |
| `just test-fast` | ✅ | Syntax-only validation passes |
| Code cleanliness | ✅ | Zero TODO/FIXME/HACK/XXX across all 111 .nix files |

### Commits Since Session 39 (4 commits)

| Commit | Description | Impact |
|--------|-------------|--------|
| `cdfe6c07` | flake.lock update — 15 inputs upgraded (home-manager, nix-darwin, nUR, +11 private repos) | Latest upstream versions |
| `cdfe6c07` | `XDG_PROJECTS_DIR` → `PROJECTS` rename | Fixes HM deprecation warning |
| `cdfe6c07` | Inline `lib.sh` state persistence into `display-watchdog.sh` and `niri-drm-healthcheck.sh` | Reduces external dependency |
| `5aefb100` | Install `netwatch` in `linuxUtilities` | Resolves Session 38/39 open question |
| `974b5075` | Add `unbound.service` and `sops-nix.service` dependencies to Docker services and Hermes | Fixes startup ordering race conditions |
| `5f6e346a` | Session 39 status report | Documentation |

### Service Dependency Fixes (Commit `974b5075`)

**Problem solved:** Docker-based services and Hermes were starting before local DNS resolver (unbound) and secrets decryption (sops-nix) were ready, causing DNS resolution failures and missing secrets at initialization.

**Changes:**
- `lib/docker.nix` (`mkDockerServiceFactory`): Added `unbound.service` to `after[]` and `wants[]` for both main docker-compose service and image-pull oneshot
- `modules/nixos/services/hermes.nix`: Added `sops-nix.service` and `unbound.service` to `after[]` and `wants[]`

### XDG_PROJECTS_DIR Fix (Commit `cdfe6c07`)

- Renamed `XDG_PROJECTS_DIR` → `PROJECTS` in `platforms/common/environment/variables.nix`
- Eliminates Home Manager deprecation warning: `using keys like 'XDG_PROJECTS_DIR' for xdg.userDirs.extraConfig is deprecated in favor of keys like 'PROJECTS'`

### netwatch Installation (Commit `5aefb100`)

- Added to `linuxUtilities` in `platforms/common/packages/base.nix`
- Placed alongside other system diagnostics tools (`nethogs`, `iftop`, `radeontop`)
- Resolves open question from Sessions 38 and 39

---

## b) PARTIALLY DONE 🔄

| Item | What's Done | What's Missing |
|------|-------------|----------------|
| **SSH config migration** | `matchBlocks` + `extraOptions` still used | Home Manager now warns these are deprecated; must migrate to `programs.ssh.settings` |
| **mkPreparedSource v2** | Created, 4+ repos migrated | SystemNix itself doesn't consume it |
| **Darwin build verification** | Evaluates via flake check | Full `nix build` not run from MacBook |
| **photomap** | Module exists | Disabled with podman permission issue; dead commented code |
| **Voice agents** | Module enabled | Whisper ROCm pipeline may need runtime verification |
| **Status report archive** | 57+ reports | No automatic cleanup policy |

---

## c) NOT STARTED ❌

| Item | Why It Matters |
|------|----------------|
| **SSH config migration to `programs.ssh.settings`** | Home-manager now emits 4 deprecation warnings on every build |
| **Raspberry Pi 3 hardware provisioning** | No backup DNS node |
| **Cachix binary cache** | Rebuilds compile from scratch |
| **CI/CD for `nix flake check`** | No automated checks on push |
| **Dependency graph visualization** | Manual vendor hash updates when deps change |
| **Automated vendor hash updater** | Still manual: set `""`, build, grep, paste |
| **SigNoz per-threshold alert routing** | All alerts to same channel |
| **Distributed Darwin builds** | MacBook disk at 90-95% |
| **AppArmor enablement** | Currently `mkDefault false` |
| **Auditd re-enablement** | Blocked by nixpkgs #483085 |

---

## d) TOTALLY FUCKED UP! 🔥

| Issue | Severity | Details |
|-------|----------|---------|
| **System load average: 26.41** | 🔴 HIGH | 8+ Crush AI processes running simultaneously + ClickHouse consuming 8.3% CPU. System is severely overloaded. Memory at 49Gi/62Gi used. |
| **Home Manager SSH deprecation warnings** | 🟡 MEDIUM | 4 new warnings since home-manager upgrade: `programs.ssh.matchBlocks` and `.extraOptions` deprecated. Must migrate to `programs.ssh.settings.*` using upstream directive names. |
| **Root disk at 86%** | 🟡 MEDIUM | 424G/512G used. Only 73G free. Nix store is ~90G. |
| **/data disk at 81%** | 🟡 MEDIUM | 827G/1T used. AI models, Docker, Immich consuming space. |
| **Nixpkgs x86_64-darwin deprecation** | 🟡 MEDIUM | Nixpkgs 26.05 is last release supporting x86_64-darwin. Signals ecosystem decline. |
| **rpi3-dns unprovisioned** | 🟡 MEDIUM | DNS failover cluster theoretical only. Single point of failure. |
| **Status report accumulation** | 🟡 LOW | 57+ reports without cleanup policy. |

---

## e) WHAT WE SHOULD IMPROVE! 📈

### Immediate (Today)

1. **Migrate SSH config from `matchBlocks` to `programs.ssh.settings`** — Eliminates 4 HM deprecation warnings
2. **Investigate system overload** — 8 Crush processes + load avg 26.41. Consider process limits.
3. **Disk cleanup** — `just clean` + `nix-collect-garbage` on evo-x2

### Short Term (This Week)

4. **Archive old status reports** — Move reports >2 weeks old to `docs/status/archive/`
5. **Verify Darwin build from MacBook** — Run full `nix build`
6. **Set up Cachix** — Binary cache for faster rebuilds
7. **GitHub Actions CI** — `nix flake check --no-build` on push/PR
8. **Create `mk-pnpm-package.nix` helper** — Reuse jscpd pattern

### Medium Term (Next Month)

9. **Dependency graph tool** — "What breaks when go-output updates?"
10. **Automated vendor hash updater** — One command for cascade updates
11. **rpi3-dns hardware provisioning** — Buy SD card, flash, deploy
12. **SigNoz alert routing** — Severity-based channels
13. **Distributed Darwin builds** — evo-x2 as remote builder

### Strategic (Next Quarter)

14. **Explore `fetchGoModules`** — Simplify vendor management
15. **Standardize all Go repos on mkPreparedSource v2** — Eliminate boilerplate
16. **Migrate justfile → flake.nix** — Per AGENTS.md policy
17. **Contribute jscpd upstream fix** — Give back to nixpkgs

---

## f) Top #25 Things We Should Get Done Next! 🎯

| # | Task | Why | Effort | Impact |
|---|------|-----|--------|--------|
| 1 | **Migrate SSH config to `programs.ssh.settings`** | 4 HM deprecation warnings on every build | 15 min | Medium |
| 2 | **Investigate system overload (load 26.41)** | 8 Crush processes consuming CPU | 10 min | High |
| 3 | **Run `just clean` on evo-x2** | Disk at 86% — prevent build failures | 10 min | High |
| 4 | **Disk cleanup /data** | 81% full — AI models consuming space | 15 min | High |
| 5 | **Archive status reports >2 weeks** | 57+ reports accumulating | 10 min | Low |
| 6 | **Verify Darwin build from MacBook** | Latent issues since Session 36 | 30 min | High |
| 7 | **Set up Cachix** | Massive rebuild time savings | 2 hours | Very High |
| 8 | **GitHub Actions CI** | Prevent breakage on push | 1 hour | Very High |
| 9 | **photomap decision** | Fix, enable, or remove | 10 min | Medium |
| 10 | **Create `mk-pnpm-package.nix` helper** | Reuse jscpd pattern | 1 hour | Medium |
| 11 | **Write upstream fix playbook** | Document vendor hash cascade | 30 min | Medium |
| 12 | **Go.sum transitive merge audit** | Prevent cascade failures | 1 hour | High |
| 13 | **Dependency graph visualization** | Auto-detect stale hashes | 2 hours | High |
| 14 | **Automated vendor hash updater** | One command for all updates | 3 hours | Very High |
| 15 | **rpi3-dns hardware provisioning** | Eliminate DNS SPOF | Hardware | High |
| 16 | **SigNoz per-threshold routing** | Critical→DM, warning→channel | 1 hour | Medium |
| 17 | **Distributed Darwin builds** | MacBook disk at 90-95% | 2 hours | High |
| 18 | **Migrate justfile → flake.nix** | AGENTS.md policy | 4 hours | Low |
| 19 | **Standardize ADR numbering** | Consistency | 15 min | Low |
| 20 | **AppArmor enablement** | Currently disabled | 2 hours | Medium |
| 21 | **Auditd re-enablement** | Track nixpkgs #483085 | Ongoing | Medium |
| 22 | **Consolidate voice-agents Caddy vHost** | Consistency | 30 min | Low |
| 23 | **Move dns-failover authPassword to sops** | Plaintext password | 30 min | Medium |
| 24 | **Add per-service health check endpoints** | Self-reporting beyond Gatus | 3 hours | Medium |
| 25 | **Contribute jscpd upstream fix** | Give back to nixpkgs | 2 hours | Low |

---

## g) Top #1 Question I Cannot Figure Out Myself ❓

**Why are 8+ Crush AI processes running simultaneously, causing load average to spike to 26.41?**

- Output shows 8+ `crush -y` processes running concurrently
- One `go test` process at 166% CPU (likely from a Go project build)
- ClickHouse consuming 8.3% CPU (expected for SigNoz)
- Memory at 49Gi/62Gi used — near capacity
- Load average: 26.41 (1-min) / 10.66 (5-min) / 8.26 (15-min)

**I cannot determine if this is:**
- (a) Normal user behavior — intentionally running multiple Crush sessions
- (b) A bug — Crush spawning duplicate processes unexpectedly
- (c) A runaway test/build — the `go test` at 166% CPU may be the culprit
- (d) Expected system load — AI workloads (Ollama, etc.) + normal services

**The system is severely overloaded.** Is this intentional, or should something be killed/restrained?

---

## System Metrics

| Metric | Value | Δ from Session 39 |
|--------|-------|-------------------|
| `.nix` files | 111 | — |
| Service modules | 35 | — |
| Overlay packages (building) | 17 | — |
| Enabled services on evo-x2 | 40 | — |
| Disabled services | 2 | — |
| Flake inputs (direct) | 30 | — |
| Flake inputs (transitive) | 137 | — |
| Total commits | 2420 | +5 |
| Status reports | 57+ | +1 (this one) |
| Root disk usage | 86% (424G/512G) | — |
| /data disk usage | 81% (827G/1T) | — |
| Memory used | 49Gi / 62Gi | +6Gi |
| Load average | 26.41 / 10.66 / 8.26 | +21.17 |
| Uptime | 2 days 4:46 | +31 min |

## Key Verification Commands

```bash
nix flake check --all-systems --no-build   # ✅ passes (warnings only)
just hash-check                             # ✅ all packages OK
just test-fast                              # ✅ syntax OK
nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage  # ✅ builds
```

## Changes This Session

| Commit | Change |
|--------|--------|
| `cdfe6c07` | flake.lock update (15 inputs) + XDG_PROJECTS_DIR→PROJECTS + lib.sh inlining |
| `5aefb100` | netwatch installed in linuxUtilities |
| `974b5075` | unbound/sops-nix service dependencies for Docker services and Hermes |
| `5f6e346a` | Session 39 status report |

---

_**Status: GOOD — System overloaded but functional. New HM SSH deprecation warnings require migration. Disk space critical.**_
