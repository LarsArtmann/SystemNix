# SystemNix Nix Codebase Review

**Date:** 2026-05-03 | **Scope:** Full repo (98 Nix files, 13,233 LOC) | **Verdict: Strong B+**

---

## Executive Summary

SystemNix is an **impressive, ambitious** Nix configuration managing two machines (macOS + NixOS) through a single flake with ~80% code sharing. The architecture is well-reasoned, the service modules are production-grade, and the tooling (statix, deadnix, treefmt, flake check) all pass clean. This is clearly the work of someone who has invested serious effort into learning Nix properly.

The review below is structured as: what's genuinely excellent, what's good-but-could-be-better, and what are real problems worth fixing — ordered by impact.

---

## 1. What You Do Well

### 1.1 flake-parts Module Architecture ★★★★★

Your service modules in `modules/nixos/services/` are a **textbook example** of the dendritic/flake-parts pattern:

- Every module defines `flake.nixosModules.<name>` — consistent, discoverable
- 50 `mkEnableOption` calls, 122 `mkOption` definitions, 97 typed option declarations across the codebase
- Proper `lib.mkIf cfg.enable` gating (not just `enable = true`)
- SigNoz module (741 lines) is **exceptional**: proper `types.submodule` options, component toggling, declarative alert rules, YAML generation, per-component `mkMerge`
- `lib/systemd.nix` + `lib/systemd/service-defaults.nix` — reusable, composable, well-documented

### 1.2 Cross-Platform Sharing ★★★★★

The `platforms/common/` architecture is the **best part** of this repo:

- 14 Home Manager program modules shared verbatim between Darwin and NixOS
- `platforms/common/preferences.nix` — centralized theme option system with typed options
- Platform differences handled via `mkIf stdenv.isLinux/isDarwin`, `mkForce`, `mkAfter`
- `sharedHomeManagerConfig` and `sharedHomeManagerSpecialArgs` in flake.nix eliminate duplication
- The `home-manager.users.<name>` pattern with thin per-platform `home.nix` wrappers is clean

### 1.3 Security Hardening ★★★★☆

- Every service uses the `harden` library from `lib/systemd.nix`
- Proper `ProtectHome`, `NoNewPrivileges`, `PrivateTmp`, `MemoryMax` throughout
- sops-nix with age (SSH host key) for all secrets
- Authelia SSO with TOTP, WebAuthn, OIDC for Immich + Gitea
- DNS failover with VRRP health checks
- fail2ban with jail configuration
- The `WatchdogSec` documentation in AGENTS.md is excellent — prevents a class of silent failures

### 1.4 Tooling & CI ★★★★☆

- `statix` and `deadnix` both pass clean (zero warnings)
- `nix flake check --no-build` passes
- treefmt + alejandra via `treefmt-full-flake`
- GitHub Actions: `flake-update.yml`, `go-test.yml`, `nix-check.yml`
- `devShells.default` with all necessary tools pre-loaded
- `perSystem.checks` for statix and deadnix

### 1.5 Domain-Specific Excellence ★★★★★

Several modules show deep domain expertise:

- **Niri session save/restore** (`niri-wrapped.nix`, 872 lines) — crash recovery with workspace-aware restore, floating state, column widths, focus order, JSON validation, configurable fallback
- **NixOS DNS blocker** — Unbound + dnsblockd + 25 blocklists + 2.5M domains + Quad9 DoT + local DNS records
- **AI stack** — ROCm GPU, llama-cpp with ROCwMMa patches, centralized model storage
- **Gitea** — declarative repo mirroring, API token generation, runner registration, all idempotent
- **Minecraft** — JVM tuning (ZGC), FOV/volume conversion functions, Prism Launcher integration

---

## 2. Issues Worth Fixing (Prioritized)

### P0: Real Problems

#### 2.1 ComfyUI Path Literals Will Copy to Nix Store

**File:** `modules/nixos/services/comfyui.nix:38,44`

```nix
package = lib.mkOption {
  type = lib.types.path;
  default = /home/lars/projects/anime-comic-pipeline/ComfyUI;  # ← COPIES ENTIRE DIR TO STORE
};
venvPython = lib.mkOption {
  default = "/home/lars/projects/anime-comic-pipeline/venv/bin/python";
};
```

`package` uses `types.path` with a path literal — Nix copies the **entire** ComfyUI directory (GB of models, checkpoints, Python packages) into the Nix store on every `nix eval`. This likely causes multi-minute evaluation hangs and enormous `/nix/store` growth.

**Fix:** Use `types.str` and string paths for mutable, on-disk locations:
```nix
type = lib.types.str;
default = "/home/lars/projects/anime-comic-pipeline/ComfyUI";
```

#### 2.2 Hardcoded `/home/lars` Paths in Module Defaults

**Files:** `monitor365.nix:121`, `file-and-image-renamer.nix:27,33,39`

These modules use hardcoded absolute paths instead of deriving from the user's home directory:
```nix
default = "/home/lars/.local/share/monitor365";
default = "/home/lars/Desktop";
```

**Fix:** Derive from `config.users.users.${cfg.user}.home`:
```nix
default = config.users.users.${cfg.user}.home + "/.local/share/monitor365";
```

#### 2.3 Hermes `chmod g+rwx /home/lars` in Activation Script

**File:** `modules/nixos/services/hermes.nix:131-132`

```nix
if [ -d /home/lars ]; then
  chmod g+rwx /home/lars
```

This makes the entire home directory group-writable every rebuild. Any process in the `users` group can modify `~/.ssh`, `~/.config`, etc.

**Fix:** Use ACLs for targeted access, or a dedicated shared directory, or add Hermes to a specific group with targeted group ownership on needed paths.

### P1: Architecture Improvements

#### 2.4 Inconsistent Option Naming Convention

Module options use three different naming conventions:

| Convention | Examples |
|---|---|
| `services.<name>.enable` | signoz, homepage, hermes, ai-models, comfyui, voice-agents |
| `services.<name>-config.enable` | sops, taskchampion, authelia, monitoring |
| No custom options at all | caddy, gitea, immich (piggyback on nixpkgs options) |

**Fix:** Adopt one convention. Recommended: `services.<name>.enable` (no suffix) for all modules. The `-config` suffix adds no value and creates inconsistency.

#### 2.5 `configuration.nix` Is a Monolith (288 lines)

**File:** `platforms/nixos/system/configuration.nix`

This file imports modules, enables services, configures users, sets up OBS, fail2ban, Minecraft, Gitea repos, smartd, and color schemes. It's doing too much.

**Fix:** Split into:
- `system/core.nix` (users, nix settings, imports)
- `system/services.nix` (service enable toggles)
- Hardware, gaming, AI stack are already split — good

#### 2.6 Duplicated ROCm Configuration

**Files:** `ai-stack.nix`, `comfyui.nix`

`rocmRuntimeLibs` and `rocmEnv` are copy-pasted with minor differences:
```nix
# ai-stack.nix
rocmRuntimeLibs = [ pkgs.rocmPackages.clr pkgs.rocmPackages.rocblas ... ];

# comfyui.nix
rocmRuntimeLibs = [ pkgs.rocmPackages.clr pkgs.rocmPackages.rocblas ... ];  # same list
```

**Fix:** Extract to `lib/rocm.nix` or a shared `lib/ai.nix`:
```nix
# lib/rocm.nix
{ pkgs }: {
  runtimeLibs = with pkgs.rocmPackages; [ clr rocblas ... ];
  env = { HSA_OVERRIDE_GFX_VERSION = "11.0.0"; ... };
}
```

#### 2.7 DRY Violation: Shell Aliases

**Files:** `platforms/darwin/programs/shells.nix`, `platforms/nixos/programs/shells.nix`

Aliases `nixup`, `nixbuild`, `nixcheck` are copy-pasted across Fish, Zsh, and Bash in both Darwin and NixOS.

**Fix:** Define once in `common/programs/shell-aliases.nix` and consume everywhere. The `common/programs/shell-aliases.nix` already exists for shared aliases — extend it.

#### 2.8 Theme Data Duplication: `theme.nix` vs `preferences.nix`

**Files:** `platforms/common/theme.nix`, `platforms/common/preferences.nix`

Both define the same Catppuccin Mocha defaults (variant, accent, density, fonts, cursor). `preferences.nix` is an option system; `theme.nix` is hardcoded values.

**Fix:** `theme.nix` should consume `config.preferences.appearance` instead of duplicating the values. Or remove `theme.nix` entirely and have callers reference `preferences` + `nix-colors.colorSchemes`.

### P2: Quality Improvements

#### 2.9 Color Scheme Dead Defaults

**Files:** `platforms/darwin/default.nix`, `platforms/nixos/system/configuration.nix`

```nix
options.colorScheme = lib.mkOption { default = nix-colors.colorSchemes.catppuccin-mocha; };
config.colorScheme = nix-colors.colorSchemes.catppuccin-mocha;  # overrides the default
```

The `options.default` is dead code — `config` always overrides it. The `options.default` references `config.preferences.appearance.colorSchemeName` which would be more flexible, but is never actually used.

**Fix:** Remove the `config.colorScheme` override and let the option default (from `preferences`) take effect, or use `config.preferences.appearance.colorSchemeName` to look up the scheme.

#### 2.10 Taskwarrior Systemd Services Missing Linux Guard

**File:** `platforms/common/programs/taskwarrior.nix`

`systemd.user.services` and `systemd.user.timers` are Linux-only (systemd) but have no `lib.mkIf pkgs.stdenv.isLinux` guard. On macOS, these silently fail or create noise.

**Fix:**
```nix
systemd.user = lib.mkIf pkgs.stdenv.isLinux { services = ...; timers = ...; };
```

#### 2.11 Ports as Magic Numbers

**Files:** `caddy.nix`, `signoz.nix`, `homepage.nix`

Caddy references ports from 9+ other services as hardcoded integers (`9091`, `3000`, `8082`, etc.). If any service changes its port, Caddy breaks silently.

**Fix:** Either:
1. Define port constants in a shared module (`modules/ports.nix`)
2. Reference other services' port options via `config.services.<name>.port` (requires adding port options to those modules)

#### 2.12 DNS Blocklist Processing Duplication

**Files:** `platforms/nixos/modules/dns-blocker.nix`, `platforms/nixos/rpi3/default.nix`

The RPi3 config duplicates the blocklist processing logic (build-time `runCommand` with hash combining) instead of reusing the `dns-blocker` module.

**Fix:** The RPi3 should import `inputs.self.nixosModules.dns-blocker` or a shared blocklist processing function.

#### 2.13 Secret Management Scattered

**Files:** `sops.nix` (centralized), `voice-agents.nix` (inline sops secrets)

Most secrets live in `modules/nixos/services/sops.nix`, but `voice-agents.nix` defines its own `sops.secrets` and `sops.templates` inline.

**Fix:** Move voice-agent secrets to `sops.nix` for consistency.

#### 2.14 `file-and-image-renamer` Dead Code

**File:** `modules/nixos/services/file-and-image-renamer.nix:52-76`

The `watch-wrapper.sh` script is written to disk but **never used** — the service calls `file-renamer watch` directly without the wrapper. The wrapper also has a mismatched API key env var (`ZAI_API_KEY_FILE` vs `ZAI_API_KEY`).

**Fix:** Remove the dead wrapper, or fix the API key integration if it's needed.

#### 2.15 Steam Package Duplication

**File:** `modules/nixos/services/steam.nix`

`programs.steam.enable = true` already installs Steam to the system profile, but `environment.systemPackages` also includes `pkgs.steam` — redundant.

**Fix:** Remove `pkgs.steam` from `environment.systemPackages`.

---

## 3. Metrics Summary

| Metric | Value | Assessment |
|---|---|---|
| Total Nix files | 98 | — |
| Total LOC | 13,233 | — |
| Flake inputs | 33 | High but justified |
| NixOS service modules | 28 | Excellent modularity |
| Custom `mkOption` definitions | 122 | Strong typing |
| `mkEnableOption` usage | 50 | Good toggle pattern |
| Typed options (`lib.types.*`) | 97 | Excellent |
| statix warnings | 0 | Clean |
| deadnix warnings | 0 | Clean |
| `nix flake check --no-build` | ✅ Passes | Good |
| Largest file | `niri-wrapped.nix` (872 lines) | Should split |
| Hardcoded `/home/lars` paths | 9 | Needs fixing |
| Cross-platform share ratio | ~80% | Excellent |

---

## 4. Recommended Action Plan (Pareto-Ordered)

| Priority | Task | Impact | Effort |
|---|---|---|---|
| **P0** | Fix ComfyUI `types.path` → `types.str` | Prevents store explosion | 5 min |
| **P0** | Fix hardcoded `/home/lars` in module defaults | Reusability, correctness | 30 min |
| **P0** | Fix Hermes `chmod g+rwx` | Security | 30 min |
| **P1** | Standardize option naming convention | Consistency | 2 hr |
| **P1** | Extract shared ROCm config to `lib/rocm.nix` | DRY, maintainability | 1 hr |
| **P1** | Centralize port definitions | Prevents silent breakage | 2 hr |
| **P1** | Unify shell aliases across platforms | DRY | 1 hr |
| **P1** | Deduplicate `theme.nix` → `preferences.nix` | Single source of truth | 1 hr |
| **P2** | Add Linux guards to taskwarrior systemd | Correctness on macOS | 15 min |
| **P2** | Move voice-agent secrets to `sops.nix` | Consistency | 30 min |
| **P2** | Remove dead code (watch-wrapper, steam dup) | Cleanliness | 15 min |
| **P2** | Split `configuration.nix` monolith | Maintainability | 2 hr |
| **P2** | Split `niri-wrapped.nix` (872 lines) | Maintainability | 2 hr |
| **P2** | Reuse dns-blocker module in rpi3 | DRY | 1 hr |

---

## 5. Comparison to Best-in-Class Nix Configs

| Dimension | SystemNix | Typical dotfiles | Best-in-class |
|---|---|---|---|
| Module system usage | ★★★★★ | ★★☆☆☆ | ★★★★★ |
| Cross-platform sharing | ★★★★★ | ★☆☆☆☆ | ★★★★☆ |
| Service hardening | ★★★★☆ | ★☆☆☆☆ | ★★★★★ |
| Option typing | ★★★★☆ | ★★☆☆☆ | ★★★★★ |
| Secret management | ★★★★☆ | ★★☆☆☆ | ★★★★★ |
| Testing/CI | ★★★☆☆ | ★☆☆☆☆ | ★★★★★ |
| Documentation | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| Code cleanliness | ★★★★☆ | ★★☆☆☆ | ★★★★★ |

**SystemNix is well above average** and in some areas (module architecture, cross-platform sharing, documentation) matches or exceeds best-in-class public Nix configs.

---

## 6. What Would Make This an A+

1. **Tests** — `perSystem.checks` has statix and deadnix but no NixOS VM tests or Home Manager activation tests. Even basic `nixosTests` for service health would be a big step up.
2. **Module option port types** — Services with configurable ports should use `lib.types.port` instead of `lib.types.int`.
3. **Consistent module conventions** — One naming pattern, one enable pattern, one port reference pattern.
4. **Eliminate all hardcoded paths** — Derive everything from `config.users` and module options.
5. **Consider `nixpkgs.lib.nixosSystem` → `mkNixosSystem` helper** — The NixOS config in flake.nix is 85 lines of module list; a helper could reduce this and make adding systems trivial.

---

_Generated by Crush — comprehensive Nix architecture review_

---

## 7. Self-Review: What the First Pass Missed

After a deep second pass, the following significant issues were discovered that Section 2 didn't cover.

### 7.1 Broken Scripts (P0)

| Script | Issue |
|---|---|
| `scripts/validate-deployment.sh` | References `dotfiles/nixos/` — directory doesn't exist. Every check fails. |
| `scripts/ai-integration-test.sh` | `if [ "11434" -eq "11434" ]` — tautology. The "test" never tests anything. |
| `scripts/nixos-diagnostic.sh` | Checks for `/etc/nixos/configuration.nix` — doesn't exist in flake-based setup. Exits immediately with false error. |
| `scripts/update-crush-latest.sh` | References NUR (`github:nix-community/NUR#repos.charmbracelet.crush.version`) — NUR is a flake input but the script's eval syntax won't resolve. |
| `scripts/lib/paths.sh` | `DOTFILES_DIR="$PROJECT_ROOT/dotfiles"` — stale. Config is in `platforms/`. |

Justfile references **4 nonexistent scripts**: `storage-cleanup.sh`, `benchmark-system.sh`, `performance-monitor.sh`, `shell-context-detector.sh`.

### 7.2 signoz.nix `types.path` for Runtime Directory (P0)

`signoz.nix:138` uses `types.path` with default `"/var/lib/signoz"` — same store-copy issue as ComfyUI.

### 7.3 `nix-settings.nix` Security Concerns (P1)

| Setting | Issue |
|---|---|
| `accept-flake-config = true` | Accepts arbitrary `nixConfig` from any flake input — a malicious input could override substituters |
| `show-trace = true` | Verbose traces in production — should be opt-in |
| `narinfo-cache-negative-ttl = 0` | Disables negative caching — causes excessive network retries |
| `keep-outputs = true` + `keep-derivations = true` | Conflicts with aggressive `--delete-older-than 7d` GC — store grows unbounded |

### 7.4 CI Is Effectively Placebo (P1)

- `nix-check.yml`: Only runs `nix flake check --no-build` — never builds anything
- `perSystem.checks` statix/deadnix are `runCommand` derivations — need building, not just eval
- `go-test.yml`: Only `go vet` + `go build` — no `go test`, no `golangci-lint`
- `flake-update.yml`: Updates lockfile but never verifies the result evaluates
- No Darwin CI runner at all
- No treefmt check in CI

### 7.5 perSystem Overlay Duplication (P1)

`flake.nix:419-439` creates a separate nixpkgs instantiation with the same overlays as the darwin/nixos configs. Every overlay is evaluated multiple times. The perSystem `pkgs` and the system `pkgs` are different sets — packages built in devShell use different nixpkgs than the system config.

### 7.6 perSystem Checks Are No-Ops (P1)

`flake.nix:502-509`: The `nix-eval-darwin` and `nix-eval-nixos` checks just `echo "passed" > $out` — they verify nothing. They always pass.

### 7.7 Voice Agents Duplicate sops Secret (P1)

`livekit_keys` is defined in both `voice-agents.nix:66-74` and `sops.nix:83-85`. When both modules are enabled, these may conflict.

### 7.8 `/data` Mount Missing `nofail` (P1)

`hardware-configuration.nix:36`: The `/data` mount has no `nofail` option — if the secondary disk is absent, the system won't boot.

### 7.9 Justfile `env-private` Contradicts sops-nix (P1)

Justfile line 712-723: Creates `~/.env.private` with GitHub tokens in plaintext — the repo has sops-nix for secrets management. This is the antithesis of the sops architecture.

### 7.10 VRRP Default Password (P1)

`dns-failover.nix:43`: `authPassword` defaults to `"DNSClusterVRRP"` — ends up in world-readable Nix store via keepalived config.

### 7.11 Type Safety Improvements (P2)

| File | Current | Should Be |
|---|---|---|
| `comfyui.nix:55` | `types.int` (port 8188) | `types.port` |
| `monitor365.nix:171` | `types.int` (port 5600) | `types.port` |
| `monitor365.nix:197` | `types.int` (retention days) | `types.ints.positive` |
| `signoz.nix:138` | `types.path` (runtime dir) | `types.str` |
| `comfyui.nix:37` | `types.path` (mutable dir) | `types.str` |
| `comfyui.nix:43` | `types.str` (python path) | keep `types.str` (mutable) |
| `file-and-image-renamer.nix:20-38` | `types.str` (paths) | `types.path` for non-mutable, `types.str` for mutable |
| `preferences.nix:17` | `types.str` (accent) | `types.enum ["rosewater" "flamingo" ...]` |
| `preferences.nix:47,59,69` | `types.int` (sizes) | `types.ints.positive` |

### 7.12 Existing Patterns to Reuse (Key Insight)

The review suggested creating `lib/rocm.nix` for shared ROCm config — but the repo already has `lib/systemd.nix` as the exact pattern to follow. Similarly, the review suggested a "port constants module" — but the correct Nix-native approach is adding `port` options to each service module (like signoz.nix already does) and referencing via `config.services.<name>.settings.port` in consumers like caddy.

### 7.13 Underutilized Libraries

| Library | Currently Used | Missed Feature |
|---|---|---|
| `nix-colors` | `colorSchemes.*` lookup only | `homeManagerModules.default` — auto-generates GTK/Qt/theme config from scheme |
| `flake-parts` | Module imports only | `easyOverlay` for overlay definitions, auto-import for service modules |
| `lib.generators` | `toYAML` in signoz.nix | `toJSON` (prefer over `builtins.toJSON` for consistency) |
| `lib.asserts` | Darwin assertions only | Cross-module validation (port conflicts, service dependencies) |
| `lib.types` | `int`, `str`, `bool`, `path` | `port`, `nonEmptyStr`, `enum`, `ints.positive`, `passwdEntry` |
| `lib.modules` | Not used | `mkRenamedOptionModule` for safe option migrations |
| `lib.strings` | Not used | `escapeShellArg` for safe shell interpolation in inline scripts |

### 7.14 Revised Metrics

| Metric | Original | Updated |
|---|---|---|
| Broken scripts | 0 | 5 (validate-deployment, ai-integration-test, nixos-diagnostic, update-crush-latest, paths.sh) |
| Missing justfile scripts | 0 | 4 (storage-cleanup, benchmark-system, performance-monitor, shell-context-detector) |
| `types.path` store-copy bugs | 1 (ComfyUI) | 2 (ComfyUI + signoz) |
| Security concerns | 1 (Hermes chmod) | 3 (+ accept-flake-config, VRRP password) |
| CI gaps | "Testing mentioned" | "CI is effectively placebo" |
| Hardcoded `/home/lars` | 9 | 9 (unchanged) |
| Duplicate sops secrets | 0 | 1 (voice-agents) |

---

## 8. Comprehensive Execution Plan (Pareto-Ordered)

Each step is self-contained, committed individually, and verifiable.

### Phase 1: Critical Fixes (P0) — ~30 min

| # | Task | Files | Impact | Effort |
|---|---|---|---|---|
| 1.1 | Fix `types.path` → `types.str` for ComfyUI mutable paths | `comfyui.nix` | Prevents GB store copy | 2 min |
| 1.2 | Fix `types.path` → `types.str` for signoz stateDir | `signoz.nix` | Prevents store copy attempt | 2 min |
| 1.3 | Fix hardcoded `/home/lars` paths in module defaults | `monitor365.nix`, `file-and-image-renamer.nix` | Reusability | 10 min |
| 1.4 | Add `nofail` to `/data` mount | `hardware-configuration.nix` | Boot resilience | 2 min |
| 1.5 | Fix Hermes `chmod g+rwx` | `hermes.nix` | Security | 10 min |

### Phase 2: Broken Scripts Cleanup (P1) — ~20 min

| # | Task | Files | Impact | Effort |
|---|---|---|---|---|
| 2.1 | Delete `scripts/validate-deployment.sh` (tests nonexistent paths) | `scripts/` | Removes broken tool | 1 min |
| 2.2 | Delete `scripts/ai-integration-test.sh` (no-op tautology) | `scripts/` | Removes false confidence | 1 min |
| 2.3 | Fix `scripts/nixos-diagnostic.sh` (checks for `/etc/nixos/configuration.nix`) | `scripts/` | Makes diagnostic usable | 5 min |
| 2.4 | Delete `scripts/update-crush-latest.sh` (broken NUR reference) | `scripts/` | Removes broken tool | 1 min |
| 2.5 | Fix `scripts/lib/paths.sh` (stale DOTFILES_DIR) | `scripts/` | Fixes path library | 3 min |
| 2.6 | Remove justfile recipes referencing nonexistent scripts | `justfile` | Removes broken tasks | 5 min |

### Phase 3: Type Safety (P1) — ~20 min

| # | Task | Files | Impact | Effort |
|---|---|---|---|---|
| 3.1 | Add `lib/rocm.nix` shared ROCm config (following `lib/systemd.nix` pattern) | `lib/rocm.nix`, `ai-stack.nix`, `comfyui.nix` | DRY | 10 min |
| 3.2 | Fix `types.int` → `types.port` for port options | `comfyui.nix`, `monitor365.nix` | Type safety | 3 min |
| 3.3 | Fix `types.int` → `types.ints.positive` for counts/sizes | `monitor365.nix`, `preferences.nix` | Type safety | 3 min |
| 3.4 | Remove duplicate sops secret in voice-agents | `voice-agents.nix` | Consistency | 3 min |
| 3.5 | Remove dead watch-wrapper in file-and-image-renamer | `file-and-image-renamer.nix` | Cleanliness | 2 min |
| 3.6 | Remove duplicate steam/gamemode/gamescope from systemPackages | `steam.nix` | Cleanliness | 2 min |

### Phase 4: Nix Settings Hardening (P1) — ~10 min

| # | Task | Files | Impact | Effort |
|---|---|---|---|---|
| 4.1 | Change `accept-flake-config` to `false` | `nix-settings.nix` | Security | 1 min |
| 4.2 | Remove `show-trace = true` from production config | `nix-settings.nix` | Noise reduction | 1 min |
| 4.3 | Set `narinfo-cache-negative-ttl` to reasonable default (3600) | `nix-settings.nix` | Performance | 1 min |
| 4.4 | Remove `keep-outputs`/`keep-derivations` (conflicts with GC) | `nix-settings.nix` | Store hygiene | 1 min |

### Phase 5: CI & Tooling (P1) — ~20 min

| # | Task | Files | Impact | Effort |
|---|---|---|---|---|
| 5.1 | Add statix + deadnix + treefmt checks to CI | `nix-check.yml` | Catches regressions | 5 min |
| 5.2 | Add `nix flake check` (with build) to verify updates evaluate | `flake-update.yml` | Prevents broken lockfiles | 3 min |
| 5.3 | Add `go test` to Go CI | `go-test.yml` | Actual testing | 3 min |
| 5.4 | Add `.envrc` watch_file directives | `.envrc` | Auto-reload on flake changes | 1 min |
| 5.5 | Remove placebo `nix-eval-*` checks from perSystem | `flake.nix` | Removes misleading checks | 2 min |

### Phase 6: Architecture (P2) — ~60 min

| # | Task | Files | Impact | Effort |
|---|---|---|---|---|
| 6.1 | Standardize option naming (remove `-config` suffix) | `sops.nix`, `taskchampion.nix`, `authelia.nix`, `monitoring.nix` | Consistency | 15 min |
| 6.2 | Extract shared preferences pattern for development/localization | `preferences.nix`, `home-base.nix`, `variables.nix` | DRY | 15 min |
| 6.3 | Unify theme.nix → preferences.nix (single source of truth) | `theme.nix`, callers | DRY | 15 min |
| 6.4 | Unify shell aliases across platforms | `shells.nix` (darwin + nixos) | DRY | 10 min |
| 6.5 | Add cross-module assertions for service dependencies | Multiple modules | Build-time safety | 15 min |

---

_Updated by Crush — comprehensive Nix architecture review with self-review additions_
