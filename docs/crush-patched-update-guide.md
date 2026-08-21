# Crush-Patched Auto-Update Guide

## Overview

The `crush-patched` package is a custom Nix derivation that applies patches from your PRs to the Crush CLI tool. It can now be automatically updated to the latest Crush release.

## Quick Start

```bash
# Option 1: Integrated update (recommended for routine updates)
just update && just switch
# This updates Nix flake AND crush-patched version

# Option 2: Full automatic update (recommended when you want complete rebuild)
just crush-full-update

# Then apply system-wide
just switch
```

## Commands

### `just update` (Routine Updates)

Updates Nix flake and crush-patched version:

1. Updates Nix flake inputs (`nix flake update`)
2. Updates crush-patched version and source hash
3. Does NOT build or update vendorHash

**Use this for:** Routine updates where you want version updates but will build later.

**Next steps:**

```bash
just update    # Updates versions
just switch     # Builds and applies (may need manual vendorHash fix)
```

### `just crush-full-update` (Complete Rebuild)

Fully automated workflow that:

1. Fetches latest Crush version from GitHub
2. Updates version, URL, and source hash in `pkgs/crush-patched.nix`
3. Builds with temporary vendor hash (may fail initially)
4. Extracts actual vendor hash from build output
5. Updates vendor hash in Nix file
6. Rebuilds successfully
7. Verifies binary works

**Use this for:** Complete rebuild with verification (takes longer, but fully automated).

### `just crush-update`

Updates version and source hash only. Manual workflow:

```bash
just crush-update      # Update version/source
just crush-build       # Build (may fail)
just crush-fix-hash   # Extract and update vendorHash
just crush-build       # Rebuild with correct hash
```

**Use this for:** When you want manual control over each step.

## Comparison: `just update` vs `just crush-full-update`

| Aspect               | `just update`   | `just crush-full-update` |
| -------------------- | --------------- | ------------------------ |
| Nix flake update     | ✅ Yes          | ❌ No                    |
| Crush version update | ✅ Yes          | ✅ Yes                   |
| Build crush-patched  | ❌ No           | ✅ Yes                   |
| Update vendorHash    | ❌ No           | ✅ Yes                   |
| Verify binary        | ❌ No           | ✅ Yes                   |
| Time taken           | Fast (~10s)     | Slow (~2-5min)           |
| When to use          | Routine updates | Complete rebuild & test  |

**Recommended workflow:**

```bash
# Daily/Weekly routine:
just update && just switch

# When testing new Crush version:
just crush-full-update && just switch

# When you know patches need updating:
just crush-info          # Check current state
# Edit pkgs/crush-patched.nix manually
just crush-full-update  # Rebuild with changes
```

### `just crush-build`

Builds crush-patched and logs output to `/tmp/crush-build.log`.

**Use this for:** Testing changes or getting vendor hash.

### `just crush-info`

Shows current version and applied patches:

```bash
just crush-info
# Output:
# 📋 Crush-Patched Information
# ==========================
#   pname = "crush-patched"
#   version = "v0.37.0"
#
# Patches applied:
#   # PR #1854: fix(grep): prevent tool from hanging when context is cancelled
#   # PR #1617: refactor: eliminate all duplicate code blocks over 200 tokens
#   ...
```

**Use this for:** Checking current state.

## Workflow Details

### What Gets Updated with `just update`

- Nix flake inputs (`flake.lock`)
- Crush version in `pkgs/crush-patched.nix`
- Source URL and hash for new version

**What is NOT updated with `just update`:**

- Vendor hash (requires build)
- Binary (requires build)
- Patches (manual)

### What Gets Updated with `just crush-full-update`

1. **Version**: `pkgs/crush-patched.nix:7`

   ```nix
   version = "v0.37.0" → version = "v0.38.0"
   ```

2. **Source URL & Hash**: `pkgs/crush-patched.nix:9-12`

   ```nix
   src = pkgs.fetchurl {
     url = "https://github.com/charmbracelet/crush/archive/refs/tags/v0.37.0.tar.gz";
     sha256 = "...";
   };
   ```

3. **Vendor Hash**: `pkgs/crush-patched.nix:74`
   ```nix
   vendorHash = "sha256:hhBjQ1Wm4ZY1KX09CgpNusse3osT8b3VSsIIj6KFjFA=";
   ```

### Patch Compatibility

Patches are NOT automatically updated. After version update:

1. **Check build output** for patch conflicts:

   ```
   Hunk #1 FAILED at line 42
   1 out of 3 hunks FAILED
   ```

2. **Update patches** in `pkgs/crush-patched.nix:14-46`:
   - Remove conflicting patches
   - Update to newer PR versions if available
   - Re-run `just crush-build`

3. **Common issues:**
   - PR not applicable to new version → Remove patch
   - Code changed since PR → Update PR number or remove
   - Merge conflicts → Check if PR was merged upstream

### Vendor Hash Explanation

Crush uses Go modules (vendor directory). The hash changes with each version because:

- Go modules lock file (`go.mod`, `go.sum`) changes
- Dependency versions may change
- Nix needs deterministic hash for reproducibility

**Workflow:**

1. Use `lib.fakeHash` initially
2. Nix builds and computes actual hash
3. Extract hash from error: `got: sha256:...`
4. Update with actual hash
5. Rebuild succeeds

## Manual Update (Script)

If you prefer manual control, or if `just update` fails:

````bash
```bash
# Step 1: Update version
./pkgs/update-crush-patched.sh

# Step 2: Build (may fail initially)
nix build .#crush-patched 2>&1 | tee /tmp/crush-build.log

# Step 3: Extract vendorHash
grep "got:" /tmp/crush-build.log

# Step 4: Update vendorHash in pkgs/crush-patched.nix
# Replace lib.fakeHash with actual hash

# Step 5: Rebuild
nix build .#crush-patched

# Step 6: Verify
./result/bin/crush --version
````

## Troubleshooting

### "got: sha256:..." not found

- Cause: Build completed successfully, or error format changed
- Fix: Check build log for vendor hash location, or try manual extraction

### Patches don't apply

- Cause: Code changed in new version
- Fix:
  1. Remove conflicting patches from `pkgs/crush-patched.nix`
  2. Check if PRs have been merged upstream
  3. Update to newer PR versions if available

### Source hash mismatch

- Cause: Tarball download failed or corrupted
- Fix: Check internet connection, re-run update script

### vendorHash mismatch after update

- Cause: Build environment changed
- Fix: Rebuild to get new vendor hash:
  ```bash
  nix build .#crush-patched 2>&1 | tee /tmp/crush-build.log
  # Extract and update hash
  ```

## Files Involved

- **`pkgs/crush-patched.nix`**: Main derivation definition
- **`pkgs/update-crush-patched.sh`**: Version update script
- **`pkgs/auto-update-crush-patched.sh`**: Full automation script
- **`pkgs/compute-hashes.sh`**: Manual hash computation (legacy)

## Related Just Commands

- `just switch` - Apply Nix configuration changes
- `just test` - Test configuration without applying
- `just go-tools-version` - Show Go tool versions
