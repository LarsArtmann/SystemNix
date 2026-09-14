# Setup-Mac Desktop Improvement Roadmap

> Ghost Systems Type-Safe Configuration
> Comprehensive Hyprland + Waybar Enhancement Plan

## 📋 Overview

This roadmap outlines potential improvements for the Setup-Mac NixOS desktop environment,
focusing on the Hyprland window manager, Waybar status bar, and overall productivity.

Improvements are organized by priority and implementation phase.

---

## 🎯 Phase 1: High Priority Improvements

### 1.1 Hyprland Configuration Reloader

**Problem**: Config changes require a full session restart

**Solution**: Add hot-reload capability with keybinding

```nix
# Ctrl+Alt+R to reload Hyprland config
"bind = $mod SHIFT, R, exec, pkill -SIGUSR1 Hyprland"
```

**Files**: `platforms/nixos/desktop/hyprland.nix`
**Impact**: ⭐⭐⭐⭐
**Complexity**: Low

---

### 1.2 Privacy & Screen Locking

**Improvements**:

- Blur effect for lock screen (using hyprlock blur)
- Privacy mode (grayscale screen toggle)
- Screenshot detection indicator in Waybar
- Lock screen with camera preview

**Features**:

- Per-workspace privacy mode
- Temporary privacy toggle (Ctrl+Alt+P)
- Visual feedback when taking screenshots

**Files**:

- `platforms/nixos/desktop/hyprland.nix`
- `platforms/nixos/desktop/waybar.nix`
- `platforms/nixos/desktop/security-hardening.nix`

**Impact**: ⭐⭐⭐⭐
**Complexity**: Medium

---

### 1.3 Productivity Scripts

**Scripts to add**:

1. **Quake Terminal** - Dropdown terminal (F12)
2. **Screenshot + OCR** - Extract text from screenshots
3. **Color Picker** - Pick screen color, save to clipboard
4. **Clipboard History Viewer** - View/copy paste history
5. **App Workspace Spawner** - Open app in specific workspace

**Keybindings**:

```nix
"bind = $mod, P, exec, ~/scripts/quake-terminal.sh"
"bind = $mod, S, exec, ~/scripts/screenshot-ocr.sh"
"bind = $mod, C, exec, ~/scripts/color-picker.sh"
"bind = $mod, V, exec, ~/scripts/clipboard-viewer.sh"
```

**Files**: Create `platforms/nixos/desktop/scripts.nix`
**Impact**: ⭐⭐⭐⭐
**Complexity**: Medium

---

### 1.4 Monitoring Improvements

**Waybar Modules to add**:

- GPU temperature (AMD GPU integration)
- CPU usage (per-core)
- Memory usage (with used/total)
- Network bandwidth (up/down speed)
- Disk usage (for key mount points)

**Implementation**:

```json
"custom/gpu": {
  "exec": "sensors | grep 'Tctl' | awk '{print $2}'",
  "interval": 2,
  "format": "🌡️ {}°C"
}
```

**Files**:

- `platforms/nixos/desktop/waybar.nix`
- `platforms/nixos/desktop/monitoring.nix`

**Impact**: ⭐⭐⭐
**Complexity**: Medium

---

### 1.5 Window Management Enhancements

**Features**:

- **Scratchpad Workspaces** - Temporary windows (Alt+S)
- **Better Floating Rules** - Size and position defaults
- **Focus Follows Mouse** - Mouse movement controls focus
- **Auto Back-and-Forth** - Toggle workspace with same key

**Configuration**:

```nix
# Scratchpad
"bind = $mod, S, togglespecialworkspace, scratchpad"

# Focus follows mouse (optional)
general.focus_follows_mouse = 1

# Auto back-and-forth
binds.allow_workspace_cycles = true
```

**Files**: `platforms/nixos/desktop/hyprland.nix`
**Impact**: ⭐⭐⭐⭐
**Complexity**: Low

---

## 🎯 Phase 2: Medium Priority Improvements

### 2.1 Keyboard & Input

**Improvements**:

- Keyboard repeat rate optimization (faster typing)
- Caps Lock as Escape/Control
- Keyboard layout switcher indicator in Waybar
- Trackpad gesture improvements (3-finger swipe)

**Configuration**:

```nix
# Caps Lock as Escape
input.kb_options = "caps:escape"

# Keyboard repeat
input.repeat_rate = 50
input.repeat_delay = 200
```

**Files**:

- `platforms/nixos/desktop/hyprland.nix`
- `platforms/nixos/desktop/waybar.nix`

**Impact**: ⭐⭐⭐
**Complexity**: Low

---

### 2.2 Audio & Media

**Waybar Modules**:

- Audio visualizer (real-time)
- Microphone status indicator
- Media player integration (Now playing)
- Volume control with visual feedback

**Features**:

- Per-app volume control
- Noise suppression toggle
- Bluetooth device switcher

**Files**:

- `platforms/nixos/desktop/waybar.nix`
- `platforms/nixos/desktop/audio.nix`

**Impact**: ⭐⭐
**Complexity**: Medium

---

### 2.3 Development Tools

**Enhancements**:

- Git branch display in Waybar
- Terminal multiplexer integration (tmux/zellij)
- Editor-specific window rules (nvim/vscode)
- Dev environment launcher

**Waybar Integration**:

```json
"custom/git": {
  "exec": "git rev-parse --abbrev-ref HEAD",
  "exec-if": "git rev-parse --abbrev-ref HEAD 2>/dev/null",
  "interval": 10
}
```

**Files**:

- `platforms/nixos/desktop/waybar.nix`
- `platforms/nixos/desktop/hyprland.nix`

**Impact**: ⭐⭐⭐
**Complexity**: Medium

---

### 2.4 Desktop Environment

**Improvements**:

- Better window borders and shadows
- Animation tuning (smoother transitions)
- Workspace naming persistence (remember names)
- Application autostart management

**Configuration**:

```nix
decoration {
  drop_shadow = yes;
  shadow_range = 4;
  shadow_render_power = 3;
  col.shadow = 0xee1a1a1a;
}

animations {
  enabled = yes;
  bezier = easeOutQuint,0.05,0.9,0.1,1.05;
  animation = windows,1,7,easeOutQuint;
}
```

**Files**:

- `platforms/nixos/desktop/hyprland.nix`
- `platforms/nixos/system/configuration.nix`

**Impact**: ⭐⭐
**Complexity**: Low

---

## 🎯 Phase 3: Long-term Enhancements

### 3.1 Backup & Configuration

**Features**:

- Automated config backups (hourly/daily)
- Workspace state preservation (remember open apps)
- One-click config sync (multiple machines)
- Config versioning with rollback

**Implementation**:

```bash
# Backup script
~/.config/backup-desktop.sh
# Backs up hyprland, waybar, kitty, nvim configs
```

**Files**: Create `platforms/nixos/desktop/backup.nix`
**Impact**: ⭐⭐⭐
**Complexity**: High

---

### 3.2 Gaming & Performance

**Features**:

- Game mode toggle (disable compositor effects)
- GPU optimization profiles
- Frame rate statistics in Waybar
- Game-specific workspace themes

**Keybindings**:

```nix
# Game mode (Ctrl+Alt+G)
"bind = $mod SHIFT, G, exec, ~/scripts/game-mode.sh"
```

**Files**:

- `platforms/nixos/desktop/hyprland.nix`
- `platforms/nixos/desktop/waybar.nix`
- `platforms/hardware/amd-gpu.nix`

**Impact**: ⭐⭐
**Complexity**: Medium

---

### 3.3 Advanced Window Rules

**Features**:

- Auto-group similar windows (tabs)
- Per-application layout rules
- Smart window positioning
- Window grouping by workflow

**Configuration**:

```nix
# Auto-group browser windows
windowrulev2 = group, class:^(firefox)$
windowrulev2 = group barred, class:^(firefox)$
```

**Files**: `platforms/nixos/desktop/hyprland.nix`
**Impact**: ⭐⭐
**Complexity**: Medium

---

### 3.4 AI Integration

**Features**:

- AI-powered workspace suggestions
- Smart window arrangement
- Voice command integration
- Activity-based automation

**Files**: Create `platforms/nixos/desktop/ai-assist.nix`
**Impact**: ⭐
**Complexity**: High

---

## 📊 Priority Matrix

| Improvement          | Impact   | Complexity | Time | Phase |
| -------------------- | -------- | ---------- | ---- | ----- |
| Config Reloader      | ⭐⭐⭐⭐ | Low        | 10m  | 1     |
| Privacy Features     | ⭐⭐⭐⭐ | Medium     | 1h   | 1     |
| Productivity Scripts | ⭐⭐⭐⭐ | Medium     | 2h   | 1     |
| Monitoring           | ⭐⭐⭐   | Medium     | 1.5h | 1     |
| Window Management    | ⭐⭐⭐⭐ | Low        | 30m  | 1     |
| Keyboard             | ⭐⭐⭐   | Low        | 20m  | 2     |
| Audio & Media        | ⭐⭐     | Medium     | 1h   | 2     |
| Dev Tools            | ⭐⭐⭐   | Medium     | 1h   | 2     |
| Desktop Environment  | ⭐⭐     | Low        | 30m  | 2     |
| Backup System        | ⭐⭐⭐   | High       | 3h   | 3     |
| Gaming Mode          | ⭐⭐     | Medium     | 2h   | 3     |
| Advanced Rules       | ⭐⭐     | Medium     | 1h   | 3     |
| AI Integration       | ⭐       | High       | 8h+  | 3     |

---

## 🚀 Implementation Order

### Week 1: Quick Wins (Phase 1)

1. Config Reloader (10m)
2. Window Management (30m)
3. Keyboard & Input (20m)
4. Desktop Environment (30m)

### Week 2: Productivity Boost (Phase 1-2)

1. Productivity Scripts (2h)
2. Development Tools (1h)
3. Monitoring Improvements (1.5h)
4. Audio & Media (1h)

### Week 3: Security & Privacy (Phase 1)

1. Privacy Features (1h)
2. Advanced Window Rules (1h)

### Week 4+: Long-term (Phase 3)

1. Backup System (3h)
2. Gaming Mode (2h)
3. AI Integration (8h+)

---

## 📁 File Structure

After implementation, the desktop modules will be:

```
platforms/nixos/desktop/
├── hyprland.nix              # Hyprland WM config
├── waybar.nix                # Status bar config
├── scripts.nix               # Productivity scripts
├── audio.nix                 # Audio configuration
├── monitoring.nix             # System monitoring
├── backup.nix                # Config backup system
├── ai-assist.nix             # AI-powered features
└── security-hardening.nix    # Privacy & security
```

---

## 🔗 Related Documentation

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Configuration](https://github.com/Alexays/Waybar/wiki)
- [Ghost Systems Hyprland Research](./HYPRLAND-COMPREHENSIVE-RESEARCH-REPORT.md)
- [Type Safety Framework](../common/core/HyprlandTypes.nix)

---

## 💘 Generated with Crush

**Assisted-by**: GLM-4.7 via Crush <crush@charm.land>

**Last Updated**: 2026-01-10

---

## 📝 Notes

- All improvements maintain Ghost Systems type-safety standards
- Use HyprlandTypes.nix for validation
- Test thoroughly before committing to master
- Document new keybindings in user-friendly format
