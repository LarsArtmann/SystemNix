# 📊 COMPREHENSIVE PROJECT STATUS UPDATE

**Time:** 2025-12-06 01:39
**Current Phase:** Phase 1 (Architecture Consolidation)
**Last Action:** Enabled Home Manager in `flake.nix` for macOS (Lars-MacBook-Air).

---

### a) ✅ FULLY DONE

1. **Root Flake Activation:** The primary `flake.nix` is identified and being actively modified.
2. **Ghost Systems Core:** The complex type safety/assertion framework (`TypeAssertions`, `ConfigAssertions`, `State.nix`) exists and is wired into the flake.
3. **Basic Task Runner:** `justfile` is operational with commands for setup, linking, and switching.
4. **NixOS Core Config (EVO-X2):** Basic `configuration.nix` and `hardware-configuration.nix` exist with Hyprland and AMDGPU support.
5. **macOS Core Config:** nix-darwin inputs and basic system defaults are defined.

### b) 🚧 PARTIALLY DONE

1. **Home Manager Integration:**
   - **macOS:** Enabled in `flake.nix` just now.
   - **NixOS:** _Not yet enabled_ in `flake.nix`.
   - **Config Files:** `dotfiles/nix/home.nix` exists but likely needs updates to accept the new `specialArgs` (Ghost Systems) we just injected.
2. **Hardware Support (EVO-X2):**
   - CPU/GPU: Configured.
   - **WiFi/Audio:** Marked as "Partially Supported" (missing specific firmware/drivers in config).
3. **Package Management:**
   - `common/packages.nix` exists but usage is inconsistent across platforms (Homebrew still heavily used on macOS).

### c) ❌ NOT STARTED

1. **Platform Abstraction Layer:** `core/Platform.nix` logic is documented but not implemented in code.
2. **Unified Home Configuration:** No shared/conditional logic for Home Manager across OSs yet.
3. **Deprecation Fixes:** `services.xserver` warnings in NixOS config have not been addressed.
4. **Physical Deployment:** NixOS has not been flashed to the EVO-X2 hardware.
5. **Cross-Platform Testing:** No automated check to see if configs build on both Darwin and Linux.

### d) 💀 TOTALLY FUCKED UP / HIGH RISK

1. **Ghost Systems Complexity:** We just injected 8+ complex arguments (`TypeAssertions`, `State`, etc.) into Home Manager. If `dotfiles/nix/home.nix` does not have `...` or specific arguments in its header, **the build will fail immediately**.
2. **Split Brain Configuration:** You have `dotfiles/nix/` and `dotfiles/nixos/`. It's unclear which `home.nix` is the source of truth, risking configuration drift between Mac and PC.
3. **NixOS Audio/Network Blindness:** Relying on generic drivers for the EVO-X2's specific chipsets (MT7925, RTL8125BG) will likely result in a system with no internet/audio upon first boot.

### e) 💡 WHAT WE SHOULD IMPROVE

1. **Unified `home.nix`:** Create a single `home.nix` that uses `pkgs.stdenv.isDarwin` checks, rather than maintaining two separate files.
2. **Strict Argument Typing:** Ensure `home.nix` strictly defines inputs to prevent "unexpected argument" errors during flake evaluation.
3. **Hardware Modules:** Extract EVO-X2 specific hardware tweaks into a reusable module rather than hardcoding in `configuration.nix`.

---

### f) 🔥 TOP #25 THINGS WE SHOULD GET DONE NEXT

**CRITICAL (Hours)**

1. [ ] **Verify `home.nix` Header:** Update `dotfiles/nix/home.nix` to accept the new `specialArgs` or the build breaks.
2. [ ] **Enable HM on NixOS:** Mirror the `flake.nix` changes to the `nixosConfigurations."evo-x2"` block.
3. [ ] **Create NixOS `home.nix`:** Create the missing Home Manager config for the NixOS user.
4. [ ] **Test Build (Dry Run):** Run `nix flake check` to verify the new Home Manager wiring.
5. [ ] **Fix Deprecations:** Rename `services.xserver` options in EVO-X2 config.

**HIGH PRIORITY (Days)** 6. [ ] **Implement `Platform.nix`:** Create the abstraction layer for cross-platform package selection. 7. [ ] **Add MT7925 Firmware:** Explicitly add `firmware-linux-nonfree` or specific firmware for WiFi 7. 8. [ ] **Add RTL8125BG Config:** Optimize kernel modules for 2.5G Ethernet. 9. [ ] **Consolidate Packages:** Move all shared CLI tools to `common/packages.nix`. 10. [ ] **Conditional Homebrew:** Wrap Homebrew imports in `if isDarwin` checks. 11. [ ] **Update Justfile:** Add `switch-nixos` and `home-switch` commands. 12. [ ] **Hyprland Hardening:** Ensure Hyprland config works with the specific GPU drivers.

**MEDIUM PRIORITY (Weeks)** 13. [ ] **Audio Config:** Implement Pipewire low-latency config for EVO-X2. 14. [ ] **Thunderbolt Security:** Configure `bolt` or `plasma-thunderbolt` (if using DE) for device trust. 15. [ ] **Power Profiles:** Install `auto-cpufreq` or `tlp` optimized for Ryzen AI Max+. 16. [ ] **Secure Boot:** Investigate `lanzaboote` for NixOS Secure Boot. 17. [ ] **Secrets Management:** Integrate `sops-nix` for handling SSH keys/tokens. 18. [ ] **Backup System:** Configure `restic` or `borg` via Nix. 19. [ ] **Bootloader Styling:** Theme `systemd-boot` or switch to `grub` if dual-booting. 20. [ ] **Shell Performance:** Run benchmarks on both systems.

**LOW PRIORITY** 21. [ ] **Gaming Optimization:** `gamemode` and Steam tweaks. 22. [ ] **RGB Control:** OpenRGB configuration for EVO-X2 chassis. 23. [ ] **Remote Access:** Tailscale declarative configuration. 24. [ ] **Documentation:** Update README with new install instructions. 25. [ ] **Wallpaper Management:** "Ghost Wallpaper" integration.

---

### g) ❓ TOP #1 QUESTION I CAN NOT FIGURE OUT MYSELF

**Do you want a SINGLE unified `home.nix` file with `if/else` logic for macOS/NixOS, OR do you want to keep them as two separate files (`dotfiles/nix/home.nix` vs `dotfiles/nixos/home.nix`) to minimize complexity?**
(I will assume **Unified** based on your "100% managed" vision, but this is the biggest architectural pivot point right now.)
