# Wallpaper Manager Comparison: hyprpaper vs swww

## Current Status

- **hyprpaper**: Already installed and configured ✓
- **swww**: Not installed

## Comparison

| Feature        | hyprpaper              | swww                     |
| -------------- | ---------------------- | ------------------------ |
| Developer      | Official Hyprland tool | Third-party              |
| Resource Usage | Lower (~10-20MB)       | Higher (~30-50MB)        |
| Animations     | No                     | Yes (smooth transitions) |
| GIF Support    | No                     | Yes                      |
| Configuration  | Simple                 | More complex             |
| Integration    | Native                 | Good (via IPC)           |
| Stability      | Excellent              | Good                     |

## Recommendation: Keep hyprpaper

### Reasons to Keep hyprpaper:

1. **Already installed** - No additional work needed
2. **Lower overhead** - Better for system performance
3. **Official integration** - More stable with Hyprland updates
4. **Simpler** - Less configuration complexity
5. **AMD GPU optimized** - Works efficiently with AMD hardware

### When to Consider swww:

- You want animated wallpapers or GIFs
- You need smooth transitions between wallpapers
- You want to cycle through multiple wallpapers automatically
- You need per-monitor different wallpapers with different behaviors

## How to Switch to swww (if needed in future)

If you later decide to switch to swww for animations:

```nix
# Replace hyprpaper with swww in hyprland.nix
home.packages = with pkgs; [
  # ... (other packages)
  swww  # Instead of hyprpaper
];
```

Then configure in Hyprland:

```ini
# In hyprland.conf
exec-once = swww init
exec-once = swww img ~/.config/wallpaper.png
```

## Current Configuration

Your current setup uses hyprpaper correctly with wallpaper management. This is the recommended approach for most users who want a stable, performant desktop without the overhead of animations.
