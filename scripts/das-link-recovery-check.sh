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
# at unmounted mountpoints, NVMe fallback-cache regrowth (real dirs replacing
# the HM symlinks), and unexpected debris dirs on the cache SSD (e.g. a
# doubled /mnt/buildcache/mnt/buildcache from a bad path join).
#
# Usage:
#   bash scripts/das-link-recovery-check.sh          # as your user
#   sudo bash scripts/das-link-recovery-check.sh     # adds: full shadow
#                                                   # triage (root-only dirs)
#
# Exit codes: 0 = everything healthy, 1 = problems found (see output).
# "issue count" counts PROBLEMS, not remediation lines.
set -euo pipefail

# Known devices (mirror of the fstab entries; drift vs /etc/fstab is CHECKED
# at runtime in [2] so a stale constant fails loud instead of silently).
# Pool mounts BY-LABEL (2026-08-27): any RAID1 member can mount the fs, so
# the fstab names the label, not one member. BOTH member by-ids below stay
# for the presence check (each member must enumerate) — and member 2 (…0ZU…)
# is btrfs-remembered only, never in fstab.
POOL_FSTAB_DEVICE="/dev/disk/by-label/pool"
POOL_MEMBERS=(
  "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A005FWTG"
  "/dev/disk/by-id/ata-TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG"
)
BUILDCACHE_DISK="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311"
BUILDCACHE_PART="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1"
# Frozen by user decision ("do not touch them; yet") — absent is EXPECTED.
FROZEN_SPARE="/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713"

# Expected top-level entries on a healthy buildcache SSD — must mirror
# buildcacheDirs in modules/nixos/services/buildcache.nix.
KNOWN_CACHE_ENTRIES=(
  cargo go go-build go-mod goimports golangci-lint npm pip pnpm-store
  playwright rust sccache
)

# Home of the invoking user (SUDO_USER-aware so [7] still checks the real
# user's cache symlinks when the whole script is run under sudo).
USER_HOME=$(getent passwd "${SUDO_USER:-$(id -un)}" | cut -d: -f6)

# HM-managed symlinks that MUST stay symlinks — a real dir here is fallback
# regrowth onto the space-critical NVMe (blocks the next HM activation and
# re-contaminates root; see AGENTS.md buildcache section).
CACHE_SYMLINKS=(
  "$USER_HOME/.cache/goimports"
  "$USER_HOME/.cache/go"
  "$USER_HOME/.cache/go-build"
  "$USER_HOME/.local/share/pnpm/store"
)
# Sibling-session fallback caches (BuildFlow names) — NOT in the recovery
# reap list; surfaced with sizes because the disposition decision is open.
FALLBACK_CACHE_DIRS=(gobuild gocache gomod)

issues=0
bad() {
  printf '  ✗ %s\n' "$*"
  issues=$((issues + 1))
}
note() {
  printf '  ⚠ %s\n' "$*"
  issues=$((issues + 1))
}
ok() { printf '  ✓ %s\n' "$*"; }
hint() { printf '    %s\n' "$*"; }

echo "== DAS USB link recovery check ($(date '+%F %T')) =="

# ── 1. USB storage tree ─────────────────────────────────────────────────────
echo "[1] USB storage interfaces (sysfs)"
usb_storage_ifaces=$(
  count=0
  for f in /sys/bus/usb/devices/*:*/bInterfaceClass; do
    if [ -f "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "08" ]; then
      count=$((count + 1))
    fi
  done
  echo "$count"
)
if [ "$usb_storage_ifaces" -gt 0 ]; then
  ok "$usb_storage_ifaces storage-class USB interface(s) present"
else
  bad "ZERO storage-class USB interfaces on the bus — the DAS link is DOWN"
  hint "Software recovery impossible: physically reseat the DAS USB cable +"
  hint "enclosure power, then REBOOT (a warm reboot may not re-enumerate)."
fi
# 8-1 is the DAS link's usual bus address, but USB topology CAN move (port
# change, hub renumeration) — only count its absence when nothing else is up.
if [ -d /sys/bus/usb/devices/8-1 ]; then
  ok "usb 8-1 (DAS link) enumerated"
elif [ "$usb_storage_ifaces" -eq 0 ]; then
  note "usb 8-1 not enumerated (DAS link down or enclosure unpowered)"
fi

# ── 2. by-id presence matrix + fstab drift ──────────────────────────────────
echo "[2] Known disks (by-id)"
fstab_device() {
  awk -v t="$1" '$2 == t { print $1 }' /etc/fstab 2>/dev/null || true
}
fstab_bc=$(fstab_device /mnt/buildcache)
if [ -n "$fstab_bc" ] && [ "$fstab_bc" != "$BUILDCACHE_PART" ]; then
  bad "fstab drift: /mnt/buildcache uses $fstab_bc but this script knows"
  hint "$BUILDCACHE_PART — update the constants at the top of this script."
fi
fstab_pool=$(fstab_device /mnt/pool)
if [ -n "$fstab_pool" ] && [ "$fstab_pool" != "$POOL_FSTAB_DEVICE" ]; then
  bad "fstab drift: /mnt/pool uses $fstab_pool but this script knows"
  hint "$POOL_FSTAB_DEVICE — update the constants at the top of this script."
  hint "(If $fstab_pool is the pre-2026-08-27 by-id member path, deploy first:"
  hint " the by-label fstab entry ships with this same change.)"
fi
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
  if [ -e "$d" ]; then
    sd_devices+=("${d##*/}")
  fi
done
if [ "${#sd_devices[@]}" -gt 0 ]; then
  ok "${#sd_devices[@]} sd* device(s): ${sd_devices[*]}"
else
  bad "no sd* block devices — no USB/SATA disks visible to the kernel"
fi

# ── 4. Mount + zombie detection ─────────────────────────────────────────────
# check_mount <target> <want_fs> <expected backing devices...>
check_mount() {
  local target="$1" want_fs="$2"
  shift 2
  local line fstype source have_dev=0 dev
  line=$(findmnt -n -o FSTYPE,SOURCE "$target" 2>/dev/null || true)
  if [ -z "$line" ]; then
    bad "$target: not mounted, no armed automount"
    return
  fi
  fstype=${line%% *}
  source=${line#* }
  for dev in "$@"; do
    if [ -b "$dev" ]; then
      have_dev=1
    fi
  done
  if [ "$fstype" = "autofs" ]; then
    if [ "$have_dev" = 1 ]; then
      ok "$target: automount armed; mounts on first access (normal)"
    else
      bad "$target: automount armed but backing device ABSENT —"
      hint "access will fail ENODEV until the disk returns; heals on replug"
      hint "(udev re-arms the automount). No software action needed."
    fi
    return
  fi
  if [ "$fstype" != "$want_fs" ]; then
    bad "$target: fstype $fstype (expected $want_fs)"
    return
  fi
  if [ ! -b "$source" ]; then
    bad "$target: ZOMBIE mount — source $source has no device node. Fix:"
    hint "systemctl stop mnt-${target#/mnt/}.automount mnt-${target#/mnt/}.mount"
    hint "umount -l $target   # then re-arm: systemctl start mnt-${target#/mnt/}.automount"
    hint "(or just: systemctl start buildcache-usb-recovery.service for buildcache)"
    return
  fi
  if timeout 15 ls -A "$target" >/dev/null 2>&1; then
    ok "$target: mounted ($fstype) and serving real I/O"
  else
    bad "$target: mounted but I/O probe FAILED (EIO/timeout) — zombie mount"
  fi
}
echo "[4] Mounts"
check_mount /mnt/buildcache ext4 "$BUILDCACHE_PART"
check_mount /mnt/pool btrfs "${POOL_MEMBERS[@]}"
if findmnt -n /mnt/pool >/dev/null 2>&1; then
  present_members=0
  for dev in "${POOL_MEMBERS[@]}"; do
    if [ -b "$dev" ]; then
      present_members=$((present_members + 1))
    fi
  done
  if [ "$present_members" -lt 2 ]; then
    note "pool mounted with $present_members/2 members — degraded RAID1; never"
    hint "write to it in this state; mounting -o degraded is a USER decision"
  fi
fi

# ── 5. ext4 damage scan (current AND previous boot) → e2fsck heuristic ──────
# The damage is usually logged in the boot that CRASHED — after the recovery
# reboot it lives in `journalctl -b -1`, so scanning only the current boot
# would print a false "clean" for exactly the incident this script targets.
echo "[5] ext4 damage scan for buildcache (kernel log, this + previous boot)"
fsck_needed=0
kernel_log_readable=1
scan_boot() {
  local label="$1" hits
  if [ "$kernel_log_readable" = 0 ]; then
    return
  fi
  hits=$(
    journalctl -k "$label" --no-pager 2>/dev/null |
      grep -E 'lost async page write|Aborting journal|journal abort|EXT4-fs (error|warning)|remounting read-only|I/O error' |
      grep -Ei 'sd[a-z]|buildcache|ext4' |
      tail -5 || true
  )
  if [ -n "$hits" ]; then
    fsck_needed=1
    bad "ext4/kernel error lines found ($label):"
    while IFS= read -r l; do hint "$l"; done <<<"$hits"
  else
    ok "no ext4 error lines ($label)"
  fi
}
# journalctl exits 0 with EMPTY output when access is denied — probe content,
# never trust the exit code alone (phantom-green guard).
if [ -n "$(journalctl -k -b --no-pager -n 1 2>/dev/null || true)" ]; then
  scan_boot -b
  scan_boot "-b -1"
else
  kernel_log_readable=0
  note "kernel journal unreadable/empty as $(id -un) — damage scan skipped;"
  hint "re-run with sudo: sudo bash scripts/das-link-recovery-check.sh"
fi
if findmnt -n -t ext4 /mnt/buildcache >/dev/null 2>&1; then
  # Superblock error counter — persists across reboots until fsck clears it.
  # Scoped to buildcache's OWN device only (a global /sys/fs/ext4/* sweep
  # would flag unrelated ext4 filesystems).
  src=$(readlink -f "$(findmnt -n -o SOURCE /mnt/buildcache)")
  ec_file="/sys/fs/ext4/${src##*/}/errors_count"
  if [ -r "$ec_file" ]; then
    ec_val=$(cat "$ec_file" 2>/dev/null || true)
    if [ -z "$ec_val" ]; then
      note "cannot read $ec_file"
    elif [ "$ec_val" != "0" ]; then
      fsck_needed=1
      bad "ext4 errors_count=$ec_val on ${src##*/} — superblock recorded errors"
    else
      ok "ext4 errors_count=0 (${src##*/})"
    fi
  fi
fi
if [ "$fsck_needed" = 1 ]; then
  echo "  e2fsck decision (cache data is DISPOSABLE by design):"
  hint "umount /mnt/buildcache && fsck.ext4 -f -y $BUILDCACHE_PART"
  hint "(or reformat the cache: mkfs.ext4 -L buildcache $BUILDCACHE_PART)"
fi

# ── 6. Shadow contamination + SSD debris ────────────────────────────────────
echo "[6] Shadow/debris checks"
for pair in "/mnt/buildcache:@/mnt/buildcache" "/mnt/pool:@/mnt/pool"; do
  live=${pair%%:*}
  shadow="/mnt/btrfs-root/${pair#*:}"
  if [ -d "$shadow" ] && [ -n "$(ls -A "$shadow" 2>/dev/null)" ] &&
    ! findmnt -n "$live" >/dev/null 2>&1; then
    # Distinguish real stranded data from empty scaffolding (dirs mkdir'd by
    # services while the mount was dead — benign, hidden once remounted).
    first_file=$(find "$shadow" -xdev -type f -print -quit 2>&1 || true)
    first_file=${first_file%%$'\n'*} # keep the first line only (display)
    case "$first_file" in
    /*)
      bad "REAL data under $shadow (e.g. $first_file) — written to the"
      hint "NVMe under a dead mount; triage before mounting over it"
      ;;
    "")
      note "$shadow: empty scaffolding only (dirs created while unmounted;"
      hint "harmless — hidden once the real mount returns — but watch that"
      hint "nothing writes here while the pool is down)"
      ;;
    *)
      note "$shadow: non-empty; full triage needs root:"
      hint "$first_file"
      hint "re-run with sudo: sudo bash scripts/das-link-recovery-check.sh"
      ;;
    esac
  fi
done
if findmnt -n -t ext4 /mnt/buildcache >/dev/null 2>&1; then
  while IFS= read -r entry; do
    if [ -z "$entry" ]; then
      continue
    fi
    known=0
    for k in "${KNOWN_CACHE_ENTRIES[@]}"; do
      if [ "$entry" = "$k" ]; then
        known=1
        break
      fi
    done
    if [ "$known" = 0 ]; then
      note "unexpected entry on cache SSD: /mnt/buildcache/$entry (debris or"
      hint "path-join bug — e.g. an 'mnt' dir means something created"
      hint "/mnt/buildcache//mnt/... inside the mount)"
    fi
  done < <(ls -A /mnt/buildcache 2>/dev/null)
else
  note "cache SSD not mounted — debris check skipped (re-run after recovery)"
fi

# ── 7. Cache symlinks + NVMe fallback growth ────────────────────────────────
echo "[7] Cache symlinks + NVMe fallback growth"
for p in "${CACHE_SYMLINKS[@]}"; do
  if [ -L "$p" ]; then
    ok "$p (symlink — correct)"
  elif [ -e "$p" ]; then
    bad "$p is a REAL dir on the NVMe ($(du -sh "$p" 2>/dev/null | cut -f1)) —"
    hint "fallback regrowth: it re-routes build churn onto the QLC root and"
    hint "blocks the next HM activation (checkLinkTargets). Rebuildable —"
    hint "deploy.sh reaps the known names pre-switch, or remove it manually."
  else
    note "$p missing (HM creates it on next activation)"
  fi
done
for name in "${FALLBACK_CACHE_DIRS[@]}"; do
  p="$USER_HOME/.cache/$name"
  if [ -e "$p" ] && [ ! -L "$p" ]; then
    note "$p (sibling-session fallback, disposition open):"
    hint "$(du -sh "$p" 2>/dev/null | cut -f1) on the space-critical NVMe;"
    hint "not in the buildcache-usb-recovery reap list — user decision"
    hint "pending (keep while DAS is down vs quarantine/remove)."
  fi
done

# ── 8. Verdict ──────────────────────────────────────────────────────────────
echo "== Decision tree =="
if [ "$usb_storage_ifaces" -eq 0 ]; then
  cat <<'EOF'
LINK DOWN (no USB storage on the bus):
  1. CRITICAL — the JMS567 bridge runs off USB VBUS from the host: pulling
     ONLY the enclosure power does NOT power-cycle it. Pull the USB cable
     AND the enclosure power, wait 60+ s, reconnect. Every "power cycle"
     with the cable attached is a fake one (2026-08-29 lesson).
  2. Use a REAR Type-A port ONLY. The front USB4-C ports have NO Type-C
     port class registration under this kernel (/sys/class/typec is empty)
     and have never enumerated a device — they are dead for data; silence
     there says nothing about the DAS.
  3. Replug after controllers are pinned awake (power/control=on — now
     automatic via the buildcache udev rule; a D3cold controller silently
     swallows hotplug events).
  4. If still silent on a rear port: the bridge is wedged beyond VBUS
     recovery → enclosure side (PSU/bridge) or disk relocation. The disks
     are plain SATA: pool reassembles by-label (both Toshibas) in any other
     enclosure; the buildcache SSD is disposable by design.
  5. buildcache heals itself: udev SYSTEMD_WANTS triggers
     buildcache-usb-recovery.service on partition add (remount + I/O verify
     + re-provision + metrics refresh). Verify with:
       systemctl status buildcache-usb-recovery.service
  6. /mnt/pool mounts via fstab once BOTH Toshiba members enumerate.
     One-member mount requires -o degraded — USER decision, never automate.
  7. If [5] flagged ext4 damage (check BOTH boots): run the printed e2fsck
     command, then systemctl start buildcache-init.service.
  8. Re-run with sudo once for full shadow triage ([6] root-only dirs).
EOF
elif [ "$issues" -eq 0 ]; then
  echo "All checks green. Confirm Gatus flips: 'Build Cache SSD' + 'DAS USB Link'."
else
  cat <<'EOF'
LINK UP but problems found above — follow the per-section ✗/⚠ notes.
Zombie buildcache mount: systemctl start buildcache-usb-recovery.service
Lingering red Gatus: systemctl start buildcache-metrics.service
Real-dir cache fallbacks ([7]): rebuildable — remove after confirming the
  mount is healthy (deploy.sh also reaps the known names pre-switch).
EOF
fi

echo "== $issues issue(s) found =="
[ "$issues" -eq 0 ]
