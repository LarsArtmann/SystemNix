# Audio Casting to Google Nest Audio - Quick Summary

## What I Did

### 1. Created Comprehensive Documentation

- **AUDIO_CASTING_HISTORY.md** - Complete history of all attempts, failures, and lessons learned
- **BLUETOOTH_SETUP_GUIDE.md** - Step-by-step guide for pairing and configuring Bluetooth

### 2. Implemented Bluetooth Solution

- **File:** `/home/lars/Setup-Mac/platforms/nixos/hardware/bluetooth.nix`
  - Enabled Bluetooth hardware support
  - Configured audio source/sink roles
  - Added Blueman GUI manager
  - Set up auto-connect on boot

- **File:** `/home/lars/Setup-Mac/platforms/nixos/system/configuration.nix`
  - Imported Bluetooth module into system configuration

### 3. Committed All Changes

- All changes committed to git with detailed message
- All pre-commit hooks passed (gitleaks, deadnix, statix, alejandra, flake check)

---

## Why This Approach?

### The Problem (What Went Wrong):

1. **FCast ≠ Google Cast** - Completely different protocols, incompatible
2. **Google Cast limitation** - Not designed for live system audio streaming
3. **Complex workaround required** - Would need 4-process chain (capture → encode → stream → cast)
4. **High latency** - Expected 2-5 second delay
5. **Poor reliability** - Multiple failure points, buffer issues

### The Solution (Bluetooth):

✅ Native Nest Audio support
✅ Simple, reliable setup
✅ Works with ALL system audio
✅ Low latency (50-200ms vs 2-5 seconds)
✅ No encoding overhead
✅ No internet required
✅ Just works once paired

---

## What You Need To Do (Next Steps)

### On evo-x2 System:

**Step 1: Rebuild NixOS**

```bash
cd /home/lars/Setup-Mac
sudo nixos-rebuild switch --flake .#evo-x2
```

**Step 2: Reboot (required for Bluetooth kernel modules)**

```bash
sudo reboot
```

**Step 3: After reboot, pair with Nest Audio**

**Option A - GUI (Recommended):**

```bash
blueman-manager
# Click Search → Select "Google Nest Audio" → Click Pair → Click Connect
```

**Option B - Command Line:**

```bash
# Turn on Bluetooth
bluetoothctl power on

# Scan for devices
bluetoothctl scan on
# Wait for "Google Nest Audio" to appear, note MAC address
bluetoothctl scan off

# Pair (replace XX:XX:XX:XX:XX:XX with actual MAC)
bluetoothctl pair XX:XX:XX:XX:XX:XX

# Connect
bluetoothctl connect XX:XX:XX:XX:XX:XX

# Trust for auto-connect
bluetoothctl trust XX:XX:XX:XX:XX:XX
```

**Step 4: Set Nest Audio as Default Audio Output**

```bash
# List available audio sinks
pactl list short sinks

# Set Nest Audio as default (replace with actual sink name)
pactl set-default-sink bluez_sink.XX_XX_XX_XX_XX_XX.a2dp_sink

# Or use GUI
pavucontrol
# Playback tab → Select "Nest Audio" from dropdown
```

**Step 5: Test**

```bash
# Play test sound
paplay /usr/share/sounds/freedesktop/stereo/complete.oga

# Or play any music file
vlc /path/to/music.mp3
# Then select Nest Audio as output in VLC
```

---

## Files Created/Modified

### New Files:

- `AUDIO_CASTING_HISTORY.md` - Complete project history
- `BLUETOOTH_SETUP_GUIDE.md` - Detailed setup instructions
- `platforms/nixos/hardware/bluetooth.nix` - Bluetooth configuration

### Modified Files:

- `platforms/nixos/system/configuration.nix` - Added Bluetooth import

### Unchanged (not relevant to Bluetooth):

- `cast-all-audio.sh` - Bash streaming script (abandoned)
- `cast-audio.go` - Go streaming program (abandoned)
- `go.mod` - Go module dependencies (abandoned)

---

## Expected Timeline

- **Rebuild:** 3-5 minutes
- **Reboot:** 1-2 minutes
- **Pairing:** 2-5 minutes
- **Testing:** 2-3 minutes

**Total:** 10-15 minutes from start to finish

---

## Success Criteria

✅ Bluetooth service running
✅ Nest Audio discovered and paired
✅ Nest Audio connected
✅ Nest Audio set as default audio output
✅ System audio playing through Nest Audio
✅ All applications routing audio to Nest Audio
✅ Audio quality acceptable (A2DP profile)

---

## Troubleshooting

### If Bluetooth won't start:

```bash
sudo systemctl start bluetooth
sudo systemctl enable bluetooth
bluetoothctl power on
```

### If Nest Audio not found during scan:

```bash
# Make sure Bluetooth is powered on
bluetoothctl power on

# Try scanning for up to 30 seconds
bluetoothctl scan on
# Wait and watch for "Google Nest Audio"
bluetoothctl scan off
```

### If pairing fails:

```bash
# Remove any existing pairing
bluetoothctl remove XX:XX:XX:XX:XX:XX

# Try again
bluetoothctl pair XX:XX:XX:XX:XX:XX
# Try PIN codes: 0000, 1234
```

### If no audio comes from Nest Audio:

```bash
# Check output device
pactl list short sinks

# Set as default
pactl set-default-sink bluez_sink.XX_XX_XX_XX_XX_XX.a2dp_sink

# Check volume
pactl set-sink-volume bluez_sink.XX_XX_XX_XX_XX_XX.a2dp_sink 50%

# Use pavucontrol GUI
pavucontrol
# Output Devices tab → Increase Nest Audio volume
```

---

## Reference Documentation

- **Full History:** `AUDIO_CASTING_HISTORY.md` - All attempts, failures, findings
- **Detailed Setup:** `BLUETOOTH_SETUP_GUIDE.md` - Complete step-by-step instructions
- **Quick Reference:** This file - Summary and quick commands

---

## Why This Is Better Than the Streaming Scripts

| Aspect           | Bluetooth | Streaming Scripts   |
| ---------------- | --------- | ------------------- |
| Reliability      | High      | Low                 |
| Complexity       | Low       | Very High           |
| Latency          | 50-200ms  | 2-5 seconds         |
| Audio Quality    | No loss   | Encoding loss       |
| Setup Time       | 10-15 min | 30+ min + debugging |
| Maintenance      | Minimal   | High                |
| Works Offline    | Yes       | No                  |
| All System Audio | Yes       | Questionable        |
| Failure Points   | 1         | 4+                  |

---

## Next Steps After Success

1. **Enable auto-connect** - Nest Audio will connect automatically on boot
2. **Test with different apps** - Music, videos, games, system sounds
3. **Check audio quality** - Verify A2DP profile is active
4. **Test range** - Move around and ensure stable connection
5. **Add other devices** - If you have more Bluetooth speakers

---

## Quick Commands Reference

```bash
# Bluetooth power
bluetoothctl power on
bluetoothctl power off

# Scan for devices
bluetoothctl scan on
bluetoothctl scan off

# Pair/Connect/Trust
bluetoothctl pair XX:XX:XX:XX:XX:XX
bluetoothctl connect XX:XX:XX:XX:XX:XX
bluetoothctl trust XX:XX:XX:XX:XX:XX

# Audio output
pactl set-default-sink bluez_sink.XX_XX_XX_XX_XX_XX.a2dp_sink
pactl list short sinks

# GUI tools
blueman-manager  # Bluetooth GUI
pavucontrol      # Audio control

# Service status
systemctl status bluetooth
sudo systemctl restart bluetooth
```

---

**Current Status:** Configuration complete, ready to rebuild and test

**Commit:** `db0886f` - "feat(nixos): add Bluetooth support for Google Nest Audio audio casting"

**Next Action:** Rebuild NixOS on evo-x2 and follow BLUETOOTH_SETUP_GUIDE.md

---

_Summary Created: 2025-12-31_
_Author: Crush AI Assistant_
