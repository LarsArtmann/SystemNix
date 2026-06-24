# SystemNix Comprehensive Master Status Report

**Date:** 2026-06-09 22:16 CEST
**Branch:** master
**Ahead of origin:** 2 commits (`aa671dd0` overview service, `f975c41a` overview docs)
**Working tree:** clean
**Session context:** Post-ecapture/monitor365 build fix, post-portal-nautilus migration, post-overview service integration

---

## a) FULLY DONE

### Core Infrastructure

| Feature | Status | Evidence |
|---------|--------|----------|
| Cross-platform flake (Darwin + NixOS) | ✅ | `flake.nix` — 2 systems, 80% shared |
| flake-parts architecture | ✅ | 36 service modules auto-discovered |
| Port centralization | ✅ | `lib/ports.nix` — all 30+ ports centralized with collision detection (`lib/default.nix:96-107`) |
| Shared overlays | ✅ | `overlays/shared.nix` — 7 cross-platform overlays |
| Linux-only overlays | ✅ | `overlays/linux.nix` — 12 overlays |
| Custom packages (pkgs/) | ✅ | 16 packages: Go, Rust, Python, Node.js |
| treefmt + alejandra | ✅ | `formatter.x86_64-linux` / `aarch64-darwin` |
| Flake checks (statix, deadnix, boot, dns-blocking) | ✅ | `checks.x86_64-linux.{statix,deadnix,boot,dns-blocking}` |
| NixOS VM tests | ✅ | `boot` + `dns-blocking` tests pass |

### NixOS Services — Production Ready

| Service | Module | Status | Notes |
|---------|--------|--------|-------|
| Caddy reverse proxy | `caddy.nix` | ✅ | TLS via sops, forward-auth, 12+ vhosts, metrics |
| Pocket ID (OIDC) | `pocket-id.nix` | ✅ | Passkey-only, SQLite, Go backend |
| oauth2-proxy | `oauth2-proxy.nix` | ✅ | Cookie sessions, Caddy integration |
| Forgejo (Git forge) | `forgejo.nix` | ✅ | SQLite, LFS, Actions runner, GitHub mirrors, federation |
| Forgejo repos (declarative) | `forgejo-repos.nix` | ✅ | Auto-sync + push mirrors, hardened oneshot |
| Immich | `immich.nix` | ✅ | PostgreSQL + Redis + ML, VA-API transcoding, OAuth |
| Twenty CRM | `twenty.nix` | ✅ | Docker Compose, PostgreSQL + Redis, daily backups |
| Homepage Dashboard | `homepage.nix` | ✅ | Catppuccin theme, 5 categories, resource widgets |
| SigNoz | `signoz.nix` | ✅ | ClickHouse, OTel Collector, 7 alert rules, dashboards |
| TaskChampion | `taskchampion.nix` | ✅ | Port 10222, TLS via Caddy, 100 snapshots |
| OpenSEO | `openseo.nix` | ✅ | Docker service, Caddy vhost |
| Manifest (LLM router) | `manifest.nix` | ✅ | Docker, Caddy, sops secrets |
| Gatus health checks | `gatus-config.nix` | ✅ | 15+ endpoints, webhook alerts, TLS cert checks |
| DNS blocker (dnsblockd) | `dns-blocker.nix` | ✅ | 2.5M+ domains, 3 upstream resolvers, block page |
| Hermes AI gateway | `hermes.nix` | ✅ | Discord bot, cron, 4G MemoryMax, USR1 reload |
| Crush Daily | `crush-daily.nix` | ✅ | AI insights, sops env template |
| Monitor365 | `monitor365.nix` | ✅ | Device monitoring, ActivityWatch integration |
| Overview dashboard | `overview` (inline) | ✅ | Git repo discovery, stats/activity (2 commits ahead) |
| File & Image Renamer | `file-and-image-renamer.nix` | ✅ | Module exists, `enable = false` in config |
| Dozzle (Docker logs) | inline `configuration.nix` | ✅ | `logs.home.lan`, OCI container |
| AI model storage | `ai-models.nix` | ✅ | `/data/ai/` tree, tmpfiles rules |
| Ollama (LLM inference) | `ai-stack.nix` | ✅ | ROCm GPU, flash attention, 32G MemoryMax |
| llama.cpp | `ai-stack.nix` | ✅ | Custom ROCm build with ROCWMMA + MFMA |
| gpu-python | `ai-stack.nix` | ✅ | ROCm env vars for GPU Python |

### Desktop Environment

| Feature | Status | Evidence |
|---------|--------|----------|
| Niri compositor | ✅ | `niri-config.nix` + `niri-wrapped.nix`, XWayland satellite |
| SDDM (SilentSDDM) | ✅ | `display-manager.nix`, Catppuccin theme |
| Waybar | ✅ | 15+ modules, DNS stats, weather, custom scripts |
| Rofi | ✅ | Grid launcher, calc, emoji, clipboard history |
| Swaylock | ✅ | Blur + Catppuccin theme |
| Ghostty (primary terminal) | ✅ | `home.nix`, Catppuccin Mocha, 0.85 opacity |
| Kitty (backup terminal) | ✅ | `home.nix` |
| Foot (Sway fallback) | ✅ | `home.nix` |
| PipeWire audio | ✅ | ALSA + PulseAudio + JACK compat, rtkit |
| Yazi file manager | ✅ | Terminal, Rust-based, image previews, Zed integration |
| Nautilus (GUI file manager) | ✅ | Replaced Dolphin, default for `inode/directory` |
| xdg-desktop-portal-gnome | ✅ | File picker, dark mode, `After=niri.service` |
| Theme centralization | ✅ | `theme.nix` — 26 colors, migrated 164 hardcoded hex values |

### Storage & Maintenance

| Feature | Status | Evidence |
|---------|--------|----------|
| BTRFS root snapshots | ✅ | `snapshots.nix`, btrbk daily, 14d + 4w retention |
| BTRFS cache subvolumes | ✅ | `@cache-home`, `@go`, `@npm`, `@cargo` |
| Snapshot freshness check | ✅ | `btrfs-verify-snapshots` timer |
| Auto-scrub | ✅ | Monthly BTRFS scrub |
| fstrim | ✅ | Weekly SSD trim |
| Docker auto-prune | ✅ | Weekly, `systemd.timer` |
| Stale LSP cleanup | ✅ | Daily, kills gopls/vtsls/rust-analyzer/lua-ls >24h |
| Disk growth check | ✅ | Daily, alerts if `/data` grows >5G/24h |

### Security

| Feature | Status | Evidence |
|---------|--------|----------|
| fail2ban (SSH aggressive) | ✅ | `security-hardening.nix` |
| ClamAV | ✅ | `security-hardening.nix` |
| polkit | ✅ | `security-hardening.nix` |
| GNOME Keyring | ✅ | `security-hardening.nix` |
| SOPS secrets (age/SSH) | ✅ | 4 sops files, per-service ownership, restartUnits |
| SSH hardening | ✅ | `platforms/nixos/system/ssh-banner` |
| 30+ security tools | ✅ | `security-hardening.nix` |

### Auth Stack

| Feature | Status | Evidence |
|---------|--------|----------|
| Pocket ID passkey-only | ✅ | WebAuthn hybrid transport enabled |
| oauth2-proxy cookie sessions | ✅ | `cookie_secret` via sops |
| Caddy forward-auth | ✅ | `protectedVHost` helper |
| Helium browser policies | ✅ | YouTube Shorts Blocker + OneTab |

### Build & Tooling

| Feature | Status | Evidence |
|---------|--------|----------|
| `just test-fast` | ✅ | Syntax validation passes |
| `just test` | ✅ | Full build passes (1m56s) |
| `just switch` | ✅ | Auto-detects platform, auto-snapshots on NixOS |
| `just verify` | ✅ | `scripts/verify-deployment.sh` over SSH |
| mkPackageOverlay | ✅ | Platform-safe overlay helper |
| mkPreparedSource | ✅ | Private Go dep injection, v2 sub-modules |
| Go flake-parts template | ✅ | `templates/go-flake-parts/flake.nix` |

### External Repo Standardization

| Repo | Status |
|------|--------|
| go-auto-upgrade | ✅ SSH URLs, no `path:` inputs |
| crush-daily | ✅ mkPackageOverlay |
| discordsync | ✅ mkPackageOverlay |
| project-meta | ✅ mkPackageOverlay |
| art-dupl | ✅ mkPackageOverlay |
| file-and-image-renamer | ✅ mkPackageOverlay |
| buildflow | ✅ mkPackageOverlay |
| todo-list-ai | ✅ mkPackageOverlay |
| library-policy | ✅ mkPackageOverlay |
| mr-sync | ✅ mkPackageOverlay |
| hierarchical-errors | ✅ mkPackageOverlay |
| govalid | ✅ mkPackageOverlay |
| jscpd | ✅ mkPackageOverlay |

---

## b) PARTIALLY DONE

| Feature | Gap | Evidence |
|---------|-----|----------|
| **Pocket ID declarative provisioning** | Admin user + OIDC clients require manual web UI setup. No systemd provision service exists yet. | `docs/planning/POCKET-ID-DECLARATIVE-PLAN.md` written, zero code |
| **Hermes OpenAI fallback** | `openai_api_key` sops placeholder exists but key not added to `platforms/nixos/secrets/hermes.yaml`. SSH deploy key not installed. | `TODO_LIST.md:13`, `sops.nix:107` |
| **BTRFS `/data` snapshotting** | `/data` is BTRFS toplevel (subvolid=5), NOT snapshotted. Only `@` root is snapshotted. | `AGENTS.md` gotcha, migration plan exists but disk space blocks execution |
| **Darwin Home Manager** | Only 7 effective lines (Zed, shells, zellij, yazi, xdg). No Rust toolchain, no Niri, no PipeWire. Intentionally minimal. | `platforms/darwin/home.nix` |
| **XDG portal race conditions** | `After=niri.service` mitigates but does not eliminate race during `nh os switch`. | `configuration.nix:52-62` |
| **Dozzle module** | Proper `modules/nixos/services/dozzle.nix` exists but breaks `nix flake check`. Workaround: inline `configuration.nix:121-130`. | `AGENTS.md` gotcha |
| **SigNoz Discord webhook** | Webhook URL loaded from sops but never tested. Alert channel routing configured but untested. | `TODO_LIST.md:32` |
| **Gatus endpoint verification** | Endpoints configured but runtime health not verified post-deploy. | `TODO_LIST.md:35` |
| **ecapture runtime test** | Added to system packages but not actually tested on evo-x2. | `docs/cybersecurity-tools-evo-x2.md` |
| **nix-colors migration** | 164 hardcoded hex values migrated, but some edge cases (HTML templates, inline CSS) may remain. | Session 121 |

---

## c) NOT STARTED

| Feature | Evidence |
|---------|----------|
| **discordsync service activation** | Module exists (`modules/nixos/services/discordsync.nix`), flake input exists, sops template exists in `sops.nix:207-215`. **NOT enabled** in `configuration.nix`. No `platforms/nixos/secrets/discordsync.yaml` file exists. |
| **PhotoMap AI** | `configuration.nix:172` — explicitly commented out: `# photomap.enable = true;` |
| **Voice Agents (LiveKit + Whisper)** | `configuration.nix:249` — `enable = false` |
| **Minecraft server** | `configuration.nix:273` — `enable = false` (client config enabled, server disabled) |
| **rpi3-dns provisioning** | `nixosConfigurations.rpi3-dns` defined, hardware not acquired, no SD image built |
| **Pocket ID declarative provisioning implementation** | Plan exists, zero code. Manual steps still required for every rebuild. |
| **Automatic Nix GC timer** | `nix.settings.auto-optimise-store` exists but no automatic `nix-collect-garbage` timer. |
| **Helium Wayland flags** | `--ozone-platform-hint=auto` not set, may cause blurry fractional scaling. |
| **AppArmor** | Disabled in `security-hardening.nix` due to NixOS bug #483085. |
| **auditd** | Disabled in `security-hardening.nix` due to NixOS bug #483085. |

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Details |
|-------|----------|---------|
| **evo-x2 disk space — CRITICAL** | 🔥🔥🔥 | Root `/` is ~99% full (historically reported 492G/512G used). Blocks `nixos-rebuild switch`, snapshot creation, and risks system instability. `/data` at ~90% (920G/1TB). |
| **Darwin disk space — CRITICAL** | 🔥🔥 | 256GB SSD at 90-95%. `nix-collect-garbage` hangs. Cannot build substantial packages. Prevents Darwin parity work. |
| **Dozzle module eval failure** | 🔥 | `modules/nixos/services/dozzle.nix` causes `nix flake check` failure. Forced to use inline `configuration.nix` workaround. Root cause unknown — `nix eval` works but `nix flake check` fails. |
| **sops-install-secrets activation failure** | 🔥 | `sops-install-secrets` fails with `user 'discordsync': user: unknown user discordsync` during `nh os test`. This is a pre-existing issue from the discordsync module being present but not fully wired (no user creation). |
| **Jan llama-server respawn** | 🔥 | Spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service — no cgroup limits. Causes memory pressure. |
| **Stale LSP processes (historical)** | 🔥 | gopls/vtsls/rust-analyzer eating ~7.4Gi RSS. Mitigated by daily cleanup timer but root cause (LSP client not exiting) not fixed. |
| **OOM crash chain (historical)** | 🔥 | Helium escaped cgroup → OOM killed journald → cascade crash. Mitigated by `MemoryHigh`, `MemoryMax`, `systemd-oomd` but fundamental cgroup isolation gaps remain. |

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (Critical — This Week)

1. **Run `nix-collect-garbage -d` on evo-x2** — 99% disk is a deployment blocker. Consider `nix.settings.auto-optimise-store = true` if not already enabled.
2. **Fix or fully remove discordsync** — Either add `users.users.discordsync`, create `platforms/nixos/secrets/discordsync.yaml`, and enable the service; OR delete the module, overlay, flake input, and sops references. Dead code causes `sops-install-secrets` activation failures.
3. **Fix Dozzle module eval** — Debug why `modules/nixos/services/dozzle.nix` breaks `nix flake check` and migrate inline config to the module.
4. **Enable `file-and-image-renamer`** — `enable = false` since Go 1.26.2 vs 1.26.3 mismatch. Pin `fantasy` version or use nixpkgs Go directly.

### Short-Term (High — Next 2 Weeks)

5. **Migrate `/data` to `@data` subvolume** — `/data` has zero snapshot protection. Run migration plan when disk space allows.
6. **Add NixOS service startup tests** — Only 2 VM tests exist (`boot`, `dns-blocking`). Add tests for Caddy, Pocket ID, oauth2-proxy, and Forgejo.
7. **Implement Pocket ID declarative provisioning** — Convert `docs/planning/POCKET-ID-DECLARATIVE-PLAN.md` into a systemd oneshot service.
8. **Hermes manual steps** — Add `openai_api_key` to sops secrets, install SSH deploy key, verify cron recovery.
9. **Helium Wayland + password store flags** — Add `--ozone-platform-hint=auto` and `--password-store=basic`.
10. **SigNoz / Gatus verification** — Run `scripts/verify-deployment.sh` on evo-x2 and fix any broken endpoints.
11. **Add port-hardcoding lint to CI** — Grep for `\d{4,5}` in service modules to prevent regression.

### Medium-Term (Next Month)

12. **Voice Agents** — Analyze GPU headroom and enable if feasible (currently `enable = false`).
13. **PhotoMap** — Evaluate if CLIP embedding visualization is still needed; either enable or remove.
14. **Minecraft server** — Either provision server or remove module.
15. **Darwin parity** — Add Rust toolchain, improve Home Manager coverage. Disk constraint is the blocker.
16. **AppArmor/auditd** — Re-enable once NixOS bug #483085 is fixed.
17. **Jan llama-server cgroup** — Investigate if Jan can be wrapped in a systemd user service with `MemoryMax`.
18. **rpi3-dns** — Acquire hardware, build SD image, provision DNS failover cluster.
19. **ecapture runtime test** — Verify eBPF capture works on evo-x2 kernel.
20. **Monitor365 UI deploy** — After build fix, verify `monitor365-ui` + `monitor365-server` deploy correctly via SystemNix.

---

## f) Top #25 Things We Should Get Done Next

| # | Task | Priority | Effort | Blocker |
|---|------|----------|--------|---------|
| 1 | Run `nix-collect-garbage -d` on evo-x2 | 🔥 Critical | 5 min | None |
| 2 | Fix or delete discordsync (resolve sops activation failure) | 🔥 Critical | 15 min | None |
| 3 | Fix Dozzle module eval and migrate inline config | 🔥 Critical | 30 min | None |
| 4 | Enable `file-and-image-renamer` | 🔥 High | 15 min | Go version mismatch |
| 5 | Verify post-deploy with `scripts/verify-deployment.sh` | 🔥 High | 10 min | Disk space (#1) |
| 6 | Add `openai_api_key` to sops + install Hermes SSH key | High | 15 min | Manual sops step |
| 7 | Migrate `/data` to `@data` BTRFS subvolume | High | 30 min | Disk space (#1) |
| 8 | Add NixOS service startup VM tests (Caddy, Pocket ID, Forgejo) | High | 2h | None |
| 9 | Implement Pocket ID declarative provisioning service | High | 4h | None |
| 10 | Helium `--ozone-platform-hint=auto` + `--password-store=basic` | High | 10 min | None |
| 11 | Test SigNoz Discord webhook + alert channel routing | High | 15 min | None |
| 12 | Test Gatus endpoints post-deploy | High | 10 min | None |
| 13 | Add automatic Nix GC weekly timer | High | 20 min | None |
| 14 | Push 2 unpushed commits (overview service) to origin | Medium | 1 min | None |
| 15 | ecapture runtime test on evo-x2 | Medium | 10 min | None |
| 16 | Monitor365 full SystemNix integration test | Medium | 30 min | None |
| 17 | Voice Agents GPU headroom analysis + enable | Medium | 1h | GPU budget |
| 18 | PhotoMap — enable or remove | Medium | 10 min | Decision needed |
| 19 | Minecraft server — enable or remove | Medium | 10 min | Decision needed |
| 20 | Darwin Rust toolchain + Home Manager expansion | Medium | 1h | Darwin disk |
| 21 | Port-hardcoding lint in CI | Medium | 30 min | None |
| 22 | Jan llama-server cgroup wrapping | Medium | 2h | Jan architecture |
| 23 | Re-enable AppArmor when NixOS bug fixed | Low | 10 min | Upstream bug |
| 24 | rpi3-dns hardware provisioning | Low | 4h | Hardware acquisition |
| 25 | Complete nix-colors migration (edge cases) | Low | 1h | None |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why does `modules/nixos/services/dozzle.nix` break `nix flake check` while `nix eval` succeeds?**

- The module defines standard `options` + `config` with `virtualisation.oci-containers.containers.dozzle`.
- `nix eval` of the NixOS configuration succeeds — the module content is valid.
- `nix flake check` fails with an eval error (exact error not captured in current docs).
- The workaround is to configure Dozzle inline in `platforms/nixos/system/configuration.nix:121-130` instead of using the module.
- **What I need:** Run `nix flake check` with the Dozzle module re-enabled and capture the exact error trace. Then determine if the issue is:
  - A missing `imports` in flake-parts module registration?
  - A NixOS option type conflict with `virtualisation.oci-containers`?
  - A flake-parts module argument mismatch (e.g., `config` vs `options` scoping)?
  - Something else entirely?

This is the single most annoying piece of technical debt because it forces inline configuration for an otherwise well-structured service.

---

## Appendix: Recent Session History

| Session | Date | Key Changes |
|---------|------|-------------|
| 127 | 2026-06-09 | ecapture added, monitor365 build fix (9 root causes), audio/mic monitoring feature |
| 126 | 2026-06-09 | vendorHash cascade fix for `follows` dep overrides, SigNoz + Hermes version bumps |
| 125 | 2026-06-09 | Go migration completion audit, nixpkgs 26.11 buildGoModule migration |
| 124 | 2026-06-08 | Cross-ecosystem flake fix sprint |
| 123 | 2026-06-08 | Post-execution comprehensive status |
| 122 | 2026-06-08 | TODO completion sprint, nix-colors migration |
| 121 | 2026-06-08 | Color migration, SigNoz routing, Darwin parity, `just status` |
| 120 | 2026-06-08 | Dedupe + port centralization sprint |
| 119 | 2026-06-05 | Overlay cleanup, flake lock build fixes |
| 118 | 2026-06-03 | Code cleanup sprint |

## Appendix: Build Health

| Check | Status | Notes |
|-------|--------|-------|
| `just test-fast` | ✅ Pass | Syntax validation |
| `just test` | ✅ Pass | Full build (1m56s) |
| `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` | ⚠️ Activation test fails | `sops-install-secrets: user 'discordsync': unknown user` — pre-existing |
| Darwin eval | ✅ Pass | `nix flake check --all-systems` would fail on aarch64-darwin app `deploy` due to systemd |
| monitor365-ui | ✅ Pass | Fixed in session 127 |
| monitor365-server | ✅ Pass | Fixed in session 127 |
