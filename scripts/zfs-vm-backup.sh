# ZFS Pool Backup — copy non-Docker data to /data/backup-2026-08-11-private-cloud/
#
# Phase 1 (user): Build VM
# Phase 2 (root): VFIO + VM boot + data copy + cleanup
#
# Usage: bash scripts/zfs-vm-backup.sh
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

cd "$PROJECT_DIR"

# ── Phase 1: Build VM as user ────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  echo "=== Phase 1: Building VM (as user) ==="
  VM_PATH="$("$NIX" path-info .#nixosConfigurations.zfs-vm.config.system.build.vm 2>/dev/null || true)"
  if [ -z "$VM_PATH" ] || [ ! -x "$VM_PATH/bin/run-nixos-vm" ]; then
    echo "Building..."
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
  echo ""; echo "=== Cleanup ==="
  if [ -f "$VM_PIDFILE" ]; then
    kill "$(cat "$VM_PIDFILE")" 2>/dev/null || true
    sleep 2; kill -9 "$(cat "$VM_PIDFILE")" 2>/dev/null || true
    rm -f "$VM_PIDFILE"
  fi
  if [ "$(get_driver "$USB_CONTROLLER")" != "xhci_hcd" ]; then
    echo "Rebinding USB controller to xhci_hcd..."
    echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    echo "" > /sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override 2>/dev/null || true
    echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
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
  echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/xhci_hcd/unbind
  sleep 1
fi
if [ "$(get_driver "$USB_CONTROLLER")" != "vfio-pci" ]; then
  echo "vfio-pci" > /sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override
  echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/vfio-pci/bind
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
"$VM_PATH/bin/run-nixos-vm" > "$VM_LOG" 2>&1 &
echo $! > "$VM_PIDFILE"
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

# ── Backup ──
echo ""
echo "=== Creating backup directory ==="
mkdir -p "$BACKUP_DIR"

echo "=== Copying data (excluding Docker layers + ZFS benchmarks) ==="
echo "Skipping: apps/ (Docker layers), cache/zfs_*_test*, cache/health_check*"
echo ""

"$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
  "tar cf - -C /storage --exclude='./apps' --exclude='./cache/zfs_*_test*' --exclude='./cache/health_check*' ." \
  | tar xvf - -C "$BACKUP_DIR" 2>&1 | grep -v '^$' || true

echo ""
echo "=== Copying legacy datasets ==="
LEGACY_DS="$("$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
  'zfs list -H -o name,mountpoint 2>/dev/null | awk "\$2==\"legacy\"{print \$1}"' 2>/dev/null || true)"
for ds in $LEGACY_DS; do
  ds_clean=$(echo "$ds" | tr '/' '_')
  mnt="/mnt/$ds"
  echo "  Copying legacy: $ds"
  mkdir -p "$BACKUP_DIR/legacy-$ds_clean"
  "$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost \
    "tar cf - -C '$mnt' ." 2>/dev/null | tar xf - -C "$BACKUP_DIR/legacy-$ds_clean" 2>/dev/null || true
done

# ── Verify ──
echo ""
echo "=========================================="
echo "=== BACKUP VERIFICATION ==="
echo "=========================================="
echo ""
echo "Total backup size:"
du -sh "$BACKUP_DIR"
echo ""
echo "All files:"
find "$BACKUP_DIR" -type f -exec ls -lh {} \; 2>/dev/null
echo ""
echo "Directory sizes:"
du -sh "$BACKUP_DIR"/*/ 2>/dev/null | sort -rh
echo ""
echo "Total file count:"
find "$BACKUP_DIR" -type f 2>/dev/null | wc -l
echo ""
echo "=== BACKUP COMPLETE: $BACKUP_DIR ==="
