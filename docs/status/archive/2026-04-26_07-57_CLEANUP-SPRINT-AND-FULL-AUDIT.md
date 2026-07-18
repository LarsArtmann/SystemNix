# Session Status: Cleanup Sprint + Full Project Audit

**Date:** 2026-04-26 07:57
**Session:** Continuation (session 5+)
**Branch:** `master` (synced with origin)
**State:** 3 uncommitted changes (justfile cleanup, monitor trim, pre-commit alias fix)

---

## Executive Summary

Pushed 6 previously-unpushed commits from prior sessions. Executed quick-win cleanup tasks: removed duplicate justfile aliases (`check-nix-syntax` → `validate`, `deploy` → `switch`), trimmed system monitors from 4 to 2 (`btop` + `bottom`). Ran comprehensive audit of all 96 MASTER_TODO_PLAN tasks against actual codebase — many tasks listed as "not started" are already done. Identified 2 stale remote branches and a handful of genuinely remaining tasks.

---

## A) FULLY DONE (Verified in codebase this session)

### Completed this session:

| #     | Task                                   | What was done                                                                                            |
| ----- | -------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| P0-1  | `git push`                             | Pushed 6 commits that were stranded locally across 4 prior sessions                                      |
| P7-73 | Consolidate duplicate justfile recipes | Removed `check-nix-syntax` alias (pre-commit now uses `validate`), removed `deploy` alias (use `switch`) |
| P7-75 | Trim system monitors 4→2               | Removed `htop` and `procs`, kept `btop` (best TUI) + `bottom` (Rust, charts)                             |

### Already done (verified by codebase audit — was incorrectly listed as "not started"):

| #     | Task                                     | Evidence                                                                                                                                                                                |
| ----- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P2-16 | Fix 3 dead `let` bindings                | `appSecretFile`, `pgPasswordFile`, `addIPScript`, `poetry` — none exist in current code. All `let` bindings in twenty.nix, dns-blocker-config.nix, aw-watcher-utilization.nix are used. |
| P2-17 | Fix git.nix `core.pager` vs `pager.diff` | No `core.pager` exists. Only `pager.diff = "bat"` at git.nix:75. Clean.                                                                                                                 |
| P2-22 | Fix pre-commit statix hook               | Statix IS in `.pre-commit-config.yaml:38-41` and working. Was never broken.                                                                                                             |
| P2-23 | Add date + commit hash to debug-map.md   | Already present: `**Date:** 2026-04-25                                                                                                                                                  | **Commit:** 0a3c318` at line 3. |
| P2-24 | Add homepage URL to emeet-pixyd meta     | Already present: `homepage = "https://github.com/LarsArtmann/SystemNix/tree/master/pkgs/emeet-pixyd"` at pkgs/emeet-pixyd.nix:22.                                                       |
| P3-29 | Remove duplicate git global ignores      | No duplicates found in current git.nix ignores list. All entries unique.                                                                                                                |
| P3-30 | Fix GPG path cross-platform              | Already cross-platform: `if pkgs.stdenv.isDarwin then "/opt/homebrew/bin/gpg" else "/run/current-system/sw/bin/gpg"` at git.nix:55-58.                                                  |
| P3-33 | Clean unfree allowlist                   | `castlabs-electron` and `cursor` already removed. `signal-desktop-bin` correctly remains — it IS installed (home.nix:128).                                                              |
| P6-54 | Twenty CRM backup rotation               | Already includes `find ${stateDir}/backup -name "*.sql" -mtime +30 -delete` in backup script.                                                                                           |
| P6-55 | Twenty hardcoded container name          | Already uses compose service name `db`, not hardcoded `twenty-db-1`.                                                                                                                    |
| P6-57 | ComfyUI WatchdogSec + MemoryMax          | `WatchdogSec = "60"`, `MemoryMax = "8G"` present.                                                                                                                                       |
| P6-60 | Voice agents unused `pipecatPort`        | Does not exist in current voice-agents.nix. Already removed.                                                                                                                            |
| P6-61 | Voice agents PIDFile cleanup             | No `PIDFile` reference in voice-agents.nix. Already removed.                                                                                                                            |
| P6-62 | Hermes health check                      | `WatchdogSec = "30"` present at hermes.nix:169.                                                                                                                                         |
| P6-64 | SigNoz duplicate rules on reboot         | Uses idempotent delete-by-name-then-POST pattern. Already fixed.                                                                                                                        |
| P7-72 | Fix eval smoke tests (`                  |                                                                                                                                                                                         | true`)                          | Eval smoke tests (flake.nix:355-363) have NO ` |     | true`. The 3 remaining ` |     | true` are in deploy/diagnostics apps — acceptable. |
| P8-84 | MANPAGER + VISUAL env vars               | Both set: `MANPAGER` (bat-based) and `VISUAL` (code --wait) in home-base.nix:47-48.                                                                                                     |

### Previously done (confirmed in prior session reports):

| #     | Task                                                 |
| ----- | ---------------------------------------------------- |
| P0-2  | Clear stale git stashes                              |
| P0-3  | Delete remote copilot branches                       |
| P0-4  | Archive old status docs                              |
| P0-5  | Rewrite status README                                |
| P0-6  | Fix "29 modules" → correct count                     |
| P1-8  | Add systemd hardening to gitea-ensure-repos          |
| P1-12 | Remove dead ublock-filters module                    |
| P1-13 | Fix gitea-ensure-repos Restart + StartLimitBurst     |
| P2-14 | WatchdogSec for caddy, gitea, authelia, taskchampion |
| P2-15 | Restart=on-failure for services                      |
| P2-18 | Fix fonts.packages darwin compat                     |
| P2-19 | Enable udisks2 on NixOS                              |
| P2-20 | Add .editorconfig                                    |
| P2-21 | Make deadnix check strict (`--fail`)                 |
| P3-31 | Fix bash.nix history config + shopt                  |
| P3-32 | Fix Fish fake variables                              |
| P3-34 | Create lib/systemd.nix shared helper                 |
| P7-69 | GitHub Actions nix-check on push                     |
| P7-74 | Replace nixpkgs-fmt with alejandra                   |
| P7-76 | Fix LC_ALL override                                  |
| P7-77 | Remove allowUnsupportedSystem                        |
| P7-78 | Taskwarrior backup timer                             |

---

## B) PARTIALLY DONE

| #     | Task                                           | Status                                                             | What remains                                                                                                                                                                                                               |
| ----- | ---------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1-7  | Move Taskwarrior encryption secret to sops     | Nix wiring done (sops.nix, taskwarrior.nix reference sops secrets) | Actual sops-encrypted file must be created on evo-x2: `sops platforms/nixos/secrets/secrets.yaml`                                                                                                                          |
| P4-35 | Wire preferences.nix to GTK/cursor theming     | Options declared in preferences.nix                                | No consumers on NixOS — GTK/cursor/font theme not wired to actual settings                                                                                                                                                 |
| P4-36 | Convert niri session restore to module options | Some `let` block extracted                                         | Not proper NixOS module options yet                                                                                                                                                                                        |
| P8-84 | MANPAGER/VISUAL env vars                       | Both set                                                           | Conflicting values: `variables.nix` sets `VISUAL="micro"` / `MANPAGER="less -R"`, `home-base.nix` overrides to `VISUAL="code --wait"` / `MANPAGER="bat-based"`. HM wins at runtime, but two sources of truth is confusing. |

---

## C) NOT STARTED (Genuinely remaining)

### Security:

| #     | Task                                  | Est. | Notes                                                                                                                                                                                                               |
| ----- | ------------------------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1-9  | Pin Docker image digest: Voice Agents | 5m   | Need sha256 from evo-x2 docker daemon                                                                                                                                                                               |
| P1-10 | Pin Docker image digest: PhotoMap     | 5m   | Need sha256 from evo-x2 docker daemon                                                                                                                                                                               |
| P1-11 | Secure VRRP auth_pass with sops       | 8m   | `dns-failover.nix:44` defaults to plaintext `"DNSClusterVRRP"`. Complex: Keepalived config is build-time, can't directly use sops runtime secrets. Need to generate a sops template or use environmentFile pattern. |

### Architecture (17 modules without enable toggles):

| #     | Task                                                                        | Est. |
| ----- | --------------------------------------------------------------------------- | ---- |
| P4-37 | Add enable toggles: sops, caddy, gitea, immich                              | 12m  |
| P4-38 | Add enable toggles: authelia, photomap, homepage, taskchampion              | 12m  |
| P4-39 | Add enable toggles: display-manager, audio, niri-config, security-hardening | 12m  |
| P4-40 | Add enable toggles: monitoring, multi-wm, chromium-policies, steam          | 12m  |

### Services improvements:

| #     | Task                                                                  | Est. |
| ----- | --------------------------------------------------------------------- | ---- |
| P6-56 | ComfyUI hardcoded paths (`/home/lars/projects/anime-comic-pipeline/`) | 12m  |
| P6-58 | ComfyUI run as system user (not `lars`)                               | 8m   |
| P6-59 | Voice agents health check                                             | 8m   |
| P6-63 | Hermes migrate remaining providers to `key_env`                       | 10m  |
| P6-65 | SigNoz missing metrics for 10 services                                | 12m  |
| P6-66 | Authelia SMTP notifications                                           | 10m  |
| P6-67 | Immich backup restore test                                            | 12m  |
| P6-68 | Twenty backup restore test                                            | 12m  |

### Tooling/CI:

| #     | Task                                                   | Est. |
| ----- | ------------------------------------------------------ | ---- |
| P7-70 | GitHub Actions: Go test CI for emeet-pixyd + dnsblockd | 10m  |
| P7-71 | GitHub Actions: flake.lock auto-update (Renovate/Deps) | 10m  |

### Documentation:

| #     | Task                               | Est. |
| ----- | ---------------------------------- | ---- |
| P8-79 | Update top-level README            | 12m  |
| P8-80 | Document DNS cluster in AGENTS.md  | 8m   |
| P8-81 | Write ADR for niri session restore | 10m  |
| P8-82 | Add module option descriptions     | 10m  |
| P8-83 | Create CONTRIBUTING.md             | 12m  |

### Deployment/Verification (requires evo-x2 runtime):

| #        | Task                                                                  |
| -------- | --------------------------------------------------------------------- |
| P5-41    | `just switch` — deploy all pending changes                            |
| P5-42-49 | Verify Ollama, Steam, ComfyUI, Caddy, SigNoz, Authelia, PhotoMap, NPU |
| P5-50-53 | Pi 3: build SD image, flash, test DNS failover, configure LAN devices |

### Research/Future (deferred):

P9-85 through P9-96: All deferred. Includes hipblaslt race investigation, lldap/Kanidm, ComfyUI packaging, VM tests, binary cache.

---

## D) TOTALLY FUCKED UP

| What                                                                     | Impact                                                                                                         | Root Cause                                                                             | Status                                                 |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| 2 stale remote branches (`feature/nushell-configs`, `organize-packages`) | 1600+ commits behind master, confusing `git branch -r` output                                                  | Leftover from pre-niri experiments                                                     | **Not yet cleaned** — needs `git push --delete origin` |
| Conflicting VISUAL/MANPAGER in two files                                 | `variables.nix` sets `micro`+`less`, `home-base.nix` overrides to `code --wait`+`bat`. HM wins, but confusing. | Two sources of truth for same env vars                                                 | Low priority, but worth consolidating                  |
| VRRP auth_pass plaintext in dns-failover.nix                             | Password `"DNSClusterVRRP"` is public in repo. Anyone with repo access can spoof VRRP on the LAN.              | Keepalived config is build-time, sops secrets are runtime — integration is non-trivial | **Security concern** — needs architecture decision     |
| No CI for Go packages                                                    | emeet-pixyd and dnsblockd have real tests but no GitHub Actions to run them                                    | Never set up                                                                           | Tests only run locally on demand                       |

---

## E) WHAT WE SHOULD IMPROVE

1. **The MASTER_TODO_PLAN is stale** — At least 17 tasks listed as "not started" are already done. The plan needs a reconciliation pass to reflect reality. Continuing to work from it wastes verification time.

2. **Two sources of truth for env vars** — `variables.nix` and `home-base.nix` both set `VISUAL`/`MANPAGER` to different values. Consolidate: remove the system-level ones and keep only the HM `sessionVariables`.

3. **17 modules still have no enable toggle** — These can never be disabled without editing source. The pattern exists (9 modules already have `mkEnableOption`), just needs rollout.

4. **VRRP auth needs architecture decision** — Keepalived reads its config at build-time from Nix. sops-nix decrypts at activation time. The standard approach is either: (a) accept the low-risk of plaintext VRRP password (LAN-only, not internet-facing), or (b) use a sops template + `environmentFile` approach. This needs a conscious choice, not an AI guess.

5. **Remote branch hygiene** — 2 stale branches (`feature/nushell-configs`, `organize-packages`) should be deleted. They're 1600+ commits behind.

6. **ComfyUI hardcoded paths** — `/home/lars/projects/anime-comic-pipeline/` is hardcoded in comfyui.nix. This should be a module option with a sensible default. Not urgent but architecturally wrong.

7. **Docker image pinning still not done** — P1-9 and P1-10 require access to evo-x2's Docker daemon to get current digests. Simple 5-minute task that's been deferred across multiple sessions because it requires runtime access.

---

## F) TOP 25 THINGS TO DO NEXT

Sorted by impact × effort (highest first):

| Rank | #     | Task                                                                        | Est. | Why                                                                  |
| ---- | ----- | --------------------------------------------------------------------------- | ---- | -------------------------------------------------------------------- |
| 1    | —     | **Delete 2 stale remote branches**                                          | 1m   | `git push --delete origin feature/nushell-configs organize-packages` |
| 2    | —     | **Consolidate VISUAL/MANPAGER to single source**                            | 2m   | Remove from `variables.nix`, keep HM `sessionVariables`              |
| 3    | P4-37 | Add enable toggles: sops, caddy, gitea, immich                              | 12m  | Core services should be toggleable                                   |
| 4    | P4-38 | Add enable toggles: authelia, photomap, homepage, taskchampion              | 12m  | Continue toggle rollout                                              |
| 5    | P4-39 | Add enable toggles: display-manager, audio, niri-config, security-hardening | 12m  | Continue toggle rollout                                              |
| 6    | P4-40 | Add enable toggles: monitoring, multi-wm, chromium-policies, steam          | 12m  | Finish toggle rollout                                                |
| 7    | P7-70 | Add Go test CI for emeet-pixyd + dnsblockd                                  | 10m  | Real tests, no CI                                                    |
| 8    | P7-71 | Add flake.lock auto-update CI                                               | 10m  | Automate manual `just update`                                        |
| 9    | P6-56 | ComfyUI hardcoded paths → module options                                    | 12m  | Violates Nix philosophy                                              |
| 10   | P1-9  | Pin Docker image: Voice Agents                                              | 5m   | Security — needs evo-x2                                              |
| 11   | P1-10 | Pin Docker image: PhotoMap                                                  | 5m   | Security — needs evo-x2                                              |
| 12   | P1-11 | Secure VRRP auth_pass                                                       | 8m   | Needs architecture decision first                                    |
| 13   | P6-58 | ComfyUI run as system user                                                  | 8m   | Currently runs as `lars`                                             |
| 14   | P6-63 | Hermes migrate providers to `key_env`                                       | 10m  | API keys inline in config                                            |
| 15   | P6-59 | Voice agents health check                                                   | 8m   | No health check defined                                              |
| 16   | P6-65 | SigNoz missing metrics for 10 services                                      | 12m  | Major observability gap                                              |
| 17   | P8-80 | Document DNS cluster in AGENTS.md                                           | 8m   | Important infra undocumented                                         |
| 18   | P8-81 | Write ADR for niri session restore                                          | 10m  | Complex system, no design record                                     |
| 19   | P8-79 | Update top-level README                                                     | 12m  | Stale since niri migration                                           |
| 20   | P6-66 | Authelia SMTP notifications                                                 | 10m  | Writes to file, no email                                             |
| 21   | P6-67 | Immich backup restore test                                                  | 12m  | Backups exist, never verified                                        |
| 22   | P6-68 | Twenty backup restore test                                                  | 12m  | Same — verify restorability                                          |
| 23   | P8-82 | Add module option descriptions                                              | 10m  | `mkEnableOption` should have meaningful text                         |
| 24   | P8-83 | Create CONTRIBUTING.md                                                      | 12m  | AGENTS.md is AI-focused                                              |
| 25   | P5-41 | `just switch` on evo-x2                                                     | 45m+ | Deploy all accumulated changes                                       |

---

## G) TOP #1 QUESTION

**P1-9/P1-10 (Docker image digest pinning):** The Voice Agents and PhotoMap services reference Docker images by tag (`latest`). To pin digests, I need the actual sha256 digests from evo-x2's Docker daemon. This can only be done on the NixOS machine:

```bash
# On evo-x2:
docker pull beecave/insanely-fast-whisper-rocm:latest
docker inspect --format='{{index .RepoDigests 0}}' beecave/insanely-fast-whisper-rocm:latest

docker pull lstein/photomapai:latest
docker inspect --format='{{index .RepoDigests 0}}' lstein/photomapai:latest
```

Can you run these on evo-x2 and share the digest strings? Without them, I cannot pin the images.

---

## Git State

```
Uncommitted (3 files):
  .pre-commit-config.yaml    — changed check-nix-syntax → validate
  justfile                    — removed check-nix-syntax and deploy aliases
  platforms/common/packages/base.nix — trimmed htop + procs

Remote: synced with origin/master
Stashes: empty
Stale remote branches: feature/nushell-configs, organize-packages
```

## Audit Summary (96 total tasks)

| Status             | Count   | Tasks                                                                                                                                      |
| ------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **DONE**           | **~40** | P0-1,2,3,4,5,6, P1-8,12,13, P2-14,15,16,17,18,19,20,21,22,23,24, P3-29,30,31,32,33,34, P6-54,55,57,60,61,62,64, P7-69,72,73,74,75,76,77,78 |
| **PARTIALLY DONE** | **4**   | P1-7, P4-35, P4-36, P8-84                                                                                                                  |
| **NOT STARTED**    | **~40** | P1-9,10,11, P4-37-40, P6-56,58,59,63,65,66,67,68, P7-70,71, P8-79,80,81,82,83, P5-41-53                                                    |
| **FUTURE**         | **12**  | P9-85-96                                                                                                                                   |
