#!/usr/bin/env bash
# Mail-relay outcome collector body (textfile collector), shared by the
# mail-relay-metrics systemd unit and its fixture selftest
# (scripts/test-mail-relay-collector.sh + the mail-relay-metrics-selftest
# flake check — the tested artifact is the SAME repo file the unit runs).
#
# The 2026-11-11 Resend outage class: artmann.tech silently lost domain
# verification and EVERY outbound application mail bounced with
# `550 The artmann.tech domain is not verified` for HOURS while the
# pipeline reported success at the client hop (send-hardening closure
# session, docs/status/2026-11-11_09-20 §d.1). The postfix CLIENT 250 is
# local truth only; the relay-hop journal line is the verdict. This
# collector reads those verdicts from the persistent journal between the
# stored resume point and NOW, and renders mail-relay.prom:
#
#   node_mail_relay_sent_total            cumulative relay-accepted sends (state file)
#   node_mail_relay_bounced_total         cumulative relay rejections (state file)
#   node_mail_relay_deferred_total        cumulative deferred (transient) relay attempts
#   node_mail_relay_bounces_last_window   rejections inside the rolling window
#   node_mail_relay_bounce_over_threshold 1|0 — window rejections >= THRESHOLD
#   node_mail_relay_last_outcome          0 sent / 1 bounced / 2 deferred (latest relay line)
#   node_mail_relay_last_rejection_class  0 none/other, 1 domain-unverified,
#                                         2 quota/rate-limit, 3 invalid-from
#   node_mail_relay_last_bounce_epoch     unix epoch of the newest rejection (0 = none)
#   node_mail_queue_held_count            mails currently on HOLD in the postfix queue
#   node_mail_relay_scrape_errors         1 = journal/queue read failed (fail-closed:
#                                         never a silently frozen collector)
#
# Configuration via environment:
#   OUT         destination .prom path (atomic via mktemp+mv)
#   TEXTFILE_DIR parent dir to mkdir -p (sticky textfile dir)
#   STATE_DIR   state + rolling-window file directory
#   THRESHOLD   bounce_over flips to 1 at this many rejections in the window
#   WINDOW      rolling window length in seconds
#   JOURNALCTL  optional override for tests (defaults to journalctl on PATH)
#   POSTQUEUE   optional override for tests (defaults to postqueue on PATH)
set -eu

OUT="${OUT:?OUT required}"
TEXTFILE_DIR="${TEXTFILE_DIR:?TEXTFILE_DIR required}"
STATE_DIR="${STATE_DIR:?STATE_DIR required}"
THRESHOLD="${THRESHOLD:?THRESHOLD required}"
WINDOW="${WINDOW:?WINDOW required}"

: "${JOURNALCTL:=journalctl}"
: "${POSTQUEUE:=postqueue}"

mkdir -p "${TEXTFILE_DIR}"
TMP="$(mktemp "${TEXTFILE_DIR}/mail-relay.prom.XXXXXX")"
chmod 644 "$TMP"
STATE="$STATE_DIR/state"
STATE_TMP="$(mktemp)"
EVENTS=""
WINDOW_TMP=""
trap 'rm -f "$TMP" "$STATE_TMP" "$EVENTS" "$WINDOW_TMP"' EXIT

NOW="$(date +%s)"

scrape_errors=0
sent_delta=0
bounced_delta=0
deferred_delta=0
last_outcome=3 # 3 = no relay traffic observed this run
last_class=0
last_bounce_epoch=0

# Resume from the stored journal timestamp; first run reads only the last
# 15 minutes so a fresh deployment does not replay the entire outage
# history into one giant delta (the usb-flap first-run precedent).
since=0
if [ -f "$STATE" ]; then
  read -r sent_total bounced_total deferred_total since <"$STATE" 2>/dev/null || true
  sent_total="${sent_total:-0}"
  bounced_total="${bounced_total:-0}"
  deferred_total="${deferred_total:-0}"
  since="${since:-0}"
else
  sent_total=0
  bounced_total=0
  deferred_total=0
  since=$((NOW - 900))
fi

EVENTS="$(mktemp)"
WINDOW_TMP="$(mktemp)"

# Relay-hop verdicts only: postfix/smtp transport lines that reached a
# relay (the end-of-DATA hop — the client-250 acceptance lines never
# appear under postfix/smtp). grep exits 1 on a zero-match window —
# healthy, not an error.
"$JOURNALCTL" -u postfix --output=short-unix --since "@$since" --until "@$NOW" 2>/dev/null |
  grep -E 'postfix/smtp\[[0-9]+\]: .*\[[0-9.]+\]:[0-9]+.*status=' >"$EVENTS" || true
# Fail-closed probe: journalctl itself must still answer.
if ! "$JOURNALCTL" -u postfix -n 1 >/dev/null 2>&1; then
  scrape_errors=1
fi

# Classify each relay line and tally.
mkdir -p "$STATE_DIR"
: >"$WINDOW_TMP"
while IFS= read -r line; do
  [ -n "$line" ] || continue
  epoch="$(printf '%s\n' "$line" | awk '{ print $1 }' | cut -d. -f1)"
  case "$epoch" in *[!0-9]* | "") continue ;; esac
  case "$line" in
  *'status=sent'*)
    sent_delta=$((sent_delta + 1))
    last_outcome=0
    ;;
  *'status=bounced'*)
    bounced_delta=$((bounced_delta + 1))
    last_outcome=1
    last_bounce_epoch="$epoch"
    echo "$epoch" >>"$WINDOW_TMP"
    case "$line" in
    *'not verified'*) last_class=1 ;;
    *quota* | *"rate limit"*) last_class=2 ;;
    *"Invalid \`from\`"*) last_class=3 ;;
    *) last_class=0 ;;
    esac
    ;;
  *'status=deferred'*)
    deferred_delta=$((deferred_delta + 1))
    last_outcome=2
    ;;
  esac
done <"$EVENTS"

# Rolling rejection window: append this run's bounce epochs to the
# persisted window, prune past-cutoff entries.
WINDOW_FILE="$STATE_DIR/window"
touch "$WINDOW_FILE"
cat "$WINDOW_TMP" >>"$WINDOW_FILE" 2>/dev/null || true
awk -v cutoff="$((NOW - WINDOW))" '$1 >= cutoff' "$WINDOW_FILE" >"$WINDOW_TMP" 2>/dev/null || true
mv "$WINDOW_TMP" "$WINDOW_FILE"
bounces_window="$(wc -l <"$WINDOW_FILE")"
case "$bounces_window" in *[!0-9]* | "")
  bounces_window=0
  scrape_errors=1
  ;;
esac
over=0
[ "$bounces_window" -ge "$THRESHOLD" ] && over=1 || true

# Held-mail count (the 2026-11-10 storm's frozen-queue state was only
# visible by hand). postqueue emits JSON entries; count them.
held=0
if queue_json="$("$POSTQUEUE" -j 2>/dev/null)"; then
  if [ -n "$queue_json" ]; then
    held="$(printf '%s\n' "$queue_json" | grep -c . || true)"
    case "$held" in *[!0-9]*) held=0 ;; esac
  fi
else
  scrape_errors=1
fi

sent_total=$((sent_total + sent_delta))
bounced_total=$((bounced_total + bounced_delta))
deferred_total=$((deferred_total + deferred_delta))

{
  echo "# HELP node_mail_relay_sent_total Relay-accepted (status=sent) outbound transactions, cumulative across boots (state-persisted)"
  echo "# TYPE node_mail_relay_sent_total counter"
  echo "node_mail_relay_sent_total $sent_total"
  echo "# HELP node_mail_relay_bounced_total Relay-rejected (status=bounced) outbound transactions, cumulative (the 2026-11-11 domain-unverified outage class)"
  echo "# TYPE node_mail_relay_bounced_total counter"
  echo "node_mail_relay_bounced_total $bounced_total"
  echo "# HELP node_mail_relay_deferred_total Deferred (transient) relay attempts, cumulative"
  echo "# TYPE node_mail_relay_deferred_total counter"
  echo "node_mail_relay_deferred_total $deferred_total"
  echo "# HELP node_mail_relay_bounces_last_window Rejections inside the rolling ${WINDOW}s window"
  echo "# TYPE node_mail_relay_bounces_last_window gauge"
  echo "node_mail_relay_bounces_last_window $bounces_window"
  echo "# HELP node_mail_relay_bounce_over_threshold 1 when window rejections meet the alert threshold"
  echo "# TYPE node_mail_relay_bounce_over_threshold gauge"
  echo "node_mail_relay_bounce_over_threshold $over"
  echo "# HELP node_mail_relay_last_outcome 0 sent / 1 bounced / 2 deferred / 3 no traffic this run (latest relay line)"
  echo "# TYPE node_mail_relay_last_outcome gauge"
  echo "node_mail_relay_last_outcome $last_outcome"
  echo "# HELP node_mail_relay_last_rejection_class 0 none/other, 1 domain-unverified, 2 quota/rate-limit, 3 invalid-from"
  echo "# TYPE node_mail_relay_last_rejection_class gauge"
  echo "node_mail_relay_last_rejection_class $last_class"
  echo "# HELP node_mail_relay_last_bounce_epoch Unix epoch of the most recent relay rejection (0 = none)"
  echo "# TYPE node_mail_relay_last_bounce_epoch gauge"
  echo "node_mail_relay_last_bounce_epoch $last_bounce_epoch"
  echo "# HELP node_mail_queue_held_count Mails currently in the postfix queue (held or pending)"
  echo "# TYPE node_mail_queue_held_count gauge"
  echo "node_mail_queue_held_count $held"
  echo "# HELP node_mail_relay_scrape_errors Nonzero when the journal or queue read failed (fail-closed)"
  echo "# TYPE node_mail_relay_scrape_errors gauge"
  echo "node_mail_relay_scrape_errors $scrape_errors"
} >"$TMP"
mv "$TMP" "$OUT"
echo "$sent_total $bounced_total $deferred_total $NOW" >"$STATE_TMP"
mv "$STATE_TMP" "$STATE"
