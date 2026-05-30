# QuickShell Desktop Shell Research

**Date:** 2026-05-30
**Context:** Replacing fragmented desktop shell components with a unified QuickShell setup for Niri on evo-x2

---

## What is QuickShell?

A **QML/Qt6 toolkit** for building your entire desktop shell as one cohesive system — bar, notifications, launcher, lockscreen, OSD, power menu, system tray. Hot-reload during development. v0.3.0 in nixpkgs.

- **Website:** https://quickshell.org/
- **Source:** https://github.com/outfoxxed/quickshell (mirror: `github:quickshell-mirror/quickshell`)
- **Nix flake:** `git+https://git.outfoxxed.me/outfoxxed/quickshell` or nixpkgs `quickshell`
- **Niri plugin:** https://github.com/imiric/qml-niri (QML plugin for Niri IPC)
- **Niri configs:** https://github.com/imiric/quickshell-niri (example configurations)
- **iNiR:** https://github.com/snowarch/iNiR (full Niri shell with Material You theming)

### Key Features

- **Hot-reload** — changes reflect instantly on save
- **QML configuration** — declarative, LSP support (`qmlls`)
- **Native service integrations** — Pipewire, UPower, NetworkManager, Bluetooth, MPRIS, SystemTray, PAM, Greetd, PolKit
- **Wayland native** — PanelWindow (layershell), FloatingWindow, PopupWindow, WlSessionLock
- **Niri support** — via qml-niri plugin: workspaces, windows, events, actions

### Required Qt Modules

| Module | Purpose |
|--------|---------|
| `qtsvg` | SVG image loading |
| `qtimageformats` | WEBP and uncommon formats |
| `qtmultimedia` | Audio/video playback |
| `qt5compat` | Gaussian blur and extra effects |

### Nix Installation

```nix
# Option 1: nixpkgs (stable releases)
environment.systemPackages = [ pkgs.quickshell ];

# Option 2: Flake (latest, recommended)
inputs.quickshell = {
  url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
  inputs.nixpkgs.follows = "nixpkgs";
};
# Package: quickshell.packages.${system}.default

# Option 3: GitHub mirror
inputs.quickshell = {
  url = "github:quickshell-mirror/quickshell";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

---

## Current Desktop Stack (evo-x2)

| Component | Tool | File | Notes |
|-----------|------|------|-------|
| **Compositor** | Niri | `platforms/nixos/desktop/niri-wrapped.nix` | Scrollable tiling, 5 named workspaces |
| **Bar** | Waybar | `platforms/nixos/desktop/waybar.nix` | 6 custom shell scripts, 42px top bar |
| **Notifications** | Dunst | `platforms/nixos/users/home.nix:435` | Catppuccin Mocha, overlay layer |
| **Launcher** | Rofi | `platforms/nixos/programs/rofi.nix` | Grid layout, rofi-calc, rofi-emoji |
| **Lockscreen** | swaylock-effects | `platforms/nixos/programs/swaylock.nix` | Catppuccin Mocha, PAM |
| **Power menu** | wlogout | `platforms/nixos/programs/wlogout.nix` | 6 actions, inline SVG icons |
| **Wallpaper** | awww | `platforms/nixos/desktop/niri-wrapped.nix:461` | Animated wallpaper daemon |
| **Idle** | swayidle | `platforms/nixos/desktop/niri-wrapped.nix:505` | 12h suspend, before-sleep lock |
| **Screenshots** | grim + slurp + swappy | keybinds in niri-wrapped.nix | Area/full/output + annotation |
| **OSD** | **NONE** | — | No volume/brightness overlay! |
| **Clipboard** | cliphist + wl-clipboard | systemd user service | History via rofi |
| **Session** | niri-session-manager | flake input | Window save/restore |
| **Display manager** | SDDM + SilentSDDM | `modules/nixos/services/display-manager.nix` | Catppuccin Mocha |
| **Theme** | Catppuccin Mocha | Global | GTK, Qt, icons (Papirus), cursor (Bibata) |

### Waybar Custom Scripts (6 total)

All in `platforms/nixos/desktop/waybar.nix`:

1. `waybar-camera` — EMEET PIXY webcam status (polls every 2s)
2. `waybar-dns-stats` — dnsblockd blocked count (curls every 30s)
3. `waybar-media` — MPRIS media info (polls every 2s)
4. `waybar-clipboard` — cliphist top entry (polls every 5s)
5. `waybar-clipboard-menu` — rofi cliphist picker
6. `waybar-weather` — wttr.in weather (curls every 1800s)

These polling-based scripts are exactly the kind of thing QuickShell replaces with native reactive bindings.

---

## Replacement Analysis

### CAN Replace (built-in QuickShell support)

| # | Current | QuickShell Module | Impact | Effort |
|---|---------|-------------------|--------|--------|
| 1 | **No OSD** | `Pipewire` + `UPower` native bindings | **HIGH** — new capability, currently missing | Medium |
| 2 | **Waybar** | `PanelWindow` + native Pipewire/MPRIS/Network | **HIGH** — eliminates 6 polling scripts, unified reactive UI | High |
| 3 | **Dunst** | `NotificationServer` | **MEDIUM** — shared theme with bar, tighter integration | Low |
| 4 | **wlogout** | `FloatingWindow` power menu | **MEDIUM** — unified theme | Low |
| 5 | **Rofi** (launcher) | `DesktopEntries` + `PopupWindow` | **MEDIUM** — native app launcher | Medium |
| 6 | **swaylock-effects** | `WlSessionLock` + `PamContext` | **LOW** — works fine, cosmetic upgrade | Medium |

### COULD Replace (but risky/low-value)

| Component | Why Not |
|-----------|---------|
| SDDM | Display manager works fine, QuickShell Greetd integration is experimental |
| awww wallpaper | Custom daemon already works, no native QuickShell wallpaper setter |
| Niri compositor | QuickShell is a shell toolkit, not a compositor |

### SHOULD NOT Replace

| Component | Reason |
|-----------|--------|
| swayidle | QuickShell has `IdleInhibitor`/`IdleMonitor` but not idle action management |
| grim/slurp/swappy | Screenshots are compositor-level, not shell |
| cliphist | Clipboard management is separate from shell UI |
| niri-session-manager | Window save/restore is orthogonal to shell |
| Rofi calc/emoji | rofi-calc and rofi-emoji have no QuickShell equivalent |

---

## Recommended Execution Plan

### Phase 1: Foundation (Day 1)

1. Add QuickShell flake input to `flake.nix`
2. Create `modules/nixos/services/quickshell.nix` — flake-parts module
3. Install qml-niri plugin for Niri integration
4. Add systemd user service for QuickShell startup
5. Verify QuickShell launches alongside existing desktop

### Phase 2: Bar (Day 1-2)

6. Build QuickShell bar replacing Waybar:
   - Left: workspace indicator (qml-niri), focused window title
   - Center: clock, media controls (MPRIS native)
   - Right: volume (Pipewire native), network (NM native), CPU/RAM, tray
7. Port custom widgets:
   - Camera status → call emeet-pixyd from QML
   - DNS stats → HTTP request from QML
   - Clipboard → cliphist integration from QML
   - Weather → HTTP fetch from QML
8. Apply Catppuccin Mocha theme
9. **Disable Waybar**, enable QuickShell bar

### Phase 3: OSD (Day 2)

10. Add Pipewire OSD — volume overlay on media key press
11. Add brightness OSD — via `ddcutil` or `brightnessctl` subprocess
12. Wire to existing XF86 keybinds (remove from niri config, handle in QuickShell)

### Phase 4: Notifications (Day 2-3)

13. Build notification daemon using `NotificationServer`
14. Match Dunst behavior: 3 urgency levels, timeout, actions
15. Catppuccin Mocha styling matching bar
16. **Disable Dunst**

### Phase 5: Power Menu + Launcher (Day 3)

17. Build power menu FloatingWindow (lock/hibernate/logout/shutdown/suspend/reboot)
18. Build app launcher PopupWindow with DesktopEntries
19. **Disable wlogout**
20. Keep Rofi installed for calc/emoji modes, or port those too

### Phase 6: Polish (Day 3+)

21. Lockscreen (optional — swaylock works fine)
22. System tray customization
23. Bluetooth panel
24. Network panel (WiFi list, etc.)
25. Hot-reload development workflow documentation

---

## Nix Module Sketch

```nix
# modules/nixos/services/quickshell.nix
{config, lib, pkgs, inputs, ...}: let
  cfg = config.services.quickshell;
in {
  options.services.quickshell = {
    enable = lib.mkEnableOption "QuickShell desktop shell";
    config = lib.mkOption {
      type = lib.types.path;
      description = "Path to QuickShell QML configuration directory";
    };
  };

  config = lib.mkIf cfg.enable {
    # Disable conflicting services
    programs.waybar.enable = false;
    services.dunst.enable = false;

    # QuickShell package with Qt modules
    environment.systemPackages = [
      (inputs.quickshell.packages.${pkgs.stdenv.system}.default.withModules [
        pkgs.qt6.qtsvg
        pkgs.qt6.qtimageformats
        pkgs.qt6.qtmultimedia
        pkgs.qt6.qt5compat
      ])
    ];

    # Systemd user service
    systemd.user.services.quickshell = {
      Unit = {
        Description = "QuickShell desktop shell";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/quickshell -p ${cfg.config}";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| QuickShell crashes → no bar | systemd auto-restart, keep wlogout/rofi as fallback |
| qml-niri plugin not in nixpkgs | Build from source or use flake |
| Learning curve for QML | Hot-reload makes iteration fast, LSP helps |
| Losing rofi-calc/rofi-emoji | Keep Rofi installed alongside, bind different keys |
| Waybar muscle memory | Can run both temporarily during migration |

---

## Reference Projects

| Project | Description | URL |
|---------|-------------|-----|
| iNiR | Full Niri shell, Material You theming, 5 visual styles | https://github.com/snowarch/iNiR |
| quickshell-niri | Example Niri configs for QuickShell | https://github.com/imiric/quickshell-niri |
| qml-niri | QML plugin for Niri IPC | https://github.com/imiric/qml-niri |
| DankMaterialShell | Modular shell for Niri/Hyprland | https://github.com/AvengeMedia/DankMaterialShell |
| Noctalia | Minimal Niri shell | https://github.com/jaytaph/noctalia |
