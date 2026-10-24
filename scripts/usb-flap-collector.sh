#!/usr/bin/env bash
# USB flap-counter collector body (textfile collector), shared by the
# usb-flap-metrics systemd unit and its fixture selftest
# (scripts/test-usb-flap-collector.sh + the usb-flap-metrics-selftest
# flake check — the tested artifact is the SAME repo file the unit runs).
#
# Reads kernel USB disconnect events from the persistent journal between
# the stored resume point and NOW, and renders usb-flap.prom:
#
#   usb_flap_disconnects_total          cumulative across boots (state file)
#   usb_flap_disconnects_delta          since the previous run
#   usb_flap_disconnects_last_hour      rolling 1h window (event timestamps)
#   usb_flap_rate_over_threshold 1|0   last_hour >= THRESHOLD
#   usb_flap_last_disconnect_epoch      0 = never within the journal window
#   usb_flap_scrape_errors              1 = the journal read itself failed
#                                       (fail-closed: never a silently
#                                       frozen collector)
#
# Configuration via environment:
#   OUT         destination .prom path (atomic via mktemp+mv)
#   TEXTFILE_DIR parent dir to mkdir -p (sticky textfile dir)
#   STATE_DIR   state + rolling-window file directory
#   THRESHOLD   rate_over flips to 1 at this many events in the window
#   WINDOW      rolling window length in seconds
#   JOURNALCTL  optional override for tests (defaults to journalctl on PATH)
set -eu

OUT="${OUT:?OUT required}"
TEXTFILE_DIR="${TEXTFILE_DIR:?TEXTFILE_DIR required}"
STATE_DIR="${STATE_DIR:?STATE_DIR required}"
THRESHOLD="${THRESHOLD:?THRESHOLD required}"
WINDOW="${WINDOW:?WINDOW required}"

# Resolved once: naming a shell function "journalctl" would shadow the
# binary inside its own body (infinite recursion, SIGSEGV).
: "${JOURNALCTL:=journalctl}"

mkdir -p "${TEXTFILE_DIR}"
TMP="$(mktemp "${TEXTFILE_DIR}/usb-flap.prom.XXXXXX")"
chmod 644 "$TMP"
STATE="$STATE_DIR/state"
STATE_TMP="$(mktemp)"
trap 'rm -f "$TMP" "$STATE_TMP"' EXIT

NOW="$(date +%s)"

scrape_errors=0
delta=0
total=0
last_epoch=0

# Resume from the stored journal timestamp; first run reads only the
# current boot so a fresh deployment does not replay the entire persistent
# history into one giant delta.
since=0
if [ -f "$STATE" ]; then
  read -r total since <"$STATE" 2>/dev/null || true
  total="${total:-0}"
  since="${since:-0}"
else
  since="$("$JOURNALCTL" -k --output=short-unix -n 1 2>/dev/null | tail -1 | awk '{ print $1 }' | cut -d. -f1 || true)"
  case "$since" in "" | *[!0-9]*) since="$NOW" ;; esac
fi

EVENTS="$(mktemp)"
trap 'rm -f "$TMP" "$STATE_TMP" "$EVENTS"' EXIT

# grep exits 1 on a zero-match window — healthy, not an error.
"$JOURNALCTL" -k --output=short-unix --since "@$since" --until "@$NOW" 2>/dev/null |
  grep -E 'usb [0-9]+-[0-9.]+: USB disconnect' >"$EVENTS" || true
# Fail-closed probe: journalctl itself must still answer.
if ! "$JOURNALCTL" -k -n 1 >/dev/null 2>&1; then
  scrape_errors=1
fi
delta="$(wc -l <"$EVENTS")"
case "$delta" in *[!0-9]*)
  delta=0
  scrape_errors=1
  ;;
esac

if [ "$delta" -gt 0 ]; then
  last_epoch="$(head -1 "$EVENTS" | awk '{ print $1 }' | cut -d. -f1)"
  case "$last_epoch" in *[!0-9]* | "") last_epoch="$NOW" ;; esac
fi

# Rolling-hour window: event epochs, one per line, pruned each run.
WINDOW_FILE="$STATE_DIR/window"
WINDOW_TMP="$(mktemp)"
trap 'rm -f "$TMP" "$STATE_TMP" "$EVENTS" "$WINDOW_TMP"' EXIT
cat "$EVENTS" | awk '{ print $1 }' | cut -d. -f1 >>"$WINDOW_FILE" 2>/dev/null || true
awk -v cutoff="$((NOW - WINDOW))" '$1 >= cutoff' "$WINDOW_FILE" >"$WINDOW_TMP" 2>/dev/null || true
mv "$WINDOW_TMP" "$WINDOW_FILE"
last_hour="$(wc -l <"$WINDOW_FILE")"
case "$last_hour" in *[!0-9]* | "")
  last_hour=0
  scrape_errors=1
  ;;
esac
rate_over=0
[ "$last_hour" -ge "$THRESHOLD" ] && rate_over=1 || true

total=$((total + delta))

{
  echo "# HELP usb_flap_disconnects_total Cumulative kernel USB disconnect events across boots (state-persisted)"
  echo "# TYPE usb_flap_disconnects_total counter"
  echo "usb_flap_disconnects_total $total"
  echo "# HELP usb_flap_disconnects_delta Disconnects observed since the previous collector run"
  echo "# TYPE usb_flap_disconnects_delta gauge"
  echo "usb_flap_disconnects_delta $delta"
  echo "# HELP usb_flap_disconnects_last_hour Disconnects inside the rolling ${WINDOW}s window"
  echo "# TYPE usb_flap_disconnects_last_hour gauge"
  echo "usb_flap_disconnects_last_hour $last_hour"
  echo "# HELP usb_flap_rate_over_threshold 1 when the rolling-hour rate meets the alert threshold (the 2026-08-16 storm class)"
  echo "# TYPE usb_flap_rate_over_threshold gauge"
  echo "usb_flap_rate_over_threshold $rate_over"
  echo "# HELP usb_flap_last_disconnect_epoch Unix epoch of the most recent observed disconnect (0 = none in window)"
  echo "# TYPE usb_flap_last_disconnect_epoch gauge"
  echo "usb_flap_last_disconnect_epoch $last_epoch"
  echo "# HELP usb_flap_scrape_errors Nonzero when the journal read itself failed (fail-closed)"
  echo "# TYPE usb_flap_scrape_errors gauge"
  echo "usb_flap_scrape_errors $scrape_errors"
} >"$TMP"
mv "$TMP" "$OUT"
echo "$total $NOW" >"$STATE_TMP"
mv "$STATE_TMP" "$STATE"
