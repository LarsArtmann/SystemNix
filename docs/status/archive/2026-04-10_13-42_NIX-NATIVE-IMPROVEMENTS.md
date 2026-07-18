# Nix-Native Improvement Session — 2026-04-10

## Session Summary

Systematic audit and improvement of SystemNix to be more Nix-native.
6 commits, all passing lint + flake check.

## Changes Completed

### 1. Dead Code Removal

| File                                   | What                                                                 | Why                                                                                                          |
| -------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `platforms/nixos/desktop/ai-stack.nix` | Removed `ollama-permissions` oneshot service (18 lines)              | Completely superseded by `systemd.tmpfiles.rules` which creates the same dirs with correct ownership at boot |
| `flake.nix`                            | Fixed dead code in overlays (`_final`, `_` prefix for unused params) | deadnix caught unused lambda args                                                                            |
| `flake.nix`                            | Removed unused input destructuring (silent-sddm, signoz-src, etc.)   | Accessed via `inputs.*` attrset, not destructured bindings                                                   |
| `flake.nix`                            | Simplified home-manager user definitions to `{...}:`                 | Params were destructured but never used (imports handle everything)                                          |

### 2. Package Deduplication

| Package        | Removed From                         | Why                                                                        |
| -------------- | ------------------------------------ | -------------------------------------------------------------------------- |
| `starship`     | `platforms/common/packages/base.nix` | `programs.starship.enable = true` in HM module handles install + config    |
| `taskwarrior3` | `platforms/common/packages/base.nix` | `programs.taskwarrior.enable = true` in HM module handles install + config |
| `timewarrior`  | `platforms/common/packages/base.nix` | Installed as dependency of `programs.taskwarrior`                          |

### 3. Script Deduplication

| What                             | Action                                                                                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/blocklist-hash-updater` | Removed (had hardcoded absolute paths). Canonical version at `platforms/nixos/scripts/blocklist-hash-updater` (relative paths, used by `scheduled-tasks.nix`) |

### 4. Flake Apps (NEW)

| App               | Command                     | Description                              |
| ----------------- | --------------------------- | ---------------------------------------- |
| `deploy`          | `nix run .#deploy`          | Deploy NixOS config via `nh os switch .` |
| `validate`        | `nix run .#validate`        | Run `nix flake check --no-build`         |
| `dns-diagnostics` | `nix run .#dns-diagnostics` | DNS stack health check (Linux only)      |

Previously these were only accessible via justfile. Now discoverable via `nix flake show`.

### 5. Flake Checks (NEW)

| Check             | Strictness                        | What                             |
| ----------------- | --------------------------------- | -------------------------------- |
| `statix`          | Fails on anti-patterns            | Lints all Nix code               |
| `deadnix`         | Advisory (reports, doesn't block) | Unused bindings and lambda args  |
| `nix-eval-darwin` | Smoke test                        | Verifies darwin config evaluates |
| `nix-eval-nixos`  | Smoke test (Linux only)           | Verifies NixOS config evaluates  |

Previously `nix flake check` only validated Nix syntax. Now it catches lint issues.

### 6. Justfile: nh Migration

Replaced all `sudo nixos-rebuild` calls with `nh os` equivalents:

- `switch` → `nh os switch . -- --print-build-logs`
- `deploy` → `nh os switch .`
- `test` → `nh os test .`
- `rollback` → `nh os switch . -- --rollback`
- `tmux-setup` → `nh os switch .`

Darwin commands unchanged (`nh darwin switch` is broken on macOS).

### 7. Deploy Script Fix

Fixed `scripts/deploy-evo-x2.sh` interface check from `enp1s0` → `eno1` (matches actual hardware).

## Not Done (Future Work)

| Priority | Task                                                                                        | Effort | Risk                                       |
| -------- | ------------------------------------------------------------------------------------------- | ------ | ------------------------------------------ |
| P1       | Replace custom `homepage-dashboard` systemd with `services.homepage-dashboard` NixOS module | Medium | Medium (config mapping needed)             |
| P1       | Replace custom `immich-db-backup` with `services.postgresqlBackup`                          | Low    | Medium (different backup semantics)        |
| P2       | Extract overlays from flake.nix to `overlays/` directory                                    | Medium | Low                                        |
| P2       | Expose overlays via `flake.overlays` output                                                 | Low    | Low                                        |
| P2       | Remove `git` from base.nix (HM module handles it)                                           | Low    | Low (system-level git useful for recovery) |
| P2       | Fix pre-existing deadnix warnings (poetry, cfg, addIPScript, etc.)                          | Low    | Low                                        |
| P3       | Convert test scripts to `flake.checks` derivations                                          | Medium | Low                                        |
| P3       | Replace cleanup scripts with `systemd.tmpfiles` + timers                                    | High   | Medium                                     |

## Pre-existing Deadnix Warnings (Not Fixed)

```
modules/nixos/services/caddy.nix:23 - unused param `subdomain` in protectedVHost
pkgs/aw-watcher-utilization.nix:2 - unused `poetry` in inherit
platforms/common/programs/keepassxc.nix:7 - unused let binding `cfg`
platforms/darwin/default.nix:67-68 - unused `final`, `oldAttrs` in overlay
platforms/nixos/desktop/ai-stack.nix:25 - unused `old` in ollama override
platforms/nixos/modules/dns-blocker.nix:288 - unused let binding `addIPScript`
```

## Top Question for User

The homepage module (`modules/nixos/services/homepage.nix`) manually creates a systemd service when `services.homepage-dashboard` exists in nixpkgs. However, the custom module includes extensive config generation (services.yaml with all service URLs, settings.yaml, widgets). Should we migrate to the nixpkgs module and map the existing config, or keep the custom module since it works well?
