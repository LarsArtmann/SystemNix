#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# RETIRED 2026-09-14 — shared constants of the retired 2026-06-26 p8/p9
# emergency trio (disk-fix.sh, disk-diagnose.sh, disk-create-p9.sh).
# No remaining consumers. Original preserved in git history.
# NOTE: this file also hardcoded the disk by kernel name (/dev/nvme0n1) —
# nvme enumeration flips across boots on this box, another reason it stays
# retired. Live device references use /dev/disk/by-id.
# ═══════════════════════════════════════════════════════════════════════════
# Intentionally defines nothing — kept as a tombstone so `source` fails
# loudly rather than silently providing stale constants.
echo "ERROR: scripts/disk-common.sh is RETIRED (p8/p9 emergency trio)." >&2
exit 1
