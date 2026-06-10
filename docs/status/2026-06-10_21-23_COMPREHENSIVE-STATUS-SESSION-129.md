# SystemNix — Comprehensive Status Report

**Date:** 2026-06-10 21:23
**Session:** 129
**Trigger:** User-requested full status audit after auth/security/hardening sprint
**Author:** Crush (assisted)

---

## Executive Summary

SystemNix is a cross-platform Nix configuration managing **2 machines** (NixOS desktop + macOS laptop) with **39 service modules**, **25 overlay packages**, and **35 port definitions**. The codebase is in **strong shape**: all CI checks pass, zero FIXME/HACK/WORKAROUND markers exist, ports are fully centralized with collision detection, and the lib/ helper layer is complete with zero dead code.

**This session** committed 5 focused changes: manifest auth protection, Pocket ID provision API fixes (header casing + URL encoding + race conditions), admin email update, homepage YAML refactoring (mkGroup/mkService), and QDirStat package addition.

**Top risks:** Pocket ID provision API still potentially broken at runtime (fix committed but not yet deployed), NVMe 2m50s boot delay (hardware/firmware), and 2 pre-existing service failures (discordsync, file-and-image-renamer).

---

## a) FULLY DONE

### Build & Quality

- ✅ `nix flake check` passes on both platforms (Darwin + NixOS)
- ✅ `just test-fast` passes (statix, deadnix, alejandra, eval)
- ✅ Pre-commit hooks: gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check
- ✅ Zero FIXME / HACK / WORKAROUND / XXX markers in any .nix file
- ✅ GitHub Actions CI: `nix-check.yml` (push/PR) + `flake-update.yml` (weekly auto-PR)

### Architecture

- ✅ flake-parts modular architecture with 39 auto-discovered service modules
- ✅ Cross-platform flake: Darwin (aarch64) + NixOS (x86_64) — 80% shared via `platforms/common/`
- ✅ `lib/` helper layer complete and fully used (0 dead helpers):
  - `harden` / `hardenUser` — systemd security hardening (~20+ modules)
  - `serviceDefaults` / `serviceDefaultsUser` — standard defaults with `mkForce`
  - `onFailure` — centralized failure notification
  - `serviceTypes` — eval-time option validators (reject `latest` tags)
  - `mkDockerServiceFactory` — Docker Compose systemd scaffolding
  - `mkStateDir` / `mkSecretCheck` / `mkDesktopNotifyService` / `mkHttpCheck`
  - `ports` — 35 ports with collision detection
  - `images` — pinned container image references
  - `rocm` — GPU runtime helpers
- ✅ Port centralization: all service modules reference `ports.*`, zero hardcoded ports
- ✅ Overlay architecture: `mkPackageOverlay` for platform-safe overlays, 25 packages total

### Infrastructure Services (Running)

| Service | Status | Notes |
|---------|--------|-------|
| Caddy (reverse proxy) | ✅ | 10+ vhosts, TLS via sops, forward auth, metrics |
| Pocket ID (OIDC) | ✅ | Passkey auth, declarative provisioning (committed, pending deploy) |
| oauth2-proxy | ✅ | Forward-auth bridge Caddy ↔ Pocket ID |
| SOPS secrets | ✅ | Age-encrypted via SSH host key, 4 sops files |
| Forgejo (Git forge) | ✅ | SQLite, LFS, Actions runner, federation, push mirrors |
| Forgejo repos | ✅ | Declarative mirroring + daily timer |
| SigNoz (observability) | ✅ | Traces/metrics/logs, ClickHouse, 7 alert rules |
| Homepage Dashboard | ✅ | Catppuccin Mocha, 6 categories, mkGroup/mkService |
| Immich (photos) | ✅ | PostgreSQL + Redis + ML, VA-API transcoding, GPU ML |
| Twenty CRM | ✅ | Docker Compose, daily DB backup |
| TaskChampion | ✅ | Taskwarrior sync, TLS via Caddy |
| Gatus (uptime) | ✅ | 30+ health checks, status page |
| Hermes (AI gateway) | ✅ | Discord bot, cron, messaging, 4G memory limit |
| Dozzle (Docker logs) | ✅ | Inline config (module causes eval issue) |
| OpenSEO | ✅ | SEO suite, Caddy vhost |
| Crush Daily | ✅ | AI-powered dev insights |
| Monitor365 | ✅ | Device monitoring, ActivityWatch integration |
| DNS Blocker | ✅ | Unbound + stats API + block page |
| Default Services | ✅ | Docker auto-enable, weekly prune |
| Disk Monitor | ✅ | Daily growth alerts, BTRFS checks |
| NVMe Health Monitor | ✅ | SSD health + temperature alerts |

### Desktop (Fully Functional)

- ✅ Niri (scrolling-tiling Wayland) — 80+ keybindings, session save/restore
- ✅ Waybar — 15+ modules including DNS stats, weather, camera
- ✅ Rofi — Catppuccin Mocha, plugins (calc, emoji)
- ✅ SDDM — SilentSDDM, Catppuccin theme
- ✅ PipeWire audio — ALSA + PulseAudio + JACK compat
- ✅ Ghostty (primary) + Kitty (backup) + Foot (sway fallback)
- ✅ Catppuccin Mocha global theme — GTK, icons, cursor, fonts, all apps
- ✅ nix-colors integration — `colorScheme` drives Starship/Fzf/Qt/GTK
- ✅ Yazi (file manager), Zellij (multiplexer), Dunst (notifications)
- ✅ Steam gaming — protontricks, gamemode, gamescope, mangohud
- ✅ EMEET PIXY webcam — auto-tracking, metrics endpoint
- ✅ AMD GPU — ROCm, VA-API, Vulkan, 32-bit support

### Session 129 Commits (This Session)

| Commit | Description |
|--------|-------------|
| `f679b8fb` | `fix(caddy)` — manifest vhost: raw reverse_proxy → `protectedVHost` (forward auth) |
| `21ce65fb` | `fix(pocket-id)` — API header casing, URL encoding, race conditions, removed deprecated fields |
| `109b6d3e` | `chore(pocket-id)` — admin email `.com` → `.cloud` |
| `78b52da0` | `refactor(homepage)` — mkGroup/mkService + ALLOWED_HOSTS + cache dir + dead `when` removed |
| `d0bf0347` | `feat(packages)` — add QDirStat for GUI disk space visualization |

---

## b) PARTIALLY DONE

### Pocket ID Declarative Provisioning

**Status:** Code complete, committed, **NOT YET DEPLOYED**

- ✅ Admin user creation with race-condition handling
- ✅ OIDC client provisioning with idempotent "already exists" detection
- ✅ Avatar upload from sops secret
- ✅ Client secret auto-generation and storage
- ⚠️ **Runtime unverified** — session 128 reported API split-brain (STATIC_API_KEY authenticates but returns empty data). This session's fixes (header casing `X-API-KEY` → `X-API-Key`, URL encoding `pagination[limit]` → `pagination%5Blimit%5D`) address the most likely causes but need deployment + testing.

### BTRFS Snapshots

- ✅ Root (`@`): daily via btrbk, 14d + 4w auto-pruning
- ✅ Pre-deploy snapshots via `just switch`
- ✅ Verify timer alerts if snapshots >3 days stale
- ⚠️ `/data` still on BTRFS toplevel (subvolid=5) — cannot be snapshotted. `just snapshot-migrate-data` exists but not yet run.

### AI Stack

- ✅ Ollama with ROCm GPU, llama.cpp custom ROCm build, gpu-python wrapper
- ✅ Centralized model storage at `/data/ai/`
- ⚠️ Voice agents (LiveKit + Whisper) disabled — Docker ROCm, no immediate need
- ⚠️ PhotoMap AI disabled — podman permission issue

### Darwin (macOS) Parity

- ✅ Shared packages, Home Manager, shell config, theme
- ⚠️ Only 7 lines of Home Manager config vs extensive NixOS desktop setup
- ⚠️ Disk critically full (90%+), cannot add heavy packages

---

## c) NOT STARTED

| Item | Priority | Blocker |
|------|----------|---------|
| Pi 3 DNS failover provisioning | Low | Hardware not available |
| Pi 3 wiring as secondary DNS | Low | Depends on Pi 3 |
| `/data` BTRFS subvolume migration | Medium | Requires downtime + testing |
| Hermes fallback LLM provider (OpenRouter) | Medium | Manual: add API key to sops |
| Hermes SSH deploy key installation | Medium | Manual: install private key + add to GitHub |
| Boot time verification (target ~35s) | Low | Requires reboot |
| SigNoz provision log verification | Low | Requires `just switch` + curl |
| Discord alert channel test | Low | Requires webhook secret on evo-x2 |
| Gatus endpoint health verification | Low | Requires deploy + curl |
| Auditd enablement | Low | Blocked on NixOS 26.05 bug (nixpkgs#483085) |
| Home Manager Darwin parity | Low | Disk constraint on MacBook Air |
| Jan llama-server respawn leak fix | Low | Not a systemd service — needs upstream fix or wrapper |
| Swap cleanup (17/19 GiB with 70Gi RAM free) | Low | `swapoff -a && swapon -a` |

---

## d) TOTALLY FUCKED UP

### Pocket ID Provision API — Split-Brain (Session 128)

The `STATIC_API_KEY` authenticates successfully but list endpoints (`/api/users`, `/api/oidc/clients`) return **empty data** while create endpoints respond with **"already exists"**. This means the API key has write access but somehow cannot read.

**Root cause hypothesis (this session):** The `X-API-KEY` header was using wrong casing (`X-API-KEY` vs `X-API-Key`). Pocket ID may be case-sensitive on header names. The fix is committed but **not yet deployed**.

**Impact:** Provision script cannot detect existing users/clients and falls through to creation, which fails with "already exists". The race-condition handling added this session should mitigate, but the core read issue may persist.

**Next step:** Deploy and test. If header casing was the root cause, this resolves fully. If not, need to investigate Pocket ID API auth model.

### Discordsync — Persistent Failure

Exit code 69 (CURLE_OPERATION_TIMEDOUT / UNAVAILABLE). The Discord bot token is likely expired or invalid. This is a **pre-existing failure** from before session 128.

**Impact:** Discord notifications not flowing. No data loss — other notification paths exist.

**Next step:** Regenerate Discord bot token, update sops secret.

### NVMe 2m50s Boot Delay

The GMKtec EVO-X2 NVMe device takes 2m50s to be detected by the kernel. This is a **hardware/firmware issue** — the kernel logs show the device not appearing until well after init.

**Impact:** Boot time is 6m17s instead of target ~35s.

**Next step:** BIOS/firmware update investigation, kernel parameter tuning (`nvme_core.default_max_host_mem_size_mb`), or hardware replacement.

---

## e) WHAT WE SHOULD IMPROVE

### Code Quality

1. **Homepage `mkGroup`/`mkService` output correctness** — The refactored helpers generate YAML via string concatenation. Should verify the output matches the previous format exactly by comparing `nix eval` output before/after. Potential whitespace/newline differences could break Homepage parsing.

2. **Dozzle modularization** — Creating a proper `dozzle.nix` module with options causes `nix flake check` eval failure. Root cause unknown. Should investigate and file upstream bug if it's a flake-parts issue.

3. **Test coverage** — Only 2 NixOS VM tests (boot + DNS blocking). No service-specific tests. Adding per-service integration tests would catch regressions earlier.

4. **Swap usage monitoring** — 17/19 GiB swap with 70 GiB RAM free indicates stale processes. Should add a swap-pressure alert to SigNoz/Gatus and a periodic swap cleanup timer.

### Architecture

5. **`/data` BTRFS migration** — Running on toplevel (subvolid=5) means no snapshot protection for Docker data, Immich uploads, AI models. High-value data at risk.

6. **Hermes secrets** — OpenAI/OpenRouter API key and SSH deploy key both require manual sops edits. Should automate with a `just hermes-setup` recipe.

7. **Darwin disk management** — 90%+ full, `nix-collect-garbage` hangs. Need a lightweight cleanup strategy or CI/CD to offload builds.

### Operations

8. **Deployment verification gap** — Many TODO items are "blocked: requires deploy + manual curl". The `just verify` recipe exists but hasn't been run since session 122. Should make post-deploy verification a standard practice.

9. **Pocket ID API documentation** — No official API docs. We're reverse-engineering the API from source code. Should contribute upstream or maintain a local API reference.

10. **Status report archive bloat** — 150+ status reports in `docs/status/`. Many are redundant. Should archive old ones and keep only the latest per-day.

---

## f) Top 25 Things We Should Get Done Next

### Critical (Deploy & Verify)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Deploy session 129 changes** (`just switch`) and verify Pocket ID provision works | 15min | HIGH — confirms auth fixes |
| 2 | **Test Pocket ID provision end-to-end** after deploy: admin user, OIDC clients, avatar | 10min | HIGH — validates 3 sessions of work |
| 3 | **Regenerate Discordsync Discord bot token** and update sops | 5min | MEDIUM — restores Discord notifications |
| 4 | **Run `just verify`** post-deploy to check all services | 5min | MEDIUM — catches regressions |

### High Value (Security & Resilience)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | **Migrate `/data` to BTRFS subvolume** — `just snapshot-migrate-data` | 30min | HIGH — enables snapshots for Docker/Immich/AI data |
| 6 | **Add swap-pressure Gatus alert** — alert when swap > 50% with RAM > 50% free | 15min | MEDIUM — catches stale process leaks |
| 7 | **Add periodic swap cleanup timer** — `swapoff -a && swapon -a` weekly | 10min | LOW — prevents swap accumulation |
| 8 | **Add Homepage `mkGroup`/`mkService` output test** — compare YAML before/after | 15min | MEDIUM — verifies refactor correctness |
| 9 | **Investigate NVMe boot delay** — kernel params, firmware update | 60min | HIGH — 6m → 35s boot time |

### Architecture & Quality

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | **Add service-level NixOS VM tests** — start with Forgejo, Immich, Pocket ID | 2hr | HIGH — catches regressions before deploy |
| 11 | **Investigate Dozzle module eval failure** — root cause the `nix flake check` issue | 30min | LOW — enables proper module pattern |
| 12 | **Create Hermes setup automation** — `just hermes-setup` for API key + SSH key | 20min | MEDIUM — eliminates manual sops edits |
| 13 | **Archive old status reports** — move pre-June reports to `docs/status/archive/` | 10min | LOW — cleans up repo |
| 14 | **Add per-service `startLimitBurst`** audit — ensure all services have crash-loop protection | 20min | MEDIUM — prevents OOM cascades |
| 15 | **Centralize Caddy vhost pattern** — all vhosts use `protectedVHost` or `vHost` helper | 15min | LOW — consistency |

### Features & Enhancements

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | **Re-enable file-and-image-renamer** when Go 1.26.3 lands in nixpkgs | 5min | MEDIUM — AI file renaming |
| 17 | **Add btdu** for BTRFS-aware disk analysis (recommended in this session) | 5min | LOW — accurate Btrfs space reporting |
| 18 | **Add compsize** for Btrfs compression ratio reporting | 5min | LOW — compression visibility |
| 19 | **Fix PhotoMap podman permissions** — investigate and re-enable | 30min | LOW — AI photo visualization |
| 20 | **Add auditd** when NixOS 26.05 bug is resolved | 5min | LOW — security compliance |
| 21 | **Darwin cleanup strategy** — automated GC + build cache management | 60min | MEDIUM — prevents disk exhaustion |

### Documentation

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 22 | **Update FEATURES.md** — last updated 2026-06-03, missing session 129 changes | 15min | MEDIUM — accurate feature inventory |
| 23 | **Update TODO_LIST.md** — mark session 129 items, add new verification tasks | 10min | MEDIUM — accurate task tracking |
| 24 | **Create Pocket ID API reference** — document discovered endpoints and auth model | 30min | MEDIUM — prevents future API confusion |
| 25 | **Update AGENTS.md** with session 129 learnings (ALLOWED_HOSTS, mkGroup/mkService pattern) | 10min | LOW — helps future sessions |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Is the Pocket ID `X-API-Key` header casing actually the root cause of the empty API responses?**

Session 128 documented that `STATIC_API_KEY` authenticates (no 401) but list endpoints return empty data while create endpoints say "already exists". This session fixed `X-API-KEY` → `X-API-Key` based on Pocket ID source code showing exact casing. But:

- **If header casing was wrong, we'd expect 401 Unauthorized, not 200 with empty data.**
- The empty-data-with-valid-auth pattern suggests a **permissions model** issue — perhaps the API key has a different access level than the admin UI session.
- Alternatively, the URL encoding fix (`pagination[limit]` → `pagination%5Blimit%5D`) may be the actual fix — raw brackets in query strings could cause the server to silently ignore the pagination parameter and return page 0 with 0 results.

**This can only be answered by deploying and testing.** The header fix, URL encoding fix, and debug logging added this session will make the diagnosis clear from the provision script output.

---

## System Health At a Glance

```
Build:           ✅ PASSING (nix flake check, just test-fast)
CI:              ✅ PASSING (nix-check.yml, flake-update.yml)
Services:        17/19 active (2 pre-existing failures)
Ports:           35 centralized, collision-protected
Overlays:        25 packages (17 shared + 8 Linux-only)
Service Modules: 39 auto-discovered
Lib Helpers:     14 helpers, 0 dead code
FIXME/HACK:      0
Commits Ahead:   0 (pushed this session)
Working Tree:    CLEAN
```

---

## Session Timeline

| Session | Date | Key Changes |
|---------|------|-------------|
| 120 | Jun 8 | Deduplication sprint, port centralization, nix-colors migration |
| 121 | Jun 8 | Color migration completion, Darwin parity |
| 122 | Jun 8 | TODO completion sprint |
| 123 | Jun 8 | Comprehensive status post-execution |
| 124 | Jun 8 | Cross-ecosystem flake fix sprint |
| 125 | Jun 9 | Go migration completion audit |
| 126 | Jun 9 | Vendor hash cascade + follow-deps fix |
| 127 | Jun 9 | Pocket ID declarative provisioning, Homepage dynamic tiles |
| 128 | Jun 10 | Post-GPU-crash cascade fix (sops, SigNoz, watchdog, hardening) |
| **129** | **Jun 10** | **Manifest auth, Pocket ID API fixes, Homepage refactor, QDirStat** |

---

_Generated by Crush. Awaiting instructions._
