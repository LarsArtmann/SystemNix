# Status Report: Evo-X2 Desktop Transformation & System Hardening

**Date:** 2025-12-07 11:42
**System:** Evo-X2 (NixOS)
**Author:** Crush AI

## 🚀 Accomplishments

### 1. Desktop Experience Overhaul (Hyprland Polish)

We have transitioned from a barebones setup to a polished Wayland desktop environment:

- **Login Manager:** Switched from `GDM` (Heavy/GNOME) to **`SDDM`** (Lightweight/Qt), fully configured for Wayland.
- **Launcher:** Installed **`rofi`** (Wayland-compatible fork merged into main) to replace `wofi`.
- **Status Bar:** Added **`waybar`** for system information and workspace management.
- **Notifications:** Added **`dunst`** for desktop notifications.
- **Typography:** Installed **`jetbrains-mono`** and **`nerd-fonts.jetbrains-mono`** for proper icon support in terminals and bars.

### 2. System Optimization & Hardware Support

- **Bootloader:** Set `boot.loader.systemd-boot.configurationLimit = 20` to prevent the 4GB boot partition from filling up (critical fix).
- **Memory:** Enabled **`zramSwap`** to optimize memory usage, essential for APUs like the Ryzen AI Max+ where RAM is shared as VRAM.
- **GPU Computing:** Enabled **ROCm OpenCL** support (`rocmPackages.clr.icd`) for the RDNA 3.5 iGPU.
- **NPU Status:** Confirmed `amd_xdna` (NPU driver) is **not yet in Nixpkgs**. AI workloads should currently target the GPU via OpenCL/ROCm.

### 3. Shell & Terminal

- **Shell:** Configured **Fish** as the default shell with `starship` prompt integration.
- **Aliases:** Ported essential aliases (`nixup`, `nixbuild`, `l`, `t`) for consistent workflow between macOS and NixOS.

### 4. Security Hardening (SSH)

Implemented a robust SSH configuration:

- **Authentication:** Disabled Password Authentication (`PasswordAuthentication = false`), enforced Public Key Authentication (`PubkeyAuthentication = true`).
- **Access Control:** Restricted access to user `lars` only (`AllowUsers = [ "lars" ]`).
- **Cryptography:** Enforced strict, modern **Ciphers**, **MACs**, and **KexAlgorithms** (removing weak/legacy options).
- **Network:** Disabled tunneling and forwarding (`PermitTunnel = "no"`, `AllowTcpForwarding = false`).
- **Banner:** Added a legal warning banner (`/etc/ssh/banner`).

## ⚠️ Configuration Sync Warning

**CRITICAL:** The configuration on the macOS host (`/Users/larsartmann/Desktop/Setup-Mac`) is now significantly ahead of the `evo-x2` machine.

- **Pending Changes:** Network drivers (r8125/mt7925e), SSH hardening, Desktop environment switch.
- **Action Required:** You **MUST** pull these changes on `evo-x2` before rebuilding. If you rebuild without the network driver fixes committed earlier, you will lose internet access.

## 📋 Next Steps (User Action Required)

1. **Sync & Apply:**

   ```bash
   # On Evo-X2
   git pull
   sudo nixos-rebuild switch --flake .#evo-x2
   ```

2. **SSH Key Setup:**
   - Since password auth is now **DISABLED**, ensure your public key (`id_ed25519.pub`) is added to `dotfiles/nixos/configuration.nix` (lines 130+) **BEFORE** applying, or manually added to `~/.ssh/authorized_keys` on the target machine. Otherwise, you will be locked out of SSH.

3. **Verify Graphics:**
   - Check if OpenCL is working: `clinfo` (might need to add `clinfo` package).
   - Verify Hyprland starts correctly from SDDM.

## 🔮 Future Work

- **NPU Support:** Monitor Nixpkgs for `amd_xdna` driver inclusion (Kernel 6.13+).
- **Secrets:** Implement `sops-nix` to manage the SSH authorized keys and other secrets declaratively instead of hardcoding in `configuration.nix`.
- **Disko:** Migrate to declarative partitioning.
