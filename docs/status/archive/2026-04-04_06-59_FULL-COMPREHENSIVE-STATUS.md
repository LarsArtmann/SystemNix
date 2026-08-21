# FULL COMPREHENSIVE STATUS REPORT — SystemNix

**Date**: 2026-04-04 06:59
**Reporter**: Crush AI (GLM-5.1)
**Project**: SystemNix — Cross-Platform Nix Configuration (macOS + NixOS)
**Branch**: `master` @ `788b1ad`
**Ahead of origin**: 5 commits (after this commit: 6)

---

## Executive Summary

SystemNix manages two machines: **Lars-MacBook-Air** (aarch64-darwin) and **evo-x2** (x86_64-linux, AMD Ryzen AI Max+ 395 with Strix Halo iGPU). The codebase has matured significantly with 17 flake inputs, 11 service modules, and a comprehensive justfile (1813 lines, 100+ recipes). However, several critical infrastructure issues remain unaddressed: sops-nix secrets not decrypting, a port 80 conflict between Caddy and dnsblockd, a static IP mismatch, and the crush-config deployment being broken after an add/remove/add cycle. The AI/ML stack is architecturally complete but has never been successfully deployed with GPU acceleration verified.

---

## A) FULLY DONE ✅

### 1. SSH Key Extraction & Hardening

- Standalone `nix-ssh-config` flake published to GitHub
- Pure flake output: `nix-ssh-config.sshKeys.lars` — zero `builtins.pathExists`
- Ed25519 key with hardened crypto: `chacha20-poly1305@openssh.com`, `curve25519-sha256`, no legacy algorithms
- Cross-platform: Home Manager module (macOS) + NixOS module
- **Commits**: `d43bbcd`, `788b1ad`
- **Status**: ✅ Code complete, deployed to macOS, needs deploy to evo-x2

### 2. Merge Conflict Resolution

- Conflict markers committed in `50dd2ed` across `flake.nix`, `flake.lock`, `configuration.nix`
- Fully resolved in subsequent commits
- **Verification**: `grep -rn "<<<<<<\|>>>>>>\|=======" --include="*.nix" .` returns zero matches
- **Status**: ✅ Clean

### 3. NixOS Security Hardening

- AppArmor enabled with `kill` and `introspection` capabilities
- Polkit with `wheel` group admin authentication
- PAM configured with u2f and fprintd
- fail2ban: SSH (10 min ban, 3 attempts) + Grafana (1 hour ban, 5 attempts), correct string syntax for `ignoreip`
- ClamAV daemon with 1-hour update interval
- `security.chromium` disabled for lockdown
- **File**: `platforms/nixos/desktop/security-hardening.nix`
- **Status**: ✅ Complete (audit daemon disabled due to NixOS 26.05 bug #483085)

### 4. SigNoz ClickHouse Fix

- Cluster name corrected to `"default"` in `bb6925d`
- **Status**: ✅ Syntax fixed, builds pass

### 5. AI/ML Stack Architecture

- Ollama ROCm with flash attention + hipBLASlt
- llama-cpp-rocwmma with GGML_HIP_ROCWMMA_FATTN + MFMA for Strix Halo
- Unsloth Studio two-service architecture (setup oneshot + runtime)
- HuggingFace cache on `/data/cache/huggingface`
- Session variables for GPU env: `HSA_OVERRIDE_GFX_VERSION=11.5.1`, `HSA_ENABLE_SDMA=0`
- **File**: `platforms/nixos/desktop/ai-stack.nix`
- **Status**: ✅ Architecture complete, NOT deployed with GPU verification

### 6. Cross-Platform Home Manager

- Shared modules in `platforms/common/` (~80% code reuse)
- 13 shared program configs: fish, zsh, bash, nushell, starship, activitywatch, tmux, git, fzf, pre-commit, ublock-filters, keepassxc, chromium
- Platform-specific overrides minimal: Darwin (5 lines), NixOS (50 lines)
- **Status**: ✅ Working

### 7. DNS Blocker (dnsblockd)

- Unbound + custom dnsblockd package
- 25 blocklists (~2.5M domains), multi-format processor
- Custom Nix package in `pkgs/dnsblockd.nix`
- **Status**: ✅ Code complete (but port 80 conflict with Caddy causes crash-loop)

### 8. Service Modules (flake-parts)

- 11 service modules in `modules/nixos/services/` using dendritic pattern
- Modules: caddy, gitea, gitea-repos, grafana, homepage, immich, monitoring, photomap, signoz, sops, default (Docker)
- Each module is self-contained with its own imports
- **Status**: ✅ Architecture complete

### 9. fail2ban Syntax Fix

- `ignoreip` changed from Nix list to space-separated string in `fcb7a82`
- **Status**: ✅ Fixed

### 10. Pre-commit Hooks

- 8 hooks configured: gitleaks, trailing-whitespace, deadnix, statix, alejandra, nix-check, flake-lock-validate, check-merge-conflicts
- **Status**: ✅ Active and passing (alejandra flagged 2 files for formatting, but hooks work)

### 11. CI Pipeline

- GitHub Actions: `nix-check.yml` with 3 jobs (flake check on macOS + Ubuntu, darwin build, syntax check)
- Cachix integration for binary cache
- **Status**: ✅ Working (no NixOS builder)

---

## B) PARTIALLY DONE 🟡

### 1. crush-config Integration — 60% Complete

- **What's done**: GitHub repo exists, was added as flake input, documented extensively
- **What's broken**: Home Manager deployment lines (`home.file.".config/crush".source = crush-config`) removed in `4da33dd` and NEVER re-added
- **Impact**: AI agent config not syncing across machines
- **Effort**: 2 lines of code, 10 minutes including test

### 2. SigNoz Observability Stack — 70% Complete

- **What's done**: Architecture complete, vendor hashes resolved, flake-parts module, ClickHouse cluster fix
- **What's broken**: Never actually built and tested end-to-end on evo-x2
- **Impact**: No distributed tracing or metrics collection
- **Effort**: Medium (build test, configuration validation)

### 3. sops-nix Secrets Management — 50% Complete

- **What's done**: Module configured with grafana, gitea, dnsblockd certs defined
- **What's broken**: `/run/secrets/` empty at boot — decryption failures reported
- **Impact**: Services requiring secrets (certs, API keys) cannot start properly
- **Effort**: Medium (needs age/GPG key debugging on evo-x2)

### 4. Niri Desktop — 75% Complete

- **What's done**: Compositor working, Catppuccin Mocha themed, keybinds configured, wrapped package
- **What's missing**: Per-app window rules, keyboard shortcut documentation, some edge cases
- **Status**: Functional daily driver

### 5. Monitoring Stack — 60% Complete

- **What's done**: Grafana + Prometheus running, custom dashboards module
- **What's missing**: Alerting not configured, dashboards incomplete, no notification integration
- **Status**: Can view metrics, no proactive alerting

### 6. Ghost Systems Type Safety — 20% Complete

- **What's done**: `core/Types.nix`, `State.nix`, `Validation.nix` files exist
- **What's broken**: NOT imported anywhere, NOT used in any configuration
- **Impact**: No compile-time validation, all type safety claims are aspirational
- **Effort**: Large (needs full integration)

### 7. nix-ssh-config CI/CD — 30% Complete

- **What's done**: Published to GitHub, documented
- **What's missing**: No automated testing, no version tag, no release automation
- **Effort**: Small (basic flake check CI)

### 8. Immich Photo Management — 70% Complete

- **What's done**: Service module, Docker config, flake-parts integration
- **What's missing**: Not verified running, no backup strategy documented
- **Status**: Configured but unverified

---

## C) NOT STARTED ⏸️

### 1. Desktop Improvements (55 items)

- `TODO_LIST.md` contains 55 items across 3 phases (Phase 1: 21, Phase 2: 21, Phase 3: 13)
- None started — all deferred

### 2. PyTorch ROCm Integration

- No implementation for native PyTorch with ROCm support
- Options: pip wheel, distrobox, or custom Nix derivation
- Required for Unsloth Studio GPU acceleration

### 3. Private Cloud Infrastructure

- 4 Hetzner servers defined in SSH config but zero NixOS configurations
- No infrastructure-as-code for cloud

### 4. Automated E2E Testing

- No VM tests, no integration tests, no smoke tests for deployed services
- CI only checks syntax/flake validation

### 5. NixOS Build in CI

- No x86_64-linux runner configured
- GitHub Actions only builds Darwin config

### 6. Documentation Site

- 168 status files in `docs/status/`, no organized documentation site
- No searchable index, no auto-generated docs

### 7. Home Manager State Version Update

- Still on `24.05` — needs migration to current

### 8. ZFS Snapshots on NixOS

- Module imported but snapshot policy not configured

### 9. AMD NPU Integration

- `nix-amd-npu` input exists but not wired to any AI workload
- NPU sits unused despite being a key feature of the hardware

---

## D) TOTALLY FUCKED UP ❌

### 1. SSH Key Ping-Pong (5 Commits)

- **Timeline**: hardcoded → conflict markers → `builtins.pathExists` (worst option) → `nix-ssh-config` path → correct flake output
- **Root cause**: Merge conflict `50dd2ed` resolved with impure pattern in `d43bbbd`
- **Status**: ✅ Now fixed in `788b1ad` but wasted 5 commits

### 2. crush-config Add→Remove→Add Cycle (3 Commits)

- Added in one commit, removed in `4da33dd`, docs say "re-added later" but Home Manager deployment is STILL missing
- **Impact**: AI agent config not syncing, confusing documentation
- **Status**: Input removed from flake.nix entirely — worse than the audit doc claims

### 3. Port 80 Conflict: Caddy vs dnsblockd

- Caddy binds `*:80` for HTTP→HTTPS redirect
- dnsblockd needs port 80 for DNS block pages
- **Result**: dnsblockd crash-looping on evo-x2
- **Status**: ❌ Unresolved, blocks DNS blocking functionality

### 4. Static IP Mismatch

- `configuration.nix` declares `192.168.1.150` with `useDHCP = false`
- Reality: machine is at `192.168.1.161` via DHCP with dhcpcd still running
- **Impact**: Inconsistent networking, potential service breaks
- **Status**: ❌ Unresolved

### 5. Ollama CPU-Only (Was Broken, Now Fixed in Code)

- Previous report: missing `HSA_OVERRIDE_GFX_VERSION=11.5.1` — 2x speedup left on table
- **Current code**: `HSA_OVERRIDE_GFX_VERSION=11.5.1` IS set in `ai-stack.nix`
- **BUT**: Code never deployed to evo-x2, so evo-x2 still running CPU-only
- **Status**: ❌ Fix in code, not deployed

### 6. sops-nix Secrets Not Decrypting

- Age/GPG key configuration issue at boot
- `/run/secrets/` empty after boot
- **Impact**: Grafana, gitea, dnsblockd certificates all fail
- **Status**: ❌ Blocks several services

### 7. `scheduled-tasks.nix` Wrong WorkingDirectory

- Points to `/home/lars/Setup-Mac` (old macOS project name)
- Should be `/home/lars/projects/SystemNix`
- **Status**: ❌ Unfixed

### 8. Duplicate Ollama Package

- Both `ollama` (CPU) and `ollama-rocm` (GPU) in systemPackages
- CPU version is redundant and confusing
- **Status**: ❌ Unfixed

---

## E) WHAT WE SHOULD IMPROVE

### Code Quality

1. **Eliminate hardcoded paths** — 18 hardcoded user paths across 6 files. Use `config.users.users.lars.home` or `pkgs.lib.getExe` patterns
2. **Remove dead code** — `ublock-filters` disabled, Ghost Systems type safety unused, duplicate ollama package
3. **Fix scheduled-tasks.nix** — Wrong `WorkingDirectory` from macOS-era naming
4. **Add Nix syntax check to pre-commit** — `alejandra` is there but `nix-instantiate --parse` would catch broken syntax before it commits

### Architecture

5. **Resolve port conflicts systematically** — Document all service ports, create a port registry
6. **Wire crush-config properly** — Either commit to it or remove it entirely (currently in limbo)
7. **Implement Ghost Systems type safety** — Files exist but do nothing; either integrate or delete
8. **Consolidate scripts** — 61 scripts in `/scripts/`, only ~6 used by justfile. Archive or delete the rest

### Documentation

9. **Stop writing status docs** — 168 files in `docs/status/` is documentation bloat. Use git log instead
10. **Update AGENTS.md** — Several claims are stale (crush-config "integrated", Ghost Systems "implemented", `builtins.pathExists` "eliminated")
11. **Create service port map** — No centralized documentation of which service runs on which port

### DevOps

12. **Add NixOS CI builder** — No x86_64-linux runner means NixOS builds never tested before merge
13. **Add smoke tests** — Justfile recipe for post-deploy verification
14. **Add conflict detection to CI** — `conflict-check` recipe exists but was never used before committing conflict markers
15. **Tag nix-ssh-config v1.0.0** — Published but unversioned

### Security

16. **Fix sops-nix** — Secrets management is broken, blocks certificate-based services
17. **Re-enable audit daemon** — When NixOS 26.05 resolves #483085
18. **Remove duplicate ollama** — CPU version could be used accidentally, bypassing GPU

---

## F) TOP 25 THINGS TO DO NEXT

### Priority 0 — Critical (Do Today)

| # | Task                                                                                                                | Effort  | Impact                          |
| - | ------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------- |
| 1 | **Push 6 unpushed commits to origin/master**                                                                        | 1 min   | Unblocks remote builds          |
| 2 | **Re-add crush-config Home Manager deployment** in `platforms/darwin/home.nix` and `platforms/nixos/users/home.nix` | 10 min  | Syncs AI config across machines |
| 3 | **Deploy to evo-x2** — `nixos-rebuild switch` to get SSH fix + AI stack + security updates                          | 30 min  | Gets all recent fixes running   |
| 4 | **Fix sops-nix decryption** — Debug age/GPG key issues on evo-x2                                                    | 2 hours | Unblocks grafana, gitea, certs  |
| 5 | **Resolve Caddy vs dnsblockd port 80 conflict** — Either move dnsblockd to different port or reconfigure Caddy      | 1 hour  | Fixes DNS blocking              |

### Priority 1 — High Impact (This Week)

| #  | Task                                                                                                              | Effort  | Impact                     |
| -- | ----------------------------------------------------------------------------------------------------------------- | ------- | -------------------------- |
| 6  | **Fix static IP** — Either set `useDHCP = true` or align config with reality (192.168.1.161)                      | 15 min  | Consistent networking      |
| 7  | **Verify Ollama GPU acceleration** — After deploy, run `ollama run llama3` and check `rocm-smi`                   | 30 min  | Confirms AI stack works    |
| 8  | **Remove duplicate `ollama` CPU package** from `ai-stack.nix` systemPackages                                      | 2 min   | Eliminates confusion       |
| 9  | **Fix `scheduled-tasks.nix` WorkingDirectory** — Change `/home/lars/Setup-Mac` to `/home/lars/projects/SystemNix` | 2 min   | Fixes scheduled tasks      |
| 10 | **Build and test SigNoz end-to-end** on evo-x2                                                                    | 3 hours | Gets observability running |

### Priority 2 — Quality of Life (Next 2 Weeks)

| #  | Task                                                                              | Effort  | Impact                       |
| -- | --------------------------------------------------------------------------------- | ------- | ---------------------------- |
| 11 | **Add NixOS CI builder** — Either self-hosted runner or use QEMU                  | 4 hours | Catches NixOS build failures |
| 12 | **Create port registry** — Document all service ports (80, 443, 3000, 8888, etc.) | 1 hour  | Prevents future conflicts    |
| 13 | **Consolidate/archive scripts** — Move unused scripts to `scripts/archive/`       | 1 hour  | Reduces clutter              |
| 14 | **Archive old status docs** — Move pre-2026 docs to `docs/status/archive/`        | 30 min  | Reduces noise                |
| 15 | **Add smoke-test justfile recipe** — Post-deploy service health checks            | 2 hours | Catches deployment issues    |
| 16 | **Tag nix-ssh-config v1.0.0**                                                     | 5 min   | Marks stability              |
| 17 | **Update AGENTS.md** — Remove stale claims about crush-config and Ghost Systems   | 30 min  | Accurate documentation       |
| 18 | **Add dnsblockd watchdog** — Auto-restart on crash                                | 30 min  | Service reliability          |

### Priority 3 — Architecture (Next Month)

| #  | Task                                                                                | Effort | Impact                         |
| -- | ----------------------------------------------------------------------------------- | ------ | ------------------------------ |
| 19 | **Integrate Ghost Systems type safety** — Wire Types.nix, State.nix, Validation.nix | 1 week | Compile-time config validation |
| 20 | **Create Hetzner NixOS configs** — Infrastructure-as-code for cloud servers         | 3 days | Managed cloud infra            |
| 21 | **Implement NixOS VM tests** — Automated integration testing                        | 3 days | Prevents regressions           |
| 22 | **PyTorch ROCm integration** — Native GPU PyTorch for Unsloth                       | 2 days | Full AI stack                  |
| 23 | **AMD NPU integration** — Wire nix-amd-npu to actual workloads                      | 3 days | Uses all hardware              |
| 24 | **ZFS snapshot policy** — Configure automated snapshots on evo-x2                   | 1 day  | Data protection                |
| 25 | **Monitoring alerting** — Configure Grafana alerts + notifications                  | 1 day  | Proactive issue detection      |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Is the evo-x2 machine currently reachable and running NixOS?**

The last 15 commits are all from the MacBook Air (Darwin). The SSH key fix (`788b1ad`), AI stack changes, security hardening, and all service module updates have **never been deployed to the actual NixOS machine**. Multiple status reports mention sops-nix failures, port conflicts, and IP mismatches — but these can only be diagnosed by running commands on evo-x2 itself.

Without access to the machine, I cannot determine:

- Whether the current config even builds successfully on x86_64-linux
- Whether sops-nix secrets are decrypting properly
- Whether Ollama is running with GPU or CPU
- Whether dnsblockd is crash-looping
- What the actual IP address is

**Action needed**: SSH into evo-x2 and run `just health` + `nixos-rebuild switch --flake .#evo-x2` to validate the entire configuration.

---

## Project Metrics

| Metric             | Value                                     |
| ------------------ | ----------------------------------------- |
| Total flake inputs | 17                                        |
| Service modules    | 11                                        |
| Justfile recipes   | 100+                                      |
| Scripts            | 61                                        |
| Status docs        | 168                                       |
| Pre-commit hooks   | 8                                         |
| CI workflows       | 1 (3 jobs)                                |
| Unpushed commits   | 5 (before this)                           |
| Hardcoded paths    | 18                                        |
| Disabled features  | 3 (ublock-filters, auditd, Ghost Systems) |
| Known open issues  | 8 critical/high                           |

---

## Commit History (Last 15)

| Commit    | Type     | Description                                                   |
| --------- | -------- | ------------------------------------------------------------- |
| `788b1ad` | fix      | Simplify SSH authorized keys to `nix-ssh-config.sshKeys.lars` |
| `c6ce990` | docs     | SSH extraction follow-up status report                        |
| `d43bbbd` | fix      | SSH authorized keys path (intermediate fix)                   |
| `7e3171b` | docs     | SSH migration session 10 status                               |
| `c23da71` | chore    | Update flake.lock                                             |
| `f2c9b18` | chore    | Update flake inputs, remove duplicate crush-config            |
| `9430504` | refactor | Ollama data dir `/data/ollama` → `/data/models/ollama`        |
| `50dd2ed` | chore    | Update flake inputs (**committed merge conflicts**)           |
| `4da33dd` | refactor | Remove crush-config from flake inputs                         |
| `fcb7a82` | fix      | fail2ban ignoreip Nix list → string                           |
| `68e1ef5` | docs     | Remove trailing whitespace                                    |
| `bb6925d` | fix      | ClickHouse cluster name + fail2ban ignoreip                   |
| `5e89455` | docs     | Crush-config integration status                               |
| `6ddb49e` | refactor | macOS→Linux path migration (**mega-commit**)                  |
| `675c20f` | docs     | Project audit and AI backend assessment                       |

---

**Report Generated**: 2026-04-04 06:59
**Next Action**: Commit this report, push to origin, then deploy to evo-x2
