# nix-colors Integration Guide

## Overview

Setup-Mac now uses `nix-colors` for centralized, declarative color scheme management. This enables easy theme switching with 220+ available Base16 color schemes.

## Current Theme

**Catppuccin Mocha** - Dark, elegant theme with soft pastels

## How to Change the Theme

### Quick Change (3 minutes)

1. Open `flake.nix` and locate the color scheme definition:
   - NixOS: Line ~31 in `platforms/nixos/system/configuration.nix`
   - Darwin: Line ~19 in `platforms/darwin/default.nix`

2. Change the scheme name:

   ```nix
   colorScheme = nix-colors.colorSchemes.catppuccin-mocha;
   ```

3. Available schemes: https://tinted-themes.github.io/base16-gallery/

4. Apply changes:

   ```bash
   # NixOS
   sudo nixos-rebuild switch --flake .

   # Darwin (macOS)
   darwin-rebuild switch --flake .
   ```

### Popular Color Schemes

- **Catppuccin Mocha**: `catppuccin-mocha` (current)
- **Dracula**: `dracula`
- **Nord**: `nord`
- **Gruvbox Dark**: `gruvbox-dark-medium`
- **Monokai**: `monokai`
- **Solarized Dark**: `solarized-dark`

## Color Scheme Structure

Each scheme provides a palette with 18 colors:

- `base00` - `base07`: Background shades
- `base08` - `base0F`: Accent colors (red, green, yellow, etc.)

## Migrated Applications

✅ **Waybar** - Status bar colors
✅ **Hyprland** - Window border colors
✅ **Starship** - Shell prompt colors
✅ **Tmux** - Terminal multiplexer colors

## Cross-Platform Consistency

All platforms (NixOS + Darwin) use the same color scheme for 100% consistency.

## Benefits

- **Fast**: Change theme in 3 minutes (vs 55+ minutes before)
- **Centralized**: One file to edit
- **Consistent**: All applications use same colors
- **Extensible**: 220+ color schemes available

## Troubleshooting

### Waybar Not Updating

```bash
# Restart Waybar
pkill waybar
# Waybar will auto-restart via systemd
```

### Hyprland Borders Not Updating

```bash
# Reload Hyprland
hyprctl reload
```

### Starship Prompt Not Updating

```bash
# Start new Fish shell
exec fish
```

## Future Enhancements

Planned additions:

- [ ] GTK theme integration
- [ ] Qt theme integration
- [ ] Terminal emulator colors (Alacritty/Kitty/WezTerm)
- [ ] Neovim color scheme
- [ ] iTerm2 colors (macOS)

## References

- [nix-colors GitHub](https://github.com/Misterio77/nix-colors)
- [Base16 Gallery](https://tinted-themes.github.io/base16-gallery/)
- [Research Report](./NIX-COLORS-INTEGRATION-RESEARCH.md)

---

_Last updated: January 14, 2026_
