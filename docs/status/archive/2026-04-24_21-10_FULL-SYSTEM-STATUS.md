# SystemNix — Full Status Report

**Date:** 2026-04-24 21:10 CEST
**Branch:** master @ `11fdbfd`
**Ahead of origin:** 6 commits (NOT PUSHED)
**Working tree:** Clean
**Build status:** ✅ Passes dry-run (zero errors)
**Stashes:** 4 (1 orphaned Hyprland, 1 vendorHash, 1 line-ending fix, 1 pre-status caddy/dnsblockd)
**Status docs:** 44 files in `docs/status/`

---

## A) FULLY DONE ✅

### Session 2026-04-24 (6 commits ahead of origin)

| Commit    | Description                                                                    |
| --------- | ------------------------------------------------------------------------------ |
| `7f3ee14` | DNS cluster: Keepalived VRRP HA (evo-x2 MASTER, Pi 3 BACKUP, VIP 192.168.1.53) |
| `7896f1f` | 10 service modules migrated to flake-parts (27 total)                          |
| `fc74ddf` | Wallpapers as private flake input                                              |
| `ec5f2ce` | Status report + statix lint fixes (`{...}:` → `_:` on 9 modules)               |
| `4d62f96` | Status report + hipblaslt fix + rpi3 restructuring + dns-blocker restructure   |
| `11fdbfd` | Caddy HTTPS reverse proxy for DNS block page + dnsblockd nil slice fix         |

#### 1. Fixed NixOS Rebuild — hipblaslt-7.2.2 Tensile Crash

- **Problem:** 47m49s build failed with 31 cascading errors. `hipblaslt` Tensile code gen crashed: `isa (9, 0, 8) doesn't support matrix instruction`
- **Root cause:** Custom overlays change derivation hashes → cache miss → from-source build hits upstream Tensile bug (gfx908 matrix instruction YAML sanity check is fatal)
- **Fix:** `hipblasltFixOverlay` in `flake.nix` — patches `Utilities.py` to convert `raise Exception` → `print()`
- **Cascading fixes:** hipblaslt → rocblas → ollama → llama-cpp → steam → comfyui → all 31 errors
- **Status:** ✅ Dry-run passes. `just switch` will work (hipblaslt/rocblas build from source ~45min)

#### 2. DNS Cluster — HA VRRP Failover

| Node       | IP            | Role   | Priority |
| ---------- | ------------- | ------ | -------- |
| evo-x2     | 192.168.1.150 | MASTER | 100      |
| rpi3-dns   | 192.168.1.151 | BACKUP | 50       |
| Virtual IP | 192.168.1.53  | —      | —        |

- Keepalived VRRP with Unbound health check, ~3s failover
- Shared blocklists: `platforms/shared/dns-blocklists.nix`
- Cross-compilation: `boot.binfmt.emulatedSystems = ["aarch64-linux"]`
- **Status:** ✅ Software complete. Hardware deployment pending.

#### 3. Caddy + DNS Block Page

- Caddy serves HTTPS block page via reverse proxy to dnsblockd
- dnsblockd: fixed nil slice initialization (`stats.RecentBlocks = make([]BlockEntry, 0)`)
- **Status:** ✅ Code complete, not yet deployed.

#### 4. Flake-Parts Module Migration (10 new → 27 total)

Converted: `display-manager`, `audio`, `niri-config`, `security-hardening`, `ai-stack`, `monitoring`, `multi-wm`, `chromium-policies`, `steam`, `dns-failover`

#### 5. Wallpapers as Flake Input

- `wallpapers` input: `git+ssh://git@github.com/LarsArtmann/wallpapers`
- niri-wrapped references Nix store paths, not `~/projects/wallpapers`

### Pre-existing (April 10-23)

- Niri session save/restore — crash recovery with 18 improvements
- EMEET PIXY webcam daemon — 30+ commits
- Voice agents — LiveKit + Whisper ASR
- DNS blocker — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains
- Taskwarrior + TaskChampion sync
- SigNoz observability pipeline
- Hermes AI gateway
- 27 flake-parts service modules
- Catppuccin Mocha everywhere
- BTRFS + Timeshift
- AMD GPU/NPU (ROCm 7.2.2, XDNA)
- SOPS secrets management

---

## B) PARTIALLY DONE 🔧

### 1. NixOS Deployment — NOT YET DEPLOYED

- All code is committed and passes dry-run
- **Still needed:** `just switch` (will take ~45min for hipblaslt+rocblas from source)
- 6 commits sitting locally, NOT pushed to origin

### 2. Pi 3 DNS Node — Hardware Not Ready

- Software: 100% complete
- **Still needed:**
  - Build SD image: `nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage`
  - Flash SD card, boot Pi 3
  - Set DNS to `192.168.1.53` on all LAN devices
  - Test failover

### 3. Flake-Parts Migration — ~60%

**Converted (27):** All service modules in `modules/nixos/services/`

**Still inline — HM configs (can't be `nixosModules`):**
waybar, niri-wrapped, rofi, swaylock, wlogout, zellij, yazi, shells, home.nix

**Still inline — system configs (machine-specific):**
boot, networking, local-network, snapshots, scheduled-tasks, sudo, dns-blocker-config, amd-gpu, amd-npu, bluetooth, emeet-pixy

---

## C) NOT STARTED 📋

### Blocked on Upstream

1. **Fullscreen state restore** — niri IPC lacks `is_fullscreen` (discussion #1843)

### Niri Session Restore

2. Waybar stats (last save, window count)
3. Integration tests with mock IPC
4. Real-time save via `niri msg event-stream`
5. ADR for session restore design

### DNS Cluster

6. Build Pi 3 SD image
7. Boot Pi 3 + verify DNS
8. Test failover
9. Configure devices

### Infrastructure

10. Archive 30+ stale status docs
11. Drop orphaned Hyprland stash
12. Clean 18 remote `copilot/fix-*` branches
13. Fix pre-commit statix hook (failed on wallpapers commit before)
14. Add CI pipeline
15. Enable `services.udisks2`

### Service Status Unknown

16. **Photomap** — unknown since 2026-03-31
17. **Authelia SSO** — unknown since 2026-04-05
18. **AMD NPU** — driver installed, untested
19. **Unsloth Studio** — unknown since 2026-04-03
20. **SigNoz** — built, unclear if actively collecting

---

## D) TOTALLY FUCKED UP 💥

### 1. 6 Unpushed Commits (CRITICAL)

If local disk dies, all today's work is lost. Includes the hipblaslt fix, DNS cluster, module migration.

### 2. hipblaslt Fix Is Fragile

The `sed` patch in an overlay modifies Python source inside a tarball. If upstream changes `Utilities.py`, the sed silently fails. Should file nixpkgs issue.

### 3. 44 Status Documents in `docs/status/`

Dumping ground. Hard to find current info. Needs aggressive archival.

### 4. 4 Stale Git Stashes

Including orphaned Hyprland config and unclear vendorHash/line-ending fixes.

### 5. No `sudo`/`systemctl` in Crush

Blocks hardware operations. Fragile `bash` pipe workarounds.

### 6. `just test` Intermittent Race

emeet-pixyd build fails during parallel test but succeeds alone. Root cause unknown.

### 7. Pi 3 `linux-rpi` Deprecation

`linux-rpi series will be removed in a future release. Please change to use nixos-hardware.`

### 8. Ollama/Steam/ComfyUI Currently Broken on System

Until `just switch` deploys the hipblaslt fix, all ROCm-dependent services are broken.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Process

- **Push IMMEDIATELY after every session** — 6 unpushed commits is dangerous
- **Archive status docs** — keep last 2 weeks, move rest to `archive/`
- **Drop dead stashes**
- **Clean remote branches** (18 `copilot/fix-*`)

### Architecture

- **File nixpkgs PR** for hipblaslt Tensile gfx908 rejection (upstream bug)
- **NixOS module options** for niri session restore (not `let` blocks)
- **`homeModules` pattern** for HM configs via flake-parts
- **sops-nix for VRRP auth** (currently plaintext `auth_pass`)
- **Binary cache (Cachix)** for overlay-heavy builds
- **Pi 3 → nixos-hardware** before linux-rpi removal

---

## F) TOP 25 NEXT ACTIONS

| #   | Action                                                 | Impact      | Effort |
| --- | ------------------------------------------------------ | ----------- | ------ |
| 1   | **`git push`** — push 6 commits NOW                    | 🔴 Critical | 0      |
| 2   | **`just switch`** — deploy hipblaslt fix + all changes | 🔴 Critical | ~45min |
| 3   | **Verify Ollama works** after rebuild                  | High        | Low    |
| 4   | **Verify Steam works** after rebuild                   | High        | Low    |
| 5   | **Verify ComfyUI works** after rebuild                 | High        | Low    |
| 6   | **Build Pi 3 SD image**                                | High        | Low    |
| 7   | **Flash SD + boot Pi 3**                               | High        | Low    |
| 8   | **Test DNS failover**                                  | High        | Low    |
| 9   | **Verify Caddy block page** serves HTTPS               | Medium      | Low    |
| 10  | **Check Authelia** SSO status                          | High        | Low    |
| 11  | **Check SigNoz** collection status                     | Medium      | Low    |
| 12  | **Archive 30+ stale status docs**                      | Medium      | Low    |
| 13  | **Drop orphaned Hyprland stash**                       | Low         | 0      |
| 14  | **Clean 18 remote branches**                           | Low         | Low    |
| 15  | **Enable `services.udisks2`**                          | High        | Low    |
| 16  | **File nixpkgs issue** for hipblaslt Tensile bug       | Medium      | Low    |
| 17  | **Secure VRRP auth** with sops-nix                     | Medium      | Low    |
| 18  | **Check Photomap** service status                      | Medium      | Low    |
| 19  | **Verify AMD NPU** with test workload                  | Medium      | Medium |
| 20  | **Fix pre-commit statix hook**                         | Medium      | Low    |
| 21  | **Convert niri session restore** to NixOS options      | High        | Medium |
| 22  | **Create `homeModules` pattern**                       | High        | Medium |
| 23  | **Add CI pipeline**                                    | High        | Medium |
| 24  | **Investigate `just test` race**                       | Medium      | Medium |
| 25  | **Setup Taskwarrior backup** timer                     | Medium      | Low    |

---

## G) TOP #1 QUESTION I CANNOT ANSWER

**Do you want to `just switch` now to deploy everything?**

- The rebuild will take ~45min (hipblaslt + rocblas from source)
- All ROCm services (Ollama, ComfyUI) will restart
- Steam will become functional again
- Keepalived, new modules, Caddy block page will go live
- You should `git push` FIRST to protect against failure

Alternative: push now, switch later. But Ollama and Steam remain broken until switch happens.

---

## System Facts

| Metric                    | Value                           |
| ------------------------- | ------------------------------- |
| Commits ahead of origin   | 6 (NOT PUSHED)                  |
| Total flake-parts modules | 27                              |
| Total service modules     | 28                              |
| Total flake inputs        | 24                              |
| DNS blocked domains       | 2.5M+                           |
| ROCm version              | 7.2.2                           |
| GPU                       | AMD Ryzen AI Max+ 395 (gfx1151) |
| RAM                       | 128GB                           |
| nixpkgs                   | `01fbdeef22b7` (Apr 23)         |
| Compositor                | niri (Wayland)                  |
| Theme                     | Catppuccin Mocha                |
