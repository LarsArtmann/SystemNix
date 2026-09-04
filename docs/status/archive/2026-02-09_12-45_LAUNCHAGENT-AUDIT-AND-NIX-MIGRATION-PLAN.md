# LaunchAgent Audit & Nix Migration Plan

**Date:** 2026-02-09 12:45
**Status:** Comprehensive Analysis Complete
**Scope:** All macOS LaunchAgents (User + System)

---

## Executive Summary

This report documents a complete audit of all LaunchAgents on the system, identifying:

- **1 Nix-managed service** (ActivityWatch)
- **6 Legacy imperative LaunchAgents** requiring migration
- **3 App-managed services** needing evaluation
- **2 Duplicate/conflicting services** requiring consolidation
- **2 External services** (outside Nix management scope)

**Recommendation:** Migrate all custom LaunchAgents to Nix for declarative, reproducible, version-controlled service management.

---

## Current State Inventory

### ✅ Nix-Managed (Gold Standard)

| Service           | Label                             | Management                                   | Health     |
| ----------------- | --------------------------------- | -------------------------------------------- | ---------- |
| **ActivityWatch** | `net.activitywatch.ActivityWatch` | `platforms/darwin/services/launchagents.nix` | ✅ Healthy |

**Features:**

- Declarative configuration
- Structured logging to `~/.local/share/activitywatch/`
- Configurable restart behavior
- Version controlled in Git

---

### ⚠️ Legacy Custom LaunchAgents (Migration Required)

These services run from imperative plist files in `~/Library/LaunchAgents/` and should be migrated to Nix.

#### 1. System Monitoring Stack

| Service     | Label               | Purpose                                       | Current Issues                     |
| ----------- | ------------------- | --------------------------------------------- | ---------------------------------- |
| **Netdata** | `com.netdata.agent` | Real-time system monitoring (localhost:19999) | Imperative config, hardcoded paths |
| **ntopng**  | `com.ntopng.daemon` | Network traffic analysis (localhost:3000)     | Runs as root, imperative config    |

**Current Configuration:**

```bash
# Netdata
Program: /run/current-system/sw/bin/netdata
Config: ~/monitoring/netdata/config/netdata.conf
Logs: ~/monitoring/netdata/logs/

# ntopng
Program: /run/current-system/sw/bin/ntopng
Config: ~/monitoring/ntopng/config/ntopng.conf
Logs: ~/monitoring/ntopng/logs/
```

**Migration Priority:** HIGH

#### 2. Maintenance Automation

| Service                | Label                              | Schedule       | Purpose                 |
| ---------------------- | ---------------------------------- | -------------- | ----------------------- |
| **Daily Maintenance**  | `com.setup-mac.daily-maintenance`  | 2:30 AM daily  | Cleanup, cache clearing |
| **Weekly Maintenance** | `com.setup-mac.weekly-maintenance` | 3:00 AM Sunday | Deep cleanup, updates   |

**Current Issues:**

- Scripts located at deprecated path: `~/Desktop/Setup-Mac/scripts/`
- Should be: `~/projects/SystemNix/scripts/`
- Imperative scheduling

**Migration Priority:** MEDIUM

#### 3. Browser/Editor Utilities

| Service           | Label                           | Schedule      | Purpose                      |
| ----------------- | ------------------------------- | ------------- | ---------------------------- |
| **Sublime Sync**  | `com.larsartmann.sublime-sync`  | 6:00 PM daily | Export Sublime Text settings |
| **uBlock Update** | `com.larsartmann.ublock-update` | 9:00 AM daily | Update ad-blocker filters    |

**Migration Priority:** LOW (evaluate if still needed)

#### 4. File Management (CRITICAL: DUPLICATES)

| Service                | Label                             | Type              | Issue     |
| ---------------------- | --------------------------------- | ----------------- | --------- |
| **Screenshot Renamer** | `com.screenshotrenamer.watcher`   | KeepAlive daemon  | DUPLICATE |
| **File Renamer**       | `com.user.file-and-image-renamer` | RunAtLoad service | DUPLICATE |

**Problem:** Both services run the same script: `~/.config/file-and-image-renamer/watch-wrapper.sh`

**Resolution:** Consolidate into single Nix-managed service.

**Migration Priority:** HIGH

#### 5. External Services (Out of Scope)

| Service                 | Label                          | Purpose                             | Action                            |
| ----------------------- | ------------------------------ | ----------------------------------- | --------------------------------- |
| **External AI Monitor** | `com.external.ai.monitor`      | Third-party AI workspace monitoring | Leave as-is (external dependency) |
| **Steam Clean**         | `com.valvesoftware.steamclean` | Steam cache management              | Evaluate if still needed          |

---

### 📦 App-Managed Services (Evaluation Required)

These are installed by applications and run outside Nix/Homebrew.

| Service               | Label                             | Source       | Recommendation                              |
| --------------------- | --------------------------------- | ------------ | ------------------------------------------- |
| **PostgreSQL**        | `homebrew.mxcl.postgresql@14`     | Homebrew     | ✅ Keep - standard Homebrew service         |
| **Podman Desktop**    | `io.podman_desktop.PodmanDesktop` | Podman.app   | ❓ Evaluate - do you actively use Podman?   |
| **Hyprnote**          | `Hyprnote`                        | Hyprnote.app | ❓ Evaluate - do you actively use Hyprnote? |
| **VPN by Google One** | `VPN by Google One`               | Google One   | ❓ Evaluate - do you actively use this VPN? |

---

### ✅ Recently Removed

| Service              | Action                                                     | Status                        |
| -------------------- | ---------------------------------------------------------- | ----------------------------- |
| Adobe Creative Cloud | Deleted `/Library/LaunchAgents/com.adobe.*`                | ✅ Complete                   |
| Adobe CCXProcess     | Deleted `/Library/LaunchAgents/com.adobe.ccxprocess.plist` | ✅ Complete                   |
| Sensei               | Pending full uninstall                                     | ⏳ Waiting for manual removal |

---

## Migration Strategy

### Phase 1: Foundation (Week 1)

**Goal:** Establish Nix module structure and migrate monitoring stack.

1. **Create LaunchAgent Module**

   ```
   platforms/darwin/modules/launchagents/
   ├── default.nix          # Module entry point
   ├── types.nix            # Type definitions
   ├── netdata.nix          # Netdata service
   ├── ntopng.nix           # ntopng service
   └── maintenance.nix      # Daily/weekly maintenance
   ```

2. **Define Types**

   ```nix
   types.launchAgent = {
     enable = mkEnableOption "service";
     schedule = mkOption { type = types.enum [ "startup" "interval" "calendar" ]; };
     program = mkOption { type = types.path; };
     arguments = mkOption { type = types.listOf types.str; default = []; };
     keepAlive = mkOption { type = types.bool; default = false; };
     logging = {
       stdout = mkOption { type = types.path; };
       stderr = mkOption { type = types.path; };
     };
   };
   ```

3. **Migrate Netdata**
   - Convert plist to `environment.userLaunchAgents`
   - Use existing config at `~/monitoring/netdata/`
   - Update `platforms/darwin/default.nix` imports

4. **Migrate ntopng**
   - Similar approach to Netdata
   - Note: Requires root privileges (use `launchd.daemons` instead)

**Impact:** High
**Effort:** 2-3 hours
**Risk:** Low (existing configs preserved)

---

### Phase 2: Consolidation (Week 2)

**Goal:** Clean up duplicates and migrate maintenance scripts.

1. **Consolidate File Renamers**
   - Create single `file-renamer.nix` module
   - Unload and delete both legacy plists
   - Single source of truth

2. **Migrate Maintenance Scripts**
   - Update script paths from `Desktop/Setup-Mac` to `projects/SystemNix`
   - Create Nix wrappers for `maintenance.sh` and `weekly-maintenance.sh`
   - Preserve existing schedule (2:30 AM daily, 3:00 AM Sunday)

3. **Standardize Logging**
   ```
   ~/.local/share/launchagents/
   ├── netdata/
   ├── ntopng/
   ├── maintenance/
   └── file-renamer/
   ```

**Impact:** High
**Effort:** 3-4 hours
**Risk:** Low

---

### Phase 3: Optional Utilities (Week 3)

**Goal:** Evaluate and optionally migrate browser/editor utilities.

1. **Evaluate Sublime Sync**
   - Is Sublime Text still your primary editor?
   - If yes: migrate to Nix
   - If no: deprecate and remove

2. **Evaluate uBlock Update**
   - Do you still use the custom uBlock Origin setup?
   - If yes: migrate to Nix
   - If no: deprecate and remove

3. **Evaluate App-Managed Services**
   - Hyprnote: Active use or trial?
   - Podman Desktop: Docker alternative or unused?
   - VPN by Google One: Active subscription?

**Impact:** Medium
**Effort:** 1-2 hours per service
**Risk:** Very Low

---

### Phase 4: Tooling & Observability (Week 4)

**Goal:** Add management utilities and documentation.

1. **Add `just` Commands**

   ```just
   launchagent-status    # Show all managed services
   launchagent-logs SERVICE  # Tail logs for service
   launchagent-migrate   # Generate Nix from existing plist
   ```

2. **Create Status Dashboard**
   - Shell script showing service status
   - Green/red indicators for running/stopped
   - Log file sizes
   - Last run timestamps

3. **Documentation**
   - Update `AGENTS.md` with LaunchAgent section
   - Migration guide for future services
   - Troubleshooting common issues

**Impact:** Medium
**Effort:** 4-5 hours
**Risk:** None

---

## Technical Implementation Details

### Module Structure

```nix
# platforms/darwin/modules/launchagents/default.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.launchagents;
in {
  options.services.launchagents = {
    enable = lib.mkEnableOption "declarative LaunchAgent management";

    netdata.enable = lib.mkEnableOption "Netdata monitoring";
    ntopng.enable = lib.mkEnableOption "ntopng network monitoring";
    maintenance.enable = lib.mkEnableOption "maintenance scripts";
  };

  config = lib.mkIf cfg.enable {
    environment.userLaunchAgents = lib.mkMerge [
      (lib.mkIf cfg.netdata.enable (import ./netdata.nix { inherit config pkgs; }))
      (lib.mkIf cfg.ntopng.enable (import ./ntopng.nix { inherit config pkgs; }))
      # ... etc
    ];
  };
}
```

### Type Safety

Leverage existing `platforms/common/core/` infrastructure:

```nix
# platforms/common/core/LaunchAgentTypes.nix
{ lib }:

{
  launchAgentConfig = lib.types.submodule {
    options = {
      Label = lib.mkOption { type = lib.types.str; };
      ProgramArguments = lib.mkOption { type = lib.types.listOf lib.types.str; };
      RunAtLoad = lib.mkOption { type = lib.types.bool; default = false; };
      KeepAlive = lib.mkOption { type = lib.types.either lib.types.bool (lib.types.attrsOf lib.types.bool); default = false; };
      StartCalendarInterval = lib.mkOption { type = lib.types.nullOr lib.types.attrs; default = null; };
      StandardOutPath = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; };
      StandardErrorPath = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; };
    };
  };
}
```

---

## Risks & Mitigations

| Risk                                  | Likelihood | Impact | Mitigation                                                |
| ------------------------------------- | ---------- | ------ | --------------------------------------------------------- |
| Service interruption during migration | Medium     | Medium | Test with `just test` before `just switch`; keep backups  |
| Path changes break scripts            | Low        | High   | Update script paths first; use symlinks during transition |
| Duplicate services conflict           | Medium     | High   | Unload legacy plists before activating Nix versions       |
| Root privileges for ntopng            | Certain    | Low    | Use `launchd.daemons` instead of `userLaunchAgents`       |
| External AI service dependency        | Low        | Medium | Leave as-is; document external dependencies               |

---

## Success Criteria

- [ ] All custom LaunchAgents migrated to Nix
- [ ] No duplicate services running
- [ ] All services have structured logging
- [ ] `just launchagent-status` shows green for all services
- [ ] Legacy plist files removed from `~/Library/LaunchAgents/`
- [ ] Documentation updated
- [ ] Git history shows atomic commits for each migration

---

## Next Actions

1. **Immediate:** Remove Sensei completely (manual uninstall)
2. **This Week:** Create LaunchAgent module structure
3. **This Week:** Migrate Netdata to Nix
4. **Next Week:** Migrate ntopng to Nix
5. **Next Week:** Consolidate file renamer services

---

## Appendix A: Complete File Inventory

### User LaunchAgents (`~/Library/LaunchAgents/`)

| File                                     | Size   | Modified   | Status         |
| ---------------------------------------- | ------ | ---------- | -------------- |
| `net.activitywatch.ActivityWatch.plist`  | 918 B  | 2026-01-20 | ✅ Nix-managed |
| `com.netdata.agent.plist`                | 1.3 KB | 2025-07-20 | ⚠️ Migrate      |
| `com.ntopng.daemon.plist`                | 1.5 KB | 2025-07-20 | ⚠️ Migrate      |
| `com.setup-mac.daily-maintenance.plist`  | 1.2 KB | 2025-07-20 | ⚠️ Migrate      |
| `com.setup-mac.weekly-maintenance.plist` | 1.3 KB | 2025-07-20 | ⚠️ Migrate      |
| `com.larsartmann.sublime-sync.plist`     | 858 B  | 2025-07-20 | ❓ Evaluate    |
| `com.larsartmann.ublock-update.plist`    | 785 B  | 2025-07-20 | ❓ Evaluate    |
| `com.screenshotrenamer.watcher.plist`    | 1.4 KB | 2026-01-27 | ⚠️ Consolidate  |
| `com.user.file-and-image-renamer.plist`  | 1.0 KB | 2026-01-27 | ⚠️ Consolidate  |
| `com.valvesoftware.steamclean.plist`     | 882 B  | 2024-12-16 | ❓ Evaluate    |
| `homebrew.mxcl.postgresql@14.plist`      | 929 B  | 2025-07-17 | ✅ Keep        |
| `io.podman_desktop.PodmanDesktop.plist`  | 940 B  | 2025-04-16 | ❓ Evaluate    |
| `Hyprnote.plist`                         | 415 B  | 2025-10-04 | ❓ Evaluate    |
| `VPN by Google One.plist`                | 472 B  | 2023-10-12 | ❓ Evaluate    |
| `com.external.ai.monitor.plist`          | 1.5 KB | 2025-02-07 | 🔌 External    |
| `environment.plist`                      | 420 B  | 2025-05-23 | 🔧 Nix env     |

### System LaunchAgents (`/Library/LaunchAgents/`)

| File                              | Status                           |
| --------------------------------- | -------------------------------- |
| `com.google.keystone.*`           | ✅ Google auto-update (keep)     |
| `com.citrix.*`                    | 🔌 Citrix (keep if using)        |
| `us.zoom.updater.*`               | 🔌 Zoom (keep if using)          |
| `org.cindori.SenseiMonitor.plist` | ❌ **REMOVE** (Sensei uninstall) |

---

## Appendix B: Related Documentation

- `AGENTS.md` - Project-wide agent guidelines
- `docs/verification/HOME-MANAGER-DEPLOYMENT-GUIDE.md` - Deployment patterns
- `platforms/darwin/services/launchagents.nix` - Current Nix implementation
- `docs/architecture/adr-001-home-manager-for-darwin.md` - Architecture decisions

---

**Report Generated:** 2026-02-09 12:45
**Author:** System Audit
**Next Review:** After Phase 1 completion
