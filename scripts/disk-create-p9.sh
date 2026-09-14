#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# RETIRED 2026-09-14 — DO NOT RUN. Original functionality removed.
#
# This script created p9 as a 100 GiB ext4 /rust-cache partition. That role
# was retired 2026-08-16 (Rust targets moved to /mnt/buildcache + sccache).
# Since 2026-08-22 p9 is the LIVE XFS ClickHouse store (label `clickhouse`,
# see scripts/migrate-clickhouse-xfs.sh and AGENTS.md "Filesystems gotchas").
#
# Running the original logic (`sgdisk -d 9` + mkfs.ext4 on p9) would DESTROY
# the live ClickHouse data partition — the exact footgun AGENTS.md warns
# about ("NEVER run the old `sudo sgdisk -d 9` deletion"). The implementation
# is preserved in git history if ever needed for archaeology.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

echo "ERROR: scripts/disk-create-p9.sh is RETIRED and refuses to run." >&2
echo "       p9 is the live XFS ClickHouse store since 2026-08-22." >&2
echo "       (Rust caches live on /mnt/buildcache; see scripts/migrate-clickhouse-xfs.sh.)" >&2
exit 1
