# Wallpaper Startup Race Condition Fix

**Date:** 2026-04-09
**File Changed:** `platforms/nixos/programs/niri-wrapped.nix`

---

## Problem

Wallpapers consistently failed to load on login. The `awww-wallpaper` systemd oneshot service would fire `awww img` once, immediately after `awww-daemon.service` started. But the daemon hadn't finished initializing its Wayland socket yet — so the client silently failed and the oneshot exited. No retry, no wallpaper until manual `Mod+W`.

## Root Cause

The previous fix (session 2026-04-05) correctly migrated from Niri `spawn-at-startup` to systemd user services with `Requires=` + `After=` ordering. However, `After=` only guarantees the daemon **process has started** — not that its **socket is ready**. This is a classic systemd race: service is "started" but not yet "ready to accept connections."

## Fix

Three changes to the `awww-wallpaper` service:

| Change                                         | Why                                                                                             |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Retry loop** (`for i in $(seq 1 30)`)        | `awww img` retries up to 30 times (1s apart), waiting for the daemon socket to actually respond |
| **`RemainAfterExit = true`**                   | Systemd marks the oneshot as "active" after success, preventing redundant triggers              |
| **`Restart = on-failure` + `RestartSec = 2s`** | If all 30 retries exhaust (e.g. daemon crashed), systemd restarts the whole service             |

### Before

```nix
Service = {
  Type = "oneshot";
  ExecStart = "... && awww img \"$img\" ...";
};
```

One attempt. Silent failure. No recovery.

### After

```nix
Service = {
  Type = "oneshot";
  RemainAfterExit = true;
  ExecStart = "... && for i in $(seq 1 30); do awww img \"$img\" ... && break; sleep 1; done";
  Restart = "on-failure";
  RestartSec = "2s";
};
```

Retries until the daemon socket is ready. Falls back to systemd-level restart if all retries fail.

## Why Not a Proper Socket Activation?

`awww` doesn't support systemd socket activation. The retry loop is the pragmatic equivalent: wait up to 30s for the socket, which is more than enough for daemon initialization on any reasonable system.

## Impact

| Trigger           | Before                        | After                    |
| ----------------- | ----------------------------- | ------------------------ |
| Login (automatic) | No wallpaper (race condition) | Wallpaper loads reliably |
| Mod+W (manual)    | Always worked                 | Unchanged                |

## History

This is the **third** wallpaper-related fix in this project:

| Date       | What                                             | Why                                                |
| ---------- | ------------------------------------------------ | -------------------------------------------------- |
| 2026-04-05 | Migrated `awww` daemons to systemd user services | `awww-daemon` was never started (only client was)  |
| 2026-04-05 | Added `Requires=` + `After=` ordering            | No dependency management between daemon and client |
| 2026-04-09 | Added retry loop + `RemainAfterExit` + `Restart` | `After=` doesn't guarantee socket readiness        |
