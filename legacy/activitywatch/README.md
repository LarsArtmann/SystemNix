# ActivityWatch Configuration

This directory contains ActivityWatch configuration and utilities for both macOS (Darwin) and NixOS (Linux).

## Watchers

### Built-in Watchers

| Watcher             | Description                         | NixOS   | macOS   |
| ------------------- | ----------------------------------- | ------- | ------- |
| `aw-watcher-afk`    | AFK detection (keyboard/mouse idle) | ✅ Auto | ✅ Auto |
| `aw-watcher-window` | Window tracking                     | ✅ Auto | ✅ Auto |

### Custom Watchers

| Watcher                  | Description                      | NixOS   | macOS     |
| ------------------------ | -------------------------------- | ------- | --------- |
| `aw-watcher-utilization` | CPU, RAM, disk, network, sensors | ✅ Auto | ⚠️ Manual |

## aw-watcher-utilization

Monitors system resource utilization and sends data to ActivityWatch.

**Data collected:**

- CPU: Usage per core, times, frequency, load average
- Memory: Virtual memory, swap usage
- Disk: Usage, I/O counters
- Network: Per-interface I/O stats
- Sensors: Temperatures, fan speeds, battery

### NixOS (Automatic)

On NixOS, `aw-watcher-utilization` is automatically installed and configured via Home Manager:

```nix
# In platforms/common/programs/activitywatch.nix
aw-watcher-utilization = {
  package = pkgs.aw-watcher-utilization;
  settings = {
    poll_time = 5;  # seconds
  };
};
```

The watcher runs as a systemd user service managed by Home Manager.

### macOS (Manual)

On macOS, ActivityWatch is installed via Homebrew, so custom watchers need manual installation:

```bash
# Install the watcher
just activitywatch-install-utilization

# Or manually
pip3 install --user aw-watcher-utilization
```

After installation:

1. Add to `~/Library/Application Support/activitywatch/aw-qt/aw-qt.toml`:
   ```toml
   [aw-qt]
   autostart_modules = ["aw-server", "aw-watcher-afk", "aw-watcher-window", "aw-watcher-utilization"]
   ```
2. Restart ActivityWatch: `just activitywatch-stop && just activitywatch-start`

## Configuration Files

| File                       | Purpose                                 |
| -------------------------- | --------------------------------------- |
| `fix-permissions.sh`       | Reset macOS Accessibility permissions   |
| `tcc-profile.mobileconfig` | macOS TCC profile for permissions       |
| `install-utilization.sh`   | Install aw-watcher-utilization on macOS |

## Commands

| Command                                  | Description                         |
| ---------------------------------------- | ----------------------------------- |
| `just activitywatch-start`               | Start ActivityWatch (macOS)         |
| `just activitywatch-stop`                | Stop ActivityWatch (macOS)          |
| `just activitywatch-fix-permissions`     | Fix Accessibility permissions       |
| `just activitywatch-install-utilization` | Install utilization watcher (macOS) |

## Resources

- [aw-watcher-utilization](https://github.com/Alwinator/aw-watcher-utilization) - System utilization watcher
- [ActivityWatch Docs](https://docs.activitywatch.net/) - Official documentation
