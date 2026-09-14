#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# RETIRED 2026-09-14 — DO NOT RUN. Original functionality removed.
#
# This was the 2026-06-26 p8-boundary EMERGENCY repair (delete the partial
# p9, resize p8 to cover the 1 TiB BTRFS /data, delete dead partitions,
# scrub). It was EXECUTED once and fully succeeded — the emergency is over.
#
# Since 2026-08-22 p9 is the LIVE XFS ClickHouse store (label `clickhouse`,
# see scripts/migrate-clickhouse-xfs.sh and AGENTS.md "Filesystems gotchas"):
# this script's PHASE 1 (`sgdisk -d 9`) would DESTROY that live partition.
# The implementation is preserved in git history if ever needed.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

echo "ERROR: scripts/disk-fix.sh is RETIRED and refuses to run." >&2
echo "       It was the 2026-06-26 emergency repair (already executed); p9 is" >&2
echo "       now the live XFS ClickHouse store — its p9-deletion phase would" >&2
echo "       destroy live data. See scripts/migrate-clickhouse-xfs.sh." >&2
exit 1
