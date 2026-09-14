# Installation Guide for GMKtec EVO-X2 (NixOS)

This guide describes how to install the `evo-x2` NixOS configuration onto the GMKtec EVO-X2 Mini PC.

## Prerequisites

1. **USB Stick**: Minimum 4GB.
2. **NixOS ISO**: **CRITICAL**: Use the [Latest Unstable GNOME ISO](https://channels.nixos.org/nixos-unstable/latest-nixos-gnome-x86_64-linux.iso).
   - **Why?** The EVO-X2 requires a very recent Linux kernel (6.10+) for WiFi/Ethernet support. Stable 24.05 (Kernel 6.6) may NOT work.
3. **Network**: Wired Ethernet (preferred) or WiFi credentials.

## Step 1: Create Bootable USB

On your macOS machine:

```bash
# List disks to find your USB drive (e.g., /dev/disk4)
diskutil list

# Unmount the disk
diskutil unmountDisk /dev/diskN

# Write the ISO (replace N with disk number, use rdisk for speed)
sudo dd if=path/to/nixos.iso of=/dev/rdiskN bs=4m status=progress
```

## Step 2: Boot the EVO-X2

1. Insert USB stick.
2. Power on and press **F7** (or Del/Esc) to enter Boot Menu/BIOS.
3. Select the USB partition.
4. Boot into "NixOS Installer" (Default).

## Step 3: Partitioning

We follow the layout defined in `hardware-configuration.nix`:

- Label `boot`: FAT32, EFI System Partition
- Label `nixos`: Ext4, Root Partition

Open a terminal on the EVO-X2:

```bash
# Find your drive (likely /dev/nvme0n1)
lsblk

# Partition using parted (WARNING: ERASES ALL DATA)
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart primary ext4 512MB 100%

# Format partitions with labels
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2

# Mount partitions
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

## Step 4: Copy Configuration

Since this repository is private/local, we will copy it from your Mac via SSH.

**On EVO-X2 (Live ISO):**

```bash
# Set a password for the 'nixos' user to allow SSH
sudo passwd nixos
# (Enter a temporary password like 'root')

# Get IP address
ip addr show
# (Look for inet address, e.g., 192.168.1.X)
```

**On macOS (Your current machine):**

```bash
# Navigate to repo root
cd ~/projects/SystemNix

# Copy files to the mounted /mnt/etc/nixos on EVO-X2
# Replace <IP> with the address found above
scp -r . nixos@<IP>:/mnt/etc/nixos
```

## Step 5: Install

**On EVO-X2 (Live ISO):**

```bash
# Enter the configuration directory
cd /mnt/etc/nixos

# Run the install
# --no-root-passwd avoids setting a root password (we use sudo)
sudo nixos-install --flake .#evo-x2

# CRITICAL: Set the password for user 'lars' before rebooting
sudo nixos-enter --root /mnt -c 'passwd lars'
```

## Step 6: Reboot

```bash
sudo reboot
```

Remove the USB stick. The system should boot into NixOS (Console or GNOME Login).

## Post-Install Verification

1. **WiFi 7**: `ip link` should show `wlan0` (mt7925e driver).
2. **Ethernet**: `ip link` should show `enp...` (r8125 driver).
3. **Graphics**: `radeontop` (if installed) or `glxinfo` should show AMD Radeon graphics.
