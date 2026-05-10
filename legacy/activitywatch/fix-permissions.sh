#!/usr/bin/env bash
# ActivityWatch Permission Helper
# This script resets and guides through permission setup

set -e

echo "=== ActivityWatch Permission Helper ==="
echo ""

# Reset existing permissions
echo "Resetting ActivityWatch permissions..."
tccutil reset All net.activitywatch.ActivityWatch 2>/dev/null || true
echo "✓ Permissions reset"
echo ""

# Check if profile exists
PROFILE="$HOME/.config/activitywatch/tcc-profile.mobileconfig"
if [[ -f $PROFILE ]]; then
  echo "Opening configuration profile..."
  open "$PROFILE"
  echo ""
  echo "=== ACTION REQUIRED ==="
  echo "1. Click 'Install' in the profile dialog"
  echo "2. Enter your password if prompted"
  echo "3. Return here and press Enter"
  read -p "Press Enter when profile is installed..."
else
  echo "Opening System Settings..."
  open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
  echo ""
  echo "=== ACTION REQUIRED ==="
  echo "1. Click the '+' button"
  echo "2. Navigate to /Applications/ActivityWatch.app"
  echo "3. Check the checkbox next to ActivityWatch"
  echo "4. Return here and press Enter"
  read -p "Press Enter when done..."
fi

echo ""
echo "Restarting ActivityWatch..."
launchctl unload ~/Library/LaunchAgents/net.activitywatch.ActivityWatch.plist 2>/dev/null || true
sleep 2
launchctl load ~/Library/LaunchAgents/net.activitywatch.ActivityWatch.plist 2>/dev/null || true
echo "✓ ActivityWatch restarted"
echo ""
echo "Done! URL tracking should work now."
echo "Test with: open http://localhost:5600/api/0/buckets/aw-watcher-window_Lars-MacBook-Air.local/events?limit=1"
