#!/usr/bin/env bash
# Weekly restore drill for the DiscordSync event-store dump leg
# (discordsync-db-backup.timer): "a backup that was never restored is a
# rumor" (sqlite-continuous-backup-deep-dive-2026, sections 8.4/9). The
# 2026-10-13 manual drill of the 2026-10-01 dump was the FIRST restore
# this leg ever had, 12+ days into its life; this script makes the drill
# weekly instead of accidental.
#
# Restores the NEWEST dump from the backup dir into tmpfs scratch and
# proves, in order:
#   1. the gz stream is intact (gunzip)
#   2. PRAGMA integrity_check passes (thorough; the nightly per-dump
#      quick_check gate only covers torn writes, not logical rot)
#   3. the three core read-model tables exist AND are non-empty (a
#      structurally-valid but logically-empty restore, the re-created
#      DB class, must not pass)
#   4. the newest captured message is within the freshness budget
#
# Any problem exits 1 so the unit FAILS and OnFailure pages (forgejo
# restore-drill pattern: a drill is an event, not a continuous signal,
# so there is deliberately no metric/gatus layer). Fixture-tested:
# checks.x86_64-linux.discordsync-restore-drill-fixture.
#
# The dump is a GZIPPED BINARY sqlite db (.backup output; the .sql.gz
# suffix is historical), never SQL text: restore = gunzip, not import.
# Env overrides (fixture hooks): DRILL_DUMP_DIR, DRILL_MAX_MESSAGE_AGE_HOURS.
set -uo pipefail

dump_dir="${DRILL_DUMP_DIR:-/mnt/pool/backups/discordsync}"
# Healthy state: nightly dump + weekly drill means the newest message is
# typically under 26h old. 72h rides out a weekend of failed runs before
# paging; the DUMP-age SLA itself is backup-coordination's backup_healthy
# (25h), not this gate.
max_message_age_hours="${DRILL_MAX_MESSAGE_AGE_HOURS:-72}"

fails=0

dump=$(ls -1 "$dump_dir"/discordsync-db-*.sql.gz 2>/dev/null | sort | tail -1 || true)
if [ -z "$dump" ]; then
  echo "drill: FAILED: no discordsync-db-*.sql.gz in $dump_dir (dump leg produced nothing?)" >&2
  exit 1
fi
echo "drill: dump path: $(basename "$dump")"
if [ ! -s "$dump" ]; then
  echo "drill: FAILED: newest dump is 0 bytes" >&2
  exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Restore into tmpfs scratch (PrivateTmp): the ~380 MB restored DB never
# touches the QLC root and vanishes with the scratch dir.
if ! gzip -dc "$dump" >"$scratch/restored.db"; then
  echo "drill: FAILED: gunzip of $(basename "$dump") failed (torn/corrupt gz)" >&2
  exit 1
fi

# A non-sqlite file fails here ("file is not a database"): the
# empty-source-trap class from the deep-dive report.
check=$(sqlite3 -readonly "$scratch/restored.db" "PRAGMA integrity_check;" 2>&1)
if [ "$check" != "ok" ]; then
  echo "drill: FAILED: integrity_check: $check" >&2
  exit 1
fi
echo "drill: integrity_check OK"

for t in messages events attachments; do
  n=$(sqlite3 -readonly "$scratch/restored.db" "SELECT count(*) FROM $t;" 2>&1)
  case "$n" in
  '' | *[!0-9]*)
    echo "drill: FAILED: table $t missing/unreadable (sqlite3: $n)" >&2
    fails=$((fails + 1))
    ;;
  0)
    echo "drill: FAILED: table $t is EMPTY (logical rot / replaced-DB class)" >&2
    fails=$((fails + 1))
    ;;
  *)
    echo "drill: count[$t] = $n"
    ;;
  esac
done

# created_at is a Go time.Time string ("2026-10-01 02:26:08.55… +0200
# CEST") that sqlite's date parser rejects outright; substr(1,19) yields
# "YYYY-MM-DD HH:MM:SS". The local-offset skew (max 2h) is noise against
# the 72h budget.
newest=$(sqlite3 -readonly "$scratch/restored.db" "SELECT strftime('%s', substr(MAX(created_at), 1, 19)) FROM messages;" 2>&1)
case "$newest" in
'' | *[!0-9]*)
  echo "drill: FAILED: cannot parse newest message timestamp (sqlite3: $newest)" >&2
  fails=$((fails + 1))
  ;;
*)
  now=$(date +%s)
  age_hours=$(((now - newest) / 3600))
  echo "drill: newest message age = ${age_hours}h (budget ${max_message_age_hours}h)"
  if [ "$age_hours" -gt "$max_message_age_hours" ]; then
    echo "drill: FAILED: newest message is ${age_hours}h old (budget ${max_message_age_hours}h): the dump predates capture or capture stalled before the dump" >&2
    fails=$((fails + 1))
  fi
  ;;
esac

if [ "$fails" -gt 0 ]; then
  echo "drill: FAILED ($fails problem(s)) restoring $(basename "$dump")" >&2
  exit 1
fi
echo "drill: OK: $(basename "$dump") restores clean and fresh"
