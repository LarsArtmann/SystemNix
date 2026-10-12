#!/usr/bin/env bash
# regenerateSecretsFor stale-list guard for pocket-id-provision.
#
# A regenerateSecretsFor entry is meant to survive EXACTLY ONE deploy
# (set -> deploy rotates -> clear the list). An entry that survives past
# that deploy re-rotates the client secret on EVERY subsequent provision
# run, silently desyncing every LoadCredential/env-file consumer that
# still holds the previous secret (the 2026-08-22 dnsblockd SSO class).
# This guard fails the provision run loudly instead of allowing the
# silent re-rotation.
#
# Usage: pocket-id-regenerate-guard.sh <secret-file> <client-id> <window-hours>
#
# Exit codes:
#   0  proceed (file missing -> recreation path, or file older than window)
#   1  GUARD TRIPPED (file fresh inside window while still listed)
set -euo pipefail

usage() {
  echo "usage: $0 <secret-file> <client-id> <window-hours>" >&2
  exit 2
}

[ $# -eq 3 ] || usage
SECRET_FILE=$1
CLIENT_ID=$2
WINDOW_HOURS=$3

case "$WINDOW_HOURS" in
'' | *[!0-9]*) usage ;;
esac

# No file yet: nothing was rotated before, the regeneration is the
# intended first write (or the recovery path after an rm escape hatch).
[ -f "$SECRET_FILE" ] || exit 0

now=$(date +%s)
mtime=$(stat -c %Y "$SECRET_FILE")
age_hours=$(((now - mtime) / 3600))

if [ "$age_hours" -lt "$WINDOW_HOURS" ]; then
  {
    echo "pocket-id regenerateSecretsFor GUARD: client '$CLIENT_ID' secret was already regenerated ${age_hours}h ago (window: ${WINDOW_HOURS}h) but is STILL listed in services.pocket-id-config.provision.regenerateSecretsFor."
    echo "  Re-rotating now would silently invalidate every consumer still holding the previous secret (LoadCredential/env-file desync, dnsblockd 2026-08-22 class)."
    echo "  FIX: remove \"$CLIENT_ID\" from services.pocket-id-config.provision.regenerateSecretsFor and redeploy."
    echo "  Escape hatch for a genuine re-rotation NOW: sudo rm '$SECRET_FILE' && sudo systemctl restart pocket-id-provision"
  } >&2
  exit 1
fi

exit 0
