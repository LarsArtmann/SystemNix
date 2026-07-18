# FULL COMPREHENSIVE STATUS REPORT — SystemNix

**Date**: 2026-04-04 16:08 CEST
**Reporter**: Crush AI (GLM-5.1)
**Project**: SystemNix — Cross-Platform Nix Configuration (macOS + NixOS)
**Branch**: `master` @ `650d8c8`
**Ahead of origin**: 4 commits (unpushed)
**Disk**: 229G total, 226G used, **3.2G free** (GC recovered ~2.5G during this session)
**Sessions**: This is session 11 of the SSH key migration project

---

## Executive Summary

The SSH key migration from RSA to Ed25519 is **architecturally complete but not deployed**. The `nix-ssh-config` flake is built, published, and consumed correctly by SystemNix. However, the hardened SSH config has **never been deployed** — the currently active `~/.ssh/config` is the OLD config with zero crypto hardening (no KexAlgorithms, no Ciphers, no MACs, no HostKeyAlgorithms). The `just switch` build has been blocked by disk space exhaustion across sessions 10-11. We recovered ~2.5GB via GC but need more for a full Nix build. A staged regression in `configuration.nix` was caught and reverted this session.

---

## A) FULLY DONE ✅

### 1. nix-ssh-config Flake Architecture

- Standalone flake at `github:LarsArtmann/nix-ssh-config`
- Exposes: `homeManagerModules.ssh`, `nixosModules.ssh`, `sshKeys.lars`
- Crypto constants defined in both modules: `pqKex`, `aeadCiphers`, `etmMacs`, `modernHostKeys`
- Home Manager module uses `lib.mkDefault` for `*` block extraOptions
- **Commit**: `2dd120d` (nix-ssh-config repo, pushed)
- **Status**: ✅ Complete and published

### 2. SystemNix Consumption of nix-ssh-config

- Flake input declared: `url = "github:LarsArtmann/nix-ssh-config"`
- Darwin home.nix imports `nix-ssh-config.homeManagerModules.ssh` ✅
- NixOS home.nix imports `nix-ssh-config.homeManagerModules.ssh` ✅
- NixOS configuration.nix uses `nix-ssh-config.sshKeys.lars` for authorized keys ✅
- NixOS sshd `authorizedKeys = [nix-ssh-config.sshKeys.lars]` ✅
- Zero `builtins.pathExists` in committed code ✅
- **Status**: ✅ Code complete in committed version

### 3. Merge Conflict Resolution

- All conflict markers from `50dd2ed` resolved across flake.nix, flake.lock, configuration.nix
- Pre-commit hooks re-installed (were overridden by `buildflow`)
- `check-merge-conflicts` hook now active and catching regressions
- **Status**: ✅ All clean — `grep -rn "<<<<<<" --include="*.nix" .` returns zero

### 4. Ed25519 Key Generation

- `~/.ssh/id_ed25519` and `id_ed25519.pub` exist (created 2026-04-04)
- Old RSA keys removed from SSH directory
- Public key published in nix-ssh-config repo
- **Status**: ✅ Complete

### 5. NixOS Security Hardening (pre-existing)

- AppArmor, Polkit, PAM (u2f + fprintd), fail2ban, ClamAV
- **Status**: ✅ Configured (not verified on evo-x2)

### 6. Disk Space Recovery (this session)

- Cleaned `~/Library/Caches/go-build` (5.7GB)
- Cleaned `~/Library/Caches/pip` (17MB)
- Ran `nix store gc` and `nix-collect-garbage`
- Deleted old home-manager profile generations
- Freed from 693MB → 3.2GB
- **Status**: ✅ Partial recovery, still tight

---

## B) PARTIALLY DONE 🟡

### 1. SSH Config Deployment (THE CRITICAL BLOCKER)

- **Code**: 100% complete in git (both repos)
- **Deployment**: 0% — `just switch` has never succeeded with the new config
- **Current `~/.ssh/config`**: OLD config, symlink to `/nix/store/dp5d1h1gm9s2pr7dsgdzb5cvmz46zvqv-home-manager-files/.ssh/config`
- **Missing from deployed config**: KexAlgorithms, Ciphers, MACs, HostKeyAlgorithms, PubkeyAcceptedAlgorithms, IdentityFile
- **Blocker**: Disk space (3.2GB free, needs ~5-10GB for Nix build)
- **Status**: 🟡 90% done, blocked on deployment

### 2. Disk Space Management

- Recovered ~2.5GB this session
- Still at 3.2GB free on 229GB disk (99% full)
- 127 system profile links (root-owned, can't delete without sudo)
- Nix store consuming majority of disk
- **Status**: 🟡 Ongoing — needs `sudo nix-collect-garbage -d` to clear system profiles

### 3. Pre-commit Hook Health

- Hooks re-installed and working (caught configuration.nix regression)
- `statix` warnings still present (not blocking)
- `alejandra` formatting warnings present
- `check-merge-conflicts` and `flake-lock-validate` active
- **Status**: 🟡 Functional but has warnings

---

## C) NOT STARTED ⬜

### 1. SSH Config Verification on evo-x2 (NixOS)

- The NixOS target has never been deployed with the hardened config
- Need to verify sshd config includes hardened crypto algorithms
- Need to verify authorized keys work for SSH login
- **Status**: ⬜ Not started (blocked on macOS deployment first)

### 2. SSH Key Deployment to GitHub

- Ed25519 key generated but not verified as deployed to GitHub account
- `ssh` command blocked in this environment, can't test directly
- Need `git push` to verify SSH key works with GitHub
- **Status**: ⬜ Not started

### 3. Crypto Constant Deduplication

- `pqKex`, `aeadCiphers`, `etmMacs`, `modernHostKeys` defined in BOTH:
  - `nix-ssh-config/modules/home-manager/ssh.nix`
  - `nix-ssh-config/modules/nixos/ssh.nix`
- Should be extracted to shared `constants.nix` module
- **Status**: ⬜ Not started (acknowledged technical debt)

### 4. SSH Key Rotation Documentation

- No runbook for rotating SSH keys
- No documentation on adding new key types
- **Status**: ⬜ Not started

### 5. sops-nix Integration

- sops-nix declared as input but secrets not decrypting
- No `.sops.yaml` configuration
- No encrypted secrets in repository
- **Status**: ⬜ Not started

---

## D) TOTALLY FUCKED UP 💥

### 1. Disk Space Situation (CRITICAL)

- **229GB disk at 99% capacity** — 3.2GB free
- Has blocked ALL Nix builds across sessions 10-11
- System profiles (127 generations) can't be cleaned without sudo
- Go build cache alone was 5.7GB
- **Impact**: Cannot deploy ANY configuration changes
- **Root cause**: Accumulated Nix store garbage, no regular GC schedule
- **Fix**: `sudo nix-collect-garbage -d` (requires user action)

### 2. Staged configuration.nix Regression (CAUGHT)

- The staging area had `configuration.nix` reverted to OLD `builtins.pathExists` pattern
- This was from a previous session's bad merge resolution that got staged
- The COMMITTED version is correct (`nix-ssh-config.sshKeys.lars`)
- **Fixed this session**: Un-staged the regression with `git restore --staged`
- **Impact**: Would have re-introduced fragile path-dependent code
- **Prevention**: Pre-commit hooks now active, would have caught this

### 3. Multiple Session Waste from Merge Conflicts

- Sessions 8-11 spent significant time on merge conflict fallout
- Conflict markers were committed to master in `50dd2ed`
- Pre-commit hooks were disabled (buildflow had overridden `.git/hooks/pre-commit`)
- Each session "discovered" and "fixed" the same issues
- **Root cause**: No CI, no pre-commit enforcement, no branch protection
- **Impact**: ~4 hours of AI session time wasted

### 4. flake.lock Corruption

- flake.lock had merge conflict markers committed
- Required full deletion and regeneration
- `nix flake lock` regenerated to same valid state
- **Impact**: Blocked builds, wasted debugging time

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Process Improvements

1. **Regular GC Schedule**: Add weekly `nix-collect-garbage` to cron/launchd — disk space issues should never block work
2. **CI Pipeline**: Even a basic GitHub Actions `nix flake check` would catch merge conflict markers
3. **Pre-commit Enforcement**: Document that `pre-commit install` must be run after `buildflow` setup
4. **Branch Protection**: `master` should require passing checks before merge
5. **Session Handoff**: Previous session summaries were accurate but verbose — key blockers should be in the first 3 lines
6. **Commit Frequency**: Don't accumulate 4+ unpushed commits — push after each logical change
7. **Disk Monitoring**: Add `df -h /` to `just health` output with warning threshold

### Technical Improvements

8. **Crypto Constants**: Extract to shared `constants.nix` in nix-ssh-config
9. **Module Tests**: Add `nix-instantiate --eval` tests for nix-ssh-config modules
10. **SSH Config Verification**: Add `just verify-ssh` recipe that checks deployed config against expected
11. **Disk Space Guard**: Add pre-build check that warns if <5GB free before `just switch`
12. **Flake Lock Validation**: Add `nix flake check --no-build` to pre-push hook

---

## F) Top 25 Things We Should Get Done Next

| #   | Priority | Task                                                                                   | Effort | Status          |
| --- | -------- | -------------------------------------------------------------------------------------- | ------ | --------------- |
| 1   | P0       | **Free disk space**: Run `sudo nix-collect-garbage -d` to clear 127 system generations | 2 min  | Blocked on user |
| 2   | P0       | **Deploy SSH config**: `just switch` once disk is free                                 | 30 min | Blocked on #1   |
| 3   | P0       | **Verify SSH deployment**: `cat ~/.ssh/config` must show KexAlgorithms, Ciphers, MACs  | 1 min  | Blocked on #2   |
| 4   | P0       | **Test git push**: Verify Ed25519 key works with GitHub                                | 1 min  | Blocked on #2   |
| 5   | P0       | **Push all commits**: 4 commits ahead of origin                                        | 1 min  | Blocked on #4   |
| 6   | P1       | **Deploy to evo-x2**: `sudo nixos-rebuild switch --flake .#evo-x2` on NixOS target     | 30 min | Ready           |
| 7   | P1       | **Verify evo-x2 SSH**: Test SSH login to evo-x2 with Ed25519 key                       | 5 min  | Blocked on #6   |
| 8   | P1       | **Add GC to justfile**: `just clean-nix` recipe with `nix-collect-garbage -d`          | 5 min  | Ready           |
| 9   | P1       | **Add disk check to just switch**: Fail early if <5GB free                             | 5 min  | Ready           |
| 10  | P1       | **Extract crypto constants**: Shared `constants.nix` in nix-ssh-config                 | 15 min | Ready           |
| 11  | P1       | **Add SSH verification recipe**: `just verify-ssh` checks deployed config              | 10 min | Ready           |
| 12  | P2       | **Fix statix warnings**: Address pre-commit hook warnings                              | 15 min | Ready           |
| 13  | P2       | **Fix alejandra formatting**: Run `just format` and address warnings                   | 10 min | Ready           |
| 14  | P2       | **Set up sops-nix**: Configure `.sops.yaml`, create encrypted secrets                  | 30 min | Ready           |
| 15  | P2       | **Add GitHub Actions CI**: Basic `nix flake check` on push/PR                          | 20 min | Ready           |
| 16  | P2       | **Document SSH key rotation**: Runbook for adding/rotating keys                        | 15 min | Ready           |
| 17  | P2       | **Add home-manager SSH test**: Verify HM module renders correct config                 | 20 min | Ready           |
| 18  | P2       | **Clean up status reports**: 140+ status reports in docs/status/, archive old ones     | 15 min | Ready           |
| 19  | P2       | **Add disk monitoring to just health**: Show disk usage with warning                   | 5 min  | Ready           |
| 20  | P3       | **Set up branch protection**: Require CI on master                                     | 10 min | Ready           |
| 21  | P3       | **Add pre-push hook**: Run `nix flake check --no-build` before push                    | 5 min  | Ready           |
| 22  | P3       | **Document buildflow vs pre-commit**: Prevent future override conflicts                | 10 min | Ready           |
| 23  | P3       | **Add launchd for weekly GC**: Automated disk cleanup                                  | 15 min | Ready           |
| 24  | P3       | **Remove stale SSH comment**: `home-base.nix` line 12 stale comment (unstaged)         | 1 min  | Ready           |
| 25  | P3       | **Consolidate nix-ssh-config README**: Document architecture and usage                 | 15 min | Ready           |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Can you run `sudo nix-collect-garbage -d` on this machine?**

The disk has 3.2GB free (99% full) and the system has 127 Nix profile generations that I cannot delete without root access. This is the single blocker preventing ALL progress — I cannot run `just switch` to deploy the hardened SSH config until we have at least 5-10GB free. Without sudo, the Nix store garbage collection can only clean user-level profiles, which have already been cleaned.

---

## Git State

### Unpushed Commits (4 ahead of origin/master):

```
650d8c8 fix(nixos): simplify SSH authorized keys configuration
e3fda1b docs: add comprehensive SSH extraction follow-up status report
cfe361b fix(nixos): correct SSH authorized keys path to use nix-ssh-config
99e97af docs(status): add SSH migration session 10 comprehensive status report
```

### Staged Changes (ready to commit):

- `docs/status/2026-04-04_05-47_FULL-AUDIT-STATUS.md` (new file, 331 lines)
- `docs/status/2026-04-04_06-59_FULL-COMPREHENSIVE-STATUS.md` (new file, 363 lines)

### Unstaged Changes:

- `docs/status/2026-04-04_05-47_SSH-EXTRACTION-FOLLOW-UP-STATUS.md` (whitespace fixes only)

### Fixed This Session:

- Un-staged `configuration.nix` regression (was reverting to `builtins.pathExists`)
- Recovered ~2.5GB disk space via cache cleanup and GC
- Verified no merge conflict markers remain in any `.nix` file
- Verified committed `configuration.nix` has correct `nix-ssh-config.sshKeys.lars`

---

## Currently Deployed SSH Config (OLD — NO hardening)

```
Host github.com
  User git
  ServerAliveInterval 60
  Compression yes
  ControlMaster auto
  ControlPath ~/.ssh/sockets/%r@%h-%p
  ControlPersist 600
  TCPKeepAlive yes

Host onprem
  User root
  HostName 192.168.1.100

Host secretive-example
  IdentityAgent /Users/larsartmann/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh

Host *
  ForwardAgent no
  ServerAliveInterval 0
  ServerAliveCountMax 3
  Compression no
  AddKeysToAgent no
  HashKnownHosts no
  UserKnownHostsFile ~/.ssh/known_hosts
  ControlMaster no
  ControlPath ~/.ssh/master-%r@%n:%p
  ControlPersist no
```

**Missing from deployed config** (will be added by `just switch`):

- `KexAlgorithms mlkem768x25519-sha256,curve25519-sha256,curve25519-sha256@libssh.org,sntrup761x25519-sha512@openssh.com`
- `Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com`
- `MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com`
- `HostKeyAlgorithms ssh-ed25519,sk-ssh-ed25519@openssh.com`
- `PubkeyAcceptedAlgorithms ssh-ed25519,sk-ssh-ed25519@openssh.com`
- `IdentityFile ~/.ssh/id_ed25519`

---

## Architecture Reference

```
nix-ssh-config (github:LarsArtmann/nix-ssh-config)
├── modules/
│   ├── home-manager/ssh.nix    # HM module: crypto hardening for SSH client
│   └── nixos/ssh.nix           # NixOS module: crypto hardening for sshd
├── ssh-keys/
│   └── lars-ed25519.pub        # Public Ed25519 key
└── flake.nix                   # Exposes: homeManagerModules.ssh, nixosModules.ssh, sshKeys.lars

SystemNix (this repo)
├── flake.nix                   # Consumes nix-ssh-config as flake input
├── platforms/darwin/home.nix   # Imports HM module, configures ssh-config
├── platforms/nixos/users/home.nix  # Imports HM module for NixOS
└── platforms/nixos/system/configuration.nix  # Uses sshKeys.lars for sshd + user auth
```
