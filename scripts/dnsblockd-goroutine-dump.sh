#!/usr/bin/env bash
# dnsblockd wedge forensics — capture the goroutine dump BEFORE restarting.
#
# 2026-08-27: dnsblockd's :9090 stats API wedged for ~3h (every HTTP handler
# stuck mid-request, CLOSE_WAIT pileup, process idle, DNS itself flawless).
# The instance healed via a deploy restart BEFORE anyone captured a dump, so
# the root cause (suspected healthProbe.Evaluate() DB check or a tracking-DB
# mutex block) is still unknown. This runbook makes the NEXT occurrence a
# 10-minute diagnosis instead of a lost sample.
#
# WHAT IT DOES (root required for kill -QUIT and journal read):
#   1. Confirms the wedge (curl :9090/health + /metrics with 5s timeouts)
#   2. Snapshots pre-kill state: fd count, CLOSE_WAIT count, goroutine-ish
#      thread count, last journal lines
#   3. Sends SIGQUIT -> Go runtime prints EVERY goroutine stack to stderr
#      (journald captures it) and the process exits -> systemd restarts it
#   4. Waits for the restart, verifies :53 (DNS) and :9090 (stats) recovered
#   5. Prints the journalctl command that shows the dump + where to look
#
# GOTRACEBACK=all is baked into dnsblockd.service Environment since
# 2026-08-27 — without it the default "single" mode only shows the
# signal-handling goroutine and says NOTHING about a mutex deadlock.
#
# Usage:
#   sudo bash scripts/dnsblockd-goroutine-dump.sh            # dump + restart
#   sudo FORCE=1 bash scripts/dnsblockd-goroutine-dump.sh    # skip wedge check
#                                                             (already verified)
# Exit codes: 0 = dump captured (or service healthy, nothing to do),
#             1 = wedge confirmed but dump/restart failed.
set -euo pipefail

STATS_PORT="${STATS_PORT:-9090}"
SERVICE="dnsblockd"
TIMEOUT_S=5

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: needs root (kill -QUIT on a root-owned process + journal read)." >&2
  echo "  sudo bash scripts/dnsblockd-goroutine-dump.sh" >&2
  exit 1
fi

# Resolve every binary up front — sudo's secure PATH hides user-profile tools
# (gptfdisk lesson, 2026-08-22 migrate-clickhouse-xfs).
for bin in curl ss pidof journalctl systemctl grep wc awk ls cat sleep seq; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: required binary '$bin' not found in PATH" >&2
    exit 1
  }
done

health_code() {
  # curl ALWAYS prints the -w output (000) even on failure — `|| echo 000`
  # double-emits "000\n000"; `|| true` keeps curl's own value.
  curl -s --compressed --max-time "$TIMEOUT_S" -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true
}

echo "=== [1] Wedge confirmation =========================================="
HEALTH_CODE=$(health_code "http://127.0.0.1:${STATS_PORT}/health")
METRICS_CODE=$(health_code "http://127.0.0.1:${STATS_PORT}/metrics")
echo "stats :${STATS_PORT} /health -> ${HEALTH_CODE} (000/timeout = wedged), /metrics -> ${METRICS_CODE}"

if [ "${FORCE:-0}" != "1" ]; then
  if [ "$HEALTH_CODE" != "000" ] && [ "$METRICS_CODE" != "000" ]; then
    echo "Both stats endpoints answered — no wedge detected. Nothing to do."
    echo "(If you still suspect a partial wedge, rerun with FORCE=1.)"
    exit 0
  fi
else
  echo "FORCE=1: skipping wedge gate on user request."
fi

PID=$(pidof "$SERVICE" || true)
if [ -z "$PID" ]; then
  echo "ERROR: no ${SERVICE} process found — nothing to dump." >&2
  exit 1
fi

echo ""
echo "=== [2] Pre-kill snapshot ==========================================="
FD_COUNT=$(ls /proc/"$PID"/fd 2>/dev/null | wc -l) || true
CLOSE_WAIT=$(ss -tan 2>/dev/null | grep -c CLOSE-WAIT) || true
THREADS=$(awk '/^Threads:/{print $2}' /proc/"$PID"/status 2>/dev/null) || true
echo "pid=$PID fds=$FD_COUNT threads=$THREADS host-wide CLOSE-WAIT=$CLOSE_WAIT"
echo "--- last 5 journal lines before the dump ---"
journalctl -u "$SERVICE" -n 5 --no-pager --output cat 2>/dev/null || true

echo ""
echo "=== [3] SIGQUIT goroutine dump ======================================"
echo "Sending SIGQUIT to $SERVICE (pid $PID) — the Go runtime prints every"
echo "goroutine stack to the journal, then the process exits (systemd restarts it)."
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id)
kill -QUIT "$PID"

echo ""
echo "=== [4] Waiting for restart ========================================="
for _ in $(seq 1 30); do
  sleep 2
  NEW_PID=$(pidof "$SERVICE" || true)
  DNS_UP=$(ss -tlnp 2>/dev/null | grep -q ':53 ' && echo yes || echo no)
  if [ -n "$NEW_PID" ] && [ "$NEW_PID" != "$PID" ] && [ "$DNS_UP" = "yes" ]; then
    echo "restarted: new pid $NEW_PID, :53 listening"
    break
  fi
done

sleep 3
POST_HEALTH=$(health_code "http://127.0.0.1:${STATS_PORT}/health")
echo "post-restart :${STATS_PORT}/health -> ${POST_HEALTH}"

echo ""
echo "=== [5] Dump-capture verification ==================================="
# journald rate-limiting can silently DROP a multi-MB goroutine stack burst —
# without this check the runbook reports success while the sample (its entire
# purpose) is lost. Go's SIGQUIT output always starts with 'SIGQUIT: quit'.
DUMP_HITS=$(timeout 20 journalctl -b "$BOOT_ID" -u "$SERVICE" --no-pager --output cat 2>/dev/null | grep -c 'SIGQUIT: quit') || true
DUMP_HITS="${DUMP_HITS:-0}"
if [ "$DUMP_HITS" -ge 1 ]; then
  echo "✓ goroutine dump CAPTURED in the journal ($DUMP_HITS signature hit(s))."
else
  echo "✗✗✗ GOROUTINE DUMP NOT FOUND IN THE JOURNAL ✗✗✗"
  echo "  The service was restarted but the forensic sample was likely dropped"
  echo "  by journald rate-limiting (multi-MB stderr bursts). Before the NEXT"
  echo "  occurrence: raise LogRateLimitBurst/LogRateLimitIntervalSec on the"
  echo "  dnsblockd unit, or capture stderr to a file. Check manually first:"
  echo "    journalctl -b '$BOOT_ID' -u $SERVICE --no-pager | tail -200"
fi

echo ""
echo "Goroutine stacks (grep-friendly):"
echo "  journalctl -b '$BOOT_ID' -u $SERVICE --no-pager | grep -A40 'SIGQUIT'"
echo "Look for: goroutines blocked on sync./sqlite locks (semacquire),"
echo "healthProbe.Evaluate, tracking-DB writes, http server handlers in"
echo "select/wait states that never return. Attach the relevant excerpt to"
echo "the upstream dnsblockd issue — the 2026-08-27 wedge root cause is open."

if [ "${POST_HEALTH:-000}" = "000" ]; then
  echo ""
  echo "WARNING: stats API STILL not answering after restart — the wedge"
  echo "survives a restart (new failure class). Check: journalctl -u $SERVICE -n 50"
  exit 1
fi

if [ "${DUMP_HITS:-0}" -lt 1 ]; then
  # Dump lost = the runbook's purpose failed even though the service recovered.
  exit 1
fi

exit 0
