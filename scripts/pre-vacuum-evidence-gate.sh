#!/usr/bin/env bash
# Pre-vacuum journal evidence gate.
#
# journald auto-vacuums at SystemMaxUse (8G on evo-x2); the journal is the
# ONLY forensic source for a freeze boot, and three autopsies (10-03 triage,
# freeze-27, freeze-28) were won-or-lost on whether an evidence pull landed
# before the vacuum ate the boot. This gate refuses (exit 1) when a boot
# still on disk has NO committed evidence file (docs/status/ grep on the
# boot id) AND an open (unchecked) stability row references the boot's
# window — i.e. an autopsy is still owed for a journal the vacuum can take
# at any moment. Boots that are unguarded but unreferenced by any open row
# degrade to a warning, not a block.
#
# Usage:
#   pre-vacuum-evidence-gate.sh            live check (used by pre-deploy §15)
#   pre-vacuum-evidence-gate.sh selftest   fixture selftest (flake check)
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATUS_DIR="$REPO_ROOT/docs/status"
TODO_FILE="$REPO_ROOT/docs/todo/stability.md"

# ── pure helpers (fixture-tested by selftest) ────────────────────────────

# Extract the 8-char boot-id prefix from a `journalctl --list-boots` line.
pvg_extract_id8() {
  # line: "-3 ee5791b9bdc7463bbc80d82fd06fdd44 Wed 2026-10-07 ..."
  printf '%s' "$1" | awk '{print substr($2, 1, 8)}'
}

# Extract the start and end ISO dates from a --list-boots line.
pvg_boot_dates() {
  # prints "<start-date> <end-date>" (YYYY-MM-DD tokens)
  printf '%s' "$1" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tr '\n' ' ' | sed 's/ $//'
}

# Evidence check: does any committed file under docs/status/ cite this boot id?
pvg_evidence_for() {
  local id8="$1"
  [ -d "$STATUS_DIR" ] || return 1
  # Hex-boundary match: a bare id8 substring would false-positive inside
  # 40-char git SHAs (phantom-green class).
  grep -rlE "(^|[^0-9a-f])$id8([^0-9a-f]|\$)" "$STATUS_DIR" >/dev/null 2>&1
}

# Open-row check: do unchecked stability rows reference one of the boot dates?
pvg_open_row_hits() {
  local dates="$1"
  [ -f "$TODO_FILE" ] || return 1
  local d hit=1
  for d in $dates; do
    if grep -E '^- \[ \]' "$TODO_FILE" | grep -q -- "$d"; then
      hit=0
      printf '%s\n' "$d"
    fi
  done
  return $hit
}

# ── selftest ─────────────────────────────────────────────────────────────

pvg_selftest() {
  local failures=0
  local line="-3 ee5791b9bdc7463bbc80d82fd06fdd44 Wed 2026-10-07 11:05:39 CEST Sat 2026-10-10 23:13:31 CEST"

  local id8 dates
  id8=$(pvg_extract_id8 "$line")
  dates=$(pvg_boot_dates "$line")
  [ "$id8" = "ee5791b9" ] || { echo "FAIL: id8 extraction got '$id8'"; failures=$((failures + 1)); }
  [ "$dates" = "2026-10-07 2026-10-10" ] || { echo "FAIL: date extraction got '$dates'"; failures=$((failures + 1)); }

  local scratch
  scratch=$(mktemp -d)
  local saved_status="$STATUS_DIR" saved_todo="$TODO_FILE"
  STATUS_DIR="$scratch/status"
  TODO_FILE="$scratch/todo.md"
  mkdir -p "$STATUS_DIR"

  if pvg_evidence_for "$id8"; then
    echo "FAIL: evidence_for true with empty status dir"
    failures=$((failures + 1))
  fi
  echo "pull cites ee5791b9 full boot id" >"$STATUS_DIR/evidence.md"
  if ! pvg_evidence_for "$id8"; then
    echo "FAIL: evidence_for false with citing file present"
    failures=$((failures + 1))
  fi

  printf -- '- [ ] [ready] **Triage the 2026-10-10 23:15 reboot — boot −1 ran 3.5 days**\n' >"$TODO_FILE"
  if ! pvg_open_row_hits "$dates" >/dev/null 2>&1; then
    echo "FAIL: open-row hit missed on checked (unchecked row cites 2026-10-10)"
    failures=$((failures + 1))
  fi
  printf -- '- [x] [ready] **Triage the 2026-10-10 23:15 reboot** — CLOSED with evidence\n' >"$TODO_FILE"
  if pvg_open_row_hits "$dates" >/dev/null 2>&1; then
    echo "FAIL: open-row hit fired on a CLOSED (checked) row"
    failures=$((failures + 1))
  fi
  printf -- '- [ ] [ready] **Unrelated row, no boot dates here**\n' >"$TODO_FILE"
  if pvg_open_row_hits "$dates" >/dev/null 2>&1; then
    echo "FAIL: open-row hit fired on a row without the boot dates"
    failures=$((failures + 1))
  fi

  STATUS_DIR="$saved_status"
  TODO_FILE="$saved_todo"
  rm -rf "$scratch"

  if [ "$failures" -gt 0 ]; then
    echo "selftest: $failures failure(s)"
    exit 1
  fi
  echo "selftest: all fixture assertions passed"
}

# ── live check ───────────────────────────────────────────────────────────

pvg_live() {
  local boots
  if ! boots=$(journalctl --list-boots --no-pager 2>&1); then
    echo "FAIL-LOUD: journalctl --list-boots failed — cannot enumerate exposed boots (anti-phantom-green): $boots"
    exit 1
  fi
  # Drop the current (last) boot: it is alive, not vacuum-fodder yet.
  # Keep only real boot rows (the --list-boots header line has no hex id).
  local exposed
  exposed=$(printf '%s\n' "$boots" | grep -E '^[[:space:]]*-?[0-9]+ [0-9a-f]{32} ' | sed '$d')
  if [ -z "$exposed" ]; then
    echo "pre-vacuum gate: no exposed (non-current) boots on disk"
    exit 0
  fi

  local blocked=0
  local line id8 dates evidence hits
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id8=$(pvg_extract_id8 "$line")
    dates=$(pvg_boot_dates "$line")
    evidence=no
    if pvg_evidence_for "$id8"; then evidence=yes; fi
    hits=""
    if [ "$evidence" = no ]; then
      hits=$(pvg_open_row_hits "$dates" | sort -u || true)
    fi
    if [ "$evidence" = yes ]; then
      echo "  guarded  boot $id8 ($dates) — evidence committed in docs/status/"
    elif [ -n "$hits" ]; then
      echo "  UNPULLED boot $id8 ($dates) — open stability row(s) cite $hits; journal vacuum can erase it any time"
      echo "    remedy: pull NOW, e.g.: journalctl -b $id8 --no-pager > docs/status/tasks/$(date +%Y-%m-%d)_boot-${id8}-evidence-pull.md"
      blocked=$((blocked + 1))
    else
      echo "  unpulled boot $id8 ($dates) — but no open stability row cites its window (warning only)"
    fi
  done <<EOF
$exposed
EOF

  # Vacuum clock: how close is the auto-vacuum to firing?
  local usage conf_max="8G"
  if [ -r /etc/systemd/journald.conf ]; then
    local conf_val
    conf_val=$(grep -oE '^ *SystemMaxUse=[^ ]+' /etc/systemd/journald.conf | head -n 1 | cut -d= -f2 || true)
    [ -n "$conf_val" ] && conf_max="$conf_val"
  fi
  usage=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGT]i?' | head -n 1 || true)
  echo "  vacuum clock: journal disk usage ${usage:-unknown} vs SystemMaxUse ${conf_max}"

  if [ "$blocked" -gt 0 ]; then
    echo "pre-vacuum gate: REFUSED — $blocked exposed boot(s) with open stability rows lack committed evidence; pull before any deploy that could follow a reboot into vacuum pressure"
    exit 1
  fi
  echo "pre-vacuum gate: pass"
}

case "${1:-}" in
selftest) pvg_selftest ;;
*) pvg_live ;;
esac
