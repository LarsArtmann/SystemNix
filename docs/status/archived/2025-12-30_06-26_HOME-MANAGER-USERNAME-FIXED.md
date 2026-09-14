# Home Manager Activation Fix - Username Mismatch

**Date:** 2025-12-30 06:26:00 CET
**Status:** ✅ BUILD SUCCESSFUL - WAITING FOR USER ACTIVATION
**Generation:** Targeting 207 (currently at 206)

---

## 🎯 Problem Identified

**Root Cause:** Home Manager was configured to activate for user `lars`, but the actual macOS username is `larsartmann`.

**Error Observed:**

```bash
Activating home-manager configuration for lars
id: 'lars': no such user: Invalid argument
sudo: unknown user lars
sudo: error initializing audit plugin sudoers_audit
```

**Investigation:**

- System username verified: `larsartmann` (via `whoami`)
- Home Manager configured: `users.lars`
- Nix-darwin user definition: `users.users.lars`
- Result: Home Manager activation failed, but darwin-rebuild succeeded

---

## 🔧 Fixes Applied

### 1. Updated `flake.nix` (Line 96)

**Before:**

```nix
users.lars = import ./platforms/darwin/home.nix;
```

**After:**

```nix
users.larsartmann = import ./platforms/darwin/home.nix;
```

### 2. Updated `platforms/darwin/default.nix` (Lines 23-26)

**Before:**

```nix
users.users.lars = {
  name = "lars";
  home = "/Users/lars";
};
```

**After:**

```nix
users.users.larsartmann = {
  name = "larsartmann";
  home = "/Users/larsartmann";
};
```

---

## ✅ Build Verification

**Build Command:**

```bash
darwin-rebuild build --flake . --show-trace
```

**Build Result:**

```bash
building '/nix/store/2ybnrk5an1hbbbssp657z7zdl3f4nn9y-activation-larsartmann.drv'...
building '/nix/store/v6ndwvyiqnc89xhnwzf1ns9smsvyry3q-darwin-system-26.05.f0c8e1f.drv'...
```

**Status:** ✅ **BUILD SUCCESSFUL**

- Exit code: 0
- Home Manager activation script: `activation-larsartmann.drv` (CORRECT USERNAME)
- Output: `/nix/store/yc3mq5bpp0jyp5r6g58j78f27nn36xm5-darwin-system-26.05.f0c8e1f`

---

## 🚀 User Action Required

The build succeeded but activation requires sudo privileges (blocked in current environment).

### Step 1: Activate System

```bash
cd ~/Desktop/Setup-Mac
sudo darwin-rebuild switch --flake .
```

### Step 2: Open New Terminal

**IMPORTANT:** Open a new terminal window for shell changes to take effect:

- Press `Cmd+N` in Terminal/iTerm2
- Or quit and reopen Terminal

### Step 3: Verify Home Manager Activation

```bash
# Check Home Manager generation
ls -lt ~/.local/state/nix/profiles/home-manager* | head -3

# Should show new generation (higher than previous)
```

### Step 4: Verify Shell Configuration

```bash
# Check Fish prompt (should show Starship prompt)
# Open new terminal first!

# Verify Fish aliases
type nixup
# Should show: darwin-rebuild switch --flake .

# Verify Starship prompt
echo $STARSHIP_SHELL
# Should show: fish

# Verify Tmux is configured
cat ~/.config/tmux/tmux.conf
# Should show custom configuration (mouse enabled, clock24, etc.)
```

### Step 5: Verify System Generation

```bash
# Check Darwin system generation
ls -lt /nix/var/nix/profiles/system-* | head -3

# Should show generation 207 or higher (currently stuck at 206)
```

### Step 6: Complete Health Check

```bash
just health
# Run comprehensive system health check
```

---

## 📋 Expected Behavior After Activation

### Fish Shell

- **Prompt:** Starship prompt with git branch, status indicators
- **Aliases:** `nixup`, `nixbuild`, `nixcheck` available
- **Greeting:** Disabled (faster startup)
- **History:** Extended history limit

### Starship Prompt

- **Format:** Shows all available modules
- **Newline:** Disabled for compact display
- **Fish Integration:** Automatic (no manual init needed)

### Tmux

- **Mouse:** Enabled (click to select panes/windows)
- **Clock:** 24-hour format
- **Base Index:** 1 (0-indexing disabled)
- **History:** 100000 lines
- **Terminal:** screen-256color

### Environment Variables

- `EDITOR`: Set to preferred editor
- `LANG`: Set to UTF-8 locale
- Platform-specific variables (Darwin only)

### Home Manager

- **Backup:** Old configs backed up with `.backup` extension
- **Symlinks:** `~/.config/fish`, `~/.config/starship.toml`, etc.
- **Generation:** New generation created and activated

---

## 🔍 Troubleshooting

### If Starship Prompt Doesn't Appear

```bash
# Restart shell
exec fish

# Check Starship config
cat ~/.config/starship.toml

# Verify Starship is installed
which starship
```

### If Fish Aliases Don't Work

```bash
# Reload Fish config
source ~/.config/fish/config.fish

# Check aliases
type nixup

# Verify Home Manager activation
ls -l ~/.local/state/nix/profiles/home-manager
```

### If System Generation Stuck at 206

```bash
# Check activation logs
sudo log show --predicate 'process == "darwin-rebuild"' --last 10m

# Rebuild and activate again
cd ~/Desktop/Setup-Mac
sudo darwin-rebuild switch --flake . --show-trace
```

### If Activation Fails Again

```bash
# Check error details
sudo darwin-rebuild switch --flake . --show-trace 2>&1 | tail -50

# Verify username
whoami
# Should show: larsartmann

# Verify Nix configuration
grep "users.larsartmann" flake.nix
grep "users.users.larsartmann" platforms/darwin/default.nix
```

---

## 📊 Files Changed

1. **`flake.nix`**
   - Line 96: `users.lars` → `users.larsartmann`

2. **`platforms/darwin/default.nix`**
   - Lines 23-26: Updated user definition with correct username and home path

---

## 🎯 Success Criteria

- [ ] Build completes successfully (exit code 0)
- [ ] Activation completes without errors
- [ ] New generation created (207+)
- [ ] Fish shell has Starship prompt
- [ ] Fish aliases (`nixup`, `nixbuild`, `nixcheck`) work
- [ ] Tmux configuration applied
- [ ] Home Manager generation activated
- [ ] All health checks pass (`just health`)

---

## 📝 Notes

- **NixOS Configuration Unchanged:** The NixOS configuration still uses `users.lars` for the evo-x2 Linux machine. This is correct and intentional.
- **MacOS Only:** These changes only affect the Darwin (macOS) configuration.
- **Cross-Platform:** Home Manager modules are shared via `platforms/common/` and work identically on both platforms.
- **Activation Required:** Shell configuration changes require opening a new terminal after activation.

---

## 🔄 Next Steps After Success

1. **Commit Changes:** Once activation succeeds, commit the username fix
2. **Create Status Report:** Document successful resolution
3. **Test All Features:** Verify all Home Manager configurations work
4. **Update Documentation:** Update AGENTS.md if needed (username handling)

---

_Status report generated: 2025-12-30 06:26:00 CET_
