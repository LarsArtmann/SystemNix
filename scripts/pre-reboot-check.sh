#!/usr/bin/env bash
# Pre-reboot verification: statically audits the ENTIRE boot chain so a planned
# reboot cannot hit what the 2026-09-07 stuck boot hit (loader default pointing
# at a generation whose init existed only on the retired QLC store), nor the
# 2026-09-05 near-miss (activation exit-4 skipped the profile/bootloader write).
#
# Boot chain audited: loader.conf default -> entry file -> kernel+initrd on the
# ESP -> init path on the LIVE store -> profile anchoring -> initrd-required
# devices present -> btrfs health -> no zombie mounts -> quiet-window advisories.
#
# Run: nix run .#pre-reboot-check   (self-elevates to root; /boot is root-only)
# Exit: 0 = safe to reboot (warnings allowed), 1 = REBOOT BLOCKED (fix first).
set -euo pipefail

# Test hook: point BOOT_DIR at a fixture to negative-test the audit logic
# (must survive the sudo re-exec, hence re-materialized here).
BOOT_DIR="${BOOT_DIR:-/boot}"

# /boot and /nix/var/nix/profiles are root-only on this box; re-exec once.
# NOTE: a nix-store sudo can never be setuid (read-only store) — the real one
# is NixOS's security wrapper, addressed by absolute path because the packaged
# app's PATH excludes it (live failure 2026-09-07: "must be owned by uid 0").
if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "✗ this audit needs root (reads /boot) and no sudo was found"
    exit 1
  fi
  exec "$SUDO" env BOOT_DIR="$BOOT_DIR" bash "$0" "$@"
fi

PASS=0
FAIL=0
WARN=0

pass() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}
fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
}
warn() {
  echo "  ⚠ $1"
  WARN=$((WARN + 1))
}

# Resolve a kernel/initrd line ("/EFI/nixos/...") against the ESP mount.
efi_path() { printf '%s%s' "$BOOT_DIR" "$1"; }

echo "=== Pre-Reboot Boot-Chain Verification ==="
echo ""

# 1. Loader default entry (the thing the machine will ACTUALLY boot)
echo "1. Loader default entry"
DEFAULT_ENTRY=""
LOADER_CONF="$BOOT_DIR/loader/loader.conf"
if [ ! -f "$LOADER_CONF" ]; then
  fail "missing $LOADER_CONF — bootloader config unreadable"
elif [ ! -d "$BOOT_DIR/loader/entries" ]; then
  fail "missing $BOOT_DIR/loader/entries/"
else
  DEFAULT_ENTRY="$(awk '$1 == "default" { print $2; exit }' "$LOADER_CONF" || true)"
  if [ -z "$DEFAULT_ENTRY" ]; then
    warn "loader.conf has no 'default' line — systemd-boot will pick by sort-key; auditing ALL entries strictly"
  elif [ ! -f "$BOOT_DIR/loader/entries/$DEFAULT_ENTRY" ]; then
    fail "default entry file missing: $DEFAULT_ENTRY"
    DEFAULT_ENTRY=""
  else
    pass "default entry present: $DEFAULT_ENTRY"
  fi
fi

# 2. Default entry: kernel + initrd on the ESP, init on the LIVE store.
#    The 2026-09-07 stuck boot passed every earlier stage and died exactly here:
#    init= existed on the old store while the flipped fstab mounts /nix from
#    the new one. File existence on the live store is the authoritative check —
#    entry titles and generation numbers LIE across a store swap.
echo ""
echo "2. Default entry boot assets"
ENTRY_VERSION=""
DEFAULT_INIT=""
if [ -n "$DEFAULT_ENTRY" ]; then
  E="$BOOT_DIR/loader/entries/$DEFAULT_ENTRY"
  ENTRY_VERSION="$(awk '/^version /{ $1=""; sub(/^ /,""); print; exit }' "$E" || true)"
  [ -n "$ENTRY_VERSION" ] && echo "  booting: $ENTRY_VERSION"

  KLINE="$(awk '$1 == "linux" { print $2; exit }' "$E" || true)"
  ILINE="$(awk '$1 == "initrd" { print $2; exit }' "$E" || true)"
  DEFAULT_INIT="$(grep -ao 'init=[^ ]*' "$E" | head -1 | cut -d= -f2- || true)"

  if [ -n "$KLINE" ] && [ -f "$(efi_path "$KLINE")" ]; then
    pass "kernel on ESP: $KLINE"
  else
    fail "kernel missing on ESP: ${KLINE:-<no linux line>}"
  fi
  if [ -n "$ILINE" ] && [ -f "$(efi_path "$ILINE")" ]; then
    pass "initrd on ESP: $ILINE"
  else
    fail "initrd missing on ESP: ${ILINE:-<no initrd line>}"
  fi

  if [ -n "$DEFAULT_INIT" ] && [ -x "$DEFAULT_INIT" ]; then
    pass "init exists on live store: $DEFAULT_INIT"
  elif [ -n "$DEFAULT_INIT" ]; then
    fail "init NOT on live store: $DEFAULT_INIT (stale entry across a store swap? this is the 2026-09-07 stuck-boot class)"
  else
    fail "default entry has no init= line"
  fi
fi

# 3. Whole menu audit — emergency menu picks must never land on a landmine.
#    Missing init on the DEFAULT is fatal (above); missing on rollback entries
#    only degrades the fallback ladder (normal after GC prunes old generations).
echo ""
echo "3. Boot menu audit"
ENTRY_COUNT=0
DEAD_ENTRIES=0
for E in "$BOOT_DIR"/loader/entries/nixos-*.conf; do
  [ -f "$E" ] || continue
  ENTRY_COUNT=$((ENTRY_COUNT + 1))
  INIT="$(grep -ao 'init=[^ ]*' "$E" | head -1 | cut -d= -f2- || true)"
  if [ -z "$INIT" ] || [ ! -e "$INIT" ]; then
    DEAD_ENTRIES=$((DEAD_ENTRIES + 1))
    warn "unbootable menu entry: $(basename "$E") -> ${INIT:-<no init=>}"
  fi
done
if [ "$ENTRY_COUNT" -eq 0 ]; then
  fail "no boot entries found"
else
  if [ "$DEAD_ENTRIES" -eq 0 ]; then
    pass "all $ENTRY_COUNT menu entries bootable from the live store"
  else
    warn "$DEAD_ENTRIES of $ENTRY_COUNT entries unbootable (rollback ladder degraded; default is what matters)"
  fi
fi

# 4. Profile anchoring — the 2026-09-05/09-07 exit-4 class: nh can activate a
#    config but SKIP the numbered-profile bump, so the next reboot silently
#    reverts. Entry wins for THIS boot; profile mismatch is a warn because it
#    is expected after any deploy that has not rebooted yet.
echo ""
echo "4. Profile anchoring"
PROFILE_TARGET="$(readlink -f /nix/var/nix/profiles/system 2>/dev/null || true)"
CURRENT_TARGET="$(readlink -f /run/current-system 2>/dev/null || true)"
if [ -z "$PROFILE_TARGET" ] || [ ! -d "$PROFILE_TARGET" ]; then
  fail "system profile broken: /nix/var/nix/profiles/system -> ${PROFILE_TARGET:-unresolvable}"
else
  pass "system profile resolves: $(basename "$PROFILE_TARGET")"
  if [ -n "$CURRENT_TARGET" ] && [ "$PROFILE_TARGET" != "$CURRENT_TARGET" ]; then
    warn "profile != running system — reboot will boot the PROFILE generation. Expected after a fresh deploy; UNEXPECTED after a deploy that exit-4'd (deploy.sh anchoring warning) — re-run nix run .#deploy"
  else
    pass "profile anchored to running system"
  fi
fi

# 5. Store/DB consistency of the running closure (catches store drift and a
#    wedged nix-daemon before they surprise the boot-time store population).
echo ""
echo "5. Nix store closure sanity"
if nix path-info -r /run/current-system >/dev/null 2>&1; then
  pass "closure of /run/current-system resolves in the store DB"
else
  fail "nix path-info -r /run/current-system failed — store/DB drift or daemon wedged (restart nix-daemon)"
fi

# 6. Initrd-required devices present NOW. Every fstab mount flagged
#    x-initrd.mount is mounted by stage 1 before journald exists; a device
#    missing right now (cable, enclosure, enumeration) means the reboot hangs
#    in the initrd with zero journal artifacts.
echo ""
echo "6. Initrd-required devices"
INITRD_DEVS=0
while read -r SPEC MOUNTPOINT _; do
  [ -n "$SPEC" ] || continue
  INITRD_DEVS=$((INITRD_DEVS + 1))
  RESOLVED=""
  case "$SPEC" in
  /dev/disk/by-label/* | /dev/disk/by-uuid/* | /dev/*)
    [ -e "$SPEC" ] && RESOLVED="$SPEC"
    ;;
  LABEL=* | UUID=*)
    KIND="${SPEC%%=*}"
    VAL="${SPEC#*=}"
    [ -e "/dev/disk/by-${KIND,,}/${VAL}" ] && RESOLVED="/dev/disk/by-${KIND,,}/${VAL}"
    ;;
  esac
  if [ -n "$RESOLVED" ]; then
    pass "$MOUNTPOINT <- $RESOLVED"
  else
    fail "$MOUNTPOINT device missing right now: $SPEC (stage 1 will wait on this and hang pre-journald)"
  fi
done < <(awk '$0 !~ /^[[:space:]]*#/ && /x-initrd\.mount/ { print $1, $2 }' /etc/fstab 2>/dev/null || true)
[ "$INITRD_DEVS" -gt 0 ] || warn "no x-initrd.mount entries found in /etc/fstab — unexpected for this host (root+ /nix should be initrd-mounted)"

if findmnt -n / >/dev/null 2>&1; then pass "root filesystem mounted"; else fail "root filesystem not mounted"; fi
if findmnt -n "$BOOT_DIR" >/dev/null 2>&1; then pass "ESP mounted at $BOOT_DIR"; else fail "ESP not mounted at $BOOT_DIR"; fi

# 7. BTRFS member health — a MISSING device in any filesystem turns the next
#    mount into a degraded refusal (pool policy: never auto-degraded).
echo ""
echo "7. BTRFS device health"
MISSING_DEVS="$(btrfs filesystem show 2>/dev/null | grep -c 'MISSING' || true)"
if [ "${MISSING_DEVS:-0}" -eq 0 ]; then
  pass "no MISSING btrfs devices"
else
  fail "$MISSING_DEVS btrfs device slot(s) MISSING — mounts may refuse or run degraded"
fi

# 8. Zombie mounts (stale mountinfo after USB flaps answers stat with EIO; a
#    clean shutdown then hangs, which LOOKS like a stuck boot next morning).
echo ""
echo "8. Zombie mount probe"
ZOMBIE=0
while read -r TARGET FSTYPE; do
  case "$FSTYPE" in
  tmpfs | proc | sysfs | devtmpfs | devpts | cgroup* | efivarfs | bpf | fuse* | securityfs | debugfs | tracefs | configfs | pstore | mqueue | hugetlbfs | ramfs | overlay | autofs | binfmt* | nsfs | rpc_pipefs | squashfs | erofs | iso9660) continue ;;
  esac
  if ! timeout 5 stat -f "$TARGET" >/dev/null 2>&1; then
    warn "mount not answering stat: $TARGET ($FSTYPE) — possible zombie (buildcache-class stale mountinfo)"
    ZOMBIE=$((ZOMBIE + 1))
  fi
done < <(findmnt -rn -o TARGET,FSTYPE 2>/dev/null || true)
[ "$ZOMBIE" -eq 0 ] && pass "all real mounts answer stat"

# 9. Quiet-window advisories (never block a reboot, but say why you might wait)
echo ""
echo "9. Quiet-window advisories"
FAILED_UNITS="$(systemctl --failed --no-legend --plain 2>/dev/null | grep -c . || true)"
if [ "${FAILED_UNITS:-0}" -eq 0 ]; then
  pass "no failed units"
else
  warn "$FAILED_UNITS failed unit(s) — harmless for boot, but they arm the NEXT deploy's exit-4 profile-skip"
fi
for UNIT in btrbk-root.service btrbk-data.service btrbk-pool.service nix-gc.service; do
  if systemctl is-active --quiet "$UNIT" 2>/dev/null; then
    warn "$UNIT is running right now — let it finish (interrupted sends/GC recover, but noisily)"
  fi
done
echo "  (none listed above = quiet window)"

echo ""
echo "=== Summary: $PASS passed, $WARN warnings, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "❌ REBOOT BLOCKED — fix the ✗ items above first"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "⚠ SAFE TO REBOOT with notes above"
else
  echo "✅ SAFE TO REBOOT"
fi
echo "If it still hangs: PHOTO the last console line (pre-journald hangs leave zero artifacts),"
echo "wait 15 min before calling it stuck, and do not pick menu entries — the default is the verified one."
