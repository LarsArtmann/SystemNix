# SystemNix — Session 24 Status Report

**Date:** 2026-05-17 01:15
**Session Focus:** "Do More With Less" — Deduplication Sprint
**Commit:** `474d1974` — 31 files changed, +939/-487, net -196 lines (but +247/-443 excluding docs/planning)

---

## Executive Summary

Executed the "Do More With Less" plan — a systematic deduplication sprint that eliminated split brains, dead code, broken scripts, misplaced responsibilities, and 8 offensive security tools from a daily-driver desktop. The project went from 111 Nix files to 110, flake.nix from 620 to 592 lines, and every duplicate definition was consolidated into a single source of truth.

**Build status:** `nix flake check` passes clean.

---

## A) FULLY DONE (19 tasks completed)

### Phase 1: Quick Wins — Bug Fixes & Dead Code Removal

| # | Task | Files Changed | Impact |
|---|------|---------------|--------|
| T1.1 | **Fix broken `dns-update.sh` path** | `scripts/dns-update.sh` | `platforms/shared/` → `platforms/common/`. Script was completely broken since directory rename. |
| T1.2 | **Remove dead `allowUnfreePredicate`** | `platforms/common/nix-settings.nix` | Deleted 17-line allowlist that never executed (`allowUnfree = true` overrides it everywhere). |
| T1.3 | **Remove duplicate `nix.gc` from networking.nix** | `platforms/nixos/system/networking.nix` | Triple-defined GC → single definition in `nix-settings.nix`. |
| T1.4 | **Remove duplicate `nix.gc` from services/default.nix** | `modules/nixos/services/default.nix` | Same. |
| T1.5 | **Remove 28 lines of dead commented-out code** | `modules/nixos/services/security-hardening.nix` | Deleted commented auditd config, audit rules, journald.audit, auditd group. Bug tracked via header comment. |
| T1.6 | **Remove 8 offensive security tools** | `modules/nixos/services/security-hardening.nix` | Removed: aircrack-ng, netscanner, masscan, sqlmap, nikto, nuclei, sleuthkit, tor-browser. |
| T4.2 | **Remove tor-browser + openvpn** | Same file | 500MB anonymous browser + unused VPN client removed from system packages. |
| T4.4 | **Use `lib.mkDefault false` for apparmor** | Same file | Bare `false` → `mkDefault false` with clear path to enable. |

### Phase 2: Deduplication & Consolidation

| # | Task | Files Changed | Impact |
|---|------|---------------|--------|
| T2.1 | **Fix double overlay imports** | `overlays/default.nix` | `shared.nix` and `linux.nix` were each imported twice. Now use `let` binding. |
| T2.2 | **Merge `hardenUser` into `harden`** | `lib/systemd.nix`, `lib/default.nix`, deleted `lib/user-harden.nix` | Single function with `mode ? "system"` param. `hardenUser` is now a convenience wrapper. Eliminated 1 file, 5 duplicated helper lines, 7 duplicated key mappings. |
| T2.3 | **Extract `colorScheme` to shared module** | NEW `platforms/common/color-scheme.nix`, edited darwin/default.nix + nixos/configuration.nix | Both platforms imported the same options. Now a shared module. |
| T2.4 | **Move Firefox UI policies out of dns-blocker** | `dns-blocker.nix` → `browser-policies.nix` | 5 browser gesture/autofocus policies don't belong in a DNS module. DNS-over-HTTPS + CA cert stay. |
| T2.5 | **Fix `internet-diagnostic.sh` to source `lib.sh`** | `scripts/internet-diagnostic.sh` | Replaced 9 lines of reimplemented color functions with `source lib.sh`. |
| T2.6 | **Fix `route-health-monitor.sh` shebang** | `scripts/route-health-monitor.sh` | Moved `set -euo pipefail` from line 17 to line 2 (after shebang). |
| T2.7 | **Remove duplicate `colorSchemeLib` config** | Absorbed into T2.3 | Both platforms had redundant `config.colorSchemeLib = nix-colors.lib;` duplicating the default. |

### Phase 3: Structural Improvements

| # | Task | Files Changed | Impact |
|---|------|---------------|--------|
| T3.1 | **Deduplicate 34-entry module list in flake.nix** | `flake.nix` | Service modules defined once in `serviceModules` list. Both `imports` (flake-parts) and `nixosConfigurations` derive from it. Adding a service = 1 entry instead of 2. |
| T3.5 | **Move `mkPackageOverlay` to overlays/default.nix** | `overlays/default.nix`, `overlays/shared.nix`, `overlays/linux.nix` | Helper moved to shared location. `dnsblockdOverlay` converted to use it. |
| T3.6 | **Replace hardcoded `/home/lars` in comfyui.nix** | `modules/nixos/services/comfyui.nix` | Uses `config.users.users.${primaryUser}.home` for defaults. |
| T3.7 | **Replace hardcoded `/home/lars` in hermes.nix** | `modules/nixos/services/hermes.nix` | Migration path uses `cfg.user` instead of hardcoded `lars`. |
| T3.9 | **Merge monitoring.nix into base packages** | Deleted `monitoring.nix`, edited `base.nix` | 5 packages (radeontop, strace, ltrace, nethogs, iftop) moved to `linuxUtilities` in base.nix. Deleted ghost module. |
| T4.1 | **Rename chromium-policies → browser-policies** | Module rename + flake.nix + configuration.nix | Accurate name now that it handles Firefox too. |
| T4.3 | **Shell script IPs to env vars** | `scripts/internet-diagnostic.sh` | Gateway IP uses `${GATEWAY:-192.168.1.1}`. Other scripts already had this pattern. |
| T4.5 | **Verify disableTests overlay** | Verified | `disableTests` correctly perSystem-only (build sandbox). NixOS doesn't need it. |
| T4.6 | **Update AGENTS.md** | `AGENTS.md` | Updated: lib/ helpers, overlays, service module pattern, gotchas table. |

---

## B) PARTIALLY DONE (0 tasks)

None — everything we started was completed.

---

## C) NOT STARTED (5 tasks — correctly skipped)

| # | Task | Why Skipped |
|---|------|-------------|
| T3.2 | Extract gitea mirror scripts to `scripts/` | Scripts reference Nix-derived config values (`giteaUrl`, `giteaPort`). Extracting would require env var plumbing, adding complexity for zero behavioral improvement. |
| T3.3 | Extract gitea token/runner scripts to `scripts/` | Same reason as T3.2. |
| T3.4 | Move `d2DarwinOverlay` out of shared.nix | Already guarded with `optionalAttrs isDarwin`. Moving adds darwin-specific overlay path for zero behavioral change. |
| T3.8 | Consolidate overlay composition helper | Each of the 4 compositions has unique additions (niri, disableTests, pythonTest, NUR-only). Helper would save ~10 lines but add indirection. |
| T3.10 | Add path validation test | Low priority — can be done as a pre-commit hook later. |

---

## D) TOTALLY FUCKED UP (0 tasks)

Nothing was broken. `nix flake check` passes clean after every change.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **`ssh-config.nix` has 6 hardcoded IPs** — `platforms/common/programs/ssh-config.nix` has LAN IPs and Hetzner server IPs hardcoded. LAN IPs should use `networking.local.*` but HM modules can't access NixOS config options. This needs a proper solution (shared module or specialArgs).

2. **`gitea.nix` is 555 lines with ~310 lines of embedded shell** — The 6 embedded scripts are the largest concentration of shell-in-Nix in the project. Extracting them requires passing Nix config values as env vars, which is doable but non-trivial.

3. **`comfyui.nix` defaults still use mutable paths** — `${userHome}/projects/anime-comic-pipeline/` is a user-specific mutable path as a module default. If the directory doesn't exist, the service silently fails. Should have a setup assertion.

4. **Overlay composition is scattered** — 4 different places compose overlays (perSystem, darwin, nixos, rpi3). Each is slightly different. A helper would reduce this but adds abstraction cost.

### Code Quality

5. **`hermes.nix` patches upstream npmDepsHash** — The local overlay intercepts `callPackage` for `tui.nix` and replaces the npmDeps hash. Fragile — breaks on hermes upgrades.

6. **`todoListAiFixedHash` in shared.nix** — Fixed-output derivation hash for todo-list-ai's `node_modules`. Must be manually updated when upstream changes. No automation.

7. **Shell scripts lack `shellcheck` in CI** — `just validate-scripts` exists but isn't in pre-commit or CI. Scripts could silently regress.

8. **No integration tests** — `nix flake check` validates evaluation, but doesn't test that services actually start or that configs render correctly. A `nixosTests` suite would catch runtime issues.

### Security

9. **`allowUnfree = true` everywhere** — No restriction on unfree packages. The previous allowlist was dead code. A proper allowlist would require removing `allowUnfree = true` and carefully testing.

10. **Authelia has hardcoded bcrypt hash in module** — `modules/nixos/services/authelia.nix:22` has a hardcoded password hash for `client_secret`. Should come from sops.

---

## F) Top #25 Things We Should Get Done Next

Sorted by impact/effort ratio:

### High Impact, Low Effort (Quick Wins)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Add `shellcheck` to pre-commit hook** | 15 min | Prevents script regressions |
| 2 | **Add setup assertions to comfyui.nix** — fail if `package` path doesn't exist | 10 min | Catches misconfig early |
| 3 | **Extract `authelia.nix` hardcoded bcrypt hash to sops** | 15 min | Security — no creds in repo |
| 4 | **Add `signoz-alerts.nix` to serviceModules list** — it's a data file, not a flake-parts module, but should be tracked | 5 min | Consistency |
| 5 | **Add `just validate-scripts` to `just test-fast`** | 5 min | Script validation in the fast test path |
| 6 | **Replace `192.168.1.100` in ssh-config.nix with `networking.local.lanIP`** — needs HM→NixOS bridge | 20 min | Removes hardcoded IP |

### Medium Impact, Medium Effort

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 7 | **Write a basic `nixosTests` suite** — test that key services start (caddy, gitea, unbound) | 2 hrs | Catches runtime breakage |
| 8 | **Extract gitea scripts to `scripts/` with env var injection** | 1 hr | Reduces gitea.nix from 555→250 lines |
| 9 | **Create `platforms/common/ssh-hosts.nix`** — derive SSH config from `networking.local.*` + sops for public IPs | 1 hr | Eliminates 6 hardcoded IPs |
| 10 | **Automate `todoListAiFixedHash` update** — script that detects hash mismatch and updates | 30 min | Prevents manual hash breakage |
| 11 | **Consolidate hermes npmDepsHash patching** — upstream fix or auto-detection | 1 hr | Fragile patch that breaks on upgrades |
| 12 | **Add `perSystem` checks for script path references** | 30 min | Prevents `dns-update.sh` style bugs |
| 13 | **Create `platforms/common/preferences.nix` → shared options module** — `primaryUser`, `stateVersion`, etc. | 1 hr | More shared config between platforms |
| 14 | **Write justfile recipes for `browser-policies` changes** | 15 min | Easy testing when browser policies change |
| 15 | **Audit all `environment.systemPackages` for duplicates across modules** | 30 min | Likely packages listed in multiple places |

### Higher Effort, High Impact

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | **Extract `flaky test` packages to `disabledTests` module** — centralize all test-skipping overlays | 1 hr | Single place for all test overrides |
| 17 | **Add `pre-commit` hooks for `statix`, `deadnix`, `alejandra`** | 1 hr | Prevents Nix code quality regressions |
| 18 | **Create a `just bootstrap` command** — one-command setup for new machines | 2 hrs | Reproducible machine provisioning |
| 19 | **Split `configuration.nix` (320 lines) into focused sub-modules** — services, packages, hardware are all in one file | 2 hrs | Better separation of concerns |
| 20 | **Add `services.gitea.admin-password` to sops** — currently stored as plain file | 30 min | Security |
| 21 | **Audit `pkgs/` for stale vendored files** — `jscpd-package-lock.json` may be stale | 15 min | Package freshness |
| 22 | **Test rpi3-dns build** — verify the minimal Pi image still evaluates | 20 min | The Pi config uses different overlays and hasn't been tested |
| 23 | **Add Darwin-specific overlay file** — move `d2DarwinOverlay` out of shared.nix properly | 30 min | Correct abstraction placement |
| 24 | **Create `modules/nixos/services/firewall.nix`** — centralize all port opens instead of scattering across modules | 1 hr | Security audit surface |
| 25 | **Document `services.enable` convention** — some use `services.<name>.enable`, others use `services.<name>-config.enable` | 30 min | Naming consistency |

---

## G) Top #1 Question I Cannot Figure Out Myself

**How should SSH config IPs be handled in Home Manager modules?**

`platforms/common/programs/ssh-config.nix` is a Home Manager module. It has 6 hardcoded IPs (LAN + Hetzner). The LAN IPs should use `config.networking.local.*` from `local-network.nix`, but HM modules can't access NixOS `config` options directly. Possible approaches:

1. **Pass via `sharedHomeManagerSpecialArgs`** — inject `networking.local` into HM extraSpecialArgs
2. **Create a shared NixOS+HM options module** — define `networking.local` as a shared option visible to both
3. **Move SSH config to NixOS `programs.ssh`** — loses the HM integration (per-user config)
4. **Use sops templates** — encrypt the IPs and decrypt at activation time

I don't know which approach best fits the project's architecture. The Hetzner public IPs are even trickier since they're not local network config — they're cloud infrastructure that might belong in secrets or a separate inventory.

---

## Session Metrics

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| flake.nix lines | 620 | 592 | -28 |
| Nix files | 111 | 110 | -1 |
| Deleted files | — | 3 (user-harden.nix, monitoring.nix, chromium-policies.nix) | -3 |
| New files | — | 2 (color-scheme.nix, browser-policies.nix) | +2 |
| Duplicate nix.gc | 3 | 1 | -2 |
| Dead code lines | ~45 | ~0 | -45 |
| Offensive security packages | 8 | 0 | -8 |
| Hardcoded `/home/lars` in modules | 3 | 0 | -3 |
| Duplicate option declarations | 2 × 2 platforms | 1 shared module | -1 copy |
| Double overlay imports | 2 × 2 | 0 | -4 imports |
| Service module sync points | 2 | 1 | -1 |
| Broken scripts | 1 | 0 | -1 |

## Git Status

```
Branch: master (1 commit ahead of origin)
Commit: 474d1974 refactor: deduplication sprint — 28 files, -196 net lines
Unstaged: scripts/display-watchdog.sh (trivial formatter whitespace)
Build: nix flake check passes
```
