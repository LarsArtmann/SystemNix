# Gaming Fix — Counter-Strike Crash on Niri + AMD — 2026-04-11 17:31

## Problem

Counter-Strike (CS2) was crashing on NixOS running Niri (Wayland) with AMD Ryzen AI Max+ 395 (Strix Halo).

## Root Causes Identified

| # | Issue                                                                                     | Severity   | File                                        |
| - | ----------------------------------------------------------------------------------------- | ---------- | ------------------------------------------- |
| 1 | `MESA_VK_WSI_PRESENT_MODE = "fifo"` forced VSync on all Vulkan apps globally              | **High**   | `platforms/nixos/hardware/amd-gpu.nix:30`   |
| 2 | No Niri window rules for Steam/CS2 — games hit the 0.95 opacity rule and tiling conflicts | **High**   | `platforms/nixos/programs/niri-wrapped.nix` |
| 3 | No gamescope launch wrapper for CS2                                                       | **Medium** | Steam launch options                        |

### Cause 1: Global VSync

`MESA_VK_WSI_PRESENT_MODE = "fifo"` was set as a global session variable, forcing FIFO (double-buffered VSync) on every Vulkan application. CS2 expects to control its own present mode and this caused Vulkan surface creation failures and frame pacing crashes.

### Cause 2: Niri Tiling + Opacity

Niri's window rules applied `opacity = 0.95` to all non-floating tiled windows (including CS2 via xwayland-satellite). This interfered with fullscreen Vulkan rendering. Additionally, no `open-fullscreen = true` rule existed for Steam game windows, causing tiling conflicts during fullscreen transitions.

## Changes Applied

### `platforms/nixos/hardware/amd-gpu.nix`

```diff
- MESA_VK_WSI_PRESENT_MODE = "fifo";
+ MESA_VK_WSI_PRESENT_MODE = "immediate";
```

Unlocked Vulkan present mode — CS2 now controls its own frame presentation (no forced VSync, lowest latency).

### `platforms/nixos/programs/niri-wrapped.nix`

Added two window rules for Steam games:

```nix
{
  matches = [{app-id = "^steam_app_.*";}];
  open-fullscreen = true;
  opacity = 1.0;
}
{
  matches = [
    {app-id = "^steam_app_.*";}
    {app-id = "^steam$";}
    {title = "^Counter-Strike";}
  ];
  open-fullscreen = true;
  opacity = 1.0;
}
```

- `open-fullscreen = true` — bypasses Niri tiling for game windows
- `opacity = 1.0` — overrides the global 0.95 rule for full rendering performance

## Deployment

- Built and activated via `just switch` — 24/24 derivations built in 26s
- Config validated: Niri config passed KDL validation, all systemd units activated

## Recommended Follow-up (Not Applied)

CS2 Steam launch option for best experience:

```
gamescope -f -- %command%
```

This wraps CS2 in gamescope's isolated compositor, completely bypassing Niri and xwayland-satellite for zero-overhead fullscreen gaming.
