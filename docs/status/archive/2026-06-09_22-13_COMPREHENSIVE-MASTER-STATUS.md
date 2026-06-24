# SystemNix — Comprehensive Master Status Report

**Date:** 2026-06-09 22:13 CEST
**Host:** evo-x2 (NixOS x86_64-linux) + Lars-MacBook-Air (aarch64-darwin)
**Branch:** master
**HEAD:** `b119d320` (refactor(ports): centralize all service ports in lib/ports.nix)
**Uncommitted Changes:** 17 files (all in this session: port centralization, xdg portals, file manager, Rust toolchain)

---

## A) FULLY DONE

### Core Infrastructure
| Feature | Status | Evidence |
|---------|--------|----------|
| `just test-fast` (nix flake check) | ✅ PASSES | Evaluates all 36 modules, 22 packages, 2 NixOS configs, Darwin config |
| flake-parts modular architecture | ✅ | 46 files in `modules/nixos/services/`, auto-discovered |
| Cross-platform (Darwin + NixOS) | ✅ | Single flake, 80% shared via `platforms/common/` |
| Port centralization (lib/ports.nix) | ✅ JUST COMPLETED | All 15+ services migrated from hardcoded ports to `ports.*` references. Removed `twenty-internal = 3000` orphan. |
| `mkPackageOverlay` platform safety | ✅ | Returns `{}` on Darwin — no eval break |
| NixOS modules auto-discovery | ✅ | `serviceModules` globs `modules/nixos/services/*.nix`, skips `_prefix` |

### Recent Session Deliverables (Sessions 120–127)
| Session | Date | Key Deliverable |
|---------|------|-----------------|
| 120 | 2026-06-08 | Port deduplication sprint — centralized `lib/ports.nix`, removed duplicate `ollama` port |
| 122 | 2026-06-08 | TODO completion sprint — `just status`, `just verify`, nix-colors migration, per-threshold SigNoz alerts |
| 123 | 2026-06-08 | Post-execution comprehensive status |
| 124 | 2026-06-08 | Cross-ecosystem flake fix sprint |
| 125 | 2026-06-09 | Go migration completion audit — all 12 Go packages build cleanly |
| 126 | 2026-06-09 | vendorHash cascade fix — `mkTidyOverride` helper, `proxyVendor` pattern for inconsistent vendoring |
| 127 (this) | 2026-06-09 | Port centralization completion — every service module now uses `ports.*` |

### Port Centralization (This Session — COMPLETE)
All services migrated from hardcoded port numbers to `lib/ports.nix`:

| Service | Before | After (ports.*) |
|---------|--------|-----------------|
| dns-blocker-stats | `9090` | `ports.dns-blocker-stats` |
| homepage | `8082` | `ports.homepage` |
| manifest | `2099` | `ports.manifest` |
| minecraft | `25565` | `ports.minecraft` |
| monitor365-server | `3001` | `ports.monitor365-server` |
| monitor365-activitywatch | `5600` | `ports.activitywatch` |
| monitor365-cadvisor | `9190` | `ports.signoz-cadvisor` |
| multi-wm | N/A | N/A (switched file manager) |
| oauth2-proxy | `4180` | `ports.oauth2-proxy` |
| openseo | `3002` | `ports.openseo` |
| photomap | `8051` | `ports.photomap` |
| pocket-id | `1411` | `ports.pocket-id` |
| pocket-id-metrics | `9464` | `ports.pocket-id-metrics` |
| taskchampion | `10222` | `ports.taskchampion` |
| twenty | `3200` | `ports.twenty` |
| voice-agents whisper | `7860` | `ports.whisper` |
| voice-agents livekit UDP | `50000-51000` | `ports.livekit-udp-start/end` |

### Authentication & Security
| Feature | Status |
|---------|--------|
| Pocket ID (passkey OIDC) | ✅ Go backend, SQLite, web UI, `auth.home.lan` |
| oauth2-proxy | ✅ Forward-auth bridge, cookie sessions, `mkSecretCheck` |
| WebAuthn hybrid transport | ✅ JUST ADDED — Helium `--enable-features=WebAuthenticationHybridTransport` + BLE experimental |
| Caddy reverse proxy | ✅ 10+ vhosts, TLS via sops, `protectedVHost` pattern |
| fail2ban (SSH aggressive) | ✅ |
| Security hardening module | ✅ 30+ tools, ClamAV, polkit, GNOME Keyring |

### Self-Hosted Applications (Enabled)
| Service | Status | Notes |
|---------|--------|-------|
| Forgejo | ✅ | SQLite, LFS, Actions, federation, declarative repos |
| Immich | ✅ | VA-API transcoding, ML GPU, OAuth via Pocket ID |
| SigNoz | ✅ | ClickHouse, OTel Collector, 7 alert rules, dashboards |
| Twenty CRM | ✅ | Docker Compose, PostgreSQL+Redis, `crm.home.lan` |
| Homepage | ✅ | Catppuccin Mocha, 5 categories, resource widgets |
| TaskChampion | ✅ | Port 10222, TLS via Caddy |
| Dozzle | ✅ | Docker log viewer at `logs.home.lan` |
| OpenSEO | ✅ | Self-hosted SEO suite |
| Hermes AI gateway | ✅ | Discord bot, cron, messaging, 4G mem limit |
| Monitor365 | ✅ | ActivityWatch integration, user systemd service |
| DNS blocker (dnsblockd) | ✅ | ~930-line Go, 2.5M+ domains, 10 categories, temp-allow API |

### AI/ML Stack
| Feature | Status |
|---------|--------|
| Ollama (ROCm GPU) | ✅ Flash attention, q8_0 KV, 32G MemoryMax |
| llama.cpp (custom ROCm) | ✅ ROCWMMA + MFMA build |
| gpu-python wrapper | ✅ ROCm env vars + LD_LIBRARY_PATH |
| AI model storage | ✅ `/data/ai/` (14 dirs), tmpfiles rules |

### Desktop Environment (Niri + Wayland)
| Feature | Status |
|---------|--------|
| Niri compositor | ✅ Unstable, XWayland satellite, session restore |
| SDDM | ✅ SilentSDDM, Catppuccin theme |
| PipeWire audio | ✅ A2DP source/sink, Nest Audio casting |
| Waybar | ✅ 15+ modules including DNS stats, weather |
| Rofi | ✅ Grid layout, calc, emoji plugins |
| Dunst | ✅ Catppuccin-colored, overlay layer |
| Ghostty | ✅ Primary terminal, VAAPI, Widevine |
| Kitty | ✅ Backup terminal |
| File manager | ✅ JUST CHANGED: Dolphin → Nautilus (Nautilus .desktop associations added) |
| Bluetooth | ✅ A2DP + BLE experimental (WebAuthn hybrid) |

### Development Tools (Cross-Platform)
| Toolchain | Status |
|-----------|--------|
| Go (1.26.1 via nixpkgs) | ✅ gopls, golangci-lint, delve, buf, sqlc, etc. |
| Node.js/Bun/pnpm | ✅ vtsls, esbuild, oxlint, oxfmt |
| Rust | ✅ JUST ADDED: cargo, rustc, rustfmt, clippy, rust-analyzer (NixOS only) |
| Python (AI/ML) | ✅ torch, transformers, opencv, etc. |
| Nix helpers | ✅ nh, statix, deadnix |
| Container/K8s | ✅ docker, docker-compose, kubectl, k9s |

### Go Package Ecosystem (All 12 Build Cleanly)
| Package | SystemNix Status | Upstream Status |
|---------|------------------|-----------------|
| buildflow | ✅ `{}` overlay | ✅ vendorHash updated |
| go-auto-upgrade | ✅ override | ✅ vendorHash updated |
| projects-management-automation | ✅ `{}` overlay | ✅ vendorHash updated |
| library-policy | ✅ `mkTidyOverride` | ✅ vendorHash updated |
| golangci-lint-auto-configure | ✅ custom override | ✅ vendorHash updated |
| mr-sync | ✅ `mkTidyOverride` | ✅ vendorHash updated |
| hierarchical-errors | ✅ override | ✅ no change needed |
| go-structure-linter | ✅ override | ✅ no change needed |
| art-dupl | ✅ override | ✅ no change needed |
| branching-flow | ✅ `{}` | ✅ no change needed |
| project-meta | ✅ `{}` | ✅ no change needed |
| todo-list-ai | ✅ `{}` | ✅ no change needed |

---

## B) PARTIALLY DONE

### XDG Desktop Portal Refinement
- **Status:** ⚠️ In progress
- **What changed:** Added `xdg-desktop-portal-gnome` alongside `xdg-desktop-portal-gtk` for better GNOME app integration (Nautilus, etc.)
- **What's missing:** Need to verify Nautilus file picker works correctly in non-GNOME sessions (Niri). GNOME portal may conflict with GTK portal for some MIME types.
- **Risk:** Low — both portals have `After=niri.service` override

### BTRFS `/data` Subvolume Migration
- **Status:** ⚠️ Partially complete
- **Current:** `/data` is BTRFS toplevel (subvolid=5) — NOT snapshotted
- **Docs exist:** `docs/planning/btrfs-snapshot-bloat-fix.html` with full migration plan
- **Blocked by:** Disk space (99% on root) — migration requires temporary free space
- **Impact:** `/data` has no snapshot protection; `just snapshot` only snapshots `@`

### Hermes AI Gateway
- **Status:** ⚠️ Partially configured
- **Done:** `OPENAI_API_KEY` env var wired, sops template placeholder exists, SSH deploy key generated
- **Pending:** Manual steps required on evo-x2:
  1. Add `openai_api_key` to `platforms/nixos/secrets/hermes.yaml` via sops
  2. Install SSH deploy key to `/home/hermes/.ssh/id_ed25519`
  3. Add public key to GitHub deploy keys
  4. Set fallback model: `hermes config set fallback_model openrouter/gpt-4o`

### monitor365 (Upstream Rust/WASM)
- **Status:** ⚠️ Build works on clean tree; broken with uncommitted changes
- **Issue:** monitor365 repo has uncommitted audio/mic monitoring feature that breaks compilation
- **Impact:** Blocks `nixos-rebuild switch` when building full system closure
- **Workaround:** Clean working tree builds fine; issue is in upstream repo, not SystemNix
- **Files affected:** `crates/domain/src/event_type/category.rs`, `enum.rs`, `events/mod.rs`, `lib.rs`, `crates/collectors/common/src/lib.rs`, `linux/src/lib.rs`, `config/src/collector.rs`, plus untracked `mic_monitor.rs` and `audio.rs`

---

## C) NOT STARTED

### Raspberry Pi 3 DNS Failover
- Hardware not provisioned
- `dns-failover.nix` module exists, `rpi3-dns` config defined
- Blocked: No Pi hardware, no SD card image built

### File & Image Renamer (Re-enable)
- Disabled due to `charm.land/fantasy@v0.25.0` requiring Go 1.26.3; nixpkgs-unstable has 1.26.2
- Resolution: Wait for nixpkgs to bump Go, or pin fantasy to older version

### Voice Agents (LiveKit + Whisper)
- Disabled in configuration
- Module exists: `voice-agents.nix` with LiveKit, Whisper ROCm, Caddy reverse proxy
- Blocked: Not prioritized; ROCm GPU resources needed

### Minecraft Server
- Disabled in configuration
- Module exists with whitelist, JDK 25, ZGC
- Blocked: Not currently playing

### PhotoMap AI
- Disabled in configuration (`# photomap.enable = true;`)
- Module exists, port 8051 (was 8050 conflict)
- Blocked: Not prioritized; may need AI model setup

### Multi-WM (Sway Backup)
- Disabled in configuration
- Module exists, may have bitrot
- Blocked: Niri is primary; Sway was emergency fallback

### `/data` → `@data` BTRFS Subvolume Conversion
- Documented in `docs/planning/btrfs-snapshot-bloat-fix.html`
- Requires: 1. Create `@data` subvolume, 2. rsync data, 3. Update fstab, 4. Reboot
- Blocked by: 99% disk on root, need temporary space

### Darwin Home Manager Parity (Complete)
- Partially done in session 121 (zellij, yazi, zed-editor, session vars, xdg)
- **Still missing from Darwin:** Rust toolchain (just added to NixOS only), ecapture (Linux-only), many Linux GUI apps
- This is BY DESIGN per AGENTS.md: Darwin is 24GB RAM, 256GB SSD, 90%+ full — must stay lightweight

---

## D) TOTALLY FUCKED UP!

### Disk Space on evo-x2 (CRITICAL)
```
/dev/nvme0n1p6  512G  492G  7.8G  99%  /
```
- **Status:** 🔥 ROOT IS 99% FULL — 7.8GB free on a 512GB drive
- **Impact:** Cannot run `nixos-rebuild switch` (needs space for new closure), cannot create snapshots, system instability risk
- **Cause:** `/nix/store` is 90GB + generations + no recent GC
- **Mitigation:** `nix-collect-garbage` + `nix store optimise` needed IMMEDIATELY
- **/data status:** 90% full (920G/1TB) — also tight but not critical

### Darwin Disk (HIGH RISK)
- 256GB SSD, 90-95% full per AGENTS.md
- `nix-collect-garbage` is known to hang
- Cannot add heavy packages (otel-tui takes 40+ min builds)

### monitor365 Uncommitted Changes (BLOCKER for Deploy)
- The monitor365 repo (flake input) has uncommitted Rust changes
- These break `nix build .#monitor365-ui` and cascade to `monitor365-server`
- Since SystemNix builds the full closure including monitor365, this blocks `just switch`
- **Fix:** Either commit WIP in monitor365 repo, or temporarily disable monitor365 in SystemNix config

### Auditd Disabled
- NixOS 26.05 bug #483085 — auditd causes issues
- Commented out in `security-hardening.nix`
- Impact: Reduced audit logging

### AppArmor Commented Out
- In `security-hardening.nix`
- Impact: No mandatory access control beyond standard Linux permissions

---

## E) WHAT WE SHOULD IMPROVE!

### 1. Disk Space Management (Priority: CRITICAL)
- Run `nix-collect-garbage -d` on evo-x2 immediately
- Consider `nix store optimise` for deduplication
- Set up automatic GC (e.g., weekly `nix-collect-garbage --max-freed 50G`)
- Evaluate `/data` subvolume migration to free up root pressure

### 2. Port Centralization Follow-Up (Priority: HIGH)
- **This session completed all hardcoded port migrations**
- **But:** Some services still reference ports in non-module files:
  - `caddy.nix` — proxies reference `cfg.port` (already dynamic, good)
  - `gatus-config.nix` — endpoint URLs may still have hardcoded ports
  - `docs/` — various markdown files reference ports for documentation
  - `scripts/` — hardcoded ports in verification/diagnostic scripts
- **Action:** Audit all `.nix`, `.sh`, `.md` files for remaining hardcoded port literals

### 3. Service Health Verification (Priority: HIGH)
- Many verification items from TODO_LIST.md are blocked (need evo-x2 access):
  - Boot time (`systemd-analyze`)
  - SigNoz provision logs (dashboards, rules, Discord channel)
  - Gatus endpoint health
  - Discord alert test
  - BTRFS snapshot freshness
- **Action:** Run `just verify` or `scripts/verify-deployment.sh` on evo-x2 after disk cleanup

### 4. Go Version Pinning (Priority: MEDIUM)
- `file-and-image-renamer` disabled due to Go 1.26.2 vs 1.26.3 mismatch
- nixpkgs-unstable will eventually bump Go
- **Alternative:** Use `buildGo126Module` equivalent or pin `go` input

### 5. Nautilus Integration Testing (Priority: MEDIUM)
- Just switched from Dolphin to Nautilus
- Added `xdg-desktop-portal-gnome` for file picker integration
- Need to verify: file picker in Electron apps, drag-and-drop in Niri, MIME type associations

### 6. Rust Toolchain Completeness (Priority: MEDIUM)
- Just added cargo/rustc/rustfmt/clippy/rust-analyzer
- **Missing on NixOS:** `rustup` (for multi-toolchain management), `cargo-sweep` (already in cleanup scripts but not in user packages)
- **Missing on Darwin:** Entire Rust toolchain (Darwin disk constraint)

### 7. Documentation Sync (Priority: LOW)
- `FEATURES.md` last updated 2026-06-03 — needs update for recent additions (ecapture, Rust toolchain, WebAuthn)
- `TODO_LIST.md` has many completed items not checked off
- `AGENTS.md` is current and well-maintained

### 8. Hermes Manual Setup (Priority: MEDIUM)
- All Nix config is done; only manual sops + SSH key steps remain
- Should be completed to enable OpenRouter fallback for GLM-5.1 rate limits

### 9. BTRFS Snapshot Automation for `/data` (Priority: MEDIUM)
- Root (`@`) has btrbk snapshots
- `/data` is toplevel (subvolid=5) — cannot be snapshotted
- Migration plan exists but not executed

### 10. Pre-Commit / CI Improvements (Priority: LOW)
- Add `statix` + `deadnix` to pre-commit hooks (currently only in flake checks)
- Add port hardcoding detection to CI (grep for `= [0-9]{4,5}` in service modules)

---

## F) Top #25 Things We Should Get Done Next

### 🔥 Critical (Do Now)
| # | Task | Why |
|---|------|-----|
| 1 | **Run `nix-collect-garbage -d` on evo-x2** | 99% disk = cannot deploy, cannot snapshot, crash risk |
| 2 | **Fix monitor365 uncommitted changes** | Blocks ALL SystemNix `just switch` / `nh os boot` |
| 3 | **Deploy current changes to evo-x2** | Port centralization, Nautilus, Rust toolchain, WebAuthn — all ready |
| 4 | **Verify `just switch` succeeds after GC + monitor365 fix** | Full system closure must build |

### High Priority (This Week)
| # | Task | Why |
|---|------|-----|
| 5 | **Run `scripts/verify-deployment.sh` on evo-x2** | Validate all services post-deploy |
| 6 | **Check SigNoz dashboards/rules/Discord alerts** | Session 122 added per-threshold routing — needs verification |
| 7 | **Complete Hermes manual setup** (sops secrets + SSH key) | Enables OpenRouter fallback, prevents GLM-5.1 rate limit stalls |
| 8 | **Audit remaining hardcoded ports** in scripts/docs/gatus | Port centralization must be 100% complete |
| 9 | **Test Nautilus file picker** in Electron/Niri apps | New file manager needs validation |
| 10 | **Enable `file-and-image-renamer`** when nixpkgs Go bumps to 1.26.3 | Feature disabled unnecessarily |
| 11 | **Re-evaluate monitor365 build** — commit or stash WIP audio feature | Prevents future deployment blockers |
| 12 | **Set up automatic Nix GC** (weekly timer or `max-free` in nix.conf) | Prevents 99% disk recurrence |

### Medium Priority (Next 2 Weeks)
| # | Task | Why |
|---|------|-----|
| 13 | **Migrate `/data` to `@data` subvolume** | Enables BTRFS snapshots for /data |
| 14 | **Provision Raspberry Pi 3** for DNS failover | DNS redundancy currently planned-only |
| 15 | **Enable voice-agents** (LiveKit + Whisper) | Module exists, just disabled — test ROCm GPU pipeline |
| 16 | **Add `rustup` to NixOS packages** | Multi-toolchain Rust management |
| 17 | **Update `FEATURES.md`** with ecapture, Rust toolchain, WebAuthn | Documentation drift |
| 18 | **Clean up `TODO_LIST.md`** — check off completed items | Many session 121/122 items still unchecked |
| 19 | **Test WebAuthn hybrid transport** with phone passkey | New feature needs real-world validation |
| 20 | **Add port-hardcoding lint to CI** | Prevent regression of hardcoded ports |
| 21 | **Re-enable AppArmor** when NixOS bug fixed | Security hardening gap |
| 22 | **Add `cargo-sweep` to user packages** (not just cleanup scripts) | Rust dev workflow |

### Lower Priority (Nice to Have)
| # | Task | Why |
|---|------|-----|
| 23 | **Enable Minecraft server** when playing again | Just a config toggle |
| 24 | **Evaluate PhotoMap AI re-enable** | Depends on AI model setup |
| 25 | **Add `just gc` recipe** for one-command disk cleanup | Convenience |

---

## G) Top #1 Question I Cannot Figure Out Myself

### Why does `nix flake check` pass but `nixos-rebuild switch` can still fail due to upstream repo working tree dirt?

**Context:** SystemNix imports monitor365 as a flake input (`git+ssh://git@github.com/LarsArtmann/monitor365`). When that repo has uncommitted changes, `nix build .#monitor365-ui` (from the monitor365 flake) fails because Nix builds from the working tree, not from a clean commit.

**The puzzle:** Nix flakes are supposed to be pure. When SystemNix does `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`, it should be building from locked flake inputs (the lock file pins a specific git rev). But the monitor365 flake input points to a local path or git repo that includes working tree changes.

**What I don't understand:**
1. Is the monitor365 flake input locked to a specific rev in `flake.lock`, or is it resolving to a dirty git tree?
2. If it's locked to a rev, why would uncommitted local changes in the monitor365 repo affect the SystemNix build?
3. If it's NOT locked (e.g., using `path:` or dirty git), should we enforce `flake.lock` purity by requiring clean trees before `nix flake lock --update-input monitor365`?

**Why this matters:** This is the #1 deployment blocker right now. I need to understand the exact mechanism so we can prevent it — either by:
- Enforcing clean upstream repos before lock updates
- Using `narHash` locks that ignore working tree
- Adding a CI check that verifies all flake inputs build from clean trees

**What I've tried:**
- Checked `flake.lock` — monitor365 is pinned to a specific rev
- But the rev might be from a dirty tree (git allows committing with uncommitted files if they're not staged)
- Actually, the issue might be that `nix flake lock --update-input monitor365` updates the lock to the latest commit in the repo, but if the repo is dirty, the build still sees the dirty tree when evaluating locally

**Can you explain:** How exactly does Nix resolve flake inputs when the source repo has uncommitted changes? And what's the recommended pattern to ensure SystemNix always builds from a clean, reproducible upstream state?

---

## Uncommitted Changes Summary (This Session)

| File | Change |
|------|--------|
| `lib/ports.nix` | Removed orphan `twenty-internal = 3000` |
| `modules/nixos/services/dns-blocker.nix` | `statsPort` now uses `ports.dns-blocker-stats` |
| `modules/nixos/services/homepage.nix` | `port` now uses `ports.homepage` |
| `modules/nixos/services/manifest.nix` | `port` now uses `ports.manifest` |
| `modules/nixos/services/minecraft.nix` | `port` now uses `ports.minecraft` |
| `modules/nixos/services/monitor365.nix` | 4 ports now use `ports.*` |
| `modules/nixos/services/multi-wm.nix` | Dolphin → Nautilus |
| `modules/nixos/services/oauth2-proxy.nix` | `port` now uses `ports.oauth2-proxy` |
| `modules/nixos/services/openseo.nix` | `port` now uses `ports.openseo` |
| `modules/nixos/services/photomap.nix` | `port` now uses `ports.photomap` |
| `modules/nixos/services/pocket-id.nix` | 2 ports now use `ports.*` |
| `modules/nixos/services/taskchampion.nix` | `port` now uses `ports.taskchampion` |
| `modules/nixos/services/twenty.nix` | `port` now uses `ports.twenty` |
| `modules/nixos/services/voice-agents.nix` | 3 ports now use `ports.*` |
| `platforms/common/programs/activitywatch.nix` | Port now uses `ports.activitywatch` |
| `platforms/nixos/system/configuration.nix` | xdg portals: added gnome, nautilus file assoc, monitor365 ports |
| `platforms/nixos/users/home.nix` | Added Rust toolchain (cargo, rustc, rustfmt, clippy, rust-analyzer), nautilus desktop entry |

---

## System Metrics

| Metric | Value |
|--------|-------|
| NixOS service modules | 36 |
| Custom packages (pkgs/) | 7 (+ Go overlays) |
| Flake inputs | ~45 |
| Just commands | 90+ |
| Enabled services (evo-x2) | ~30 |
| Disabled services | 5 (file-rename, voice, minecraft, photomap, multi-wm) |
| `just test-fast` | ✅ Passes |
| Root disk (`/`) | 99% full (7.8G free) |
| `/data` disk | 90% full (103G free) |
| `/nix/store` | 90GB |
| Current system closure | 44.7 GiB |
| BTRFS snapshots | Daily, 14d + 4w retention |

---

_Generated by comprehensive codebase audit — all modules, configs, docs, and recent commits analyzed._
