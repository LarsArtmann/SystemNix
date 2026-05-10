# SublimeText Configuration

This directory contains synchronized SublimeText configuration files.

## Structure

- `settings/` - User preferences and settings files
- `packages/` - Package installation metadata
- `keymaps/` - Custom key bindings
- `snippets/` - Code snippets
- `themes/` - Custom color schemes and themes

## Sync Process

Configuration is automatically synchronized using the `sublime-text-sync.sh` script:

1. **Backup**: Current settings are backed up before sync
2. **Export**: Active configuration is exported to dotfiles
3. **Import**: Configuration is imported from dotfiles to SublimeText
4. **Validate**: Changes are validated for consistency

## Files Managed

- `Preferences.sublime-settings` - Main preferences
- `*.sublime-keymap` - Key bindings
- `*.sublime-snippet` - Code snippets
- `*.sublime-theme` - UI themes
- `*.sublime-color-scheme` - Color schemes
- `Package Control.sublime-settings` - Package manager settings

## Restoration

To restore configuration on a new system:
```bash
./scripts/sublime-text-sync.sh --import
```

## Manual Sync

To manually export current configuration:
```bash
./scripts/sublime-text-sync.sh --export
```
