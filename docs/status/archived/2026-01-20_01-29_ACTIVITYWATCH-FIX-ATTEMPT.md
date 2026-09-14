# ActivityWatch Fix Attempt Status Report

**Date:** 2026-01-20
**Time:** 01:29 CET
**Status:** 🟡 PARTIALLY WORKING - Watchers Not Tracking
**Duration:** ~30 minutes troubleshooting session

---

## 📋 Executive Summary

ActivityWatch LaunchAgent configuration was fixed (invalid `--background` flag replaced with `--no-gui`), and all processes are now running correctly. However, the watchers (aw-watcher-window and aw-watcher-afk) are not actually tracking programs or updating the database, despite being in running state.

**Root Cause:** Invalid command-line flag preventing aw-qt from starting
**Current Issue:** Watchers running silently but not collecting data
**Status:** 50% - Configuration fixed, but tracking not working

---

## 🎯 Objectives

1. ✅ **Identify** why ActivityWatch stopped reporting programs on macOS
2. ✅ **Fix** the LaunchAgent configuration issue
3. ⚠️ **Verify** that ActivityWatch is tracking programs correctly
4. ❌ **Test** that data is being collected and stored in database

---

## 🔍 Root Cause Analysis

### Initial Problem

- **Symptom:** ActivityWatch not reporting programs in use on macOS
- **Discovery:** Check `~/.local/share/activitywatch/stderr.log`
- **Finding:** Repeated error: `Error: No such option: --background`
- **Count:** ~100+ occurrences of the error (97,000 lines in log file)

### Root Cause

- **Invalid Flag:** LaunchAgent was using `--background` flag which doesn't exist in `aw-qt`
- **Location:** `platforms/darwin/services/launchagents.nix:26`
- **Incorrect:** `<string>--background</string>`
- **Correct:** `<string>--no-gui</string>`

### Why This Happened

- The `aw-qt` command has changed over time
- The `--background` flag was never valid for `aw-qt`
- Valid flags per `aw-qt --help`:
  - `--testing` - Run in testing mode
  - `--verbose` - Run with debug logging
  - `--autostart-modules TEXT` - Comma-separated list of modules
  - `--no-gui` - Start without GUI (what we need)
  - `--interactive` - Start in interactive CLI mode

---

## 🔧 Actions Taken

### 1. Configuration Fix

**File:** `platforms/darwin/services/launchagents.nix`
**Change:** Line 26

```nix
# Before
<string>--background</string>

# After
<string>--no-gui</string>
```

### 2. Nix Configuration Applied

**Command:** `just switch`
**Result:** ✅ Success

- LaunchAgent plist updated to `/Users/larsartmann/Library/LaunchAgents/net.activitywatch.ActivityWatch.plist`
- Service reloaded automatically by nix-darwin

### 3. Process Cleanup

**Commands:**

```bash
pkill -9 -f "aw-(qt|server|watcher)"
launchctl kickstart -k gui/$(id -u)/net.activitywatch.ActivityWatch
```

**Result:** ✅ All zombie processes killed and restarted

---

## 📊 Current State

### Process Status ✅

All 5 required processes are running:

| PID   | Process                 | State        | Parent            | Description                  |
| ----- | ----------------------- | ------------ | ----------------- | ---------------------------- |
| 23658 | aw-qt                   | R (running)  | launchd           | Main manager process         |
| -     | aw-server               | S (sleeping) | aw-qt             | API server (Flask)           |
| -     | aw-watcher-window       | S (sleeping) | aw-qt             | Window activity tracker      |
| -     | aw-watcher-window-macos | S (sleeping) | aw-watcher-window | Swift subprocess             |
| -     | aw-watcher-afk          | S (sleeping) | aw-qt             | AFK (keyboard/mouse) tracker |

### Network Status ✅

- **Port 5600:** ✅ LISTENING
- **Server:** aw-server (Flask)
- **Command:** `lsof -i :5600` confirms `aw-server 22872 larsartmann 8u IPv4 TCP localhost:esmmanager (LISTEN)`

### LaunchAgent Status ✅

- **Label:** `net.activitywatch.ActivityWatch`
- **Status:** Active (PID 23658)
- **Launch Command:** `/Applications/ActivityWatch.app/Contents/MacOS/aw-qt --no-gui`
- **KeepAlive:** Enabled
- **RunAtLoad:** Enabled

### Database Status ⚠️

- **File:** `~/Library/Application Support/activitywatch/aw-server/peewee-sqlite.v2.db`
- **Size:** 364 MB
- **Last Modified:** 2026-01-20 01:08
- **Current Time:** 2026-01-20 01:29
- **Issue:** No updates in ~20 minutes (database not growing)

### Log Status ❌

- **Stdout:** `~/.local/share/activitywatch/stdout.log` (52 bytes)
  - Last entry: `* Debug mode: off`
  - Status: ✅ Aw-server started

- **Stderr:** `~/.local/share/activitywatch/stderr.log` (2.1 MB, 97,100 lines)
  - Last entries (01:08:46-01:08:48):
    ```
    2026-01-20 01:08:46 [INFO ]: Starting module aw-watcher-window  (aw_qt.manager:148)
    2026-01-20 01:08:46 [INFO ]: macOS: Disable dock icon  (aw_qt.manager:162)
    2026-01-20 01:08:48 [INFO ]: Starting module aw-watcher-afk  (aw_qt.manager:148)
    2026-01-20 01:08:48 [INFO ]: macOS: Disable dock icon  (aw_qt.manager:162)
    ```
  - **Issue:** No "started" or "connection established" messages
  - **Issue:** No new log entries since 01:08:48 (21+ minutes ago)

---

## 🔬 Investigation Results

### Expected Behavior (Previous Working State)

Looking at logs from 00:29-00:31, a working session showed:

```
2026-01-20 00:29:47 [INFO ]: Starting module aw-watcher-window
2026-01-20 00:31:01 [INFO ]: aw-watcher-window started  (aw_watcher_window.main:70)
2026-01-20 00:31:03 [INFO ]: Using swift strategy, calling out to swift binary
2026-01-20 00:31:06 [INFO ]: Connection to aw-server established by aw-watcher-window
```

### Current Behavior (Not Working)

Current session (01:08-01:29) shows:

```
2026-01-20 01:08:46 [INFO ]: Starting module aw-watcher-window
[NO "aw-watcher-window started" message]
[NO "Using swift strategy" message]
[NO "Connection established" message]
```

### Key Differences

| Behavior                           | Previous (Working) | Current (Broken) |
| ---------------------------------- | ------------------ | ---------------- |
| aw-watcher-window starts           | ✅ Yes             | ✅ Yes           |
| "aw-watcher-window started" logged | ✅ Yes             | ❌ No            |
| Swift strategy message             | ✅ Yes             | ❌ No            |
| Connection established             | ✅ Yes             | ❌ No            |
| Database updating                  | ✅ Yes             | ❌ No            |

---

## 🚨 Identified Issues

### 1. Silent Watcher Failure ❌

**Severity:** Critical
**Description:** Watchers are running but not functioning
**Evidence:**

- Processes in S (sleeping) state
- No "started" or "connection" logs
- Database not updating
- No program data being collected

### 2. Missing Startup Logs ❌

**Severity:** High
**Description:** Watcher startup sequence incomplete in logs
**Expected:**

```
aw-watcher-window started
Using swift strategy
Connection to aw-server established
```

**Actual:** None of these messages appear

### 3. Log File Bloat ⚠️

**Severity:** Medium
**Description:** stderr.log is 2.1 MB with 97,100 lines
**Issue:** Contains thousands of repeated `--background` errors
**Risk:** File will continue growing without rotation

### 4. No Health Monitoring ❌

**Severity:** High
**Description:** No way to verify if ActivityWatch is actually tracking
**Impact:** Silent failures go undetected for extended periods

---

## 🎯 Possible Root Causes (Current Tracking Issue)

### Hypothesis 1: macOS Permission Denied 🔐

**Likelihood:** High
**Explanation:** ActivityWatch requires Accessibility and Screen Recording permissions
**Evidence:**

- Swift strategy relies on macOS APIs
- Silent failure is typical of permission issues
- Previous successful runs may have had permissions

**Verification Needed:**

- Check System Preferences → Privacy & Security → Accessibility
- Check System Preferences → Privacy & Security → Screen Recording
- Look for denies in Console.app

### Hypothesis 2: Swift Strategy Failure 💻

**Likelihood:** Medium
**Explanation:** `aw-watcher-window` uses Swift strategy to track windows
**Evidence:**

- Last working log: `Using swift strategy`
- Previous errors: `unrecognized arguments: --multiprocessing-fork`
- Swift subprocess exists but may be failing silently

**Verification Needed:**

- Try JXA strategy as fallback: `--strategy jxa`
- Check Swift binary compatibility with macOS version
- Review ActivityWatch Swift strategy issues on GitHub

### Hypothesis 3: Database Lock/Corruption 💾

**Likelihood:** Low
**Explanation:** Database may be locked or corrupted
**Evidence:**

- Database not updating since 01:08
- Previous "Address already in use" error for port 5600
- 364 MB database (large but not suspicious)

**Verification Needed:**

- Check database locks: `lsof ~/Library/Application Support/activitywatch/aw-server/peewee-sqlite.v2.db`
- Test database integrity with SQLite
- Try stopping aw-server and checking locks

### Hypothesis 4: Version Incompatibility 🔄

**Likelihood:** Medium
**Explanation:** Homebrew-installed ActivityWatch may be outdated
**Evidence:**

- No current version checked
- API changes may have introduced issues
- Swift strategy may have changed

**Verification Needed:**

- Check ActivityWatch version: `/Applications/ActivityWatch.app/Contents/MacOS/aw-qt --version`
- Compare with latest version on GitHub
- Check if updates are available via Homebrew

---

## 📝 Next Steps (Priority Order)

### IMMEDIATE (Do Now)

1. **Check macOS Permissions**
   - System Preferences → Privacy & Security → Accessibility
   - System Preferences → Privacy & Security → Screen Recording
   - Add ActivityWatch if not present

2. **Verify ActivityWatch Version**

   ```bash
   /Applications/ActivityWatch.app/Contents/MacOS/aw-qt --version
   brew info activitywatch
   ```

3. **Test with GUI Mode**
   - Open ActivityWatch.app normally (not headless)
   - Check if watchers connect in GUI mode
   - Verify program tracking works in GUI

4. **Check System Logs**
   - Open Console.app
   - Filter for "ActivityWatch" or "aw-"
   - Look for permission denies or errors

5. **Try Alternative Strategy**
   - Test JXA strategy instead of Swift
   - Modify LaunchAgent to add: `<string>--strategy</string><string>jxa</string>`

### SHORT-TERM (Today)

6. **Add Verbose Logging**
   - Add `--verbose` flag to LaunchAgent
   - Restart service
   - Analyze detailed logs

7. **Check API Buckets**
   - Query aw-server API for active buckets
   - Verify if data buckets exist
   - Check if data is being written

8. **Review Database Integrity**
   - Use SQLite to check database
   - Verify no locks or corruption
   - Check recent entries

9. **Test Manual Start with Logs**
   - Stop all processes
   - Start manually: `/Applications/ActivityWatch.app/Contents/MacOS/aw-qt --no-gui --verbose`
   - Watch console output in real-time

10. **Check for Updates**
    - `brew update && brew upgrade activitywatch`
    - Or download latest version from GitHub

### MEDIUM-TERM (This Week)

11. **Implement Log Rotation**
    - Add logrotate or similar mechanism
    - Prevent stderr.log from growing indefinitely
    - Keep last N logs, archive older ones

12. **Add Health Check Command**
    - Create `just activitywatch-health` command
    - Check: process status, port listening, database updating, API responding
    - Return detailed health report

13. **Implement Watchdog**
    - Monitor ActivityWatch processes
    - Auto-restart if not tracking
    - Alert on persistent failures

14. **Create Test Workflow**
    - Create `just activitywatch-test` command
    - Test program tracking
    - Verify database writes
    - Confirm API accessibility

15. **Document Troubleshooting**
    - Create comprehensive troubleshooting guide
    - Document common issues and solutions
    - Add to AGENTS.md

---

## 📊 Metrics & Observations

### Timeline of Events

| Time (CET) | Event                     | Details                               |
| ---------- | ------------------------- | ------------------------------------- |
| 00:29:31   | Previous successful start | aw-qt started, all modules loaded     |
| 00:31:01   | aw-watcher-window started | Successful startup                    |
| 00:31:06   | Connection established    | Watcher connected to aw-server        |
| 00:31:16   | Port conflict error       | "Address already in use" on port 5600 |
| 00:31:33   | Watchers stopped          | Module shutdown triggered             |
| 01:08:22   | New start attempt         | After configuration fix               |
| 01:08:26   | aw-server started         | Server module loaded                  |
| 01:08:46   | aw-watcher-window started | Window watcher launched               |
| 01:08:48   | aw-watcher-afk started    | AFK watcher launched                  |
| 01:29:00   | Current time              | No tracking for 21 minutes            |

### Log File Analysis

| File                | Lines  | Size   | Last Entry          | Status          |
| ------------------- | ------ | ------ | ------------------- | --------------- |
| stdout.log          | 1      | 52 B   | `* Debug mode: off` | ✅ OK           |
| stderr.log          | 97,100 | 2.1 MB | 01:08:48            | ❌ No new logs  |
| peewee-sqlite.v2.db | -      | 364 MB | 01:08               | ❌ Not updating |

### Process Resource Usage

| Process           | CPU%     | Memory | State | Duration |
| ----------------- | -------- | ------ | ----- | -------- |
| aw-qt             | 0.0-0.2% | 12 MB  | R/S   | 21 min   |
| aw-server         | 0.0-0.1% | 13 MB  | S     | 21 min   |
| aw-watcher-window | 0.0%     | 8 KB   | S     | 21 min   |
| aw-watcher-afk    | 0.0%     | 12 KB  | S     | 21 min   |

---

## 🎯 Success Criteria

### Definition of Done

- [x] LaunchAgent configuration fixed (no-gui instead of --background)
- [x] All ActivityWatch processes running
- [x] aw-server listening on port 5600
- [x] No error logs (--background errors gone)
- [ ] aw-watcher-window logs "started" message
- [ ] aw-watcher-window logs "connection established" message
- [ ] aw-watcher-afk logs "started" message
- [ ] Database is being updated (modification time < 1 min ago)
- [ ] Programs appear in ActivityWatch web UI
- [ ] AFK detection works

### Current Progress: 4/10 (40%)

---

## 💡 Recommendations

### Immediate Actions

1. **Grant macOS Permissions** - Highest priority
   - Accessibility permission for ActivityWatch
   - Screen Recording permission for ActivityWatch
   - Restart after granting permissions

2. **Switch to JXA Strategy** - Quick workaround
   - Modify LaunchAgent to use JXA instead of Swift
   - Test if this resolves tracking issue

3. **Enable Verbose Logging** - Diagnostics
   - Add `--verbose` flag to LaunchAgent
   - Restart and analyze detailed output

### Long-term Improvements

1. **Migrate to Nix Package** - Declarative management
   - Replace Homebrew installation with Nix package
   - Update `platforms/darwin/services/launchagents.nix` accordingly

2. **Implement Health Monitoring** - Prevent silent failures
   - Create `just activitywatch-health` command
   - Check process status, database, API
   - Alert on failures

3. **Add Log Rotation** - Prevent bloat
   - Implement log rotation mechanism
   - Keep last 7 days of logs
   - Archive older logs

4. **Automated Testing** - Verify tracking works
   - Create test workflow
   - Verify program detection
   - Confirm database writes
   - Test API endpoints

---

## 📚 References

### Files Modified

- `platforms/darwin/services/launchagents.nix:26` - Changed `--background` to `--no-gui`

### Files Referenced

- `~/Library/LaunchAgents/net.activitywatch.ActivityWatch.plist` - Installed LaunchAgent
- `~/.local/share/activitywatch/stderr.log` - Error logs (2.1 MB)
- `~/.local/share/activitywatch/stdout.log` - Standard output logs
- `~/Library/Application Support/activitywatch/aw-server/peewee-sqlite.v2.db` - Database (364 MB)
- `~/Library/Application Support/activitywatch/aw-server/aw-server.toml` - Server configuration

### Commands Used

```bash
# Investigation
/Applications/ActivityWatch.app/Contents/MacOS/aw-qt --help
launchctl list | grep activitywatch
tail -50 ~/.local/share/activitywatch/stderr.log
lsof -i :5600

# Fix
just switch  # Applied Nix configuration with --no-gui flag

# Debugging
pkill -9 -f "aw-(qt|server|watcher)"
/Applications/ActivityWatch.app/Contents/MacOS/aw-qt --no-gui &
tail -30 ~/.local/share/activitywatch/stderr.log
```

---

## 📌 Conclusion

**Configuration Fix:** ✅ Complete

- Invalid `--background` flag replaced with `--no-gui`
- LaunchAgent successfully updated
- All processes running correctly

**Tracking Issue:** ❌ Unresolved

- Watchers running but not collecting data
- Database not updating
- No startup/connection logs
- Likely macOS permission or Swift strategy issue

**Recommendation:** Focus on macOS permissions first (highest probability), then try JXA strategy as fallback.

---

**Report Generated:** 2026-01-20 01:29 CET
**Duration:** ~30 minutes
**Status:** 🟡 PARTIALLY WORKING - Configuration fixed, tracking not working
**Next Action:** Check macOS Accessibility and Screen Recording permissions
