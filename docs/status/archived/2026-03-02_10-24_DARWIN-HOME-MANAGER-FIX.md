# Status Report: Darwin Home Manager User Workaround Fix

**Date:** 2026-03-02 10:24 CET
**Reporter:** Crush (AI Assistant)
**Scope:** platforms/darwin - Home Manager user configuration fix
**Branch:** master (5 commits ahead of origin)

---

## Executive Summary

Fixed the **pre-existing Home Manager configuration issue** that was blocking all Darwin system updates. The error `home.homeDirectory is not of type 'absolute path'` with value `null` has been resolved by restoring the explicit user definition workaround.

---

## Root Cause

The `platforms/darwin/default.nix` had the Home Manager user workaround commented out:

```nix
# TEST: Removed workaround - testing if still needed
# Was: users.users.larsartmann = { name = "larsartmann"; home = "/Users/larsartmann"; };
```

This caused Home Manager to fail because:

1. Home Manager's `nix-darwin/default.nix` imports `../nixos/common.nix`
2. This NixOS-specific module requires `config.users.users.<name>.home` to be defined
3. Without the explicit definition, `home.homeDirectory` evaluates to `null`
4. This cascades to break `xdg.configHome` → `programs.zsh.dotDir` and other options

---

## The Fix

**File:** `platforms/darwin/default.nix`

```nix
# Home Manager workaround: Explicit user definition required
# Home Manager's nix-darwin/default.nix imports ../nixos/common.nix which
# requires config.users.users.<name>.home to be defined for home.directory
users.users.larsartmann = {
  name = "larsartmann";
  home = "/Users/larsartmann";
};
```

---

## Verification

### Build Output

```
[U.] darwin-system 26.05.3mbfa436 -> 26.05.52d0615
[U*] sd 1.0.0 -> 1.1.0
[A+] crush-patched-v0.46.1 <none>
[R-] crush-patched-v0.46.0 <none>

SIZE: 7.40 GiB -> 7.40 GiB
DIFF: 1.12 MiB
```

### Activation Success

```
Activating home-manager configuration for larsartmann
Starting Home Manager activation
Activating checkFilesChanged
Activating checkLinkTargets
Activating writeBoundary
Activating installPackages
Activating linkGeneration
Creating home file links in /Users/larsartmann
Activating onFilesChange
Activating setupLaunchAgents
```

### Binary Verification

```bash
$ crush --version
crush version v0.46.1
```

---

## Commit Made

```
6303cb7 fix(darwin): restore Home Manager user workaround for larsartmann

- Restore users.users.larsartmann definition with name and home path
- Update comment to explain why this workaround is necessary
- Fixes nh darwin switch and just switch commands
- Resolves: home.homeDirectory is not of type 'absolute path' error
```

---

## Impact Assessment

| Component               | Before     | After      |
| ----------------------- | ---------- | ---------- |
| `nh darwin switch`      | ❌ Failed  | ✅ Works   |
| `just switch`           | ❌ Failed  | ✅ Works   |
| `just test`             | ❌ Failed  | ✅ Works   |
| Home Manager activation | ❌ Error   | ✅ Success |
| crush-patched           | ❌ v0.46.0 | ✅ v0.46.1 |

---

## Related Work

This fix completes the crush-patched v0.46.1 update chain:

1. **2b6891b** - fix(crush-patched): update to v0.46.1 and fix hash format
2. **8cd7600** - fix(crush-patched): add hash validation and fix sed pattern
3. **28cb3b4** - docs(status): status report for crush-patched v0.46.1 fix
4. **6303cb7** - fix(darwin): restore Home Manager user workaround (this fix)

---

## Technical Details

### Error Chain

```
home-manager.users.larsartmann.home.homeDirectory
  → null (undefined)
  → config.xdg.configHome = "${home.homeDirectory}/.config" fails
  → programs.zsh.dotDir = "${xdg.configHome}/zsh" fails
  → lib.hasInfix "$" cfg.dotDir throws type error
```

### Why This Happens

Home Manager's Darwin module reuses the NixOS common module for user configuration, but macOS doesn't use `/etc/passwd` in the same way. The explicit `users.users` definition provides the metadata Home Manager needs.

---

## Recommendations

### Immediate

- ✅ **DONE** - Restore workaround with better documentation

### Short-term

- Monitor Home Manager issues for permanent fix
- Consider pinning Home Manager version if this regresses
- Add CI check that validates `nh darwin switch` succeeds

### Long-term

- Upstream fix to Home Manager to handle macOS user detection
- Separate Darwin-specific user module that doesn't require explicit definition

---

## References

- Previous status report: `2026-03-02_10-11_CRUSH-PATCHED-v0.46.1-UPDATE-FIX.md`
- File changed: `platforms/darwin/default.nix`
- Related: `platforms/darwin/services/launchagents.nix` (uses `config.users.users.larsartmann.home`)

---

**Status:** ✅ RESOLVED - System now builds and switches successfully

**Report Generated:** 2026-03-02 10:24 CET
**Assistant:** Crush v0.46.1
