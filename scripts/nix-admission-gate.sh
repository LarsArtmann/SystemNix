#!/usr/bin/env bash
# nix-admission-gate.sh — battery-class admission gate (2026-10-28 §7.1b
# RATIFIED, hard-fail variant): refuses the IO-battery nix subcommands
# (build / shell / develop / run / flake check) while the memory-emergency
# guard recently tripped OR live PSI sits in the storm band. The 8
# documented gate violations each killed the box (freezes #14–#33 battery
# class); deploy.sh has enforced this band at the switch since 2026-08-22 —
# this is the same doctrine at the TYPING layer, before a single store path
# is built.
#
# Owner login shells never include the devshell PATH prefix => the owner is
# unaffected BY CONSTRUCTION (F16 wires this into flake devshells only).
#
# Escape: ADMISSION_GATE_FORCE=1 — audit-logged, never silent.
# Output contract: the refusal names the condition + current readings +
# the calm-window bar. Exit 1 on refusal, exec's the real nix otherwise.
#
# Seams (selftest): REAL_NIX, GUARD_PROM, LAST_TRIP_SRC, PSI_IO_SRC,
# PSI_MEM_SRC, AUDIT_LOG.
set -euo pipefail

GATED_SUBCOMMANDS=" build shell develop run "
PSI_BAND=20
TRIP_WINDOW_SECONDS=1800
REAL_NIX="${REAL_NIX:-}"
GUARD_PROM="${GUARD_PROM:-/var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom}"
LAST_TRIP_SRC="${LAST_TRIP_SRC:-/var/lib/memory-emergency-guard/last-trip}"
PSI_IO_SRC="${PSI_IO_SRC:-/proc/pressure/io}"
PSI_MEM_SRC="${PSI_MEM_SRC:-/proc/pressure/memory}"
AUDIT_LOG="${AUDIT_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/admission-gate/audit.log}"

# --- resolve the REAL nix (first nix on PATH that is not this wrapper) ---
if [ -z "$REAL_NIX" ]; then
  self_dir=$(cd "$(dirname "$0")" && pwd)
  IFS=: read -r -a path_parts <<< "$PATH"
  for d in "${path_parts[@]}"; do
    [ "$d" = "$self_dir" ] && continue
    if [ -x "$d/nix" ]; then
      REAL_NIX="$d/nix"
      break
    fi
  done
fi
if [ -z "$REAL_NIX" ] || [ ! -x "$REAL_NIX" ]; then
  echo "nix-admission-gate: cannot resolve the real nix binary on PATH — refusing to run ungated. Set REAL_NIX or fix the devshell PATH wiring." >&2
  exit 1
fi

# --- is this invocation a gated battery form? ---
# `nix flake check` is gated as a unit; `nix eval`/`nix fmt` pass free.
sub="${1:-}"
gated=0
case "$GATED_SUBCOMMANDS" in
  *" $sub "*) gated=1 ;;
esac
if [ "$sub" = "flake" ] && [ "${2:-}" = "check" ]; then
  gated=1
fi
[ "$gated" = "1" ] || exec "$REAL_NIX" "$@"

# --- gate state (each input fails OPEN: unreadable = not a reason to
#     block — a dead guard must not wedge every devshell) ---
trip_recent=0
if [ -r "$GUARD_PROM" ]; then
  v=$(awk '$1 == "memory_emergency_guard_last_trip_recent" { print $2; exit }' "$GUARD_PROM" 2>/dev/null) || v=""
  [ "${v:-0}" = "1" ] && trip_recent=1
fi
if [ "$trip_recent" = "0" ] && [ -r "$LAST_TRIP_SRC" ]; then
  last_trip=$(cat "$LAST_TRIP_SRC" 2>/dev/null) || last_trip=0
  last_trip="${last_trip:-0}"
  now=$(date +%s)
  if [ "$last_trip" -gt 0 ] 2>/dev/null && [ $((now - last_trip)) -lt "$TRIP_WINDOW_SECONDS" ]; then
    trip_recent=1
  fi
fi

psi_io="-1"
[ -r "$PSI_IO_SRC" ] && psi_io=$(awk '/^some avg10=/ { sub("avg10=", "", $2); print $2; exit }' "$PSI_IO_SRC" 2>/dev/null) || psi_io=-1
psi_mem="-1"
[ -r "$PSI_MEM_SRC" ] && psi_mem=$(awk '/^some avg10=/ { sub("avg10=", "", $2); print $2; exit }' "$PSI_MEM_SRC" 2>/dev/null) || psi_mem=-1
psi_band_hit=0
awk -v p="$psi_io" 'BEGIN { exit !(p >= '"$PSI_BAND"') }' 2>/dev/null && psi_band_hit=1 || true
awk -v p="$psi_mem" 'BEGIN { exit !(p >= '"$PSI_BAND"') }' 2>/dev/null && psi_band_hit=1 || true

# --- decision ---
audit() {
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
  # subcommand only — full argv can carry secrets
  printf '%s %s sub=%s trip_recent=%s io_avg10=%s mem_avg10=%s\n' \
    "$(date -Is)" "$1" "$sub" "$trip_recent" "$psi_io" "$psi_mem" >> "$AUDIT_LOG" 2>/dev/null || true
}

refuse() {
  echo "nix-admission-gate: REFUSED (battery class — the freezes #14-#33 lesson)" >&2
  echo "  condition: $1" >&2
  echo "  current:   io PSI some avg10=${psi_io}%  memory PSI some avg10=${psi_mem}%  guard-trip-recent=${trip_recent}" >&2
  echo "  calm bar:  both PSI avg10 < ${PSI_BAND}% AND no guard trip in the last $((TRIP_WINDOW_SECONDS / 60)) min" >&2
  echo "  override:  ADMISSION_GATE_FORCE=1 nix $sub … (audit-logged)" >&2
  audit REFUSED
  exit 1
}

if [ "${ADMISSION_GATE_FORCE:-0}" = "1" ]; then
  echo "nix-admission-gate: FORCED past the gate (trip_recent=${trip_recent} io_avg10=${psi_io}% mem_avg10=${psi_mem}%) — this run is in the audit log" >&2
  audit FORCED
  exec "$REAL_NIX" "$@"
fi

if [ "$trip_recent" = "1" ]; then
  refuse "guard tripped within the last $((TRIP_WINDOW_SECONDS / 60)) min — the box is in or just out of a storm"
fi
if [ "$psi_band_hit" = "1" ]; then
  refuse "live PSI in the storm band (>= ${PSI_BAND}% some avg10)"
fi
audit PASSED
exec "$REAL_NIX" "$@"
