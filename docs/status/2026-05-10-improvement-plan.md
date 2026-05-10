# SystemNix Improvement Plan

**Generated:** 2026-05-10
**Context:** Comprehensive audit of codebase after dual-WAN/DNS outage resolution

---

## Reflection: What We Forgot & Could Do Better

### Incident Response Lessons
1. **Missing `path` directive** — The `mptcp-endpoint-manager` service crash-looped for 18+ restarts because `logger` wasn't in PATH. This is a class of bug that should be caught at build time, not runtime.
2. **No service health tests** — `just test-fast` only checks Nix syntax. There's no validation that systemd services can actually start (missing commands, wrong paths, bad permissions).
3. **No module template** — Every new module requires copy-pasting 3 lib imports (`harden`, `serviceDefaults`, `types`). Inconsistent import patterns lead to subtle bugs (like `sd` vs `sd.serviceDefaults`).

### Architecture Observations
- `lib/types.nix` has `systemdServiceIdentity`, `restartDelay`, `stopTimeout` — **all unused**
- 20+ modules copy the same 3-line import block — should be a single import
- 3 scripts define identical color constants — should be sourced from a shared file
- Shell scripts lack a `source`-able common library for logging, error handling, and color output

---

## Execution Plan (sorted by impact / effort)

### Tier 1: Quick Wins (low effort, high impact)

| # | Task | Files | Impact | Effort |
|---|------|-------|--------|--------|
| 1 | Create `lib/default.nix` — single import for `harden`, `serviceDefaults`, `serviceDefaultsUser`, `serviceTypes` | `lib/default.nix` | DRY across 20+ modules, prevents import bugs | 15min |
| 2 | Add missing `serviceDefaults` to `disk-monitor` and `dns-failover` | `disk-monitor.nix`, `dns-failover.nix` | Consistent restart behavior on all services | 5min |
| 3 | Extract shared shell script library (`scripts/lib.sh`) | `scripts/lib.sh`, `health-check.sh`, `test-home-manager.sh`, `test-shell-aliases.sh` | DRY color constants, logging, test counters | 20min |
| 4 | Delete unused `restartDelay`/`stopTimeout` from `lib/types.nix` (or adopt them) | `lib/types.nix` | Dead code removal | 5min |

### Tier 2: Consistency Fixes (medium effort, high impact)

| # | Task | Files | Impact | Effort |
|---|------|-------|--------|--------|
| 5 | Migrate all 20+ modules from triple-import to `lib/default.nix` | All service modules | Consistent pattern, fewer LOC, single source of truth | 30min |
| 6 | Adopt `serviceTypes.servicePort` in `voice-agents`, `signoz`, `taskchampion` | 3 modules | Consistent port typing, no inline `lib.types.port` | 15min |
| 7 | Extract hardcoded port from `taskchampion` into a proper option | `taskchampion.nix` | Enables caddy reference, discoverability | 10min |
| 8 | Fix `signoz.nix` hardcoded `0.0.0.0:8080` → use module option | `signoz.nix` | Removes last hardcoded port | 10min |
| 9 | Remove `dns-failover.nix` plaintext `authPassword` — route through sops | `dns-failover.nix`, secrets | Security: no plaintext passwords in nix store | 20min |

### Tier 3: Script Quality (medium effort, medium impact)

| # | Task | Files | Impact | Effort |
|---|------|-------|--------|--------|
| 10 | Add `set -euo pipefail` + bash shebang to `gpu-recovery.sh`, `niri-drm-healthcheck.sh` | 2 scripts | Proper error propagation | 5min |
| 11 | Parameterize `nixos-diagnostic.sh` hostname (remove hardcoded `#evo-x2`) | `nixos-diagnostic.sh` | Reusable across machines | 10min |
| 12 | Auto-detect GPU PCI address in `gpu-recovery.sh` instead of hardcoding | `gpu-recovery.sh` | Portable across hardware | 15min |

### Tier 4: Test Infrastructure (higher effort, very high impact)

| # | Task | Files | Impact | Effort |
|---|------|-------|--------|--------|
| 13 | Add `just validate-scripts` recipe — shellcheck all scripts + verify PATH deps exist | `justfile`, `scripts/` | Catch `command not found` before deploy | 30min |
| 14 | Add NixOS VM test for critical services (caddy, unbound) | `checks/` or `flake.nix` | Catch service start failures at build time | 2hr |
| 15 | Integrate `test-home-manager.sh` and `test-shell-aliases.sh` into `just test` | `justfile`, scripts | Single command validates everything | 15min |

### Tier 5: Architecture Improvements (higher effort, high impact)

| # | Task | Files | Impact | Effort |
|---|------|-------|--------|--------|
| 16 | Extract overlay boilerplate from `flake.nix` into `overlays/` directory | `flake.nix`, `overlays/*.nix` | Reduce flake.nix complexity (currently 800+ lines) | 1hr |
| 17 | Add `mkGraphicalUserService` helper to `lib/` | `lib/`, `monitor365.nix`, `file-and-image-renamer.nix` | DRY user service boilerplate | 30min |
| 18 | Consolidate `voice-agents.nix` Caddy vHost into `caddy.nix` pattern | `voice-agents.nix`, `caddy.nix` | Single source of truth for reverse proxy config | 20min |

---

## What Already Exists That Could Fit Requirements

Before implementing anything new, leverage existing patterns:

| Need | Already Have | Where |
|------|-------------|-------|
| Service hardening | `harden {}` helper | `lib/systemd.nix` |
| Service defaults | `serviceDefaults {}` / `serviceDefaultsUser {}` | `lib/systemd/service-defaults.nix` |
| Port option factory | `servicePort` | `lib/types.nix` |
| User/group/stateDir | `systemdServiceIdentity` | `lib/types.nix` (unused!) |
| ROCm GPU support | `rocm.env`, `rocm.makeLdLibraryPath` | `lib/rocm.nix` |
| Local network IPs | `networking.local.*` options | `platforms/nixos/system/local-network.nix` |
| DNS config pattern | `dns-blocker-config.nix` | `modules/nixos/services/` |
| Shell formatting | `treefmt` + `alejandra` + `shellcheck` | Pre-commit hooks |
| Color theme | Catppuccin Mocha (universal) | Multiple files |

## Well-Established Libraries to Consider

| Library | Purpose | Relevance |
|---------|---------|-----------|
| [nixos-generators](https://github.com/nix-community/nixos-generators) | Build VM images from NixOS config | Could enable `nixosTests` without full deploys |
| [nix-unit](https://github.com/nix-community/nix-unit) | Unit testing for Nix expressions | Test lib helpers, module option evaluation |
| [nixt](https://github.com/nix-community/nixt) | NixOS module linter | Catch missing options, inconsistent patterns |
| [systemd-sandboxed-bin](https://github.com/imsofi/systemd-sandboxed-bin) | Hardened systemd wrappers | Could supplement our `harden {}` helper |
| [shellcheck](https://www.shellcheck.net/) | Already in pre-commit | Extend to validate PATH deps at CI time |
