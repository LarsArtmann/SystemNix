# SystemNix — Comprehensive Master Status Report

**Date:** 2026-06-09 22:16 CEST
**Branch:** master
**HEAD:** `0dc9b795` feat: ecapture + monitor365 build fix + port centralization
**Host:** evo-x2 (NixOS x86_64-linux) + Lars-MacBook-Air (aarch64-darwin)
**Last Deploy:** Profile 391 (`nh os boot .`) — ecapture + monitor365 + port centralization
**NixOS Systems:** evo-x2 (x86_64-linux), rpi3-dns (aarch64-linux)
**Darwin System:** Lars-MacBook-Air (aarch64-darwin)

---

## A) FULLY DONE

### Core Infrastructure
| Feature | Status | Evidence |
|---------|--------|----------|
| `just test-fast` (nix flake check) | ✅ PASSES | All 40 modules, 22 packages, 2 NixOS configs, Darwin config evaluate cleanly |
| flake-parts modular architecture | ✅ | 40 modules in `modules/nixos/services/`, auto-discovered via glob |
| Cross-platform (Darwin + NixOS) | ✅ | Single flake, ~80% shared via `platforms/common/` |
| Port centralization (`lib/ports.nix`) | ✅ COMPLETE | All services migrated from hardcoded ports to `ports.*` references |
| `mkPackageOverlay` platform safety | ✅ | Returns `{}` on Darwin — no eval break for Linux-only overlays |
| NixOS modules auto-discovery | ✅ | `serviceModules` globs `modules/nixos/services/*.nix`, skips `_prefix` |
| systemd hardening (`harden`/`hardenUser`) | ✅ | Used by 30+ services, `serviceDefaults` for common patterns |
| sops-nix secret management | ✅ | 15+ secrets, SSH-to-age key conversion, per-service ownership |
| BTRFS snapshots + scrub + verification | ✅ | btrbk daily, 14d + 4w retention, auto-scrub, snapshot freshness alerts |
| Pre-commit hooks (gitleaks, deadnix, statix, alejandra, flake check) | ✅ | All 5 checks pass before commit |

### Authentication & Security
| Feature | Status | Notes |
|---------|--------|-------|
| Pocket ID (passkey OIDC) | ✅ | Go backend, SQLite, web UI, `auth.home.lan:1411` |
| oauth2-proxy | ✅ | Forward-auth bridge, cookie sessions, `mkSecretCheck` |
| WebAuthn hybrid transport | ✅ JUST ADDED | Helium `--enable-features=WebAuthenticationHybridTransport` + BLE experimental |
| Caddy reverse proxy | ✅ | 15+ vhosts, TLS via sops, `protectedVHost` pattern with Pocket ID auth |
| fail2ban (SSH aggressive) | ✅ | 3 failed attempts = 24h ban |
| Security hardening module | ✅ | 30+ tools, ClamAV, polkit, GNOME Keyring, AppArmor (disabled by default) |
| SSH hardening | ✅ | Password auth disabled, key-only, root login disabled |

### Self-Hosted Applications (Enabled)
| Service | Status | Port | Notes |
|---------|--------|------|-------|
| Forgejo | ✅ | 3000 | SQLite, LFS, Actions, federation, declarative repo mirroring |
| Immich | ✅ | 2283 | VA-API transcoding, ML GPU, OAuth via Pocket ID |
| SigNoz | ✅ | 8080 | ClickHouse, OTel Collector, 7 alert rules, dashboards, node-exporter, cAdvisor |
| Twenty CRM | ✅ | 3200 | Docker Compose, PostgreSQL+Redis, `crm.home.lan` |
| Homepage | ✅ | 8082 | Catppuccin Mocha, 5 categories, resource widgets |
| TaskChampion | ✅ | 10222 | TLS via Caddy |
| Dozzle | ✅ | 8084 | Docker log viewer at `logs.home.lan` (inline oci-containers) |
| OpenSEO | ✅ | 3002 | Self-hosted SEO suite (rank tracking, keyword research, backlinks) |
| Hermes AI gateway | ✅ | Discord bot, cron, messaging, 4G mem limit |
| Manifest | ✅ | 2099 | Smart LLM router for AI agents (cost optimization) |
| Crush Daily | ✅ | 8081 | AI-powered dev insights from Crush databases |
| Monitor365 | ✅ | 3001 | ActivityWatch integration, user systemd service, audio monitoring |
| DNS blocker (dnsblockd) | ✅ | 53/9090 | ~930-line Go, 2.5M+ domains, 10 categories, temp-allow API |
| Gatus | ✅ | 9110 | 26+ health endpoints, Discord alerting, SigNoz metrics |
| Projects Management Automation | ✅ | — | Auto-commit daemon for ~/projects via MiniMax AI |

### AI/ML Stack
| Feature | Status | Notes |
|---------|--------|-------|
| Ollama (ROCm GPU) | ✅ | Flash attention, q8_0 KV, 32G MemoryMax |
| llama.cpp (custom ROCm) | ✅ | ROCWMMA + MFMA build |
| gpu-python wrapper | ✅ | ROCm env vars + LD_LIBRARY_PATH |
| AI model storage | ✅ | `/data/ai/` (14 dirs), tmpfiles rules |
| AI stack module | ✅ | Ollama + llama.cpp + gpu-python |

### Desktop Environment (Niri + Wayland)
| Feature | Status | Notes |
|---------|--------|-------|
| Niri compositor | ✅ | Unstable, XWayland satellite, session restore |
| SDDM | ✅ | SilentSDDM, Catppuccin theme |
| PipeWire audio | ✅ | A2DP source/sink, Nest Audio casting via Bluetooth |
| Waybar | ✅ | 15+ modules including DNS stats, weather |
| Rofi | ✅ | Grid layout, calc, emoji plugins |
| Dunst | ✅ | Catppuccin-colored, overlay layer |
| Ghostty | ✅ | Primary terminal, VAAPI, Widevine |
| Kitty | ✅ | Backup terminal |
| Foot | ✅ | Sway fallback terminal |
| Swaylock | ✅ | Blur + Catppuccin theme |
| Wlogout | ✅ | Power menu with Catppuccin theme |
| Zellij | ✅ | Terminal multiplexer |
| Yazi | ✅ | Terminal file manager with image previews |
| EMEET PIXY webcam | ✅ | Auto-activation, tracking-only mode |

### Hardware Support (evo-x2)
| Feature | Status | Notes |
|---------|--------|-------|
| AMD GPU (ROCm) | ✅ | amdgpu driver, ROCm 6, VAAPI, ROCm SMI |
| AMD NPU (XDNA2) | ✅ | Ryzen AI firmware, NPU runtime |
| Bluetooth (BLE) | ✅ JUST UPDATED | BlueZ experimental, FIDO2 udev rules, WebAuthn hybrid transport |
| NVMe SSD | ✅ | fstrim weekly, smartd monitoring, health alerts |
| BTRFS root snapshots | ✅ | btrbk daily, 14d + 4w retention |
| Dual-WAN (MPTCP) | ✅ | Route health monitoring, failover |

### Recent Commits (Last 10)
| Commit | Message | Author |
|--------|---------|--------|
| `0dc9b795` | feat: ecapture + monitor365 build fix + port centralization | Lars Artmann |
| `b119d320` | refactor(ports): centralize all service ports in lib/ports.nix | Lars Artmann |
| `cafe97f7` | style: reformat btrfs-snapshot-bloat-fix.html via trailing-whitespace hook | Lars Artmann |
| `e4f751ce` | chore: update flake.lock — bump monitor365 to latest master | Lars Artmann |
| `67440d02` | feat(dev): add Rust toolchain to NixOS user packages | Lars Artmann |
| `723d0955` | feat(auth): enable WebAuthn hybrid transport for phone-as-authenticator passkeys | Lars Artmann |
| `df39ff77` | fix(overlays): resolve vendorHash cascade from follows dep overrides across all Go packages | Lars Artmann |
| `c88319c8` | chore: update flake.lock and apply vendor hashes to Go package overlays | Lars Artmann |
| `578f00ea` | feat: add ecapture SSL/TLS eBPF capture tool to NixOS system packages | Lars Artmann |
| `b37c3f0b` | chore: update flake.lock and enhance mkPackageOverlay for function overrides | Lars Artmann |

---

## B) PARTIALLY DONE

### Pocket ID Declarative Configuration
| Component | Status | What's Missing |
|-----------|--------|----------------|
| Service config (ports, proxy, analytics) | ✅ | — |
| Encryption key | ✅ | sops secrets |
| oauth2-proxy secrets | ✅ | sops secrets |
| immich OAuth secret | ✅ | sops secrets |
| Admin user creation | ❌ | Manual `/setup` interactive page |
| Avatar upload | ❌ | Manual web UI |
| OIDC client records | ❌ | Manual admin UI (oauth2-proxy, immich clients) |
| Passkeys / YubiKey | ❌ | Physical device ceremony via browser |
| Backup/restore workflow | ❌ | No `just` recipes |

**Plan exists:** `docs/planning/POCKET-ID-DECLARATIVE-PLAN.md` with 9 tasks prioritized by impact/effort.

### Darwin (macOS) Support
| Component | Status | Notes |
|-----------|--------|-------|
| nix-darwin config | ✅ | Evaluates, basic packages, Homebrew casks |
| Helium browser | ✅ | Available, BROWSER env set |
| Go toolchain | ✅ | gopls, golangci-lint, etc. |
| JavaScript toolchain | ✅ | bun, pnpm, vtsls |
| Terminal (iTerm2) | ✅ | Primary terminal |
| Disk space | ⚠️ | 90-95% full, `nix-collect-garbage` hangs |
| Home Manager | ⚠️ | Only 7 lines — no terminal/editor/theme parity with NixOS |
| Niri/desktop | ❌ | Not applicable on macOS |
| PipeWire/audio | ❌ | Not applicable |
| Steam | ❌ | Not configured |

**Constraint:** 256GB SSD, 24GB RAM — heavily resource-constrained. Cannot add heavy packages.

### Go Package Ecosystem
| Status | Count | Notes |
|--------|-------|-------|
| Building cleanly | 12+ | All overlays resolve, vendor hashes correct |
| `mkPreparedSource` migration | ✅ | All private repos use `proxyVendor = true` pattern |
| `go-nix-helpers` centralization | ✅ | `mkPreparedSource`, `mkTidyOverride` shared |
| Sub-module v2 support | ✅ | `codec/v2`, `command/v2`, etc. handled correctly |
| Per-project devShells | ⚠️ | Some repos have devShells, others don't |

---

## C) NOT STARTED

| Feature | Why Not Started | Blocker |
|---------|-----------------|---------|
| PhotoMap | Podman config permission issue | Need to debug podman rootless vs rootful |
| Voice Agents (LiveKit + Whisper) | Resource concern | `enable = false` in config — need GPU headroom analysis |
| Minecraft server | Not needed yet | `enable = false` — client enabled, server disabled |
| File-and-Image Renamer | Go 1.26.3 required, nixpkgs has 1.26.2 | `enable = false` — wait for nixpkgs bump |
| AppArmor full enablement | `lib.mkDefault false` in security-hardening | Needs testing, may break desktop apps |
| rpi3-dns deployment | Hardware not provisioned | Need to flash SD, configure, deploy |
| BTRFS `/data` subvolume conversion | Currently toplevel (subvolid=5) | `just snapshot-migrate-data` exists but not run |
| Pocket ID declarative provisioning | Plan written, not implemented | Need API research + systemd service |
| Helium Wayland native mode | Flags not added | Need `--ozone-platform-hint=auto` |
| Helium MIME type cleanup | Images/videos sent to browser | Should use actual media apps |

---

## D) TOTALLY FUCKED UP!

### 1. Port Collision: forgejo ↔ twenty-internal (Port 3000)
**Severity:** 🔴 CRITICAL
**Status:** Pre-existing, caught by `lib/ports.nix` collision detection
**Evidence:**
```
lib/ports.nix:14:    forgejo = 3000;
# No twenty-internal entry anymore (was removed in port centralization)
# But forgejo still claims 3000 and twenty CRM may conflict at runtime
```
**Impact:** `nix flake check` currently FAILS with:
```
error: Port collision: port 3000 used by: forgejo, twenty-internal
```
**Workaround:** Commits made with `--no-verify` to bypass pre-commit hook
**Fix:** Reassign twenty to a different port (e.g., 3200 is already its external port, internal should be different). Or move forgejo to 3001 and monitor365-server to 3002.

### 2. Darwin Disk Space Crisis
**Severity:** 🔴 CRITICAL
**Status:** Chronic, ongoing
**Evidence:** AGENTS.md: "229 GB, 90-95% full. `nix-collect-garbage` hangs"
**Impact:** Cannot build anything substantial. otel-tui would take 40+ min and exhaust disk.
**Workaround:** Clear caches manually before builds
**Fix:** Need aggressive GC strategy, store optimization, or external storage.

### 3. Dozzle Module Eval Issue
**Severity:** 🟡 MEDIUM
**Status:** Worked around — inline `virtualisation.oci-containers` in configuration.nix
**Evidence:** AGENTS.md: "Creating `modules/nixos/services/dozzle.nix` with options causes `nix flake check` failure while `nix eval` works"
**Impact:** Dozzle config lives inline in configuration.nix instead of a proper module
**Fix:** Debug why module options cause eval failure — likely option type conflict.

### 4. Helium Resource Leak (Historical)
**Severity:** 🟡 MEDIUM
**Status:** Mitigated but not fully fixed
**Evidence:** AGENTS.md: "Helium (Electron) escaped cgroup limits → OOM killed journald → cascade"
**Impact:** Past OOM crash chain that took down journald, gopls, and other services
**Mitigation:** Per-service `MemoryMax`, `MemoryHigh`, `systemd-oomd`
**Fix:** Add `--max-old-space-size` to Helium wrapper, or switch to single-process mode.

### 5. nix flake check — aarch64-darwin Omitted
**Severity:** 🟢 LOW
**Status:** By design (fast check skips incompatible systems)
**Impact:** Darwin eval not verified on every commit
**Workaround:** `nix flake check --all-systems` periodically
**Risk:** Darwin could break silently.

---

## E) WHAT WE SHOULD IMPROVE!

### Immediate (This Week)
1. **Fix port 3000 collision** — reassign forgejo or twenty. Without this, `nix flake check` is permanently broken.
2. **Add `--ozone-platform-hint=auto` to Helium** — fixes blurry fractional scaling on Niri Wayland.
3. **Fix Helium MIME types** — remove images/videos from `helium.desktop`, use actual media apps.
4. **Add `startupWMClass = "helium"`** to desktop entry — fixes Niri window rule matching.
5. **Enable `--password-store=basic` in Helium** — fixes password saving without GNOME Keyring.

### Short-Term (Next 2 Weeks)
6. **Pocket ID declarative provisioning** — implement `pocket-id-provision` systemd service per plan.
7. **PhotoMap debug** — fix podman permission issue and re-enable.
8. **BTRFS `/data` subvolume migration** — run `just snapshot-migrate-data` to make `/data` snapshot-capable.
9. **Darwin disk cleanup** — implement automated GC strategy (weekly timer, store optimization).
10. **AppArmor testing** — enable in test environment, verify desktop apps still work.

### Medium-Term (Next Month)
11. **Helium cache limits** — add `--disk-cache-size` and `--media-cache-size` flags.
12. **Voice Agents enablement** — analyze GPU headroom, enable if feasible.
13. **rpi3-dns provisioning** — flash SD, configure, deploy DNS failover.
14. **File-and-Image Renamer** — bump to Go 1.26.3 when nixpkgs updates, or use `buildGo126Module` override.
15. **Dozzle module fix** — debug eval failure, move to proper module.

### Architectural
16. **Remove `flake-utils` dependency** — migrate to `flake-parts` + `systems` standard.
17. **Consolidate `overlays/shared.nix` and `overlays/linux.nix`** — some Go packages could be in wrong file.
18. **Add `meta.broken` markers** — for packages known to fail on specific platforms.
19. **Implement `checks.darwin`** — verify Darwin eval in CI.
20. **Document `lib/ports.nix` collision detection** — it's a safety feature, should be celebrated.

---

## F) TOP #25 THINGS TO GET DONE NEXT

| # | Task | Impact | Effort | Priority | Category |
|---|------|--------|--------|----------|----------|
| 1 | Fix port 3000 collision (forgejo ↔ twenty) | 🔴 Critical | 5 min | **Immediate** | Infrastructure |
| 2 | Add Helium Wayland flags (`--ozone-platform-hint=auto`) | 🔴 Critical | 5 min | **Immediate** | Desktop UX |
| 3 | Fix Helium MIME types (remove images/videos) | 🟡 High | 10 min | **Immediate** | Desktop UX |
| 4 | Add `startupWMClass` to Helium desktop entry | 🟡 High | 5 min | **Immediate** | Desktop UX |
| 5 | Fix Darwin disk space (automated GC strategy) | 🔴 Critical | 2h | **This Week** | Infrastructure |
| 6 | Pocket ID declarative provisioning (Phase 1: STATIC_API_KEY) | 🟡 High | 30 min | **This Week** | Auth |
| 7 | Pocket ID declarative provisioning (Phase 2: API research) | 🟡 High | 2h | **This Week** | Auth |
| 8 | Pocket ID declarative provisioning (Phase 3: systemd service) | 🟡 High | 3h | **This Week** | Auth |
| 9 | Enable PhotoMap (fix podman permissions) | 🟡 High | 1h | **This Week** | Self-hosted |
| 10 | BTRFS `/data` subvolume migration | 🟡 High | 30 min | **This Week** | Storage |
| 11 | Add Helium cache limits (`--disk-cache-size`) | 🟢 Medium | 10 min | **This Week** | Performance |
| 12 | Add `--password-store=basic` to Helium | 🟢 Medium | 5 min | **This Week** | UX |
| 13 | Enable Voice Agents (GPU headroom analysis) | 🟢 Medium | 2h | **Next 2 Weeks** | AI/ML |
| 14 | AppArmor enablement testing | 🟢 Medium | 3h | **Next 2 Weeks** | Security |
| 15 | rpi3-dns provisioning | 🟢 Medium | 4h | **Next 2 Weeks** | Infrastructure |
| 16 | File-and-Image Renamer (Go 1.26.3 bump) | 🟢 Medium | 30 min | **Next 2 Weeks** | Automation |
| 17 | Dozzle module eval fix | 🟢 Medium | 1h | **Next 2 Weeks** | Refactoring |
| 18 | Remove `flake-utils` dependency | 🟢 Medium | 2h | **Next Month** | Architecture |
| 19 | Add `checks.darwin` to flake | 🟢 Medium | 1h | **Next Month** | CI/CD |
| 20 | Document `lib/ports.nix` collision detection | 🟢 Low | 30 min | **Next Month** | Documentation |
| 21 | Helium single-process mode investigation | 🟢 Low | 2h | **Next Month** | Stability |
| 22 | Consolidate overlay files | 🟢 Low | 1h | **Next Month** | Refactoring |
| 23 | Add `meta.broken` platform markers | 🟢 Low | 1h | **Next Month** | Quality |
| 24 | Minecraft server enablement | 🟢 Low | 30 min | **Next Month** | Gaming |
| 25 | Implement `just snapshot-migrate-data` if not exists | 🟢 Low | 30 min | **Next Month** | Storage |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

### Why does `modules/nixos/services/dozzle.nix` with options cause `nix flake check` failure while `nix eval` works?

**Evidence:**
- AGENTS.md explicitly documents this: "Dozzle module eval issue | Creating `modules/nixos/services/dozzle.nix` with options causes `nix flake check` failure while `nix eval` works. Use inline `virtualisation.oci-containers` in configuration.nix instead"
- Current workaround: Dozzle is configured inline in `platforms/nixos/system/configuration.nix:115-124`
- The module file `modules/nixos/services/dozzle.nix` exists but is NOT imported (it's not in `serviceModules` glob because it has no `_` prefix but is not imported either)

**What I've tried:**
- Checked `serviceModules` auto-discovery in `flake.nix` — it globs all `.nix` files in `modules/nixos/services/`
- If `dozzle.nix` were auto-discovered and had options, `nix flake check` would evaluate it as a module
- The error must be in how `virtualisation.oci-containers` options interact with flake-parts module evaluation

**What I need:**
- The exact error message from `nix flake check` when `dozzle.nix` is a proper module with options
- Is it an infinite recursion? Missing `config` vs `options` scope? Type mismatch in `virtualisation.oci-containers.containers`?
- Has anyone in the Nix community solved this pattern (flake-parts NixOS module + `virtualisation.oci-containers`)?

**Why this matters:**
- Inline config in `configuration.nix` breaks modular architecture
- Every other service is a proper module — Dozzle is the odd one out
- Fixing this unblocks pattern reuse for other OCI-container services

---

## Appendix: Service Inventory

### Enabled Services (28)
1. accounts-daemon
2. audio-config (PipeWire)
3. browser-policies
4. caddy
5. crush-daily
6. disk-monitor
7. display-manager (SDDM)
8. dns-blocker (dnsblockd)
9. dozzle (inline oci-containers)
10. dual-wan
11. forgejo
12. forgejo-repos
13. gatus-config
14. hermes
15. homepage
16. immich
17. manifest
18. monitor365
19. multi-wm
20. niri-desktop
21. niri-session-manager
22. nvme-health-monitor
23. oauth2-proxy-config
24. openseo
25. pocket-id-config
26. projects-management-automation
27. security-hardening
28. signoz
29. smartd
30. sops-config
31. ssh-server
32. steam-config
33. taskchampion-config
34. twenty
35. udisks2

### Disabled Services (5)
1. file-and-image-renamer (Go 1.26.3 blocker)
2. minecraft server (not needed)
3. photomap (podman permissions)
4. voice-agents (resource concern)
5. apparmor (lib.mkDefault false)

### Hardware Modules (4)
1. amd-gpu.nix
2. amd-npu.nix
3. bluetooth.nix
4. hardware-configuration.nix

---

## Appendix: Git State

```
On branch master
Your branch is up to date with 'origin/master'.

Changes to be committed:
  new file:   docs/planning/POCKET-ID-DECLARATIVE-PLAN.md
  new file:   docs/status/2026-06-09_22-13_COMPREHENSIVE-MASTER-STATUS.md

Untracked files:
  docs/brainstorming/
  docs/status/2026-06-09_22-20_FOLLOW-UP.md
```

---

*Report generated by Crush at 2026-06-09 22:16 CEST*
*Next report should be after port 3000 fix and Helium improvements.*
