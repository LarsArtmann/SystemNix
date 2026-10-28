#!/usr/bin/env bash
# projects-cutover-quiesce — pause/restore the ~/projects writer fleet around
# the projects-subvol prepare/cutover (plan D1, docs/planning/2026-10-28_projects-samsung-subvol-migration.md:
# "agent stops the writer units"). Two granularities:
#
#   storm-stop   pause ONLY tq-agent-pool (the storm engine: ~1.7TB/boot
#                walking the 342 QLC repos — the sustained IO PSI baseline
#                that keeps the maintenance entry gate's 60-min trip-free
#                window from ever opening). Also used to quiet the box while
#                the throttled prepare rsync runs (cleaner parity, too).
#   cutover-stop pause the full D6 writer list so the final delta rsync
#                converges and no daemon commits into the QLC shadow across
#                the mount instant (auto-commit daemon = the 10-min-cycle
#                dominant writer; git object stores are append-only, but a
#                ref written on the subvol pointing at objects still on the
#                shadow = a dangling-ref repo).
#   start        restore exactly what a previous stop recorded (idempotent).
#   status       report every fleet unit's live state + the stop record.
#
# The deploy itself (switch-to-configuration) restarts units whose config
# changed; `start` here is for the units the switch does NOT touch.
set -euo pipefail

STATE_DIR=${PROJ_QUIESCE_STATE_DIR:-/home/lars/.cache/projects-migration}
RECORD=$STATE_DIR/quiesce.stopped

STORM_SET=(tq-agent-pool.service)
CUTOVER_SET=(
  tq-agent-pool.service
  projects-management-automation.service
  project-discovery-daemon.service
  cv-server.service
  nsfw-classifier.service
  git-lag-metrics.timer
  crush-daily.service
)

if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "must run as root (sudo)" >&2
    exit 1
  fi
  exec "$SUDO" env PATH="$PATH" PROJ_QUIESCE_STATE_DIR="$STATE_DIR" bash "$0" "$@"
fi

usage() {
  echo "usage: projects-cutover-quiesce.sh storm-stop|cutover-stop|start|status" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ACTION=$1

mkdir -p "$STATE_DIR"

record() {
  printf '%s\n' "$1" >>"$RECORD"
  sort -u -o "$RECORD" "$RECORD" 2>/dev/null || true
}

stop_set() {
  for unit in "$@"; do
    if systemctl is-active --quiet "$unit"; then
      echo "+ systemctl stop $unit"
      systemctl stop "$unit"
      record "$unit"
    else
      echo "= $unit already inactive — skipping"
    fi
  done
}

case "$ACTION" in
storm-stop)
  stop_set "${STORM_SET[@]}"
  echo "storm set paused (recorded in $RECORD). Watch the entry gate:"
  echo "  while ! maintenance-entry-gate --name stormwatch --psi-max 30; do sleep 120; done"
  ;;
cutover-stop)
  stop_set "${CUTOVER_SET[@]}"
  echo "cutover fleet paused (recorded in $RECORD)."
  echo "Now: re-run migrate-projects-subvol.sh prepare (delta pass), then deploy."
  ;;
start)
  if [ ! -f "$RECORD" ]; then
    echo "no stop record — nothing to restore"
    exit 0
  fi
  while IFS= read -r unit; do
    [ -n "$unit" ] || continue
    echo "+ systemctl start $unit"
    systemctl start "$unit" || echo "! $unit failed to start — check journalctl -u $unit" >&2
  done <"$RECORD"
  rm -f "$RECORD"
  echo "fleet restored, stop record cleared."
  ;;
status)
  echo "== writer fleet states:"
  for unit in "${CUTOVER_SET[@]}"; do
    printf '  %-42s %s\n' "$unit" "$(systemctl is-active "$unit" || true)"
  done
  if [ -f "$RECORD" ]; then
    echo "== recorded stopped (pending start):"
    sed 's/^/  /' "$RECORD"
  else
    echo "== no pending stop record"
  fi
  ;;
*)
  usage
  ;;
esac
