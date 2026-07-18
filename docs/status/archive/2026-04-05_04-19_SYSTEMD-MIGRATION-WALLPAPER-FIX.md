# SystemD Migration & Wallpaper Fix — Comprehensive Status

**Date:** 2026-04-05 04:19
**Session Focus:** Fix missing wallpapers; migrate Niri spawn-at-startup daemons to systemd user services

---

## Executive Summary

The desktop had **no wallpaper** — only a dark blue fallback (`#1e1e2e`) from Niri's `background-color`. The root cause was that `awww img` (the client) was being spawned at startup, but `awww-daemon` (the long-running daemon process) was never started. The socket `/run/user/1000/wayland-1-awww-daemon.sock` never existed, so every wallpaper command silently failed.

This was fixed and, in the process, **all long-running daemons** were migrated from Niri's `spawn-at-startup` to proper **systemd user services** with dependency ordering, auto-restart, and clean lifecycle management.

---

## Changes Made

### File: `platforms/nixos/programs/niri-wrapped.nix`

This was the only file changed across this session. It is a Home Manager module that configures the Niri compositor.

#### 1. Wallpaper Fix — `awww-daemon` Was Never Started

**Root cause:** The `spawn-at-startup` block ran `awww img "$img"` (the client), but `awww-daemon` was never launched. The client connects to a Unix domain socket created by the daemon — without the daemon, the socket doesn't exist and every `awww img` call fails with:

```
Socket file '/run/user/1000/wayland-1-awww-daemon.sock' not found.
```

**Fix:** Created `awww-daemon.service` (systemd user service) that starts the daemon, and `awww-wallpaper.service` (oneshot) with `Requires=awww-daemon.service` + `After=awww-daemon.service` so systemd guarantees the socket exists before the client runs.

#### 2. Migrated swayidle to systemd

**Before:** Spawned inline in `spawn-at-startup` with no restart on failure.

**After:** `swayidle.service` — long-running daemon with `Restart=on-failure`.

- 5 min idle → `swaylock -f`
- 10 min idle → `systemctl suspend`
- Before sleep → `swaylock -f`

#### 3. Migrated cliphist to systemd

**Before:** `wl-paste --watch cliphist store` spawned in `spawn-at-startup`.

**After:** `cliphist.service` — long-running clipboard watcher with `Restart=on-failure`.

#### 4. Removed duplicate dunst spawn

**Before:** `dunst` was both spawned in `spawn-at-startup` **and** configured as `services.dunst` in `home.nix:295`. Home Manager already generates a systemd user service when `services.dunst.enable = true` is set, so the manual spawn created a **duplicate dunst instance**.

**After:** Removed from `spawn-at-startup`. Only the HM-managed `dunst.service` runs.

#### 5. Added `sudo btop` startup kitty

A second kitty instance now opens at startup running `sudo btop` for system monitoring.

---

## Service Architecture (After)

### `spawn-at-startup` (Niri-managed, short-lived)

| Entry                          | Purpose        |
| ------------------------------ | -------------- |
| `kitty`                        | Terminal       |
| `kitty -e fish -c "sudo btop"` | System monitor |

Only interactive applications remain in `spawn-at-startup`. These are not daemons — they don't need restart or dependency management.

### `systemd.user.services` (Daemon lifecycle management)

| Service          | Type      | Restart      | Dependencies                                                | Description                                                                       |
| ---------------- | --------- | ------------ | ----------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `awww-daemon`    | `simple`  | `on-failure` | `After=graphical-session.target`                            | Wallpaper daemon (socket at `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY-awww-daemon.sock`) |
| `awww-wallpaper` | `oneshot` | no           | `Requires=awww-daemon.service`, `After=awww-daemon.service` | Picks random wallpaper from `/home/lars/projects/wallpapers/` on login            |
| `swayidle`       | `simple`  | `on-failure` | `After=graphical-session.target`                            | Idle management (lock at 5m, suspend at 10m)                                      |
| `cliphist`       | `simple`  | `on-failure` | `After=graphical-session.target`                            | Clipboard history via `wl-paste --watch cliphist store`                           |
| `dunst`          | `simple`  | HM-managed   | `After=graphical-session.target`                            | Notification daemon (managed by `services.dunst` in home.nix)                     |

All services use `PartOf=graphical-session.target` and `WantedBy=graphical-session.target` for clean start/stop with the desktop session.

---

## Commit History (This Session)

| Commit    | Description                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------- |
| `1a415b1` | Add `awww-daemon` to startup (initial fix attempt — daemon spawned but client had no ordering) |
| `b38f87e` | Wait for awww-daemon socket before wallpaper init (socket polling approach)                    |
| `596c414` | Migrate awww-daemon and wallpaper to systemd user services (first systemd migration)           |
| `c730661` | Migrate swayidle/dunst/cliphist to systemd services (complete migration)                       |
| `d5951ba` | Add btop with sudo to startup applications                                                     |

---

## Keybinding: Mod+W

`Mod+W` still works as a random wallpaper switcher — it calls `awww img` directly (the daemon is already running via systemd, so the client connects immediately):

```nix
"Mod+W".action.spawn = sh "img=$(ls /home/lars/projects/wallpapers/*.{jpg,jpeg,png,webp} 2>/dev/null | shuf -n1) && [ -n \"$img\" ] && awww img \"$img\" --transition-type random --transition-duration 3";
```

5 wallpapers available in `/home/lars/projects/wallpapers/`.

---

## What Was the Iteration

1. **First attempt:** Added `awww-daemon` to `spawn-at-startup` before `awww img` — but Niri spawns them near-simultaneously with no ordering guarantee, so the client could still race.
2. **Second attempt:** Added `sleep 1` before `awww img` — fragile, arbitrary delay.
3. **Third attempt:** Replaced sleep with socket polling (`while [ ! -S ... ]`) — better but still a busy-wait hack in Niri config.
4. **Final approach:** Proper systemd user services with `Requires=` + `After=` dependencies. Zero polling, zero sleeps. systemd guarantees ordering.

---

## Uncommitted Changes

| File                                        | Change                                                     |
| ------------------------------------------- | ---------------------------------------------------------- |
| `platforms/nixos/programs/niri-wrapped.nix` | Added `kitty -e fish -c "sudo btop"` to `spawn-at-startup` |

The monitoring.nix and sops.nix files shown in git status at session start had already been committed in a prior session.

---

## System State

- **Wallpaper tool:** `awww` v0.12.0 (daemon + client)
- **Wallpaper directory:** `/home/lars/projects/wallpapers/` (5 images: jpg, jpeg, png)
- **Niri background fallback:** `#1e1e2e` (Catppuccin Mocha base — visible during transitions and behind gaps)
- **All daemons:** systemd-managed with auto-restart
- **Validation:** `just test-fast` passes clean
