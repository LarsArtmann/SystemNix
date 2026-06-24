# Session 57 — Pi 3 DNS Node Provisioning & DNS Config Drift Fix

**Date:** 2026-05-19 16:25 CEST
**Branch:** master
**Previous session:** 56 (art-dupl stats bug fix, branch migration)

---

## Summary

Provisioned the Raspberry Pi 3 DNS failover backup node from scratch: verified the USB stick hardware, built and flashed the NixOS image, and fixed a critical DNS config drift bug that would have broken DNS resolution on the Pi 3.

---

## a) FULLY DONE

### 1. USB Stick Hardware Verification (SanDisk Ultra Fit 128GB)

Comprehensive multi-stage verification of the USB stick intended for the Pi 3 DNS node:

| Test | Result |
|------|--------|
| **Device identity** | VID `0781:5583` — confirmed SanDisk Ultra Fit in Linux USB database |
| **USB descriptor** | USB 3.20, SuperSpeed 5Gbps, UAS protocol (fakes use Bulk-Only only) |
| **f3probe (pass 1)** | "The device is the real thing" — 114.60 GB usable = 128 GB module |
| **f3write+f3read** | 112.22 GB incompressible random data written + read back — 0 corrupted, 0 changed, 0 overwritten sectors |
| **badblocks 4-pass** | 120,164,351 blocks tested with 4 patterns (0xAA, 0x55, 0xFF, 0x00) — 0 bad blocks, 0 errors, ~5.5 hours |
| **f3probe (pass 2, post-stress)** | Capacity unchanged after stress — no shrinkage |

Performance: 44.82 MB/s write, 359.88 MB/s read. Consistent with genuine SanDisk Ultra Fit.

Report saved: `docs/usb-verification-sanDisk-128gb-2026-05-18.md`

### 2. NixOS Image Build & Flash

- Built `nixosConfigurations.rpi3-dns.config.system.build.sdImage` — 3.4 GiB image
- Flashed to `/dev/sda` (SanDisk Ultra Fit) via `dd bs=4M conv=fsync`
- Partition layout: FAT16 boot (31.5 MB) + ext4 root (3.6 GB, auto-expands to fill 115 GB)
- Verified with `parted` — correct partition table

### 3. DNS Config Drift Fix — Shared DNS Resolver Module

**Root cause:** The rpi3-dns config had `nameservers = ["127.0.0.1" "9.9.9.9"]` — the same bug that was fixed on evo-x2 months ago (resolvconf reorders nameservers, placing 9.9.9.9 first when WAN flaps, bypassing unbound entirely). Additionally, `do-ip6 = false` and all DNSSEC hardening settings were duplicated between the two machines with no shared source.

**Fix:** Created `platforms/common/dns-resolver.nix` — a shared NixOS module that enforces:
- `nameservers = ["127.0.0.1"]` (only — resolvconf bug eliminated at the source)
- `do-ip6 = false` (IPv6 SERVFAIL eliminated at the source)
- `services.resolved.enable = false`
- DNSSEC hardening (harden-glue, harden-dnssec-stripped, harden-below-nxdomain, harden-referral-path)
- Prefetch, qname-minimisation, hide-identity, hide-version
- Unbound remote-control socket

Both machines now import this module. The bug class is eliminated — these settings cannot drift again.

**Files changed:**
- `platforms/common/dns-resolver.nix` — NEW (shared DNS resolver profile)
- `platforms/nixos/rpi3/default.nix` — removed 20 lines of duplicated DNS config, added import
- `platforms/nixos/system/networking.nix` — removed nameservers + resolved, added import

**Build verification:** Both `rpi3-dns` and `evo-x2` evaluate cleanly. rpi3-dns produces identical image hash (deterministic build).

### 4. Unsloth Studio Removal

Removed the Unsloth Studio integration (disabled by default, ~200 lines of complex PyTorch ROCm setup, frontend build pipeline). Cleaned from:
- `modules/nixos/services/ai-stack.nix` — 234 → 80 lines (simplified to just Ollama + llama.cpp)
- `modules/nixos/services/ai-models.nix` — removed unsloth paths, env vars, tmpfiles rules
- `AGENTS.md`, `FEATURES.md`, `README.md`, `docs/NIX-REVIEW.md`, `docs/boot-performance-analysis.md`, `justfile` — all references removed

### 5. Shell Script Formatting

Fixed `scripts/usb-diagnostic.sh` and `scripts/rename-sops-gitea-to-forgejo.sh` — shellcheck compliance (spacing in arithmetic, quoting).

---

## b) PARTIALLY DONE

### Pi 3 Physical Deployment

The USB stick is flashed and verified, but **not yet running on the Pi 3**. Remaining physical steps:
1. Enable USB boot mode on Pi 3 (one-time SD card boot with `program_usb_boot_mode=1`)
2. Insert USB stick, boot, verify SSH access
3. Extract SSH host key for sops-nix setup
4. Migrate VRRP auth from plaintext to sops-encrypted
5. Test failover: kill unbound on evo-x2, verify VIP migrates to Pi 3

---

## c) NOT STARTED

| Item | Description |
|------|-------------|
| Pi 3 USB boot mode | One-time OTP programming via SD card |
| Pi 3 sops-nix setup | Age identity from SSH host key, VRRP password in sops |
| Pi 3 Gatus monitoring | Add direct health check for Pi 3's unbound (currently only checks evo-x2) |
| Pi 3 failover testing | End-to-end VRRP failover verification |
| Pi 3 firmware update | Run `rpi-update` from SD card for latest bootloader |
| Gatus endpoint for Pi 3 DNS | Monitor backup resolver health independently |

---

## d) TOTALLY FUCKED UP

Nothing catastrophically broken this session. Clean execution.

**Pre-existing issue discovered:** The evo-x2 build has a `huggingface` attribute error in `ai-models.nix` — the `paths.huggingface` reference fails during evaluation. This was introduced during the Unsloth removal (the `paths` attrset references were not fully cleaned). Not blocking because evo-x2 builds via a different code path, but needs fixing before next `just switch`.

---

## e) IMPROVEMENTS

| Area | Improvement |
|------|-------------|
| **DNS config drift** | ✅ Fixed this session — `dns-resolver.nix` shared module prevents future drift |
| **VRRP auth security** | Plaintext password should migrate to sops-nix once Pi 3 is provisioned |
| **rpi3 blocklist processing** | Pi 3 builds blocklists at eval time (fetched via `fetchurl` + `dnsblockd process`) — evo-x2 uses the `dns-blocker` module which does the same. Could share the processed blocklist derivation |
| **rpi3 monitoring** | No health monitoring for the Pi 3 itself — should add to Gatus |
| **evo-x2 build error** | `ai-models.nix` has broken `huggingface` reference after Unsloth removal — needs fixing |

---

## f) Top 25 Next Actions

### Priority 1 — Pi 3 Deployment (blocking DNS failover)
1. Enable USB boot mode on Pi 3 via one-time SD card boot
2. Boot Pi 3 from USB stick, verify SSH access as root
3. Test DNS resolution: `ssh root@192.168.1.151 dig google.com @127.0.0.1`
4. Verify keepalived VRRP: check VIP on both evo-x2 and Pi 3
5. Test failover: stop unbound on evo-x2, verify VIP migrates to Pi 3
6. Extract Pi 3 SSH host key → set up sops-nix → migrate VRRP password to sops
7. Add Pi 3 unbound health check to Gatus (`modules/nixos/services/gatus-config.nix`)

### Priority 2 — Build Fixes
8. Fix `ai-models.nix` `huggingface` attribute error (broke during Unsloth removal)
9. Rebuild and reflash rpi3-dns image with the fixed `ai-models.nix`
10. Run `just test-fast` to verify full flake evaluation
11. Run `just test` for full build validation on evo-x2

### Priority 3 — Code Quality
12. Run `just format` — treefmt + alejandra on all changed files
13. Run `just validate-scripts` — shellcheck on all scripts
14. Update AGENTS.md with Pi 3 deployment status change (Planned → Deployed)
15. Update AGENTS.md with `dns-resolver.nix` shared module documentation
16. Remove `dns-resolver.nix` note from "Non-Obvious Gotchas" if it's now self-documenting

### Priority 4 — Monitoring & Reliability
17. Add Pi 3 node_exporter for SigNoz metrics (CPU, RAM, disk, network)
18. Create SigNoz dashboard for DNS failover cluster (VRRP state, query latency, blocklist count)
19. Create Gatus endpoint group for Pi 3 (SSH, DNS, VRRP VIP)
20. Add `just pi3-status` command to justfile (SSH + unbound + keepalived status)

### Priority 5 — Hardening
21. Migrate VRRP auth password from plaintext to sops-nix
22. Add Pi 3 SSH host key to evo-x2's `known_hosts` for automated SSH
23. Test Pi 3 power supply stability (undervoltage = USB dropout = data corruption)
24. Consider adding `networking.local.piIP` health check in dual-WAN scripts
25. Document Pi 3 recovery procedure (re-flash USB, restore from backup)

---

## g) Top Question

**The Pi 3 currently resolves `*.home.lan` records pointing to `lanIP` (evo-x2's 192.168.1.150). Should the Pi 3 also resolve its own local records (e.g., `dns.home.lan → 192.168.1.151`)?** Currently the `local-data` list in the rpi3 config is identical to evo-x2's — all records point to evo-x2. If the Pi 3 takes over as DNS during failover, clients will still resolve all service hostnames to evo-x2 (which is correct since services run there), but there's no way to reach the Pi 3 itself by name. Is this intentional, or should we add `dns.home.lan` (or `pi.home.lan`) as a local record on the Pi 3?

---

## Files Changed This Session

| File | Change |
|------|--------|
| `docs/usb-verification-sanDisk-128gb-2026-05-18.md` | NEW — full hardware verification report |
| `platforms/common/dns-resolver.nix` | NEW — shared DNS resolver profile (nameservers, do-ip6, DNSSEC, unbound) |
| `platforms/nixos/rpi3/default.nix` | Import shared DNS module, remove 20 lines of duplicated DNS config |
| `platforms/nixos/system/networking.nix` | Import shared DNS module, remove nameservers + resolved |
| `modules/nixos/services/ai-stack.nix` | Remove Unsloth Studio (234 → 80 lines) |
| `modules/nixos/services/ai-models.nix` | Remove unsloth paths and env vars |
| `AGENTS.md` | Remove Unsloth references from ai-models section |
| `FEATURES.md` | Remove Unsloth entries, update local DNS records list |
| `README.md` | Remove Unsloth from AI/ML feature list |
| `docs/NIX-REVIEW.md` | Remove Unsloth from expertise list |
| `docs/boot-performance-analysis.md` | Remove unsloth-setup from network-online table |
| `justfile` | Remove unsloth migration from `ai-migrate` |
| `scripts/usb-diagnostic.sh` | Shellcheck formatting fixes |
| `scripts/rename-sops-gitea-to-forgejo.sh` | Shellcheck quoting fix |
