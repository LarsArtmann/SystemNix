#!/bin/sh
# Recovers from GPU DRM corruption without rebooting.
# Triggered when niri-drm-healthcheck detects a zombie state.
#
# Steps:
# 1. Stop niri (so it releases DRM master)
# 2. Unbind amdgpu from the PCI device (tears down all DRM state)
# 3. Rebind amdgpu (full driver reinitialization) — with retry
# 4. Wait for DRM device to reappear
# 5. Start niri (re-acquires DRM master)
# 6. If recovery fails, trigger system reboot
#
# Requires: root (PolicyKit or sudo)

set -eu

DRIVER="amdgpu"
MAX_REBIND_ATTEMPTS=3
REBIND_RETRY_DELAY=5

# Auto-detect first AMD GPU PCI address from DRM subsystem
# Falls back to 0000:c5:00.0 (evo-x2 default) if detection fails
detect_gpu_pci() {
  for card in /sys/class/drm/card*/device; do
    if [ -f "$card/vendor" ] && [ "$(cat "$card/vendor")" = "0x1002" ]; then
      basename "$(readlink -f "$card")"
      return 0
    fi
  done
  echo "0000:c5:00.0"
}

GPU_PCI="${GPU_PCI:-$(detect_gpu_pci)}"
DRM_CARD="/sys/class/drm/card1"
UNBIND="/sys/bus/pci/drivers/$DRIVER/unbind"
BIND="/sys/bus/pci/drivers/$DRIVER/bind"

log() { echo "gpu-recovery: $*"; }

reboot_system() {
  log "Triggering system reboot — GPU is unrecoverable."
  systemctl reboot 2>/dev/null || {
    log "reboot failed. MANUAL INTERVENTION REQUIRED."
    exit 1
  }
}

# Verify GPU is still present
if [ ! -d "$DRM_CARD" ]; then
  log "ERROR: $DRM_CARD not found. Aborting."
  reboot_system
fi

log "Stopping niri..."
systemctl --user stop niri.service 2>/dev/null || true
sleep 2

pkill -x niri 2>/dev/null || true
sleep 1

log "Unbinding $DRIVER from $GPU_PCI..."
echo "$GPU_PCI" >"$UNBIND" 2>/dev/null || {
  log "ERROR: unbind failed. Device may be in use."
  reboot_system
}

sleep 2

# Retry rebind — kernel driver may need multiple attempts after corruption
bind_ok=false
for attempt in $(seq 1 "$MAX_REBIND_ATTEMPTS"); do
  log "Rebinding $DRIVER to $GPU_PCI (attempt $attempt/$MAX_REBIND_ATTEMPTS)..."
  if echo "$GPU_PCI" >"$BIND" 2>/dev/null; then
    bind_ok=true
    break
  fi
  log "Rebind attempt $attempt failed."
  if [ "$attempt" -lt "$MAX_REBIND_ATTEMPTS" ]; then
    sleep "$REBIND_RETRY_DELAY"
  fi
done

if [ "$bind_ok" = "false" ]; then
  log "ERROR: all rebind attempts failed."
  reboot_system
fi

# Wait for DRM device to reappear and initialize
log "Waiting for GPU to reinitialize..."
for i in $(seq 1 30); do
  if [ -d "$DRM_CARD" ] && [ -e "$DRM_CARD/device/enable" ]; then
    log "GPU back online after ${i}s."
    break
  fi
  sleep 1
done

if [ ! -d "$DRM_CARD" ]; then
  log "ERROR: GPU did not come back after 30s."
  reboot_system
fi

sleep 2

log "Starting niri..."
systemctl --user start niri.service

sleep 5

# Verify niri is healthy
drm_errors=$(journalctl --user -u niri --no-pager -n 10 --since "5 sec ago" 2>/dev/null |
  grep -cE "Permission denied|DeviceMissing" || true)

if [ "$drm_errors" -ge 5 ]; then
  log "ERROR: niri still has DRM errors after recovery."
  reboot_system
fi

log "GPU recovery successful."
