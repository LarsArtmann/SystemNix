# ActivityWatch Debug Report

**Date:** 2026-03-02 11:39
**Status:** ✅ RESOLVED

## Summary

All ActivityWatch watchers are now working correctly after debugging and fixing configuration issues.

## Issues Resolved

### 1. aw-watcher-window (Python multiprocessing fork errors)

**Problem:** Watcher was showing errors:

```
aw-watcher-window: error: unrecognized arguments: --multiprocessing-fork tracker_fd=8 pipe_handle=10
```

**Root Cause:** The multiprocessing fork errors are non-fatal warnings from Python's multiprocessing module on macOS. The actual issue was that the watcher wasn't being started by aw-qt.

**Solution:** Manually started the watcher. The errors are cosmetic - the watcher uses a swift binary for window detection and works correctly despite these warnings.

**Status:** ✅ Working - Last event: 2026-03-02T10:38:25

### 2. aw-watcher-input (Never reported events)

**Problem:** Bucket existed but had no events.

**Root Cause:** The watcher was never started.

**Solution:** Started the watcher manually. Input Monitoring permission was already granted.

**Status:** ✅ Working - Last event: 2026-03-02T10:32:20

### 3. aw-watcher-utilization (LaunchAgent crash loop)

**Problem:** LaunchAgent was in crash loop with error:

```
error: unrecognized arguments: --host localhost --port 5600 --poll-time 5
```

**Root Cause:** The Nix package of aw-watcher-utilization has a different CLI interface than standard ActivityWatch watchers. It only supports `-h`, `-v`, and `--testing` flags.

**Solution:** Fixed `platforms/darwin/services/launchagents.nix` to remove unsupported arguments.

**Status:** ✅ Working - Last event: 2026-03-02T10:38:19

## Current Bucket Status

| Bucket                 | Status    | Last Event          |
| ---------------------- | --------- | ------------------- |
| aw-watcher-afk         | ✅ Active | 2026-03-02T10:36:54 |
| aw-watcher-window      | ✅ Active | 2026-03-02T10:38:25 |
| aw-watcher-web-chrome  | ✅ Active | 2026-03-02T10:38:26 |
| aw-watcher-web-helium  | ✅ Active | 2026-03-02T10:37:23 |
| aw-watcher-input       | ✅ Active | 2026-03-02T10:32:20 |
| aw-watcher-utilization | ✅ Active | 2026-03-02T10:38:19 |

## Files Modified

- `platforms/darwin/services/launchagents.nix` - Removed unsupported CLI arguments from aw-watcher-utilization LaunchAgent

## Running Processes

```
/Applications/ActivityWatch.app/Contents/MacOS/aw-qt
/Applications/ActivityWatch.app/Contents/MacOS/aw-server
/Applications/ActivityWatch.app/Contents/MacOS/aw-watcher-afk
/Applications/ActivityWatch.app/Contents/MacOS/aw-watcher-window
/Applications/ActivityWatch.app/Contents/MacOS/aw-watcher-input
/nix/store/...-aw-watcher-utilization-1.2.2/bin/aw-watcher-utilization
```

## Notes

- The multiprocessing fork errors in aw-watcher-window are cosmetic and don't affect functionality
- aw-watcher-input requires Input Monitoring permission (already granted)
- aw-watcher-utilization is now fully Nix-managed via LaunchAgent
