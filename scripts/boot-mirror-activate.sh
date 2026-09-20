#!/usr/bin/env bash
# Switch the firmware boot chain to the Samsung 2nd-boot-disk ESP.
# Idempotent: ensures an explicit "Linux Boot Manager (Samsung)" EFI boot
# entry exists (loader \EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI on the mirror ESP)
# and orders it FIRST; every existing entry (QLC "Linux Boot Manager" and
# the rest) keeps its relative order as fallback.
#
# Run: nix run .#boot-mirror-activate   (self-elevates to root)
# Rollback: pick the QLC entry in the firmware boot menu (F8/F11/F12), or
# re-run the final efibootmgr -o with the QLC "Linux Boot Manager" id first.
set -euo pipefail

MIRROR="${MIRROR:-/boot-mirror}"
ENTRY_LABEL="Linux Boot Manager (Samsung)"
LOADER_EFI='\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI'

# /boot-mirror is root-only (fmask/dmask 0077) and efibootmgr needs root —
# re-exec once through the NixOS sudo wrapper (pre-reboot-check pattern:
# preserve PATH so runtimeInputs survive sudo's secure_path).
if [ "$(id -u)" -ne 0 ]; then
  SUDO=/run/wrappers/bin/sudo
  [ -x "$SUDO" ] || SUDO="$(command -v sudo || true)"
  if [ -z "$SUDO" ]; then
    echo "✗ this switch needs root (EFI variables + $MIRROR) and no sudo was found"
    exit 1
  fi
  exec "$SUDO" env PATH="$PATH" MIRROR="$MIRROR" bash "$0" "$@"
fi

echo "=== Boot-Mirror Activate (Samsung 2nd boot disk) ==="

# 1. The mirror must be mounted and actually bootable — refuse to reorder
#    firmware onto an unverified ESP (the sync unit's diff gate ran first).
if ! findmnt -n "$MIRROR" >/dev/null 2>&1; then
  echo "✗ $MIRROR is not mounted (Samsung absent?) — nothing to activate"
  exit 1
fi
if ! bootctl --esp-path="$MIRROR" is-installed >/dev/null 2>&1; then
  echo "✗ systemd-boot is not installed on $MIRROR — run boot-mirror-sync first"
  exit 1
fi
SRC="$(findmnt -n -o SOURCE "$MIRROR")"
PARTUUID="$(lsblk -no PARTUUID "$SRC")"
echo "mirror ESP: $SRC (PARTUUID $PARTUUID)"

# 2. Idempotent EFI entry: match on the mirror partition + the systemd-boot
#    loader path, so re-runs never mint duplicates (nvme0/nvme1 flip across
#    boots — always derive disk/partition from the mounted device).
find_mirror_entry() {
  efibootmgr -v 2>/dev/null |
    grep -iF "$PARTUUID" |
    grep -iF 'systemd-bootx64.efi' |
    head -1
}
ENTRY_LINE="$(find_mirror_entry || true)"
if [ -n "$ENTRY_LINE" ]; then
  ENTRY_ID="$(echo "$ENTRY_LINE" | awk '{print $1}' | tr -d '*' | sed 's/^Boot//')"
  echo "EFI entry exists: $ENTRY_LINE"
else
  DISK="/dev/$(lsblk -no PKNAME "$SRC")"
  PART="$(lsblk -no PARTN "$SRC")"
  echo "creating EFI entry on $DISK part $PART: $ENTRY_LABEL $LOADER_EFI"
  efibootmgr --create --disk "$DISK" --part "$PART" --label "$ENTRY_LABEL" --loader "$LOADER_EFI" >/dev/null
  ENTRY_LINE="$(find_mirror_entry || true)"
  [ -n "$ENTRY_LINE" ] || {
    echo "✗ created entry not found afterwards — inspect efibootmgr -v"
    exit 1
  }
  ENTRY_ID="$(echo "$ENTRY_LINE" | awk '{print $1}' | tr -d '*' | sed 's/^Boot//')"
fi

# 3. BootOrder: mirror first, everything else keeps relative order.
CURRENT_ORDER="$(efibootmgr | awk '/^BootOrder:/ {print $2}')"
REST="$(echo "$CURRENT_ORDER" | tr ',' '\n' | grep -vx "$ENTRY_ID" | paste -sd, -)"
NEW_ORDER="$ENTRY_ID${REST:+,$REST}"
efibootmgr --bootorder "$NEW_ORDER" >/dev/null

# 4. Verify the final state — never trust the write alone.
FINAL_ORDER="$(efibootmgr | awk '/^BootOrder:/ {print $2}')"
FIRST="$(echo "$FINAL_ORDER" | cut -d, -f1)"
if [ "$FIRST" != "$ENTRY_ID" ]; then
  echo "✗ BootOrder verification failed: first=$FIRST want=$ENTRY_ID"
  efibootmgr
  exit 1
fi

efibootmgr
echo ""
echo "✓ firmware now boots the Samsung mirror first (entry $ENTRY_ID); QLC entries remain fallbacks"
echo "  next: nix run .#pre-reboot-check  → then reboot"
