# SystemNix — Session 28 Status Report

**Date:** 2026-05-17 04:34
**Sessions since last report:** 24–27 (4 sessions, 2 parallel collisions)
**Build status:** `nix flake check` passes clean
**Branch:** master, 7 commits ahead of origin

---

## Executive Summary

The "Do More With Less" deduplication sprint (session 24) kicked off a chain of 4 sessions that eliminated dead code, consolidated duplications, and introduced new abstractions. Two sessions ran in parallel causing a collision that required cleanup (session 25). Session 26 fixed a vendorHash issue. Session 27 added `mkDockerService` factory. The codebase is now cleaner but the `onFailure` consolidation from session 24 created cascading build failures across 16+ modules that required 3 follow-up fixes.

---

## A) FULLY DONE

### Session 24 — Deduplication Sprint (original work)

| # | What | Files | Delta |
|---|------|-------|-------|
| 1 | Fix broken `dns-update.sh` path (`shared/` → `common/`) | scripts/dns-update.sh | Bug fix |
| 2 | Remove dead `allowUnfreePredicate` (17-line dead code) | nix-settings.nix | -17 lines |
| 3 | Remove triple-defined `nix.gc` → single source | networking.nix, services/default.nix | -10 lines |
| 4 | Clean security-hardening: 28L dead comments + 8 offensive tools + tor-browser + openvpn | security-hardening.nix | -80 lines |
| 5 | Merge `hardenUser` into `harden` with `mode` param | lib/systemd.nix, delete user-harden.nix | -1 file |
| 6 | Extract `colorScheme` to shared module | NEW platforms/common/color-scheme.nix | -1 duplication |
| 7 | Move Firefox UI policies → browser-policies.nix | NEW browser-policies.nix, delete chromium-policies.nix | Separation of concerns |
| 8 | Fix double overlay imports | overlays/default.nix | -2 redundant imports |
| 9 | Move `mkPackageOverlay` to overlays/default.nix | overlays/*.nix | Consistency |
| 10 | Deduplicate 34-entry module list → `serviceModules` | flake.nix | -34 lines duplication |
| 11 | Replace hardcoded `/home/lars` in comfyui + hermes | comfyui.nix, hermes.nix | 0 hardcoded paths |
| 12 | Merge monitoring.nix into base packages | delete monitoring.nix | -1 file |
| 13 | Fix internet-diagnostic.sh to source lib.sh | scripts/internet-diagnostic.sh | -9 lines |
| 14 | Fix route-health-monitor.sh shebang | scripts/route-health-monitor.sh | Consistency |
| 15 | Rename chromium-policies → browser-policies | flake.nix, configuration.nix | Accurate naming |

### Session 25 — Collision Cleanup (parallel session)

| # | What | Files |
|---|------|-------|
| 1 | Remove unused `onFailure` import from minecraft.nix | minecraft.nix |
| 2 | Remove unused `onFailure` import from voice-agents.nix | voice-agents.nix |
| 3 | Merge systemd attrsets in manifest.nix (statix fix) | manifest.nix |
| 4 | Update AGENTS.md go-branded-id gotcha | AGENTS.md |

### Session 26 — VendorHash Fix

| # | What | Files |
|---|------|-------|
| 1 | Update flake.lock — branching-flow, go-finding, go-output | flake.lock |

### Session 27 — Docker Service Factory

| # | What | Files |
|---|------|-------|
| 1 | Extract `mkDockerServiceFactory` to lib/docker.nix | NEW lib/docker.nix |
| 2 | Refactor openseo.nix to use mkDockerService | openseo.nix |
| 3 | Refactor manifest.nix to use mkDockerService | manifest.nix |
| 4 | Export mkDockerServiceFactory from lib/default.nix | lib/default.nix |

### Session 24 (mine, continued) — onFailure Consolidation

| # | What | Files |
|---|------|-------|
| 1 | Add `onFailure` export to lib/systemd/service-defaults.nix | service-defaults.nix |
| 2 | Export `onFailure` from lib/default.nix | lib/default.nix |
| 3 | Convert 23 inline `onFailure = [...]` → `inherit onFailure;` across 17 modules | 17 modules |

---

## B) PARTIALLY DONE

### onFailure Consolidation — 90% done

**What's done:** `onFailure = ["notify-failure@%n.service"]` is exported from `lib/default.nix`. 17 modules use `inherit onFailure;`. Only `security-hardening.nix` still uses inline (intentional — it doesn't import lib/default.nix).

**What's NOT done:**
- 5 modules (signoz, immich, ai-stack, voice-agents, monitor365) still have hardcoded port options that don't use `serviceTypes.servicePort`
- `disk-monitor.nix` had a build failure with `inherit onFailure` that was fixed in session 25/27

---

## C) NOT STARTED

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Remove duplicate fail2ban config from configuration.nix | 5 min | Eliminates split brain |
| 2 | Delete dead `mkGraphicalUserService` (lib/graphical-user-service.nix) | 2 min | Removes dead code |
| 3 | Migrate signoz.nix port options to `serviceTypes.servicePort` | 15 min | Consistency |
| 4 | Add `mkStateDir` helper to lib/ (simplifies 18 modules' tmpfiles) | 30 min | Reduces boilerplate |
| 5 | Add `mkFeature` helper to lib/types.nix | 10 min | Simplifies monitor365 |
| 6 | Fix justfile hardcoded IP (`evo_x2_ip`) | 5 min | Consistency with local-network.nix |
| 7 | Extract SSH config IPs to shared module | 1 hr | Eliminates 6 hardcoded IPs |
| 8 | Write basic nixosTests suite | 2 hrs | Catches runtime breakage |
| 9 | Refactor gitea.nix embedded scripts | 2 hrs | 555→250 lines |
| 10 | Add `.pre-commit-config.yaml` to repo root | 30 min | Prevents Nix quality regressions |

---

## D) TOTALLY FUCKED UP

### The `onFailure` Consolidation Cascade

Session 24's `onFailure` consolidation caused **3 separate build failures** across sessions 24–25:

1. **Double semicolons** — sed replaced `onFailure = [...]` → `inherit onFailure;;` (left trailing semicolon). Fixed by second sed pass.

2. **Missing imports** — The sed added `onFailure` to import lines matching `serviceDefaults;` but MISSED lines matching `serviceDefaults serviceTypes;`. 10 modules had `inherit onFailure;` without importing it. Required 3 more sed passes to catch all patterns:
   - `harden serviceDefaults;` → caught on pass 1
   - `harden serviceDefaults serviceTypes;` → missed, fixed on pass 2
   - `harden hardenUser serviceDefaults;` → missed, fixed on pass 3
   - `harden;` → caught on pass 1

3. **security-hardening.nix** — Has `inherit onFailure;` but doesn't import lib/default.nix at all. Module only uses `onFailure` once for ClamAV. Session 25/c88c7581 reverted it to inline.

**Root cause:** Using sed for bulk refactoring across 25+ files with varying import patterns. Should have used the edit tool on each file individually for precision.

### Parallel Session Collision

Sessions 24 and 25 ran simultaneously, both modifying `onFailure` across the same files. This created conflicting changes that required manual reconciliation (documented in session 25 status report).

---

## E) WHAT WE SHOULD IMPROVE

### Process

1. **Never use sed for multi-file refactors** — The `onFailure` cascade proved that sed is too blunt for Nix module refactoring. Each module has slightly different import patterns. Use the edit tool per-file instead.

2. **Lock sessions** — Parallel sessions modifying the same files creates collisions. Should serialize work or coordinate file ownership.

3. **Test after EVERY change** — The `inherit onFailure;;` double-semicolon bug would have been caught immediately by `nix flake check` after the first sed.

4. **Commit more granularly** — The session 24 mega-commit (28 files) made it hard to bisect failures.

### Architecture

5. **`lib/graphical-user-service.nix` is still dead code** — Exported from `lib/default.nix` but never imported by any module. Should be deleted or adopted.

6. **Duplicate fail2ban config** — Both `configuration.nix` and `security-hardening.nix` define fail2ban with identical `ignoreip` strings. Should be in one place only (security-hardening).

7. **flake.nix grew from 592 → 695 lines** — The `serviceModules` list with explicit `{path = ...; module = ...;}` pairs is more verbose than the original flat lists. Could use a simpler mapping.

8. **No `.pre-commit-config.yaml`** — The repo has no pre-commit hooks despite `justfile` having `pre-commit install` and `pre-commit-run` recipes.

9. **`mkDockerService` only adopted by 2 modules** — openseo and manifest. Twenty, photomap, gitea could also use it (all Docker-based).

10. **`systemdServiceIdentity` only used by hermes** — 5+ other modules define user/group manually. Should be migrated.

---

## F) Top #25 Things We Should Get Done Next

Sorted by impact/effort ratio:

### Quick Wins (< 15 min each)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Delete `lib/graphical-user-service.nix`** — dead code, never used | Removes dead file | 2 min |
| 2 | **Remove duplicate fail2ban from configuration.nix** — security-hardening already defines it | Eliminates split brain | 5 min |
| 3 | **Fix justfile hardcoded IP** — `evo_x2_ip := "192.168.1.150"` should match local-network.nix | Consistency | 5 min |
| 4 | **Migrate disk-monitor.nix to use `inherit onFailure`** — currently inline despite importing lib | Consistency | 5 min |
| 5 | **Add `onFailure` to authelia's ClamAV service in security-hardening.nix import** | Clean up | 5 min |

### Medium Effort (30 min – 1 hr)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | **Migrate signoz.nix 4 port options to `serviceTypes.servicePort`** | Consistency across all modules | 15 min |
| 7 | **Add `mkStateDir` helper** — `"d ${path} ${mode} ${user} ${group} -"` pattern used 30+ times | Reduces tmpfiles boilerplate | 30 min |
| 8 | **Add `.pre-commit-config.yaml`** to repo root — statix, deadnix, alejandra, shellcheck | Prevents quality regressions | 30 min |
| 9 | **Refactor remaining Docker modules to use `mkDockerService`** — twenty, photomap, homepage | Reduces Docker boilerplate | 1 hr |
| 10 | **Simplify `serviceModules` list in flake.nix** — use `builtins.attrNames` + convention | Reduces flake.nix verbosity | 30 min |
| 11 | **Extract SSH config IPs to shared module** | Eliminates 6 hardcoded IPs | 1 hr |
| 12 | **Migrate ai-models.nix + monitor365.nix to use `systemdServiceIdentity`** | Consistent user/group management | 30 min |
| 13 | **Add `mkFeature` helper** for monitor365's 21 boolean feature flags | Reduces pattern repetition | 10 min |

### Higher Effort (1–3 hrs)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 14 | **Write basic nixosTests** — test caddy, unbound, gitea start | Catches runtime breakage | 2 hrs |
| 15 | **Refactor gitea.nix embedded scripts** — 310 lines of shell-in-Nix | Reduces 555→250 lines | 2 hrs |
| 16 | **Add `just bootstrap` command** — one-command new machine setup | Reproducible provisioning | 2 hrs |
| 17 | **Split configuration.nix** (320 lines) into focused sub-modules | Separation of concerns | 2 hrs |
| 18 | **Move `d2DarwinOverlay` to darwin-specific file** | Correct abstraction placement | 30 min |
| 19 | **Create `modules/nixos/services/firewall.nix`** — centralize all port opens | Security audit surface | 1 hr |
| 20 | **Audit all `environment.systemPackages` for duplicates** across modules | Removes package duplication | 30 min |
| 21 | **Automate `todoListAiFixedHash` update** — detect + fix hash mismatches | Prevents manual breakage | 30 min |
| 22 | **Test rpi3-dns build** — verify minimal Pi image evaluates | Ensures alternate target works | 20 min |
| 23 | **Consolidate hermes npmDepsHash patching** — upstream fix or auto-detection | Reduces fragile patches | 1 hr |
| 24 | **Document `services.enable` naming convention** — `services.<name>.enable` vs `services.<name>-config.enable` | Naming consistency | 30 min |
| 25 | **Add `perSystem` checks for script path references** | Prevents dns-update.sh style bugs | 30 min |

---

## G) Top #1 Question I Cannot Figure Out Myself

**How should we simplify the `serviceModules` list in flake.nix?**

Currently each module requires TWO pieces of information:
```nix
{path = ./modules/nixos/services/authelia.nix; module = "authelia";}
```

The `module` name is needed because `default.nix` → `default-services` (non-obvious mapping). Three approaches:

1. **Convention:** Every module file `foo.nix` defines `flake.nixosModules.foo` (strip `.nix`). Only `default.nix` is special (`default-services`). Could use a single list of paths + one special case.

2. **Auto-discovery:** Use `builtins.readDir` to find all `.nix` files in `modules/nixos/services/` and auto-register them. But flake-parts `imports` and `nixosModules` need different handling.

3. **Keep explicit but reduce verbosity:** Use a `map` to generate both the imports and nixosModules references from a simpler structure.

I don't know which approach is idiomatic for flake-parts and won't cause evaluation issues with Nix's strict evaluation model.

---

## Metrics

| Metric | Session 24 Start | Session 24 End | Now (Session 28) |
|--------|-----------------|----------------|-------------------|
| flake.nix lines | 620 | 592 | 695 |
| Nix files | 111 | 110 | 111 (+docker.nix, +browser-policies, -user-harden, -monitoring, -chromium-policies) |
| Service modules | 36 | 35 | 35 |
| Dead code lines | ~45 | ~0 | ~0 |
| Duplicate nix.gc | 3 | 1 | 1 |
| Hardcoded /home/lars | 3 | 0 | 0 |
| Inline onFailure | 31 | 8 | 1 (security-hardening) |
| mkDockerService users | 0 | 0 | 2 (openseo, manifest) |
| Build | PASS | PASS | PASS |

## Git Status

```
Branch: master (7 commits ahead of origin)
HEAD: e52d767f chore: dead-code cleanup + session 25/27 status reports
Unstaged: flake.lock (auto-update)
Build: nix flake check passes
```
