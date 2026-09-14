# NixOS evo-x2 Improvement Ideas

Generated: 2026-03-29

---

## Security

### 1. Enable NixOS firewall (deny-by-default)

No `networking.firewall` configured. NixOS defaults to allowing all inbound. Only Caddy and SSH explicitly open ports, but Docker punches its own holes.

**File:** `platforms/nixos/system/networking.nix`
**Effort:** ~20 lines

### 2. Bind Immich to localhost only

Immich is on `0.0.0.0` with `openFirewall = true`, exposing it on all interfaces. Should be `host = "127.0.0.1"` since Caddy reverse-proxies it.

**File:** `platforms/nixos/services/immich.nix:13`
**Effort:** 2 lines

### 3. Enable fail2ban for SSH

SSH port 22 is open (`ssh.nix:59`) but `fail2ban.enable = false` (`security-hardening.nix:60`). No brute-force protection.

**File:** `platforms/nixos/desktop/security-hardening.nix:60`
**Effort:** 1 line

### 4. Remove legacy ssh-rsa from accepted algorithms

`PubkeyAcceptedAlgorithms` includes `ssh-rsa` (SHA-1 based). Weakens SSH posture for macOS client compatibility.

**File:** `platforms/nixos/services/ssh.nix:16`
**Effort:** 1 line

---

## Reliability & Backups

### 5. Immich media has zero backup

Only the PostgreSQL DB is backed up daily. The actual photos/videos in `/var/lib/immich` have no backup strategy. Highest data-loss risk.

**Effort:** ~30 lines (restic/borg timer to external storage)

### 6. Add off-disk backup with restic or borg

All backups (Immich DB, Gitea dump, BTRFS snapshots) are on the same disk. No NAS, S3, or external storage target. Disk failure = total loss.

**Effort:** ~40 lines

### 7. Add automatic Nix garbage collection

`nix.gc` is completely absent. Store grows unbounded. Comment in `nix-settings.nix:34` says "handled via systemd timers" but no timers exist.

**File:** `platforms/nixos/system/scheduled-tasks.nix` or `platforms/common/core/nix-settings.nix`
**Effort:** 5 lines

### 8. Add systemd restart policies to services

No custom restart config for: caddy, gitea, immich-server, immich-machine-learning, postgresql, ollama. Only dnsblockd has `Restart = "on-failure"`.

**Effort:** ~15 lines across service files

---

## Performance & Hardware

### 9. Remove `processor.max_cstate=1` kernel param

Disables CPU deep sleep states, preventing power saving. High power consumption and heat for a workstation, not a latency-critical server.

**File:** `platforms/nixos/system/boot.nix:19`
**Effort:** 1 line

### 10. Enable Immich GPU acceleration

`accelerationDevices = null` explicitly disables GPU ML inference. Should use AMD GPU via ROCm for face detection and Smart Search.

**File:** `platforms/nixos/services/immich.nix:16`
**Effort:** 3-5 lines

### 11. Add `amdgpu` to initrd kernel modules

Empty `boot.initrd.kernelModules = []` in hardware-configuration.nix. `amdgpu` should be in initrd for early KMS/display, especially with encrypted root + display manager.

**File:** `platforms/nixos/hardware/hardware-configuration.nix:17`
**Effort:** 1 line

### 12. Enable SSD TRIM

No `services.fstrim.enable = true`. NVMe/SATA SSDs benefit from periodic TRIM for performance and longevity.

**File:** `platforms/nixos/system/configuration.nix` (new import or inline)
**Effort:** 1 line

### 13. Tune PostgreSQL for photo library workload

PostgreSQL is co-located with Immich but has no tuning: `shared_buffers`, `work_mem`, `effective_cache_size` all at defaults. Photo library queries are heavy.

**File:** `platforms/nixos/services/immich.nix` or a new `platforms/nixos/services/postgresql.nix`
**Effort:** ~10 lines

---

## Monitoring

### 14. Enable SMART disk health monitoring

No `services.smartd.enable = true`. NVMe failures happen silently. Should alert on wear level, temperature, reallocated sectors.

**Effort:** 3 lines

### 15. Add disk space alerts

No monitoring for disk usage. BTRFS + Immich photos can fill the disk silently. Simple timer + threshold check would prevent this.

**Effort:** ~15 lines (timer + script)

### 16. Add Gitea and Ollama to service health check

The health check script (`scripts/service-health-check`) only monitors caddy, immich-server, immich-machine-learning, postgresql, unbound, dnsblockd. Gitea and Ollama are not checked.

**File:** `platforms/nixos/scripts/service-health-check`
**Effort:** ~10 lines

---

## Code Quality

### 17. Delete dead Technitium DNS config files

`platforms/nixos/system/dns-config.nix` (103 lines) and `platforms/nixos/system/dns.md` are full Technitium DNS configs replaced by `dns-blocker-config.nix`. Never imported, confusing for maintenance.

**Effort:** Delete 2 files

### 18. Fix Hyprland `$mod,G` bind conflict

`$mod,G` is mapped to both `gitui` (line 317) and `togglegroup` (line 359). The second silently overrides the first.

**File:** `platforms/nixos/desktop/hyprland.nix`
**Effort:** 1 line

### 19. Deduplicate Go overlay across flake.nix

Go 1.26.1 override is defined 3 times: perSystem (line 114), darwin overlay (line 194), nixos overlay (line 270). Should be a shared overlay file.

**File:** `flake.nix`
**Effort:** Extract to `overlays/go.nix`, ~20 lines saved

### 20. Fix justfile commands for NixOS platform

`check`, `deploy`, `rollback`, `test`, `info` commands all hardcode `darwin-rebuild` without platform detection. None work on NixOS.

**File:** `justfile`
**Effort:** ~50 lines

---

## Bonus (beyond 20)

- Fix duplicate comment in `configuration.nix:96-97` (AMD GPU comment appears twice)
- Remove duplicate `ollama` package in `ai-stack.nix:28` (service already installs `ollama-vulkan`)
- Remove duplicate `foot` package (in `multi-wm.nix`, `home.nix`, and `base.nix`)
- Fix `immich.lan` DNS hardcoded to `127.0.0.1` — inaccessible from LAN devices
- Add `gitea.lan` Caddy vhost (Gitea only accessible via `localhost:3000`)
- Fix Gitea mirror script bug: `wc -l < /dev/stdin` reads nothing (line 91)
- Remove `chrome-144.0.7559.97` version-pinned `permittedInsecurePackages` — breaks on next Chrome update
- Fix `SystemAssertions.nix` — 3 of 5 assertions are `assertion = true` (no-op validation)
- Clean up empty `platforms/darwin/test-minimal.nix` and `minimal-test.nix` debug stubs
- Fix `networking.nix` stale comment about "hyprland-system.nix" (file was split/renamed)
