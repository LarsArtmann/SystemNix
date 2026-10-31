#!/usr/bin/env bash
# crash-triage.sh — step 0 of EVERY crash diagnosis (stability plan
# M10/F38-F39): reset reasons, un-evidenced-crashed-boot sweep, vacuum
# clock, and the per-boot guard/thermal census that feeds the
# freeze-family discriminator fork (docs/agents/stability.md — pick
# branch A/B/C BEFORE deep-diving drivers).
#
# Born 2026-10-28 from the double-crash night: boot -2's verdict was
# first written "thermal absent" off a head-truncated grep (452 DEEP
# THROTTLE ENTERs hidden), and boot -3's abrupt end sat unnoticed until
# manual archaeology. Both classes are structural here: every census in
# this script is FULL-COUNT, and the boot sweep flags abrupt ends
# WITHOUT a committed evidence file.
#
# Seams (selftest): JOURNALCTL (stub), DOCS_ROOT (fixture evidence dir),
# JOURNAL_CAP_BYTES (vacuum math).  Read-only; never mutates anything.
set -euo pipefail

BOOTS=5
JOURNALCTL="${JOURNALCTL:-journalctl}"
DOCS_ROOT="${DOCS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
JOURNAL_CAP_BYTES="${JOURNAL_CAP_BYTES:-8589934592}"

while [ $# -gt 0 ]; do
  case "$1" in
  --boots)
    BOOTS="$2"
    shift 2
    ;;
  -h | --help)
    sed -n '2,17p' "$0" >&2
    exit 0
    ;;
  *)
    echo "crash-triage: unknown flag: $1" >&2
    exit 2
    ;;
  esac
done

# --- Boot inventory ------------------------------------------------------
# Format: "offset fullid start end".  Oldest first from journalctl; we
# reverse to newest-first, keep N+1 (the boot AFTER a crash carries its
# reset reason).
mapfile -t bootlist < <("$JOURNALCTL" --list-boots --no-pager 2>/dev/null | tail -n $((BOOTS + 1)) | tac)
[ ${#bootlist[@]} -ge 2 ] || {
  echo "crash-triage: need >=2 boots from --list-boots" >&2
  exit 1
}

# Reset-reason line of the PREVIOUS boot, read from boot N's kernel log
# (the reason lives in the NEXT boot, never the dying one).  NOTE: no
# `| head -1` under pipefail — rg with multiple matches + head = SIGPIPE
# = silently "none" (live-caught 2026-10-28).
reset_reason_for() { # full-boot-id -> prints reason or "none"
  local reason
  reason=$("$JOURNALCTL" -b "$1" -k --no-pager 2>/dev/null | rg -m1 -o 'Previous system reset reason \[[^]]*\]: .*') || true
  echo "${reason:-none}"
}

# FULL-COUNT censuses (the F35 rule: head-truncated censuses lie).
census() { # full-id pattern -> count
  local n
  n=$("$JOURNALCTL" -b "$1" --no-pager 2>/dev/null | rg -c "$2") || n=0
  echo "${n:-0}"
}

shutdown_ceremony() { # full-id -> 1 if PID-1 final-target markers exist
  # USER managers also log "Reached target Shutdown" when sessions close
  # mid-boot (the stability.md trap), and systemd[1] logs "Stopping X"
  # for ordinary unit stops — only the FINAL targets count as ceremony.
  local n
  n=$("$JOURNALCTL" -b "$1" --no-pager 2>/dev/null | rg -c 'systemd\[1\]: (Reached target (Shutdown|Power-Off|Reboot|Halt))') || n=0
  [ "${n:-0}" -gt 0 ] && echo 1 || echo 0
}

evidence_file_for() { # short-id -> path or empty
  ls "$DOCS_ROOT"/docs/status/tasks/*boot-"$1"*evidence*.md 2>/dev/null | head -1 || true
}

echo "=== crash-triage: last $BOOTS boots (newest first) ==="
i=0
for line in "${bootlist[@]}"; do
  i=$((i + 1))
  [ "$i" -gt "$BOOTS" ] && break
  read -r offset full <<<"$(printf '%s\n' "$line" | awk '{print $1, $2}')"
  start=$(printf '%s\n' "$line" | awk '{print $4, $5, $6}')
  end=$(printf '%s\n' "$line" | awk '{print $8, $9, $10}')
  short="${full:0:8}"
  clean=$(shutdown_ceremony "$full")
  # trips metric counts BOTH eras (2026-10-31 fix): the socket-stop era
  # ('action taken: sockets') AND the ioPause era (live since the Oct 28
  # 18:06 mid-boot deploy, 'IO-PAUSE (trip' — both the SIGSTOPped and the
  # NO-eligible shapes are distinct trips). The sockets-only grep
  # undercounted freeze #38 by 10x (40 vs 412 real trips, boot 0 0 vs 169).
  trips=$(census "$full" 'action taken: sockets|IO-PAUSE \(trip')
  throttle=$(census "$full" 'DEEP THROTTLE ENTER')
  oom=$(census "$full" 'invoked oom-killer')
  # reset reason for the PREVIOUS boot, read from THIS boot's kernel log
  # (valid for every boot incl. the newest — boot 0 carries the last
  # crash's reason; "none" = previous boot ended cleanly or first boot)
  reason=$(reset_reason_for "$full")
  endkind="ABRUPT"
  [ "$clean" = "1" ] && endkind="clean"
  # discriminator branch proposal (docs/agents/stability.md fork)
  branch="?"
  if [ "$endkind" = "ABRUPT" ]; then
    if [ "$throttle" -ge 20 ] && [ "$trips" -ge 5 ]; then
      branch="C combined (storm+ceiling)"
    elif [ "$throttle" -ge 20 ]; then
      branch="A thermal"
    elif [ "$trips" -ge 5 ]; then
      branch="B livelock"
    else
      branch="A/B (census thin — pull evidence before branching)"
    fi
  fi
  ev="(evidence: "
  evfile=$(evidence_file_for "$short")
  [ -n "$evfile" ] && ev+="$(basename "$evfile")" || ev+="NONE"
  ev+=")"
  echo "- $short  $start -> $end  [$endkind] trips=$trips throttle_ENTER=$throttle oom=$oom"
  echo "    reset-reason(in this boot, for previous): $reason"
  [ "$endkind" = "ABRUPT" ] && echo "    discriminator proposal: $branch  $ev"
  # offset 0 is the RUNNING boot — "abrupt" just means it has not shut
  # down yet; never page on it.
  if [ "$endkind" = "ABRUPT" ] && [ "$offset" != "0" ] && [ -z "$evfile" ]; then
    echo "    !! UNEVIDENCED CRASHED BOOT — pull evidence NOW: scripts/boot-evidence-pull.sh -b <offset> (journal vacuum eats oldest boots at the cap)"
  fi
done

# --- Vacuum clock --------------------------------------------------------
usage_line=$("$JOURNALCTL" --disk-usage --no-pager 2>/dev/null | head -1)
used=$(printf '%s\n' "$usage_line" | rg -o '[0-9]+\.?[0-9]*[Gg]' | head -1 | rg -o '[0-9]+\.?[0-9]*') || used=""
echo "=== vacuum clock ==="
echo "journal: ${usage_line:-unknown} | cap: $((JOURNAL_CAP_BYTES / 1073741824))G"
if [ -n "$used" ]; then
  awk -v u="$used" -v c=$((JOURNAL_CAP_BYTES / 1073741824)) 'BEGIN {
    head = c - u
    printf "headroom: %.1fG (%.0f%% of cap) — oldest boots are %s\n", head, head / c * 100, (head < 0.5 ? "AT THE VACUUM EDGE — pull evidence before anything journal-heavy" : "safe for now")
  }'
fi
