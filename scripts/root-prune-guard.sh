#!/usr/bin/env bash
# root-prune-guard.sh; Root-space floor: immediate btrbk root prune above 90% df usage.
#
# The 10-02 06:33 dnsblockd SIGBUS/ENOSPC outage class had an empty ladder
# rung: 93% gatus alert -> (nothing) -> 100% -> outage (two 100% events in
# 24h). This guard is the missing rung: when the QLC root crosses 90% (df
# scale), run `btrbk -c /etc/btrbk/root.conf prune` IMMEDIATELY instead of
# waiting for the nightly windows (btrbk run only prunes AFTER its send
# phase, so storm-killed sends defer pruning indefinitely; the exact
# accumulation that drove the 10-01/10-02 root to 100%).
#
# Fail-safety (btrbk 0.32.7, source-verified in snapshots.nix): the latest
# common snapshot per target is FORCE_PRESERVEd (send parents can never be
# pruned while the target is reachable; racing a live nightly send is safe)
# and if ANY target aborts (pool detached) source cleanup is SKIPPED
# entirely, so prune can never break the incremental chain.
#
# Metric contract (ALWAYS written, even below threshold; the Gatus check
# carries an anchored presence leg that needs the line alive):
#   root_prune_guard_fired       1 = threshold crossed, prune invoked this run
#   root_prune_guard_usage_pct   df-scale used percent of /
#   root_prune_guard_prune_exit  exit status of this run's prune (0 when not fired)
#
# The unit always exits 0: a failed prune is operational state recorded in
# the metric + journal (Gatus is red while fired 1), not a crash to retry at
# the systemd layer. Consumed by root-prune-guard.{service,timer} in
# platforms/nixos/system/snapshots.nix; fixture-tested via the
# root-prune-guard-fixture flake check (stubs for df/btrbk).
set -euo pipefail

THRESHOLD=90
OUT="${ROOT_PRUNE_GUARD_OUT:-/var/lib/prometheus-node-exporter/textfile_collectors/root-prune-guard.prom}"

# df-scale used % (the same basis as df Use%: used / (used + available),
# reserved blocks excluded). Collector-scale (statvfs) reads ~3pp below
# this, so the 93% "Root FS Early Warning" band starts at the same place:
# guard first, alert second, no silent rung between them.
read -r USED AVAIL < <(df -Pk / | awk 'NR == 2 { print $3, $4 }')
PCT=$((USED * 100 / (USED + AVAIL)))

fired=0
prune_rc=0
if [ "$PCT" -gt "$THRESHOLD" ]; then
  fired=1
  echo ":: root at ${PCT}% (>${THRESHOLD}%); btrbk root prune NOW (root-space floor; expired local snapshots are the deterministic reclaim lever)"
  btrbk -c /etc/btrbk/root.conf prune || prune_rc=$?
  if [ "$prune_rc" -ne 0 ]; then
    # Benign when a nightly btrbk run is mid-flight or /mnt/pool is
    # detached (aborted target skips source cleanup by design); the next
    # 5-min cycle retries. Recorded in the metric either way.
    echo "ERROR: btrbk prune failed (exit ${prune_rc}); expired root snapshots may be lingering; investigate only if this persists across cycles: btrbk -c /etc/btrbk/root.conf prune" >&2
  fi
fi

# mktemp + trap per scripts/audit-textfile-tmp.sh class A: a fixed tmp name
# wedges the rename on stale foreign-owned leftovers in the sticky 1777
# textfile dir (mail-relay 2026-09-02..06 class).
TMP="$(mktemp "$(dirname "$OUT")/root-prune-guard.prom.XXXXXX")"
chmod 644 "$TMP"
trap 'rm -f "$TMP"' EXIT
{
  echo "# HELP root_prune_guard_fired 1 = root usage crossed 90% (df scale) and btrbk root prune was invoked this run"
  echo "# TYPE root_prune_guard_fired gauge"
  echo "root_prune_guard_fired ${fired}"
  echo "# HELP root_prune_guard_usage_pct df-scale used percent of / (used / (used + avail), reserved excluded)"
  echo "# TYPE root_prune_guard_usage_pct gauge"
  echo "root_prune_guard_usage_pct ${PCT}"
  echo "# HELP root_prune_guard_prune_exit exit status of this run's btrbk root prune (0 when not fired)"
  echo "# TYPE root_prune_guard_prune_exit gauge"
  echo "root_prune_guard_prune_exit ${prune_rc}"
} >"$TMP"

# Sticky-dir rename: the unit always runs as the btrbk user, so the .prom is
# btrbk-owned and the rename never crosses owners. A root-owned leftover
# (manual root test run) wedges this mv; that is the fail-visible
# mail-relay class (unit red + onFailure), not a frozen green.
mv "$TMP" "$OUT"
