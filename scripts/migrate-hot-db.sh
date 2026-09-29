#!/usr/bin/env bash
# migrate-hot-db — user-run migration of a service dataDir onto the Samsung
# hot-DB tier (services.hot-db). Companion to modules/nixos/services/hot-db.nix
# (which renders the mounts + anti-shadow wiring); this script owns the DATA.
#
# Flow per service (ONE maintenance window each — one by one, never batched:
# deploying an entry that was never prepared mounts an EMPTY subvol over the
# live dataDir and shadow-splits the service):
#
#   1. Add the entry to services.hot-db.entries (see docs/services/hot-db.md
#      for the verified per-wave snippet) — enable = true, DO NOT deploy yet.
#   2. sudo nix run .#migrate-hot-db -- prepare <name>
#      Pressure-gated WARM copy: creates the hot/<name> subvolume and rsyncs
#      the dataDir into it while the service keeps RUNNING (the warm WAL copy
#      is discarded garbage; the cutover delta pass re-syncs it quiesced).
#   3. nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel
#      Pre-build the closure so step 5's switch is seconds, not minutes —
#      the service is STOPPED between cutover and the deploy's restart.
#   4. sudo nix run .#migrate-hot-db -- cutover <name>
#      Stops the service (+ its sidecar stop-set), delta-rsyncs quiesced,
#      verifies EXACT file count + byte size, writes the marker, leaves the
#      units STOPPED.
#   5. nix run .#deploy
#      Mounts the populated subvol AT the dataDir; stc restarts the service
#      onto it (RequiresMountsFor orders it after the mount).
#   6. sudo nix run .#migrate-hot-db -- finalize <name>
#      Verifies the mountpoint + counts against the marker, restarts the
#      stop-set, prints the functional probes.
#
# ROLLBACK (never automated mid-incident): remove the entry from the config,
# deploy, `sudo systemctl start <units>` — the QLC original sits shadowed
# under the mountpoint with everything up to the cutover (post-cutover writes
# live only in the subvol; flip back SOON after a bad wave to minimize the
# divergence). Keep the shadowed original until the soak ends (journal-hot
# doctrine); when cleaning it, remove its CONTENTS and keep the directory —
# systemd never creates mountpoints, and the mount unit needs the dir to
# exist for the next boot.
#
# PARALLEL-DEPLOY HAZARD (the 2026-09-30 defect list): between cutover and
# the deploy, ANY other session's deploy can restart the stopped units back
# onto the un-mounted QLC dir — a later mount-over then shadow-splits the
# running process (open fds keep writing the shadow). Keep the cutover→deploy
# gap small and do not run waves while other sessions are deploying.
#
# Env overrides (fixture tests + future waves):
#   MIGRATE_TOPLEVEL  toplevel mount to create subvols through (default /mnt/hot)
#   MIGRATE_PSI_FILE  IO PSI source               (default /proc/pressure/io)
#
# DRY RUN: --dry-run prints every action without executing (and skips all
# verification that would read never-created trees).
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

TOPLEVEL="${MIGRATE_TOPLEVEL:-/mnt/hot}"
PSI_FILE="${MIGRATE_PSI_FILE:-/proc/pressure/io}"
HOT_PARENT="$TOPLEVEL/hot"
STATE_DIR="$HOT_PARENT/.migrate-state"

usage() {
  cat >&2 <<EOF
usage: migrate-hot-db.sh [--dry-run] prepare|cutover|finalize|status [name]
       migrate-hot-db.sh [--dry-run] prepare|cutover|finalize <name> <dataDir> <unit> [more units...]

Registry (defaults; the 3+ arg form overrides dataDir + stop-set for
out-of-registry waves, e.g. the future postgres leg):
EOF
  for n in gatus dnsblockd pocket-id browser-history discordsync; do
    echo "  $n  ->  $(reg_dataDir "$n")  [$(echo "$(reg_units "$n")" | tr '\n' ' ')]" >&2
  done
  exit 2
}

# ── registry ────────────────────────────────────────────────────────────────
# dataDir = the REAL host path. DynamicUser services (gatus,
# browser-history) live behind the /var/lib/<name> -> private/<name>
# symlink — the mount must target the REAL dir, not the symlink.
# Stop-sets include sidecar timers that would otherwise fire mid-window
# (browser-history-agent) and DB-writing oneshots
# (browser-history-agent-token-provision, pocket-id-provision writes
# client-secrets/).
reg_dataDir() {
  case "$1" in
    gatus) echo "/var/lib/private/gatus" ;;
    dnsblockd) echo "/var/lib/dnsblockd" ;;
    pocket-id) echo "/var/lib/pocket-id" ;;
    browser-history) echo "/var/lib/private/browser-history" ;;
    discordsync) echo "/var/lib/discordsync" ;;
    *) return 1 ;;
  esac
}

reg_units() {
  case "$1" in
    # Monitoring blind for the window — every gatus check reds once, then
    # resolves; the runbook notes this is expected.
    gatus) echo "gatus.service" ;;
    # Sole resolver: the window is a LAN-wide DNS blip (clients cache or
    # blip; gatus "DNS Resolver" pages once and resolves).
    dnsblockd) echo "dnsblockd.service" ;;
    # pocket-id-provision writes client-secrets/ under the dataDir.
    pocket-id)
      echo "pocket-id.service"
      echo "pocket-id-provision.service"
      ;;
    # agent timer+service hammer the server while it is down (noise +
    # start-limit); token-provision writes the DB directly.
    browser-history)
      echo "browser-history-agent.timer"
      echo "browser-history-agent.service"
      echo "browser-history.service"
      echo "browser-history-agent-token-provision.service"
      ;;
    discordsync) echo "discordsync.service" ;;
    *) return 1 ;;
  esac
}

# ── plumbing ────────────────────────────────────────────────────────────────
run() {
  echo "+ $*"
  [ "$DRY_RUN" = "1" ] || "$@"
}

[ "$(id -u)" -eq 0 ] || {
  echo "must run as root (sudo)" >&2
  exit 1
}

[ $# -ge 1 ] || usage
ACTION=$1
NAME=${2:-}

DATADIR=""
STOP_UNITS=""
if [ $# -ge 4 ]; then
  # Generic override form: <name> <dataDir> <unit> [more units...]
  NAME=$2
  DATADIR=$3
  shift 3
  STOP_UNITS="$*"
elif [ $# -ge 2 ]; then
  if ! DATADIR=$(reg_dataDir "$NAME") || ! STOP_UNITS=$(reg_units "$NAME"); then
    echo "unknown service '$NAME' — pass the explicit form: $0 $ACTION $NAME <dataDir> <unit>" >&2
    exit 2
  fi
fi

[ -n "$NAME" ] || usage

SUBVOL="$HOT_PARENT/$NAME"
MARKER="$STATE_DIR/$NAME"

psi_gate() {
  # Deploy-pressure doctrine: never add a full dataDir read+write during an
  # IO storm. /proc/pressure/io line 1: "some avg10=x.y ..." — field 2.
  local psi
  psi=$(awk 'NR==1 {print $2}' "$PSI_FILE" 2>/dev/null || echo "avg10=0")
  psi="${psi#avg10=}"
  psi="${psi:-0}"
  if awk -v p="$psi" 'BEGIN { exit !(p >= 20) }'; then
    echo "REFUSED: IO PSI some avg10 = ${psi}% (>= 20%). Wait for a quiet window." >&2
    exit 1
  fi
  echo "PSI avg10 ${psi}%"
}

tier_gate() {
  if ! mountpoint -q "$TOPLEVEL"; then
    echo "$TOPLEVEL is not a mountpoint — detached Samsung. Refusing." >&2
    exit 1
  fi
}

counts() {
  # Apparent size of a tree (the migration's secondary verify currency:
  # rsync -a is mtime/size-preserving; a quiesced source must match EXACTLY).
  du -sb --apparent-size "$1" 2>/dev/null | awk '{print $1}'
}

count_files() {
  find "$1" -xdev -type f 2>/dev/null | wc -l
}

start_units() {
  for u in $STOP_UNITS; do
    run systemctl start "$u"
  done
}

case "$ACTION" in
prepare)
  [ -n "$DATADIR" ] || usage
  tier_gate
  psi_gate
  if [ ! -d "$DATADIR" ]; then
    echo "$DATADIR does not exist" >&2
    exit 1
  fi
  if mountpoint -q "$DATADIR"; then
    echo "$DATADIR is already a mountpoint — already migrated?" >&2
    exit 1
  fi
  echo "== prepare (WARM, service keeps running): $DATADIR -> $SUBVOL"
  # mkdir -p, NOT a pre-gate: the first-ever run precedes any deploy, so
  # nothing has created hot/ yet (the module bootstrap only runs at deploy
  # time — the 2026-09-30 defect list's gate-vs-flow contradiction).
  run mkdir -p "$HOT_PARENT"
  if ! btrfs subvolume show "$SUBVOL" >/dev/null 2>&1; then
    run btrfs subvolume create "$SUBVOL"
  fi
  # NOTE: no chattr here — cow=true entries (all five in the registry, per
  # the 2026-09-21 fsync matrix: nodatacow is worthless on TLC, cow keeps
  # checksums) must NOT get +C; the module bootstrap applies +C only to
  # cow=false entries, idempotently, at deploy time.
  run ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --info=stats2 "$DATADIR"/ "$SUBVOL"/
  if [ "$DRY_RUN" != "1" ]; then
    echo "warm copy: $(count_files "$SUBVOL") files staged (source is LIVE — no verify yet; cutover re-syncs quiesced)"
  fi
  echo "prepare OK. Next: add the entry (if not yet), pre-build the closure, then:"
  echo "  sudo $0 cutover ${NAME}"
  ;;
cutover)
  [ -n "$DATADIR" ] || usage
  tier_gate
  psi_gate
  if mountpoint -q "$DATADIR"; then
    echo "$DATADIR is already a mountpoint — migrated or entry deployed early. Refusing." >&2
    exit 1
  fi
  if ! btrfs subvolume show "$SUBVOL" >/dev/null 2>&1; then
    echo "$SUBVOL missing — run prepare first (or the entry is not declared)." >&2
    exit 1
  fi
  echo "== cutover: stop [$(echo "$STOP_UNITS" | tr '\n' ' ')], delta-sync quiesced, verify"
  for u in $STOP_UNITS; do
    run systemctl stop "$u"
  done
  if [ "$DRY_RUN" != "1" ]; then
    # --delete: the subvol is exclusively ours pre-mount; a stale warm-pass
    # file that vanished from the source since must not survive.
    if ! ionice -c 3 nice -n 19 rsync -aHAX --numeric-ids --delete --info=stats2 "$DATADIR"/ "$SUBVOL"/; then
      echo "rsync FAILED — restarting units on the untouched source." >&2
      start_units
      exit 1
    fi
    SRC_COUNT=$(count_files "$DATADIR")
    SRC_SIZE=$(counts "$DATADIR")
    DST_COUNT=$(count_files "$SUBVOL")
    DST_SIZE=$(counts "$SUBVOL")
    echo "files: src=$SRC_COUNT dst=$DST_COUNT  bytes: src=$SRC_SIZE dst=$DST_SIZE"
    if [ "$SRC_COUNT" != "$DST_COUNT" ] || [ "$SRC_SIZE" != "$DST_SIZE" ]; then
      echo "VERIFY FAILED — counts/sizes differ. Units left STOPPED; source untouched." >&2
      echo "Inspect $SUBVOL vs $DATADIR, then restart by hand: systemctl start$(echo "$STOP_UNITS" | sed 's/^/ /' | tr '\n' ' ')" >&2
      exit 1
    fi
    mkdir -p "$STATE_DIR"
    printf 'FILES=%s\nBYTES=%s\nSTAMP=%s\n' "$SRC_COUNT" "$SRC_SIZE" "$(date +%s)" >"$MARKER"
  fi
  echo "cutover OK — units STOPPED, subvol quiesced-synced, marker at $MARKER."
  echo "NOW (keep tight — parallel deploys can restart the stopped units onto the QLC dir):"
  echo "  nix run .#deploy   (closure should be pre-built)"
  echo "then: sudo $0 finalize ${NAME}"
  ;;
finalize)
  [ -n "$DATADIR" ] || usage
  if ! mountpoint -q "$DATADIR"; then
    echo "$DATADIR is not a mountpoint — deploy the enabled entry first" >&2
    exit 1
  fi
  if [ "$DRY_RUN" != "1" ] && [ ! -f "$MARKER" ]; then
    echo "$MARKER missing — cutover never ran for this name? Refusing to verify nothing." >&2
    exit 1
  fi
  echo "== finalize: verify mount + counts, restart [$(echo "$STOP_UNITS" | tr '\n' ' ')]"
  if [ "$DRY_RUN" != "1" ]; then
    # The 2026-09-30 defect list: finalize used to verify NOTHING. Counts
    # may legitimately drift UP (deploy restarted the service, writers
    # append) and the WAL/-shm pair can appear/vanish — the gate is
    # "not FEWER than cutover (minus the WAL/-shm pair)".
    MARKER_FILES=$(sed -n 's/^FILES=//p' "$MARKER")
    MARKER_BYTES=$(sed -n 's/^BYTES=//p' "$MARKER")
    DST_COUNT=$(find "$DATADIR" -xdev -type f | wc -l)
    DST_SIZE=$(du -sb --apparent-size "$DATADIR" | awk '{print $1}')
    echo "files: cutover=$MARKER_FILES now=$DST_COUNT  bytes: cutover=$MARKER_BYTES now=$DST_SIZE"
    if [ "$((DST_COUNT + 2))" -lt "$MARKER_FILES" ]; then
      echo "VERIFY FAILED: fewer files than the cutover snapshot ($DST_COUNT < $MARKER_FILES)." >&2
      echo "Units NOT restarted. Inspect the mount before starting anything." >&2
      exit 1
    fi
  fi
  start_units
  echo "finalize OK. Functional probes before closing the window:"
  case "$NAME" in
    gatus) echo "  https://status.$(hostname -d 2>/dev/null || echo home.lan) renders + one check cycle green" ;;
    dnsblockd) echo "  dig cache.home.lan @127.0.0.1 +short answers; /health 200" ;;
    pocket-id) echo "  one SSO login (passkey) through auth.home.lan" ;;
    browser-history) echo "  dashboard loads; inboxclean/agent ingest green on next tick" ;;
    discordsync) echo "  /api/health on :8085 OK; a new Discord message lands in the capture" ;;
  esac
  echo "Keep the QLC shadow under the mountpoint as rollback insurance until the soak ends."
  ;;
status)
  for n in gatus dnsblockd pocket-id browser-history discordsync; do
    if [ -n "$NAME" ] && [ "$n" != "$NAME" ]; then
      continue
    fi
    d=$(reg_dataDir "$n") || continue
    s="$HOT_PARENT/$n"
    sub="missing"
    btrfs subvolume show "$s" >/dev/null 2>&1 && sub="exists"
    sub="$sub$( [ -n "$(ls -A "$s" 2>/dev/null || true)" ] && echo ",populated" || echo ",empty")"
    mp="no"
    mountpoint -q "$d" && mp="YES"
    mk="none"
    [ -f "$STATE_DIR/$n" ] && mk="$(sed -n '1p' "$STATE_DIR/$n")"
    echo "$n: dataDir=$d mountpoint=$mp subvol=$sub marker=$mk"
  done
  ;;
*)
  usage
  ;;
esac
