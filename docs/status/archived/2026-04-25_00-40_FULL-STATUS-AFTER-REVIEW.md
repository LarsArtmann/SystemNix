# SystemNix — Full System Status

**Date:** 2026-04-25 00:40 CEST
**Branch:** master @ `7a7b08b`
**Ahead of origin:** 2 commits (NOT PUSHED) + 12 modified files unstaged + 1 stash
**Working tree:** DIRTY — 12 modified + 1 untracked
**Build status:** ✅ `just test-fast` passes clean
**Stashes:** 1 (this session's WIP)
**Status docs:** 5 active + 242 archived (down from 44 active)

---

## A) FULLY DONE ✅

### This Session (2026-04-24 → 2026-04-25)

#### 1. Full Status Docs Review

- Read all 44 non-archive status docs (2026-04-10 to 2026-04-24) + sampled archive
- Cross-referenced every claim against the actual codebase
- Found 6+ inaccurate factual claims (e.g. "29 modules" — actually 27)
- Found 7 verified security issues still present, 8 confirmed fixed
- Identified 8 recurring action items recommended 10-15x but never executed
- Output: `docs/status/REVIEW_DOCS.md`

#### 2. Status Docs Cleanup (40 files archived)

- Moved 40 redundant docs to `archive/` — kept only 5 with unique value
- Rewrote `docs/status/README.md` from 84 stale lines to 6 accurate ones
- Fixed "29 modules" → "27" in the retained status doc
- Added date + commit context to `debug-map.md`
- Active status docs: **5** (was 44)

#### 3. Git Hygiene

- Dropped 3 stale stashes (orphaned Hyprland, vendorHash, line-endings)
- Deleted 17 stale `copilot/fix-*` remote branches

#### 4. Security Fixes (7 items)

| # | Fix                                                                                                     | File                           |
| - | ------------------------------------------------------------------------------------------------------- | ------------------------------ |
| 1 | Removed dead `ublock-filters.nix` module (disabled, broken timer, no browser integration)               | `home-base.nix` + deleted file |
| 2 | Added full systemd hardening to `gitea-ensure-repos` (was zero directives)                              | `gitea-repos.nix`              |
| 3 | Pinned Voice Agents image `latest` → `1.0.0` (compose + pull service)                                   | `voice-agents.nix`             |
| 4 | Pinned PhotoMap image `latest` → `1.0.0`                                                                | `photomap.nix`                 |
| 5 | Added VRRP authentication to Keepalived + `authPassword` option                                         | `dns-failover.nix`             |
| 6 | Removed dead `appSecretFile`/`pgPasswordFile` let bindings from Twenty CRM                              | `twenty.nix`                   |
| 7 | Removed unused `castlabs-electron`/`cursor` from unfree allowlist; set `allowUnsupportedSystem = false` | `nix-settings.nix`             |

#### 5. Reliability Fixes (6 items)

| # | Fix                                                                                | File                |
| - | ---------------------------------------------------------------------------------- | ------------------- |
| 1 | Added `WatchdogSec=30` + `Restart=on-failure` to Gitea main service                | `gitea.nix`         |
| 2 | Added `Restart=on-failure` + `RestartSec=5` to Authelia                            | `authelia.nix`      |
| 3 | Added `Restart=on-failure` + `RestartSec=5` to TaskChampion                        | `taskchampion.nix`  |
| 4 | Removed `core.pager = "cat"` from git config (was overriding `pager.diff = "bat"`) | `git.nix`           |
| 5 | Enabled `services.udisks2` for auto-mounting USB/SD                                | `configuration.nix` |
| 6 | Made deadnix check strict (`--fail` flag) in flake.nix                             | `flake.nix`         |

#### 6. Code Quality Fixes (5 items)

| # | Fix                                                                                                                              | File               |
| - | -------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 1 | Created `.editorconfig` (2-space, LF, UTF-8, Go=tab)                                                                             | `.editorconfig`    |
| 2 | Removed 7 duplicate git ignore entries (`*.so` 3→1, `target/` 2→1, `*~` 2→1, `*.log` 2→1, `*.out` 2→1, `*.rar` 2→1, `*.zip` 2→1) | `git.nix`          |
| 3 | Made GPG program path cross-platform (`gpg` on darwin, full path on linux)                                                       | `git.nix`          |
| 4 | Removed unused `utils` param from voice-agents                                                                                   | `voice-agents.nix` |
| 5 | Removed dead PIDFile from voice-agents + fixed infinite `TimeoutStartSec=0` → 600                                                | `voice-agents.nix` |

### Pre-existing (Sessions 2026-04-10 to 2026-04-24)

- Niri session save/restore — crash recovery with 18 improvements
- EMEET PIXY webcam daemon — 30+ commits (Go, HID, streaming, hotplug, security)
- DNS blocker — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains
- DNS cluster — Keepalived VRRP HA (evo-x2 MASTER, Pi 3 BACKUP, VIP 192.168.1.53)
- Taskwarrior + TaskChampion sync — zero-setup cross-platform
- SigNoz observability pipeline — node_exporter, cAdvisor, OTLP, journald → ClickHouse
- Hermes AI gateway — Discord bot, cron scheduler, sops secrets
- 27 flake-parts service modules
- Catppuccin Mocha theme everywhere
- BTRFS + Timeshift
- AMD GPU/NPU (ROCm 7.2.2, XDNA)
- SOPS secrets management
- hipblaslt fix overlay for from-source builds
- Wallpapers as flake input
- Cross-platform Home Manager (14 shared program modules)

---

## B) PARTIALLY DONE 🔧

### 1. Taskwarrior Encryption — NOT Moved to sops

- The encryption secret is still `builtins.hashString "sha256" "taskchampion-sync-encryption-systemnix"` (public in repo)
- Added `home.file.".config/taskchampion/encryption_secret".text` as intermediate step
- **Still needed:** Create a proper sops secret, reference it from both platforms
- **Blocker:** Requires sops secret creation + coordination between darwin/nixos home-manager configs

### 2. Docker Image Pinning — Tag-level only (not sha256 digest)

- Voice Agents: `latest` → `1.0.0` (tag, not digest)
- PhotoMap: `latest` → `1.0.0` (tag, not digest)
- **Still needed:** Pull actual images, get sha256 digests, pin to `image@sha256:...`
- TODO comments added in both files with instructions

### 3. VRRP Auth — Has Password, Not sops-managed

- `authPassword` option added with default `"DNSClusterVRRP"`
- **Still needed:** Create sops secret, set `services.dns-failover.authPassword` from sops in configuration.nix

### 4. Flake-Parts Migration — ~60%

- **Converted (27):** All service modules in `modules/nixos/services/`
- **Still inline — HM configs (not convertible to `nixosModules`):**
  waybar, niri-wrapped, rofi, swaylock, wlogout, zellij, yazi, shells, home.nix
- **Still inline — system configs (machine-specific):**
  boot, networking, local-network, snapshots, scheduled-tasks, sudo, dns-blocker-config, amd-gpu, amd-npu, bluetooth, emeet-pixy

### 5. Deadnix Warnings — Strict Flag Added, Warnings Not Fixed

- Added `--fail` flag to deadnix check in flake.nix
- ~33+ deadnix warnings still exist across the codebase (unused params, dead let bindings)
- **Next step:** Fix warnings in batches (4 batches planned in MASTER_TODO_PLAN.md)

---

## C) NOT STARTED 📋

### Blocked on Upstream

1. **Fullscreen state restore** — niri IPC lacks `is_fullscreen` (discussion #1843)

### Niri Session Restore Backlog

2. Waybar stats (last save, window count)
3. Integration tests with mock IPC
4. Real-time save via `niri msg event-stream`
5. ADR for session restore design

### DNS Cluster

6. Build Pi 3 SD image (`nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage`)
7. Boot Pi 3 + verify DNS
8. Test failover (stop Unbound on evo-x2)
9. Configure devices to use `192.168.1.53`

### Infrastructure

10. Add CI pipeline (GitHub Actions — `just test-fast` on push)
11. Add Renovate/Dependabot for automated flake.lock updates
12. Fix pre-commit statix hook (failed on wallpapers commit)
13. Create `homeModules` pattern for HM configs via flake-parts
14. Extract `lib/systemd-harden.nix` shared helper
15. Wire `preferences.nix` to actual GTK/Qt/cursor/font theming
16. Convert niri session restore to NixOS module options
17. Add `options` + `mkIf` to 16 always-on service modules (4 batches)
18. Fix eval smoke tests (remove `|| true`)
19. Write top-level README.md
20. Document DNS cluster in AGENTS.md
21. Write ADR for niri session restore
22. Add GitHub Actions for Go tests (emeet-pixyd, dnsblockd)
23. Setup Taskwarrior backup timer
24. Migrate Pi 3 from deprecated `linux-rpi` to `nixos-hardware`
25. Package ComfyUI as proper Nix derivation

### Service Status Unknown

26. **Photomap** — unknown since 2026-03-31
27. **Authelia SSO** — unknown since 2026-04-05
28. **AMD NPU** — driver installed, untested
29. **Unsloth Studio** — unknown since 2026-04-03
30. **SigNoz** — built, unclear if actively collecting

---

## D) TOTALLY FUCKED UP 💥

### 1. 2+ Unpushed Commits + Dirty Working Tree (CRITICAL)

`7a7b08b` and `76c2416` are local-only. Plus 12 modified files with security/reliability fixes are **not even committed yet**. If the disk dies, everything from the last 48 hours is lost.

### 2. hipblaslt Fix Is Fragile

The `sed` patch in the overlay modifies Python source inside a tarball. If upstream changes `Utilities.py`, the sed silently fails. All ROCm services (Ollama, Steam, ComfyUI) depend on this fix.

### 3. All Changes Are Not Deployed

`just switch` has NOT been run. The system is running pre-hipblaslt-fix code:

- Ollama, Steam, ComfyUI are broken on the live system
- Keepalived, new flake-parts modules, Caddy block page are not live
- The only changes that took effect are from the previous session's commit

### 4. `just test` Race Condition

`emeet-pixyd` nix build can fail during parallel `just test` but succeeds in isolation. Root cause unknown. Not investigated this session.

### 5. Pi 3 `linux-rpi` Deprecation

Build warns: `linux-rpi series will be removed in a future release. Please change to use nixos-hardware.` Will break the Pi 3 build when removed.

### 6. No CI Pipeline

Zero automated checks on push. Broken formatting, dead code, and eval errors can all reach master without detection.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Process

- **Push IMMEDIATELY after every session** — we keep accumulating unpushed work
- **One status doc per session, max 100 lines** — we had 44 redundant docs
- **Use Taskwarrior for action items** — not "Top 25" lists in status docs
- **Archive status docs aggressively** — keep only last 2 weeks active

### Security

- **Move Taskwarrior encryption to sops** — the "encryption" secret is public
- **Pin Docker images to sha256 digests** — tags can be silently overwritten
- **Move VRRP auth_pass to sops** — currently a default string in code
- **File nixpkgs issue for hipblaslt** — the sed patch is a time bomb

### Architecture

- **Create `homeModules` pattern** — 9 HM configs can't be `nixosModules`
- **Extract systemd hardening helper** — 20 lines repeated per service
- **Wire `preferences.nix`** — options exist but nothing consumes them
- **Add `options` + `mkIf` to all modules** — 16 have no enable toggle
- **Binary cache (Cachix)** — overlay-heavy builds cause ROCm cache misses

### Reliability

- **Investigate `just test` race** — intermittent emeet-pixyd failure
- **Fix pre-commit statix hook** — broken since wallpapers commit
- **Fix eval smoke tests** — `|| true` means they never actually fail
- **Pi 3 → nixos-hardware** — fix deprecation before it breaks

---

## F) TOP 25 NEXT ACTIONS

| #  | Action                                                                      | Impact      | Effort |
| -- | --------------------------------------------------------------------------- | ----------- | ------ |
| 1  | **`git commit` + `git push`** — commit this session's 13 fixes and push NOW | 🔴 Critical | 2m     |
| 2  | **`just switch`** — deploy hipblaslt fix + all changes to evo-x2            | 🔴 Critical | 45m+   |
| 3  | **Verify Ollama works** after rebuild                                       | High        | Low    |
| 4  | **Verify Steam works** after rebuild                                        | High        | Low    |
| 5  | **Verify ComfyUI works** after rebuild                                      | High        | Low    |
| 6  | **Verify Caddy HTTPS block page**                                           | Medium      | Low    |
| 7  | **Check Authelia SSO** status                                               | High        | Low    |
| 8  | **Check SigNoz** collection status                                          | Medium      | Low    |
| 9  | **Build Pi 3 SD image**                                                     | High        | Low    |
| 10 | **Pin Docker digests** (pull images, get sha256)                            | Medium      | Low    |
| 11 | **Move Taskwarrior encryption to sops**                                     | 🔴 Security | Medium |
| 12 | **Move VRRP auth to sops**                                                  | Medium      | Low    |
| 13 | **Fix deadnix warnings batch 1** (6 service modules)                        | Medium      | Low    |
| 14 | **Fix deadnix warnings batch 2** (6 more modules)                           | Medium      | Low    |
| 15 | **Fix deadnix warnings batch 3** (5 platform files)                         | Medium      | Low    |
| 16 | **Fix deadnix warnings batch 4** (remaining files)                          | Medium      | Low    |
| 17 | **Add GitHub Actions** (`just test-fast` on push)                           | High        | Low    |
| 18 | **Extract `lib/systemd-harden.nix`** shared helper                          | Medium      | Low    |
| 19 | **Fix pre-commit statix hook**                                              | Medium      | Low    |
| 20 | **Wire `preferences.nix`** to actual GTK/Qt theming                         | High        | Medium |
| 21 | **Convert niri session restore** to NixOS options                           | High        | Medium |
| 22 | **Add `options`+`mkIf` to 16 always-on modules** (4 batches)                | Medium      | Medium |
| 23 | **Create `homeModules` pattern** for HM configs                             | High        | Medium |
| 24 | **File nixpkgs issue** for hipblaslt Tensile gfx908 bug                     | Medium      | Low    |
| 25 | **Setup Taskwarrior backup** timer                                          | Medium      | Low    |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Do you want to `just switch` now?**

The system is running without the hipblaslt fix, meaning Ollama, Steam, and ComfyUI are broken. But:

- The rebuild will take ~45min+ (hipblaslt + rocblas build from source)
- All ROCm services will restart during rebuild
- We should `git commit` + `git push` FIRST to protect against failure
- The Pi 3 isn't running yet, so Keepalived VRRP will add a virtual IP with no backup node

---

## System Facts

| Metric                | Value                           |
| --------------------- | ------------------------------- |
| Total service modules | 27                              |
| Total flake inputs    | 24+                             |
| DNS blocked domains   | 2.5M+                           |
| ROCm version          | 7.2.2                           |
| GPU                   | AMD Ryzen AI Max+ 395 (gfx1151) |
| RAM                   | 128GB                           |
| nixpkgs               | `01fbdeef22b7` (Apr 23)         |
| Compositor            | niri (Wayland)                  |
| Theme                 | Catppuccin Mocha                |
| Active status docs    | 5 (was 44)                      |
| Archived status docs  | 242                             |
| Git stashes           | 1                               |
| Unpushed commits      | 2 + unstaged changes            |
