# Session 14 Final: Wallpaper Working — Comprehensive Status

**Date:** 2026-05-01 23:55 CEST
**Host:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB reported / 62GB usable)
**Branch:** master (aea82ce, 2 ahead of origin)
**Uptime:** ~11h since last boot

---

## Session Summary

Wallpaper fix from earlier this session is **deployed and working**. The awww daemon is running, displaying a wallpaper on DP-2 (3072×1728, scale 1.25). However, the daemon is running from a **manual shell invocation** — it will NOT survive a shell exit. The systemd user service still needs to be activated.

---

## a) FULLY DONE ✅

### Wallpaper Pipeline (this session)

| Step                 | Status                   | Detail                                                                                                     |
| -------------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| Nix config fix       | ✅ Committed (`34b2d12`) | `wallpaperDir` → `$HOME/.local/share/wallpapers`, `home.file` deployment, `After=graphical-session.target` |
| Build validation     | ✅ Passed                | `just test` clean, -8 bytes diff                                                                           |
| Deploy to evo-x2     | ✅ Applied               | Service files updated, wallpapers symlinked to `~/.local/share/wallpapers/`                                |
| Wallpapers on disk   | ✅ 4 images              | `.png`, `.jpeg`, `.jpg`, (no `.webp` — none in repo)                                                       |
| niri keybind Mod+W   | ✅ Deployed              | `$HOME/.local/share/wallpapers/*.{jpg,jpeg,png,webp}` in config.kdl                                        |
| awww-daemon running  | ✅ Manual start          | PID 1216186, socket at `/run/user/1000/wayland-1-awww-daemon.sock`                                         |
| Wallpaper displaying | ✅ **CONFIRMED**         | DP-2 showing `wp1984234-beijing-wallpapers-red-door-gold-studs-temple-of-heaven.jpg`                       |

### From Previous Sessions (carried forward)

| Area                     | Status         | Detail                                                                   |
| ------------------------ | -------------- | ------------------------------------------------------------------------ |
| 19/19 system services    | ✅ All running | Caddy, Authelia, SigNoz, Gitea, Immich, Hermes, etc.                     |
| Security hardening       | ✅ Applied     | `lib/systemd.nix` with configurable params, `ProtectSystem=full` default |
| Master TODO P0-P4, P7-P8 | ✅ 100% each   | 62/95 total tasks done (65%)                                             |
| CI/CD                    | ✅ 3 workflows | nix-check, go-test, flake-update                                         |

---

## b) PARTIALLY DONE ⚠️

### awww-daemon systemd integration

| Aspect                               | Status       | Why                                                             |
| ------------------------------------ | ------------ | --------------------------------------------------------------- |
| Service file deployed                | ✅ Correct   | `After=graphical-session.target`, `StartLimit*` in `[Unit]`     |
| WantedBy symlink                     | ✅ Present   | `graphical-session.target.wants/awww-daemon.service` → HM files |
| Service actually running via systemd | ❌ **NO**    | Daemon started manually — not tracked by systemd                |
| Auto-start on next login             | ✅ Will work | `WantedBy=graphical-session.target` activates at session start  |
| Survives current shell exit          | ❌ **NO**    | Manual `awww-daemon &` will be killed                           |

**User action needed:** Run `systemctl --user start awww-daemon awww-wallpaper` in a terminal to hand off to systemd. Or just log out/in.

### Master TODO Plan (65%, 62/95)

| Category         | Done | Remaining                                         |
| ---------------- | ---- | ------------------------------------------------- |
| P1 SECURITY      | 3/7  | 4 blocked on evo-x2 (sops, Docker digests, VRRP)  |
| P5 DEPLOY/VERIFY | 0/13 | All need evo-x2 manual verification               |
| P6 SERVICES      | 9/15 | 6 remaining (Hermes health, SigNoz metrics, etc.) |
| P9 FUTURE        | 2/12 | 10 research items                                 |

---

## c) NOT STARTED 📋

### Security (P1)

1. Move Taskwarrior encryption to sops-nix
2. Pin Docker digest for Voice Agents (`beecave/insanely-fast-whisper-rocm`)
3. Pin Docker digest for PhotoMap (`lstein/photomapai`)
4. Secure VRRP `auth_pass` with sops-nix

### Deployment Verification (P5)

5. Verify Ollama after rebuild
6. Verify Steam after rebuild
7. Verify ComfyUI after rebuild
8. Verify Caddy HTTPS block page
9. Verify SigNoz metrics/logs/traces
10. Check Authelia SSO
11. Check PhotoMap service
12. Verify AMD NPU workload
13. Build Pi 3 SD image
14. Flash + boot Pi 3
15. Test DNS failover
16. Configure LAN devices for DNS VIP

### Services (P6)

17. Hermes health check endpoint
18. Hermes mergeEnvScript cleanup
19. SigNoz missing metrics for 10 services
20. Authelia SMTP notifications
21. Immich backup restore test
22. Twenty CRM backup restore test

### Operational

23. SigNoz JWT secret (`SIGNOZ_TOKENIZER_JWT_SECRET`) — missing, sessions insecure
24. Gitea GitHub mirror token — expired, needs manual update
25. Disk audit — root 88%, /data 86%
26. Swap audit — 8.2GB/41GB
27. Twenty CRM v2.x data integrity verification
28. Homepage dashboard update for new services

---

## d) TOTALLY FUCKED UP 💥

### This Session

1. **First fix didn't work** — The initial `wallpaperDir = wallpapers` → `"$HOME/.local/share/wallpapers"` + `home.file` fix was correct in code but the daemon was never restarted. I assumed `just switch` would restart it. It didn't — because the fix was deployed mid-session and systemd user services only auto-start at graphical session activation (login). **I should have told the user to restart the services immediately after switch.**

2. **Took 2 rounds to get wallpaper showing** — First attempt: code fix only. Second attempt: manually started daemon + set wallpaper. The user had to come back and say "STILL NOT WORKING" before I actually verified the runtime state. **I should have verified end-to-end (daemon running + wallpaper visible) before declaring done.**

3. **StartLimitIntervalSec audit was incomplete in session 13** — Session 13 fixed all system-level services but missed the user-level `awww-daemon` in `niri-wrapped.nix`. The audit should have covered ALL systemd units, not just system services.

### Carried Forward

4. **awww-daemon upstream crash (April 30)** — Rust `BrokenPipe` panic at `daemon/src/main.rs:712:32`, coredump. Upstream bug, `Restart=always` covers it now that start limits are in the correct section.

5. **Caddy WatchdogSec broken** — Caddy's `sd_notify` never sends `WATCHDOG=1`. Running without `WatchdogSec`. Upstream issue with Caddy + certmagic interaction.

---

## e) WHAT WE SHOULD IMPROVE 📈

### Process

1. **End-to-end verification before declaring done** — When fixing a runtime service, don't just check the build. Verify the service is running, the socket exists, and the actual output (wallpaper, web page, etc.) is visible. "Build passes" ≠ "Works".

2. **After `just switch`, explicitly restart affected services** — NixOS switch only activates system-level services. User services need `systemctl --user restart <service>` or a re-login. Document this in the justfile.

3. **Comprehensive systemd audits** — When auditing `StartLimitIntervalSec` placement, grep ALL `.service` definitions including `systemd.user.services`, not just `systemd.services`.

### Code

4. **`awww-daemon` should have `Environment=WAYLAND_DISPLAY=wayland-1`** — Currently relies on session environment inheritance. If systemd starts the service before `WAYLAND_DISPLAY` is exported, it will look for `wayland-0` (default) and fail.

5. **`awww-wallpaper` retry loop is fragile** — The `for i in $(seq 1 30); do awww img ... && break; sleep 1; done` retries for 30 seconds. If the daemon takes longer to initialize (large images, slow GPU), it gives up silently.

6. **`lib/systemd.nix` should be a proper NixOS module** — Currently just a function returning an attrset. Should have `mkHarden` with `lib.mkOption` for type safety and conflict detection.

7. **Service health checks should use a shared helper** — Every ExecStartPost independently reinvents `curl -sf --max-time --retry ...`.

8. **Podman services should have a dedicated hardening profile** — `lib/systemd/podman.nix` with podman-compatible defaults.

### System

9. **Disk cleanup automation** — 88% root, 86% /data. Need nix-store GC + Docker image prune timer.

10. **Monitoring for crash loops** — SigNoz should alert on service restart count > 5 in 5 minutes.

---

## f) Top #25 Next Actions

| #   | Action                                                                                    | Impact | Effort  | Est.   |
| --- | ----------------------------------------------------------------------------------------- | ------ | ------- | ------ |
| 1   | **Start awww services via systemd** (`systemctl --user start awww-daemon awww-wallpaper`) | High   | Trivial | 1min   |
| 2   | **Add `Environment=WAYLAND_DISPLAY`** to awww-daemon service                              | High   | Trivial | 2min   |
| 3   | **Add `ExecStartPost` health check** to awww-daemon (verify socket created)               | Medium | Low     | 5min   |
| 4   | **Pin Docker images by digest** (whisper, twenty, photomap)                               | High   | Low     | 15min  |
| 5   | **Add SIGNOZ_TOKENIZER_JWT_SECRET** via sops                                              | High   | Low     | 10min  |
| 6   | **Update Gitea GitHub mirror token**                                                      | High   | Trivial | 2min   |
| 7   | **Create `lib/systemd/podman.nix`** hardening profile                                     | Medium | Low     | 10min  |
| 8   | **Create `lib/systemd/health-check.nix`** shared curl helper                              | Medium | Low     | 10min  |
| 9   | **Disk usage audit** — find large dirs/files on root and /data                            | Medium | Low     | 10min  |
| 10  | **Nix GC + Docker prune timer**                                                           | Medium | Low     | 15min  |
| 11  | **Verify SigNoz dashboards/alerts** provisioned correctly                                 | Medium | Low     | 10min  |
| 12  | **Add signoz alert for service crash loops**                                              | Medium | Medium  | 15min  |
| 13  | **Update homepage dashboard** for new/changed services                                    | Low    | Low     | 10min  |
| 14  | **Test Caddy TLS cert renewal**                                                           | Medium | Low     | 5min   |
| 15  | **Verify whisper-asr GPU passthrough**                                                    | Medium | Low     | 5min   |
| 16  | **Verify Twenty CRM v2.x data integrity**                                                 | Medium | Medium  | 20min  |
| 17  | **Review swap usage** — 8.2GB seems high                                                  | Low    | Low     | 10min  |
| 18  | **BTRFS scrub timer** for data integrity                                                  | Medium | Low     | 10min  |
| 19  | **Consolidate StartLimitBurst/IntervalSec** into serviceDefaults helper                   | Low    | Low     | 10min  |
| 20  | **Audit all sops secrets** — check for rotation needs                                     | Medium | Medium  | 20min  |
| 21  | **Build Pi 3 SD image** for DNS failover                                                  | High   | High    | 30min+ |
| 22  | **Migrate Taskwarrior encryption to sops**                                                | Medium | Low     | 10min  |
| 23  | **Secure VRRP auth_pass with sops**                                                       | Medium | Low     | 8min   |
| 24  | **Create integration tests** for hardening lib                                            | High   | High    | 30min  |
| 25  | **Add `just wallpaper-status`** recipe to justfile                                        | Low    | Trivial | 5min   |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why doesn't `just switch` restart user-level systemd services?**

`nixos-rebuild switch` activates system-level services (`systemd.services.*`) but does NOT restart user-level services (`systemd.user.services.*`). After `just switch`, user services like `awww-daemon`, `awww-wallpaper`, `cliphist`, `swayidle`, and `waybar` get new unit files on disk but keep running the old code (or stay stopped if they weren't running).

Home Manager has `systemd.user.startServices` (default: `sd-switch` or `true` in some versions) which should handle this. Is this configured? If not, every `just switch` that changes user services requires a manual `systemctl --user restart ...` or a full logout/login — which defeats the purpose of live switching.

**Impact:** Every user-service change (wallpaper, waybar, cliphist, session restore) is silently not applied until the user logs out and back in. This is the exact reason the wallpaper "didn't work" after the first fix.

---

## Current System State

| Area                 | Status             | Detail                                           |
| -------------------- | ------------------ | ------------------------------------------------ |
| NixOS build          | ✅ Clean           | `just test` passes                               |
| System services (19) | ✅ All running     | Verified session 13                              |
| awww-daemon          | ⚠️ Manual PID      | Running but not via systemd — dies on shell exit |
| awww-wallpaper       | ✅ Displaying      | DP-2, 3072×1728, scale 1.25                      |
| Mod+W keybind        | ✅ Deployed        | Will work while daemon lives                     |
| Disk root            | ⚠️ 88% (443G/512G) | 64G free — needs audit                           |
| Disk /data           | ⚠️ 86% (685G/800G) | 116G free — needs audit                          |
| Swap                 | ⚠️ 8.2G/41G        | Elevated                                         |
| RAM                  | 40G/62G used       | 21G available                                    |
| Git                  | 2 ahead of origin  | Not pushed                                       |
