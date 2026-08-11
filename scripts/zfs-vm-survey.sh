# ZFS Pool Survey Script — VFIO VM approach
#
# Boots a headless NixOS VM (kernel 6.18 + ZFS) with the USB controller
# passed through via VFIO, imports the ZFS pool, lists all data, then
# cleanly shuts down and returns the controller to the host.
#
# Usage:  sudo bash scripts/zfs-vm-survey.sh
#
# Requirements: nix build .#nixosConfigurations.zfs-vm.config.system.build.vm
set -euo pipefail

VM_PATH="/nix/store/036pkvfsp6q1x0i9cwc34md5q7lmjddz-nixos-vm"
USB_CONTROLLER="0000:c7:00.4"
SSH_PORT=2222
VM_PIDFILE="/tmp/zfs-survey-vm.pid"
VM_LOG="/tmp/zfs-survey-vm.log"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password"

# Find sshpass (may not be in PATH under sudo)
SSHPASS_BIN=""
for candidate in "$(command -v sshpass 2>/dev/null)" "/home/lars/.nix-profile/bin/sshpass" "/run/current-system/sw/bin/sshpass"; do
  [ -x "$candidate" ] && SSHPASS_BIN="$candidate" && break
done
if [ -z "$SSHPASS_BIN" ]; then
  echo "sshpass not found — installing via nix..."
  SSHPASS_BIN="$(nix build nixpkgs#sshpass --no-link --print-out-paths)/bin/sshpass"
fi
echo "Using sshpass: $SSHPASS_BIN"

ssh_cmd() {
  "$SSHPASS_BIN" -p zfs ssh $SSH_OPTS -p "$SSH_PORT" root@localhost "$@"
}

# ── Helpers ──────────────────────────────────────────────────────────

cleanup() {
  local exit_code=$?
  echo ""
  echo "=== Cleanup ==="

  # Shut down VM if running
  if [ -f "$VM_PIDFILE" ]; then
    local pid
    pid=$(cat "$VM_PIDFILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "Shutting down VM (PID $pid)..."
      kill "$pid" 2>/dev/null || true
      sleep 3
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$VM_PIDFILE"
  fi

  # Rebind USB controller to host
  if [ -d "/sys/bus/pci/devices/$USB_CONTROLLER" ]; then
    local driver_link
    driver_link=$(readlink -f "/sys/bus/pci/devices/$USB_CONTROLLER/driver" 2>/dev/null || echo "")
    if [ "$driver_link" != "/sys/bus/pci/drivers/xhci_hcd" ]; then
      echo "Rebinding USB controller to xhci_hcd..."
      # Unbind from vfio-pci
      echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
      # Unload vfio-pci override
      echo "152d 0567" > /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true
      # Bind back to xhci_hcd
      echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/xhci_hcd/bind 2>/dev/null || true
      sleep 2
      echo "Controller rebound: $(ls -la /sys/bus/pci/devices/$USB_CONTROLLER/driver 2>/dev/null)"
    else
      echo "Controller already bound to xhci_hcd — good."
    fi
  fi

  echo "Done. Exit code: $exit_code"
}

trap cleanup EXIT

# ── Step 1: Prepare VFIO passthrough ─────────────────────────────────

echo "=== Step 1: VFIO Setup ==="

# Load vfio-pci module
if ! lsmod | grep -q vfio_pci; then
  echo "Loading vfio-pci module..."
  modprobe vfio-pci || {
    echo "ERROR: Cannot load vfio-pci. Check AMD-Vi/IOMMU is enabled in BIOS."
    exit 1
  }
fi

# Unbind USB controller from xhci_hcd
if [ -d "/sys/bus/pci/drivers/xhci_hcd/$USB_CONTROLLER" ]; then
  echo "Unbinding $USB_CONTROLLER from xhci_hcd..."
  echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/xhci_hcd/unbind
  sleep 1
else
  echo "Controller already unbound from xhci_hcd."
fi

# Bind to vfio-pci
if [ ! -d "/sys/bus/pci/drivers/vfio-pci/$USB_CONTROLLER" ]; then
  echo "Binding $USB_CONTROLLER to vfio-pci..."
  echo "152d 0567" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
  echo "$USB_CONTROLLER" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
  sleep 1
fi

# Verify
driver=$(basename "$(readlink -f "/sys/bus/pci/devices/$USB_CONTROLLER/driver" 2>/dev/null)" 2>/dev/null || echo "none")
echo "Controller driver: $driver"
if [ "$driver" != "vfio-pci" ]; then
  echo "ERROR: Controller not bound to vfio-pci (got: $driver)"
  exit 1
fi
echo "VFIO setup OK."

# ── Step 2: Boot VM headless ──────────────────────────────────────────

echo ""
echo "=== Step 2: Booting VM (headless) ==="
echo "VM path: $VM_PATH"

# Remove stale qcow2 from /tmp so we get a clean boot
rm -f ./nixos.qcow2 2>/dev/null || true

# Start VM in background
"$VM_PATH/bin/run-nixos-vm" > "$VM_LOG" 2>&1 &
VM_PID=$!
echo "$VM_PID" > "$VM_PIDFILE"
echo "VM started (PID $VM_PID). Waiting for SSH..."

# Wait for SSH to become available (up to 120s)
for i in $(seq 1 60); do
  if ssh_cmd "echo READY" 2>/dev/null | grep -q READY; then
    echo "SSH available after ${i}x2s."
    break
  fi
  if ! kill -0 "$VM_PID" 2>/dev/null; then
    echo "ERROR: VM process died. Log:"
    tail -30 "$VM_LOG"
    exit 1
  fi
  sleep 2
done

# Final check
if ! ssh_cmd "echo READY" 2>/dev/null | grep -q READY; then
  echo "ERROR: SSH never became available. VM log tail:"
  tail -30 "$VM_LOG"
  exit 1
fi

# ── Step 3: Survey the ZFS pool ───────────────────────────────────────

echo ""
echo "=== Step 3: ZFS Pool Survey ==="

ssh_cmd bash -s <<'REMOTE_SCRIPT'
set -euo pipefail

echo "--- Available pools ---"
zpool import 2>/dev/null || echo "(no pools to import)"

echo ""
echo "--- Importing datapool ---"
zpool import datapool 2>/dev/null || zpool import -f datapool 2>/dev/null || {
  echo "Could not import 'datapool'. Listing all importable pools:"
  zpool import
  echo "Trying to import by pool ID..."
  POOL=$(zpool import 2>/dev/null | grep "^  pool:" | head -1 | awk '{print $2}')
  [ -n "$POOL" ] && zpool import -f "$POOL" || { echo "No pool found."; exit 1; }
}

echo ""
echo "=== POOL STATUS ==="
zpool status

echo ""
echo "=== DATASETS (with sizes) ==="
zfs list -o name,used,avail,refer,mountpoint -r datapool 2>/dev/null || zfs list -o name,used,avail,refer,mountpoint -r "$POOL"

echo ""
echo "=== SNAPSHOTS (count + sample) ==="
SNAPSHOT_COUNT=$(zfs list -t snapshot 2>/dev/null | tail -n +2 | wc -l)
echo "Total snapshots: $SNAPSHOT_COUNT"
echo "First 10 snapshots:"
zfs list -t snapshot 2>/dev/null | head -11

echo ""
echo "=== TOP-LEVEL CONTENTS ==="
# Mount and explore each dataset
for ds in $(zfs list -H -o name 2>/dev/null | tail -n +1); do
  mountpoint=$(zfs get -H -o value mountpoint "$ds" 2>/dev/null)
  if [ "$mountpoint" != "-" ] && [ "$mountpoint" != "none" ] && [ -d "$mountpoint" ]; then
    echo ""
    echo "--- $ds ($mountpoint) ---"
    ls -lah "$mountpoint"/ 2>/dev/null | head -30
    echo ""
    echo "Size breakdown:"
    du -sh "$mountpoint"/* 2>/dev/null | sort -rh | head -20
  fi
done

echo ""
echo "=== ALL FILES > 100MB ==="
find / -xdev -type f -size +100M 2>/dev/null | head -30

echo ""
echo "=== DOCKER IMAGES (if present) ==="
find / -xdev -name "manifest.json" -path "*/docker*" 2>/dev/null | head -10
find / -xdev -name "repositories" -path "*/docker*" 2>/dev/null | head -10

echo ""
echo "=== ANY PHOTOS/DOCS/IMPORTANT DATA ==="
find / -xdev \( -name "*.jpg" -o -name "*.png" -o -name "*.pdf" -o -name "*.docx" \
  -o -name "*.heic" -o -name "*.mov" -o -name "*.mp4" \) 2>/dev/null | head -30

echo ""
echo "=== SURVEY COMPLETE ==="
REMOTE_SCRIPT

echo ""
echo "Survey finished."
