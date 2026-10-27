#!/usr/bin/env bash
# backup-catchup-report.sh — one-command backup-catchup review.
#
# The backup arc (btrbk sends, pool receives, coordination metrics) spans
# four btrbk instances, a 5-min metric timer, and a backup-slot catch-up
# guard. Reviewing a backup outage re-derived all of it by hand every time
# (docs/status/2026-08-31_16-29 §e.3-4/§f.15-18). This script closes the
# remaining half of that item: stamps vs OnCalendar, prom-vs-filesystem
# diff, and an opt-in btrbk dry-run.
#
# What it reports, per btrbk instance:
#   1. Timer stamp (last trigger epoch from /var/lib/systemd/timers) vs the
#      newest snapshot subvolume in each configured snapshot_dir — a fired
#      timer with no fresh snapshot is the catch-up failure class.
#   2. backups.prom freshness gauges (backup_last_success_timestamp /
#      backup_age_hours) diffed against the ACTUAL newest filesystem stamp
#      for every coordination entry that points at a scanned dir — a stale
#      or lying metric is invisible to everything downstream.
#   3. Optional `btrbk --dry-run run` per instance (flag --dry-run):
#      read-only send/prune plan, catches config drift after restores.
#
# Read-only by default (stamp/stat/find + reading the prom textfile); the
# dry-run is btrbk's own read-only mode.
#
# Usage:
#   backup-catchup-report.sh [--dry-run] [--prom <file>] [--selftest]
#     --dry-run   additionally run `btrbk --dry-run run` per instance
#     --prom      backups.prom path (default:
#                 /var/lib/prometheus-node-exporter/textfile_collectors/backups.prom)
#     --selftest  fixture selftest of the pure helpers, then exit
# Exit codes: 0 = no findings; 1 = at least one WARN/CRIT finding (findings
# are the point of a review tool); 2 = environment error (no /etc/btrbk,
# missing btrbk/systemctl).
set -euo pipefail

BTRBK_CONF_DIR="/etc/btrbk"
TIMER_STAMP_DIR="/var/lib/systemd/timers"
PROM_FILE="/var/lib/prometheus-node-exporter/textfile_collectors/backups.prom"
DO_DRY_RUN=0
SELFTEST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DO_DRY_RUN=1 ;;
    --prom)
      shift
      [ $# -gt 0 ] || { echo "backup-catchup-report.sh: --prom needs a path" >&2; exit 2; }
      PROM_FILE="$1"
      ;;
    --selftest) SELFTEST=1 ;;
    *)
      echo "unknown option: $1 (usage: $0 [--dry-run] [--prom <file>] [--selftest])" >&2
      exit 2
      ;;
  esac
  shift
done

FINDINGS=0

note() { echo "  $1"; }
warn_finding() {
  FINDINGS=$((FINDINGS + 1))
  echo "  WARN  $1"
}
crit_finding() {
  FINDINGS=$((FINDINGS + 1))
  echo "  CRIT  $1"
}
section() { echo; echo "== $1"; }

# ── pure helpers (fixture-tested by --selftest) ──────────────────────────

# newest_btrbk_snapshot <dir> — newest `*.YYYYMMDD[T[HHMM[...]]]` subvolume
# dir in <dir> (btrbk names snapshots <name>.<timestamp>, lexicographic =
# chronological), empty when none. | head -1 with `|| true`: SIGPIPE-safe.
newest_btrbk_snapshot() {
  find "$1" -maxdepth 1 -mindepth 1 -type d 2>/dev/null \
    | grep -E '/[^/]+\.[0-9]{8}(T[0-9]{4})?$' \
    | sort | tail -1 || true
}

# prom_gauges <prom-file> — emits "name{labels}=value" triples minus HELP/
# TYPE, newline-tolerant. Empty on missing file (caller decides severity).
prom_gauges() {
  [ -f "$1" ] && grep -v '^#' "$1" || true
}

# prom_value <prom-file> <metric-name> <backup-label> — prints the value of
# `metric{...backup="<label>"...}` (exact label match) or nothing when absent.
prom_value() {
  prom_gauges "$1" \
    | awk -v m="$2" -v b="$3" '
        $1 ~ "^" m "\\{" {
          labels = $1
          sub(/^[^{]+\{/, "", labels); sub(/\}.*/, "", labels)
          n = split(labels, parts, ",")
          for (i = 1; i <= n; i++) {
            split(parts[i], kv, "=")
            gsub(/"/, "", kv[2])
            if (kv[1] == "backup" && kv[2] == b) { print $NF; exit }
          }
        }'
}

hours_between() { echo "$(( ($1 - $2) / 3600 ))"; }

SELFTEST_DIR=""

selftest() {
  local pass=0 failn=0
  SELFTEST_DIR=$(mktemp -d)
  local scratch="$SELFTEST_DIR"
  trap 'rm -rf "$SELFTEST_DIR"' EXIT

  # newest_btrbk_snapshot: picks the lexicographically-newest timestamped dir
  mkdir -p "$scratch/snap/@.20260101T2300" "$scratch/snap/@.20260930T2301" \
    "$scratch/snap/not-a-snapshot" "$scratch/snap/@.bogus" "$scratch/empty"
  r=$(newest_btrbk_snapshot "$scratch/snap")
  if [ "${r##*/}" = "@.20260930T2301" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL newest_btrbk_snapshot: got '$r'";
  fi

  # empty dir -> empty result (not an error)
  r=$(newest_btrbk_snapshot "$scratch/empty")
  if [ -z "$r" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL newest_btrbk_snapshot empty: got '$r'";
  fi

  # missing dir -> empty result (find 2>/dev/null)
  r=$(newest_btrbk_snapshot "$scratch/nonexistent")
  if [ -z "$r" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL newest_btrbk_snapshot missing: got '$r'";
  fi

  # prom_value: exact-label match, absent label -> empty
  cat > "$scratch/backups.prom" <<'EOF'
# HELP backup_age_hours x
# TYPE backup_age_hours gauge
backup_age_hours{backup="immich"} 3
backup_age_hours{backup="pool-snapshots"} 9
backup_last_success_timestamp{backup="immich"} 1700000000
backup_all_healthy 1
EOF
  r=$(prom_value "$scratch/backups.prom" backup_age_hours immich)
  if [ "$r" = "3" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL prom_value exact: got '$r'";
  fi
  r=$(prom_value "$scratch/backups.prom" backup_age_hours nonexistent)
  if [ -z "$r" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL prom_value absent: got '$r'";
  fi
  r=$(prom_value "$scratch/backups.prom" backup_last_success_timestamp immich)
  if [ "$r" = "1700000000" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL prom_value other metric: got '$r'";
  fi
  # label is a PREFIX of another label — must not match the longer one
  cat > "$scratch/prefix.prom" <<'EOF'
backup_age_hours{backup="immich"} 3
backup_age_hours{backup="immich-db"} 77
EOF
  r=$(prom_value "$scratch/prefix.prom" backup_age_hours immich)
  if [ "$r" = "3" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL prom_value prefix: got '$r'";
  fi

  # hours_between
  r=$(hours_between 3600 0)
  if [ "$r" = "1" ]; then
    pass=$((pass + 1))
  else
    failn=$((failn + 1)); echo "FAIL hours_between: got '$r'";
  fi

  echo "selftest: $pass passed, $failn failed"
  [ "$failn" -eq 0 ]
}

if [ "$SELFTEST" -eq 1 ]; then
  selftest
  exit $?
fi

# ── environment ──────────────────────────────────────────────────────────
[ -d "$BTRBK_CONF_DIR" ] || { echo "no $BTRBK_CONF_DIR — not the backup host?" >&2; exit 2; }
command -v btrbk >/dev/null 2>&1 || { echo "btrbk not on PATH" >&2; exit 2; }
command -v systemctl >/dev/null 2>&1 || { echo "systemctl not on PATH" >&2; exit 2; }

NOW=$(date +%s)

declare -A SNAP_DIRS_SEEN=()

section "btrbk instances: timer stamp vs newest snapshot"
for conf in "$BTRBK_CONF_DIR"/*.conf; do
  name=$(basename "$conf" .conf)
  echo
  echo "-- $name ($conf)"

  stamp_file="$TIMER_STAMP_DIR/stamp-btrbk-$name.timer"
  if [ -f "$stamp_file" ]; then
    stamp=$(stat -c %Y "$stamp_file")
    stamp_h=$(hours_between "$NOW" "$stamp")
    note "timer last trigger: $stamp_h h ago ($(date -d "@$stamp" '+%F %T' 2>/dev/null || echo '?'))"
  else
    stamp=""
    warn_finding "$name: no timer stamp file $stamp_file (timer never fired or unit renamed)"
  fi

  conf_snapshot_dirs=$(awk '$1 == "snapshot_dir" {print $2}' "$conf")
  if [ -z "$conf_snapshot_dirs" ]; then
    warn_finding "$name: no snapshot_dir line parseable in $conf"
  fi
  while IFS= read -r sdir; do
    [ -n "$sdir" ] || continue
    SNAP_DIRS_SEEN["$sdir"]="$name"
    latest=$(newest_btrbk_snapshot "$sdir")
    if [ -z "$latest" ]; then
      crit_finding "$name: no btrbk snapshot subvolume found in $sdir"
      continue
    fi
    snap_mtime=$(stat -c %Y "$latest")
    snap_h=$(hours_between "$NOW" "$snap_mtime")
    note "newest snapshot: ${latest##*/} ($snap_h h ago)"
    if [ -n "$stamp" ]; then
      # A trigger that fired LONG before the newest snapshot is fine (the
      # snapshot landed after it); a trigger newer than the snapshot by
      # >1 h means the run produced nothing (the catch-up failure class).
      if [ "$snap_mtime" -lt $((stamp - 3600)) ]; then
        lag_h=$(hours_between "$stamp" "$snap_mtime")
        warn_finding "$name/$sdir: timer fired $lag_h h after the newest snapshot — last run produced nothing"
      fi
    fi
  done <<EOF
$conf_snapshot_dirs
EOF

  if [ "$DO_DRY_RUN" -eq 1 ]; then
    echo "-- btrbk --dry-run run ($name):"
    if btrbk -c "$conf" --dry-run run; then
      note "dry-run clean (no pending changes reported above = converged)"
    else
      crit_finding "$name: btrbk --dry-run run exited non-zero (config drift or backend error)"
    fi
  fi
done

section "backups.prom vs filesystem stamps"
if [ -f "$PROM_FILE" ]; then
  prom_ts_count=$(prom_gauges "$PROM_FILE" | awk '$1 ~ /^backup_last_success_timestamp\{/' | wc -l)
  if [ "$prom_ts_count" -eq 0 ]; then
    warn_finding "$PROM_FILE has no backup_last_success_timestamp series (collector broken?)"
  fi
  # Coordination entries named after a scanned snapshot dir (basename match)
  # get their prom stamp diffed against the real newest filesystem stamp;
  # everything else (file-pattern backups owned by services) is out of
  # this script's scan scope and is only sanity-checked for presence.
  while IFS= read -r sdir; do
    [ -n "$sdir" ] || continue
    backup_label=${sdir##*/}
    latest=$(newest_btrbk_snapshot "$sdir")
    [ -n "$latest" ] || continue
    fs_ts=$(stat -c %Y "$latest")
    prom_ts=$(prom_value "$PROM_FILE" backup_last_success_timestamp "$backup_label")
    if [ -z "$prom_ts" ]; then
      warn_finding "no backup_last_success_timestamp series for '$backup_label' in $PROM_FILE (coordination entry missing?)"
      continue
    fi
    diff=$(( fs_ts - prom_ts ))
    adiff=${diff#-}
    if [ "$adiff" -gt 3600 ]; then
      warn_finding "$backup_label: prom stamp ($prom_ts) vs filesystem ($fs_ts) differ by $((adiff / 3600)) h — metric is stale or lying"
    else
      note "$backup_label: prom stamp within 1 h of filesystem (diff ${diff} s)"
    fi
  done < <(printf '%s\n' "${!SNAP_DIRS_SEEN[@]}" | sort)
else
  warn_finding "no prom file at $PROM_FILE — coordination collector never ran?"
fi

section "summary"
if [ "$FINDINGS" -eq 0 ]; then
  echo "all checks green: every fired timer produced a fresh snapshot; prom agrees with the filesystem"
fi
echo "findings: $FINDINGS"
[ "$FINDINGS" -eq 0 ]
