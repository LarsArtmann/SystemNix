#!/usr/bin/env bash
# HDD vibration/shock SMART report — READ-ONLY, safe to run any time.
#
# The pool members (2x Toshiba MG08ACA16TE behind the JMS567 USB-SAT bridge)
# do NOT expose a live "vibration meter" via SMART. They DO keep lifetime
# shock/vibration counters:
#
#   191 G-Sense_Error_Rate — read errors attributed to external shock/vibration
#   220 Disk_Shift         — permanent platter displacement (sustained shock)
#
# Both are CUMULATIVE since manufacture, not real-time amplitude. The useful
# signal is the DELTA between runs: re-run after any enclosure drop, physical
# move, or USB-wedge incident and watch for increases. For a live reading an
# external accelerometer (e.g. a phone lying on the enclosure) is the only way.
#
# Usage:
#   bash scripts/hdd-vibration-check.sh            # auto-elevates via sudo
#   sudo bash scripts/hdd-vibration-check.sh       # already root
#   bash scripts/hdd-vibration-check.sh --no-sudo      # refuse elevation
#   bash scripts/hdd-vibration-check.sh --error-log    # per-drive SMART error log
#                                                      # (entries carry PoH timestamps)
#
# Exit codes: 0 = nothing notable, 1 = findings/problems (see output).
set -uo pipefail

# By-id paths survive sd-letter reshuffles on every replug (never match by
# /dev/sdX). Mirrors POOL_MEMBERS in das-link-recovery-check.sh.
POOL_MEMBERS=(
  "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A005FWTG"
  "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG"
)

NO_SUDO=0 ERROR_LOG=0
FLAGS=()
for arg in "$@"; do
  case "$arg" in
    --no-sudo) NO_SUDO=1; FLAGS+=(--no-sudo) ;;
    --error-log) ERROR_LOG=1; FLAGS+=(--error-log) ;;
    *) echo "unknown argument: $arg (only --no-sudo, --error-log)" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  if [ "$NO_SUDO" -eq 1 ]; then
    echo "ERROR: SMART needs root to open the device; --no-sudo given." >&2
    exit 2
  fi
  SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  echo "SMART needs root — re-running with sudo ..."
  exec sudo -- bash "$SCRIPT_PATH" "${FLAGS[@]}"
fi

# Resolve smartctl: PATH first, then the binary the RUNNING smartd uses
# (authoritative — same package that monitors these drives), then a store
# glob fallback (sort is arbitrary; only hit when smartd is somehow absent).
SMARTCTL=""
if command -v smartctl >/dev/null 2>&1; then
  SMARTCTL="$(command -v smartctl)"
else
  smartd_exec="$(systemctl show -p ExecStart --value smartd.service 2>/dev/null | awk '{print $1}')"
  if [ -n "$smartd_exec" ] && [ -x "$(dirname "$smartd_exec")/../bin/smartctl" ]; then
    SMARTCTL="$(dirname "$smartd_exec")/../bin/smartctl"
  else
    for candidate in /nix/store/*-smartmontools-*/bin/smartctl; do
      if [ -x "$candidate" ]; then SMARTCTL="$candidate"; break; fi
    done
  fi
fi
if [ -z "$SMARTCTL" ]; then
  echo "ERROR: smartctl not found (not on PATH, smartd not running, no store match)." >&2
  exit 2
fi

smart() { "$SMARTCTL" "$@"; }

# Raw value of one SMART attribute id for a device; empty when absent.
get_raw() {
  smart -d sat -A "$2" 2>/dev/null | awk -v id="$1" '$1 == id { print $NF }'
}

# Normalized (0-100) value of one SMART attribute id; empty when absent.
get_val() {
  smart -d sat -A "$2" 2>/dev/null | awk -v id="$1" '$1 == id { print $4 }'
}

issues=0

for dev in "${POOL_MEMBERS[@]}"; do
  serial="${dev##*_}"
  echo "== Toshiba MG08  serial $serial =="

  if [ ! -e "$dev" ]; then
    echo "  ✗ drive NOT enumerated (DAS outage? see das-link-recovery-check.sh)"
    issues=$((issues + 1))
    continue
  fi

  health="$(smart -H -d sat "$dev" 2>/dev/null | awk -F': ' '/overall-health/{print $2}')"
  case "$health" in
    PASSED) echo "  ✓ overall health: PASSED" ;;
    *) echo "  ✗ overall health: ${health:-UNKNOWN}"; issues=$((issues + 1)) ;;
  esac

  poh="$(get_raw 9 "$dev")"
  echo "  ℹ power-on hours: ${poh:-unknown} (counters below are LIFETIME totals)"

  gsense="$(get_raw 191 "$dev")"
  if [ -z "$gsense" ]; then
    echo "  ⚠ attr 191 G-Sense_Error_Rate NOT reported (SAT bridge hid it) — no shock visibility"
    issues=$((issues + 1))
  else
    gnorm="$(get_val 191 "$dev")"
    if [ "$gsense" -gt 0 ] 2>/dev/null; then
      echo "  ⚠ G-Sense_Error_Rate: normalized $gnorm, raw $gsense — shock/vibration-induced errors RECORDED"
      issues=$((issues + 1))
    else
      echo "  ✓ G-Sense_Error_Rate: normalized $gnorm, raw 0 — no shock-induced errors ever recorded"
    fi
  fi

  shift="$(get_raw 220 "$dev")"
  snorm="$(get_val 220 "$dev")"
  if [ -z "$shift" ]; then
    echo "  ⚠ attr 220 Disk_Shift NOT reported — no sustained-shock visibility"
    issues=$((issues + 1))
  else
    echo "  ℹ Disk_Shift: normalized $snorm, raw $shift"
    echo "    (raw is vendor-packed 48-bit on these Toshibas — millions are common;"
    echo "     the health signal is normalized ~100 and same-drive raw DELTAS)"
  fi

  echo "  --- context ---"
  for id in 5 194 196 197 198 199; do
    raw="$(get_raw "$id" "$dev")"
    name="$(smart -d sat -A "$dev" 2>/dev/null | awk -v id="$id" '$1 == id { print $2; exit }')"
    echo "    $id $name = ${raw:-absent}"
  done

  realloc="$(get_raw 5 "$dev")"; pending="$(get_raw 197 "$dev")"; uncorr="$(get_raw 198 "$dev")"
  for pair in "realloc:$realloc" "pending:$pending" "uncorrectable:$uncorr"; do
    key="${pair%%:*}"; val="${pair#*:}"
    if [ -n "$val" ] && [ "$val" -gt 0 ] 2>/dev/null; then
      echo "  ⚠ $key sectors = $val (media damage, not vibration — but check with G-Sense history)"
      issues=$((issues + 1))
    fi
  done

  if [ "$ERROR_LOG" -eq 1 ]; then
    echo "  --- SMART error log (timestamps are power-on hours, not wall-clock) ---"
    smart -d sat -l error "$dev" 2>&1 | sed 's/^/    /'
  fi
  echo
done

cat <<'EOF'
How to read this:
- 191 G-Sense = lifetime count of errors the drive attributed to shock/vibration.
  0 on a healthy install. Any INCREASE between runs = a real mechanical event.
- 220 Disk_Shift = platter displacement. The RAW column is vendor-packed on
  these Toshibas (huge values are normal); normalized ~100 + raw DELTAS are
  the signal.
- Counters are cumulative — the delta across runs is the signal, not the absolute.
- Live amplitude needs an external accelerometer (phone on the enclosure).
EOF

echo "== $issues issue(s)/finding(s) =="
[ "$issues" -eq 0 ]
