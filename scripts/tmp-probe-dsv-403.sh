#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then exec sudo -n bash "$0"; fi
env_file=/var/lib/discordsync/immich-api-env
url=$(sed -n 's/^IMMICH_URL=//p' "$env_file")
key=$(sed -n 's/^IMMICH_API_KEY=//p' "$env_file")
if [ -z "$key" ]; then echo "env file unreadable/empty"; exit 2; fi
echo "url=$url key_bytes=${#key}"
c1=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "X-Api-Key: $key" "$url/api/users/me" || echo 000)
echo "GET  /api/users/me -> HTTP $c1"
c2=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "X-Api-Key: $key" -H 'Content-Type: application/json' -d '{"assets":[{"id":"verify-probe","checksum":"2jmj7l5rSw0yVb/vlWAYkK/YBwk="}]}' "$url/api/assets/bulk-upload-check" || echo 000)
echo "POST /api/assets/bulk-upload-check (assets shape, base64 sha1 of empty) -> HTTP $c2"
echo "--- bulk-upload-check body (first 300B) ---"
curl -s --max-time 10 -H "X-Api-Key: $key" -H 'Content-Type: application/json' -d '{"assets":[{"id":"verify-probe","checksum":"2jmj7l5rSw0yVb/vlWAYkK/YBwk="}]}' "$url/api/assets/bulk-upload-check" | head -c 300
echo
echo "--- users/me body (first 300B) ---"
curl -s --max-time 10 -H "X-Api-Key: $key" "$url/api/users/me" | head -c 300
echo
