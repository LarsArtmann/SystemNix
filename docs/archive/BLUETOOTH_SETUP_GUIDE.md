# Bluetooth Setup for Google Nest Audio

**Target:** Stream system-wide audio to Google Nest Audio via Bluetooth
**Device:** Google Nest Audio (192.168.1.150)
**System:** NixOS on evo-x2

---

## Configuration Changes Made

### 1. Created Bluetooth Configuration

**File:** `/home/lars/Setup-Mac/platforms/nixos/hardware/bluetooth.nix`

```nix
{
  # Bluetooth configuration for audio casting to Google Nest Audio
  # Nest Audio supports Bluetooth audio streaming natively
  # This is the recommended approach over Google Cast for system-wide audio

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Enable audio source and sink roles
        Enable = "Source,Sink,Media,Socket";
        # Auto-connect to paired devices
        AutoEnable = true;
      };
    };
  };

  # Blueman: GTK+ Bluetooth Manager with GUI
  services.blueman.enable = true;

  # PipeWire handles Bluetooth audio automatically when enabled
}
```

### 2. Added Bluetooth Module to System Configuration

**File:** `/home/lars/Setup-Mac/platforms/nixos/system/configuration.nix`
**Line 13:** Added `../hardware/bluetooth.nix` to imports

---

## Step 1: Rebuild NixOS System

**Run on evo-x2:**

```bash
cd /home/lars/Setup-Mac
sudo nixos-rebuild switch --flake .#evo-x2
```

**Expected Output:**

- Configuration builds successfully
- Bluetooth service enabled
- Blueman installed
- No errors

---

## Step 2: Reboot System

**Required for Bluetooth kernel modules to load:**

```bash
sudo reboot
```

---

## Step 3: Verify Bluetooth is Running

After reboot:

```bash
# Check if Bluetooth service is running
systemctl status bluetooth

# Check if Bluetooth hardware is detected
rfkill list

# Turn on Bluetooth (if not already on)
sudo systemctl start bluetooth
bluetoothctl power on
```

**Expected Output:**

```
# bluetoothctl power on
Changing power on succeeded
[CHG] Controller XX:XX:XX:XX:XX:XX Powered: yes
```

---

## Step 4: Pair with Google Nest Audio

### Option A: Using Bluetooth GUI (Recommended)

1. **Open Bluetooth Manager:**

   ```bash
   blueman-manager
   ```

2. **Search for Nest Audio:**
   - Click the "Search" button (magnifying glass)
   - Look for "Google Nest Audio" in the list

3. **Pair:**
   - Select "Google Nest Audio"
   - Click "Pair"
   - If prompted for a PIN code, try `0000` or `1234`
   - Nest Audio will announce the pairing

4. **Connect:**
   - After pairing, click "Connect"
   - Nest Audio will say "Connected"

### Option B: Using Command Line

```bash
# Start scanning
bluetoothctl scan on

# Look for Nest Audio (MAC address will appear)
# Example output:
# [NEW] Device 00:11:22:33:44:55 Google Nest Audio

# Stop scanning
bluetoothctl scan off

# Pair with Nest Audio (replace MAC address)
bluetoothctl pair 00:11:22:33:44:55

# Connect to Nest Audio
bluetoothctl connect 00:11:22:33:44:55

# Trust the device (auto-connect in future)
bluetoothctl trust 00:11:22:33:44:55

# Set as default audio output
# Use pavucontrol or the GUI to select Nest Audio as output
```

**Expected Pairing Output:**

```
# bluetoothctl pair 00:11:22:33:44:55
Attempting to pair with 00:11:22:33:44:55
[CHG] Device 00:11:22:33:44:55 Connected: yes
[CHG] Device 00:11:22:33:44:55 Paired: yes
Pairing successful

# bluetoothctl connect 00:11:22:33:44:55
Attempting to connect to 00:11:22:33:44:55
[CHG] Device 00:11:22:33:44:55 Connected: yes
Connection successful
```

---

## Step 5: Set Nest Audio as Default Audio Output

### Using Blueman Manager (GUI):

1. Open `blueman-manager`
2. Right-click on "Google Nest Audio"
3. Select "Audio Profile"
4. Choose "High Fidelity Playback (A2DP Sink)"
5. Click "Set as Default Audio Device" if available

### Using PipeWire CLI:

```bash
# List all audio sinks
pactl list short sinks

# Find Nest Audio sink (look for "bluez" or "Nest Audio" in output)
# Example output:
# 0	alice_card	...
# 1	bluez_sink.00_11_22_33_44_55.a2dp_sink	...

# Set Nest Audio as default sink (replace with actual sink name)
pactl set-default-sink bluez_sink.00_11_22_33_44_55.a2dp_sink

# Or set system default:
wpctl set-default bluez_sink.00_11_22_33_44_55.a2dp_sink
```

### Using Pavucontrol (GUI):

```bash
pavucontrol
```

1. Go to "Playback" tab
2. Select "Nest Audio" from the dropdown
3. All audio will now route to Nest Audio

---

## Step 6: Test Audio Streaming

### Test with System Sounds:

```bash
# Play test sound
paplay /usr/share/sounds/freedesktop/stereo/complete.oga

# Or play any audio file
vlc /path/to/music.mp3
# Then select Nest Audio as output in VLC
```

### Test with YouTube/Music:

1. Open ungoogled-chromium (Helium)
2. Play any audio/video
3. Verify sound comes from Nest Audio

### Test with System Audio:

- All system sounds should route to Nest Audio
- Notifications, music, videos, games - everything

---

## Step 7: Set Auto-Connect (Optional)

To make Nest Audio auto-connect on boot:

### Using Blueman Manager:

1. Right-click on "Google Nest Audio"
2. Check "Auto-connect"

### Using Command Line:

```bash
bluetoothctl trust 00:11:22:33:44:55
bluetoothctl connect 00:11:22:33:44:55
```

The device will now automatically connect when in range and Bluetooth is on.

---

## Troubleshooting

### Bluetooth Not Starting

```bash
# Check service status
systemctl status bluetooth

# Start service
sudo systemctl start bluetooth

# Enable on boot
sudo systemctl enable bluetooth
```

### Device Not Found During Scan

```bash
# Make sure Bluetooth is on
bluetoothctl power on

# Try extended scan
bluetoothctl scan on
# Wait up to 30 seconds, Nest Audio should appear

# Restart Bluetooth controller
bluetoothctl power off
bluetoothctl power on
```

### Pairing Fails

```bash
# Remove existing pairing (if any)
bluetoothctl remove 00:11:22:33:44:55

# Try pairing again
bluetoothctl pair 00:11:22:33:44:55

# If asked for PIN code, try: 0000, 1234, or check Nest Audio bottom
```

### Connection Drops

```bash
# Check signal strength
bluetoothctl info 00:11:22:33:44:55

# Move closer to Nest Audio (should be within 30 ft / 10 m)
# Remove other Bluetooth devices that might interfere

# Reconnect
bluetoothctl disconnect 00:11:22:33:44:55
bluetoothctl connect 00:11:22:33:44:55
```

### Audio Quality Issues

```bash
# Use A2DP profile (better quality than HSP/HFP)
# Blueman Manager: Right-click Nest Audio → Audio Profile → High Fidelity Playback (A2DP Sink)

# Or via command line:
pactl set-card-profile <card_name> a2dp_sink

# Check current profile
pactl list cards | grep -A 20 "Nest Audio"
```

### No Audio Output

```bash
# Check if Nest Audio is selected as output
pactl list short sinks

# Set as default
pactl set-default-sink bluez_sink.00_11_22_33_44:55.a2dp_sink

# Check volume
pactl set-sink-volume bluez_sink.00_11_22_33_44:55.a2dp_sink 50%

# Or use pavucontrol
pavucontrol
# Go to "Output Devices" tab, increase Nest Audio volume
```

### Audio Latency/Delay

Bluetooth audio typically has 50-200ms latency. This is normal.

If latency is unacceptable:

1. Use wired connection (not possible with Nest Audio)
2. Accept Bluetooth delay (normal behavior)
3. Google Cast would have similar or worse latency (2-5 seconds)

---

## Why Bluetooth Instead of Google Cast?

### Bluetooth Advantages:

✅ **Native Support:** Nest Audio has built-in Bluetooth
✅ **Simple:** No complex streaming setup
✅ **Reliable:** No protocol issues
✅ **All Audio:** Streams everything - system sounds, music, videos, games
✅ **Low Latency:** 50-200ms (vs 2-5 seconds for casting)
✅ **No Encoding:** Direct audio stream, no quality loss
✅ **Always Connected:** Once paired, just works
✅ **No Internet Required:** Works offline

### Google Cast Disadvantages:

❌ **Protocol Limitation:** Not designed for live system audio
❌ **Complex:** Requires capture → encode → stream → cast chain
❌ **High Latency:** 2-5 seconds delay
❌ **Quality Loss:** Encoding overhead
❌ **Buffer Issues:** Continuous streams may stutter
❌ **Internet Required:** Even for local casting
❌ **Not Reliable:** Multiple failure points

---

## Quick Reference Commands

```bash
# Toggle Bluetooth power
bluetoothctl power on
bluetoothctl power off

# Scan for devices
bluetoothctl scan on
bluetoothctl scan off

# Pair, connect, trust
bluetoothctl pair 00:11:22:33:44:55
bluetoothctl connect 00:11:22:33:44:55
bluetoothctl trust 00:11:22:33:44:55

# Disconnect
bluetoothctl disconnect 00:11:22:33:44:55

# Set default audio sink
pactl set-default-sink bluez_sink.00_11_22_33_44:55.a2dp_sink

# List audio devices
pactl list short sinks

# Open GUI tools
blueman-manager
pavucontrol

# Check service status
systemctl status bluetooth

# Restart service
sudo systemctl restart bluetooth
```

---

## Success Criteria

✅ Bluetooth service running
✅ Nest Audio discovered and paired
✅ Nest Audio connected
✅ Nest Audio set as default audio output
✅ System audio playing through Nest Audio
✅ All applications routing audio to Nest Audio
✅ Audio quality acceptable (A2DP profile)
✅ Auto-connect configured (optional)

---

## Next Steps After Success

1. **Set Auto-Connect:** Make Nest Audio connect automatically on boot
2. **Configure Multiple Devices:** Add other Bluetooth speakers if desired
3. **Create Desktop Shortcuts:** Add quick connect/disconnect scripts
4. **Audio Quality Testing:** Verify A2DP profile is active
5. **Range Testing:** Ensure reliable connection throughout home

---

**Expected Total Setup Time:** 10-15 minutes
**Reliability:** High
**Complexity:** Low
**Maintenance:** Minimal (pair once, use forever)

---

_Created: 2025-12-31_
_Author: Crush AI Assistant_
