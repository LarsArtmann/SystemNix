# ZFS Deep Dive — inspect specific non-Docker datasets
set -euo pipefail

VM_PATH="/nix/store/036pkvfsp6q1x0i9cwc34md5q7lmjddz-nixos-vm"
USB_CONTROLLER="0000:c7:00.4"
SSH_PORT=2222
VM_PIDFILE="/tmp/zfs-deep-vm.pid"
VM_LOG="/tmp/zfs-deep-vm.log"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password"

SSHPASS_BIN="/home/lars/.nix-profile/bin/sshpass"
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
    echo "Rebinding USB controller..."
    echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    echo "" > /sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override 2>/dev/null || true
    echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
  fi
  echo "Done."
}
trap cleanup EXIT

# ── VFIO Setup ──
echo "=== VFIO Setup ==="
lsmod | grep -q vfio_pci || modprobe vfio-pci
[ "$(get_driver "$USB_CONTROLLER")" = "xhci_hcd" ] && {
  echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 1; }
[ "$(get_driver "$USB_CONTROLLER")" != "vfio-pci" ] && {
  echo "vfio-pci" > /sys/bus/pci/devices/"$USB_CONTROLLER"/driver_override
  echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/vfio-pci/bind; sleep 1; }
echo "Driver: $(get_driver "$USB_CONTROLLER")"

# ── Boot VM ──
echo "=== Booting VM ==="
rm -f ./nixos.qcow2 2>/dev/null || true
"$VM_PATH/bin/run-nixos-vm" > "$VM_LOG" 2>&1 &
echo $! > "$VM_PIDFILE"

echo "Waiting for SSH..."
for i in $(seq 1 60); do
  ssh_cmd "echo READY" 2>/dev/null | grep -q READY && break
  kill -0 "$(cat "$VM_PIDFILE")" 2>/dev/null || { echo "VM died"; tail -20 "$VM_LOG"; exit 1; }
  sleep 2
done
ssh_cmd "echo READY" 2>/dev/null | grep -q READY || { echo "SSH failed"; tail -20 "$VM_LOG"; exit 1; }

# ── Deep Dive ──
echo "=== Importing pool ==="
ssh_cmd "zpool import datapool 2>/dev/null || zpool import -f datapool"

echo ""
echo "=== DEEP DIVE: Non-Docker datasets ==="
ssh_cmd bash -s <<'REMOTE'
set -euo pipefail

for ds in \
  datapool/cache \
  datapool/config \
  datapool/databases \
  datapool/documents \
  datapool/documents/general \
  datapool/documents/paperless \
  datapool/media \
  datapool/media/general \
  datapool/media/photos \
  datapool/backups \
  datapool/logs \
  datapool/dev \
  datapool/apps/volumes \
  datapool/apps/containers \
  datapool/apps/images
do
  mp=$(zfs get -H -o value mountpoint "$ds" 2>/dev/null || echo "legacy")
  echo ""
  echo "============================================"
  echo "DATASET: $ds"
  echo "MOUNTPOINT: $mp"
  echo "REFER: $(zfs get -H -o value refer "$ds" 2>/dev/null)"
  echo "USED: $(zfs get -H -o value used "$ds" 2>/dev/null)"
  echo "============================================"

  # Mount if legacy
  if [ "$mp" = "legacy" ]; then
    mnt="/mnt/$ds"
    mkdir -p "$mnt"
    mount -t zfs "$ds" "$mnt" 2>/dev/null || true
    dir="$mnt"
  else
    dir="$mp"
  fi

  if [ -d "$dir" ]; then
    echo "--- ls -la ---"
    ls -la "$dir"/ 2>/dev/null | head -30
    echo ""
    echo "--- du -sh (top items) ---"
    du -sh "$dir"/* 2>/dev/null | sort -rh | head -20
    echo ""
    echo "--- find (all files, max depth 3) ---"
    find "$dir" -maxdepth 3 -type f -exec ls -lh {} \; 2>/dev/null | head -50
    echo ""
    echo "--- File count ---"
    find "$dir" -type f 2>/dev/null | wc -l
  else
    echo "(directory not accessible)"
  fi
done

echo ""
echo "=== CACHE BREAKDOWN (3.76 GB — where is it?) ==="
cache_dir="/storage/cache"
if [ -d "$cache_dir" ]; then
  echo "--- Top-level dirs by size ---"
  du -sh "$cache_dir"/* 2>/dev/null | sort -rh | head -30
  echo ""
  echo "--- All files > 10MB ---"
  find "$cache_dir" -type f -size +10M -exec ls -lh {} \; 2>/dev/null | head -30
  echo ""
  echo "--- File extensions ---"
  find "$cache_dir" -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
fi
REMOTE

echo ""
echo "Deep dive complete."
