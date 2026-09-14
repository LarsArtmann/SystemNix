# Status Report: Evo-X2 NixOS Rescue & Partition Fix

**Date:** 2025-12-07 11:15
**System:** Evo-X2 (NixOS)
**Author:** Crush AI

## 🚨 Critical Incident: "No space left on device"

**Issue:**
The `nixos-rebuild switch` failed because the EFI partition (`/boot`) was full. This partition was likely created by the factory Windows installation (approx 100MB) and could not hold multiple NixOS kernel generations.

**Resolution:**
The user manually intervened to resize the disk layout:

- **Root Partition (`/`):** Resized/Shrunk to 1TB.
- **Boot Partition (`/boot`):** Expanded from ~100MB to **4GB**.
- **Filesystem Change:** Switched Root from `ext4` to **`btrfs`**.
- **Addressing:** Switched from Label-based (`nixos`, `boot`) to **UUID-based** mounting.

## 🛠️ Configuration Recovery

The `hardware-configuration.nix` was regenerated, which stripped critical manual overrides. We have successfully patched the file to restore functionality.

### 1. Driver Restoration

The following kernel modules were re-injected to ensure network connectivity on the Ryzen AI Max+ platform:

- `r8125`: Realtek 2.5GbE Ethernet driver.
- `mt7925e`: MediaTek WiFi 7 driver.
- `kvm-amd`: Virtualization support.

### 2. Filesystem Optimization

Applied best-practice mount options for the new Btrfs root:

- `compress=zstd`: Transparent compression (saves space, increases read speed on NVMe).
- `noatime`: Disables access time writes (reduces SSD wear, improves perf).
- `subvol=@`: Maintained standard subvolume layout.

### 3. Firmware

- Re-enabled `hardware.enableRedistributableFirmware = true` (Required for WiFi/Bluetooth blobs).

## ⚠️ Current Risks & Action Items

### Risk 1: Configuration Sync ("Split Brain")

- **State:** The corrected config is on the Mac. The NixOS machine must pull these changes before rebuilding.
- **Impact:** If `nixos-rebuild` runs on the generated config without our patches, **Network drivers will be lost** on reboot.
- **Action:** `git pull` on Evo-X2 immediately.

### Risk 2: UUID Mismatch

- **State:** We are trusting the UUIDs provided by the user/regenerated file (`0b629...` / `80A3...`).
- **Action:** Verify with `lsblk -f` on target machine before rebooting.

### Risk 3: Bootloader Garbage Collection

- **State:** User declined `configurationLimit`.
- **Mitigation:** The 4GB partition provides ample space, but manual `nix-collect-garbage` will be required eventually to prevent future "No space left" errors.

## 📋 Next Steps (Immediate)

1. **Sync:** Push changes from Mac -> Pull on Evo-X2.
2. **Verify:** Check UUIDs match hardware.
3. **Apply:** Run `sudo nixos-rebuild switch --flake .#evo-x2`.
4. **Reboot:** Confirm network connectivity and boot success.

## 🔮 Future Improvements

1. **Disko:** Implement declarative partitioning to avoid manual `gparted` work.
2. **Subvolumes:** Refactor Btrfs to use `@home`, `@nix`, `@log` separation for atomic rollbacks.
3. **Security:** Implement `sops-nix` for secret management.
