#!/usr/bin/env bash
# ZFS Pool Backup v2 — copy ONLY real data with SHA256 verification
#
# Excludes:
#   - apps/ (Docker image layers — 3.44 GB disposable)
#   - cache/zfs_* (all ZFS benchmark files: zfs_4k_write.*, zfs_*_test*, etc.)
#   - cache/health_check* (ZFS health benchmark)
#   - cache/{immich,paperless} (stale Redis AOF/RDB from retired Docker deployments)
#   - All legacy datasets under datapool/apps/ (Docker layers)
#
# Includes hash verification: SHA256 manifest generated on source,
# verified on destination after copy.
#
# Usage: bash scripts/zfs-vm-backup.sh
# PERMISSION REQUIRED: Do NOT run without user approval.
set -euo pipefail

PROJECT_DIR="/home/lars/projects/SystemNix"
NIX="/run/current-system/sw/bin/nix"
export USB_CONTROLLER="0000:c7:00.4"
export SSH_PORT=2222
export SSHPASS_BIN="/home/lars/.nix-profile/bin/sshpass"
export BACKUP_DIR="/data/backup-2026-08-11-private-cloud"
export VM_PIDFILE="/tmp/zfs-backup-vm.pid"
export VM_LOG="/tmp/zfs-backup-vm.log"
export SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password"
export MANIFEST="/tmp/zfs-backup-manifest.sha256"
export MANIFEST_DEST="$BACKUP_DIR/.source-manifest.sha256"

cd "$PROJECT_DIR"

# ── Phase 1: Build VM as user ────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  echo "=== Phase 1: Resolving VM build (as user) ==="
  VM_PATH="$("$NIX" path-info .#nixosConfigurations.zfs-vm.config.system.build.vm 2>/dev/null || true)"
  if [ -z "$VM_PATH" ] || [ ! -x "$VM_PATH/bin/run-nixos-vm" ]; then
    echo "Building VM..."
    VM_PATH="$("$NIX" build .#nixosConfigurations.zfs-vm.config.system.build.vm --no-link --print-out-paths 2>&1 | tail -1)"
  fi
  if [ -z "$VM_PATH" ] || [ ! -x "$VM_PATH/bin/run-nixos-vm" ]; then
    echo "ERROR: Cannot resolve VM build: $VM_PATH"
    exit 1
  fi
  echo "VM path: $VM_PATH"
  echo ""
  echo "=== Phase 2: Re-executing as root ==="
  export VM_PATH
  exec sudo -E bash "$0" "$@"
fi

# ── Phase 2: Root operations ─────────────────────────────────────────

ssh_cmd() { "$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost "$@"; }

get_driver() {
  local link="/sys/bus/pci/devices/$1/driver"
  [ -L "$link" ] && basename "$(readlink "$link")" || echo "none"
}

cleanup() {
  echo ""
  echo "=== Cleanup ==="
  if [ -f "$VM_PIDFILE" ]; then
    kill "$(cat "$VM_PIDFILE")" 2>/dev/null || true
    sleep 2
    kill -9 "$(cat "$VM_PIDFILE")" 2>/dev/null || true
    rm -f "$VM_PIDFILE"
  fi
  if [ "$(get_driver "$USB_CONTROLLER")" != "xhci_hcd" ]; then
    echo "Rebinding USB controller to xhci_hcd..."
    echo "$USB_CONTROLLER" >/sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    echo "" >/sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override 2>/dev/null || true
    echo "$USB_CONTROLLER" >/sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
    sleep 2
    echo "Controller: $(get_driver "$USB_CONTROLLER")"
  else
    echo "Controller already on xhci_hcd — good."
  fi
  echo "Cleanup done."
}
trap cleanup EXIT

# ── VFIO Setup ──
echo "=== VFIO Setup ==="
lsmod | grep -q vfio_pci || modprobe vfio-pci
if [ "$(get_driver "$USB_CONTROLLER")" = "xhci_hcd" ]; then
  echo "$USB_CONTROLLER" >/sys/bus/pci/drivers/xhci_hcd/unbind
  sleep 1
fi
if [ "$(get_driver "$USB_CONTROLLER")" != "vfio-pci" ]; then
  echo "vfio-pci" >/sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override
  echo "$USB_CONTROLLER" >/sys/bus/pci/drivers/vfio-pci/bind
  sleep 1
fi
DRIVER="$(get_driver "$USB_CONTROLLER")"
echo "Controller driver: $DRIVER"
if [ "$DRIVER" != "vfio-pci" ]; then
  echo "ERROR: Failed to bind vfio-pci"
  exit 1
fi

# ── Boot VM ──
echo ""
echo "=== Booting VM (headless) ==="
rm -f ./nixos.qcow2 2>/dev/null || true
"$VM_PATH/bin/run-nixos-vm" >"$VM_LOG" 2>&1 &
echo $! >"$VM_PIDFILE"
echo "VM PID: $(cat "$VM_PIDFILE")"

echo "Waiting for SSH (up to 120s)..."
SSH_READY=false
for i in $(seq 1 60); do
  if ssh_cmd "echo READY" 2>/dev/null | grep -q READY; then
    echo "SSH available after $((i * 2))s."
    SSH_READY=true
    break
  fi
  if ! kill -0 "$(cat "$VM_PIDFILE")" 2>/dev/null; then
    echo "ERROR: VM process died. Log tail:"
    tail -30 "$VM_LOG"
    exit 1
  fi
  sleep 2
done
if [ "$SSH_READY" = false ]; then
  echo "ERROR: SSH never became available. Log tail:"
  tail -30 "$VM_LOG"
  exit 1
fi

# ── Import & mount ──
echo ""
echo "=== Importing pool ==="
ssh_cmd "zpool import datapool 2>/dev/null || zpool import -f datapool"

echo "=== Mounting all datasets ==="
ssh_cmd 'for ds in $(zfs list -H -o name,mountpoint 2>/dev/null | awk "\$2 != \"legacy\" && \$2 != \"-\" && \$2 != \"none\" {print \$1}"); do zfs mount "$ds" 2>/dev/null || true; done; for ds in $(zfs list -H -o name,mountpoint 2>/dev/null | awk "\$2 == \"legacy\" {print \$1}"); do mnt="/mnt/$ds"; mkdir -p "$mnt"; mount -t zfs "$ds" "$mnt" 2>/dev/null || true; done; echo "All datasets mounted."'

# ── Generate SHA256 manifest on source ───────────────────────────────
echo ""
echo "=== Generating SHA256 manifest on source ==="
echo "Excluding: apps/, cache/zfs_*, cache/health_check*, cache/{immich,paperless}"

# Generate manifest for /storage (excluding Docker + benchmarks + stale Redis dumps)
ssh_cmd bash -s <<'REMOTE'
set -euo pipefail

# /storage manifest — exclude Docker layers, ZFS benchmarks, and stale Redis state
find /storage \
  -not -path '/storage/apps/*' \
  -not -path '/storage/apps' \
  -not -path '/storage/cache/immich*' \
  -not -path '/storage/cache/paperless*' \
  -not -name 'zfs_*' \
  -not -name 'health_check*' \
  -type f -exec sha256sum {} + 2>/dev/null | \
  sed 's|/storage/||' > /tmp/source-manifest.sha256

# Legacy datasets — ONLY datapool root (documents/ + media/), NOT apps/
# datapool root is mounted at /mnt/datapool and contains documents/ and media/ dirs
# datapool/apps/<hash> are all Docker layers — SKIP
find /mnt/datapool \
  -not -path '/mnt/datapool/apps/*' \
  -not -path '/mnt/datapool/apps' \
  -type f -exec sha256sum {} + 2>/dev/null | \
  sed 's|/mnt/datapool/|legacy/|' >> /tmp/source-manifest.sha256

echo "Manifest entries: $(wc -l < /tmp/source-manifest.sha256)"
echo "Manifest preview:"
head -20 /tmp/source-manifest.sha256
REMOTE

# Pull manifest to host
echo ""
echo "=== Pulling manifest to host ==="
ssh_cmd "cat /tmp/source-manifest.sha256" >"$MANIFEST"
echo "Manifest entries: $(wc -l <"$MANIFEST")"

# ── Clear old backup and create fresh dir ────────────────────────────
echo ""
echo "=== Preparing backup directory ==="
echo "Clearing old backup at $BACKUP_DIR..."
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# ── Copy /storage (excluding Docker + benchmarks) ────────────────────
echo ""
echo "=== Copying /storage (excluding Docker layers + ZFS benchmarks) ==="

"$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
  "tar cf - -C /storage --exclude='./apps' --exclude='./cache/zfs_*' --exclude='./cache/health_check*' --exclude='./cache/immich' --exclude='./cache/paperless' ." |
  tar xvf - -C "$BACKUP_DIR" 2>&1 | grep -v '^$' || true

# ── Copy legacy datasets (ONLY datapool root — documents/ + media/) ──
echo ""
echo "=== Copying legacy: datapool root (documents/ + media/ only) ==="
mkdir -p "$BACKUP_DIR/legacy"

"$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
  "tar cf - -C /mnt/datapool --exclude='./apps' ." |
  tar xvf - -C "$BACKUP_DIR/legacy" 2>&1 | grep -v '^$' || true

# ── Save manifest to backup dir ──────────────────────────────────────
cp "$MANIFEST" "$MANIFEST_DEST"

# ── Verify: generate dest manifest and compare ───────────────────────
echo ""
echo "=========================================="
echo "=== SHA256 VERIFICATION ==="
echo "=========================================="
echo ""
echo "Source manifest entries: $(wc -l <"$MANIFEST")"
echo ""

# Generate destination manifest in the same format
echo "Generating destination manifest..."
pushd "$BACKUP_DIR" >/dev/null
find . -type f -not -name '.source-manifest.sha256' -exec sha256sum {} + 2>/dev/null |
  sed 's| \./| |' | sort >/tmp/dest-manifest.sha256
popd >/dev/null

# Normalize source manifest for comparison
# Source format (already from find+sed): <hash>  <relative-path>     for /storage/*
#                                        <hash>  legacy/<relative>   for /mnt/datapool/*
# Dest format (after tar -C + sed):   <hash>  <relative-path>     for /storage
#                                        <hash>  legacy/<relative>   for legacy/
# Identical — no normalization needed. Source normalize is a no-op kept for clarity.

# Normalize source: strip /storage/ prefix and legacy/ prefix (already absent)
sort "$MANIFEST" | sed -e 's|  /storage/|  |' -e 's|  legacy/|  |' >/tmp/source-manifest-normalized.sha256

# Normalize dest: strip leading ./
sort /tmp/dest-manifest.sha256 | sed 's|  \./|  |' >/tmp/dest-manifest-normalized.sha256

echo "Source files (normalized): $(wc -l </tmp/source-manifest-normalized.sha256)"
echo "Dest files (normalized):   $(wc -l </tmp/dest-manifest-normalized.sha256)"
echo ""

# Compare
DIFF_OUTPUT="$(diff /tmp/source-manifest-normalized.sha256 /tmp/dest-manifest-normalized.sha256 2>&1 || true)"

if [ -z "$DIFF_OUTPUT" ]; then
  echo "✅ ALL FILES VERIFIED — SHA256 hashes match"
else
  echo "❌ VERIFICATION FAILED — mismatches found:"
  echo "$DIFF_OUTPUT" | head -30
  echo ""
  ONLY_SRC=$(comm -23 /tmp/source-manifest-normalized.sha256 /tmp/dest-manifest-normalized.sha256 | wc -l)
  ONLY_DST=$(comm -13 /tmp/source-manifest-normalized.sha256 /tmp/dest-manifest-normalized.sha256 | wc -l)
  MATCHED=$(comm -12 /tmp/source-manifest-normalized.sha256 /tmp/dest-manifest-normalized.sha256 | wc -l)
  echo "Files in source but not in dest (missing): $ONLY_SRC"
  echo "Files in dest but not in source (extra):   $ONLY_DST"
  echo "Files with matching hashes (verified):     $MATCHED"
fi

# ── Final summary ────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "=== BACKUP SUMMARY ==="
echo "=========================================="
echo ""
echo "Location: $BACKUP_DIR"
echo "Total size:"
du -sh "$BACKUP_DIR"
echo ""
echo "All files:"
find "$BACKUP_DIR" -type f -not -name '.source-manifest.sha256' -exec ls -lh {} \; 2>/dev/null
echo ""
echo "Directory tree:"
find "$BACKUP_DIR" -type d | sort
echo ""
echo "Total file count (excluding manifest):"
find "$BACKUP_DIR" -type f -not -name '.source-manifest.sha256' | wc -l
echo ""
echo "Manifest saved at: $MANIFEST_DEST"
echo ""
echo "=== BACKUP COMPLETE ==="
