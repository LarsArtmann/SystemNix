#!/usr/bin/env bash
# Trash-size textfile collector.
#
# Emits trash_size_bytes{path=...} for the box's trash locations so parked
# trash is observable (storage.md "make parked-trash size observable" row):
# 55G sat invisible in ~/.local/share/Trash for a month (2026-10-08 →) with
# no metric, no alert, and no closing loop. Companion legs: the trash-prune
# user timer (platforms/common/programs/trash-prune.nix) bounds the home
# Trash at 30d, and pre-deploy-check.sh §20 warns when the home Trash
# exceeds its threshold before a deploy freezes it into the snapshot pin
# window.
#
# Metric freshness follows the memory-guard doctrine: the .prom is rewritten
# atomically (mktemp + rename) on every tick and stamps
# last_run_timestamp_seconds, so a dead collector is detectable by
# staleness.
#
# Runbook: docs/services/trash-metrics.md

set -euo pipefail

OUT="${TRASH_METRICS_OUT:-/var/lib/prometheus-node-exporter/textfile_collectors/trash-metrics.prom}"
# Space-separated trash paths; a missing dir emits 0 (honest "no trash",
# keeps alert expressions absent-handling-free).
TRASH_PATHS="${TRASH_METRICS_PATHS:-/home/lars/.local/share/Trash /data/.Trash-1000}"

PROM_TMP=""
cleanup() {
  if [ -n "$PROM_TMP" ]; then
    rm -f "$PROM_TMP"
  fi
}
trap cleanup EXIT

# mktemp + rename per the repo textfile doctrine (1777 sticky dir: a fixed
# .tmp path wedges on foreign-owned leftovers; the unique-tmp form needs no
# caps and keeps the audit exception list empty).
render_prom() {
  PROM_TMP="$(mktemp "${OUT}.XXXXXX")"
  chmod 644 "$PROM_TMP"
  {
    echo "# HELP trash_size_bytes On-disk size in bytes of trashed items per trash location (0 = location absent/empty)"
    echo "# TYPE trash_size_bytes gauge"
    local p bytes
    for p in $TRASH_PATHS; do
      bytes=0
      if [ -d "$p" ]; then
        bytes="$(du -sb "$p" 2>/dev/null | cut -f1)"
        bytes="${bytes:-0}"
      fi
      echo "trash_size_bytes{path=\"$p\"} $bytes"
    done
    echo "# HELP trash_metrics_last_run_timestamp_seconds Epoch of this collection — freshness signal; a frozen value means the collector is DEAD (node_exporter serves the stale textfile forever)"
    echo "# TYPE trash_metrics_last_run_timestamp_seconds gauge"
    echo "trash_metrics_last_run_timestamp_seconds $(date +%s)"
  } >"$PROM_TMP"
  mv "$PROM_TMP" "$OUT"
  PROM_TMP=""
}

render_prom

# --- selftest -------------------------------------------------------------
# Fixture trash trees; asserts emitted bytes for a populated dir, 0 for a
# missing dir, and the freshness stamp.
selftest() {
  local scratch out
  scratch="$(mktemp -d)"
  out="$scratch/trash.prom"

  mkdir -p "$scratch/trash-home/files"
  dd if=/dev/zero of="$scratch/trash-home/files/blob" bs=1024 count=2048 status=none

  TRASH_METRICS_OUT="$out" \
    TRASH_METRICS_PATHS="$scratch/trash-home $scratch/trash-absent" \
    bash "${BASH_SOURCE[0]}"

  local fail=0
  if ! grep -q "trash_size_bytes{path=\"$scratch/trash-home\"} 2097152" "$out"; then
    echo "selftest FAIL: populated trash dir did not emit its du -sb bytes" >&2
    fail=1
  fi
  if ! grep -q "trash_size_bytes{path=\"$scratch/trash-absent\"} 0" "$out"; then
    echo "selftest FAIL: missing trash dir must emit 0" >&2
    fail=1
  fi
  if ! grep -q '^trash_metrics_last_run_timestamp_seconds [0-9]' "$out"; then
    echo "selftest FAIL: freshness stamp missing" >&2
    fail=1
  fi

  rm -rf "$scratch"
  if [ "$fail" -eq 0 ]; then
    echo "trash-size-metrics selftest: OK"
  fi
  exit "$fail"
}

if [ "${1:-}" = "selftest" ]; then
  selftest
fi
