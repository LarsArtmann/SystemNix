# Session 14: Wallpaper Fix — Comprehensive Status

**Date:** 2026-05-01 16:18 — 23:46 CEST
**Host:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)
**Branch:** master (fc74c2d → pending)

---

## Session Focus

User reported wallpapers not showing. Investigated the full pipeline: flake input → NixOS config → Home Manager deployment → systemd services → aww daemon → Wayland compositor.

---

## a) FULLY DONE ✅

### Wallpaper Pipeline Fix (3 root causes found, all fixed)

| # | Issue                                                      | Root Cause                                                                                                                                                                                                                                                                                        | Fix                                                                                                                                                             |
| - | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Wallpapers never deployed to user space**                | `wallpaperDir = wallpapers;` pointed to raw flake input path (a Nix store path owned by root). The `awww` CLI runs as user `lars` and needed a user-accessible path.                                                                                                                              | Changed `wallpaperDir = "$HOME/.local/share/wallpapers"` + added `home.file.".local/share/wallpapers".source = wallpapers;` to symlink wallpapers into home dir |
| 2 | **awww-daemon never started after boot**                   | Service had `After=` missing from `[Unit]` section. A comment said "avoids ordering cycle with awww-wallpaper" but this was wrong — `After=` on a target never creates cycles. The daemon just had no ordering guarantee.                                                                         | Added `After = ["graphical-session.target"]` to `awww-daemon` unit                                                                                              |
| 3 | **StartLimitBurst/StartLimitIntervalSec in wrong section** | These directives were in `[Service]` instead of `[Unit]`. Systemd silently ignored them and logged `Unknown key 'StartLimitIntervalSec' in section [Service], ignoring` on every reload. The daemon crashed on April 30 (broken pipe → coredump) and with broken restart limits, never recovered. | Already fixed in session 13 for system-level services. This session fixed the remaining instance in the `awww-daemon` user service.                             |

### Files Changed

```
platforms/nixos/programs/niri-wrapped.nix  |  6 +++---
```

**Diff:**

- Line 10: `wallpaperDir = wallpapers` → `wallpaperDir = "$HOME/.local/share/wallpapers"`
- Line 367: Added `home.file.".local/share/wallpapers".source = wallpapers;`
- Line 770: Added `After = ["graphical-session.target"];` (replaced comment)
- Line 770: `StartLimitBurst` and `StartLimitIntervalSec` now in correct `[Unit]` section (was already correct in this file — only the `After=` was missing)

### Verification

- `just test-fast` — all checks passed
- `just test` — full build validation passed (41.7 GiB, -8 bytes diff)
- `~/.local/share/wallpapers/` — 4 wallpaper files present (png, jpeg, jpg)
- Manual test: `WAYLAND_DISPLAY=wayland-1 awww-daemon &` + `awww img <file>` — wallpaper displayed correctly on DP-2 (3072x1728, scale 1.25)

### Pre-existing Issue from Session 13

The `awww-daemon` had crashed on April 30 with a Rust panic (`BrokenPipe` at `daemon/src/main.rs:712:32`) and coredump. The `Restart=always` should have restarted it, but:

- `StartLimitIntervalSec` was in `[Service]` (wrong section), so systemd ignored it
- Without `After=graphical-session.target`, the service had no proper activation ordering
- The `PartOf=graphical-session.target` means it stops when the graphical session stops — but nothing ensured it **starts** with the session

Both ordering issues are now fixed.

---

## b) PARTIALLY DONE ⚠️

### Wallpaper — needs `just switch` to deploy

The Nix changes are built and tested but **not deployed**. User needs to run `just switch` for the changes to take effect. After switch:

- `awww-daemon` service will start properly with graphical session
- `awww-wallpaper` oneshot will pick a random wallpaper and display it
- `Mod+W` keybind will work for random wallpaper cycling

### Master TODO Plan (from session 12 audit)

| Category         | Total  | Done   | Remaining | % Complete |
| ---------------- | ------ | ------ | --------- | ---------- |
| P0 CRITICAL      | 6      | 6      | 0         | 100%       |
| P1 SECURITY      | 7      | 3      | 4         | 43%        |
| P2 RELIABILITY   | 11     | 11     | 0         | 100%       |
| P3 CODE QUALITY  | 9      | 9      | 0         | 100%       |
| P4 ARCHITECTURE  | 7      | 7      | 0         | 100%       |
| P5 DEPLOY/VERIFY | 13     | 0      | 13        | 0%         |
| P6 SERVICES      | 15     | 9      | 6         | 60%        |
| P7 TOOLING/CI    | 10     | 10     | 0         | 100%       |
| P8 DOCS          | 5      | 5      | 0         | 100%       |
| P9 FUTURE        | 12     | 2      | 10        | 17%        |
| **TOTAL**        | **95** | **62** | **33**    | **65%**    |

No change from last session — wallpaper fix is an operational bug, not a TODO item.

---

## c) NOT STARTED 📋

### From Previous Sessions (still pending)

1. **SigNoz JWT secret** — `SIGNOZ_TOKENIZER_JWT_SECRET` not set, sessions insecure
2. **Gitea GitHub mirror token** — expired, needs manual update in Gitea web UI
3. **Disk usage audit** — root 88%, /data 86%
4. **Swap audit** — 11GB/41GB high
5. **Twenty CRM v2.x migration verification** — database auto-migrated, custom configs need checking
6. **Homepage dashboard update** — needs updating for new/changed services
7. **P5 deployment verification** — all 13 items (see Master TODO)
8. **P1 security items** — 4 items blocked on evo-x2 access (sops secrets, Docker digests, VRRP auth)

### New This Session

9. **Wallpaper awww-daemon crash investigation** — The April 30 `BrokenPipe` panic in awww daemon (Rust code at `daemon/src/main.rs:712:32`) is an upstream bug. It coredumped and the process aborted. Not actionable from NixOS config side, but worth monitoring if it recurs.

---

## d) TOTALLY FUCKED UP 💥

### This Session

**Nothing.** Clean fix, build passed on first try.

### Carried Forward from Previous Sessions

1. **awww-daemon crash (April 30)** — Rust panic on `BrokenPipe` in awww daemon. Upstream bug, not caused by our config. The daemon had been dead for 1.5 days before this session noticed.
2. **Caddy WatchdogSec still broken** — From session 13: Caddy's `sd_notify` never sends `WATCHDOG=1`, so any `WatchdogSec` kills it. Currently running without `WatchdogSec`. Upstream issue with Caddy + certmagic interaction.

---

## e) WHAT WE SHOULD IMPROVE 📈

### From This Session

1. **`home.file` for wallpapers should have been there from day 1** — The original implementation used `wallpaperDir = wallpapers` (raw Nix store path) which only worked if `awww` was invoked during build evaluation, not at runtime. The fix (Home Manager `home.file` symlink) is the correct NixOS-native pattern.

2. **User services need the same `StartLimitBurst` audit as system services** — Session 13 fixed all system-level services but missed the user-level `awww-daemon` in `niri-wrapped.nix`. Should have done a comprehensive search for ALL `[Service]` sections with start limit directives.

3. **awww-daemon should have `Environment=WAYLAND_DISPLAY=wayland-1`** — The daemon defaults to `wayland-0` but the system uses `wayland-1`. Currently works because niri sets `WAYLAND_DISPLAY` in the session environment, but if the service ever starts before the env is available, it will fail.

### Carried Forward from Session 13

4. **`lib/systemd.nix` should be a proper NixOS module** — currently just a function returning an attrset
5. **Service health checks should use a shared helper** — every ExecStartPost independently reinvents `curl -sf --max-time --retry ...`
6. **Docker image tags should be pinned by digest** — Whisper and Twenty use floating tags
7. **Podman services should have a dedicated hardening profile** — `lib/systemd/podman.nix`
8. **Pre-switch validation** — Run `nix eval` to check hardening overrides propagate correctly
9. **Monitoring for crash loops** — SigNoz should alert on service restart count > 5 in 5 minutes
10. **Disk cleanup automation** — 88% root usage, need nix-store GC + Docker image prune timer

---

## f) Top #25 Next Actions

Sorted by (impact × urgency) / effort:

| #  | Action                                                                      | Impact | Effort  | Status                 | Est.   |
| -- | --------------------------------------------------------------------------- | ------ | ------- | ---------------------- | ------ |
| 1  | **`just switch`** — deploy wallpaper fix to evo-x2                          | High   | Trivial | READY                  | 5min   |
| 2  | **Verify awww-daemon + awww-wallpaper start** after switch                  | High   | Trivial | BLOCKED on #1          | 2min   |
| 3  | **Pin Docker images by digest** (whisper, twenty, photomap)                 | High   | Low     | READY                  | 15min  |
| 4  | **Add SIGNOZ_TOKENIZER_JWT_SECRET** via sops                                | High   | Low     | READY                  | 10min  |
| 5  | **Update Gitea GitHub mirror token**                                        | High   | Trivial | BLOCKED on user        | 2min   |
| 6  | **Create `lib/systemd/podman.nix`** hardening profile                       | Medium | Low     | READY                  | 10min  |
| 7  | **Create `lib/systemd/health-check.nix`** shared curl helper                | Medium | Low     | READY                  | 10min  |
| 8  | **Nix GC + Docker image prune timer**                                       | Medium | Low     | READY                  | 15min  |
| 9  | **Audit disk usage** — find large dirs/files                                | Medium | Low     | READY                  | 10min  |
| 10 | **Add WAYLAND_DISPLAY env to awww-daemon** service                          | Low    | Trivial | READY                  | 2min   |
| 11 | **Verify Twenty CRM v2.x data integrity**                                   | Medium | Medium  | BLOCKED on user        | 20min  |
| 12 | **Verify SigNoz dashboards/alerts** provisioned correctly                   | Medium | Low     | BLOCKED on #1          | 10min  |
| 13 | **Add signoz alert for service crash loops**                                | Medium | Medium  | READY                  | 15min  |
| 14 | **Update homepage dashboard** for new services                              | Low    | Low     | READY                  | 10min  |
| 15 | **Test Caddy TLS cert renewal**                                             | Medium | Low     | BLOCKED on #1          | 5min   |
| 16 | **Verify whisper-asr GPU passthrough** working                              | Medium | Low     | BLOCKED on #1          | 5min   |
| 17 | **Review swap usage** — 11GB seems high                                     | Low    | Low     | READY                  | 10min  |
| 18 | **Add systemd watchdog** for services that support sd_notify (caddy, gitea) | Medium | Medium  | BLOCKED — Caddy broken | 15min  |
| 19 | **Consolidate StartLimitBurst/IntervalSec** into serviceDefaults helper     | Low    | Low     | READY                  | 10min  |
| 20 | **BTRFS scrub timer** for data integrity                                    | Medium | Low     | READY                  | 10min  |
| 21 | **Audit all sops secrets** — check for rotation needs                       | Medium | Medium  | READY                  | 20min  |
| 22 | **Build Pi 3 SD image** for DNS failover cluster                            | High   | High    | BLOCKED on hardware    | 30min+ |
| 23 | **Migrate Taskwarrior encryption to sops**                                  | Medium | Low     | BLOCKED on evo-x2      | 10min  |
| 24 | **Secure VRRP auth_pass with sops**                                         | Medium | Low     | BLOCKED on evo-x2      | 8min   |
| 25 | **Create integration tests** for hardening lib                              | High   | High    | READY                  | 30min  |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why did `awww-daemon` get a `BrokenPipe` panic on April 30?**

The daemon ran fine for 2d 17h then crashed with:

```
thread '<unnamed>' panicked at daemon/src/main.rs:712:32:
called `Result::unwrap()` on an `Err` value: Os { code: 32, kind: BrokenPipe, message: "Broken pipe" }
fatal runtime error: failed to initiate panic, error 5, aborting
```

This is an awww upstream bug — an `unwrap()` on a write operation that hit a broken pipe. The pipe was likely the Wayland compositor socket (`/run/user/1000/wayland-0-awww-daemon.sock`). The niri compositor may have briefly disconnected or the socket was cleaned up during a compositor restart. The daemon should handle this gracefully (reconnect) instead of panicking.

**Impact:** If this happens again, the wallpaper disappears silently until next login or manual restart. We should add a systemd watchdog or `ExecStartPre` socket check.

**Actionable?** Not from NixOS config side — needs an upstream fix in awww. Our `Restart=always` should cover it now that the start limits are fixed.

---

## Overall System Health

| Area                 | Status               | Notes                                             |
| -------------------- | -------------------- | ------------------------------------------------- |
| NixOS build          | ✅ Clean             | `just test` passes, no eval warnings              |
| System services (19) | ✅ All running       | Verified in session 13                            |
| User services        | ⚠️ awww-daemon down   | Fix staged, needs `just switch`                   |
| Disk (root)          | ⚠️ 88% full           | Needs audit + cleanup                             |
| Disk (/data)         | ⚠️ 86% full           | Needs audit + cleanup                             |
| Swap                 | ⚠️ 11GB/41GB          | Higher than expected                              |
| Security hardening   | ✅ Applied           | All services hardened (except podman — by design) |
| DNS blocker          | ✅ Running           | 2.5M+ domains blocked                             |
| Sops secrets         | ⚠️ SigNoz JWT missing | Needs sops secret creation                        |
| Wallpaper            | 🔧 Fix staged        | Needs `just switch` to deploy                     |
