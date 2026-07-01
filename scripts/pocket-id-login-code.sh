#!/usr/bin/env bash
set -euo pipefail

API_KEY=$(sudo cat /run/secrets/pocket_id_static_api_key)
API_URL="http://127.0.0.1:1411"

# Get admin user ID
ADMIN_ID=$(curl -sf -H "X-API-Key: $API_KEY" \
  "$API_URL/api/users?pagination%5Blimit%5D=100" \
  | jq -r '.data[] | select(.isAdmin == true) | .id' | head -1)

if [ -z "$ADMIN_ID" ]; then
  echo "ERROR: No admin user found in Pocket ID" >&2
  exit 1
fi

# Generate one-time access token (1 hour = 3600s)
TOKEN=$(curl -sf -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"expiration":3600}' \
  "$API_URL/api/users/$ADMIN_ID/one-time-access-token" \
  | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to generate login code" >&2
  exit 1
fi

echo "https://auth.home.lan/lc/$TOKEN"
echo ""
echo "One-time code — expires in 1 hour, works once."
echo "After logging in, register a passkey on the new device."
