#!/usr/bin/env bash
# Post-mutation smoke for browser-history manual (non-deploy) mutations:
# stop-window ops, manual sqlite edits, config hand-edits. Three probes,
# each aimed at a historical failure class:
#   1. /health poll-until-ANSWERED  — bind race (Type=simple = spawned, not
#      bound; is-active lies for ~seconds) and the freshness-503 class
#      (a restarted server answers 503 until the first agent ingest — ANY
#      answered status is success here).
#   2. one agent ingest tick         — agent wedge / token rejection
#      (journal raw=/kept= or accepted lines since the mutation start).
#   3. browser_history_users gauge   — read-model rollback / count drift
#      (textfile collector, not the HTTP metrics port — survives server
#      restarts).
# Usage: scripts/mutation-smoke.sh [expected_users]   (default: probe only)
set -euo pipefail

PORT=8087
AGENT_UNIT=browser-history-agent.service
TEXTFILE=/var/lib/prometheus-node-exporter/textfile_collectors/browser-history-agent.prom
TIMEOUT_S=120
EXPECTED_USERS="${1:-}"

fail() { echo "mutation-smoke: FAIL — $1" >&2; exit 1; }

since=$(date '+%Y-%m-%d %H:%M:%S')

# Probe 1: health answered (any status).
answered=""
for _ in $(seq 1 "$TIMEOUT_S"); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
    "http://localhost:${PORT}/health" 2>/dev/null || true)
  if [ -n "$code" ] && [ "$code" != "000" ]; then
    answered="$code"
    break
  fi
  sleep 1
done
[ -n "$answered" ] || fail "/health never answered within ${TIMEOUT_S}s (bind race or dead server)"
echo "ok: /health answered (status $answered)"

# Probe 2: one agent tick since the mutation window.
tick=""
for _ in $(seq 1 "$TIMEOUT_S"); do
  if journalctl -u "$AGENT_UNIT" --since "$since" --no-pager 2>/dev/null \
    | grep -Eq 'raw=[0-9]+|accepted:[0-9]+|total:[0-9]+'; then
    tick=1
    break
  fi
  sleep 3
done
[ -n "$tick" ] || fail "no browser-history-agent ingest tick within ${TIMEOUT_S}s (agent wedge or token rejection — journalctl -u $AGENT_UNIT -n 30)"
echo "ok: agent ingest tick observed since $since"

# Probe 3: users gauge (textfile; survives server restarts).
if [ -r "$TEXTFILE" ]; then
  users=$(grep -E '^browser_history_users ' "$TEXTFILE" | awk '{print $2}')
  if [ -z "$users" ]; then
    fail "browser_history_users absent from $TEXTFILE (collector failing — the zero-agents alert class)"
  fi
  if [ -n "$EXPECTED_USERS" ] && [ "$users" != "$EXPECTED_USERS" ]; then
    fail "browser_history_users = $users, expected $EXPECTED_USERS (rollback or count drift)"
  fi
  echo "ok: browser_history_users = $users"
else
  echo "warn: textfile $TEXTFILE not readable — users gauge probe skipped"
fi

echo "mutation-smoke: all probes green"
