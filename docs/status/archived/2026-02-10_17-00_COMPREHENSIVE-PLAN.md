# Comprehensive Task Plan

**Date**: 2026-02-10 17:00
**Objective**: Fix alejandra pre-commit + Migrate LaunchAgents to Nix

---

## Task Priority Matrix

| Priority | Task                             | Impact | Effort | Customer Value                | Est. Time |
| -------- | -------------------------------- | ------ | ------ | ----------------------------- | --------- |
| 🔴 P0    | Fix alejandra stdin error        | HIGH   | LOW    | HIGH - Blocks commits         | 10 min    |
| 🔴 P1    | Migrate ublock LaunchAgent       | HIGH   | MED    | HIGH - Removes 30+ bash lines | 12 min    |
| 🔴 P2    | Migrate sublime-text LaunchAgent | HIGH   | MED    | HIGH - Removes 30+ bash lines | 12 min    |
| 🟡 P3    | Create ublock maintenance script | MED    | LOW    | MED - Support for LaunchAgent | 8 min     |
| 🟡 P4    | Create sublime-text sync script  | MED    | LOW    | MED - Support for LaunchAgent | 8 min     |
| 🟡 P5    | Test LaunchAgent loading         | MED    | LOW    | HIGH - Verify migration works | 10 min    |
| 🟢 P6    | Archive old bash scripts         | LOW    | LOW    | LOW - Cleanup                 | 5 min     |
| 🟢 P7    | Update documentation             | LOW    | LOW    | MED - Record changes          | 8 min     |

---

## Detailed Task Breakdown

### 🔴 P0: Fix alejandra stdin error (10 min)

**Problem**: Pre-commit hook passes filenames but alejandra receives empty stdin
**Root Cause**: `pass_filenames: true` with bash wrapper doesn't forward arguments

**Steps**:

1. Read `.pre-commit-config.yaml` alejandra section
2. Change from `pass_filenames: true` to `pass_filenames: false`
3. Change from checking specific files to checking all files via `alejandra --check .`
4. Test with `just pre-commit-run`

**Verification**: Pre-commit should pass without stdin errors

---

### 🔴 P1: Migrate ublock LaunchAgent (12 min)

**Source**: `scripts/ublock-origin-setup.sh:539-571`
**Target**: `platforms/darwin/services/launchagents.nix`

**LaunchAgent Specification**:

- Label: `com.larsartmann.ublock-maintenance`
- Program: `~/.local/share/ublock/update-filters.sh`
- Schedule: Daily at 09:00
- Logs: `~/.local/share/ublock/maintenance.log`

**Steps**:

1. View ublock script to understand current LaunchAgent
2. Extract plist template from bash heredoc
3. Add `environment.userLaunchAgents."com.larsartmann.ublock-maintenance.plist"` to launchagents.nix
4. Convert bash variables to Nix expressions (`$UBLOCK_CONFIG_DIR` → `${userHome}/.local/share/ublock`)

**Verification**: Nix syntax valid, plist structure correct

---

### 🔴 P2: Migrate sublime-text LaunchAgent (12 min)

**Source**: `scripts/sublime-text-sync.sh:439-472`
**Target**: `platforms/darwin/services/launchagents.nix`

**LaunchAgent Specification**:

- Label: `com.larsartmann.sublime-sync`
- Program: `~/projects/SystemNix/scripts/sublime-text-sync.sh --export`
- Schedule: Daily at 18:00
- Logs: `~/.config/sublime-text/sync.log`

**Steps**:

1. View sublime-text script LaunchAgent creation
2. Extract plist template
3. Add `environment.userLaunchAgents."com.larsartmann.sublime-sync.plist"` to launchagents.nix
4. Convert bash variables to Nix

**Verification**: Nix syntax valid, plist structure correct

---

### 🟡 P3: Create ublock maintenance script (8 min)

**Purpose**: Script that the LaunchAgent will call
**Location**: `~/.local/share/ublock/update-filters.sh`

**Steps**:

1. Check if ublock already has filter update logic in the main script
2. Extract or create `update-filters.sh` that:
   - Downloads latest filter lists
   - Updates uBlock configuration
   - Logs output
3. Ensure script is executable and in correct location

**Verification**: Script runs successfully when called directly

---

### 🟡 P4: Create sublime-text sync script (8 min)

**Purpose**: Script that the LaunchAgent will call for export
**Note**: May already exist - the bash script has `--export` functionality

**Steps**:

1. Check if `sublime-text-sync.sh --export` works standalone
2. If not, create wrapper script at appropriate location
3. Ensure it handles the export functionality

**Verification**: Script runs with `--export` flag

---

### 🟡 P5: Test LaunchAgent loading (10 min)

**Purpose**: Verify declarative LaunchAgents work correctly

**Steps**:

1. Run `just test` to validate Nix configuration
2. After switch, check LaunchAgent files exist in `~/Library/LaunchAgents/`
3. Verify they are loaded: `launchctl list | grep com.larsartmann`
4. Test manual trigger: `launchctl start com.larsartmann.ublock-maintenance`

**Verification**: LaunchAgents loaded and functional

---

### 🟢 P6: Archive old bash scripts (5 min)

**Purpose**: Clean up after migration

**Steps**:

1. Move `scripts/ublock-origin-setup.sh` to `scripts/archive/`
2. Move `scripts/sublime-text-sync.sh` to `scripts/archive/`
3. Or add deprecation notices pointing to new Nix configuration

**Verification**: Scripts no longer referenced, safely archived

---

### 🟢 P7: Update documentation (8 min)

**Purpose**: Record what was changed and why

**Steps**:

1. Update `docs/TODO-STATUS.md` - mark LaunchAgent migration complete
2. Update `docs/status/2026-02-10_16-48_TODO-RESOLUTION...md` with details
3. Add notes about new declarative LaunchAgents

**Verification**: Documentation reflects current state

---

## Execution Order

```
P0 (alejandra fix)
  ↓
P1 (ublock LaunchAgent) → P3 (ublock script)
  ↓                          ↓
P2 (sublime LaunchAgent) → P4 (sublime script)
  ↓
P5 (test all)
  ↓
P6 (archive) + P7 (document)
```

---

## Success Criteria

- [ ] alejandra pre-commit hook passes without errors
- [ ] ublock LaunchAgent defined in Nix (not bash)
- [ ] sublime-text LaunchAgent defined in Nix (not bash)
- [ ] Both LaunchAgents load correctly after `just switch`
- [ ] Old bash scripts archived or deprecated
- [ ] Documentation updated

---

## Risk Mitigation

| Risk                            | Mitigation                                     |
| ------------------------------- | ---------------------------------------------- |
| LaunchAgent doesn't load        | Keep old scripts until verified, test manually |
| Script paths wrong              | Use absolute paths, test standalone first      |
| Pre-commit still fails          | Alternative: use treefmt instead of alejandra  |
| Migration breaks existing setup | Test on non-critical system first              |
