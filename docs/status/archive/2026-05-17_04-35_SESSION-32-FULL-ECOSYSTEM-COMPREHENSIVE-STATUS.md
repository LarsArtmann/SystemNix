# Session 32 — Full Comprehensive Ecosystem Status Report

**Date:** 2026-05-17 04:35 CEST
**Author:** Crush (AI Agent)
**Scope:** Full SystemNix codebase — 2,390 commits, 111 `.nix` files, 22 shell scripts, 35 service modules

---

## Executive Summary

SystemNix is in **strong shape**. The last 72 hours saw a massive sprint: deduplication (28 files, -196 lines), display watchdog self-healing, `mkDockerService` factory extraction, `mkHttpCheck` helper, `mkStateDir` helper, `serviceTypes.servicePort` migration, dead code purge, and 6 rounds of flake.lock updates. The build evaluates clean for both `evo-x2` (NixOS) and `Lars-MacBook-Air` (Darwin). There is **one outstanding build issue**: `voice-agents.nix` and `twenty.nix` still use inline docker-compose patterns that could be migrated to `mkDockerService`. The flake.lock has drifted slightly from HEAD (1 commit ahead of origin).

**Key metric:** 444 commits in May 2026 alone — the project is extremely active.

**Build status:** ✅ `nix build '.#nixosConfigurations.evo-x2.config.system.build.toplevel'` evaluates and dry-runs successfully. 140 systemd services configured.

---

## a) FULLY DONE ✅

### Infrastructure & Architecture
- **Dual-WAN ECMP+MPTCP** — Active-active failover with route health monitoring, MPTCP endpoint management, NM dispatcher events. Fully production.
- **DNS Blocker** — Unbound + dnsblockd with 2.5M+ domains blocked, DoT upstream, `.home.lan` local records. CA trusted system-wide.
- **SigNoz Observability** — Full stack (ClickHouse, OTel Collector, Query Service). 26+ Gatus endpoints. Alert rules for GPU, DNS, Docker, Caddy, disk.
- **Caddy Reverse Proxy** — TLS termination, forward auth, virtual host routing. All ports derived from service config options.
- **SOPS Secrets** — age-encrypted via SSH host key. Templates for env-file injection.
- **BTRFS Layout** — Root (zstd), `/data` (zstd:3 + async discard). Docker on `/data`.
- **GPU Compute Headroom** — Multi-layer defense: `OLLAMA_MAX_LOADED_MODELS=1`, per-service memory fractions, `OOMScoreAdjust` hierarchy, gpu-python wrapper.
- **Niri Compositor Stack** — DRM healthcheck (60s), GPU recovery (unbind/rebind + auto-reboot), display watchdog, niri-session-manager, wallpaper self-healing.
- **AI Model Storage** — Centralized `/data/ai/` with `services.ai-models.paths` attrset. All AI services reference it.
- **EMEET PIXY Webcam** — Full daemon with auto-tracking, call detection, Waybar integration, privacy toggle.

### Shared Library (`lib/`)
- **`lib/default.nix`** — Single import pattern: `harden`, `hardenUser`, `serviceDefaults`, `serviceDefaultsUser`, `onFailure`, `serviceTypes`, `mkDockerServiceFactory`, `mkStateDir`
- **`lib/systemd.nix`** — Security hardening with system/user modes
- **`lib/systemd/service-defaults.nix`** — Common Restart/RestartSec defaults + `onFailure` helper
- **`lib/types.nix`** — Reusable option constructors (`servicePort`, `systemdServiceIdentity`, `restartDelay`, `stopTimeout`)
- **`lib/docker.nix`** — `mkDockerService` factory for declarative Docker service management
- **`lib/graphical-user-service.nix`** — Boilerplate for Wayland-bound user services
- **`lib/rocm.nix`** — ROCm GPU runtime helpers

### Helper Adoption (across 35 service modules)
| Helper | Adopted by |
|--------|-----------|
| `harden {}` | 20 services |
| `serviceDefaults {}` | 19 services |
| `onFailure` | 16 services |
| `serviceTypes.*` | 8 services |
| `mkDockerService` | 2 services (manifest, openseo) |
| `mkStateDir` | NEW — needs adoption |
| `mkHttpCheck` | gatus-config.nix |

### Cross-Platform Home Manager
- **14 program modules** shared via `platforms/common/home-base.nix`
- **70+ packages** in `platforms/common/packages/base.nix`
- Taskwarrior 3 sync across NixOS, macOS, Android (zero-config)

### Custom Packages (6 in `pkgs/`)
- `aw-watcher-utilization`, `govalid`, `jscpd`, `modernize`, `netwatch`, `openaudible`

### Flake Inputs (30+)
- All LarsArtmann repos use `git+ssh://` — fully portable
- `mkPackageOverlay` used for all 12 flake-input overlays
- Overlays split into `shared.nix` (12) + `linux.nix` (6)

### Documentation
- **42 status reports** in `docs/status/`
- **30 planning docs** in `docs/planning/`
- **6 ADRs** in `docs/adr/`
- Comprehensive `AGENTS.md` with architecture, gotchas, commands

### Desktop (NixOS)
- **Niri** (Wayland compositor) with wrapped config
- **Waybar** with Catppuccin Mocha theme
- **SDDM** with silent theme
- **Rofi**, swaylock, wlogout, Yazi, Zellij, Chromium

### Scripts (17 in `scripts/`)
- All under `justfile` recipes
- Shared `scripts/lib.sh` for common functions
- `validate.sh` for shellcheck

---

## b) PARTIALLY DONE 🔧

### `mkDockerService` Migration (2/4 done)
- ✅ `manifest.nix` — migrated
- ✅ `openseo.nix` — migrated
- ❌ `twenty.nix` — still uses inline docker-compose pattern
- ❌ `voice-agents.nix` — still uses inline docker-compose pattern

These two modules have the same boilerplate (tmpfiles, preStart, serviceConfig, harden, serviceDefaults) that `mkDockerService` was designed to eliminate.

### `serviceTypes.servicePort` Migration (4/~15 done)
- ✅ `signoz.nix` — 4 port options migrated
- ✅ `openseo.nix` — uses `serviceTypes.servicePort`
- ✅ `manifest.nix` — uses `serviceTypes.servicePort`
- ✅ `photomap.nix` — uses `serviceTypes.servicePort`
- ❌ Other services with `port` options still use manual `lib.types.port` or `lib.types.int`

### `mkStateDir` Adoption (0 services)
- Helper exists in `lib/default.nix` but no service module uses it yet
- Many services manually write `"d ${stateDir} 0755 root root -"` in tmpfiles

### `mkHttpCheck` Adoption (1 service)
- Only `gatus-config.nix` uses it
- Could be expanded to other health-check patterns

### DNS Failover Cluster
- Module exists (`dns-failover.nix`) with Keepalived VRRP
- **Pi 3 hardware not yet provisioned** — module tested but not deployed

### macOS (Darwin) Platform
- Config builds and deploys
- otel-tui correctly excluded (saves 40+ min build)
- d2 overlay with Darwin stubs works
- **Darwin disk** regularly at 90-95% — needs ongoing vigilance

---

## c) NOT STARTED 📋

### Service Modules Not Using Shared Helpers
These services still use inline systemd patterns instead of `harden {}` / `serviceDefaults {}`:
- `default.nix` (docker auto-prune — trivial, 31 lines)
- `audio.nix` (33 lines — PipeWire config)
- `display-manager.nix` (32 lines — SDDM)
- `browser-policies.nix` (72 lines — Chromium policies)
- `multi-wm.nix` (60 lines)
- `steam.nix` (54 lines)
- `minecraft.nix` (449 lines — inline service, no docker)

### RPI3 DNS Node
- `nixosConfigurations.rpi3-dns` defined in flake
- Uses minimal overlays (`[NUR] ++ linuxOnlyOverlays`)
- **Hardware not provisioned** — Pi 3 not yet set up

### Twenty CRM Full Integration
- Service module exists (188 lines)
- Not yet migrated to `mkDockerService`
- Status: running but boilerplate-heavy

### Automated Testing
- `just test-fast` (syntax validation) works
- `just test-aliases` (shell alias tests) works
- **No NixOS VM tests** — no `nixosTests` defined
- **No integration tests** — services tested manually

### Remote Deploy from macOS
- Currently SSH into evo-x2 → `nh os boot`
- No `just switch` from macOS that deploys remotely
- Could use `nixos-rebuild --target-host` or `deploy-rs`

### Secrets Rotation
- No automated secret rotation
- Manual process via `sops`

---

## d) TOTALLY FUCKED UP 💥

### Session 25-31 Build Error Marathon
The last 7 sessions (25-31) were dominated by a cascade of build failures:
1. **`lib/docker.nix` not tracked by Git** — new file not `git add`ed. Nix flakes require all referenced files to be tracked.
2. **`undefined variable 'onFailure'`** — transient error caused by dirty working tree with inconsistent partial changes from parallel sessions.
3. **`voice-agents.nix` vendorHash mismatch** — upstream Go dependency changes breaking Nix build hashes.
4. **`todo-list-ai` npmDeps hash** — same pattern, Node.js dependency hash drift.
5. **5 out of 6 upstream Go repos needed hash updates** — cascading `flake.lock` updates required.

**Root cause:** Multiple parallel AI sessions modifying the same codebase without coordination, leaving partial changes that break evaluation.

**Fix applied:** All sessions resolved. Build evaluates clean. Working tree is clean.

### Known Permanent Issues
| Issue | Impact | Status |
|-------|--------|--------|
| GMKtec 130W power ceiling | CPU throttled under sustained load | Accepted — firmware limit |
| awww-daemon 0.12.0 BrokenPipe | Wallpaper daemon crashes on Wayland disconnect | Mitigated — `Restart=always` |
| statix pipe operator parse errors | Pre-commit hook false positives on `|>` | Mitigated — grep filter |
| watchdogd nixpkgs module broken | `device` and `reset-reason` sections fail | Workaround — omit broken options |
| niri-session-manager limitation | Cannot restore terminal child processes | Accepted — upstream issue |
| Darwin disk (229 GB) | Regularly at 90-95% capacity | Ongoing — manual cleanup |

---

## e) WHAT WE SHOULD IMPROVE 🚀

### 1. Stop Having Parallel Sessions Break the Build
This week's 7-session build error marathon was caused by multiple AI sessions modifying files simultaneously. We need either:
- A session lock file (`.session-lock` that sessions check before modifying)
- Or a strict rule: **one session at a time**, commit between sessions

### 2. Automated Hash Drift Detection
5/6 upstream Go repos needed hash updates in the same build. We should have a CI job or `just` recipe that:
- Runs `nix build` for each overlay package
- Detects hash mismatches early
- Suggests the correct hash

### 3. Test Coverage
111 `.nix` files, 35 service modules, 140 systemd services — **zero automated NixOS VM tests**. We're flying blind on correctness. Even basic `test-fast` only validates syntax.

### 4. `mkDockerService` Migration Completion
2 services remain with inline docker-compose boilerplate. The factory exists and works. Just needs adoption.

### 5. `serviceTypes.servicePort` Full Adoption
~11 services still define ports manually. Centralizing on `serviceTypes.servicePort` ensures consistency and makes port changes single-source-of-truth.

### 6. Dead Status Report Accumulation
42 status reports in `docs/status/` — many are redundant (sessions 25-31 are all about the same build error cascade). Should archive older ones to `docs/status/archive/`.

### 7. Remote Deploy Pipeline
SSH-ing into evo-x2 to build is slow and fragile. A proper remote deploy from macOS would be faster (evo-x2 has 128GB RAM + 16 cores) and safer (no dirty tree issues).

### 8. AGENTS.md is Huge
The AGENTS.md file is extremely comprehensive but at ~1000+ lines it's expensive to load into every session context. Consider splitting into domain-specific files (e.g., `AGENTS-services.md`, `AGENTS-desktop.md`).

### 9. Pre-commit Hook Coverage
The pre-commit config runs statix and alejandra but doesn't validate that `nix eval` succeeds. A quick `nix eval --impure` check would have caught the `lib/docker.nix` issue before it became a 7-session problem.

### 10. Monitoring Maturity
26+ Gatus endpoints exist but no automated runbook. When an endpoint fails, the response is manual. Consider PagerDuty-style escalation or at minimum a `just runbook <service>` command.

---

## f) Top 25 Things We Should Get Done Next

### Priority 1: Critical (Do This Week)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Migrate `twenty.nix` to `mkDockerService`** | Eliminates 80+ lines of boilerplate | Low |
| 2 | **Migrate `voice-agents.nix` to `mkDockerService`** | Eliminates 60+ lines of boilerplate | Low |
| 3 | **Add `nix eval` to pre-commit hook** | Prevents 7-session build error marathons | Low |
| 4 | **Commit the `flake.lock` update** (1 commit ahead of origin) | Keeps origin in sync | Trivial |
| 5 | **Add `just hash-check` recipe** to detect vendor hash drift | Early warning on upstream changes | Medium |

### Priority 2: High (Do This Month)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | **Migrate remaining ~11 ports to `serviceTypes.servicePort`** | Single source of truth for all ports | Medium |
| 7 | **Adopt `mkStateDir` across all services with tmpfiles** | DRY tmpfiles boilerplate | Low |
| 8 | **Write first NixOS VM test** (e.g., DNS resolver test) | Validates actual service behavior | High |
| 9 | **Archive old status reports** (>30 days) to `docs/status/archive/` | Reduces docs noise | Trivial |
| 10 | **Add session lock mechanism** to prevent parallel session collisions | Prevents build breakage | Medium |
| 11 | **Set up remote deploy pipeline** from macOS → evo-x2 | Faster, safer deployments | Medium |

### Priority 3: Medium (Next Quarter)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 12 | **Provision Pi 3** for DNS failover cluster | HA DNS | Medium |
| 13 | **Split AGENTS.md** into domain-specific files | Reduces context loading | Medium |
| 14 | **Add automated secret rotation** via sops + cron | Security hygiene | High |
| 15 | **Write `just runbook <service>` command** | Faster incident response | Medium |
| 16 | **Migrate `minecraft.nix` to use `harden` + `serviceDefaults`** | Consistency | Low |
| 17 | **Add health check endpoints** to services lacking them | Observability | Medium |

### Priority 4: Nice-to-Have

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | **Extract Caddy virtual hosts to a helper** | DRY reverse proxy config | Medium |
| 19 | **Add Dozzle** for Docker log viewer | Better container observability | Low |
| 20 | **Write integration tests** for critical services (Caddy, DNS, SigNoz) | Correctness validation | High |
| 21 | **Automate Darwin disk cleanup** via LaunchAgent | Prevents disk exhaustion | Low |
| 22 | **Add `nix flake check` to CI** (even manual `just ci`) | Full flake validation | Low |
| 23 | **Monitor365 alerting rules** in Gatus/SigNoz | Device monitoring coverage | Low |
| 24 | **Twenty CRM backup** via `mkDockerService` `backup` parameter | Data protection | Low |
| 25 | **Consolidate `signoz-alerts.nix` mkRule helper** into shared lib | Reusable alert definitions | Medium |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Why do 15 out of 35 service modules NOT use `harden {}`?**

Looking at the adoption numbers: 20 services use `harden`, 15 don't. Some are trivially small (`audio.nix` = 33 lines, `display-manager.nix` = 32 lines). But `minecraft.nix` is 449 lines with inline `PrivateTmp`, `NoNewPrivileges`, etc. — exactly the pattern `harden {}` was designed to replace.

**Is this intentional?** Are there services where `harden {}` can't be applied (e.g., services that need capabilities that harden restricts)? Or is this simply "not yet migrated"?

Understanding this determines whether items 16 and the "adoption gap" are real issues or by design.

---

## Metrics Dashboard

| Metric | Value |
|--------|-------|
| Total commits | 2,390 |
| Commits in May 2026 | 444 |
| `.nix` files | 111 |
| Shell scripts | 22 |
| Service modules | 35 |
| Systemd services (evo-x2) | 140 |
| Custom packages | 6 |
| Flake inputs | 30+ |
| Overlays (shared) | 12 |
| Overlays (linux-only) | 6 |
| Status reports | 42 |
| Planning docs | 30 |
| ADRs | 6 |
| `harden {}` adoption | 20/35 (57%) |
| `serviceDefaults {}` adoption | 19/35 (54%) |
| `onFailure` adoption | 16/35 (46%) |
| `mkDockerService` adoption | 2/4 Docker services (50%) |
| Build status | ✅ Clean |
| Working tree | ✅ Clean (1 commit ahead of origin) |

---

## Recent Session History (Sessions 25-32)

| Session | Date | Summary | Status |
|---------|------|---------|--------|
| 25 | 05-17 03:58 | Parallel session collision, build broken | ✅ Fixed |
| 26 | 05-17 04:00 | Branching-flow vendorHash fix, onFailure bugfix | ✅ Fixed |
| 27 | 05-17 04:11 | Full ecosystem status post-fix | ✅ Done |
| 28 | 05-17 ~04:15 | Abstraction sprint (mkHttpCheck, mkStateDir, consecutive-failure DRY) | ✅ Done |
| 29 | 05-17 ~04:20 | Continued deduplication + AGENTS.md update | ✅ Done |
| 30 | 05-17 ~04:25 | Abstraction sprint complete, full status | ✅ Done |
| 31 | 05-17 ~04:30 | Build error marathon, 5/6 upstream fixes | ✅ Fixed |
| 32 | 05-17 04:35 | **This report** — comprehensive status | 📝 Writing |

---

*Generated by Crush — Session 32*
