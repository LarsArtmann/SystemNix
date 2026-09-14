# 🚨 SYSTEM STATUS REPORT: Unified Deployment Architecture

**Date:** December 6, 2025
**Timestamp:** 04:42
**Target Systems:** MacBook Air M2 (`Lars-MacBook-Air`) & GMKtec EVO-X2 (`evo-x2`)
**Architecture:** Unified Nix Flake + 3-Tier Home Manager + Ghost Systems

---

## a) ✅ FULLY DONE (Architectural Wins)

1. **Unified Flake Architecture**: Single `flake.nix` managing both macOS (Darwin) and Linux (NixOS) targets with shared inputs.
2. **3-Tier Home Manager**: Successfully implemented `common/home.nix` (Base), `nix/home.nix` (Darwin), and `nixos/home.nix` (Linux) to share 90% of config while allowing OS-specific overrides.
3. **EVO-X2 Hardware Config**: Kernel upgraded to `linuxPackages_latest` (6.12+) to support Ryzen AI Max+; WiFi 7 (`mt7925e`) and 2.5G Ethernet (`r8125`) modules defined.
4. **Ghost Systems Integration (Phase 1)**: TypeAssertions, State, and ConfigAssertions successfully injected via `specialArgs` into both systems.
5. **Installation Documentation**: Comprehensive `docs/evo-x2-install-guide.md` created for bootstrapping the new machine.
6. **Version State**: System state version bumped to `25.11` (future-proofing).
7. **Git Hygiene**: All changes committed, clean tree, pre-commit hooks passing.
8. **Remote Access Prep**: `openssh` enabled on NixOS target.

## b) 🚧 PARTIALLY DONE (In Progress)

1. **NixOS GUI Config**: Hyprland/Wayland enabled, but **unconfigured** (default config). No `hyprland.conf`, `waybar` config, or keybindings defined yet.
2. **Monitoring Stack**: Netdata/ntopng exist for macOS but haven't been ported/tested on the NixOS configuration yet.
3. **Shell Performance**: Fish is configured, but performance benchmarking (Ghost Systems feature) needs validation on the AMD hardware.
4. **Hardware Acceleration**: AMDGPU drivers enabled, but ROCm/OpenCL for AI workloads is not yet configured.

## c) 🛑 NOT STARTED (Pending)

1. **Physical Deployment**: The code has not touched the EVO-X2 hardware yet.
2. **AI Stack Implementation**: Installing LocalAI/Ollama/Torch with specific Zen 5 / RDNA 3.5 optimizations.
3. **VPN/Mesh Networking**: Tailscale setup for secure cross-device communication.
4. **Automated Backups**: No backup strategy defined for the NixOS node.
5. **Secure Boot**: Not configured (standard for NixOS, but risky for physical security).

## d) 💥 TOTALLY FUCKED UP (Critical Technical Debt)

1. **Secret Management (The "Manual" Hole)**: We are currently relying on `passwd` commands and manual entry. **This violates the Declarative Principle.** We have `sops-nix` dependencies but no implementation. If the machine dies, you lose access logic.
2. **Treefmt Disabled**: The global formatter is commented out in `flake.nix`. Code style is currently unenforceable via CI/Flake.
3. **"Blind" Driver Support**: We are assuming `linuxPackages_latest` covers the MT7925e WiFi 7 card. If it requires proprietary firmware not in `linux-firmware`, the install will fail hard, and we have no fallback USB WiFi plan.

## e) 🔧 WHAT WE SHOULD IMPROVE

1. **Implement SOPS-Nix immediately**: Encrypt secrets (WiFi passwords, user hashes) in the repo using Age keys.
2. **Modularize NixOS Config**: `configuration.nix` is becoming a monolith. Split into `desktop.nix`, `network.nix`, `ai-hardware.nix`.
3. **Ghost Systems Expansion**: Use the assertion framework to block the build if `sops` files are missing (safety check).
4. **Automated Rice**: Port your macOS aesthetics (fonts, colors) to Hyprland so the Linux box looks like _your_ machine instantly.

---

## f) 📋 TOP 25 THINGS TO GET DONE NEXT

**Deployment & Connectivity**

1. [ ] **DEPLOY**: Flash USB, boot EVO-X2, run install (The Moment of Truth).
2. [ ] **Verify Network**: Confirm WiFi 7 and 2.5G Ethernet link negotiation.
3. [ ] **Setup Tailscale**: Link EVO-X2 to your personal mesh for SSH without local IP reliance.
4. [ ] **Fix Secrets**: Initialize `sops-nix`, generate Age keys, move passwords to code.

**AI & Hardware Performance** 5. [ ] **ROCm Setup**: Configure AMD Compute stack for the Ryzen AI Max+. 6. [ ] **NPU Verification**: Check if the NPU is visible/usable (requires specialized kernel flags or firmware). 7. [ ] **Benchmarks**: Run `geekbench` or `sysbench` to baseline the new hardware. 8. [ ] **Storage Optimization**: Tune NVMe scheduler and mount options for performance.

**Desktop Experience (NixOS)** 9. [ ] **Hyprland Config**: Create `dotfiles/nixos/hyprland/default.nix`. 10. [ ] **Waybar**: configure status bar (CPU, RAM, Net, Time). 11. [ ] **Wofi/Rofi**: Theme the launcher to match system style. 12. [ ] **Fonts**: Install NerdFonts (JetBrains Mono) globally. 13. [ ] **Display Manager**: Style GDM or switch to `sddm` (better Wayland support). 14. [ ] **Audio**: Verify Pipewire/Wireplumber routing and latency. 15. [ ] **Bluetooth**: Verify controller functionality and pairing.

**Dev Environment** 16. [ ] **Restore Treefmt**: Uncomment and fix the formatter configuration. 17. [ ] **Ghost Systems Phase 2**: Implement hardware capability assertions. 18. [ ] **Sync SSH Keys**: Ensure GitHub access works from EVO-X2. 19. [ ] **Port Aliases**: Ensure `common/home.nix` aliases work in Fish on Linux. 20. [ ] **Docker/Podman**: Configure container runtime with GPU passthrough.

**Maintenance & Polish** 21. [ ] **Auto-Upgrade**: Configure `system.autoUpgrade` (optional but good for unstable). 22. [ ] **Garbage Collection**: Tune GC settings for the 1TB drive. 23. [ ] **Power Management**: TLP or `auto-cpufreq` tuning (Ryzen runs hot/fast). 24. [ ] **Boot Theme**: Grub/Systemd-boot theming. 25. [ ] **Documentation**: Update README with actual "post-install" findings.

---

## g) ❓ TOP #1 QUESTION

**"Will the 'linuxPackages_latest' (Kernel 6.12.x) actually successfully initialize the NPU (Neural Processing Unit) on the Ryzen AI Max+ 395, or is that silicon currently dead weight on Linux until AMD releases specific XDNA drivers?"**
_(Risk: We might have a powerful CPU/GPU but a dormant NPU for several months.)_
