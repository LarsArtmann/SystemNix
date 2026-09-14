# Animated Wallpapers Setup Guide

This guide provides step-by-step instructions for setting up and managing animated wallpapers in NixOS with Hyprland.

## Overview

This setup uses:

- **swww** (Simple Wayland Wallpaper) - An efficient wallpaper daemon for Wayland that supports animated wallpapers
- **ImageMagick** - For creating and manipulating wallpaper images
- **Custom scripts** - For automated wallpaper management

## Requirements

1. **NixOS with Hyprland** - This configuration assumes you're using Hyprland as your Wayland compositor
2. **Wayland session** - swww requires a Wayland environment
3. **Sufficient GPU memory** - Animated wallpapers consume more memory than static images

## Installation

The wallpaper management tools are already included in your NixOS configuration:

```nix
# platforms/nixos/desktop/hyprland.nix
home.packages = with pkgs; [
  # ... other packages
  swww # Animated wallpapers
  imagemagick # Image manipulation
];
```

## Initial Setup

### 1. Create Wallpaper Directories

The following directory structure is automatically created:

```
~/.config/wallpapers/
├── static/      # Regular wallpapers
├── animated/    # Animated wallpapers
└── gifs/        # GIF wallpapers
```

### 2. Generate Sample Wallpapers

Sample wallpapers are automatically created on first build:

- Default static wallpaper: A dark gradient
- Sample animated wallpapers: Red, green, and blue gradients

### 3. Start the Wallpaper Daemon

The swww daemon is automatically started by Hyprland:

```bash
# Manual restart if needed
swww-daemon &
sleep 1
```

## Usage

### Basic Commands

The wallpaper management script provides several options:

1. **Random static wallpaper** (default):

   ```bash
   ~/.config/scripts/wallpaper-switcher
   ```

2. **Animated wallpaper**:

   ```bash
   ~/.config/scripts/wallpaper-switcher --animate
   ```

3. **Clear wallpaper**:

   ```bash
   ~/.config/scripts/wallpaper-switcher --clear
   ```

4. **Cycle through wallpapers**:

   ```bash
   ~/.config/scripts/wallpaper-switcher --cycle [delay_seconds]
   ```

5. **Use specific wallpaper**:
   ```bash
   ~/.config/scripts/wallpaper-switcher path/to/image.png
   ```

### Hyprland Keybindings

The following keybindings are configured:

- `Mod + W`: Random static wallpaper
- `Mod + Shift + W`: Animated wallpaper
- `Mod + Alt + W`: Clear wallpaper

## Adding Your Own Wallpapers

### Static Wallpapers

Simply add image files to:

```bash
~/.config/wallpapers/static/
```

Supported formats: PNG, JPG, JPEG

### Animated Wallpapers

For animated effects, add images to:

```bash
~/.config/wallpapers/animated/
```

These will be displayed with smooth transition effects.

## Performance Optimization

### GPU Considerations

1. **AMD GPUs**: The configuration is optimized for AMD hardware with:
   - Proper GPU driver support
   - Hardware acceleration

2. **Memory Usage**:
   - Static wallpapers: Minimal memory usage
   - Animated wallpapers: Higher memory consumption
   - GIF wallpapers: Highest memory usage

### CPU Optimization

1. **Transitions**: Smooth transitions use GPU acceleration
2. **Background Management**: Only one wallpaper process runs at a time

## Troubleshooting

### Common Issues

1. **Wallpaper not changing**:
   - Ensure swww daemon is running: `pgrep swww-daemon`
   - Restart the daemon: `pkill swww-daemon && swww-daemon &`

2. **Performance issues**:
   - Check GPU memory usage: `nvtop` (AMD)
   - Reduce wallpaper resolution if needed

3. **Transitions not working**:
   - Verify Wayland session: `echo $XDG_SESSION_TYPE`
   - Check for GPU driver issues

### Debug Commands

```bash
# Check swww status
swww query

# List available wallpapers
ls ~/.config/wallpapers/static/
ls ~/.config/wallpapers/animated/

# Test with specific image
swww img path/to/image.png --transition-type fade
```

## Advanced Configuration

### Custom Transitions

You can customize transition effects in the wallpaper script:

```bash
# Available transition types
--transition-type {any,none,fade,simple,top,bottom,center,wipe}
--transition-fps 60      # Animation FPS
--transition-duration 1.5 # Transition duration in seconds
```

### Multiple Monitor Setup

For multiple monitors, swww automatically handles all connected displays:

```bash
# Set different wallpapers per monitor
swww img wall1.png --outputs eDP-1
swww img wall2.png --outputs HDMI-A-1
```

## Integration with Other Tools

### Hyprpaper Integration

If you prefer Hyprpaper for static wallpapers:

1. Both tools can coexist
2. Use Hyprpaper for default static wallpapers
3. Use swww for animated wallpapers and transitions

### Systemd Integration

The wallpaper daemon can be managed by systemd:

```bash
# Enable auto-start
systemctl --user enable swww.service

# Check status
systemctl --user status swww.service
```

## Performance Monitoring

Monitor wallpaper-related performance:

```bash
# GPU memory usage
nvtop

# Process information
ps aux | grep swww

# Transition performance testing
time swww img wallpaper.png --transition-type any
```

## Security Considerations

1. **File Permissions**: Wallpapers are stored in user's home directory
2. **Resource Usage**: Monitor memory and GPU usage with animated wallpapers
3. **Images from Untrusted Sources**: Always validate images from external sources

## Maintenance

### Cleanup

Remove old wallpapers to save space:

```bash
# Clean cache
swww cache-cleanup

# Remove old wallpaper files
rm -rf ~/.config/wallpapers/cache/
```

### Updates

Update wallpaper tools with NixOS:

```bash
sudo nixos-rebuild switch --flake .#evo-x2
```

## Support

For issues:

1. Check the Hyprland and swwww documentation
2. Verify NixOS configuration is properly applied
3. Test with minimal configuration
4. Report issues with system information and error logs
