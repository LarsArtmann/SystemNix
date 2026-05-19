#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_FILE="$REPO_ROOT/platforms/nixos/secrets/secrets.yaml"
AGE_KEY_FILE="/run/secrets.d/age-keys.txt"

if [[ ! -r "$AGE_KEY_FILE" ]]; then
  echo "Error: Cannot read $AGE_KEY_FILE (need sudo)"
  exit 1
fi

export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
SOPS="$(nix build nixpkgs#sops --no-link --print-out-paths)/bin/sops"

echo "=== Rename sops key: gitea_token → forgejo_token ==="
echo "Using sops: $SOPS"

# Check if gitea_token exists
if $SOPS -d --extract '["gitea_token"]' "$SECRETS_FILE" >/dev/null 2>&1; then
  echo "Found gitea_token — renaming to forgejo_token"

  # Get current value
  VALUE=$($SOPS -d --extract '["gitea_token"]' "$SECRETS_FILE")
  echo "Got value (${#VALUE} chars)"

  # Set new key
  $SOPS set "$SECRETS_FILE" '["forgejo_token"]' "\"$VALUE\""
  echo "Set forgejo_token"

  # Remove old key
  $SOPS unset "$SECRETS_FILE" '["gitea_token"]'
  echo "Removed gitea_token"

  echo "Done: gitea_token → forgejo_token"
else
  echo "gitea_token not found — may already be renamed"
fi

# Verify
echo ""
echo "Verification:"
$SOPS -d --extract '["forgejo_token"]' "$SECRETS_FILE" >/dev/null 2>&1 && echo "forgejo_token: OK" || echo "forgejo_token: NOT FOUND"
! $SOPS -d --extract '["gitea_token"]' "$SECRETS_FILE" >/dev/null 2>&1 && echo "gitea_token: removed OK" || echo "gitea_token: STILL EXISTS (unexpected)"
