# NixOS Configuration Audit — evo-x2

**Date:** 2026-04-03
**Machine:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395, 128GB RAM, NixOS 26.05)
**Compositor:** Niri (Wayland), Waybar, Rofi, Kitty, SDDM
**Theme:** Catppuccin Mocha throughout

---

## Session Changes (Committed)

| Commit    | Change                                                                                |
| --------- | ------------------------------------------------------------------------------------- |
| `be6a9b5` | Reddit DNS blocking via unbound `always_nxdomain` (`extraDomains` wired up in module) |

## Session Changes (Uncommitted — ready to apply)

| File                        | Change                                                                                                                                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `programs/niri-wrapped.nix` | Clipboard: `Mod+C` → `Alt+C`; floating position fix (float 0.25/0.15 + `relative-to`); `default-width` → `default-column-width`; `default-height` → `default-window-height`; `Mod+Z`/`Mod+Shift+Z` for Zed |
| `users/home.nix`            | `pavucontrol` → `pwvucontrol`; GTK4 theme enabled (`gtk4.theme.name`); extracted `gtkThemeName` let binding                                                                                                |
| `desktop/waybar.nix`        | Audio on-click: `pavucontrol` → `pwvucontrol`                                                                                                                                                              |
| `programs/rofi.nix`         | Removed invalid `x-offset`, `y-offset`, `enabled` from window block; all `@color / X%` replaced with ARGB hex                                                                                              |

**Next step:** `nh os switch .` then verify rofi, Blueman theme, pwvucontrol.

---

## Audit Findings

### HIGH — Bugs & Conflicts

| #   | Issue                                   | File                                  | Detail                                                                                                                      |
| --- | --------------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Duplicate notification daemons**      | `desktop/multi-wm.nix:48`             | `mako` installed alongside `dunst` (fully configured in `home.nix:221`). Two daemons race for notifications. Remove `mako`. |
| 2   | **`wofi` unmaintained**                 | `desktop/multi-wm.nix:14,35`          | Unmaintained since 2022, known Wayland bugs. `rofi` already used everywhere else. Remove `wofi`.                            |
| 3   | **`nvtopPackages.amd` twice**           | `monitoring.nix:5` + `amd-gpu.nix:54` | Same package installed in two places. Remove from `monitoring.nix`.                                                         |
| 4   | **`kitty` redundant in packages**       | `users/home.nix:124`                  | `programs.kitty.enable = true` already installs kitty. Remove from `home.packages`.                                         |
| 5   | **Wrong WorkingDirectory**              | `system/scheduled-tasks.nix:50`       | Points to `/home/lars/Setup-Mac` (old macOS path). Should be `/home/lars/projects/SystemNix`.                               |
| 6   | **`tesseract4` outdated**               | `desktop/ai-stack.nix:59`             | `tesseract5` has significantly better accuracy. Update.                                                                     |
| 7   | **Duplicate xkb config**                | `desktop/multi-wm.nix:20-28`          | `xkb.layout = "us"` already set in `display-manager.nix`. Remove from `multi-wm.nix`.                                       |
| 8   | **Firewall port 22 open, SSH disabled** | `system/networking.nix:12`            | `allowedTCPPorts` includes `22` but SSH service is not enabled. Remove.                                                     |
| 9   | **`bash.initExtra` deprecated**         | `programs/shells.nix:68`              | Deprecated in Home Manager 26.05. Use `bash.initContent`.                                                                   |

### MEDIUM — AI Workstation Tuning

| #   | Issue                                | File                                    | Detail                                                                                                                                                   |
| --- | ------------------------------------ | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 10  | **Missing `vm.overcommit_memory=1`** | `system/boot.nix`                       | Without this, mmap'd AI models (llama.cpp, PyTorch) can get OOM-killed on large loads.                                                                   |
| 11  | **ZRAM swap unconfigured**           | `system/boot.nix`                       | Defaults to 50% of 128GB = 64GB compressed swap. Set `memoryPercent = 25`, `algorithm = "zstd"`.                                                         |
| 12  | **No `systemd.oomd`**                | —                                       | No OOM protection. Critical for AI workloads that can consume all 128GB. Add `systemd.oomd.enable = true`.                                               |
| 13  | **Missing kernel hardening sysctls** | `system/boot.nix`                       | Missing: `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`, `kernel.unprivileged_bpf_disabled=1`, `kernel.yama.ptrace_scope=2`, `kernel.kexec_load=0`. |
| 14  | **GPU device mode `0666`**           | `hardware/amd-gpu.nix:38-39`            | `/dev/kfd` and `/dev/drm` world-readable/writable. Change to `0660` with `GROUP="render"` (user already in render group).                                |
| 15  | **`iotop` deprecated**               | `desktop/security-hardening.nix:107`    | Requires `NET_ADMIN` on modern kernels. Replace with `iotop-c`.                                                                                          |
| 16  | **`wireshark-cli` redundant**        | `desktop/security-hardening.nix:96,130` | `wireshark` package includes CLI tools. Remove `wireshark-cli`.                                                                                          |
| 17  | **Qt `gtk2` platform theme legacy**  | `users/home.nix:214`                    | `qt.platformTheme.name = "gtk2"` is outdated. Consider `"qt5ct"` or `"kde"`.                                                                             |
| 18  | **`fail2ban` enabled, SSH disabled** | `desktop/security-hardening.nix`        | Monitors a service that doesn't exist. Disable or remove.                                                                                                |
| 19  | **`swayidle` spawned manually**      | `programs/niri-wrapped.nix:24-38`       | Niri has native `idle` config key. Manual swayidle spawn in `spawn-at-startup` could be replaced with niri's built-in idle hooks.                        |
| 20  | **Missing `HSA_ENABLE_SDMA=0`**      | `desktop/ai-stack.nix`                  | Some ROCm workloads on gfx11 need this to avoid SDMA engine bugs.                                                                                        |
| 21  | **Missing journald size limits**     | —                                       | No `SystemMaxUse` configured. Journal can fill `/var`. Add `services.journald.extraConfig = "SystemMaxUse=500M"`.                                        |

### LOW — Polish & Optimization

| #   | Issue                                | File                                          | Detail                                                                                                  |
| --- | ------------------------------------ | --------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 22  | **VSync forced**                     | `hardware/amd-gpu.nix:24`                     | `MESA_VK_WSI_PRESENT_MODE = "fifo"` adds latency. `"mailbox"` gives lower latency with minimal tearing. |
| 23  | **GPU locked at max clocks**         | `hardware/amd-gpu.nix:42`                     | `power_dpm_force_performance_level = "high"` always. `"auto"` for desktop, `"high"` for AI workloads.   |
| 24  | **No initrd systemd**                | `system/boot.nix`                             | `boot.initrd.systemd.enable = true` enables faster, parallelized boot (supported since 24.05).          |
| 25  | **Timer missing `AccuracySec`**      | `system/scheduled-tasks.nix`                  | `OnCalendar = "00:00"` without `AccuracySec`. Add `AccuracySec = "1h"` to batch timer wakeups.          |
| 26  | **`colorScheme` double-defined**     | `system/configuration.nix:49,63`              | Defined both in `options` (with default) and `config`. Option default already covers it.                |
| 27  | **Missing `vm.page-cluster` tuning** | `system/boot.nix`                             | Default 3 causes excessive swap readahead on 128GB. Set to 2.                                           |
| 28  | **`ollama` package redundant**       | `desktop/ai-stack.nix:55`                     | Both `ollama` (CPU) and `ollama-rocm` (service) installed. CPU package is redundant.                    |
| 29  | **`swaylock-effects` duplicate**     | `multi-wm.nix:39` + `programs/swaylock.nix:4` | Installed system-wide and via Home Manager. Redundant.                                                  |
| 30  | **Missing `OMP_NUM_THREADS`**        | `desktop/ai-stack.nix`                        | No OpenMP/BLAS thread control for AI workloads.                                                         |

---

## Open Issues (Pre-existing)

- **Stale IP `.161` on eno1** — Likely leftover DHCP lease from router. Reboot or release from router admin panel.
- **Photomap container health check failing** — Pre-existing podman issue on startup.

---

## Recommended Execution Order

1. Apply pending changes: `nh os switch .`
2. Verify: rofi opens, Blueman themed, pwvucontrol launches from waybar
3. Commit all remaining changes
4. Apply HIGH fixes (#1–9) — low risk, immediate value
5. Apply MEDIUM tuning (#10–21) — requires `nh os switch` and reboot for sysctls
6. Apply LOW polish (#22–30) — discretionary
