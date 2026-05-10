#!/usr/bin/env bash

# uBlock Origin Filter Update Script
# Automatically updates custom filter lists and checks for updates

set -euo pipefail

FILTERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/filters" && pwd)"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Update custom filters with latest content
update_custom_filters() {
  log "Checking for filter list updates..."

  # Add timestamp to filter files
  local timestamp=$(date +%Y%m%d)

  # Update version in custom filters
  if [[ -f "$FILTERS_DIR/custom-filters.txt" ]]; then
    sed -i.bak "s/! Version: .*/! Version: 1.0.$timestamp/" "$FILTERS_DIR/custom-filters.txt"
    rm -f "$FILTERS_DIR/custom-filters.txt.bak"
    log "Updated custom filters version"
  fi

  log "Filter update completed"
}

# Validate filter syntax
validate_filters() {
  log "Validating filter syntax..."

  for filter_file in "$FILTERS_DIR"/*.txt; do
    if [[ -f $filter_file ]]; then
      # Basic syntax validation
      if grep -q "^[^!].*\$.*[^$]$" "$filter_file" 2>/dev/null; then
        log "Warning: Potential syntax issues in $(basename "$filter_file")"
      else
        log "✓ $(basename "$filter_file") syntax OK"
      fi
    fi
  done
}

main() {
  log "Starting filter update process..."
  update_custom_filters
  validate_filters
  log "Filter update process completed"
}

main "$@"
