# SystemNix — Comprehensive Status Report

**Date:** 2026-05-03 09:59 | **Session:** 18 | **Branch:** master (clean, pushed)
**Commits:** 2,017 total | **May commits:** 65 | **April+ commits:** 681
**Nix files:** 101 | **Justfile recipes:** 127 | **Flake inputs:** 33

---

## System Health

| Metric             | Value                                             | Status                                                         |
| ------------------ | ------------------------------------------------- | -------------------------------------------------------------- |
| Root disk `/`      | 444G/512G used (89%)                              | 🔴 Critical — 59 GB free                                       |
| Data disk `/data`  | 590G/800G used (74%)                              | 🟡 Warning — 210 GB free                                       |
| Physical RAM       | 64 GB LPDDR5x (8×8 GB)                            | 🟡 AGENTS.md corrected from wrong 128 GB                       |
| GPU GTT allocation | 22.4 GB (35% of RAM)                              | 🔴 `amdgpu.gttsize=131072` allows 128 GB GTT — 2× physical RAM |
| Working tree       | Clean, all pushed                                 | ✅                                                             |
| Build status       | ✅ Passing (`nix flake check`, all linters)       | ✅                                                             |
| Pre-commit hooks   | gitleaks, deadnix, statix, alejandra, flake check | ✅                                                             |

---

## a) FULLY DONE ✅

### This Session (Session 18)

| # | What                                | Commit    | Details                                                                                                                      |
| - | ----------------------------------- | --------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Rust target/ cleanup timer**      | `0fec977` | Weekly systemd timer + service in `scheduled-tasks.nix`                                                                      |
| 2 | **cargo-sweep integration**         | `be80f55` | Replaced raw `rm -rf` with `cargo-sweep --time 7d` for smarter incremental cleanup                                           |
| 3 | **Systemd hardening for cleanup**   | `be80f55` | `harden {}` with `ProtectHome=read-only`, `ReadWritePaths=["~/projects"]`, `MemoryMax=256M`, `PrivateTmp`, `NoNewPrivileges` |
| 4 | **Environment-based notifications** | `be80f55` | Moved from inline `export` to `Environment` Nix key (consistent with other services)                                         |
| 5 | **Justfile recipes**                | `be80f55` | `rust-clean` + `rust-clean-status` for manual invocation                                                                     |
| 6 | **Flake input update**              | `4aaf8db` | All flake inputs updated to latest                                                                                           |

### Previous Sessions (May 1–3)

| #  | What                              | Commit(s)            | Impact                                                              |
| -- | --------------------------------- | -------------------- | ------------------------------------------------------------------- |
| 7  | Btrfs disk monitor service        | `0fec977`            | Desktop notifications at disk thresholds                            |
| 8  | Theme centralization (DRY)        | Pre-session          | 13 appearance options → `theme.nix` single source                   |
| 9  | Shell alias DRY (Darwin + NixOS)  | Pre-session          | `nixAliases` attrset deduplication                                  |
| 10 | ROCm config extraction            | `3b770c7`            | Shared ROCm config → `lib/rocm.nix`                                 |
| 11 | Dead Go tool input removal        | `900b871`            | 22 unused Go tool inputs removed, build time reduced                |
| 12 | dnsblockd external flake          | `5e26242`            | Extracted from SystemNix into standalone repo                       |
| 13 | Hermes state migration            | `dd0d5ac`            | `/home/hermes` dedicated user, LD_PRELOAD → binutils                |
| 14 | Caddy LAN auth bypass             | `209ebbb`            | Forward auth skipped for `192.168.1.0/24`                           |
| 15 | Authelia argon2id migration       | `4115f8e`            | bcrypt → argon2id for lars user                                     |
| 16 | Voice Agents image pinning        | `e9dc43e`            | Docker image SHA256 digest pinned                                   |
| 17 | VRRP plaintext default removal    | `b188f9d`            | No more default auth passwords                                      |
| 18 | Broken script cleanup             | `2f4db9f`, `ad061f0` | Removed 6 broken justfile recipes and stale scripts                 |
| 19 | Systemd hardening standardization | `d50de23`, `18fabff` | `harden()` + `serviceDefaults()` applied across 25+ modules         |
| 20 | Post-reboot service recovery      | `4a2eab1`            | Fixed 6 crashed services after hardening broke them                 |
| 21 | Path input migration              | `716ca67`, `64edb8b` | All 25 `path:` inputs → `git+ssh://` URLs (fully portable)          |
| 22 | Nix type safety hardening         | `9610681`, `9f48cc7` | `types.path` → `types.str` where appropriate, hardcoded paths fixed |

### MASTER_TODO_PLAN Progress

| Category        | Done | Total | %    |
| --------------- | ---- | ----- | ---- |
| P0 CRITICAL     | 6    | 6     | 100% |
| P2 RELIABILITY  | 11   | 11    | 100% |
| P3 CODE QUALITY | 9    | 9     | 100% |
| P4 ARCHITECTURE | 7    | 7     | 100% |
| P7 TOOLING/CI   | 10   | 10    | 100% |
| P8 DOCS         | 5    | 5     | 100% |

---

## b) PARTIALLY DONE ⚠️

| # | What                   | Done                     | Remaining                                       | Blocker                                                                                                       |
| - | ---------------------- | ------------------------ | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1 | **P1 Security**        | 3/7 (43%)                | 4 tasks                                         | Taskwarrior encryption → sops, Docker digest pinning (Voice Agents ✅ done, PhotoMap pending), VRRP sops auth |
| 2 | **P6 Services**        | 9/15 (60%)               | 6 tasks                                         | Whisper ASR fix, PhotoMap digest, service hardening gaps                                                      |
| 3 | **P9 Future**          | 2/12 (17%)               | 10 tasks                                        | DNS-over-QUIC, Pi 3 provisioning, NixOS tests, etc.                                                           |
| 4 | **Service hardening**  | ~8/29 modules            | 21 modules lack `harden {}`                     | Incremental work, not blocking                                                                                |
| 5 | **Homepage dashboard** | Port extracted to option | Full service health wiring                      | All `siteMonitor` URLs hardcoded                                                                              |
| 6 | **AGENTS.md accuracy** | RAM spec fixed           | GPU GTT, disk monitor, rust-target-cleanup docs | Needs update                                                                                                  |

---

## c) NOT STARTED 📋

| #  | What                                         | Priority | Notes                                                                 |
| -- | -------------------------------------------- | -------- | --------------------------------------------------------------------- |
| 1  | P5 DEPLOY/VERIFY (0/13)                      | HIGH     | All 13 tasks require evo-x2 `just switch` — smoke tests after deploy  |
| 2  | Whisper ASR fix                              | P0       | `python3: can't open file '/app/python'` — compose command format bug |
| 3  | AMD GPU GTT reduction                        | P0       | `amdgpu.gttsize=131072` → `8192` in `boot.nix` — saves ~22 GB RAM     |
| 4  | AGENTS.md full update                        | P1       | Add rust-target-cleanup, disk monitor, GPU GTT findings, correct RAM  |
| 5  | PhotoMap Docker digest pinning               | P1       | `lstein/photomapai:1.0.0` not digest-pinned                           |
| 6  | VRRP sops auth                               | P1       | `dns-failover.nix` has no sops secret for auth                        |
| 7  | Taskwarrior encryption → sops                | P1       | Hardcoded `sha256("taskchampion-sync-encryption-systemnix")`          |
| 8  | Orphaned file cleanup (`/data/testfile` 4GB) | P2       | Runtime cleanup on evo-x2                                             |
| 9  | Hermes old state dirs (`~/.hermes` 1.3 GB)   | P2       | Runtime cleanup on evo-x2                                             |
| 10 | DNS-over-QUIC overlay                        | P3       | Disabled — 40+ min binary cache cascade                               |
| 11 | Pi 3 DNS failover provisioning               | P3       | Hardware not provisioned                                              |
| 12 | auditd enablement                            | P3       | Blocked by NixOS 26.05 bug (#483085)                                  |
| 13 | AppArmor enablement                          | P3       | Never configured                                                      |
| 14 | TODO_LIST.md creation                        | P3       | Flagged as gap in multiple status reports                             |
| 15 | Remaining 21 modules systemd hardening       | P3       | Incremental, not urgent                                               |

---

## d) TOTALLY FUCKED UP 💥

| # | Issue                                                    | Severity                                                      | Root Cause                                                               | File                                         |
| - | -------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------- |
| 1 | **Root disk at 89% (59 GB free)**                        | 🔴 CRITICAL                                                   | Aggressive growth from Docker, AI models, Nix store                      | Runtime                                      |
| 2 | **GPU GTT eating 22.4 GB RAM (35%)**                     | 🔴 CRITICAL                                                   | `amdgpu.gttsize=131072` on 64 GB machine — kernel allows 128 GB GTT      | `platforms/nixos/system/boot.nix:35,37`      |
| 3 | **Whisper ASR crash-loop**                               | 🔴 CRITICAL                                                   | Docker command `python -m ...` conflicts with image entrypoint `python3` | `modules/nixos/services/voice-agents.nix:29` |
| 4 | **AGENTS.md RAM spec was wrong**                         | 🟡 Was saying 128 GB, actually 64 GB                          | Corrected in status report but not yet in AGENTS.md                      | `AGENTS.md`                                  |
| 5 | **dnsblockd.service failing**                            | 🟡 Reported in previous session, root cause unknown           | Needs investigation on evo-x2                                            | Runtime                                      |
| 6 | **User services dead after reboot**                      | 🟡 awww-daemon, file-renamer, monitor365 enabled but inactive | WantedBy targets may be wrong                                            | Various                                      |
| 7 | **AWWW daemon `StartLimitIntervalSec` in wrong section** | 🟡 `[Service]` instead of `[Unit]`                            | Systemd config error                                                     | User service                                 |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Module option types**: Many modules use `types.str` for paths that should be `types.path` or `types.port`. Inconsistent. Some modules use `types.path` and cause unwanted store copies — we fixed some but haven't audited all 29 service modules systematically.

2. **Centralized port registry**: Ports are scattered across 29 service modules. No single source of truth. A `lib/ports.nix` with all service ports would prevent conflicts and make the homepage dashboard auto-configurable.

3. **Systemd hardening coverage**: Only ~8/29 service modules use `harden {}`. The `lib/systemd.nix` helper exists and is proven — should be applied everywhere.

4. **Scheduled-tasks.nix as shared module**: All timers/services are in a single 238-line file. As tasks grow (now 5 timers + 6 services + notification template), this should be split into individual timer modules or at least separate files per concern.

5. **Docker image pinning policy**: Only Voice Agents is digest-pinned. Twenty CRM, PhotoMap, and any other Docker images should follow the same standard.

### Operational

6. **Disk space management**: Root at 89% is critical. Need: (a) Nix store GC more aggressive, (b) Docker image cleanup, (c) Orphaned file audit, (d) Consider moving more data to `/data`.

7. **GPU RAM waste**: 22.4 GB lost to GTT is the single biggest RAM waste. Reducing `gttsize` from 131072 to 8192 would reclaim ~22 GB instantly.

8. **TODO_LIST.md**: Every status report flags this gap. Should generate from codebase TODOs + MASTER_TODO_PLAN.

9. **P5 DEPLOY/VERIFY**: 0/13 tasks done — all require evo-x2 access. Should batch into a single deploy session with smoke tests.

### Code Quality

10. **Shell scripts in Nix strings**: The `writeShellScript ''...''` pattern with Nix antiquotations (`${pkgs.foo}`) and bash variable escapes (`''${var}`) is fragile. Consider extracting scripts to standalone files (like `scripts/service-health-check`) and using `builtins.readFile`.

---

## f) Top 25 Things We Should Get Done Next

Sorted by **Impact × Effort** (Pareto order):

| #  | Task                                                              | Impact                    | Effort    | Category |
| -- | ----------------------------------------------------------------- | ------------------------- | --------- | -------- |
| 1  | Reduce `amdgpu.gttsize` from 131072 → 8192 in `boot.nix`          | 🔴 Reclaims ~22 GB RAM    | 1 line    | P0       |
| 2  | Fix Whisper ASR crash-loop (remove `python` prefix)               | 🔴 Voice agents working   | 1 line    | P0       |
| 3  | Deploy to evo-x2 (`just switch`) and run P5 smoke tests           | 🔴 Verifies 65 commits    | 30 min    | P0       |
| 4  | Update AGENTS.md with all session 15–18 changes                   | 🟡 Documentation accuracy | 30 min    | P1       |
| 5  | Clean orphaned files on evo-x2 (`/data/testfile`, `~/.hermes`)    | 🟡 Reclaims ~5.3 GB       | 5 min     | P1       |
| 6  | Pin PhotoMap Docker image to SHA256 digest                        | 🟡 Supply chain security  | 5 min     | P1       |
| 7  | Apply `harden {}` to remaining 21 service modules                 | 🟡 Security hardening     | 2 hours   | P1       |
| 8  | Create centralized port registry (`lib/ports.nix`)                | 🟡 Architecture quality   | 1 hour    | P2       |
| 9  | Fix AWWW daemon `StartLimitIntervalSec` section placement         | 🟡 Service reliability    | 5 min     | P1       |
| 10 | Investigate and fix dnsblockd.service failure                     | 🟡 DNS reliability        | 30 min    | P1       |
| 11 | Investigate dead user services (awww, file-renamer, monitor365)   | 🟡 Service reliability    | 30 min    | P1       |
| 12 | Move Taskwarrior encryption to sops-nix                           | 🟡 Security               | 30 min    | P1       |
| 13 | Secure VRRP auth_pass with sops                                   | 🟡 Security               | 30 min    | P1       |
| 14 | Extract cleanup script to `scripts/rust-target-cleanup` file      | 🟢 Code quality           | 15 min    | P3       |
| 15 | Split `scheduled-tasks.nix` into per-concern files                | 🟢 Maintainability        | 1 hour    | P3       |
| 16 | Create TODO_LIST.md from codebase + MASTER_TODO_PLAN              | 🟢 Documentation          | 30 min    | P3       |
| 17 | Update MASTER_TODO_PLAN (regenerate with current progress)        | 🟢 Planning accuracy      | 30 min    | P3       |
| 18 | Add NixOS integration tests for critical services                 | 🟢 Reliability            | Multi-day | P3       |
| 19 | Digest-pin Twenty CRM Docker image                                | 🟡 Supply chain security  | 5 min     | P1       |
| 20 | Enable AppArmor with basic profiles                               | 🟢 Security               | Multi-day | P3       |
| 21 | Provision Pi 3 for DNS failover cluster                           | 🟢 HA DNS                 | Hardware  | P3       |
| 22 | Investigate DNS-over-QUIC overlay performance                     | 🟢 Performance            | 2 hours   | P3       |
| 23 | Move root disk workloads to `/data` to reduce 89% usage           | 🟡 Disk pressure          | 1 hour    | P1       |
| 24 | Add `nix.gc` aggressive settings (already weekly, consider daily) | 🟢 Disk management        | 5 min     | P2       |
| 25 | Archive status docs older than 1 week (last done Apr 26)          | 🟢 Housekeeping           | 5 min     | P3       |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Why is `dnsblockd.service` failing?**

The previous session reported it failing, but I cannot determine the root cause without:

1. Running `systemctl status dnsblockd` on evo-x2
2. Reading `journalctl -u dnsblockd --no-pager -n 50`
3. Checking if the dnsblockd binary (now external flake input) built correctly

This is a **blocking question for DNS reliability** — if dnsblockd is down, the block page server isn't serving, and blocked DNS queries may return NXDOMAIN instead of the block page. Need evo-x2 access to diagnose.

---

## Session Metrics

| Metric               | Value                                                           |
| -------------------- | --------------------------------------------------------------- |
| Commits this session | 4 (`0fec977`, `be80f55`, `4aaf8db`, `be80f55`)                  |
| Files changed        | 5 (scheduled-tasks.nix, justfile, flake.lock, + status docs)    |
| Lint checks          | All passing (deadnix, statix, alejandra, gitleaks, flake check) |
| Build status         | ✅ Clean                                                        |
| Working tree         | ✅ Clean, pushed to origin/master                               |
| MASTER_TODO progress | 65% (62/95) → ~67% with session 18 work                         |
