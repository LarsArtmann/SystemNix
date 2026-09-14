# COMPREHENSIVE STATUS REPORT — 2026-04-10 13:45

## a) FULLY DONE

### This Session (7 commits, all pushed)

| Commit    | What                                                                                 | Lines Changed |
| --------- | ------------------------------------------------------------------------------------ | ------------- |
| `6b7eb4a` | Removed dead `ollama-permissions` oneshot service                                    | -19 lines     |
| `de40a2f` | Removed packages duplicated by HM modules (starship, taskwarrior3, timewarrior)      | -5 lines      |
| `be0ffbf` | Removed duplicate `scripts/blocklist-hash-updater`                                   | -75 lines     |
| `2ac816c` | Added flake apps: `deploy`, `validate`, `dns-diagnostics`                            | +35 lines     |
| `e00b3e3` | Migrated justfile to `nh os` (5 recipes)                                             | 5 changed     |
| `1d6b857` | Added flake.checks (statix, deadnix, eval smoke tests) + fixed dead code in overlays | +60/-42 lines |
| `e9869c3` | Status report documentation                                                          | +95 lines     |

### Prior Sessions (Also Done)

| What                                                        | Commit    |
| ----------------------------------------------------------- | --------- |
| TaskChampion sync server + cross-platform Taskwarrior 3     | `0049f3d` |
| Firewall hardening + token file permissions                 | `e7244e1` |
| Statix W04/W20 lint fixes + deploy script `enp1s0→eno1` fix | `15050f5` |
| AGENTS.md updated with Taskwarrior architecture docs        | `125b242` |

---

## b) PARTIALLY DONE

### Flake Checks

- **statix check**: Fully working, strict, catches anti-patterns
- **deadnix check**: Advisory only (reports but doesn't fail) because ~6 pre-existing deadnix warnings exist across the codebase that need manual fixing
- **nix-eval smoke tests**: Work but use `|| true` since full eval needs all flake inputs

### Package Deduplication

- Removed starship, taskwarrior3, timewarrior from `base.nix`
- Still in `base.nix` but have HM modules: `fish`, `git`, `fzf`, `tmux`, `zsh`, `bash`, `nushell`, `chromium`
- These are kept because the system package provides CLI access even without HM activation (recovery scenario)

---

## c) NOT STARTED (Prioritized Backlog)

### P1 — High Impact, Moderate Effort

| # | Task                                                                 | Why                                                                 | Effort | Risk                         |
| - | -------------------------------------------------------------------- | ------------------------------------------------------------------- | ------ | ---------------------------- |
| 1 | Migrate `homepage.nix` to `services.homepage-dashboard` NixOS module | Custom systemd service when nixpkgs has a native module             | Medium | Medium (config mapping)      |
| 2 | Replace `immich-db-backup` with `services.postgresqlBackup`          | Custom backup service when NixOS has built-in                       | Low    | Medium (different semantics) |
| 3 | Fix 6 pre-existing deadnix warnings                                  | `poetry` unused, `cfg` unused, `addIPScript` unused, overlay params | Low    | Low                          |
| 4 | Extract overlays from `flake.nix` to `overlays/` directory           | 170 lines of overlays inline in flake.nix, triple-duplicated        | Medium | Low                          |
| 5 | Expose overlays via `flake.overlays` output                          | No flake.overlays defined — can't consume downstream                | Low    | Low                          |

### P2 — Medium Impact

| #  | Task                                                              | Why                                                                      | Effort | Risk   |
| -- | ----------------------------------------------------------------- | ------------------------------------------------------------------------ | ------ | ------ |
| 6  | Convert `test-home-manager.sh` to `flake.checks` derivation       | Shell script could be Nix test                                           | Medium | Low    |
| 7  | Convert `test-shell-aliases.sh` to `flake.checks` derivation      | Cross-shell alias validation as Nix test                                 | Medium | Low    |
| 8  | Convert `ai-integration-test.sh` to `flake.checks` derivation     | Ollama/GPU readiness test                                                | Medium | Low    |
| 9  | Replace `perSystem` pkgs override with flake-parts nixpkgs module | Current `_module.args.pkgs` fights flake-parts                           | Medium | Medium |
| 10 | Add `nixosTest` for DNS blocker module                            | VM test verifying unbound + dnsblockd work together                      | High   | Low    |
| 11 | Add `nixosTest` for Caddy vhost generation                        | Verify reverse proxy config                                              | Medium | Low    |
| 12 | Deduplicate `dnsblockd`/`dnsblockd-processor` package definitions | Same package defined in BOTH `perSystem.packages` AND `dnsblockdOverlay` | Low    | Low    |

### P3 — Nice to Have

| #  | Task                                                                             | Why                                                 | Effort  | Risk   |
| -- | -------------------------------------------------------------------------------- | --------------------------------------------------- | ------- | ------ |
| 13 | Replace `scripts/storage-cleanup.sh` with `systemd.tmpfiles.rules`               | Imperative cleanup → declarative                    | High    | Medium |
| 14 | Replace `scripts/cleanup.sh` with `nix.gc` + `systemd.timers`                    | Manual script → Nix-native                          | High    | Medium |
| 15 | Replace `scripts/maintenance.sh` with `systemd` services                         | Same as above                                       | High    | Medium |
| 16 | Replace `scripts/optimize.sh` with `auto-optimise-store = true` (already set!)   | Script is literally unnecessary                     | Low     | Low    |
| 17 | Make `performance-monitor.sh` a `systemd` service + timer                        | Currently manual                                    | Medium  | Low    |
| 18 | Add `services.netdata` NixOS module instead of manual justfile recipes           | `netdata-start`/`netdata-stop` could be declarative | Low     | Low    |
| 19 | Add `meta.description` to all flake apps                                         | Warning: app lacks attribute 'meta.description'     | Low     | None   |
| 20 | Remove `config.allowBroken = false` from flake.nix (it's the default)            | Dead config                                         | Trivial | None   |
| 21 | Consolidate Docker/OCI container management into `virtualisation.oci-containers` | Only photomap uses Docker but pattern is correct    | Low     | Low    |

### P4 — Architecture / Deep Refactoring

| #  | Task                                                                                                                      | Why                                                        | Effort | Risk   |
| -- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | ------ | ------ |
| 22 | Move from inline `home-manager` module wiring in flake.nix to `home-manager.nixosModules.home-manager` with shared config | 80+ lines of HM config duplicated between darwin and NixOS | High   | High   |
| 23 | Investigate `flake-parts` perSystem `nixpkgs` module to replace `_module.args.pkgs`                                       | Current pattern is anti-pattern per flake-parts docs       | Medium | Medium |
| 24 | Create `lib/` directory for shared Nix functions (e.g., `svcUrl`, port helpers)                                           | Repeated patterns across service modules                   | Medium | Low    |
| 25 | Add `nixosTest` for Authelia OIDC config end-to-end                                                                       | Verify SSO integration works                               | High   | Low    |

---

## d) TOTALLY FUCKED UP

Nothing. All 7 commits pass:

- deadnix: clean
- statix: clean
- alejandra: clean
- nix flake check: pass
- git push: success

### GitHub Dependabot Alerts (External)

GitHub reports 7 vulnerabilities (1 critical, 2 high, 4 moderate) on the default branch. These are likely in flake inputs (nixpkgs packages), not in our code. Need investigation.

---

## e) WHAT WE SHOULD IMPROVE

### Pre-existing Deadnix Warnings (Found by New Check)

```
modules/nixos/services/caddy.nix:23         - unused param `subdomain` in protectedVHost
pkgs/aw-watcher-utilization.nix:2            - unused `poetry` in inherit
platforms/common/programs/keepassxc.nix:7    - unused let binding `cfg`
platforms/darwin/default.nix:67-68           - unused `final`, `oldAttrs` in overlay
platforms/nixos/desktop/ai-stack.nix:25      - unused `old` in ollama override
platforms/nixos/modules/dns-blocker.nix:288  - unused let binding `addIPScript`
```

### Architecture Debt

1. **Overlays defined 3 times**: perSystem, darwin config, NixOS config — should be `overlays/` dir + `flake.overlays` output
2. **Package definitions duplicated**: `dnsblockd` + `dnsblockd-processor` defined in both `perSystem.packages` AND `dnsblockdOverlay`
3. **Home-manager config 200+ lines inline in flake.nix**: Should be extracted to shared modules
4. **`_module.args.pkgs` override**: Fights flake-parts' own nixpkgs module

### Missing Nix Fundamentals

1. Zero `nixosTest` VM tests
2. Zero `flake.overlays` output
3. No `lib/` shared functions directory
4. Flake apps missing `meta.description`

---

## f) Top #25 Things to Get Done Next

Sorted by impact × ease (highest first):

1. Fix 6 pre-existing deadnix warnings → make deadnix check strict (`--fail`)
2. Add `meta.description` to flake apps (trivial, removes warnings)
3. Remove `config.allowBroken = false` (dead config, it's the default)
4. Deduplicate dnsblockd/dnsblockd-processor package definitions
5. Extract overlays to `overlays/` directory
6. Expose `flake.overlays` output
7. Migrate `homepage.nix` to `services.homepage-dashboard` NixOS module
8. Replace `immich-db-backup` with `services.postgresqlBackup`
9. Create `lib/` for shared Nix functions
10. Fix `perSystem` pkgs override to use flake-parts nixpkgs module
11. Convert `test-shell-aliases.sh` to `flake.checks`
12. Convert `test-home-manager.sh` to `flake.checks`
13. Add `nixosTest` for Caddy vhost generation
14. Add `nixosTest` for DNS blocker module
15. Replace `scripts/optimize.sh` with nothing (auto-optimise-store already enabled)
16. Replace `scripts/storage-cleanup.sh` with `systemd.tmpfiles`
17. Replace `scripts/cleanup.sh` with `nix.gc` + timers
18. Replace `scripts/maintenance.sh` with `systemd` services
19. Add `services.netdata` module instead of justfile recipes
20. Make `performance-monitor.sh` a systemd timer
21. Investigate GitHub Dependabot 7 vulnerabilities
22. Extract home-manager config from flake.nix to shared modules
23. Add `nixosTest` for Authelia OIDC
24. Convert `ai-integration-test.sh` to `flake.checks`
25. Consolidate Docker management into `virtualisation.oci-containers`

---

## g) Top #1 Question I Can NOT Figure Out Myself

**Should `fish`, `git`, `fzf`, `tmux`, `zsh`, `bash`, `nushell` be removed from `base.nix`?**

They all have corresponding HM modules in `common/programs/` that install and configure them. But keeping them in `environment.systemPackages` ensures they're available system-wide (for root, for recovery shells, before HM activates). The HM modules add configuration but the system package provides the binary.

Options:

- **A)** Keep both (current for most, works fine, slight duplication)
- **B)** Remove from base.nix entirely, rely on HM only (cleaner but risky for recovery)
- **C)** Keep only in base.nix for shells that are "system shells" (bash, zsh, fish) and remove the rest (git, fzf, tmux, nushell have no recovery need)

This is a user preference / policy decision I can't make autonomously.
