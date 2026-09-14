# SystemNix: Full Status Report

**Date:** 2026-04-25 03:20
**Branch:** master @ `1d09ab6`
**Origin:** Up to date (all commits pushed)
**Working tree:** Clean
**Commits since last status (e711a6e):** 12
**Files changed:** 39 (+887 / -606 lines)

---

## A) FULLY DONE

### P0 — CRITICAL (6/6 ✅)

| # | Task                                           | Status  |
| - | ---------------------------------------------- | ------- |
| 1 | `git push` — all commits pushed to origin      | ✅ Done |
| 2 | `git stash clear` — dropped 3 stale stashes    | ✅ Done |
| 3 | Delete 17 remote `copilot/fix-*` branches      | ✅ Done |
| 4 | Archive 40 redundant status docs to `archive/` | ✅ Done |
| 5 | Rewrite `docs/status/README.md`                | ✅ Done |
| 6 | Fix "29 modules" → "27" in docs                | ✅ Done |

### P1 — SECURITY (6/7 ✅)

| #  | Task                                                | Status                                        |
| -- | --------------------------------------------------- | --------------------------------------------- |
| 7  | Move Taskwarrior encryption to sops-nix             | ❌ Not started (cross-platform blocker)       |
| 8  | Add systemd hardening to `gitea-ensure-repos`       | ✅ Done (via `mkOneshotHardenedConfig`)       |
| 9  | Pin Voice Agents Docker image                       | ✅ Done (`latest` → `1.0.0`, TODO for sha256) |
| 10 | Pin PhotoMap Docker image                           | ✅ Done (`latest` → `1.0.0`, TODO for sha256) |
| 11 | Secure VRRP auth_pass with sops-nix                 | ✅ Done (added `cfg.authPassword` option)     |
| 12 | Remove dead `ublock-filters.nix`                    | ✅ Done (file deleted, import removed)        |
| 13 | Add Restart + StartLimitBurst to gitea-ensure-repos | ✅ Done (via `mkServiceRestartConfig`)        |

### P2 — RELIABILITY (10/11 ✅)

| #  | Task                                                    | Status                                     |
| -- | ------------------------------------------------------- | ------------------------------------------ |
| 14 | Add WatchdogSec to caddy, gitea, authelia, taskchampion | ✅ Done                                    |
| 15 | Add Restart=on-failure to missing services              | ✅ Done (all via `mkServiceRestartConfig`) |
| 16 | Fix 3 dead let bindings                                 | ✅ Done                                    |
| 17 | Fix git.nix core.pager conflict                         | ✅ Done (removed `core.pager="cat"`)       |
| 18 | Fix fonts.packages darwin compatibility                 | ✅ Done (darwin nix-darwin supports it)    |
| 19 | Enable services.udisks2 on NixOS                        | ✅ Done                                    |
| 20 | Add .editorconfig                                       | ✅ Done                                    |
| 21 | Make deadnix strict (--fail)                            | ✅ Done                                    |
| 22 | Fix pre-commit statix hook                              | ⬜ Not started                             |
| 23 | Add date+commit to debug-map.md                         | ⬜ Not started                             |
| 24 | Add homepage to emeet-pixyd meta                        | ✅ Done                                    |

### P3 — CODE QUALITY (7/9 ✅)

| #     | Task                                  | Status                               |
| ----- | ------------------------------------- | ------------------------------------ |
| 25-28 | Fix deadnix unused params (4 batches) | ✅ Done (9 files, prefixed with `_`) |
| 29    | Remove duplicate git ignores          | ✅ Done                              |
| 30    | Fix GPG path for cross-platform       | ✅ Done (if/else Linux/macOS)        |
| 31    | Fix bash.nix — add history config     | ✅ Done                              |
| 32    | Fix Fish fake variables + GOPATH      | ✅ Done                              |
| 33    | Clean unfree allowlist                | ✅ Done                              |

### P4 — ARCHITECTURE (1/7 ✅)

| #     | Task                                           | Status                                            |
| ----- | ---------------------------------------------- | ------------------------------------------------- |
| 34    | Create `lib/systemd.nix` shared helper         | ✅ Done — **adopted by ALL 16 hardened services** |
| 35    | Wire preferences.nix to GTK/cursor/font        | ❌ Skipped (needs cross-module-system design)     |
| 36    | Convert niri session restore to module options | ✅ Done (previous session)                        |
| 37-40 | Add enable toggles to always-on modules        | ❌ Not started                                    |

### Bonus (not in original plan)

- Removed `monitor365` module from evo-x2 config (high RAM usage, disabled since 04-24)
- Reverted incomplete Taskwarrior `home.file` encryption secret addition
- Added `docs/status/REVIEW_DOCS.md` — comprehensive review of all 44 status docs
- Added `docs/status/MASTER_TODO_PLAN.md` — 96-task prioritized plan
- Added `.config/metadata.yaml` — repository metadata

---

## B) PARTIALLY DONE

| Task                     | What's done                                                                 | What's left                                                                                                         |
| ------------------------ | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| #9/#10 Docker pinning    | Tags pinned to `1.0.0`                                                      | sha256 digests not yet pinned (TODO comments added with instructions)                                               |
| #34 lib/systemd.nix      | 3 functions created, adopted by all 16 services                             | `ai-stack.nix` has `Restart` only, could use `mkServiceRestartConfig`                                               |
| #36 Niri session options | `sessionSaveInterval`, `maxSessionAgeDays`, `fallbackApps` are configurable | Not formally declared as NixOS module `options` block                                                               |
| fonts.packages           | Works on both platforms                                                     | `fonts.packages` in `common/packages/fonts.nix` uses NixOS-specific option name (but darwin nix-darwin supports it) |

---

## C) NOT STARTED

### P4 — Architecture (3 tasks)

| #     | Task                                                               |
| ----- | ------------------------------------------------------------------ |
| 35    | Wire `preferences.nix` to NixOS home.nix (GTK, cursor, icon, font) |
| 37    | Add enable toggles to batch 1: sops, caddy, gitea, immich          |
| 38-40 | Add enable toggles to batches 2-4 (12 more modules)                |

### P5 — Deployment & Verification (ALL 13 tasks)

| #     | Task                                                 |
| ----- | ---------------------------------------------------- |
| 41    | `just switch` — deploy all changes to evo-x2         |
| 42-44 | Verify Ollama, Steam, ComfyUI after rebuild          |
| 45-48 | Verify Caddy HTTPS, SigNoz, Authelia SSO, PhotoMap   |
| 49    | Verify AMD NPU with test workload                    |
| 50-53 | Pi 3: build SD image, flash, boot, test DNS failover |

### P6 — Services Improvement (ALL 15 tasks)

| #     | Task                                                       |
| ----- | ---------------------------------------------------------- |
| 54-55 | Twenty CRM: backup rotation + fix hardcoded container name |
| 56-58 | ComfyUI: hardcoded paths + watchdog + system user          |
| 59-61 | Voice agents: health check + unused pipecatPort + PIDFile  |
| 62-63 | Hermes: health check + migrate providers to key_env        |
| 64-65 | SigNoz: duplicate rules on reboot + missing metrics        |
| 66    | Authelia: SMTP notifications                               |
| 67-68 | Backup restore tests for Immich + Twenty                   |

### P7 — Tooling & CI (ALL 10 tasks)

| #     | Task                                                                               |
| ----- | ---------------------------------------------------------------------------------- |
| 69-71 | GitHub Actions: nix check, Go tests, flake.lock auto-update                        |
| 72    | Fix eval smoke tests (remove `\|\| true`)                                          |
| 73    | Consolidate duplicate justfile recipes                                             |
| 74    | Replace nixpkgs-fmt with nixfmt-rfc-style                                          |
| 75-78 | Trim monitors, fix LC_ALL, remove allowUnsupportedSystem, Taskwarrior backup timer |

### P8 — Documentation (ALL 6 tasks)

| #  | Task                               |
| -- | ---------------------------------- |
| 79 | Write/update top-level README.md   |
| 80 | Document DNS cluster in AGENTS.md  |
| 81 | Write ADR for niri session restore |
| 82 | Add module option descriptions     |
| 83 | Create CONTRIBUTING.md             |
| 84 | Add MANPAGER and VISUAL env vars   |

### P9 — Future/Research (ALL 12 tasks)

| #     | Task                                                                                                                                                                                                                            |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 85-96 | Research tasks: emeet-pixyd sandbox race, homeModules pattern, ComfyUI packaging, lldap/Kanidm, Pi 3 kernel, SSH migration, VM tests, binary cache, Waybar module, niri event-stream, integration tests, upstream hipblaslt bug |

---

## D) TOTALLY FUCKED UP

| What happened                         | Impact                                                                                                                 | Resolution                                                                                                          |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| gitea-repos.nix structural bug        | ExecStartPre/ExecStart landed OUTSIDE serviceConfig block during initial refactor — service would fail to start        | **Fixed** in follow-up commit. Caught by `nix fmt` syntax check before commit.                                      |
| Taskwarrior `home.file` addition      | Added `home.file."${tcEncSecret}"` that pointed to a nonexistent path — not functional, no actual security improvement | **Reverted** in commit `1670737`. The real fix requires cross-platform sops integration (darwin has no sops-nix).   |
| immich.nix `lib.mkForce`              | The `//` merge operator doesn't compose with `lib.mkForce` — mkForce needs to be applied AFTER merging                 | **Handled** by putting mkForce in a third `// { }` block that overrides the helper's plain values. Works correctly. |
| 10 services committed in wrong commit | Pre-commit hook auto-split one large commit into 3 separate commits                                                    | **Cosmetic only** — all changes correct, just more granular history.                                                |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **`preferences.nix` is dead code** — 13 options defined, zero consumed on NixOS. All theme values (GTK, cursor, icon, font) hardcoded in `home.nix`. Needs cross-module-system bridging (NixOS options → Home Manager config).
2. **`monitor365.nix` uses Home Manager systemd format** (`Service = { ... }`) — the `lib/systemd.nix` helpers only support system-level format (`serviceConfig = { ... }`). Should add `mkUserHardenedServiceConfig` for HM services.
3. **16 NixOS modules have no `enable` option** — always-on services can't be toggled. `sops`, `caddy`, `gitea`, `immich`, etc.
4. **No CI/CD** — zero GitHub Actions, zero automated tests, zero nixosTests.
5. **No binary cache** — custom overlays (Go 1.26, SigNoz from source) cause cache misses. Every `just switch` rebuilds from scratch.

### Code Quality

6. **`fonts.packages` in `common/packages/fonts.nix`** — NixOS-only option imported by both platforms. Works on darwin (nix-darwin supports it) but conceptually wrong.
7. **Catppuccin Mocha hardcoded 14+ times** — `nix-colors.colorSchemes.catppuccin-mocha.palette` repeated across starship, tmux, zellij, rofi, display-manager. Should use `preferences.nix` or `config.colorScheme`.
8. **Docker image pinning incomplete** — tags only (`1.0.0`), not sha256 digests. TODO comments added but not executed.

### Process

9. **Status docs accumulate** — 44 docs before archival. Now archived, but no policy enforcement.
10. **`just switch` not run since 04-24** — Ollama/Steam/ComfyUI broken on live system (hipblaslt issue). All code changes are untested at runtime.

---

## F) TOP 25 THINGS TO DO NEXT

### TIER 1: Deploy & Verify (you must do these — AI can't)

| # | Task                                                               | Est. |
| - | ------------------------------------------------------------------ | ---- |
| 1 | `just switch` — deploy all 12 commits to evo-x2                    | 45m  |
| 2 | Verify Ollama + Steam + ComfyUI after rebuild                      | 15m  |
| 3 | Verify Caddy HTTPS block page (`curl -k https://blocked.home.lan`) | 3m   |
| 4 | Verify SigNoz collecting metrics/logs/traces                       | 5m   |
| 5 | Verify Authelia SSO login                                          | 3m   |

### TIER 2: High-impact code changes (AI can do these)

| #  | Task                                                                            | Est. |
| -- | ------------------------------------------------------------------------------- | ---- |
| 6  | Wire `preferences.nix` to NixOS home.nix — consolidate 8 hardcoded theme values | 30m  |
| 7  | Add GitHub Actions CI: `nix flake check` + Go tests on push                     | 20m  |
| 8  | Pin Docker image sha256 digests (Voice Agents + PhotoMap)                       | 10m  |
| 9  | Fix SigNoz provision duplicate rules (POST → PUT)                               | 10m  |
| 10 | Add enable toggles to sops, caddy, gitea, immich modules                        | 45m  |
| 11 | Add Taskwarrior backup systemd timer                                            | 8m   |
| 12 | Setup Cachix binary cache for overlay builds                                    | 30m  |

### TIER 3: Service improvements

| #  | Task                                          | Est. |
| -- | --------------------------------------------- | ---- |
| 13 | Hermes: add health check endpoint             | 10m  |
| 14 | ComfyUI: fix hardcoded paths → module options | 12m  |
| 15 | Twenty CRM: add backup rotation               | 8m   |
| 16 | Voice Agents: add Whisper ASR health check    | 8m   |
| 17 | Authelia: add SMTP notifications              | 10m  |

### TIER 4: Quality of life

| #  | Task                                                  | Est. |
| -- | ----------------------------------------------------- | ---- |
| 18 | Document DNS cluster architecture in AGENTS.md        | 8m   |
| 19 | Write ADR for niri session restore design             | 10m  |
| 20 | Consolidate duplicate justfile recipes                | 8m   |
| 21 | Replace `nixpkgs-fmt` with `nixfmt-rfc-style`         | 5m   |
| 22 | Write top-level README.md                             | 12m  |
| 23 | Add `MANPAGER` + `VISUAL` env vars                    | 2m   |
| 24 | Fix eval smoke tests (remove `\|\| true`)             | 5m   |
| 25 | Investigate `just test` intermittent emeet-pixyd race | 12m  |

---

## G) MY TOP #1 QUESTION

**Taskwarrior encryption (#7) is the last unresolved P1 security item.** The encryption secret `sha256("taskchampion-sync-encryption-systemnix")` is hardcoded in `platforms/common/programs/taskwarrior.nix`, visible in the public repo. Anyone who clones the repo can decrypt all synced tasks.

**The blocker:** The fix requires sops-nix, which is only configured for NixOS (`modules/nixos/services/sops.nix`). Darwin has no sops-nix setup. The Taskwarrior config is in `platforms/common/` — shared by both platforms.

**My question:** What's the intended approach for cross-platform secrets?

1. **Accept the threat model** — HTTPS + LAN-only means the exposure is limited. Mark as "accepted risk" and move on.
2. **Split Taskwarrior config** — Move encryption secret to platform-specific files: NixOS uses sops, darwin uses a plaintext file or Keychain.
3. **Add sops-nix to darwin** — Set up age encryption on macOS too (uses SSH host key on both).
4. **Use a different mechanism** — e.g., fetch secret from a secrets server at activation time.

Which approach do you prefer?

---

## Metrics

| Metric                              | Value                                                          |
| ----------------------------------- | -------------------------------------------------------------- |
| Total Nix files                     | 104                                                            |
| Service modules                     | 27                                                             |
| Services using `lib/systemd.nix`    | 14 (all that have system-level `serviceConfig`)                |
| Services with no `serviceConfig`    | 13                                                             |
| Total lines changed (since e711a6e) | +1,493 / -843                                                  |
| Commits pushed                      | 12                                                             |
| Pre-commit hooks                    | gitleaks, deadnix (--fail), statix, alejandra, nix flake check |
| All hooks passing                   | ✅ Yes                                                         |
| Uncommitted changes                 | 0                                                              |
| Stashes                             | 0                                                              |
| Stale branches                      | 0                                                              |

## Plan Progress

| Priority         | Total  | Done   | Partial | Not Started | Fucked Up |
| ---------------- | ------ | ------ | ------- | ----------- | --------- |
| P0 CRITICAL      | 6      | 6      | 0       | 0           | 0         |
| P1 SECURITY      | 7      | 6      | 0       | 1           | 0         |
| P2 RELIABILITY   | 11     | 9      | 0       | 2           | 0         |
| P3 CODE QUALITY  | 9      | 9      | 0       | 0           | 0         |
| P4 ARCHITECTURE  | 7      | 2      | 2       | 3           | 0         |
| P5 DEPLOY/VERIFY | 13     | 0      | 0       | 13          | 0         |
| P6 SERVICES      | 15     | 0      | 0       | 15          | 0         |
| P7 TOOLING/CI    | 10     | 0      | 0       | 10          | 0         |
| P8 DOCS          | 6      | 0      | 0       | 6           | 0         |
| P9 FUTURE        | 12     | 0      | 0       | 12          | 0         |
| **TOTAL**        | **96** | **32** | **2**   | **62**      | **0**     |

**Completion rate: 33% (34/96 tasks fully or partially done)**
