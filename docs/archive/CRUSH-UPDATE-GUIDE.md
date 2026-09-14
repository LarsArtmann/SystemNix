# 🚀 Always Stay on Latest Crush Version

## The Solution: NUR (Nix User Repository)

Instead of waiting for nixpkgs-unstable to update (which can take days/weeks), we now use **NUR** (Nix User Repository) which is updated **much faster** - often within hours of a new release!

### What Changed

**Before (nixpkgs unstable):**

- Crush v0.49.0 (4 versions behind)
- Updates only when nixpkgs maintainers merge
- Can lag by days or weeks

**After (NUR):**

- Crush v0.53.0 (same day as release!)
- Directly from Charm's NUR repository
- Updates within hours of release

## Files Modified

1. **`platforms/common/packages/base.nix`**
   - Changed from `pkgs.crush` → `pkgs.nur.repos.charmbracelet.crush`

2. **`platforms/nixos/system/scheduled-tasks.nix`**
   - Updated systemd service to use NUR crush

3. **Added `scripts/update-crush-latest.sh`**
   - One-command update to latest version

## Quick Commands

```bash
# Check current version
crush --version

# Update to latest (build only)
./scripts/update-crush-latest.sh

# Update and immediately switch
./scripts/update-crush-latest.sh --switch

# Or manually update just NUR and rebuild
cd ~/Setup-Mac
nix flake update nur
just switch  # or: sudo nixos-rebuild switch --flake .
```

## How It Works

1. **NUR Overlay** is already configured in your `flake.nix` (line 281-282)
2. When you update the flake input (`nix flake update nur`), you get the latest packages
3. The Charm team maintains their own NUR repo with instant updates

## Verification

```bash
# Check what version NUR has
nix eval --json 'github:nix-community/NUR#repos.charmbracelet.crush.version'

# Check what's in your flake.lock
cat flake.lock | grep -A5 '"nur"'

# Build and test without switching
nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
./result/bin/crush --version
```

## Future Updates

When a new Crush version drops:

1. **Automatic:** Just run `just switch` - it'll use the cached NUR version
2. **Get latest:** Run `./scripts/update-crush-latest.sh` to update NUR first
3. **Check:** Run `crush --version` to confirm

## Why This Is Better

| Method               | Lag Time      | Maintenance             |
| -------------------- | ------------- | ----------------------- |
| nixpkgs-unstable     | Days to weeks | Manual PRs required     |
| NUR (this solution)  | Hours         | Automated by Charm team |
| Building from source | Immediate     | You maintain it         |

NUR gives you the best of both worlds: **bleeding-edge updates** with **zero maintenance**!

---

_Last updated: March 27, 2026_
_Current NUR Crush: v0.53.0_
_Previous nixpkgs Crush: v0.49.0_
