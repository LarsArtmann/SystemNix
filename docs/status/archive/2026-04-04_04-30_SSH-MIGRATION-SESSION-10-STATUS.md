# SSH Key Migration & Project Status Report

**Date**: 2026-04-04 04:30
**Sessions**: 9th-10th continuation (multi-session effort)
**Focus**: RSA-to-Ed25519 SSH key migration + hardened SSH config deployment
**Status**: PARTIALLY COMPLETE — build in progress, crypto hardening NOT YET deployed

---

## Executive Summary

9 sessions have been spent migrating SSH keys from RSA to Ed25519 and deploying hardened SSH configuration. The `nix-ssh-config` repository is complete and pushed. The `SystemNix` integration is wired but the `just switch` build has never completed successfully with the hardened config. The currently deployed SSH config is **missing all crypto hardening** (KexAlgorithms, Ciphers, MACs, HostKeyAlgorithms, IdentityFile).

### Root Cause of Delay

1. **Merge conflict markers committed to master** in both `flake.nix` and `flake.lock` (commit `50dd2ed`) — prevented all builds
2. **Long compilation times** — terraform (Go) and otel-tui (Rust) dominate build time (~2+ hours)
3. **Session churn** — 9 continuation sessions, each spending significant time on context recovery

---

## A) FULLY DONE

| #   | Item                                                 | Evidence                                                                               |
| --- | ---------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 1   | `nix-ssh-config` repository created and structured   | `github:LarsArtmann/nix-ssh-config`, commit `2dd120d`                                  |
| 2   | Ed25519 key generated and stored                     | `~/.ssh/id_ed25519` exists, `ssh-keys/lars-ed25519.pub` in repo                        |
| 3   | RSA key removed                                      | `~/.ssh/id_rsa` does NOT exist                                                         |
| 4   | HM module with hardened crypto defaults              | `modules/home-manager/ssh.nix` with pqKex, aeadCiphers, etmMacs                        |
| 5   | NixOS sshd module with hardening                     | `modules/nixos/ssh.nix` with modern algorithms, banner, access control                 |
| 6   | sshKeys flake output                                 | `sshKeys.lars` reads from `ssh-keys/lars-ed25519.pub`                                  |
| 7   | SystemNix flake.nix wired to consume nix-ssh-config  | Both Darwin and NixOS home.nix import `nix-ssh-config.homeManagerModules.ssh`          |
| 8   | Host configs migrated                                | `ssh-config.hosts` in `platforms/darwin/home.nix` and `platforms/nixos/users/home.nix` |
| 9   | Merge conflicts resolved in flake.nix and flake.lock | Commits `f2c9b18`, `c23da71`                                                           |
| 10  | Both repos clean and pushed to origin                | `git status` clean on both                                                             |

---

## B) PARTIALLY DONE

| #   | Item                            | Status                       | Blocker                                                   |
| --- | ------------------------------- | ---------------------------- | --------------------------------------------------------- |
| 1   | `just switch` deployment        | Build running (session 10)   | Compilation time (terraform, otel-tui)                    |
| 2   | SSH config with hardened crypto | Module written, NOT deployed | Depends on `just switch`                                  |
| 3   | GitHub SSH key updated          | Ed25519 key generated        | Cannot verify `ssh -T git@github.com` (blocked by policy) |
| 4   | Git push without workaround     | Not tested                   | Depends on SSH config deployment                          |

---

## C) NOT STARTED

| #   | Item                                                         | Priority |
| --- | ------------------------------------------------------------ | -------- |
| 1   | Verify `git push` works without `GIT_SSH_COMMAND` workaround | High     |
| 2   | Test SSH connection to onprem (192.168.1.100) with new key   | Medium   |
| 3   | Test SSH to evo-x2 (192.168.1.150) with new key              | Medium   |
| 4   | Deploy hardened sshd on NixOS (evo-x2)                       | High     |
| 5   | Deploy hardened sshd on private-cloud-hetzner-0              | Medium   |
| 6   | Remove any remaining RSA key references across all repos     | Low      |

---

## D) TOTALLY FUCKED UP

### Critical Failure: Merge Conflict Markers Committed and Pushed

**What happened**: Commit `50dd2ed` ("chore(config): update flake inputs and remote configuration management") contained `<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes` markers in BOTH `flake.nix` AND `flake.lock`. This was pushed to `origin/master`.

**Impact**:

- All `nix-instantiate`, `nix build`, `just switch`, and `just test` commands failed with parse errors
- Every subsequent session tried to build but hit `syntax error, unexpected '<'`
- 3+ sessions wasted monitoring builds that could never succeed

**Root cause**: A `git stash pop` or merge was performed without resolving conflicts, then committed with a generic message that didn't indicate conflict resolution was needed.

**Lesson**: ALWAYS check for conflict markers before committing. Add a pre-commit hook or CI check.

**Resolution**: Fixed in commit `f2c9b18` (flake.nix) and lock regenerated in `c23da71`.

### Wasted Sessions

| Session | Time Spent | Activity                                | Value                                         |
| ------- | ---------- | --------------------------------------- | --------------------------------------------- |
| 8       | ~2 hours   | Monitoring `just switch` build          | ZERO — build was parsing corrupted flake.lock |
| 9       | ~1 hour    | Context recovery, checking build status | LOW — discovered conflicts too late           |
| 1-7     | ~8 hours   | Various SSH migration work              | HIGH — actual implementation                  |

### What Went Wrong With Session Management

1. No automated check for conflict markers in CI/pre-commit
2. Sessions assumed `just switch` would "just work" instead of verifying parse first
3. Long build times masked the real error — the error was in parsing, not compilation
4. Session handoff notes didn't include "check for parse errors before building"

---

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Pre-commit hook for conflict markers** — Prevent `<<<<<<` from ever being committed
2. **Fast validation before slow builds** — Always run `nix-instantiate --eval flake.nix` before `just switch`
3. **Session handoff checklist** — Include "verify parse, check git status, check for conflict markers"
4. **Build time optimization** — Consider splitting Darwin/NixOS builds, or using `--no-build` for validation

### Architecture Improvements

5. **Type-safe SSH config** — The `extraOptions = lib.types.attrsOf lib.types.str` is weak; NixOS sshd uses proper structured settings while HM uses stringly-typed attrs. Consider a shared type module.
6. **Crypto algorithm constants** — Currently duplicated between `modules/home-manager/ssh.nix` and `modules/nixos/ssh.nix`. Extract to `lib/crypto.nix` in nix-ssh-config.
7. **flake-parts migration** — AGENTS.md mentions `mkMerge` incompatibility with flake-parts. This limits composability.
8. **Test infrastructure** — No automated tests for nix-ssh-config. Should add `nix flake check` with actual validation, not just formatting.

### Code Quality

9. **Remove dead comments** — `platforms/common/home-base.nix` still has `# SSH config now loaded from nix-ssh-config flake input` as a comment with no actual import
10. **Consistent naming** — `ssh-config` (option namespace) vs `nix-ssh-config` (flake name) vs `ssh-server` (NixOS option). Should be unified.
11. **Status report sprawl** — 120+ status reports in `docs/status/`. Most are redundant. Consider a single living document.

---

## F) TOP 25 THINGS TO GET DONE NEXT

### Priority 1: Complete Current Work (0-1 hour each)

| #   | Task                                                                            | Impact   | Effort |
| --- | ------------------------------------------------------------------------------- | -------- | ------ |
| 1   | Wait for `just switch` to complete and verify SSH config has hardened crypto    | CRITICAL | 5 min  |
| 2   | Verify `~/.ssh/config` contains KexAlgorithms, Ciphers, MACs, HostKeyAlgorithms | CRITICAL | 2 min  |
| 3   | Test `git push` works without `GIT_SSH_COMMAND` workaround                      | HIGH     | 2 min  |
| 4   | Add pre-commit hook to reject conflict markers                                  | HIGH     | 15 min |
| 5   | Commit this status report                                                       | LOW      | 2 min  |

### Priority 2: NixOS Deployment (1-3 hours each)

| #   | Task                                                          | Impact | Effort |
| --- | ------------------------------------------------------------- | ------ | ------ |
| 6   | SSH to evo-x2 and run `nixos-rebuild switch --flake .#evo-x2` | HIGH   | 2 hrs  |
| 7   | Verify hardened sshd config on evo-x2                         | HIGH   | 15 min |
| 8   | Deploy nix-ssh-config to hetzner server                       | MEDIUM | 2 hrs  |
| 9   | Test SSH to all configured hosts with Ed25519                 | MEDIUM | 30 min |

### Priority 3: Architecture & Quality (2-4 hours each)

| #   | Task                                                                  | Impact | Effort |
| --- | --------------------------------------------------------------------- | ------ | ------ |
| 10  | Extract crypto constants to shared `lib/crypto.nix` in nix-ssh-config | MEDIUM | 1 hr   |
| 11  | Add `nix flake check` validation tests to nix-ssh-config              | MEDIUM | 2 hrs  |
| 12  | Unify naming: `ssh-config` vs `nix-ssh-config` vs `ssh-server`        | LOW    | 2 hrs  |
| 13  | Remove dead `home-base.nix` SSH comment                               | LOW    | 2 min  |
| 14  | Clean up 120+ status reports — archive old ones                       | LOW    | 1 hr   |

### Priority 4: Type Safety & DX (4+ hours each)

| #   | Task                                                                     | Impact | Effort |
| --- | ------------------------------------------------------------------------ | ------ | ------ |
| 15  | Create structured SSH option types (not `attrsOf str`)                   | MEDIUM | 4 hrs  |
| 16  | Investigate flake-parts mkMerge incompatibility                          | MEDIUM | 3 hrs  |
| 17  | Add CI pipeline for both repos (build check + conflict marker detection) | HIGH   | 3 hrs  |
| 18  | Create `just test-ssh` recipe that validates SSH config generation       | MEDIUM | 1 hr   |
| 19  | Document SSH architecture in ADR format                                  | LOW    | 2 hrs  |

### Priority 5: Broader Improvements (Ongoing)

| #   | Task                                                                                 | Impact | Effort |
| --- | ------------------------------------------------------------------------------------ | ------ | ------ |
| 20  | Audit all flake inputs for unnecessary dependencies                                  | MEDIUM | 3 hrs  |
| 21  | Investigate why terraform/otel-tui take so long to build — can we use binary caches? | HIGH   | 4 hrs  |
| 22  | Consider modular build targets — build only changed modules                          | MEDIUM | 6 hrs  |
| 23  | Set up Cachix or GitHub Actions cache for this flake                                 | HIGH   | 4 hrs  |
| 24  | Add `just validate` recipe that runs `nix-instantiate --eval flake.nix`              | LOW    | 10 min |
| 25  | Create session handoff template with mandatory checks                                | LOW    | 30 min |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Is the Ed25519 public key added to your GitHub account?**

I can generate keys and configure SSH to use them, but I cannot:

- Open `https://github.com/settings/keys` to verify
- Run `ssh -T git@github.com` (blocked by security policy)
- Add the key via `gh` CLI

The key fingerprint is: `SHA256:PCt1vyHm3QHeGoRO0rM8UER3gyEXRDOxX4fNuZPNURs`

Please verify this key is enrolled at https://github.com/settings/keys. Without this, `git push` will fail regardless of our SSH config.

---

## Technical State Summary

### SSH Keys

| Key             | Path                    | Status  |
| --------------- | ----------------------- | ------- |
| Ed25519 private | `~/.ssh/id_ed25519`     | Present |
| Ed25519 public  | `~/.ssh/id_ed25519.pub` | Present |
| RSA private     | `~/.ssh/id_rsa`         | REMOVED |
| RSA public      | `~/.ssh/id_rsa.pub`     | REMOVED |

### SSH Config (`~/.ssh/config`)

Currently deployed (OLD — no hardening):

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

**MISSING from deployed config**: KexAlgorithms, Ciphers, MACs, HostKeyAlgorithms, PubkeyAcceptedAlgorithms, IdentityFile

### nix-ssh-config Crypto Constants (in module, NOT yet deployed)

| Setting           | Value                                                                                                     |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| KexAlgorithms     | `mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org` |
| Ciphers           | `chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com`                             |
| MACs              | `hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com`                    |
| HostKeyAlgorithms | `ssh-ed25519,sk-ssh-ed25519@openssh.com,rsa-sha2-512,rsa-sha2-256`                                        |
| IdentityFile      | `~/.ssh/id_ed25519`                                                                                       |

### Git State

| Repo           | Branch | Status        | Latest Commit |
| -------------- | ------ | ------------- | ------------- |
| SystemNix      | master | CLEAN, pushed | `c23da71`     |
| nix-ssh-config | master | CLEAN, pushed | `2dd120d`     |

### Build Status

| Command                            | Status                           |
| ---------------------------------- | -------------------------------- |
| `nix-instantiate --eval flake.nix` | PASSES                           |
| `flake.lock` JSON validity         | PASSES                           |
| `just switch`                      | RUNNING (background shell `08C`) |
