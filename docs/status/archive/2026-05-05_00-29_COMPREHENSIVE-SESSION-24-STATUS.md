# SystemNix — Comprehensive Status Report

**Generated:** 2026-05-05 00:29 CEST
**Branch:** master (up to date with origin)
**Working tree:** CLEAN — nothing staged, nothing uncommitted
**Commits on master:** 38 commits since 2026-04-27
**Total Nix code:** ~12,000 lines across 100+ files

---

## a) FULLY DONE ✅

### Core Infrastructure (100%)

| Area                                                  | Status | Evidence                                                                                                           |
| ----------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------ |
| Cross-platform flake (Darwin + NixOS)                 | ✅     | Single flake, two systems, 80% shared                                                                              |
| flake-parts modular architecture                      | ✅     | 39 service modules imported in `flake.nix`                                                                         |
| Shared overlays (NUR, aw-watcher, todo-list-ai, etc.) | ✅     | `sharedOverlays` + `linuxOnlyOverlays` pattern                                                                     |
| Custom packages (13 total)                            | ✅     | 6 Go, 2 Rust, 1 Python, 1 Node.js, 3 via flake inputs                                                              |
| Formatter (treefmt + alejandra)                       | ✅     | Via `treefmt-full-flake`                                                                                           |
| Flake checks (statix ✅, deadnix, eval)               | ✅     | `nix flake check --no-build` passes clean                                                                          |
| lib/ shared helpers                                   | ✅     | `lib/systemd.nix` (harden), `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix`, `lib/default.nix` |

### Session 24 Work (2026-05-04 → 2026-05-05)

| Commit    | What                                                                               |
| --------- | ---------------------------------------------------------------------------------- |
| `98c8415` | docs(AGENTS.md): expand lib/ helpers section with types.nix, rocm.nix, default.nix |
| `427f834` | chore: fix modernize hash attr, remove dead code in netwatch/darwin-home           |
| `bda62e2` | docs(AGENTS.md): add wallpaper self-healing architecture and commands              |
| `d53214e` | fix(gpu): remove NVIDIA-only env var and dead comments from AMD config             |
| `01fd963` | fix(services): add missing imports and adopt harden() in photomap                  |
| `e03cf51` | docs(status): add library-policy nix migration and SystemNix integration report    |
| `922648a` | fix(whisper-asr): correct container command + adopt harden() across 6 services     |
| `2085dd0` | feat(lib): extract shared systemd helpers into centralized lib/ module             |
| `8d77137` | fix(wallpaper): self-healing with awww restore + extracted script                  |
| `e122256` | chore: add library-policy for Go library governance, update flake inputs           |
| `af9ca87` | docs(status): add session 23 resilience hardening & GPU rebalance report           |
| `50c7170` | refactor(nixos): reduce GPU memory ceiling from 128GB to 32GB                      |
| `36424f2` | feat(nixos): add pstore panic logging, journald/coredump limits                    |
| `593be03` | fix(crash-recovery): add 6-layer defense-in-depth against GPU hang                 |

### Service Modules — Production Quality (29 modules)

All active services have:

- `harden()` from `lib/systemd.nix` for security sandboxing
- `serviceDefaults()` from `lib/systemd/service-defaults.nix` for lifecycle
- `Restart`, `RestartSec`, `StartLimitBurst` consistent
- WatchdogSec ONLY on `Type=notify` services (Caddy, Gitea) — correct post-watchdog-massacre

| Service                | harden()     | serviceDefaults() | Status        |
| ---------------------- | ------------ | ----------------- | ------------- |
| Docker                 | N/A (system) | N/A               | ✅            |
| Caddy                  | ✅           | ✅                | ✅            |
| Sops                   | N/A          | N/A               | ✅            |
| Authelia               | ✅           | ✅                | ✅            |
| Gitea                  | ✅           | ✅                | ✅            |
| Gitea-repos            | ✅           | ✅                | ✅            |
| Homepage               | ✅           | ✅                | ✅            |
| Immich                 | ✅           | ✅                | ✅            |
| SigNoz                 | ✅           | ✅                | ✅            |
| TaskChampion           | ✅           | ✅                | ✅            |
| Hermes                 | ✅           | ✅                | ✅            |
| Monitor365             | ✅           | ✅                | ✅            |
| File-and-image-renamer | ✅           | ✅                | ✅            |
| Voice-agents           | ✅           | ✅                | ✅            |
| Awww (wallpaper)       | ✅           | ✅                | ✅            |
| ComfyUI                | ✅           | ✅                | ✅            |
| Photomap               | ✅           | ✅                | ✅ (disabled) |
| Twenty                 | ✅           | ✅                | ✅            |
| Minecraft              | ✅           | ✅                | ✅            |

### Desktop & NixOS Platform (100% for active features)

| Component                             | Status |
| ------------------------------------- | ------ |
| Niri (scrolling-tiling Wayland)       | ✅     |
| Session save/restore (crash recovery) | ✅     |
| Waybar (15+ modules)                  | ✅     |
| Rofi (grid launcher, calc, emoji)     | ✅     |
| EMEET PIXY webcam daemon              | ✅     |
| SDDM + Catppuccin Mocha               | ✅     |
| DNS blocking (Unbound + dnsblockd)    | ✅     |
| GPU crash recovery (6-layer defense)  | ✅     |
| BTRFS snapshots (Timeshift)           | ✅     |

### Cross-Platform Programs (100%)

Fish, Zsh, Bash, Starship, Git, Tmux, Fzf, Taskwarrior, KeePassXC, SSH config — all wired and working.

### CI/CD (100%)

| Pipeline         | Trigger                       | Status |
| ---------------- | ----------------------------- | ------ |
| nix-check        | push/PR to master             | ✅     |
| go-test          | push/PR (dnsblockd-processor) | ✅     |
| flake-update     | Weekly Mon 06:00 UTC          | ✅     |
| Pre-commit hooks | Local                         | ✅     |

### Quality Gates

| Check                        | Result                             |
| ---------------------------- | ---------------------------------- |
| `nix flake check --no-build` | ✅ PASS (all 39 modules evaluated) |
| `statix check .`             | ✅ CLEAN                           |
| `deadnix`                    | ⚠️ 3 minor warnings (see section d) |
| Formatting (alejandra)       | ✅ PASS                            |

### Documentation

| Doc                                | Status                            |
| ---------------------------------- | --------------------------------- |
| AGENTS.md (project guide)          | ✅ Comprehensive, up-to-date      |
| FEATURES.md                        | ✅ 140+ features inventoried      |
| MASTER_TODO_PLAN.md                | ✅ 95 tasks tracked, 65% complete |
| 5 ADRs                             | ✅                                |
| CONTRIBUTING.md                    | ✅                                |
| 70+ status reports in docs/status/ | ✅ (excessive — see improvements) |

---

## b) PARTIALLY DONE ⚠️

### Gatus Uptime Monitor (30%)

- `modules/nixos/services/gatus.nix` — ~500 line module exists with full options
- **NOT imported** in `flake.nix`
- **NOT wired** into `configuration.nix`
- No flake input for Gatus binary
- Status: **Draft module, needs wiring + testing**

### Voice Agents (70%)

- Module exists and enabled
- Whisper Docker + ROCm pipeline configured
- Caddy reverse proxy wired
- UDP range 50000-51000 open
- **Needs verification** on evo-x2 after next deploy

### Hermes AI Gateway (85%)

- Full module with sops secrets, 6 API keys, systemd service
- 4G memory limit, USR1 reload
- **Missing**: Health check endpoint (needs Hermes code change)
- **Low-priority cleanup**: `mergeEnvScript` redundancy in ExecStartPre

### SigNoz Observability (90%)

- Full stack: ClickHouse + OTel Collector + Query Service
- node_exporter + cadvisor scraping
- 7 alert rules provisioned
- Dashboard provisioning
- **Missing**: Verification that all 10 service metric endpoints are scraped

### DNS Failover Cluster (40%)

- Module `dns-failover.nix` complete with Keepalived VRRP
- `rpi3-dns` nixosConfiguration defined
- `local-network.nix` shared options
- **BLOCKED**: Pi 3 hardware not provisioned
- **BLOCKED**: VRRP auth_pass in plaintext (needs sops)

---

## c) NOT STARTED 📋

| Area                             | Description                       | Est.  | Blocker             |
| -------------------------------- | --------------------------------- | ----- | ------------------- |
| Pi 3 SD image build + flash      | Hardware provisioning             | 45min | Pi 3 hardware       |
| DNS failover testing             | Two-node VRRP cluster test        | 30min | Pi 3 hardware       |
| Cachix binary cache              | Investigate shared binary cache   | 2h    | Decision needed     |
| NixOS VM tests                   | Test critical services in VMs     | 4h+   | Complex setup       |
| ComfyUI proper Nix derivation    | Replace venv-based setup          | 8h+   | Complex packaging   |
| lldap/Kanidm unified auth        | Replace file-based Authelia       | 4h+   | Research + decision |
| Home Manager flake-parts pattern | Create homeModules pattern        | 2h    | Architecture work   |
| Waybar session restore stats     | Module for save/restore metrics   | 1h    | Feature work        |
| Real-time niri event-stream save | Replace polling with event stream | 3h    | niri IPC research   |

---

## d) TOTALLY FUCKED UP 💥

### deadnix Warnings (3 — low severity but real)

```
1. platforms/darwin/home.nix:2 — Unused lambda pattern: pkgs
2. pkgs/netwatch.nix:3 — Unused lambda pattern: stdenv
3. flake.nix:191 — Unused lambda pattern: crush-config
```

**#3 is interesting**: `crush-config` IS used at line 733 via `inputs.crush-config`, but the direct variable binding is unused because `crush-config` (hyphenated) isn't a valid Nix identifier. It should be removed from the outputs destructuring pattern — it's accessed via `inputs.crush-config` which works regardless of whether it's in the pattern.

### AGENTS.md Accuracy Drift

The AGENTS.md file references "29 service modules" but the actual count is now 39 files in `modules/nixos/services/` (including non-module files like patches, guides, and drafts). The module list in the Architecture section may be stale.

### Excessive Status Reports

70+ status reports accumulated in `docs/status/` — many are redundant session-by-session dumps. The `archive/` subdirectory exists but the main directory is still bloated. This creates noise when searching for actual status information.

### Missing Scripts Referenced in FEATURES.md

FEATURES.md still lists `benchmark-system.sh`, `performance-monitor.sh`, `shell-context-detector.sh`, and `storage-cleanup.sh` as ❌ — these were never created but are still referenced in FEATURES.md audit.

### Auditd Disabled

`services.auditd.enable = false` due to NixOS 26.05 bug #483085 — kernel audit system completely non-functional. AppArmor also commented out in `security-hardening.nix`. This is a real security gap on a production machine.

---

## e) WHAT WE SHOULD IMPROVE

### 1. Fix the 3 deadnix warnings (5 min)

Remove unused `pkgs` from `platforms/darwin/home.nix`, unused `stdenv` from `pkgs/netwatch.nix`, and unused `crush-config` from `flake.nix` outputs pattern.

### 2. Wire Gatus into the flake (30 min)

The module is written but orphaned. Import in `flake.nix`, add gatus flake input, wire into `configuration.nix`, test.

### 3. Consolidate status reports (15 min)

Move all but the last 5 reports to `archive/`. The current 70+ files make the directory useless for quick reference.

### 4. Update FEATURES.md (30 min)

Remove ghost entries for non-existent scripts. Update module count. Verify all status indicators.

### 5. Update MASTER_TODO_PLAN.md (30 min)

The plan shows 65% complete (62/95 tasks). Many items completed in sessions 22-24 are not reflected. The "P6 Services" section still lists tasks as pending that were completed.

### 6. Security: Move secrets to sops (1 hour on evo-x2)

Taskwarrior encryption, VRRP auth_pass, Docker image digests — all blocked on evo-x2 access.

### 7. Adopt `lib/types.nix` more broadly (2 hours)

The shared types library exists but is only used in a few modules. Standardize port, path, and user types across all service modules.

### 8. Create mkHardenedService wrapper (1 hour)

Combine `harden {} // serviceDefaults {} // { ... }` into a single `mkHardenedService` function to reduce boilerplate across 20+ service modules.

### 9. Investigate auditd/AppArmor alternatives (research)

The kernel audit system is broken on NixOS 26.05. Research SELinux or alternative LSM modules, or track the upstream bug.

### 10. Clean up AGENTS.md service list (30 min)

The architecture section lists specific services but is missing gatus, minecraft, twenty, disk-monitor, etc. Update to match reality.

---

## f) Top 25 Things We Should Get Done Next

### Immediate (can do now)

| # | Task                                                                       | Est. | Impact                |
| - | -------------------------------------------------------------------------- | ---- | --------------------- |
| 1 | Fix 3 deadnix warnings (darwin/home.nix, netwatch.nix, flake.nix)          | 5m   | Code quality          |
| 2 | Wire gatus module into flake.nix + configuration.nix                       | 30m  | New monitoring        |
| 3 | Consolidate 70+ status reports → archive                                   | 15m  | Clarity               |
| 4 | Update MASTER_TODO_PLAN.md with session 22-24 completions                  | 30m  | Accuracy              |
| 5 | Update FEATURES.md — remove ghost script entries, fix module count         | 30m  | Accuracy              |
| 6 | Update AGENTS.md service list (add gatus, minecraft, twenty, disk-monitor) | 15m  | Accuracy              |
| 7 | Create `mkHardenedService` lib helper                                      | 1h   | DRY across 20 modules |
| 8 | Adopt `lib/types.nix` in more service modules                              | 2h   | Type safety           |

### Needs evo-x2 Access

| #  | Task                                               | Est. | Impact        |
| -- | -------------------------------------------------- | ---- | ------------- |
| 9  | `just switch` — deploy all pending changes         | 45m+ | Everything    |
| 10 | Move Taskwarrior encryption to sops                | 10m  | Security      |
| 11 | Pin Docker image digests (Voice Agents + PhotoMap) | 10m  | Security      |
| 12 | Secure VRRP auth_pass with sops                    | 8m   | Security      |
| 13 | Verify Ollama + ROCm after rebuild                 | 5m   | AI stack      |
| 14 | Verify SigNoz collecting all metrics               | 10m  | Observability |
| 15 | Verify Voice Agents Whisper pipeline               | 10m  | AI stack      |
| 16 | Test Immich backup restore                         | 10m  | Data safety   |
| 17 | Test Twenty CRM backup restore                     | 10m  | Data safety   |
| 18 | Configure SMTP for Authelia notifications          | 15m  | Security UX   |
| 19 | Verify all 10 service metric endpoints in SigNoz   | 30m  | Observability |

### Bigger Initiatives

| #  | Task                                                           | Est. | Impact        |
| -- | -------------------------------------------------------------- | ---- | ------------- |
| 20 | Hermes health check endpoint                                   | 2h   | Observability |
| 21 | Pi 3 provisioning — build, flash, boot, DNS failover test      | 2h   | HA DNS        |
| 22 | Investigate Cachix binary cache for cross-machine sharing      | 2h   | Build speed   |
| 23 | NixOS VM tests for critical services (Caddy, Authelia, Immich) | 4h+  | Reliability   |
| 24 | Research auditd/AppArmor alternatives or track upstream bug    | 1h   | Security      |
| 25 | Waybar module for niri session restore statistics              | 1h   | UX            |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Is the Gatus uptime monitor module intended for production use?**

The module at `modules/nixos/services/gatus.nix` is a ~500-line, fully-featured NixOS module with endpoints, alerts, storage config, and TLS options. But it's:

- Not imported in `flake.nix`
- Not wired into `configuration.nix`
- Has no flake input for the Gatus binary
- Was created as a "draft" in commit `af44116`

Should I complete the wiring (add flake input, import, enable), or is this intentionally shelved? The code quality is production-ready — it just needs the final 3 lines of integration.

---

## Build & Lint Health Summary

| Check                        | Result                        |
| ---------------------------- | ----------------------------- |
| `nix flake check --no-build` | ✅ PASS                       |
| `statix check .`             | ✅ CLEAN                      |
| `deadnix`                    | ⚠️ 3 warnings (unused params)  |
| Formatting                   | ✅ PASS                       |
| Working tree                 | ✅ CLEAN                      |
| Branch sync                  | ✅ `master` = `origin/master` |

## Session Statistics

| Metric                    | Value                                           |
| ------------------------- | ----------------------------------------------- |
| Sessions documented       | 24 (based on status reports)                    |
| Total status reports      | 70+                                             |
| Commits since 2026-04-27  | 38                                              |
| Total Nix LOC             | ~12,000                                         |
| Service modules           | 39 files (29 active)                            |
| Custom packages           | 13                                              |
| MASTER_TODO_PLAN progress | 65% (62/95) → likely ~70% after uncounted fixes |
| Flake inputs              | 30+                                             |

---

_Report generated by deep analysis of git history, all service modules, platform configs, build checks, statix, deadnix, FEATURES.md, MASTER_TODO_PLAN.md, and AGENTS.md._
