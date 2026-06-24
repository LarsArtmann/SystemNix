# Session 102 — Comprehensive Status Report

**Date:** 2026-05-28 00:30 CEST
**Scope:** Full project audit — architecture review + nixosTests implementation
**Previous session:** 101 (health-check fix, cookie guard, port DX, writeShellApplication migration)

---

## Executive Summary

SystemNix is a **mature, ambitious cross-platform Nix configuration** managing 2 machines (NixOS evo-x2, macOS MacBook Air) plus an RPi3 DNS failover node. It hosts 29 service modules, 13 custom packages, 90+ justfile commands, and extensive monitoring (Gatus, SigNoz, custom disk/NVMe/GPU watchdogs).

**This session** performed a full architecture audit identifying 100 improvement areas across infrastructure safety, architecture, developer experience, operations, documentation, and desktop UX. Then implemented the **#1 highest-impact recommendation: `nixosTests`** — NixOS VM integration tests that boot real QEMU VMs and assert system behavior.

---

## A) FULLY DONE ✅

### Session 102 Deliverables

| Item | Status | Details |
|------|--------|---------|
| **nixosTests framework** | ✅ Done | `tests/default.nix` with `makeTest` wrapper for pure-flake evaluation |
| **Boot test** | ✅ Done & Passing | VM boots, systemd reaches `multi-user.target`, `systemctl is-system-running` reports `running` |
| **DNS blocking test** | ✅ Done & Passing | Unbound starts, blocked domains return NXDOMAIN, `dig` assertions pass |
| **Mock sops-nix module** | ✅ Done | `tests/mock-sops.nix` — drop-in replacement for sops-nix that creates empty secret files |
| **Flake wiring** | ✅ Done | Tests integrated into `perSystem.checks` via `lib.optionalAttrs pkgs.stdenv.isLinux` |
| **100-point audit** | ✅ Done | Comprehensive analysis across 7 categories with prioritized recommendations |
| **Formatting** | ✅ Done | All files pass `nix fmt` |
| **Eval check** | ✅ Done | `nix flake check --no-build` passes |

### Pre-existing (from session 101, unstaged)

| Item | Status | Details |
|------|--------|---------|
| **writeShellApplication migration** | ✅ Done | 15 files migrated from `writeShellScript`/`writeShellScriptBin` to `writeShellApplication` (runtimeInputs, shellcheck, set -euo pipefail) |
| **oauth2-proxy cookie_secret guard** | ✅ Done | Extracted to named `checkCookieSecret` derivation, validates byte length |
| **Port collision detection** | ✅ Done | `ports.nix` genericClosure dedup assertion |
| **Auto-discovery of service modules** | ✅ Done | `getServiceModuleName` parses `flake.nixosModules.<name>` from files |
| **Health check script improvements** | ✅ Done | `scripts/health-check.sh` updated |

### Stable Infrastructure

| Item | Status |
|------|--------|
| Cross-platform flake (Darwin + NixOS) | ✅ Working |
| 29 service modules auto-discovered | ✅ Working |
| 13 custom Go/Node/Python packages | ✅ Building |
| Caddy reverse proxy + Pocket ID auth chain | ✅ Working |
| DNS blocking (unbound + dnsblockd, 2.5M+ domains) | ✅ Working |
| SigNoz observability (ClickHouse + OTel + dashboards) | ✅ Working |
| BTRFS snapshots + verification + scrub | ✅ Working |
| Dual-WAN ECMP + MPTCP | ✅ Working |
| GPU compute (ROCm, Ollama, ComfyUI, Hermes) | ✅ Working |
| AI stack (Ollama, llama.cpp, voice agents, gpu-python) | ✅ Working |
| Gatus health monitoring (25+ endpoints) | ✅ Working |
| CI (statix, deadnix, alejandra, gitleaks, shellcheck) | ✅ Working |
| Pre-commit hooks | ✅ Working |
| sops-nix secrets management | ✅ Working |
| Homebrew + nix-darwin (macOS) | ✅ Working |

---

## B) PARTIALLY DONE 🔧

| Item | What's Done | What's Missing |
|------|------------|----------------|
| **nixosTests** | Framework + 2 tests (boot, DNS blocking) + mock-sops infrastructure | No tests for: caddy auth chain, dnsblockd module, service dependencies, backup/restore, forgejo, signoz, immich |
| **writeShellApplication migration** | 15 files migrated | `scripts/*.sh` (20+ scripts) still use raw shell — not Nix-managed, not shellchecked by the build system |
| **CI pipeline** | `nix-check.yml` (eval + lint), `flake-update.yml` (weekly lockfile PR) | No actual builds in CI, no nixosTests in CI, no Darwin CI, no binary cache |
| **Documentation** | ADRs (7), AGENTS.md, FEATURES.md, CONTRIBUTING.md, 100+ status reports | 250+ stale session reports, no searchable docs, stale CHANGELOG, no per-service runbooks |
| **Monitoring** | Gatus (25+ endpoints), SigNoz (traces/metrics/logs), custom NVMe/GPU/disk watchdogs | No log aggregation (promtail/loki), no SLA tracking, no capacity planning |
| **Security hardening** | systemd `harden` helper, fail2ban, ClamAV, AppArmor prep, gitleaks | No vulnerability scanning of Docker images, no firewall between services, no cert rotation |

---

## C) NOT STARTED ❌

### Top Priority (from 100-point audit)

| # | Item | Impact |
|---|------|--------|
| 1 | Binary cache (attic/cachix) | 30-min deploys → 5-min deploys, enables CI builds |
| 2 | `just diff` — preview changes before switch | #1 DX improvement for any NixOS config |
| 3 | Module assertions (oauth2 requires pocket-id, etc.) | Catch misconfiguration at eval time |
| 4 | Backup restore testing | Untested backups are not backups |
| 5 | `just new-service` scaffolding generator | Eliminates steepest learning curve |
| 6 | `just doctor` unified diagnostic | Single command checks everything |
| 7 | Split signoz.nix (684 lines) and monitor365.nix (715 lines) | Unmaintainable single-file modules |
| 8 | Service dependency graph validation | Caddy → oauth2 → pocket-id → sops chain is implicit |
| 9 | Multi-node nixosTests (DNS failover between 2 VMs) | Complex networking with zero test coverage |
| 10 | Darwin CI | Zero coverage for macOS config |
| 11 | `just status` unified service overview | 29 services with no single health command |
| 12 | `just preflight` pre-switch validation | Check secrets, ports, disk space before 30-min build |
| 13 | Prune docs/ — archive 250+ stale session reports | Finding current info is archaeological work |
| 14 | Vulnerability scanning for Docker images | 5+ container services with no CVE checking |
| 15 | CI that actually builds packages | `perSystem.checks` only has statix/deadnix, no package builds |
| 16 | `just changelog` — diff-based config changelog | Config changes are opaque |
| 17 | Per-service runbooks | 29 services, all tribal knowledge |
| 18 | Capacity planning / trend analysis | No disk/memory/GPU usage tracking over time |
| 19 | Emergency access procedure | If sops keys lost, no break-glass for SSH |
| 20 | Rate limiting on Caddy | All services vulnerable to brute force |
| 21 | Network segmentation between services | Docker containers reach each other freely |
| 22 | `disko` declarative partitioning | hardware-configuration.nix is hand-maintained |
| 23 | Secret rotation strategy | All secrets in one sops file, no rotation schedule |
| 24 | Nix-generated module documentation | Most `mkOption` lack `description` strings |
| 25 | Fleet management (multi-node deploy) | 3 machines managed independently |

---

## D) TOTALLY FUCKED UP 💥

| Item | Severity | Details |
|------|----------|---------|
| **Staged but uncommitted changes from session 101** | ⚠️ Medium | 15 files modified but not staged/committed. `git diff` shows ~2000 lines of writeShellApplication migration sitting in working tree. Risk of loss or conflict. |
| **Untracked files** | ⚠️ Low | `check-services.sh` and `fix-services.sh` are untracked — unclear if they should be committed or are temporary debug scripts. |

No actual breakage found. All services are running, flake evaluates clean, tests pass.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Split mega-modules** — `signoz.nix` (684 lines, 7 concerns) and `monitor365.nix` (715 lines) into `signoz/` and `monitor365/` directories with sub-modules
2. **Co-locate overlays with modules** — `shared.nix` and `linux.nix` are flat lists; each service should bring its own overlay
3. **Add `lib.mkGoOverlay` helper** — eliminates 80% of overlay boilerplate for Go packages
4. **Make `ports.nix` a proper NixOS module** — `mkOption` with `types.port`, not a raw attrset
5. **Add module assertions** — at minimum: "if caddy vhost references port X, service X must be enabled"
6. **Standardize platform-difference pattern** — currently 3 different approaches (`isLinux`, `_module.args = null`, separate overlay lists)

### Developer Experience

7. **`just new-service <name>`** — scaffolding generator
8. **`just diff`** — `nixos-rebuild dry-activate` diff before switch
9. **`just doctor`** — unified diagnostic (disk, DNS, GPU, Docker, sops, ports, BTRFS)
10. **`just status`** — query systemd + gatus for unified service health table
11. **`just preflight`** — pre-switch validation (secrets decrypted, ports free, disk space)
12. **`just changelog`** — diff-based config changelog from last generation
13. **Interactive TUI for service management** — `lazydocker`-style for 29 services

### Infrastructure Safety

14. **Binary cache** — attic or cachix for Nix store sharing
15. **CI builds actual packages** — at minimum `nix build .#dnsblockd`
16. **nixosTests in CI** — boot + DNS tests already pass, add to GitHub Actions
17. **Backup restore automation** — weekly restore-and-verify for Immich, Twenty, TaskChampion
18. **Vulnerability scanning** — `grype` or `trivy` on Docker images in CI

### Documentation

19. **Archive stale docs** — move 250+ session reports to `docs/archive/status/`
20. **Per-service runbooks** — start/stop/debug/backup/restore for each of 29 services
21. **Architecture diagram** — single D2/mermaid showing all services, ports, dependencies
22. **Glossary** — project-specific jargon (`_local_deps`, `BTRFS toplevel`, `PMA`, `VRRP`)

---

## F) TOP 25 THINGS TO DO NEXT (Prioritized by Impact × Effort)

| Rank | Task | Impact | Effort | Type |
|------|------|--------|--------|------|
| 1 | **Commit session 101 changes** (writeShellApplication migration) | High | 5min | Cleanup |
| 2 | **Add `just diff` command** (dry-activate preview) | High | 15min | DX |
| 3 | **Add module assertions** (oauth2→pocket-id, caddy→ports) | High | 30min | Safety |
| 4 | **Wire nixosTests into CI** (GitHub Actions) | High | 15min | CI |
| 5 | **Add `just doctor` command** | High | 1hr | DX |
| 6 | **Set up attic/cachix binary cache** | Very High | 2hr | Infra |
| 7 | **Add CI package builds** (at least dnsblockd) | High | 30min | CI |
| 8 | **Add caddy-auth-chain nixosTest** | High | 1hr | Testing |
| 9 | **Add dnsblockd nixosTest** (with mock-sops) | High | 1hr | Testing |
| 10 | **Add backup-restore nixosTest** | High | 1hr | Testing |
| 11 | **Split signoz.nix into sub-modules** | Medium | 2hr | Architecture |
| 12 | **Split monitor365.nix into sub-modules** | Medium | 2hr | Architecture |
| 13 | **Archive 250+ stale docs** | Medium | 30min | Docs |
| 14 | **Add `just new-service` scaffolding** | Medium | 1hr | DX |
| 15 | **Add `just status` overview command** | Medium | 1hr | DX |
| 16 | **Add Docker image vulnerability scanning** | Medium | 1hr | Security |
| 17 | **Add `just preflight` pre-switch check** | Medium | 1hr | DX |
| 18 | **Write per-service runbooks** (start with top 5) | Medium | 2hr | Docs |
| 19 | **Generate architecture diagram** (D2) | Medium | 1hr | Docs |
| 20 | **Add Darwin eval in CI** | Medium | 30min | CI |
| 21 | **Add `mkGoOverlay` lib helper** | Low | 30min | Architecture |
| 22 | **Migrate remaining scripts/ to writeShellApplication** | Low | 2hr | Code quality |
| 23 | **Add rate limiting to Caddy** | Low | 30min | Security |
| 24 | **Add disko for declarative partitioning** | Low | 3hr | Infra |
| 25 | **Create service dependency graph validator** | Low | 2hr | Safety |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**What are `check-services.sh` and `fix-services.sh`?**

These two files are untracked (`??` in `git status`) but present at the repo root. They were not part of session 101 or 102 changes and are not referenced by any other file in the project. They could be:
- Temporary debug scripts from a previous session that should be committed or deleted
- Work-in-progress from a manual debugging session
- Intentionally excluded via `.gitignore` but still visible

I need clarification: **should these be committed (and to where), or should they be removed?**

---

## File Inventory

### New Files (session 102)
- `tests/default.nix` — nixosTests framework + boot + dns-blocking tests
- `tests/mock-sops.nix` — mock sops-nix for integration tests

### Modified Files (session 102)
- `flake.nix` — added `perSystem.checks` integration for nixosTests

### Modified Files (session 101, unstaged)
- `flake.nix` — auto-discovery, port collision detection
- `modules/nixos/services/dns-blocker.nix` — writeShellApplication migration
- `modules/nixos/services/dual-wan.nix` — writeShellApplication migration
- `modules/nixos/services/forgejo.nix` — writeShellApplication migration
- `modules/nixos/services/forgejo-repos.nix` — writeShellApplication migration
- `modules/nixos/services/hermes.nix` — minor fix
- `modules/nixos/services/monitor365.nix` — writeShellApplication migration
- `modules/nixos/services/niri-config.nix` — writeShellApplication migration
- `modules/nixos/services/nvme-health-monitor.nix` — minor fix
- `modules/nixos/services/oauth2-proxy.nix` — cookie guard extraction
- `modules/nixos/services/signoz.nix` — writeShellApplication migration
- `modules/nixos/services/disk-monitor.nix` — minor fix
- `platforms/common/programs/taskwarrior.nix` — changes
- `platforms/nixos/desktop/niri-wrapped.nix` — writeShellApplication migration
- `platforms/nixos/desktop/waybar.nix` — writeShellApplication migration
- `platforms/nixos/system/scheduled-tasks.nix` — writeShellApplication migration

### Untracked Files
- `check-services.sh` — purpose unknown
- `fix-services.sh` — purpose unknown

---

## Test Results

| Test | Result | Time |
|------|--------|------|
| `nix flake check --no-build` | ✅ Pass | ~30s eval |
| `checks.x86_64-linux.boot` | ✅ Pass | ~60s (first run, cached after) |
| `checks.x86_64-linux.dns-blocking` | ✅ Pass | ~60s (first run, cached after) |
| `checks.x86_64-linux.statix` | ✅ Pass | ~5s |
| `checks.x86_64-linux.deadnix` | ✅ Pass | ~5s |
| `nix fmt` | ✅ Pass | All files formatted |

---

_Arte in Aeternum_
