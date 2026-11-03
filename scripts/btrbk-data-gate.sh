#!/usr/bin/env bash
# btrbk-data-gate — ExecStartPre contract for btrbk-data.service
# (platforms/nixos/system/snapshots.nix, btrbkDataGate).
#
# Leg 1 — EIO repair gate (2026-09-11, docs/todo/storage.md /data repair
# item): the /data -> pool send has been structurally dead since 2026-07
# (EIO csum errors from the unsafe-partition-shrink corruption), yet every
# nightly run still READ the full ~258G tree for ~3h12m before dying
# (18G page-cache peak = the oom-kill failure mode, ~329G written) —
# ~8TB/month of pointless QLC reads. Owner stance: btrbk-data keeps
# FAILING (the failure is the tripwire), so the gate makes the failure
# CHEAP: while /data/.repair-done is absent it takes the cheap local CoW
# snapshot + retention prune (the /data rollback tier never missed a
# night — only the send died) and then exits 1, so OnFailure still fires
# nightly and ExecStart (the expensive `btrbk run` send) never starts.
#
# Leg 2 — exclude-rot guard (2026-11-03, storage-pareto plan T-02; owner
# doctrine: NEVER pool-backup re-downloadable AI models): /data/ai,
# /data/SteamLibrary and /data/gcs-staging are excluded from the "."
# snapshot as NESTED SUBVOLUMES (btrbk has no per-directory exclude;
# nested subvols are skipped by both `btrfs subvolume snapshot` and
# `btrfs send` — the migrate-nix-subvol precedent). If any tree rots back
# to a plain dir (Steam reinstall, restore tooling, manual copy), a
# resumed send would carry ~650G of models to the pool. While the EIO
# gate holds, rot is a WARNING (the send is dead anyway — visibility
# only); once /data/.repair-done exists it is a HARD tripwire: exit 1
# before any byte is read. A path that does not exist at all is CLEAN
# (the tree was purged — nothing to carry; the T12 gcs-staging purge
# shape). Migration runbook: scripts/migrate-data-exclude-subvols.sh.
#
# Fixture-tested via checks.btrbk-data-gate-fixture (stubbed btrfs/btrbk
# through BTRBK_DATA_GATE_ROOT/SUBVOLS_OK env); negative-proven by
# scripts/negative-test-lints.sh (datagate group).
set -euo pipefail

DATA_ROOT="${BTRBK_DATA_GATE_ROOT:-/data}"
EXCLUDE_SUBVOLS=(ai SteamLibrary gcs-staging)

rotted=()
for subvol in "${EXCLUDE_SUBVOLS[@]}"; do
  path="$DATA_ROOT/$subvol"
  # Absent = clean (nothing to carry); present-but-not-a-subvolume = rot.
  [ -e "$path" ] || continue
  if ! btrfs subvolume show "$path" >/dev/null 2>&1; then
    rotted+=("$subvol")
  fi
done

if [ ! -f "$DATA_ROOT/.repair-done" ]; then
  if [ "${#rotted[@]}" -gt 0 ]; then
    echo "btrbk-data: EXCLUDE-ROT WARNING: ${rotted[*]} not subvolume(s) — a resumed /data send would carry them (~650G models class, owner doctrine 2026-11-03). Run scripts/migrate-data-exclude-subvols.sh before lifting the EIO gate." >&2
  fi
  echo "btrbk-data: /data EIO repair gate ACTIVE (no /data/.repair-done marker) — taking local snapshot + retention prune, then deliberate fast-fail"
  if ! btrbk -c /etc/btrbk/data.conf snapshot; then
    echo "btrbk-data: local snapshot ALSO failed — inspect /data health before the repair run" >&2
  fi
  if ! btrbk -c /etc/btrbk/data.conf prune; then
    echo "btrbk-data: retention prune failed — snapshots may accumulate while the gate is active" >&2
  fi
  echo "btrbk-data: nightly pool send deliberately SKIPPED (known /data EIO, docs/todo/storage.md P0). This failure is the tripwire and is EXPECTED while the marker is absent; remove the gate after the T04-T08 repair." >&2
  exit 1
fi

if [ "${#rotted[@]}" -gt 0 ]; then
  echo "btrbk-data: EXCLUDE-ROT TRIPWIRE: ${rotted[*]} not subvolume(s) — REFUSING the pool send (owner doctrine 2026-11-03: NEVER pool-backup re-downloadable AI models). Heal with scripts/migrate-data-exclude-subvols.sh." >&2
  exit 1
fi

exit 0
