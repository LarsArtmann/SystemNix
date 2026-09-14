# Status Report: 2026-03-30 17:21

**Session Focus:** Display Manager Migration (SDDM → greetd/ReGreet)
**Host:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395)
**Platform:** NixOS 26.05 (unstable)

---

## A. FULLY DONE ✅

### 1. Display Manager Migration: SDDM → greetd + ReGreet

- **Research**: Evaluated 7 display manager options (GDM, SDDM, Ly, tuigreet, regreet, greetd bare, UWSM-only)
- **Selection**: greetd + ReGreet (GTK4-native, Wayland-first, CSS-themable, Rust-based)
- **Implementation**: Complete replacement of SDDM in `display-manager.nix`
- **Theming**: Full Catppuccin Mocha CSS theme (235 lines) with Lavender accents
- **Build verification**: `nix build` and `just test-fast` both pass
- **Commit**: `9530c05` — committed and pushed

### 2. DNS Blocker Service Fix

- Fixed dnsblockd systemd capabilities (CAP_NET_BIND_SERVICE, AmbientCapabilities)
- Added ExecStopPost for IP cleanup
- Commit: `9530c05`

### 3. Project Infrastructure

- 120+ status reports tracked in `docs/status/`
- 90+ justfile recipes
- 16 flake inputs
- 0 broken imports across 94 `.nix` files
- 10 flake-parts dendritic service modules
- 7 custom packages/overlays

### 4. Deployment Scripts for evo-x2

- `deploy-evo-x2-local.sh` — comprehensive deployment with lock cleanup
- `deploy-evo-x2.sh` — simple deployment wrapper

---

## B. PARTIALLY DONE 🔧

### 1. ReGreet Display Manager — Awaiting Live Deploy

- **Config complete**: NixOS config builds successfully
- **NOT YET APPLIED**: Needs `sudo nixos-rebuild switch --flake .#evo-x2` on the actual machine
- **Risk**: Regreet on cage may have HiDPI scaling issues (4K TV output)
- **Verification needed**: Login flow, session selection, theme rendering on actual hardware

### 2. Hyprland 0.54 Migration

- Core config migrated, builds fine
- **3 plugins disabled**: hy3, hyprsplit, hyprwinwrap (incompatible with 0.54 API)
- Audio still uses `pactl` instead of `wpctl`

### 3. Security Hardening

- AppArmor, fail2ban, ClamAV, polkit, dbus-broker all enabled
- **auditd disabled** — blocked by NixOS bug #483085
- **Audit kernel module disabled** — AppArmor conflicts

### 4. AMD NPU Support

- Module written (`amd-npu.nix`) for XDNA2 50 TOPS NPU
- **Disabled** — requires kernel 6.14+ (currently on 6.12.x)

---

## C. NOT STARTED 📋

### High Priority

1. **ReGreet live deployment and testing** on evo-x2
2. **Immich Smart Search / Face Detection re-index** after config import
3. **GPU-accelerated ML for Immich** (ROCm + Docker Compose)
4. **Grafana alerting rules** — dashboards exist but no alerts
5. **CI/CD pipeline** — no automated testing or deployment
6. **Offsite backup strategy** — local backups only

### Architecture

7. **Ghost Systems type safety** — Types.nix, State.nix, Validation.nix exist but 0/14 tasks completed, not imported anywhere
8. **55 desktop improvement items** — tracked but 0 completed
9. **NixOS module documentation** — modules lack structured docs

### Quality

10. **docs/STATUS.md stale** — last updated 2025-12-27
11. **DNS blocklist hash pinning** — fragile, breaks on upstream change
12. **PhotoMap `latest` tag** — non-reproducible container image

---

## D. TOTALLY FUCKED UP 💥

### Nothing critically broken right now.

**Near-misses this session:**

- `regreet.css` file created but not `git add`-ed before build → Nix flakes couldn't find it (path doesn't exist in store) → Fixed by staging file
- `just test` showed "Could not acquire lock" → Not a build failure, just can't apply config from non-NixOS host → Build itself succeeded

**Ongoing pain points:**

- **Immich ML CPU-only**: Running machine learning on CPU instead of GPU. Documented in `2026-03-30_14-25_IMMICH-AI-MODEL-OPTIMIZATION.md` but not resolved.
- **Plugin ecosystem lag**: Hyprland 0.54 broke 3 plugins with no timeline for fixes.

---

## E. WHAT WE SHOULD IMPROVE 📈

### Critical (Do Next)

1. **Deploy and verify ReGreet** — config means nothing until it runs on hardware
2. **HiDPI testing** — 4K TV output may need cage/regreet scaling adjustments
3. **Regreet background image** — Currently solid color, could add wallpaper support
4. **Fallback greeter** — Add tuigreet as emergency fallback in greetd config

### Architecture Improvements

5. **Activate Ghost Systems** — Types.nix etc. exist but aren't wired. Delete or integrate.
6. **Secret management** — sops-nix is an input but underutilized
7. **Module tests** — No automated testing beyond `nix flake check`
8. **Cross-platform parity audit** — Darwin and NixOS configs may have drifted

### Quality of Life

9. **Regreet autologin option** — Could add `initial_session` for faster development iteration
10. **Consolidate Catppuccin colors** — Colors are hardcoded in 8+ files; should centralize
11. **Monitoring alerts** — Netdata/ntopng/Grafana running but no proactive notifications
12. **Documentation freshness** — 120+ status reports but main docs stale

---

## F. TOP 25 THINGS TO DO NEXT 🎯

| #  | Task                                                    | Priority | Effort | Impact                                                |
| -- | ------------------------------------------------------- | -------- | ------ | ----------------------------------------------------- |
| 1  | Deploy ReGreet on evo-x2 and verify login flow          | P0       | 1h     | Critical — no display manager until deployed          |
| 2  | Test HiDPI scaling on 4K TV output                      | P0       | 30m    | Visual — broken scaling = unusable                    |
| 3  | Add regreet background wallpaper support                | P1       | 2h     | Aesthetic — custom wallpaper on login                 |
| 4  | Wire tuigreet as fallback greeter                       | P1       | 30m    | Safety — if regreet breaks, still can login           |
| 5  | Immich GPU acceleration (ROCm)                          | P1       | 4h     | Performance — ML on GPU vs CPU                        |
| 6  | Immich Smart Search re-index                            | P1       | 2h     | Feature — AI search across photo library              |
| 7  | Centralize Catppuccin color palette                     | P1       | 3h     | Maintenance — 8+ files with hardcoded colors          |
| 8  | Activate Ghost Systems type safety or remove it         | P2       | 8h     | Architecture — dead code vs. active validation        |
| 9  | Grafana alerting rules                                  | P2       | 3h     | Operations — proactive incident detection             |
| 10 | CI/CD pipeline (GitHub Actions)                         | P2       | 4h     | Quality — automated nix flake check on push           |
| 11 | NPU activation (check kernel 6.14 availability)         | P2       | 1h     | Hardware — unlock 50 TOPS AI accelerator              |
| 12 | Fix Hyprland audio: pactl → wpctl                       | P2       | 30m    | Consistency — wpctl is the PipeWire native tool       |
| 13 | Regreet autologin for dev iteration                     | P2       | 15m    | DX — skip login during active development             |
| 14 | Update docs/STATUS.md                                   | P2       | 1h     | Documentation — main status page 3 months stale       |
| 15 | Offsite backup strategy                                 | P2       | 4h     | Safety — local-only backups = single point of failure |
| 16 | Pin PhotoMap container image by digest                  | P3       | 15m    | Reproducibility — eliminate `latest` tag drift        |
| 17 | DNS blocklist hash automation                           | P3       | 2h     | Reliability — auto-update instead of manual pinning   |
| 18 | NixOS module documentation                              | P3       | 4h     | Onboarding — structured docs for each module          |
| 19 | Cross-platform parity audit (Darwin vs NixOS)           | P3       | 3h     | Consistency — detect config drift                     |
| 20 | Security audit: re-enable auditd when NixOS fixes bug   | P3       | 1h     | Security — audit logging is disabled                  |
| 21 | Waybar module consolidation (hyprland+niri)             | P3       | 2h     | Maintenance — shared bar config has duplication       |
| 22 | Hyprland plugin migration (hy3, hyprsplit, hyprwinwrap) | P3       | 2h     | Features — waiting for 0.54 compatibility             |
| 23 | Automated health check cron (system-level)              | P3       | 1h     | Operations — scheduled `just health` runs             |
| 24 | SOPS secrets audit — what's encrypted vs. plaintext     | P3       | 2h     | Security — verify all secrets managed properly        |
| 25 | Desktop environment screenshot/visual documentation     | P4       | 2h     | Documentation — catalog the visual setup              |

---

## G. TOP #1 QUESTION ❓

**How does ReGreet actually look and behave on your 4K TV at 2m viewing distance?**

The config is built and committed, but I cannot verify:

- Whether the Cantarell 16pt font is readable on a 4K TV at 2m
- Whether cage handles HiDPI correctly with your DP-3 output
- Whether the Catppuccin CSS renders properly or has GTK4 quirks
- Whether session selection shows Hyprland (with UWSM) correctly
- Whether the Bibata cursor appears at the right size inside cage

This can ONLY be answered by deploying to evo-x2 and physically looking at the screen. If anything is off, we'll iterate on the CSS and config.
