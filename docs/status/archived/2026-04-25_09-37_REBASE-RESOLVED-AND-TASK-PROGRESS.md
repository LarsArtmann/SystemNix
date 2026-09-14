# SystemNix: Full Status Report — Rebase Resolution + Task Progress

**Date:** 2026-04-25 09:37 | **Commit:** `1181907`
**Branch:** `master` (3 commits ahead of origin)
**Status:** Rebase complete, working tree clean, ready for push

---

## Executive Summary

Resolved a complex 3-commit interactive rebase onto `201a441` that had 7+ merge conflicts across two commits. All conflicts resolved, rebase completed successfully. The repo is in a clean state with no uncommitted changes.

**Key achievement:** Consolidated from two competing `lib/systemd.nix` designs (complex module vs simple function) to one consistent approach (simple function used as `harden` via direct import).

---

## A) FULLY DONE ✅

### Rebase Resolution (this session)

- **Commit 1** (`f12e110`): Resolved all conflicts from `e0afb3e` — took inline hardening approach, removed dead helper imports from gitea-repos, taskchampion, caddy, authelia, ai-stack, darwin/default.nix
- **Commit 2** (`8ea8ac0`): Applied cleanly — status report
- **Commit 3** (`1181907`): Resolved 7 conflicts:
  - `lib/systemd.nix` — took c7ce2b6's simple function design (19 lines vs 57)
  - `bash.nix` — merged both: HEAD's history config + c7ce2b6's globstar/nocaseglob
  - `fish.nix` — took c7ce2b6's `fish_maximum_history_size` + `fish_autosuggestion_enabled`, kept GOPATH comment, removed `LC_ALL` override
  - `git.nix` — took c7ce2b6's full path `/opt/homebrew/bin/gpg` for macOS
  - `flake.nix` — kept HEAD's simple echo-based eval tests (no nix-instantiate dependency)
  - `hermes.nix` — took c7ce2b6's `harden` pattern + `WatchdogSec=30`, removed dead `mkHardenedServiceConfig` import
  - `voice-agents.nix` — took c7ce2b6's inline hardening, removed dead `mkHardenedServiceConfig`/`mkServiceRestartConfig` imports

### From Earlier Sessions (already committed)

| Task     | Description                                               | Commit(s)                       |
| -------- | --------------------------------------------------------- | ------------------------------- |
| P0-4     | Archive 39 redundant status docs                          | `821d829`                       |
| P0-5     | Rewrite `docs/status/README.md`                           | `821d829`                       |
| P0-6     | Fix inaccurate "29 modules" count                         | `821d829`                       |
| P1-8     | Add systemd hardening to `gitea-ensure-repos`             | `c03c59f`, `f12e110`            |
| P1-12    | Remove dead `ublock-filters.nix` module                   | `c03c59f`                       |
| P1-13    | Fix `gitea-ensure-repos` Restart + StartLimitBurst        | `c03c59f`                       |
| P2-14    | Add `WatchdogSec` to caddy, gitea, authelia, taskchampion | `f3eab12` etc.                  |
| P2-15    | Add `Restart=on-failure` to missing services              | `f3eab12` etc.                  |
| P2-16    | Fix 3 dead `let` bindings                                 | `f12e110`                       |
| P2-17    | Fix `core.pager` vs `pager.diff` conflict in git.nix      | `f12e110`                       |
| P2-18    | Fix `fonts.packages` darwin compat                        | Earlier session                 |
| P2-19    | Enable `services.udisks2` on NixOS                        | Earlier session                 |
| P2-20    | Add `.editorconfig`                                       | Earlier session                 |
| P2-21    | Make deadnix check strict (`--fail`)                      | Earlier session                 |
| P2-23    | Add date + commit hash to `debug-map.md`                  | `821d829`                       |
| P2-24    | Add `homepage` URL to `emeet-pixyd` package meta          | Earlier session                 |
| P3-25–28 | Fix deadnix unused params (batches 1–4)                   | `f12e110`                       |
| P3-29    | Remove duplicate git global ignores                       | `f12e110`                       |
| P3-30    | Fix GPG program path cross-platform                       | `1181907`                       |
| P3-31    | Fix bash.nix history config + shopt                       | `1181907`                       |
| P3-32    | Fix Fish GOPATH init + fake variables                     | `1d09ab6`                       |
| P3-33    | Clean unfree allowlist                                    | `f12e110`                       |
| P4-34    | Create `lib/systemd.nix` shared helper                    | `d6e4b80`, refined in `1181907` |
| P4-36    | Convert niri session restore to `lib.mkOption`            | `1181907`                       |
| P6-54    | Twenty CRM backup rotation                                | `1181907`                       |
| P6-60    | Voice agents: remove unused `pipecatPort`                 | `f12e110`                       |
| P6-61    | Voice agents: remove dead PIDFile                         | `f12e110`                       |
| P6-62    | Hermes: add `WatchdogSec=30`                              | `1181907`                       |
| P7-69    | GitHub Actions CI workflow                                | Already existed                 |
| P7-72    | Fix eval smoke tests                                      | `8db683e`                       |
| P7-76    | Fix `LC_ALL` override redundancy                          | `1181907`                       |
| P7-77    | Remove `allowUnsupportedSystem`                           | Earlier session                 |
| P8-84    | Add `MANPAGER` and `VISUAL` env vars                      | `1181907`                       |

---

## B) PARTIALLY DONE ⚠️

| Task  | What's done                                                                                                                                    | What remains                                                                                                                                         |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1-7  | Taskwarrior sops wiring: secret defined in `sops.nix`, `extraSpecialArgs` in `flake.nix`, `taskwarrior.nix` reads from sops file with fallback | Actual encrypted secret file must be created on evo-x2: `sops platforms/nixos/secrets/secrets.yaml` and add `taskwarrior_sync_encryption_secret` key |
| P1-8  | Hardening added to gitea-ensure-repos                                                                                                          | Could be improved with `harden` helper from `lib/systemd.nix` (currently inline)                                                                     |
| P2-22 | Pre-commit statix hook investigated                                                                                                            | Root cause unclear, needs debugging on Linux                                                                                                         |

---

## C) NOT STARTED ⏳

### P0 — CRITICAL

| #    | Task                                      | Why it matters           |
| ---- | ----------------------------------------- | ------------------------ |
| P0-1 | `git push` — 3 unpushed commits           | Unpushed work can vanish |
| P0-2 | `git stash clear` — 4 stale stashes       | Orphaned cruft           |
| P0-3 | Delete 17 remote `copilot/fix-*` branches | Stale since April        |

### P1 — SECURITY

| #     | Task                                                                                   | Why it matters                  |
| ----- | -------------------------------------------------------------------------------------- | ------------------------------- |
| P1-9  | Pin Docker image digest for Voice Agents (`beecave/insanely-fast-whisper-rocm:latest`) | Silent breakage on redeploy     |
| P1-10 | Pin Docker image digest for PhotoMap (`lstein/photomapai:latest`)                      | Same issue                      |
| P1-11 | Secure VRRP `auth_pass` with sops-nix                                                  | Plaintext in `dns-failover.nix` |

### P2 — RELIABILITY

| #     | Task                       | Why it matters              |
| ----- | -------------------------- | --------------------------- |
| P2-22 | Fix pre-commit statix hook | Failed on wallpapers commit |

### P4 — ARCHITECTURE

| #        | Task                                                 | Why it matters                          |
| -------- | ---------------------------------------------------- | --------------------------------------- |
| P4-35    | Wire `preferences.nix` to GTK/Qt/cursor/font theming | Options declared, nothing consumes them |
| P4-37–40 | Add `options` + `mkIf` to 16 always-on modules       | No enable toggles                       |

### P5 — DEPLOYMENT (all require evo-x2 runtime)

| #        | Task                                                                  |
| -------- | --------------------------------------------------------------------- |
| P5-41    | `just switch` — deploy all pending changes                            |
| P5-42–49 | Verify Ollama, Steam, ComfyUI, Caddy, SigNoz, Authelia, PhotoMap, NPU |
| P5-50–53 | Pi 3 SD image build + flash + DNS failover test                       |

### P6 — SERVICES

| #        | Task                                                               |
| -------- | ------------------------------------------------------------------ |
| P6-55    | Twenty CRM: fix hardcoded container name `twenty-db-1`             |
| P6-56    | ComfyUI: replace hardcoded `/home/lars/projects/` paths            |
| P6-57    | ComfyUI: add `WatchdogSec` + `MemoryMax`                           |
| P6-58    | ComfyUI: run as dedicated system user                              |
| P6-59    | Voice agents: add health check for Whisper ASR                     |
| P6-63    | Hermes: migrate remaining providers to `key_env`                   |
| P6-64    | SigNoz: fix duplicate rules on reboot (already done in `d64125e`?) |
| P6-65    | SigNoz: add missing metrics for 10 services                        |
| P6-66    | Authelia: add SMTP notifications                                   |
| P6-67–68 | Backup restore tests for Immich + Twenty                           |

### P7 — TOOLING & CI

| #     | Task                                                        |
| ----- | ----------------------------------------------------------- |
| P7-70 | GitHub Actions: Go test for emeet-pixyd and dnsblockd       |
| P7-71 | GitHub Actions: flake.lock auto-update (Renovate)           |
| P7-73 | Consolidate duplicate justfile recipes                      |
| P7-74 | Replace `nixpkgs-fmt` with `nixfmt-rfc-style`               |
| P7-75 | Trim system monitors from 4 to 2                            |
| P7-78 | Setup Taskwarrior backup timer (already done in `20aaa6e`?) |

### P8 — DOCUMENTATION

| #     | Task                                                     |
| ----- | -------------------------------------------------------- |
| P8-79 | Update top-level `README.md`                             |
| P8-80 | Document DNS cluster in AGENTS.md                        |
| P8-81 | Write ADR for niri session restore                       |
| P8-82 | Add module option descriptions to 10 toggleable services |
| P8-83 | Create `docs/CONTRIBUTING.md`                            |

---

## D) TOTALLY FUCKED UP 💥

| Issue                                     | Severity    | Details                                                                                                                                                                                                 |
| ----------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Unpushed commits**                      | 🔴 CRITICAL | 3 commits ahead of origin. If this machine dies, work is lost. P0-1.                                                                                                                                    |
| **Taskwarrior sops incomplete**           | 🟡 MEDIUM   | Nix wiring exists but the actual encrypted secret file doesn't exist yet. Needs runtime action on evo-x2.                                                                                               |
| **Two `lib/systemd.nix` import patterns** | 🟡 MEDIUM   | `hermes.nix` uses `import ../../lib/systemd.nix` (simple function), but other services still have inline hardening. Should standardize — either all use `harden` helper or all inline. Currently mixed. |

---

## E) WHAT WE SHOULD IMPROVE 🔧

1. **Push more frequently** — 3 unpushed commits across a rebase is risky. Should push after every completed feature.
2. **Avoid rebasing unpushed work** — The rebase was necessary but created 10+ merge conflicts. Smaller, more frequent commits pushed immediately would avoid this.
3. **Standardize `lib/systemd.nix` usage** — `hermes.nix` uses `harden` helper, `voice-agents.nix` has inline values, other services have inline. Pick ONE pattern and apply everywhere.
4. **Test on Darwin before committing** — Several conflicts were about Darwin-specific paths (`/opt/homebrew/bin/gpg`). CI would catch this.
5. **Status doc proliferation** — 8 status docs in 24 hours. Should consolidate into one living doc.
6. **P5 tasks are all blocked** — Everything in P5 requires physical access to evo-x2. Consider SSH-based remote execution.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

| Rank | Task                                                                             | Priority | Est. | Why                                                                       |
| ---- | -------------------------------------------------------------------------------- | -------- | ---- | ------------------------------------------------------------------------- |
| 1    | **`git push --force-with-lease`**                                                | P0       | 1m   | 3 unpushed commits. DO THIS FIRST.                                        |
| 2    | **`git stash clear`**                                                            | P0       | 1m   | 4 stale stashes                                                           |
| 3    | **Delete remote `copilot/fix-*` branches**                                       | P0       | 2m   | `git branch -r \| grep copilot/fix \| xargs -n1 git push --delete origin` |
| 4    | **Create taskwarrior sops secret on evo-x2**                                     | P1       | 5m   | P1-7: `sops platforms/nixos/secrets/secrets.yaml`                         |
| 5    | **Pin Voice Agents Docker digest**                                               | P1       | 5m   | P1-9: Pull on evo-x2, get sha256                                          |
| 6    | **Pin PhotoMap Docker digest**                                                   | P1       | 5m   | P1-10: Pull on evo-x2, get sha256                                         |
| 7    | **Secure VRRP auth_pass with sops**                                              | P1       | 8m   | P1-11: Move plaintext to encrypted secret                                 |
| 8    | **Standardize `lib/systemd.nix` usage across all services**                      | P4       | 12m  | Mixed inline/helper pattern is inconsistent                               |
| 9    | **Wire `preferences.nix` to actual theming**                                     | P4       | 12m  | P4-35: Options declared but unconsumed                                    |
| 10   | **Add `options`+`mkIf` to batch 1 (sops, caddy, gitea, immich)**                 | P4       | 12m  | P4-37: No enable toggles                                                  |
| 11   | **Add `options`+`mkIf` to batch 2 (authelia, photomap, homepage, taskchampion)** | P4       | 12m  | P4-38                                                                     |
| 12   | **`just switch` on evo-x2**                                                      | P5       | 45m  | Deploy everything                                                         |
| 13   | **Verify Ollama + ROCm works**                                                   | P5       | 5m   | P5-42                                                                     |
| 14   | **Verify SigNoz collecting metrics**                                             | P5       | 5m   | P5-46                                                                     |
| 15   | **Fix Twenty CRM hardcoded container name**                                      | P6       | 5m   | P6-55: Fragile docker-compose name                                        |
| 16   | **ComfyUI: replace hardcoded paths**                                             | P6       | 12m  | P6-56: Not portable                                                       |
| 17   | **Add health check for Whisper ASR**                                             | P6       | 8m   | P6-59: No health check                                                    |
| 18   | **Hermes: migrate providers to `key_env`**                                       | P6       | 10m  | P6-63: Inline API keys                                                    |
| 19   | **GitHub Actions: Go test CI**                                                   | P7       | 10m  | P7-70: Go packages have tests, no CI                                      |
| 20   | **Replace `nixpkgs-fmt` with `nixfmt-rfc-style`**                                | P7       | 5m   | P7-74: Deprecated formatter                                               |
| 21   | **Update top-level README.md**                                                   | P8       | 12m  | P8-79: May be stale                                                       |
| 22   | **Document DNS cluster in AGENTS.md**                                            | P8       | 8m   | P8-80: Missing docs                                                       |
| 23   | **Write ADR for niri session restore**                                           | P8       | 10m  | P8-81: Complex system, no ADR                                             |
| 24   | **Build Pi 3 SD image**                                                          | P5       | 30m  | P5-50: Cross-compile                                                      |
| 25   | **Fix pre-commit statix hook**                                                   | P2       | 10m  | P2-22: Broken on wallpaper commits                                        |

---

## G) TOP QUESTION ❓

**Can you SSH into evo-x2 from this machine to run runtime tasks?**

Many tasks require evo-x2 access (sops secret creation, Docker digest pinning, `just switch`, service verification). If SSH access is available, I can execute P1-7, P1-9, P1-10, and P5-41 remotely. If not, these are all blocked on manual execution.

---

## Rebase Resolution Details

### Commit chain (post-rebase):

```
1181907 chore: cleanup, hardening, and cross-platform compatibility improvements  ← NEW
8ea8ac0 docs(status): full system status report (2026-04-25 04:36)               ← clean apply
f12e110 fix(security/reliability): systemd hardening, dead code removal, lint... ← conflict resolved
201a441 feat(theme): create shared theme.nix, wire to NixOS home.nix             ← rebase base
```

### Conflict resolution strategy:

- **lib/systemd.nix**: Simple function (19 lines) won over complex module (57 lines). Consistent with inline hardening already in services.
- **hermes.nix**: Uses `harden` helper from `lib/systemd.nix` as `import ../../lib/systemd.nix` at module level. Added `WatchdogSec=30`.
- **voice-agents.nix**: Inline hardening values (no helper import). Removed dead `mkHardenedServiceConfig`/`mkServiceRestartConfig` imports.
- **bash/fish/git**: Took c7ce2b6's improvements (globstar, nocaseglob, fish history, full gpg path) while preserving HEAD's structure.
- **flake.nix**: Kept HEAD's simple eval tests (echo only, no nix-instantiate dependency).
