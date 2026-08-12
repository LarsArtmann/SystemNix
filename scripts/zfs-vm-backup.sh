# ZFS Pool Backup — copy ALL data to /data/backup-2026-08-11-private-cloud/
#
# Uses tar over SSH to pull everything from the VM.
# At ~100 MB/s, 20 GB takes ~3-4 min.
set -euo pipefail

VM_PATH="/nix/store/036pkvfsp6q1x0i9cwc34md5q7lmjddz-nixos-vm"
USB_CONTROLLER="0000:c7:00.4"
SSH_PORT=2222
VM_PIDFILE="/tmp/zfs-backup-vm.pid"
VM_LOG="/tmp/zfs-backup-vm.log"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password"
SSHPASS_BIN="/home/lars/.nix-profile/bin/sshpass"
BACKUP_DIR="/data/backup-2026-08-11-private-cloud"

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
    echo "Rebinding USB controller..."
    echo "$USB_CONTROLLER" >/sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    echo "" >/sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override 2>/dev/null || true
    echo "$USB_CONTROLLER" >/sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
    sleep 2
    echo "Controller: $(get_driver "$USB_CONTROLLER")"
  fi
  echo "Done."
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
echo "Driver: $(get_driver "$USB_CONTROLLER")"

# ── Boot VM ──
echo "=== Booting VM ==="
rm -f ./nixos.qcow2 2>/dev/null || true
"$VM_PATH/bin/run-nixos-vm" >"$VM_LOG" 2>&1 &
echo $! >"$VM_PIDFILE"

echo "Waiting for SSH..."
for i in $(seq 1 60); do
  ssh_cmd "echo READY" 2>/dev/null | grep -q READY && break
  kill -0 "$(cat "$VM_PIDFILE")" 2>/dev/null || {
    echo "VM died"
    tail -20 "$VM_LOG"
    exit 1
  }
  sleep 2
done
ssh_cmd "echo READY" 2>/dev/null | grep -q READY || {
  echo "SSH failed"
  tail -20 "$VM_LOG"
  exit 1
}

# ── Import pool & mount everything ──
echo "=== Importing pool ==="
ssh_cmd "zpool import datapool 2>/dev/null || zpool import -f datapool"

echo "=== Mounting all datasets ==="
ssh_cmd bash -s <<'REMOTE'
set -euo pipefail
# Mount all datasets that have real mountpoints
for ds in $(zfs list -H -o name,mountpoint 2>/dev/null | awk '$2 != "legacy" && $2 != "-" && $2 != "none" {print $1}'); do
  zfs mount "$ds" 2>/dev/null || true
done
# Mount legacy datasets
for ds in $(zfs list -H -o name,mountpoint 2>/dev/null | awk '$2 == "legacy" {print $1}'); do
  mnt="/mnt/$ds"
  mkdir -p "$mnt"
  mount -t zfs "$ds" "$mnt" 2>/dev/null || true
done
echo "=== Mounted datasets ==="
zfs list -H -o name,used,mountpoint 2>/dev/null
echo "=== df ==="
df -h /storage 2>/dev/null || true
REMOTE

# ── Create backup dir on host ──
echo ""
echo "=== Creating backup directory: $BACKUP_DIR ==="
mkdir -p "$BACKUP_DIR"

# ── Copy data via tar over SSH (skip Docker layers + ZFS benchmarks) ──
echo "=== Copying data (tar over SSH, excluding Docker + benchmarks)... ==="
echo "Skipping: apps/ (Docker layers), cache benchmark files (zfs_*_test, health_check)"
echo ""

# Copy /storage excluding:
#   apps/         — 3.44 GB Docker image layers (disposable)
#   cache/zfs_*   — ZFS benchmark files (disposable)
#   cache/health* — ZFS health check benchmark (disposable)
echo "--- Copying /storage (minus Docker + benchmarks) ---"
"$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
  "tar cf - -C /storage --exclude='./apps' --exclude='./cache/zfs_*_test*' --exclude='./cache/health_check*' ." |
  tar xvf - -C "$BACKUP_DIR" 2>&1 | tail -10

# Copy legacy-mounted datasets
echo ""
echo "--- Copying legacy datasets ---"
"$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
  'for d in /mnt/datapool/*; do [ -d "$d" ] && echo "$d"; done' 2>/dev/null | while read -r ds_path; do
  ds_name=$(basename "$ds_path")
  echo "  Copying legacy: $ds_name"
  "$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
    "tar cf - -C '$ds_path' ." 2>/dev/null | tar xf - -C "$BACKUP_DIR/legacy-$ds_name" 2>/dev/null || true
  mkdir -p "$BACKUP_DIR/legacy-$ds_name"
done

# ── Verify ──
echo ""
echo "=== Backup verification ==="
echo "Total size:"
du -sh "$BACKUP_DIR"
echo ""
echo "Top-level contents:"
ls -la "$BACKUP_DIR"/
echo ""
echo "Size breakdown:"
du -sh "$BACKUP_DIR"/* 2>/dev/null | sort -rh
echo ""
echo "File count:"
find "$BACKUP_DIR" -type f | wc -l
echo ""
echo "=== Backup complete: $BACKUP_DIR ==="
