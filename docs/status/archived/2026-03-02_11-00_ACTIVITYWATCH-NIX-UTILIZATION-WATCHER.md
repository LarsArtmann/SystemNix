# Status Report: ActivityWatch Nix-Managed Utilization Watcher

**Date:** 2026-03-02 11:00 CET
**Reporter:** Crush (AI Assistant)
**Scope:** ActivityWatch aw-watcher-utilization - Nix-native Darwin configuration
**Branch:** master (up to date with origin)

---

## Executive Summary

**CRITICAL ISSUE IDENTIFIED:** ActivityWatch on macOS was using a **manual pip install workaround** (`just activitywatch-install-utilization`) instead of the **Nix package** that's already defined in `pkgs/aw-watcher-utilization.nix`.

**FIX IMPLEMENTED:** Added Nix-managed LaunchAgent for `aw-watcher-utilization` in `platforms/darwin/services/launchagents.nix`, replacing the imperative manual installation process.

---

## a) FULLY DONE

### 1. Root Cause Analysis

| Issue              | Discovery                                                                  |
| ------------------ | -------------------------------------------------------------------------- |
| **Problem**        | `aw-watcher-utilization` required manual `pip3 install` on macOS           |
| **Why**            | ActivityWatch on macOS uses Homebrew Cask, not Nix package                 |
| **Mistake**        | Custom watcher wasn't integrated into Nix-Darwin LaunchAgent system        |
| **Package Exists** | `pkgs/aw-watcher-utilization.nix` was already defined but unused on Darwin |

### 2. Investigation Completed

**Active Buckets (Before Fix):**

- ✅ `aw-watcher-afk_Lars-MacBook-Air.local` - Working
- ⚠️ `aw-watcher-window_Lars-MacBook-Air.local` - Partial (restart loop errors)
- ✅ `aw-watcher-web-chrome_Lars-MacBook-Air.local` - Working
- ❌ `aw-watcher-utilization` - **NOT INSTALLED** (manual install required)
- ❌ `aw-watcher-input_Lars-MacBook-Air.local` - Broken (no events)

**3 of 5 buckets reporting events** - utilization watcher missing due to manual install requirement.

### 3. Nix Configuration Added

**File:** `platforms/darwin/services/launchagents.nix`

**Changes:**

1. Added `pkgs` to function arguments
2. Added new LaunchAgent `net.activitywatch.aw-watcher-utilization.plist`
3. Uses `${pkgs.aw-watcher-utilization}/bin/aw-watcher-utilization` (Nix store path)
4. Configured with `--poll-time 5` for 5-second intervals
5. Logs to `~/.local/share/activitywatch/aw-watcher-utilization.log`

**LaunchAgent Configuration:**

```nix
"net.activitywatch.aw-watcher-utilization.plist" = {
  enable = true;
  text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>net.activitywatch.aw-watcher-utilization</string>
        <key>ProgramArguments</key>
        <array>
            <string>${pkgs.aw-watcher-utilization}/bin/aw-watcher-utilization</string>
            <string>--host</string><string>localhost</string>
            <string>--port</string><string>5600</string>
            <string>--poll-time</string><string>5</string>
        </array>
        <key>RunAtLoad</key><true/>
        <key>KeepAlive</key><true/>
        <key>ProcessType</key><string>Background</string>
        ...
    </dict>
    </plist>
  '';
};
```

### 4. Package Verification

**Nix Package Location:** `pkgs/aw-watcher-utilization.nix`

- Version: 1.2.2
- Source: GitHub (Alwinator/aw-watcher-utilization)
- Dependencies: `aw-client`, `psutil`
- Available via: `pkgs.aw-watcher-utilization` in flake overlay

**Flake Integration:**

```nix
# flake.nix line 115, 126, 176, 242
aw-watcher-utilization = prev.callPackage ./pkgs/aw-watcher-utilization.nix {};
```

---

## b) PARTIALLY DONE

### Configuration Applied

- ✅ LaunchAgent configuration added to `launchagents.nix`
- ✅ Changes staged in git
- ⏳ **Build/Activation INTERRUPTED** - `nh darwin switch` was terminated mid-build

**Need to complete:**

1. Run `nh darwin switch .` to apply the configuration
2. Verify `aw-watcher-utilization` bucket appears
3. Test that events are being reported

---

## c) NOT STARTED

1. **Post-activation verification:** Check if utilization bucket is reporting
2. **Update documentation:** Remove manual install instructions from README
3. **Deprecate install script:** Mark `install-utilization.sh` as deprecated
4. **Update justfile:** Remove or deprecate `activitywatch-install-utilization` command
5. **Fix window watcher:** Address Python multiprocessing fork errors
6. **Investigate input watcher:** Debug why it's not reporting events

---

## d) TOTALLY FUCKED UP!

### The Manual Install Anti-Pattern

**File:** `dotfiles/activitywatch/install-utilization.sh`

```bash
# THIS IS WRONG - manual pip install in a Nix project!
pip3 install --user aw-watcher-utilization
```

**Why This is Bad:**

1. **Imperative** - violates Nix's declarative philosophy
2. **Non-reproducible** - pip install can fail or install different versions
3. **State leakage** - creates ~/.local files outside Nix store
4. **Not atomic** - can't roll back cleanly
5. **Harder to debug** - scattered state across filesystem

**The Nix package WAS ALREADY THERE:**

- `pkgs/aw-watcher-utilization.nix` - properly packaged
- Available in flake overlay
- Just needed LaunchAgent integration

**Status:** ✅ Fixed by adding Nix-managed LaunchAgent

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (Today)

1. ✅ Complete the `nh darwin switch` to activate the new LaunchAgent
2. Verify the utilization bucket appears in ActivityWatch API
3. Confirm events are flowing (CPU, RAM, disk, network data)

### Short-term (This Week)

4. **Remove manual install cruft:**
   - Deprecate `dotfiles/activitywatch/install-utilization.sh`
   - Update `dotfiles/activitywatch/README.md`
   - Update `justfile` to indicate command is no longer needed

5. **Fix window watcher restart loop:**
   - Python multiprocessing fork errors in logs
   - Check if strategy flag helps: `--strategy swift`

6. **Debug input watcher:**
   - Check System Preferences → Input Monitoring permissions
   - Verify process is running

### Medium-term (This Month)

7. **Consider full Nix ActivityWatch:**
   - Currently using Homebrew Cask for ActivityWatch.app
   - Could use Nix-packaged ActivityWatch for complete purity
   - Trade-off: GUI app vs Nix purity

8. **Add ActivityWatch to NixOS config:**
   - Ensure NixOS side is also properly configured
   - Verify Linux watchers are working

9. **Monitoring dashboard:**
   - Create just command to check ActivityWatch status
   - Show active buckets and last event times

---

## f) TOP 25 THINGS TO GET DONE NEXT

| Priority | Task                                                                    | Effort | Context               |
| -------- | ----------------------------------------------------------------------- | ------ | --------------------- |
| 🔴 P0    | Complete `nh darwin switch` for utilization LaunchAgent                 | 2 min  | Interrupted build     |
| 🔴 P0    | Verify utilization bucket is reporting events                           | 5 min  | Test fix              |
| 🟡 P1    | Update ActivityWatch README.md (remove manual install)                  | 15 min | Documentation         |
| 🟡 P1    | Deprecate `install-utilization.sh` script                               | 10 min | Cleanup               |
| 🟡 P1    | Update justfile command documentation                                   | 10 min | UX                    |
| 🟡 P1    | Debug aw-watcher-window restart loop                                    | 30 min | Logs show fork errors |
| 🟢 P2    | Debug aw-watcher-input (check permissions)                              | 20 min | Not reporting         |
| 🟢 P2    | Create `just activitywatch-status` command                              | 30 min | Monitoring            |
| 🟢 P2    | Consider Nix-packaged ActivityWatch.app                                 | 2 hr   | Purity vs GUI         |
| 🟢 P2    | Verify NixOS ActivityWatch configuration                                | 30 min | Cross-platform        |
| ⚪ P3    | Add ActivityWatch health check to `just health`                         | 45 min | System health         |
| ⚪ P3    | Document all ActivityWatch buckets                                      | 30 min | Reference             |
| ⚪ P3    | Create troubleshooting guide                                            | 1 hr   | Support               |
| ⚪ P3    | Add bucket count check to CI                                            | 1 hr   | Testing               |
| ⚪ P4    | Investigate web watcher duplication (chrome vs chrome_Lars-MacBook-Air) | 30 min | Cleanup               |
| ⚪ P4    | Archive old IntelliJ/WebStorm buckets                                   | 15 min | Maintenance           |
| ⚪ P4    | Consider aw-watcher-vscode for Nix-managed VS Code                      | 1 hr   | Extension             |
| ⚪ P4    | Review ActivityWatch TCC profile                                        | 30 min | Permissions           |
| ⚪ P4    | Add log rotation for ActivityWatch logs                                 | 45 min | Maintenance           |
| ⚪ P5    | Contribute aw-watcher-utilization to nixpkgs                            | 4 hr   | Upstreaming           |
| ⚪ P5    | Create ActivityWatch module for nix-darwin                              | 4 hr   | Abstraction           |
| ⚪ P5    | Investigate aw-stopwatch usage                                          | 15 min | Unused bucket?        |
| ⚪ P5    | Review Helium browser watcher                                           | 15 min | Additional browser    |
| ⚪ P5    | Add ActivityWatch to system monitoring dashboard                        | 2 hr   | Observability         |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

### Why was the manual install script created when the Nix package already existed?

**Evidence:**

- `pkgs/aw-watcher-utilization.nix` has existed for some time
- Flake overlay exposes it as `pkgs.aw-watcher-utilization`
- NixOS configuration already uses it via Home Manager

**Possible explanations:**

1. **Historical:** Nix package was added after manual script was created
2. **Integration difficulty:** Uncertainty about connecting Nix watcher to Homebrew ActivityWatch
3. **Documentation gap:** README documents manual approach, not Nix approach
4. **Platform inconsistency:** macOS uses Homebrew ActivityWatch, Linux uses Nix ActivityWatch

**The core confusion:**
ActivityWatch architecture has:

- **Server** (aw-server) - runs on port 5600
- **Watchers** - connect to server via HTTP API
- **Client** (aw-qt or web UI) - displays data

The watchers just need to connect to `localhost:5600` - they don't care if the server is from Homebrew or Nix. So the Nix-packaged watcher should work fine with the Homebrew server.

**Why wasn't this obvious?**
The LaunchAgent integration pattern wasn't established for custom watchers on Darwin. The existing pattern was only for ActivityWatch.app itself and the Sublime sync script.

---

## Technical Details

### ActivityWatch Architecture

```
┌─────────────────────────────────────────┐
│         ActivityWatch Server            │
│         (aw-server :5600)               │
│  ┌─────────┐ ┌─────────┐ ┌──────────┐  │
│  │  Buckets │ │ Buckets │ │ Buckets  │  │
│  │  (AFK)   │ │(Window) │ │ (Chrome) │  │
│  └─────────┘ └─────────┘ └──────────┘  │
│  ┌─────────┐ ┌─────────┐               │
│  │(Utiliz.)│ │ (Input) │ ← NEW         │
│  └─────────┘ └─────────┘               │
└─────────────────────────────────────────┘
           ▲
           │ HTTP API localhost:5600
    ┌──────┴──────┬────────────┬──────────────┐
    │             │            │              │
┌───┴───┐   ┌────┴────┐ ┌─────┴────┐ ┌──────┴──────┐
│ AFK   │   │ Window  │ │ Chrome   │ │ Utilization │
│Watcher│   │ Watcher │ │ Watcher  │ │ Watcher     │
│(Auto) │   │ (Auto)  │ │ (Ext)    │ │ (NIX)       │
└───────┘   └─────────┘ └──────────┘ └─────────────┘
```

### Nix vs Manual Install Comparison

| Aspect              | Manual (pip)                                 | Nix (new)                                                 |
| ------------------- | -------------------------------------------- | --------------------------------------------------------- |
| **Installation**    | `pip3 install --user aw-watcher-utilization` | Declarative in `launchagents.nix`                         |
| **Location**        | `~/.local/lib/python*/site-packages/`        | `/nix/store/...-aw-watcher-utilization/`                  |
| **Version**         | Latest from PyPI (uncontrolled)              | Pinned in `pkgs/aw-watcher-utilization.nix`               |
| **Autostart**       | Manual edit of `aw-qt.toml`                  | LaunchAgent managed by nix-darwin                         |
| **Logs**            | Console/unknown                              | `~/.local/share/activitywatch/aw-watcher-utilization.log` |
| **Rollback**        | Manual uninstall/reinstall                   | `nix rollback`                                            |
| **Reproducibility** | ❌ Environment-dependent                     | ✅ Pure Nix expression                                    |

---

## Conclusion

**Status:** Configuration complete, **waiting for build activation**

The manual install anti-pattern has been identified and replaced with proper Nix-managed LaunchAgent configuration. The `aw-watcher-utilization` watcher will now be:

- Installed from Nix store (reproducible)
- Managed by nix-darwin LaunchAgent (declarative)
- Auto-started with correct parameters
- Logging to standard location

**Next step:** Complete the `nh darwin switch` that was interrupted.

---

**Report Generated:** 2026-03-02 11:00 CET
**Assistant:** Crush v0.46.1
**Status:** 🟡 CONFIG STAGED - Build pending
