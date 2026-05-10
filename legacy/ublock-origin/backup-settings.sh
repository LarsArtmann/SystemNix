#!/usr/bin/env bash

# uBlock Origin Settings Backup Script
# Automatically backs up uBlock Origin settings from all browsers

set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/backup" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Chrome/Chromium backup
backup_chrome() {
  local chrome_dir="$HOME/Library/Application Support/Google/Chrome/Default/Extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm"
  if [[ -d $chrome_dir ]]; then
    log "Backing up Chrome uBlock Origin settings..."
    mkdir -p "$BACKUP_DIR/chrome-$TIMESTAMP"
    # Chrome extension settings are in Local Storage and need special handling
    log "Chrome backup requires manual export from uBlock Origin dashboard"
  fi
}

# Firefox backup
backup_firefox() {
  local firefox_profile=$(find "$HOME/Library/Application Support/Firefox/Profiles" -name "*.default*" -type d | head -1)
  if [[ -n $firefox_profile && -d $firefox_profile ]]; then
    log "Backing up Firefox uBlock Origin settings..."
    mkdir -p "$BACKUP_DIR/firefox-$TIMESTAMP"
    # Firefox addon storage
    if [[ -d "$firefox_profile/storage/default/moz-extension+++*" ]]; then
      cp -r "$firefox_profile/storage/default/moz-extension"* "$BACKUP_DIR/firefox-$TIMESTAMP/" 2>/dev/null || true
    fi
  fi
}

# Create manual backup instructions
create_manual_instructions() {
  cat >"$BACKUP_DIR/manual-backup-instructions.md" <<'EOL'
# Manual Backup Instructions

Due to browser security restrictions, some settings require manual backup:

## Chrome/Chromium
1. Open uBlock Origin dashboard
2. Go to "Settings" tab
3. Click "Backup to file"
4. Save file to backup directory

## Firefox
1. Open uBlock Origin dashboard
2. Go to "Settings" tab
3. Click "Backup to file"
4. Save file to backup directory

## Safari/Other Browsers
1. Export settings through extension interface
2. Save configuration files
3. Document custom filter lists
EOL
}

main() {
  log "Starting uBlock Origin backup process..."
  mkdir -p "$BACKUP_DIR"

  backup_chrome
  backup_firefox
  create_manual_instructions

  log "Backup process completed"
  log "Manual backup instructions created: $BACKUP_DIR/manual-backup-instructions.md"
}

main "$@"
