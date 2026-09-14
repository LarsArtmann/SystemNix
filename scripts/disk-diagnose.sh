#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# RETIRED 2026-09-14 — DO NOT RUN. Original functionality removed.
#
# This was the diagnosis companion of the 2026-06-26 p8/p9 overlap EMERGENCY
# (disk-fix.sh + disk-create-p9.sh). That emergency was resolved long ago and
# both fix scripts are retired — keeping a diagnostic whose GO/NO-GO output
# recommends running them (including in the SAFE state) is a footgun.
#
# Current p9 is the LIVE XFS ClickHouse store (label `clickhouse`,
# scripts/migrate-clickhouse-xfs.sh). For current disk health use the live
# monitoring instead: btrfs-health metrics + Gatus, pool-smart-metrics,
# `btrfs scrub status`, `lsblk -f`. Original preserved in git history.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

echo "ERROR: scripts/disk-diagnose.sh is RETIRED and refuses to run." >&2
echo "       The 2026-06-26 p8/p9 overlap emergency is long resolved; p9 is now" >&2
echo "       the live XFS ClickHouse store. See scripts/migrate-clickhouse-xfs.sh" >&2
echo "       and AGENTS.md 'Filesystems gotchas'." >&2
exit 1
