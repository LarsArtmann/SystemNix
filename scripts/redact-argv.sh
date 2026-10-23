#!/usr/bin/env bash
# redact-argv.sh — mask secret-looking values in argv text before it reaches
# a transcript, report, or status doc. Born from the 2026-10-22/23 incidents:
# `pgrep -af` output carried the monitor365 `--jwt-secret <value>` and the
# crm `-api-token <value>` into agent transcripts (the raw values are
# world-readable via /proc anyway — the mask protects the TRANSCRIPT, not
# the box; argv-carried secrets are their own upstream-class problem).
#
# Covers the two shapes secrets take on argv:
#   1. flag-with-value:      --jwt-secret s3cr3t   /  -api-token=abc   /  --API-Key xyz
#   2. env-style assignment: JWT_SECRET=abc MONITOR365_TOKEN=def
#
# Deliberately CONSERVATIVE: any flag containing secret/token/password/
# passphrase/api-key/credential (case-insensitive) masks its value, even
# when the value is mundane (--max-tokens 4096 masks too). Over-masking is
# safe; under-masking is the incident class this exists to prevent.
# Non-matching tokens pass through untouched.
#
# Usage:
#   pgrep -af monitor365 | scripts/redact-argv.sh
#   ss -ltnp 2>/dev/null | scripts/redact-argv.sh
set -euo pipefail

sed -E \
  -e 's/(-{1,2}[A-Za-z0-9_.-]*(secret|token|password|passwd|passphrase|api[_-]?key|credential)[A-Za-z0-9_.-]*)([= ][^ ]+)/\1=REDACTED/gI' \
  -e 's/([A-Za-z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|PASSPHRASE|API_KEY|APIKEY|CREDENTIAL)[A-Za-z0-9_]*)=([^ ]+)/\1=REDACTED/gI'
