# Session 55 — Boot Diagnostics & Desktop Session Fix

**Date:** 2026-05-08 13:19
**Session:** 55
**Trigger:** Reboot revealed broken wallpaper, missing dark mode, no auto-starting terminals
**Commits:** `1c79da5` `12aebf4` `0c9f1ba`
**Status:** Fixes committed & pushed. **Reboot required to fully verify.**

---

## Executive Summary

Post-reboot, three desktop session issues surfaced simultaneously. Root cause: a systemd ordering cycle in the wallpaper services + incorrect xdg-desktop-portal backend config (inherited from niri's defaults). All three fixes are committed and deployed via `just switch`, but the portal fix and spawn-at-startup require a reboot to take effect.

---

## a) FULLY DONE

| # | Item | Commit | Verified |
|---|------|--------|----------|
| 1 | **Wallpaper ordering cycle fix** | `1c79da5` | YES — service starts cleanly after `just switch`, no more cycle errors |
| 2 | **btop/nvtop spawn-at-startup** | `1c79da5` | Config committed — needs reboot to verify |
| 3 | **Portal backend config fix** | `12aebf4` | Config on disk at `/etc/xdg/xdg-desktop-portal/niri-portals.conf` shows `default=gtk;wlr` — needs reboot to verify |
| 4 | **AGENTS.md documentation** | `0c9f1ba` | Two new gotchas added: ordering cycle + niri portal config |
| 5 | **$HOME warning in wallpaper ExecStart** | `1c79da5` | Removed `${wallpaperDir}` arg, script uses its own default |

### Wallpaper Ordering Cycle — Root Cause

```
awww-wallpaper → (After) → awww-daemon → (After) → graphical-session.target → (WantedBy) → awww-wallpaper
```

Systemd broke the cycle by deleting the daemon from startup → wallpaper script waited 60s with no daemon → failed with exit-code.

**Fix:** `awww-wallpaper` now has `After = ["graphical-session.target"]` only. The `wallpaper-set.sh` script has its own 60s wait loop for the daemon socket (`awww query`), so `After=awww-daemon` was both unnecessary and harmful.

### Portal Dark Mode — Root Cause

Niri's package ships `niri-portals.conf` with:
```
default=gnome;gtk;
```

Without a GNOME session, the gnome portal backend times out (25s) trying to D-Bus activate `org.freedesktop.impl.portal.desktop.gnome`. The `org.freedesktop.portal.Settings` interface never exports, so browsers can't read `color-scheme=dark`.

**Fix:** Added `xdg.portal.config.niri` override:
```nix
config.niri = {
  default = ["gtk" "wlr"];
  "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
  "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
};
```

Generated file at `/etc/xdg/xdg-desktop-portal/niri-portals.conf` now shows `default=gtk;wlr`.

---

## b) PARTIALLY DONE

| # | Item | Status | Blocking |
|---|------|--------|----------|
| 1 | **Helium dark mode** | Portal config fix deployed but portal hasn't restarted | Reboot needed |
| 2 | **Portal Settings interface** | Config correct on disk, but running portal still uses old gnome-first config | Reboot needed |
| 3 | **Boot time verification** | The ordering cycle wasted 60s+ at boot. Fixed but not yet measured on clean boot | Reboot needed |

---

## c) NOT STARTED

| # | Item | Notes |
|---|------|-------|
| 1 | **udev DPM force performance** | `ATTR{device/power_dpm_force_performance_level}="high"` fails on all DP/HDMI outputs — sysfs path doesn't exist for amdgpu outputs. May be a kernel API change or wrong attribute path. |
| 2 | **blueman-applet duplicate ExecStart** | `blueman-applet.service: Service has more than one ExecStart= setting, which is only allowed for Type=oneshot services` — Home Manager + system both defining the service. |
| 3 | **Duplicate D-Bus names** | 20+ `Ignoring duplicate name` messages from dbus-broker — system-path and individual packages both providing the same D-Bus services. Cosmetic but noisy. |
| 4 | **xdg-desktop-portal pidns errors** | `Could not get pidns for pid: Not a directory` — portal trying to do namespace operations inside containers/NixOS sandbox. Non-blocking but indicates mismatch. |
| 5 | **Disk usage at 90%** | Root partition (`/dev/nvme0n1p6`) at 444G/512G (90%). Needs cleanup — likely old Nix generations, Docker images, or build artifacts. |
| 6 | **Swap usage at 10/25 GB** | 10GB of swap used despite 36GB available RAM. Likely leftover from heavy AI workloads. Could be cleared. |

---

## d) TOTALLY FUCKED UP

| # | Item | What Happened | Fix |
|---|------|---------------|-----|
| 1 | **This entire boot was broken** | All three desktop session features (wallpaper, dark mode, auto-terminals) were non-functional from boot. The ordering cycle has been present since the wallpaper service was first configured. | Fixed in this session. |
| 2 | **Portal Settings was NEVER working on niri** | The `xdg.portal.config.common.default = ["*"]` was a wildcard that let niri's built-in config (gnome-first) take precedence. Dark mode via portal has likely never worked in this setup. | Fixed with explicit niri override. |
| 3 | **Wallpaper $HOME expansion in systemd** | `ExecStart=... $HOME/.local/share/wallpapers` — systemd doesn't expand `$HOME` in ExecStart the same way bash does, producing a spurious warning on every start. | Fixed by removing the arg (script defaults to `$HOME/.local/share/wallpapers`). |

---

## e) WHAT WE SHOULD IMPROVE

| # | Area | Current State | Improvement |
|---|------|---------------|-------------|
| 1 | **Boot-time validation** | No automated check for ordering cycles or failed services after `just switch` | Add a `just health` check that looks for ordering cycles in journal after switch |
| 2 | **Portal configuration** | Was using wildcard `["*"]` which silently fell through to niri's broken defaults | Always be explicit about portal backends per desktop environment |
| 3 | **Niri service dependencies** | Services defined in Home Manager `systemd.user.services` with implicit dependencies | Document the dependency chain clearly: `graphical-session.target` → `awww-daemon` → (independent) `awww-wallpaper` |
| 4 | **Disk monitoring** | Root at 90% with no alerting | Add disk usage to waybar or gatus monitoring |
| 5 | **Self-review discipline** | I initially ignored the Helium dark mode report — should have addressed ALL reported issues before declaring done | Always cross-check user's full complaint list against fixes |
| 6 | **Boot performance tracking** | No baseline boot time measurement | Run `systemd-analyze` after clean reboot to establish baseline |
| 7 | **Session manager app mappings** | Session only restores `kitty` (app_id), not the child commands inside (btop, nvtop). The `spawn-at-startup` workaround starts fresh terminals but doesn't restore previous state. | Consider if niri-session-manager `app_mappings` could help, or accept the limitation |
| 8 | **Root disk cleanup** | 90% is dangerous — Nix builds need temp space | Add a `just clean` cron or auto-prune old generations |

---

## f) TOP 25 THINGS TO DO NEXT

### Critical (Do First)

| # | Task | Impact | Effort | Notes |
|---|------|--------|--------|-------|
| 1 | **Reboot and verify all fixes** | HIGH | Tiny | Wallpaper, dark mode, btop/nvtop, boot time |
| 2 | **Clean root disk** (`just clean`, prune generations) | HIGH | Small | 90% → safer level |
| 3 | **Verify portal Settings exports color-scheme=dark** | HIGH | Tiny | `dbus-send` after reboot |
| 4 | **Verify Helium dark mode after reboot** | HIGH | Tiny | Visual check |
| 5 | **Measure boot time** (`systemd-analyze`) | MEDIUM | Tiny | Establish baseline post-fix |

### High Impact

| # | Task | Impact | Effort | Notes |
|---|------|--------|--------|-------|
| 6 | **Fix udev DPM performance rule** | MEDIUM | Small | Wrong sysfs path for amdgpu — may need `power_dpm_state` or remove entirely if amdgpu handles it |
| 7 | **Fix blueman-applet duplicate ExecStart** | MEDIUM | Small | Conflict between HM and system-level service definition |
| 8 | **Add disk usage monitoring** | MEDIUM | Small | Waybar module or gatus endpoint for root partition |
| 9 | **Clear stale swap** (`swapoff -a && swapon -a`) | LOW | Tiny | 10GB swap used with RAM available |
| 10 | **Add boot health check to justfile** | MEDIUM | Small | `just health` checks for ordering cycles, failed services |

### Architecture & Quality

| # | Task | Impact | Effort | Notes |
|---|------|--------|--------|-------|
| 11 | **Deduplicate D-Bus service names** | LOW | Medium | System-path causes 20+ duplicate name warnings |
| 12 | **Investigate portal pidns errors** | LOW | Medium | May need namespace fix in portal service |
| 13 | **Consolidate niri portal config** | LOW | Tiny | Remove niri's built-in portal config, rely entirely on NixOS `xdg.portal` |
| 14 | **Add gatus endpoint for portal health** | LOW | Small | Check `org.freedesktop.portal.Settings` D-Bus availability |
| 15 | **Review all systemd user services for ordering issues** | MEDIUM | Medium | Audit all services in niri-wrapped.nix for cycle risks |

### Features & Polish

| # | Task | Impact | Effort | Notes |
|---|------|--------|--------|-------|
| 16 | **Session manager: map kitty+btop to spawn command** | LOW | Small | niri-session-manager `app_mappings` won't help (can't detect child process) — accept spawn-at-startup |
| 17 | **Auto-prune Nix generations** | MEDIUM | Small | `nix.gc` automatic or systemd timer for old generations |
| 18 | **Wallpaper: add randomize-on-boot option** | LOW | Tiny | Currently restores last, could optionally randomize |
| 19 | **Waybar: add disk module** | LOW | Tiny | Show root/data partition usage |
| 20 | **Niri config: add workspace names to waybar** | LOW | Tiny | Named workspaces (main, browser, dev, chat, media) shown in bar |
| 21 | **Review niri-session-manager skip_apps** | LOW | Tiny | Check if any apps should be skipped during restore |
| 22 | **Add emoji/unicode picker to waybar** | LOW | Small | Trigger rofi emoji from waybar click |
| 23 | **Verify SDDM theme matches post-reboot** | LOW | Tiny | Catppuccin Mocha at login screen |
| 24 | **Test awww-daemon crash recovery** | LOW | Small | Kill daemon, verify wallpaper service self-heals via PartOf |
| 25 | **Document niri keybinds in AGENTS.md** | LOW | Small | Quick reference for all Mod+X bindings |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why does `xdg-desktop-portal-gtk` export `Settings` but only after a GNOME session starts?**

The gtk portal DOES support `org.freedesktop.impl.portal.Settings` (confirmed in its `.portal` file). Yet the logs show it timed out during this boot. The timeout happened because the portal tried gnome first (niri's default config), which blocked for 25s, and by the time it fell back to gtk, waybar had already started and gotten the "No such interface" error.

**After reboot with the new config (`default=gtk;wlr`), the gtk portal should load Settings immediately** since there's no gnome delay. But I cannot verify this without the reboot.

**Sub-question:** Is `xdg-desktop-portal-gtk` the right Settings provider for niri? Some niri users use `xdg-desktop-portal-gnome` specifically for the Settings/ColorScheme interface. Should we keep both `gtk` and `gnome` in the fallback list but with gtk first?

---

## System State

| Metric | Value |
|--------|-------|
| Uptime | 1h 43m (same boot as problem) |
| Root disk | 90% (444G/512G) — NEEDS CLEANUP |
| Data disk | 66% (675G/1.0T) |
| RAM | 26G/62G used |
| Swap | 10G/25G used (stale from AI workloads) |
| NixOS version | 26.05.20260423.01fbdee |
| Current generation | `/nix/store/3sc8nn219f4gx8bki8gwdz06314q4ng3-nixos-system-evo-x2` |
| Git HEAD | `0c9f1ba` (pushed to origin/master) |

## Files Changed This Session

| File | Changes |
|------|---------|
| `platforms/nixos/programs/niri-wrapped.nix` | Fixed wallpaper ordering cycle, removed $HOME arg, added spawn-at-startup |
| `platforms/nixos/system/configuration.nix` | Portal config: explicit gtk+wlr with niri override |
| `AGENTS.md` | Two new gotchas: ordering cycle + niri portal config |

## Services Status (Current Boot — Pre-Fix)

| Service | Status | Notes |
|---------|--------|-------|
| niri | Running | PID 5070 |
| waybar | Running | PID 10375, but can't read portal appearance |
| awww-daemon | Running | PID 40477 (restarted by `just switch`) |
| awww-wallpaper | Running | Fixed after `just switch`, was broken at boot |
| niri-session-manager | Running | PID 10373, working correctly |
| xdg-desktop-portal | Running | Settings interface NOT available (gnome timeout) |
| xdg-desktop-portal-gtk | Running | Working for file chooser etc, but Settings came too late |
| swayidle | Running | Normal |
| cliphist | Running | Normal |

## Services Status (Expected Post-Reboot)

| Service | Expected |
|---------|----------|
| awww-daemon | Starts immediately (no cycle) |
| awww-wallpaper | Starts after graphical-session, restores wallpaper via daemon wait loop |
| xdg-desktop-portal | Settings interface available immediately (gtk first, no gnome delay) |
| Helium | Dark mode via portal color-scheme=dark |
| kitty btop/nvtop | Auto-started via spawn-at-startup |
| Boot time | ~60s faster (no ordering cycle timeout) |

---

*Session 55 — Boot diagnostics, desktop session fixes, comprehensive status.*
