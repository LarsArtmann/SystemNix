#!/usr/bin/env bash
# DAS USB link recovery diagnostics — READ-ONLY, safe to run any time.
#
# After a crash/freeze the DAS enclosure (USB link 8-1) can drop off the bus
# entirely: ALL external disks (both pool Toshibas, both SanDisks incl. the
# buildcache SSD) vanish simultaneously, sometimes mid-write (ext4 journal
# abort). Software cannot heal a dead link — this script gathers the facts and
# prints the decision tree so the next session does not rediscover them.
#
# Also catches the software-side failure modes seen around such events:
# zombie mounts (findmnt green, every I/O EIOs), root-fs shadow contamination
# at unmounted mountpoints, and unexpected debris dirs on the cache SSD
# (e.g. a doubled /mnt/buildcache/mnt/buildcache from a bad path join).
#
# Usage:
#   bash scripts/das-link-recovery-check.sh
#
# Needs no root; degrades gracefully when the journal is unreadable.
# Exit codes: 0 = everything healthy, 1 = problems found (see output).
set -euo pipefail

# Known devices (mirror of configuration.nix fstab entries).
POOL_MEMBERS=(
  "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A005FWTG"
  "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG"
)
BUILDCACHE_DISK="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311"
BUILDCACHE_PART="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1"
# Frozen by user decision ("do not touch them; yet") — absent is EXPECTED.
FROZEN_SPARE="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713"

# Expected top-level entries on a healthy buildcache SSD (buildcacheDirs in
# modules/nixos/services/buildcache.nix + HM symlink targets).
KNOWN_CACHE_ENTRIES=(
  cargo go go-build go-mod goimports golangci-lint npm pip pnpm-store
  playwright rust sccache
)

issues=0
note() { printf '  ⚠ %s\n' "$*"; issues=$((issues + 1)); }
ok() { printf '  ✓ %s\n' "$*"; }
bad() { printf '  ✗ %s\n' "$*"; issues=$((issues + 1)); }

echo "== DAS USB link recovery check ($(date '+%F %T')) =="

# ── 1. USB storage tree ─────────────────────────────────────────────────────
echo "[1] USB storage interfaces (sysfs)"
usb_storage_ifaces=$(
  for f in /sys/bus/usb/devices/*:*/bInterfaceClass; do
    [ -f "$f" ] || continue
    [ "$(cat "$f" 2>/dev/null)" = "08" ] && dirname "$f"
  done | wc -l
)
if [ "$usb_storage_ifaces" -gt 0 ]; then
  ok "$usb_storage_ifaces storage-class USB interface(s) present"
else
  bad "ZERO storage-class USB interfaces on the bus — the DAS link is DOWN"
  note "Software recovery impossible: physically reseat the DAS USB cable +"
  note "enclosure power, then REBOOT (a warm reboot may not re-enumerate)."
fi
if [ -d /sys/bus/usb/devices/8-1 ]; then
  ok "usb 8-1 (DAS link) enumerated"
else
  note "usb 8-1 not enumerated (DAS link down or enclosure unpowered)"
fi

# ── 2. by-id presence matrix ────────────────────────────────────────────────
echo "[2] Known disks (by-id)"
for dev in "${POOL_MEMBERS[@]}" "$BUILDCACHE_DISK"; do
  if [ -b "$dev" ]; then
    ok "present: $(basename "$dev")"
  else
    bad "ABSENT: $(basename "$dev")"
  fi
done
if [ -b "$FROZEN_SPARE" ]; then
  ok "present (frozen spare, do not touch): $(basename "$FROZEN_SPARE")"
else
  ok "frozen spare absent (expected — user decision: do not touch)"
fi

# ── 3. Block devices ────────────────────────────────────────────────────────
echo "[3] sd* block devices"
sd_devices=()
for d in /sys/class/block/sd*; do
  [ -e "$d" ] && sd_devices+=("${d##*/}")
done
if [ "${#sd_devices[@]}" -gt 0 ]; then
  ok "${#sd_devices[@]} sd* device(s): ${sd_devices[*]}"
else
  bad "no sd* block devices — no USB/SATA disks visible to the kernel"
fi

# ── 4. Mount + zombie detection ─────────────────────────────────────────────
check_mount() {
  local target="$1" want_fs="$2"
  local line fstype source
  line=$(findmnt -n -o FSTYPE,SOURCE "$target" 2>/dev/null || true)
  if [ -z "$line" ]; then
    bad "$target: not mounted, no armed automount"
    return
  fi
  fstype=${line%% *}
  source=${line#* }
  if [ "$fstype" = "autofs" ]; then
    if [ -b "$BUILDCACHE_PART" ] && [ "$target" = "/mnt/buildcache" ]; then
      note "$target: automount armed but not yet triggered — access it, then re-check"
    else
      ok "$target: automount armed (will mount on access)"
    fi
    return
  fi
  if [ "$fstype" != "$want_fs" ]; then
    bad "$target: fstype $fstype (expected $want_fs)"
    return
  fi
  if [ ! -b "$source" ]; then
    bad "$target: ZOMBIE mount — source $source has no device node. Fix:"
    note "  systemctl stop mnt-${target#/mnt/}.automount mnt-${target#/mnt/}.mount"
    note "  umount -l $target   # then re-arm: systemctl start mnt-${target#/mnt/}.automount"
    note "  (or just: systemctl start buildcache-usb-recovery.service for buildcache)"
    return
  fi
  if timeout 15 ls -A "$target" >/dev/null 2>&1; then
    ok "$target: mounted ($fstype) and serving real I/O"
  else
    bad "$target: mounted but I/O probe FAILED (EIO/timeout) — zombie mount"
  fi
}
echo "[4] Mounts"
check_mount /mnt/buildcache ext4
check_mount /mnt/pool btrfs
if findmnt -n /mnt/pool >/dev/null 2>&1; then
  present_members=0
  for dev in "${POOL_MEMBERS[@]}"; do
    [ -b "$dev" ] && present_members=$((present_members + 1))
  done
  if [ "$present_members" -lt 2 ]; then
    note "pool mounted with $present_members/2 members — degraded RAID1; never"
    note "write to it in this state; mounting -o degraded is a USER decision"
  fi
fi

# ── 5. ext4 damage scan (this boot) → e2fsck heuristic ──────────────────────
echo "[5] ext4 error scan for buildcache (kernel log, this boot)"
fsck_needed=0
if journalctl -k -b --no-pager >/dev/null 2>&1; then
  ext4_errors=$(
    journalctl -k -b --no-pager 2>/dev/null \
      | grep -E 'lost async page write|journal abort|EXT4-fs (error|warning)|remounting read-only|I/O error' \
      | grep -Ei 'sd[a-f]|buildcache|ext4' \
      | tail -5 || true
  )
  if [ -n "$ext4_errors" ]; then
    fsck_needed=1
    bad "ext4/kernel error lines found this boot:"
    while IFS= read -r l; do note "  $l"; done <<<"$ext4_errors"
  else
    ok "no ext4 error lines in this boot's kernel log"
  fi
else
  note "journal unreadable without root — re-run with sudo for the ext4 scan"
fi
if findmnt -n -t ext4 /mnt/buildcache >/dev/null 2>&1; then
  sysfs_errors=$(cat /sys/fs/ext4/*/errors_count 2>/dev/null | grep -vc '^0$' || true)
  [ "${sysfs_errors:-0}" -gt 0 ] && fsck_needed=1
fi
if [ "$fsck_needed" = 1 ]; then
  echo "  e2fsck decision (cache data is DISPOSABLE by design):"
  note "  umount /mnt/buildcache && fsck.ext4 -f -y $BUILDCACHE_PART"
  note "  (or reformat the cache: mkfs.ext4 -L buildcache $BUILDCACHE_PART)"
fi

# ── 6. Shadow contamination + SSD debris ────────────────────────────────────
echo "[6] Shadow/debris checks"
for pair in "/mnt/buildcache:@/mnt/buildcache" "/mnt/pool:@/mnt/pool"; do
  live=${pair%%:*}
  shadow="/mnt/btrfs-root/${pair#*:}"
  if [ -d "$shadow" ] && [ -n "$(ls -A "$shadow" 2>/dev/null)" ] \
    && ! findmnt -n "$live" >/dev/null 2>&1; then
    bad "root-fs shadow at $shadow is NON-EMPTY while $live is unmounted —"
    note "  data was written to the NVMe under a dead mount; triage before mounting"
  fi
done
if findmnt -n -t ext4 /mnt/buildcache >/dev/null 2>&1; then
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    known=0
    for k in "${KNOWN_CACHE_ENTRIES[@]}"; do
      [ "$entry" = "$k" ] && known=1 && break
    done
    if [ "$known" = 0 ]; then
      note "unexpected entry on cache SSD: /mnt/buildcache/$entry (debris or"
      note "  path-join bug — e.g. an 'mnt' dir means something created"
      note "  /mnt/buildcache//mnt/... inside the mount)"
    fi
  done < <(ls -A /mnt/buildcache 2>/dev/null)
else
  note "cache SSD not mounted — debris check skipped (re-run after recovery)"
fi

# ── 7. Verdict ───────────────────────────────────────────────────────────────
echo "== Decision tree =="
if [ "$usb_storage_ifaces" -eq 0 ]; then
  cat <<'EOF'
LINK DOWN (no USB storage on the bus):
  1. Reseat the DAS USB cable AND the enclosure power connector.
  2. REBOOT the machine (power cycle — a warm reboot may not re-enumerate).
  3. After boot, re-run this script; expect [1][2][3] green.
  4. buildcache heals itself: udev SYSTEMD_WANTS triggers
     buildcache-usb-recovery.service on partition add (remount + I/O verify
     + re-provision + metrics refresh). Verify with:
       systemctl status buildcache-usb-recovery.service
  5. /mnt/pool mounts via fstab once BOTH Toshiba members enumerate.
     One-member mount requires -o degraded — USER decision, never automate.
  6. If [5] flagged ext4 damage: run the printed e2fsck command, then
     systemctl start buildcache-init.service.
EOF
elif [ "$issues" -eq 0 ]; then
  echo "All checks green. Confirm Gatus flips: 'Build Cache SSD' + 'DAS USB Link'."
else
  cat <<'EOF'
LINK UP but problems found above — follow the per-section ✗/⚠ notes.
Zombie buildcache mount: systemctl start buildcache-usb-recovery.service
Lingering red Gatus: systemctl start buildcache-metrics.service
EOF
fi

echo "== $issues issue(s) found =="
[ "$issues" -eq 0 ]
