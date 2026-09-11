#!/usr/bin/env bash
# /data corruption repair runbook — T04..T09 of the master plan
# (docs/planning/2026-08-17_14-41_data-corruption-recovery-pool-completion-master-plan.md).
#
# Root cause (corrected 2026-09-06): operator-inflicted UNSAFE PARTITION
# SHRINK, NOT failing hardware. SMART on the host disk (Lexar NQ790, nvme0n1)
# is clean (media_errors=0, critical_warning=0, percent_used=15) and the
# journal csum-failure census is bounded-static (same inodes/offsets for
# weeks, ~10 lines/day = nightly btrbk re-reads). Repair = delete the
# affected files (extents cluster; 1.35M csum errors ≠ 1.35M files), let
# btrbk snapshot retention (14d+4w on /data) release the pinned extents,
# then scrub clean and resume btrbk-data.
#
# Phases (master plan T-numbers):
#   --status        read-only summary: SMART, last scrub, corrupt-file inventory (any user)
#   --map-full      T05 full read-verify of /data incl. root-owned trees + inode-resolve (root)
#   --safety-copy   T04 copy monitor365 data to /mnt/pool/archive/monitor365-nvme-safety (root)
#   --repair-list   print proposed per-file destructive actions (plan step 06a) (any user)
#   --apply-repair  T06 trash the redownloadable corrupt files (root; T04 must have run)
#   --metadata-check T07 maintenance window: docker down -> umount /data ->
#                   btrfs check --mode=low-risk (read-only) -> remount -> docker up (root)
#   --scrub         T08 scrub /data, gate on 0 csum errors (root)
#   --resume-seed   T09 re-kick btrbk-data after an IO-window check (root)
#
# No flag = --status.
# Exit codes: 0 healthy/complete, 1 problems found, 2 usage, 3 precondition failed.
set -uo pipefail

STATE_DIR="/var/lib/systemnix-data-repair"
CORRUPT_LIST="$STATE_DIR/corrupt-files.txt"
SAFETY_DIR="/mnt/pool/archive/monitor365-nvme-safety"

# Resolve binaries up front: sudo's secure PATH hides user-profile tools
# (migrate-clickhouse-xfs.sh lesson) and missing binaries must fail BEFORE
# any service is stopped. Core set for all phases; heavy phases re-check
# their specific binaries via need_bins.
need_bins() {
  local b
  for b in "$@"; do
    command -v "$b" >/dev/null 2>&1 || {
      echo "FATAL: missing binary: $b" >&2
      exit 3
    }
  done
}
need_bins awk cat cut date dd find findmnt grep head id journalctl pgrep \
  readlink sed sleep sort stat tail tr uniq wc

err=0
die() {
  echo "FATAL: $*" >&2
  exit 3
}
fail() {
  echo "FAIL: $*"
  err=1
}
ok() { echo "OK: $*"; }
warn() { echo "WARN: $*"; }

need_root() {
  [ "$(id -u)" -eq 0 ] || die "$1 requires root (run via sudo). Blocked: $2"
}

# IO-window guard: refuse heavy phases while pressure is high or a
# scrub/balance/btrbk is streaming (master plan timing constraint 3/4).
io_window_clear() {
  local psi_some
  psi_some=$(awk '/some avg10/ {print int($2)}' /proc/pressure/io 2>/dev/null)
  if [ "${psi_some:-0}" -ge 20 ]; then
    warn "IO PSI some avg10=${psi_some}% >= 20% — wait for a quiet window (or set I_OVERALL_OK=1 to override)"
    return 1
  fi
  local swap
  swap=$(awk '/^(SwapTotal|SwapFree)/ {print $2}' /proc/meminfo)
  local swap_used=$(($(echo "$swap" | head -1) - $(echo "$swap" | tail -1)))
  if [ "$(echo "$swap" | head -1)" -gt 0 ] && [ "$swap_used" -gt $(($(echo "$swap" | head -1) * 92 / 100)) ]; then
    warn "zram/swap >=92% full — the freeze cliff; postpone heavy IO (or set I_OVERALL_OK=1 to override)"
    return 1
  fi
  if pgrep -x btrbk >/dev/null 2>&1; then
    warn "btrbk is running — postpone (or set I_OVERALL_OK=1 to override)"
    return 1
  fi
  return 0
}

cmd_status() {
  echo "== /data corruption repair status =="

  echo "--- gate (a): host-disk SMART (Lexar NQ790, /data on nvme0n1p8) ---"
  local dev
  dev=$(findmnt -no SOURCE /data 2>/dev/null)
  [ -n "$dev" ] || {
    fail "/data not mounted"
    return
  }
  local disk="${dev%p*}"
  if command -v smartctl >/dev/null 2>&1; then
    smartctl --all "$disk" 2>/dev/null | awk \
      '/media and data integrity errors|Media and Data Integrity Errors/ {print "  " $0}
       /Percentage Used:/ {print "  " $0}
       /Critical Warning:/ {print "  " $0}
       /Available Spare:/ {print "  " $0}'
  else
    warn "smartctl not on PATH — reading the nvme.prom textfile metric instead"
    grep -E "media_errors_total|percentage_used|critical_warning" \
      /var/lib/prometheus-node-exporter/textfile_collectors/nvme.prom 2>/dev/null | grep -v '^#' | sed 's/^/  /' ||
      fail "cannot read SMART (no smartctl, no textfile metric)"
  fi

  echo "--- gate (b): scrub + damage census ---"
  journalctl --output cat --since "2026-08-23" -g "csum failed" 2>/dev/null |
    grep -oP 'ino \K[0-9]+' | sort -n | uniq -c | sort -rn |
    awk '{print "  ino " $2 ": " $1 " csum failures"}' ||
    echo "  (no csum failures journaled since 2026-08-23)"
  local lines
  lines=$(journalctl --output cat --since "48 hours ago" -g "csum failed" 2>/dev/null | wc -l)
  echo "  last 48h csum lines: $lines (steady ~10/day = bounded-static; rising trend = hardware triage)"

  echo "--- corrupt-file inventory ---"
  if [ -r "$CORRUPT_LIST" ]; then
    cat "$CORRUPT_LIST" | sed 's/^/  /'
  else
    echo "  (no inventory yet — run a read-verify pass first)"
  fi

  echo "--- btrbk-data state (the tripwire) ---"
  systemctl is-active btrbk-data.service 2>&1 | sed 's/^/  btrbk-data: /'
  systemctl is-failed btrbk-data.service 2>&1 | sed 's/^/  btrbk-data is-failed: /'
}

# T05 user-runnable mapping: journal inode census + full read-verify of the
# user-readable /data trees (DIRECT IO first, cache fallback), writing the
# corrupt-file inventory. The 2026-09-11 run found: 7 journal inodes, 6
# resolved to redownloadable model weights, 2 in root-owned trees, and
# DISPROVED the historical "~595G/~627-639G" window numbers (the Aug-17
# fiemap scan silently failed on `filefrag -v1`; read-verify is authoritative).
cmd_map_user() {
  need_bins dd
  io_window_clear || die "IO window not clear (see WARN above)"
  mkdir -p "$STATE_DIR" 2>/dev/null || STATE_DIR=$(mktemp -d)/systemnix-data-repair
  mkdir -p "$STATE_DIR"

  echo "== journal csum census (full retention) =="
  journalctl --output cat -g "csum failed" 2>/dev/null |
    grep -oP 'ino \K[0-9]+' | sort -n | uniq -c | sort -rn |
    awk '{print "  ino " $2 ": " $1 " csum failures"}' | tee "$STATE_DIR/csum-inodes.txt"
  local inodes
  inodes=$(awk '{print $2}' "$STATE_DIR/csum-inodes.txt")

  echo "== resolving inodes via find (user-readable trees) =="
  local trees="/data/ai /data/models /data/SteamLibrary /data/cache /data/gcs-staging /data/tmp-crush-test /data/.crush"
  local ino resolved=0 unresolved=""
  for ino in $inodes; do
    p=$(find $trees -xdev -inum "$ino" -type f -print -quit 2>/dev/null)
    if [ -n "$p" ]; then
      echo "  ino $ino -> $p"
      resolved=$((resolved + 1))
    else
      echo "  ino $ino -> not in user-readable trees (root-owned / docker / snapshot)"
      unresolved="$unresolved $ino"
    fi
  done
  [ -n "$unresolved" ] && echo "  unresolved:$unresolved (run --map-full as root for the btrfs ioctl resolve)"

  echo "== read-verify all user-readable files (DIRECT IO, no cache pressure; ~615G) =="
  local fails="$STATE_DIR/corrupt-files.txt.raw"
  : >"$fails"
  local n=0 total
  total=$(find $trees -xdev -type f 2>/dev/null | wc -l)
  while IFS= read -r f; do
    n=$((n + 1))
    if ! dd if="$f" of=/dev/null iflag=direct bs=4M count=100000 2>/dev/null; then
      if ! dd if="$f" of=/dev/null bs=4M count=100000 2>>"$fails"; then
        echo "$f" >>"$fails"
        echo "  EIO: $f"
      fi
    fi
    ((n % 5000 == 0)) && echo "  ... $n/$total files"
  done < <(find $trees -xdev -type f 2>/dev/null)
  sort -u "$fails" | grep -v '^dd:' >"$STATE_DIR/corrupt-files.txt" || true
  echo "== inventory: $(wc -l <"$STATE_DIR/corrupt-files.txt") corrupt files -> $STATE_DIR/corrupt-files.txt =="
  echo "bounded-vs-progressing verdict: compare this ino set against csum-inodes.txt over time;"
  echo "new inodes appearing = growing damage (hardware triage); static set = bounded (repair as planned)."
}

# T05 root-extended mapping: resolve the journal inodes via the btrfs ioctl
# (user inode-resolve is EPERM) and read-verify the root-owned trees.
cmd_map_full() {
  need_root "--map-full" "inode-resolve ioctl + /data/{docker,containers} reads"
  need_bins btrfs
  io_window_clear || die "IO window not clear (see WARN above)"

  mkdir -p "$STATE_DIR"
  local known_inodes
  known_inodes=$(awk '{print $2}' "$STATE_DIR/csum-inodes.txt" 2>/dev/null)
  [ -n "$known_inodes" ] || known_inodes="2114533 4969950 1331118 85607022 4995089 4020751 2608101"
  echo "== resolving journal inodes (btrfs ioctl) =="
  for ino in $known_inodes; do
    local p
    p=$(btrfs inspect-internal inode-resolve "$ino" /data 2>/dev/null | head -1)
    if [ -n "$p" ]; then echo "  ino $ino -> $p"; else echo "  ino $ino -> unresolved (not in /data root tree — likely a snapshot subvol or already deleted)"; fi
  done

  echo "== read-verify root-owned trees (/data/docker /data/containers) =="
  local tmp="$STATE_DIR/corrupt-files.root-owned"
  : >"$tmp"
  while IFS= read -r -d '' f; do
    dd if="$f" of=/dev/null bs=4M count=100000 2>/dev/null ||
      echo "$f" >>"$tmp"
  done < <(find /data/docker /data/containers -xdev -type f -print0 2>/dev/null)
  echo "  root-owned read fails: $(wc -l <"$tmp") (listed in $tmp)"
}

# T04: safety-copy every monitor365 data dir that still exists to the pool
# archive. Original plan targeted /data/monitor365 — that dir is GONE
# (data-to-pool-migration 2026-08-18), so discover what remains instead.
cmd_safety_copy() {
  need_root "--safety-copy" "reads root-owned /var/lib/monitor365-server; writes /mnt/pool/archive"
  need_bins rsync sha256sum mkdir df
  [ -d /mnt/pool ] || die "/mnt/pool not mounted"
  df --output=avail -BG /mnt/pool | tail -1 | awk '{print "  pool free: " $1}'

  mkdir -p "$SAFETY_DIR"
  local src
  for src in /var/lib/monitor365-server /data/monitor365 /mnt/pool/services/monitor365; do
    [ -d "$src" ] || {
      echo "  skip (absent): $src"
      continue
    }
    echo "== copying $src -> $SAFETY_DIR/$(basename "$src") =="
    rsync -a --info=stats1 "$src/" "$SAFETY_DIR/$(basename "$src")/" || {
      fail "rsync $src"
      continue
    }
  done

  echo "== checksum manifest =="
  find "$SAFETY_DIR" -type f -name '*.duckdb' -print0 |
    xargs -0 sha256sum >"$SAFETY_DIR/SHA256SUMS" 2>/dev/null
  wc -l <"$SAFETY_DIR/SHA256SUMS" | awk '{print "  " $1 " duckdb checksums in " $SAFETY_DIR "/SHA256SUMS"}'
  cat "$SAFETY_DIR/SHA256SUMS" | sed 's/^/  /'
}

cmd_repair_list() {
  local inv
  for inv in "$CORRUPT_LIST" "$STATE_DIR/corrupt-files.txt"; do [ -s "$inv" ] && break; done
  echo "== proposed destructive actions (master plan 06a: review before --apply-repair) =="
  cat "$inv" 2>/dev/null | while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
    /data/models/* | /data/ai/*)
      echo "  TRASH (redownloadable model weights): $f"
      ;;
    /data/docker/* | /data/containers/*)
      echo "  MANUAL (container state — restore from pool pg_dumps, do not blind-delete): $f"
      ;;
    *.duckdb* | */monitor365/*)
      echo "  MANUAL (DuckDB — never auto-delete; safety copy must exist first): $f"
      ;;
    *)
      echo "  REVIEW (unknown class): $f"
      ;;
    esac
  done
  [ -s "$inv" ] || echo "  (inventory empty — run --map-user, or --map-full as root)"
}

# T06: trash redownloadable corrupt files. DuckDB/container classes are
# NEVER auto-deleted (plan: T04 precondition + per-file human review).
cmd_apply_repair() {
  need_root "--apply-repair" "trashes files owned by other users"
  need_bins trash
  [ -d "$SAFETY_DIR" ] && [ -s "$SAFETY_DIR/SHA256SUMS" ] ||
    die "T04 precondition not met: $SAFETY_DIR/SHA256SUMS missing — run --safety-copy first"
  [ -s "$CORRUPT_LIST" ] || die "inventory empty — run the read-verify pass first"
  io_window_clear || die "IO window not clear"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
    /data/models/* | /data/ai/*)
      if [ -e "$f" ]; then
        trash "$f" && ok "trashed (redownloadable): $f" || fail "trash failed: $f"
      else
        warn "already gone: $f"
      fi
      ;;
    *) warn "skipped (manual class, see --repair-list): $f" ;;
    esac
  done <"$CORRUPT_LIST"
  echo "NOTE: freed extents stay PINNED by /data btrbk snapshots (14d+4w) — scrub-clean (T08) only after they expire."
}

# T07: the maintenance window. Read-only btrfs check, service outage gated
# behind an explicit flag so it can never ride along accidentally.
cmd_metadata_check() {
  need_root "--metadata-check" "docker stop, umount /data, btrfs check"
  need_bins btrfs lsof mount umount systemctl trash
  [ "${I_ACCEPT_SERVICE_OUTAGE:-0}" = "1" ] || die "this phase stops docker + unmounts /data. Re-run with I_ACCEPT_SERVICE_OUTAGE=1"
  io_window_clear || die "IO window not clear"

  echo "== stopping docker (twenty/manifest/dozzle go down) =="
  systemctl stop docker.service docker.socket || fail "docker stop"
  sleep 5
  echo "== quiesce check =="
  if lsof +f -- /data 2>/dev/null | tail -n +2 | grep -qv '^$'; then
    lsof +f -- /data | tail -n +2 | sed 's/^/  OPEN: /'
    systemctl start docker.service
    fail "/data still in use — aborted (docker restarted)"
    return
  fi
  ok "/data quiesced"
  echo "== unmount /data =="
  umount /data || {
    fail "umount /data"
    systemctl start docker.service
    return
  }
  local dev
  dev=$(readlink -f "/dev/disk/by-uuid/046ea663-da55-48b7-b516-0dcdb87ba710" 2>/dev/null)
  [ -n "$dev" ] || dev="/dev/nvme0n1p8"
  echo "== btrfs check --mode=low-risk (read-only) on $dev =="
  btrfs check --mode=low-risk "$dev"
  local rc=$?
  echo "== remount + restart docker =="
  mount /data || die "remount /data FAILED — check dmesg, this is the one non-recoverable step"
  systemctl start docker.service || fail "docker start"
  [ "$rc" -eq 0 ] && ok "btrfs check clean" || { fail "btrfs check exit $rc — capture the report"; }
}

# T08: scrub and gate on 0 csum errors. NOTE: errors pinned by not-yet-
# expired /data snapshots are EXPECTED until 14d+4w retention releases them.
cmd_scrub() {
  need_root "--scrub" "btrfs scrub"
  need_bins btrfs
  io_window_clear || die "IO window not clear"
  btrfs scrub start /data || die "scrub start failed"
  while :; do
    sleep 60
    local line
    line=$(btrfs scrub status -R /data 2>/dev/null | grep -E "errors:|status:" | tr '\n' ' ')
    echo "  $(date +%H:%M:%S) $line"
    btrfs scrub status /data 2>/dev/null | grep -q "status: finished" && break
  done
  local errors
  errors=$(btrfs scrub status -R /data 2>/dev/null | awk '/data_scrub_errors|errors:/ {print $NF}' | tail -1)
  if [ "${errors:-1}" = "0" ]; then
    ok "scrub complete, 0 csum errors — /data integrity gate PASSED"
  else
    fail "scrub complete with errors=${errors:-unknown} — corrupt extents remain (snapshot-pinned or new files; re-run the mapping)"
  fi
}

# T09: re-kick btrbk-data after verifying the IO window (plan: MORNING, never midnight).
cmd_resume_seed() {
  need_root "--resume-seed" "systemctl start btrbk-data"
  need_bins systemctl
  io_window_clear || die "IO window not clear — btrbk-data next fires at its 23:30 timer slot"
  systemctl start btrbk-data.service || fail "btrbk-data start"
  sleep 15
  journalctl -u btrbk-data.service --since "1 minute ago" --no-pager 2>/dev/null | tail -5 | sed 's/^/  /'
  echo "Watch for: 'send' lines advancing with no EIO (throughput ~17+ MB/s is sane)."
}

case "${1:---status}" in
--status) cmd_status ;;
--map-user) cmd_map_user ;;
--map-full) cmd_map_full ;;
--safety-copy) cmd_safety_copy ;;
--repair-list) cmd_repair_list ;;
--apply-repair) cmd_apply_repair ;;
--metadata-check) cmd_metadata_check ;;
--scrub) cmd_scrub ;;
--resume-seed) cmd_resume_seed ;;
*)
  sed -n '2,30p' "${BASH_SOURCE[0]}" | grep -E '^#' | sed 's/^# \{0,1\}//'
  exit 2
  ;;
esac

exit $err
