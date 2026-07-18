# SystemNix — Full Comprehensive Status Report

**Date:** 2026-04-04 05:47 CEST
**Project:** SystemNix Nix Configuration
**Platforms:** macOS (nix-darwin) + NixOS (evo-x2, AMD Ryzen AI Max+ 395)
**Report Type:** Comprehensive Audit After 10-Commit Review
**Commit:** HEAD = `c6ce990` (3 ahead of origin/master)
**Reviewer:** Crush AI Agent

---

## Executive Summary

Conducted a full audit of the last 10 commits (`68e1ef5`..`c6ce990`) to identify issues, regressions, and improvement opportunities. Found 3 significant problems: (1) merge conflict markers committed in `50dd2ed` that broke the flake, (2) SSH key management ping-ponged between 3 different approaches over 5 commits, (3) crush-config was added, removed, then re-added across 3 commits. The conflict markers and SSH regressions have been resolved in this session. The project has substantial infrastructure but several critical issues remain unfixed on the NixOS target.

---

## A) FULLY DONE ✅

### 1. SSH Key Extraction to Standalone Flake (`573a244`)

- **Status:** Architecture complete and correct
- `nix-ssh-config` repo exposes `sshKeys` as flake output
- SystemNix consumes via `nix-ssh-config.sshKeys.lars`
- Zero `builtins.pathExists` references in any `.nix` file
- Zero hardcoded SSH key strings in any `.nix` source file
- `ssh-keys/lars.pub` duplicate deleted from SystemNix
- Published to `github:LarsArtmann/nix-ssh-config`

### 2. Merge Conflict Resolution (This Session)

- **Status:** Fixed (unstaged, ready to commit)
- Removed all conflict markers from `flake.nix`, `flake.lock`, `configuration.nix`
- Resolved SSH keys to pure flake output: `nix-ssh-config.sshKeys.lars`
- All files parse correctly: `nix-instantiate --parse` passes on all 3 files

### 3. NixOS Security Hardening

- AppArmor enabled, Polkit auth agent, PAM for swaylock
- fail2ban: SSH (3 retries/1hr ban) + Grafana (5 retries/1hr ban)
- `ignoreip` correctly uses space-separated strings (fixed in `fcb7a82`)
- ClamAV antivirus daemon + auto-updater running
- 30+ security tool packages installed

### 4. SigNoz ClickHouse Cluster Name Fix (`bb6925d`)

- Corrected from `"cluster"` to `"default"` in both config and preStart

### 5. AI/ML Stack Architecture

- Ollama with ROCm at `/data/models/ollama`
- Custom `llama-cpp-rocwmma` with rocWMMA + MFMA for Strix Halo
- Unsloth Studio at `/data/unsloth` with Python 3.13 venv
- HuggingFace cache centralized at `/data/cache/huggingface`
- GPU env vars: `HSA_OVERRIDE_GFX_VERSION=11.5.1`, `HSA_ENABLE_SDMA=0`

### 6. Cross-Platform Home Manager

- `platforms/common/` shared modules: fish, starship, tmux, packages, fonts
- Platform-specific overrides minimal and focused
- ActivityWatch conditional: Linux only (`pkgs.stdenv.isLinux`)

### 7. DNS Blocker Architecture

- Unbound + dnsblockd with 25 blocklists (~2.5M domains)
- Multi-format processor: hosts, AdBlock, dnsmasq, plain domains
- Custom Nix module + packages via flake overlays

### 8. Service Modules (Flake-Parts Dendritic Pattern)

- 11+ service modules in `modules/nixos/services/`
- Caddy, Gitea, Grafana, Homepage, Immich, Monitoring, PhotoMap, SigNoz, sops
- Clean separation of concerns

### 9. Documentation

- Comprehensive AGENTS.md with architecture, patterns, and workflows
- 131+ status reports in `docs/status/`
- ADRs for key decisions (home-manager, ZFS ban, etc.)

---

## B) PARTIALLY DONE 🟡

### 1. crush-config Integration

- **Status:** Flake input defined in `flake.nix` as `github:LarsArtmann/crush-config`
- **Missing:** NOT deployed via Home Manager (`home.file.".config/crush"` removed in `4da33dd`, not re-added)
- **Impact:** `~/.config/crush` is NOT managed by Nix on any machine
- **Fix:** Re-add `home.file.".config/crush".source = crush-config;` to both `darwin/home.nix` and `nixos/users/home.nix`

### 2. SigNoz Integration

- **Status:** Architecture complete, builds not tested
- **Issue:** Vendor hashes may be placeholders (`sha256-AAAA...`)
- **Files:** `modules/nixos/services/signoz.nix`
- **Action:** Resolve source/vendor hashes, test full build

### 3. sops-nix Secrets

- **Status:** Module configured, secrets defined in `secrets.yaml` + `dnsblockd-certs.yaml`
- **Issue:** Previously reported decryption failure at boot (`/run/secrets/` empty)
- **Secrets managed:** grafana admin password, grafana secret key, gitea token, github token/user, dnsblockd CA cert/key, dnsblockd server cert/key
- **Templates:** `gitea-sync.env` for GitHub sync service
- **Action needed:** Verify decryption works on evo-x2

### 4. nix-ssh-config CI/CD

- **Status:** Published to GitHub, no automated testing
- **Missing:** GitHub Actions, `nix flake check`, formatting validation
- **Priority:** Medium

### 5. Desktop Environment (Niri)

- **Status:** Niri compositor + SilentSDDM configured
- Waybar, Dunst, Rofi, swaylock, wlogout, zellij all configured
- Catppuccin Mocha theme across all components
- **Missing:** Per-app window rules, keyboard shortcuts documentation

### 6. Monitoring Stack

- **Status:** Grafana + Prometheus configured via flake modules
- **Missing:** Custom dashboards incomplete, alerting not configured
- SigNoz for observability but vendor hashes unresolved

---

## C) NOT STARTED ⏸️

### 1. Desktop Improvements (55 items from TODO_LIST.md)

- Phase 1 (21 items): Config reloader, privacy/locking, productivity scripts
- Phase 2 (21 items): Keyboard/input, audio/media, dev tools
- Phase 3 (13 items): Backup/config, gaming, window rules, AI integration

### 2. PyTorch ROCm on NixOS

- Not implemented — pip wheel with ROCm runtime needed
- Options: Distrobox container, custom derivation, or pip venv

### 3. Type Safety System (Ghost Systems)

- `core/Types.nix`, `State.nix`, `Validation.nix` exist but NOT imported
- Module assertions not enabled
- User config consolidation: split brain between platforms

### 4. Audit Daemon

- Disabled due to NixOS 26.05 bug (#483085) — conflicts with AppArmor
- Awaiting upstream fix

### 5. Private Cloud Infrastructure

- `platforms/nixos/private-cloud/README.md` exists
- Hetzner servers defined in SSH config (4 hosts)
- No NixOS configurations for Hetzner servers

### 6. Automated Testing / CI

- No GitHub Actions for SystemNix itself
- No `nix flake check` in CI
- No automated build verification

---

## D) TOTALLY FUCKED UP ❌

### 1. SSH Key Management Ping-Pong (5 commits, 3 regressions)

**Timeline:**

| Commit    | SSH Key Method                | Quality                |
| --------- | ----------------------------- | ---------------------- |
| `573a244` | `nix-ssh-config.sshKeys.lars` | ✅ Pure, correct       |
| `6ddb49e` | Hardcoded string              | ❌ Regression          |
| `4da33dd` | Hardcoded string              | ❌ Kept regression     |
| `50dd2ed` | Conflict markers              | ❌ BROKEN              |
| `d43bbbd` | `builtins.pathExists`         | ❌ WORST option chosen |

**Root cause:** The `6ddb49e` commit ("migrate paths") did too many things and regressed the SSH key. Then `d43bbbd` resolved the conflict from `50dd2ed` by choosing the WORST possible option — the impure `builtins.pathExists` pattern that `573a244` specifically eliminated.

**Current fix:** Working tree has correct `nix-ssh-config.sshKeys.lars` (unstaged, ready to commit).

### 2. crush-config Add → Remove → Add (3 commits wasted)

| Commit    | Action                                                     |
| --------- | ---------------------------------------------------------- |
| `573a244` | Added as `github:LarsArtmann/crush-config`                 |
| `6ddb49e` | Changed to `git+file:///home/lars/.config/crush` (local)   |
| `4da33dd` | Removed entirely from flake, lock, and both home.nix files |
| `f2c9b18` | Re-added as `github:LarsArtmann/crush-config`              |

**Impact:** Home Manager deployment lines (`home.file.".config/crush".source = crush-config`) were removed in `4da33dd` and never re-added. The flake input exists but does nothing.

### 3. Port 80 Conflict (Caddy vs dnsblockd)

- **Issue:** Caddy binds `*:80` for HTTP→HTTPS redirect, dnsblockd needs port 80 for block pages
- **Symptom:** dnsblockd crash-looping: "bind: address already in use"
- **Status:** Unresolved

### 4. Static IP Configuration Mismatch

- **Config:** `networking.useDHCP = false` with static IP `192.168.1.150`
- **Reality:** System gets `192.168.1.161` via DHCP, dhcpcd.service still running
- **Impact:** All `.lan` domains may point to wrong IP
- **Status:** Unresolved

---

## E) WHAT WE SHOULD IMPROVE 📈

### 1. Commit Hygiene

- **One logical change per commit** — `6ddb49e` had 10+ unrelated changes (paths, SSH keys, nixpkgs channel, signoz, sops formatting, AI stack)
- **Verify before committing** — `nix-instantiate --parse` should be run before every commit
- **Check for conflict markers** — `just conflict-check` exists but wasn't used
- **Smaller PRs** — mega-commits hide regressions

### 2. Pre-commit Hooks

- Gitleaks exists but no Nix syntax validation
- Add `nix-instantiate --parse` check to pre-commit
- Add conflict marker detection (`grep -r "<<<<<<" *.nix`)

### 3. CI/CD Pipeline

- No GitHub Actions for SystemNix
- Should run: `nix flake check`, `nix-instantiate --parse`, `treefmt --check`
- Prevent broken commits from reaching master

### 4. Documentation Staleness

- 131+ status reports in `docs/status/` — many reference outdated patterns
- AGENTS.md references crush-config deployment that was removed
- Consider periodic cleanup or archival of old status reports

### 5. Architecture Consistency

- Choose ONE SSH key approach and stick to it (`nix-ssh-config.sshKeys` is correct)
- Choose ONE crush-config approach and stick to it (GitHub-based input + Home Manager deployment)
- Document decisions in ADRs to prevent future ping-ponging

### 6. Testing on Target Machine

- Most changes committed without verifying on evo-x2
- `nixos-rebuild switch` should be the final verification step
- Consider `nixos-rebuild build` as minimum before committing

---

## F) TOP 25 THINGS TO GET DONE NEXT 🎯

### Priority 0 — Critical (Fix Now)

1. **Commit SSH key fix** — `configuration.nix` has correct `nix-ssh-config.sshKeys.lars` in working tree, needs commit
2. **Re-add crush-config Home Manager deployment** — `home.file.".config/crush".source = crush-config;` in both darwin and nixos home.nix
3. **Push to origin/master** — 3 local commits not pushed, plus new fix
4. **Deploy to evo-x2** — Run `nixos-rebuild switch` to verify everything works on target
5. **Fix sops-nix secret decryption** — Debug why `/run/secrets/` is empty at boot

### Priority 1 — High Impact

6. **Resolve Caddy vs dnsblockd port 80 conflict** — Reverse proxy or alternate port strategy
7. **Fix static IP or fully embrace DHCP** — `networking.useDHCP = false` doesn't match reality
8. **Verify Unsloth Studio GPU detection** — Confirm ROCm fix works after rebuild
9. **Complete SigNoz vendor hash resolution** — Build and test
10. **Add GitHub Actions CI for SystemNix** — `nix flake check`, parse validation, formatting

### Priority 2 — Quality of Life

11. **Auto-discover SSH keys in nix-ssh-config** — Directory scan instead of manual enumeration
12. **Add Nix syntax check to pre-commit hooks** — Prevent broken commits
13. **Add conflict marker detection to pre-commit** — `grep -r "<<<<<<" *.nix`
14. **Update AGENTS.md crush-config section** — Deployment lines removed but docs still reference them
15. **Create `just smoke-test` recipe** — Quick validation after changes (parse, eval, build --dry-run)
16. **Document all service ports** — Single reference doc for operational clarity
17. **Add systemd watchdog to dnsblockd** — Detect crash loops early
18. **Monitor memory usage with ~2.5M DNS domains** — Check Unbound RSS

### Priority 3 — Architecture

19. **Add GitHub Actions CI to nix-ssh-config** — `nix flake check`, formatting
20. **Tag nix-ssh-config v1.0.0** — Stable API contract
21. **Implement sops secret validation in CI** — Verify secrets decrypt during `nix flake check`
22. **Clean up stale documentation** — Archive old status reports, update references
23. **Enable type safety system** — Import core/Types.nix, State.nix, Validation.nix
24. **Add NixOS VM integration tests** — Test SSH, services, desktop
25. **Create per-host NixOS configs for Hetzner servers** — Expand infrastructure as code

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT 🤔

### Why were the conflict markers in `50dd2ed` not detected before committing?

**Context:**

- Commit `50dd2ed` had `<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes` in 3 files
- `nix-instantiate --parse flake.nix` would have FAILED
- `just conflict-check` recipe EXISTS in the justfile
- Pre-commit hooks are installed (Gitleaks, treefmt)
- The conflict pattern `<<<<<<< Updated upstream` suggests a `git stash pop` conflict

**Why this matters:**
If we can't prevent broken commits from reaching master, we'll keep spending time fixing regressions instead of building features. The tools exist (`just conflict-check`, `nix-instantiate --parse`, pre-commit hooks) but weren't effective.

**What I need to understand:**

1. Were pre-commit hooks active at the time of `50dd2ed`?
2. Was the commit made with `--no-verify`?
3. Should we add a git `pre-commit` hook that runs `nix-instantiate --parse` on all changed `.nix` files?
4. Should `just conflict-check` be added to the `dev` recipe?

**Proposed fix:**
Add to `.pre-commit-config.yaml`:

```yaml
- repo: local
  hooks:
    - id: nix-parse-check
      name: Nix syntax check
      entry: nix-instantiate --parse
      language: system
      types: [nix]
    - id: conflict-markers
      name: Check for conflict markers
      entry: bash -c 'grep -rn "<<<<<<\|>>>>>>" --include="*.nix" .'
      language: system
      pass_filenames: false
```

---

## Commit Audit Summary (Last 10 Commits)

| #   | Hash      | Message                                                    | Quality                                   |
| --- | --------- | ---------------------------------------------------------- | ----------------------------------------- |
| 1   | `c6ce990` | docs: SSH extraction follow-up status report               | ✅ Clean                                  |
| 2   | `d43bbbd` | fix(nixos): correct SSH authorized keys path               | ❌ Wrong fix — used `builtins.pathExists` |
| 3   | `7e3171b` | docs(status): SSH migration session 10 report              | ✅ Clean                                  |
| 4   | `c23da71` | chore(flake): update flake.lock                            | ✅ Clean                                  |
| 5   | `f2c9b18` | chore(flake): update inputs, remove duplicate crush-config | ✅ Clean                                  |
| 6   | `50dd2ed` | chore(config): update flake inputs                         | ❌ Merge conflict markers committed       |
| 7   | `4da33dd` | refactor: remove crush-config                              | ⚠️ Premature — re-added 2 commits later   |
| 8   | `fcb7a82` | fix(nixos): correct fail2ban ignoreip syntax               | ✅ Correct fix                            |
| 9   | `68e1ef5` | docs(status): remove trailing whitespace                   | ✅ Clean                                  |
| 10  | `bb6925d` | fix(nixos): correct ClickHouse cluster + fail2ban ignoreip | ⚠️ Wrong fail2ban syntax (fixed in #8)    |

**Score:** 5 clean, 2 wrong fixes, 1 premature removal, 1 merge conflict, 1 clean fix of a previous wrong fix

---

## File Change Summary (This Session)

| File                                                | Change                                                           | Reason                 |
| --------------------------------------------------- | ---------------------------------------------------------------- | ---------------------- |
| `platforms/nixos/system/configuration.nix`          | Replace `builtins.pathExists` with `nix-ssh-config.sshKeys.lars` | Fix SSH key regression |
| `docs/status/2026-04-04_05-47_FULL-AUDIT-STATUS.md` | This report                                                      | Comprehensive audit    |

---

_Report generated: 2026-04-04 05:47 CEST_
_Commit: c6ce990 (3 ahead of origin/master)_
_SSH key fix: unstaged in working tree_
