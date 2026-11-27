#!/usr/bin/env bash
# redact-argv.sh — mask secret-looking values in argv text before it reaches
# a transcript, report, or status doc. Born from the 2026-10-22/23 incidents:
# `pgrep -af` output carried the monitor365 `--jwt-secret <value>` and the
# crm `-api-token <value>` into agent transcripts (the raw values are
# world-readable via /proc anyway — the mask protects the TRANSCRIPT, not
# the box; argv-carried secrets are their own upstream-class problem).
#
# ONE redaction program: hooks/redact.sed of the crush-config repo (the
# same file crush's redact-argv-output and stop-failure-log hooks run).
# Until 2026-11-27 this script carried its own two expressions; a third
# copy of a redaction policy drifts, and drift here is a transcript leak.
# Resolution order: $REDACT_SED, then the sibling checkout
# (<parent>/crush-config/hooks/redact.sed). Without a program the script
# FAILS CLOSED (exit 1, nothing printed): unredacted argv must never pass.
#
# Usage:
#   pgrep -af monitor365 | scripts/redact-argv.sh
#   ss -ltnp 2>/dev/null | scripts/redact-argv.sh
set -euo pipefail

if [[ -n ${REDACT_SED:-} ]]; then
  program="$REDACT_SED"
else
  program="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/../crush-config/hooks/redact.sed"
fi
if [[ ! -r $program ]]; then
  echo "redact-argv: redaction program not found: $program (set REDACT_SED to hooks/redact.sed of a crush-config checkout); output withheld" >&2
  exit 1
fi

sed -E -f "$program"
