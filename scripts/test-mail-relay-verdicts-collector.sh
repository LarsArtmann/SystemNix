#!/usr/bin/env bash
# mail-relay-collector fixture selftest (the usb-flap selftest pattern):
# exercises the SAME repo file the unit runs, against a fake JOURNALCTL +
# fake POSTQUEUE, asserting counters, window pruning, rejection-class
# mapping, held-queue counting, and the fail-closed scrape-error path.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
COLLECTOR="${1:-$HERE/mail-relay-verdicts-collector.sh}"
failures=0

assert_eq() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "ok: $label"
  else
    echo "FAIL: $label: want '$want' got '$got'"
    failures=$((failures + 1))
  fi
}

run_case() {
  local journal_fixture="$2" queue_fixture="$3"
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/textfile"

  cat >"$dir/journalctl" <<EOF
#!/usr/bin/env bash
# fake journalctl: fixture lines to stdout for the read pass; -n 1 probe succeeds
if [ "\$1" = "-n" ]; then exit 0; fi
cat "$journal_fixture"
EOF
  chmod +x "$dir/journalctl"

  cat >"$dir/postqueue" <<EOF
#!/usr/bin/env bash
cat "$queue_fixture"
EOF
  chmod +x "$dir/postqueue"

  OUT="$dir/textfile/mail-relay-verdicts.prom" \
    TEXTFILE_DIR="$dir/textfile" \
    STATE_DIR="$dir/state" \
    THRESHOLD=1 \
    WINDOW=3600 \
    JOURNALCTL="$dir/journalctl" \
    POSTQUEUE="$dir/postqueue" \
    bash "$COLLECTOR" >/dev/null 2>&1
  echo "$dir"
}

metric() { grep -E "^$1 " "$2/textfile/mail-relay-verdicts.prom" | awk '{ print $2 }'; }

NOW="$(date +%s)"
export NOW

# ── case 1: mixed outcomes, domain-unverified bounce, 2 held mails ──────────
JOURNAL_FIXTURE="$(mktemp)"
QUEUE_FIXTURE="$(mktemp)"
{
  echo "$((NOW - 3000)).000000 evo-x2 postfix/smtp[111]: ABC: to=<a@b.c>, relay=smtp.resend.com[1.2.3.4]:587, status=sent (250 ok)"
  echo "$((NOW - 2000)).000000 evo-x2 postfix/smtp[112]: DEF: to=<x@y.z>, relay=smtp.resend.com[1.2.3.4]:587, status=bounced (host said: 550 The artmann.tech domain is not verified)"
  echo "$((NOW - 1000)).000000 evo-x2 postfix/smtp[113]: GHI: to=<q@r.s>, relay=smtp.resend.com[1.2.3.4]:587, status=deferred (host said: 450 try later)"
  echo "$((NOW - 500)).000000 evo-x2 postfix/cleanup[114]: unrelated line status=sent (client hop — must not match)"
} >"$JOURNAL_FIXTURE"
printf '%s\n%s\n' '{"queue_name":"hold","recipients":[]}' '{"queue_name":"hold","recipients":[]}' >"$QUEUE_FIXTURE"

d1="$(run_case mixed "$JOURNAL_FIXTURE" "$QUEUE_FIXTURE")"
assert_eq "mixed: sent_total" 1 "$(metric node_mail_relay_sent_total "$d1")"
assert_eq "mixed: bounced_total" 1 "$(metric node_mail_relay_bounced_total "$d1")"
assert_eq "mixed: deferred_total" 1 "$(metric node_mail_relay_deferred_total "$d1")"
assert_eq "mixed: last_outcome (deferred is latest)" 2 "$(metric node_mail_relay_last_outcome "$d1")"
assert_eq "mixed: rejection class 1 (domain-unverified)" 1 "$(metric node_mail_relay_last_rejection_class "$d1")"
assert_eq "mixed: bounce over threshold" 1 "$(metric node_mail_relay_bounce_over_threshold "$d1")"
assert_eq "mixed: held count 2" 2 "$(metric node_mail_queue_held_count "$d1")"
assert_eq "mixed: scrape_errors 0" 0 "$(metric node_mail_relay_scrape_errors "$d1")"
assert_eq "mixed: state persisted" "1 1 1 $NOW" "$(cat "$d1/state/state" | awk -v n="$NOW" '{ print $1, $2, $3, n }')"

# ── case 2: quota bounce class + empty queue ────────────────────────────────
JOURNAL_FIXTURE="$(mktemp)"
QUEUE_FIXTURE="$(mktemp)"
: >"$QUEUE_FIXTURE"
{
  echo "$((NOW - 100)).000000 evo-x2 postfix/smtp[211]: ZZZ: to=<a@b.c>, relay=smtp.resend.com[1.2.3.4]:587, status=bounced (host said: 550 You have reached your sending quota limit)"
} >"$JOURNAL_FIXTURE"
d2="$(run_case quota "$JOURNAL_FIXTURE" "$QUEUE_FIXTURE")"
assert_eq "quota: rejection class 2" 2 "$(metric node_mail_relay_last_rejection_class "$d2")"
assert_eq "quota: held count 0 (empty output)" 0 "$(metric node_mail_queue_held_count "$d2")"
assert_eq "quota: last_outcome bounced" 1 "$(metric node_mail_relay_last_outcome "$d2")"

# ── case 3: window pruning — stale bounce falls out, fresh stays ────────────
JOURNAL_FIXTURE="$(mktemp)"
QUEUE_FIXTURE="$(mktemp)"
: >"$QUEUE_FIXTURE"
{
  echo "$((NOW - 10000)).000000 evo-x2 postfix/smtp[311]: OLD: to=<a@b.c>, relay=r[1.2.3.4]:587, status=bounced (550 old)"
  echo "$((NOW - 50)).000000 evo-x2 postfix/smtp[312]: NEW: to=<a@b.c>, relay=r[1.2.3.4]:587, status=bounced (550 new)"
} >"$JOURNAL_FIXTURE"
d3="$(run_case pruning "$JOURNAL_FIXTURE" "$QUEUE_FIXTURE")"
assert_eq "pruning: only fresh bounce in window" 1 "$(metric node_mail_relay_bounces_last_window "$d3")"
assert_eq "pruning: bounced_total counts both" 2 "$(metric node_mail_relay_bounced_total "$d3")"

# ── case 4: fail-closed — journalctl probe fails ────────────────────────────
d4="$(mktemp -d)"
mkdir -p "$d4/textfile"
cat >"$d4/journalctl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$d4/journalctl"
cat >"$d4/postqueue" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$d4/postqueue"
OUT="$d4/textfile/mail-relay-verdicts.prom" TEXTFILE_DIR="$d4/textfile" STATE_DIR="$d4/state" \
  THRESHOLD=1 WINDOW=3600 JOURNALCTL="$d4/journalctl" POSTQUEUE="$d4/postqueue" \
  bash "$COLLECTOR" >/dev/null 2>&1
assert_eq "failclosed: prom written" 1 "$(test -f "$d4/textfile/mail-relay-verdicts.prom" && echo 1 || echo 0)"
assert_eq "failclosed: scrape_errors 1" 1 "$(metric node_mail_relay_scrape_errors "$d4")"

# ── case 5: delta accumulation across runs (state resume) ───────────────────
JOURNAL_FIXTURE="$(mktemp)"
QUEUE_FIXTURE="$(mktemp)"
: >"$QUEUE_FIXTURE"
d5="$(run_case resume-seed "$JOURNAL_FIXTURE" "$QUEUE_FIXTURE")"
{
  echo "$((NOW - 10)).000000 evo-x2 postfix/smtp[511]: L1: to=<a@b.c>, relay=r[1.2.3.4]:587, status=sent (250)"
  echo "$((NOW - 9)).000000 evo-x2 postfix/smtp[512]: L2: to=<b@b.c>, relay=r[1.2.3.4]:587, status=bounced (550 x)"
} >"$JOURNAL_FIXTURE"
OUT="$d5/textfile/mail-relay-verdicts.prom" TEXTFILE_DIR="$d5/textfile" STATE_DIR="$d5/state" \
  THRESHOLD=1 WINDOW=3600 JOURNALCTL="$d5/journalctl" POSTQUEUE="$d5/postqueue" \
  bash "$COLLECTOR" >/dev/null 2>&1
assert_eq "resume: sent_total 1" 1 "$(metric node_mail_relay_sent_total "$d5")"
assert_eq "resume: bounced_total 1" 1 "$(metric node_mail_relay_bounced_total "$d5")"

if [ "$failures" -gt 0 ]; then
  echo "$failures selftest assertion(s) failed" >&2
  exit 1
fi
echo "all mail-relay-collector selftest assertions passed"
