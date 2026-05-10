#!/usr/bin/env bash
# ActivityWatch Utilization Watcher Installer for macOS
# https://github.com/Alwinator/aw-watcher-utilization

set -euo pipefail

AW_DIR="/Applications/ActivityWatch.app/Contents/MacOS"
WATCHER_NAME="aw-watcher-utilization"
WATCHER_DIR="$AW_DIR/$WATCHER_NAME"

echo "=== ActivityWatch Utilization Watcher Installer ==="
echo ""

# Check if ActivityWatch is installed
if [[ ! -d "/Applications/ActivityWatch.app" ]]; then
  echo "❌ ActivityWatch not found at /Applications/ActivityWatch.app"
  echo "   Please install ActivityWatch first: brew install --cask activitywatch"
  exit 1
fi

echo "✅ ActivityWatch found"

# Check if already installed
if [[ -d $WATCHER_DIR ]]; then
  echo "⚠️  aw-watcher-utilization already installed"
  echo "   To reinstall, remove: rm -rf '$WATCHER_DIR'"
  read -p "   Reinstall? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
  rm -rf "$WATCHER_DIR"
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo ""
echo "📥 Downloading aw-watcher-utilization..."

# Download latest release
curl -L "https://github.com/Alwinator/aw-watcher-utilization/releases/download/v1.2.2/aw-watcher-utilization" \
  -o "$TEMP_DIR/aw-watcher-utilization" 2>/dev/null || {
  echo "❌ Failed to download watcher"
  exit 1
}

echo "✅ Downloaded successfully"

# Create watcher directory
mkdir -p "$WATCHER_DIR"

# Extract and install
echo ""
echo "📦 Installing..."

# The release is a Python package, so we need to install it differently
# For macOS with Homebrew ActivityWatch, we install to the user's ActivityWatch directory
USER_AW_DIR="$HOME/Library/Application Support/activitywatch"
USER_WATCHER_DIR="$USER_AW_DIR/$WATCHER_NAME"

mkdir -p "$USER_WATCHER_DIR"

# Download and extract the source
curl -L "https://github.com/Alwinator/aw-watcher-utilization/archive/refs/tags/v1.2.2.tar.gz" \
  -o "$TEMP_DIR/source.tar.gz" 2>/dev/null

tar -xzf "$TEMP_DIR/source.tar.gz" -C "$TEMP_DIR"

# Install Python package locally
if command -v pip3 &>/dev/null; then
  pip3 install --user "$TEMP_DIR/aw-watcher-utilization-1.2.2" --quiet || {
    echo "⚠️  pip install failed, trying with --break-system-packages..."
    pip3 install --user "$TEMP_DIR/aw-watcher-utilization-1.2.2" --break-system-packages --quiet || {
      echo "❌ Failed to install Python package"
      echo "   Try: pip3 install --user aw-watcher-utilization"
      exit 1
    }
  }
else
  echo "❌ pip3 not found. Please install Python 3 and pip."
  exit 1
fi

echo "✅ Installed Python package"

# Create config directory
mkdir -p "$USER_WATCHER_DIR"

# Create default config
cat >"$USER_WATCHER_DIR/aw-watcher-utilization.toml" <<'EOF'
[aw-watcher-utilization]
poll_time = 5
EOF

echo "✅ Created default config"

# Add to aw-qt autostart (if config exists)
AWQT_CONFIG="$USER_AW_DIR/aw-qt/aw-qt.toml"
if [[ -f $AWQT_CONFIG ]]; then
  if ! grep -q "aw-watcher-utilization" "$AWQT_CONFIG" 2>/dev/null; then
    echo ""
    echo "📝 Adding to aw-qt autostart..."
    # Backup original
    cp "$AWQT_CONFIG" "$AWQT_CONFIG.backup"
    # Add to autostart_modules if it exists
    if grep -q "autostart_modules" "$AWQT_CONFIG"; then
      sed -i '' 's/autostart_modules = \[/autostart_modules = ["aw-watcher-utilization", /' "$AWQT_CONFIG"
    else
      echo -e "\n[aw-qt]\nautostart_modules = [\"aw-server\", \"aw-watcher-afk\", \"aw-watcher-window\", \"aw-watcher-utilization\"]" >>"$AWQT_CONFIG"
    fi
    echo "✅ Added to autostart"
  else
    echo "ℹ️  Already in autostart"
  fi
else
  echo "⚠️  aw-qt.toml not found. You may need to start the watcher manually."
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "🎉 aw-watcher-utilization is installed!"
echo ""
echo "Next steps:"
echo "  1. Restart ActivityWatch: just activitywatch-stop && just activitywatch-start"
echo "  2. Or start the watcher manually: aw-watcher-utilization"
echo "  3. Check the dashboard: http://localhost:5600"
echo ""
echo "📊 Collects: CPU, RAM, disk, network, sensors data every 5 seconds"
echo ""
echo "⚙️  Config location: $USER_WATCHER_DIR/aw-watcher-utilization.toml"
echo ""
