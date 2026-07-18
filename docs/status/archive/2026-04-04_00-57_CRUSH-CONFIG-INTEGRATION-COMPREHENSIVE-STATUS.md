# SystemNix — Comprehensive Integration Status Report

**Date:** 2026-04-04 00:57:08 CEST
**Project:** SystemNix Nix Configuration
**Platforms:** macOS (nix-darwin) + NixOS (evo-x2)
**Report Type:** Integration Comprehensive Status

---

## Executive Summary

This report captures the state of SystemNix after integrating `crush-config` as a Nix flake input. The integration follows the same pattern as `nix-ssh-config` — using a GitHub-based flake input with Home Manager deployment via symlink.

---

## A) FULLY DONE ✅

### 1. Crush Config Integration (Today's Work)

- **Flake input added** — `crush-config` declared in `flake.nix`
- **GitHub-based URL** — `github:LarsArtmann/crush-config` (not local file://)
- **Home Manager deployment** — Single-line symlink for entire directory
- **Cross-platform** — Both Darwin and NixOS configurations updated
- **Documentation** — AGENTS.md updated with crush-config section

### 2. SSH Key Refactoring (Just Completed)

- **Eliminated `builtins.pathExists`** — No more impure path checking
- **Flake-native SSH keys** — `nix-ssh-config.sshKeys.lars` output
- **Single source of truth** — Keys now live only in nix-ssh-config repo
- **Deleted duplicate** — Removed `ssh-keys/lars.pub` from SystemNix
- **Pure evaluation** — No runtime path existence checks

### 3. Core Infrastructure (Previously Done)

- **Niri compositor** with SilentSDDM display manager
- **DNS blocker** with unbound + dnsblockd (25 blocklists, ~2.5M domains)
- **Multi-format blocklist processor** (hosts, AdBlock, dnsmasq, plain domains)
- **Caddy reverse proxy** for .lan domains with TLS
- **Self-hosted services**: Immich, Gitea, PhotoMapAI, Homepage
- **AMD Strix Halo optimizations**: rocWMMA, GPU DPM, IOMMU disabled

### 4. Architecture Improvements

- **Dendritic pattern migration** — 11 service modules in flake-parts
- **SSH extraction** to standalone `nix-ssh-config` flake
- **Go 1.26.1 overlay** for consistent Go version
- **Data partition** created (/data, 800GB) for AI models

---

## B) PARTIALLY DONE 🟡

### 1. SigNoz Integration

- **Status:** Architecture complete, builds not tested
- **Issue:** Vendor hashes are fake/placeholders (`sha256-AAAA...`)
- **Files:** `modules/nixos/services/signoz.nix`
- **Action needed:** Resolve source hashes, vendor hashes, frontend build

### 2. sops-nix Secrets (CRITICAL ISSUE)

- **Status:** Module configured but secrets not decrypting at boot
- **Issue:** `/run/secrets/` empty despite correct configuration
- **Impact:** DNS/Caddy certificate migration blocked
- **Action needed:** Debug age key matching, verify encryption keys

### 3. Unsloth Studio GPU

- **Status:** Service deployed, GPU detection fixed in latest commit
- **Previous issue:** `torch.cuda.is_available()` returned False
- **Fix applied:** ROCm libraries in LD_LIBRARY_PATH
- **Verification needed:** Confirm GPU detection works after rebuild

### 4. nix-ssh-config Publishing

- **Status:** Functional but uses local file:// URL
- **Current:** `url = "git+file:///Users/larsartmann/projects/nix-ssh-config"`
- **Action needed:** Push to GitHub, update to `github:LarsArtmann/nix-ssh-config`

---

## C) NOT STARTED ⏸️

### 1. Desktop Improvements (55 items from TODO_LIST.md)

- **Phase 1 (21 items):** Config reloader, privacy/locking, productivity scripts
- **Phase 2 (21 items):** Keyboard/input, audio/media, dev tools
- **Phase 3 (13 items):** Backup/config, gaming, window rules, AI integration

### 2. Security Hardening

- **Audit daemon:** Disabled due to AppArmor conflicts (NixOS bug #483085)
- **Bluetooth setup:** Kernel modules configured but not paired/verified

### 3. Nix Architecture (Ghost Systems)

- **Type safety system:** core/Types.nix, State.nix, Validation.nix not imported
- **Module assertions:** Not enabled
- **User config consolidation:** Split brain between platforms

### 4. PyTorch ROCm on NixOS

- **Status:** Not implemented - pip wheel with ROCm runtime needed
- **Options:** Distrobox container, custom derivation, or pip venv

---

## D) TOTALLY FUCKED UP ❌

### 1. sops-nix Secret Decryption Failure (CRITICAL)

- **Impact:** Full DNS outage on 2026-04-02, rollback required
- **Symptom:** `/run/secrets/` completely empty at boot
- **Root cause:** Secrets migrated from Nix store to `/run/secrets/` but decryption fails
- **Files:** `modules/nixos/services/sops.nix`, `secrets.yaml`, `dnsblockd-certs.yaml`
- **Status:** DNS currently working on rolled-back generation (store paths)

### 2. Port 80 Conflict (CRITICAL)

- **Conflict:** Caddy binds to `*:80` for HTTP→HTTPS redirect, dnsblockd needs port 80 for block pages
- **Symptom:** dnsblockd crash-looping: "bind: address already in use"
- **Current:** dnsblockd has restart counter at 1908+
- **Fix needed:** Caddy reverse-proxy to dnsblockd, or different port strategy

### 3. Static IP Configuration Lie (HIGH)

- **Config:** `networking.useDHCP = false` with static IP `192.168.1.150`
- **Reality:** System gets `192.168.1.161` via DHCP, dhcpcd.service still running
- **Impact:** All .lan domains point to wrong IP (192.168.1.150 vs actual 192.168.1.161)
- **Files:** `platforms/nixos/system/networking.nix`, `dns-blocker-config.nix`

### 4. DNS Blocker IP Mismatch (HIGH)

- **Issue:** `blockIP = "192.168.1.150"` in dns-blocker-config.nix doesn't match actual IP
- **Impact:** Block pages unreachable, dnsblockd crash-looping
- **Fix:** Dynamic IP detection committed but not deployed

---

## E) WHAT WE SHOULD IMPROVE 📈

### 1. Pre-Deploy Verification

- Add smoke tests for service dependencies before `nixos-rebuild switch`
- Verify `/run/secrets/*` paths exist before deploying sops-dependent services
- Add `systemd-analyze verify` for service configuration validation

### 2. Monitoring & Alerting

- Add systemd watchdog to dnsblockd (`WatchdogSec=30`)
- Monitor for persistent service failures (crash loops)
- Alert on DNS resolution failures

### 3. Secret Management Process

- Document sops-nix checklist: (1) edit secrets.yaml, (2) verify decryption, (3) declare in sops.nix
- Create `just sops-add-secret` recipe for safe secret addition
- Never migrate from static paths to dynamic paths without verification

### 4. Network Configuration

- Fix static IP or fully embrace DHCP with reservation documentation
- Document all service ports in single reference doc
- Add network interface assertions to fail build if IP doesn't match

### 5. Code Quality

- Auto-discover SSH keys from directory in nix-ssh-config
- Clean up stale documentation references (old `ssh-keys/` paths)
- Fix eval warnings (deprecated `system` parameter - already fixed)

---

## F) TOP 25 THINGS TO GET DONE NEXT 🎯

### Priority 0 — Critical (Fix Now)

1. **Fix sops-nix secret decryption** — Debug why `/run/secrets/` is empty, verify age key matches
2. **Resolve Caddy vs dnsblockd port 80 conflict** — Use different port or reverse-proxy strategy
3. **Deploy latest changes to evo-x2** — `nixos-rebuild switch` with current config
4. **Fix static IP or embrace DHCP** — Make `networking.useDHCP = false` actually work
5. **Verify Unsloth Studio GPU detection** — Confirm ROCm fix works after rebuild

### Priority 1 — High Impact

6. **Complete SigNoz vendor hash resolution** — Run `nix build`, copy hashes from errors
7. **Publish nix-ssh-config to GitHub** — Create repo, push, update flake URL
8. **Add RPZ format output for TLD blocking** — HaGeZi spam-tlds list support
9. **Monitor memory usage with ~2.5M domains** — Check Unbound RSS after DNS expansion
10. **Add daily auto-update for threat lists** — DGA7 and TIF lists update daily
11. **Add systemd watchdog to dnsblockd** — Detect crash loops
12. **Create custom llama.cpp derivation** — Already done with rocWMMA flags
13. **Test Ollama Vulkan vs ROCm benchmark** — Compare inference speeds
14. **Fix deprecated eval warnings** — Already resolved

### Priority 2 — Quality of Life

15. **Add GitHub Actions CI to nix-ssh-config** — `nix flake check`, formatting validation
16. **Document all service ports** — Single reference doc for operational clarity
17. **Standardize `host.docker.internal`** — For container → host communication
18. **Add sops secret validation to CI** — Verify secrets decrypt during `nix flake check`
19. **Auto-discover SSH keys in flake output** — Directory scan instead of manual enumeration
20. **Clean up stale documentation** — Update docs referencing old `ssh-keys/` paths
21. **Add health checks for critical services** — DNS, Caddy, Immich, Gitea
22. **Implement auto-discovery of SSH keys** — Future-proof key management
23. **Add generation diff tool** — Compare what changed between NixOS generations
24. **Document sops-nix setup** — How to encrypt, key rotation, troubleshooting
25. **Add DNS blocklist metrics** — Export to Prometheus/Grafana

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT 🤔

### Why are sops-nix secrets not being decrypted at boot?

**Context:**

- `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]` — key exists on disk
- `sops.defaultSopsFile` points to valid `secrets.yaml` in repo
- `dnsblockd-certs.yaml` exists with encrypted secrets
- `sops-nix.nixosModules.sops` is imported in the flake
- `/run/secrets.d/25/` is completely empty after boot

**Possible causes:**

1. SSH host key doesn't match the age identity used to encrypt secrets
2. sops files were encrypted with a different key than the host's SSH key
3. sops-nix service ordering issue (secrets decrypted after services start)
4. Silent failure in sops-nix decryption that doesn't show in logs

**What I've tried:**

- Verified SSH host key exists at `/etc/ssh/ssh_host_ed25519_key`
- Confirmed `sops-nix.nixosModules.sops` is imported in flake.nix
- Checked that `secrets.yaml` and `dnsblockd-certs.yaml` exist in the repository

**What I need:**
Access to the machine with `sops --decrypt` and the age/SSH keys to verify:

- Does `sops --decrypt secrets.yaml` work with the host's SSH key?
- Does the age public key derived from `/etc/ssh/ssh_host_ed25519_key` match what was used to encrypt the files?
- Are there any systemd journal entries showing sops-nix decryption failures?

**Why this matters:**
This blocks the entire certificate migration (dnsblockd CA/cert, Caddy TLS). Without working sops-nix, we're stuck on the old Nix-store-based certificate paths, which is technical debt and prevents proper secret rotation.

---

## Crush Config Integration Details

### What Was Done Today

| File                             | Change                                                            |
| -------------------------------- | ----------------------------------------------------------------- |
| `flake.nix`                      | Added `crush-config` input with `github:LarsArtmann/crush-config` |
| `flake.nix`                      | Added `crush-config` to `extraSpecialArgs` for both platforms     |
| `platforms/darwin/home.nix`      | Added `home.file.".config/crush".source = crush-config;`          |
| `platforms/nixos/users/home.nix` | Added `home.file.".config/crush".source = crush-config;`          |
| `AGENTS.md`                      | Added comprehensive crush-config documentation section            |

### Architecture

```
GitHub (LarsArtmann/crush-config)  ←  Push after editing locally
    ↓
flake.nix (inputs.crush-config)     ←  Fetched by Nix
    ↓
home.file.".config/crush"           ←  Symlink in Home Manager
    ↓
~/.config/crush  →  /nix/store/...-crush-config/  (read-only)
```

### Workflow

```bash
# 1. Edit (in local git repo)
cd ~/.config/crush
# edit files...
git commit -am "Update" && git push

# 2. Deploy (fetches from GitHub)
cd ~/projects/SystemNix
just update && just switch
```

### Key Design Decision

**Why GitHub instead of local file://?**

- Local file path creates circular dependency: flake reads from `~/.config/crush`, then tries to symlink `~/.config/crush` → nix store
- GitHub-based workflow separates source (editable git repo) from deployment (nix store)
- Enables editing without immediate rebuild, proper version control, and cross-machine sync

---

## SSH Key Refactoring Details

### Before (Impure)

```nix
lib.optional (builtins.pathExists ../../../ssh-keys/lars.pub)
  (builtins.readFile ../../../ssh-keys/lars.pub)
++ lib.optional (builtins.pathExists ../../../nix-ssh-config/ssh-keys/lars.pub)
  (builtins.readFile ../../../nix-ssh-config/ssh-keys/lars.pub)
```

### After (Pure)

```nix
authorizedKeys.keys = [ nix-ssh-config.sshKeys.lars ]
```

### Benefits

- No runtime path existence checks — fails at eval time if key missing
- No relative path fragility — immune to directory restructuring
- No duplication — single source of truth in nix-ssh-config repo
- Fully pure evaluation compatible
- Content-addressed in Nix store

---

## Validation Commands

```bash
# Verify crush-config integration
nix eval .#nixosConfigurations.evo-x2.config.home-manager.users.lars.home.file.".config/crush".source --impure

# Verify SSH keys
nix eval .#nixosConfigurations.evo-x2.config.users.users.lars.openssh.authorizedKeys.keys --impure

# Full syntax check
nix-instantiate --parse flake.nix

# Test build (dry run)
nix build --dry-run .#nixosConfigurations.evo-x2.config.system.build.toplevel
```

---

## Next Steps

1. **Deploy to evo-x2:** `just switch` to apply crush-config and SSH key changes
2. **Fix sops-nix:** Debug why `/run/secrets/` is empty
3. **Fix port 80 conflict:** Resolve Caddy vs dnsblockd binding issue
4. **Publish nix-ssh-config:** Push to GitHub and update flake URL
5. **Complete SigNoz:** Resolve vendor hashes and test build

---

_Report generated: 2026-04-04 00:57:08 CEST_
_Commit: 573a244e2a193c8785a0d45121ee619900007280_
