#!/usr/bin/env bash
# Zombie-mount gate (pre-deploy §17, 2026-08-16 buildcache class) — shared
# lib extracted from the inline pre-deploy-check.sh block so the fixture
# selftest exercises the SAME code the deploy gate runs (scripts/
# test-zombie-mount-gate.sh + the zombie-mount-gate-selftest flake check;
# the §10/§11/§13/§14/§15/§16 extraction pattern — the gate shipped
# green-path-tested only, no zombie mount was available to prove the FAIL
# path, docs/status/tasks/2026-10-21_04-27_task-* §e.3).
#
# What a zombie is: a USB hot-unplug/replug reassigns the device letter
# without clearing the VFS mount entry — findmnt still reports the OLD
# /dev/sdX (gone from sysfs), every I/O on the mount fails EIO, and df
# serves stale superblock numbers. Either trip BLOCKS the deploy.
#
# Callers provide the verdict callbacks (single message argument):
#   ZM_PASS ZM_FAIL
# Testable seams (live defaults in parentheses):
#   ZM_FINDMNT      findmnt command          (findmnt)
#   ZM_TIMEOUT_BIN  timeout command          (timeout)
#   ZM_DEV_ROOT     prefix for -e existence checks ("" — real sysfs)

ZM_FINDMNT="${ZM_FINDMNT:-findmnt}"
ZM_TIMEOUT_BIN="${ZM_TIMEOUT_BIN:-timeout}"
ZM_DEV_ROOT="${ZM_DEV_ROOT:-}"

zm_scan() {
  local zm_mnt zm_src zm_dev zm_tripped=0 zm_targets
  zm_targets=$("$ZM_FINDMNT" -rn -o TARGET 2>/dev/null | grep -E '^/mnt/' | sort -u || true)
  while IFS= read -r zm_mnt; do
    [ -n "$zm_mnt" ] || continue
    # Real filesystems only — automounted targets also list an autofs row
    # whose SOURCE is "systemd-1"; btrfs renders SOURCE as /dev/sda1[/subvol].
    zm_src="$("$ZM_FINDMNT" -nro SOURCE -t btrfs,ext4,ext3,ext2,xfs,vfat,ntfs3,fuseblk "$zm_mnt" 2>/dev/null | tail -1 || true)"
    zm_dev="${zm_src%%\[*}"
    case "$zm_dev" in
    /dev/*)
      if [ ! -e "$ZM_DEV_ROOT$zm_dev" ]; then
        "$ZM_FAIL" "ZOMBIE MOUNT $zm_mnt: source $zm_dev no longer exists (device-letter reassignment after USB flap) — recovery: sudo umount -l $zm_mnt && sudo systemctl restart the target's .automount unit, then reboot if it persists (see docs/agents/storage.md 'Stale mountinfo after USB hot-plug')"
        zm_tripped=1
      fi
      ;;
    esac
    # Real-IO probe: the phantom-green killer. A zombie or shutdown-superblock
    # fs answers findmnt but fails every read (EIO). Own shell cd'd into the
    # mount is the main EIO spammer — cd out before recovering.
    if ! "$ZM_TIMEOUT_BIN" 10 ls -A "$zm_mnt" >/dev/null 2>&1; then
      "$ZM_FAIL" "ZOMBIE/DEAD MOUNT $zm_mnt: real-IO probe failed (EIO / shutdown superblock) while findmnt still lists it — the 2026-08-16 phantom-green signature. Recovery: sudo umount -l $zm_mnt, restart the automount, then run scripts/das-link-recovery-check.sh"
      zm_tripped=1
    fi
  done <<< "$zm_targets"
  if [ "$zm_tripped" -eq 0 ]; then
    "$ZM_PASS" "no zombie mounts — every live /mnt/* mount has an existing device and answers real IO"
  fi
}
