# SystemNix: Full Status Report

**Date:** 2026-04-25 04:36 (CEST) | **Branch:** master | **Commit:** 0a3c318
**Machines:** evo-x2 (NixOS x86_64) + Lars-MacBook-Air (macOS aarch64)
**ROCm:** 7.2.2 | **GPU:** Radeon 8060S (gfx1151, RDNA 3.5) | **RAM:** 128GB unified

---

## a) FULLY DONE ✅

### Session Work (uncommitted, staged in working tree)

| Area                                      | What                                                                                                                                         | Files                                                                                                         |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Deadnix strict mode**                   | `deadnix --fail` in flake.nix check — catches unused params at eval time                                                                     | `flake.nix`                                                                                                   |
| **Unused param cleanup**                  | Prefixed 8 unused lambda args with `_` to satisfy deadnix                                                                                    | `flake.nix`, `ai-stack.nix` (×2), `caddy.nix`, `sops.nix`, `darwin/default.nix`, `fonts.nix`, `keepassxc.nix` |
| **Systemd hardening: gitea-ensure-repos** | Added `PrivateTmp`, `NoNewPrivileges`, `ProtectHome`, `ProtectSystem=strict`, `MemoryMax=512M`, `RestartSec=5`, `StartLimitBurst=3`          | `gitea-repos.nix`                                                                                             |
| **Systemd restart policies**              | Added `Restart=on-failure` + `RestartSec=5` to authelia, caddy, taskchampion                                                                 | `authelia.nix`, `caddy.nix`, `taskchampion.nix`                                                               |
| **Gitea watchdog**                        | Added `WatchdogSec=30` to gitea service                                                                                                      | `gitea.nix`                                                                                                   |
| **Udisks2**                               | Enabled `services.udisks2` for USB/SD auto-mounting                                                                                          | `configuration.nix`                                                                                           |
| **EditorConfig**                          | Added `.editorconfig` with 2-space Nix, tab Go, 4-space Python, LF line endings                                                              | `.editorconfig`                                                                                               |
| **uBlock-filters removed**                | Deleted dead `ublock-filters.nix` module (was `enable=false`, timer just echoed) + removed import from `home-base.nix`                       | `ublock-filters.nix` (DELETED), `home-base.nix`                                                               |
| **Fonts guard**                           | Wrapped `fonts.packages` with `lib.mkIf pkgs.stdenv.isLinux` — fixes darwin eval                                                             | `fonts.nix`                                                                                                   |
| **Git global ignores deduplicated**       | Removed duplicate entries: `*.so` (×2), `*~`, `*.log`, `target/`                                                                             | `git.nix`                                                                                                     |
| **Dead bindings cleaned**                 | Removed unused `poetry` import, `cfg` in keepassxc, `userHome` in niri-wrapped, `appSecretFile`/`pgPasswordFile` in twenty                   | 4 files                                                                                                       |
| **emeet-pixyd meta**                      | Added `homepage` URL to package metadata                                                                                                     | `emeet-pixyd.nix`                                                                                             |
| **debug-map.md updated**                  | Added date + commit hash to header                                                                                                           | `debug-map.md`                                                                                                |
| **ROCm VMM research**                     | Confirmed `HSA_ENABLE_VMM` does not exist — VMM is auto-detected from amdgpu driver. evo-x2 already has all prerequisites. No action needed. | This report                                                                                                   |

### Previously Committed (this session, already in git)

| Commit    | What                                                       |
| --------- | ---------------------------------------------------------- |
| `0a3c318` | Repository metadata configuration (.editorconfig skeleton) |
| `821d829` | Archived 40 old status reports, updated documentation      |
| `d9bbca5` | dnsblockd dedicated IP architecture status report          |
| `935e962` | Master TODO plan (96 tasks across 9 priority tiers)        |
| `409f7a2` | Full system status report                                  |
| `a00834f` | Remove hipblaslt, fix DNS blocker binding, fix Caddy TLS   |

---

## b) PARTIALLY DONE 🟡

| Item                                   | Status   | What Remains                                                          |
| -------------------------------------- | -------- | --------------------------------------------------------------------- |
| **P0: git push**                       | Not done | All local commits unpushed since ~04-20. ~18 commits ahead of origin. |
| **P0: Stash cleanup**                  | Not done | 3 stale stashes still exist (Hyprland, vendorHash, line-endings).     |
| **P1: Docker image pinning**           | Not done | Voice agents + PhotoMap still use `:latest` tags.                     |
| **P1: VRRP auth to sops**              | Not done | `auth_pass "DNSClusterVRRP"` plaintext in dns-failover.nix.           |
| **P1: Taskwarrior encryption to sops** | Not done | Deterministic hash visible in repo.                                   |
| **P2: Eval smoke tests**               | Not done | `                                                                     |     | true` still in test expressions. |
| **P2: Pre-commit statix hook**         | Not done | Failed on wallpapers commit.                                          |
| **P5: `just switch`**                  | Not done | Many changes deployed to config but not built/applied to evo-x2.      |

---

## c) NOT STARTED ⬜

### From MASTER_TODO_PLAN (96 tasks total)

| Priority         | Total  | Done This Session                                  | Remaining                                                       |
| ---------------- | ------ | -------------------------------------------------- | --------------------------------------------------------------- |
| P0 CRITICAL      | 6      | 3 (docs, editorconfig)                             | 3 (push, stashes, branches)                                     |
| P1 SECURITY      | 7      | 4 (gitea hardening, ublock removal, unused params) | 3 (sops secrets, Docker pins)                                   |
| P2 RELIABILITY   | 11     | 8 (watchdog, restart, fonts, udisks2, git dedup)   | 3 (eval tests, statix, pre-commit)                              |
| P3 CODE QUALITY  | 9      | 4 (dead params, dead bindings)                     | 5 (remaining params, bash, fish, GPG, unfree)                   |
| P4 ARCHITECTURE  | 7      | 0                                                  | 7 (shared helper, module options ×4, preferences, niri options) |
| P5 DEPLOY/VERIFY | 13     | 0                                                  | 13 (all runtime tasks — require evo-x2)                         |
| P6 SERVICES      | 15     | 0                                                  | 15 (per-service improvements)                                   |
| P7 TOOLING/CI    | 10     | 1 (deadnix strict)                                 | 9 (GitHub Actions, justfile, pre-commit)                        |
| P8 DOCS          | 6      | 1 (debug-map date)                                 | 5 (README, AGENTS.md, ADR, contributing, env vars)              |
| P9 FUTURE        | 12     | 0                                                  | 12 (research, large refactors)                                  |
| **TOTAL**        | **96** | **~21**                                            | **~75**                                                         |

---

## d) TOTALLY FUCKED UP 💥

| Issue                                   | Severity    | Details                                                                                        |
| --------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| **Unpushed commits**                    | 🔴 CRITICAL | ~18 commits ahead of origin since ~04-20. If this machine dies, work is gone.                  |
| **No CI**                               | 🔴 CRITICAL | Zero GitHub Actions. No `nix flake check` on push. Every change is untested in CI.             |
| **Taskwarrior encryption key in repo**  | 🟡 HIGH     | `sha256("taskchampion-sync-encryption-systemnix")` is public. Anyone can decrypt synced tasks. |
| **Docker `:latest` tags**               | 🟡 HIGH     | Voice agents + PhotoMap can silently break on redeploy. No rollback possible.                  |
| **VRRP auth plaintext**                 | 🟡 MEDIUM   | DNS failover auth_pass in cleartext.                                                           |
| **SigNoz provision duplicates**         | 🟡 MEDIUM   | POST instead of PUT — creates duplicate alert rules on every reboot.                           |
| **No service verification since 04-20** | 🟡 MEDIUM   | Authelia, PhotoMap, Immich, ComfyUI, Steam, NPU — all unverified for 5 days.                   |

---

## e) WHAT WE SHOULD IMPROVE 📈

1. **Push after every session** — This has been recommended 15+ times. Make it automatic.
2. **CI pipeline** — Even a basic `nix flake check` on push would catch eval errors before deploy.
3. **Service health verification** — After `just switch`, automate a smoke test suite.
4. **Sops for all secrets** — Taskwarrior encryption, VRRP auth, and any other plaintext values.
5. **Module enable toggles** — 16 modules have no `enable` option. Makes selective deployment impossible.
6. **Shared systemd hardening helper** — 20 lines repeated per service. Extract to `lib/systemd-harden.nix`.
7. **Binary cache** — Custom overlays cause cache misses. Cachix would save 45+ min per rebuild.
8. **Integration tests** — Zero `nixosTests`. Critical services (Authelia + Caddy + DNS) completely untested.
9. **Documentation currency** — AGENTS.md doesn't mention DNS cluster, Pi 3, or VRRP.
10. **Regular deploys** — Changes accumulate for days without building. Small batches are safer.

---

## f) Top #25 Things to Get Done Next

### Immediate (this session, ~30 min)

| #   | Task                                                   | Est. | Impact                   |
| --- | ------------------------------------------------------ | ---- | ------------------------ |
| 1   | **`git push`** — push all local commits to origin      | 1m   | Prevents data loss       |
| 2   | **`git stash clear`** — drop 3 stale stashes           | 1m   | Hygiene                  |
| 3   | **Delete 17 remote `copilot/fix-*` branches**          | 2m   | Hygiene                  |
| 4   | **Pin Docker image digests** (voice agents + photomap) | 5m   | Prevents silent breakage |
| 5   | **Move Taskwarrior encryption to sops**                | 10m  | Security                 |
| 6   | **Move VRRP auth_pass to sops**                        | 8m   | Security                 |

### This Week (~2 hours)

| #   | Task                                                                                    | Est. | Impact                  |
| --- | --------------------------------------------------------------------------------------- | ---- | ----------------------- |
| 7   | **Add `just switch` + smoke test to evo-x2**                                            | 45m  | Verify everything works |
| 8   | **Verify all 7 services** (authelia, immich, photomap, comfyui, ollama, signoz, hermes) | 15m  | Confidence              |
| 9   | **Create `lib/systemd-harden.nix`** shared helper                                       | 12m  | DRY, consistency        |
| 10  | **Add module enable toggles** to 4 core modules (sops, caddy, gitea, immich)            | 12m  | Architecture            |
| 11  | **Add GitHub Actions** `nix flake check` on push                                        | 10m  | CI baseline             |
| 12  | **Fix eval smoke tests** (remove `                                                      |      | true`)                  | 5m  | Quality |
| 13  | **Fix pre-commit statix hook**                                                          | 10m  | Tooling                 |
| 14  | **Replace `nixpkgs-fmt` with `nixfmt-rfc-style`**                                       | 5m   | Modernization           |
| 15  | **Add GPG cross-platform path**                                                         | 5m   | Darwin compat           |

### Next Two Weeks (~4 hours)

| #   | Task                                                           | Est. | Impact        |
| --- | -------------------------------------------------------------- | ---- | ------------- |
| 16  | **Build Pi 3 SD image** + flash + boot                         | 45m  | DNS HA        |
| 17  | **Test DNS failover** (VRRP)                                   | 10m  | Reliability   |
| 18  | **Add module enable toggles** batch 2–4 (remaining 12 modules) | 36m  | Architecture  |
| 19  | **SigNoz: fix duplicate rules** (POST → PUT)                   | 10m  | Reliability   |
| 20  | **SigNoz: add missing metrics** for 10 services                | 12m  | Observability |
| 21  | **Write top-level README.md** update                           | 12m  | Onboarding    |
| 22  | **Document DNS cluster in AGENTS.md**                          | 8m   | Documentation |
| 23  | **Hermes: add WatchdogSec + health check**                     | 10m  | Reliability   |
| 24  | **ComfyUI: replace hardcoded paths** with module options       | 12m  | Architecture  |
| 25  | **Setup binary cache** (Cachix) for overlay builds             | 30m  | Build perf    |

---

## g) Top #1 Question I Cannot Answer

**What is the current runtime state of evo-x2?**

Everything in this repo is configuration-as-code — I can only analyze the _declarative_ state. I cannot verify:

- Whether the last `just switch` succeeded or was even run
- Whether Authelia, Immich, PhotoMap, ComfyUI, Ollama, SigNoz, Hermes are actually running
- Whether the sops secrets decrypted correctly at boot
- Whether the DNS blocker is actually serving the block page over HTTPS
- Whether Caddy obtained/renewed TLS certificates
- Whether the AMD NPU driver loaded successfully
- Whether the Pi 3 has been built/flashed/booted yet

**The single most valuable action right now:** SSH into evo-x2, run `just switch`, then verify each service. 5 days of unverified changes is the biggest risk.

---

## Uncommitted Changes Summary

21 files changed, 31 insertions(+), 274 deletions(-):

- **1 new file:** `.editorconfig`
- **1 deleted file:** `platforms/common/programs/ublock-filters.nix`
- **19 modified files:** Service hardening, lint fixes, dead code removal, cross-platform fixes
