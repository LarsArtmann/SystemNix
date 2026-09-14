# Session 21: Deep Cleanup & Architecture Improvements

**Date:** 2026-05-04
**Trigger:** User asked "What did you forget? What could you have done better?"
**Scope:** Self-audit of prior session's work (Go overlay removal, niri script extraction, justfile ghost cleanup)

---

## A) Fully Done

### Original tasks (prior session — verified correct)

1. **Go 1.26.1 overlay removal** — Removed Darwin-only Go pin, now uses nixpkgs default
2. **Niri session scripts extracted** — ~300 lines of inline shell → `scripts/niri-session-save.sh` + `scripts/niri-session-restore.sh` with template injection
3. **Justfile ghost cleanup** — Removed ~315 lines of dead recipes (netdata, ntopng, better-claude, keychain, tmux-save/restore, perf-full-analysis, automation-setup)

### Self-audit fixes (this session)

4. **`rm -rf` → `trash`** — All clean recipes now use `trash` instead of `rm -rf` (3 commits)
5. **Platform guards** — Fixed `activitywatch` recipe (macOS-only), removed dead `tmux-save`/`tmux-restore`
6. **Keychain ghost recipes removed** — 13 recipes (~100 lines) referencing non-existent keychain tools
7. **Pre-commit shellcheck** — Added shellcheck hook for `scripts/*.sh` with proper severity/exclusions
8. **Caddy hardcoded IP fix** — Replaced `192.168.1.0/24` with `config.networking.local.subnet`
9. **Dead code removed** — Deleted `scripts/lib/paths.sh` (157-line library sourced by nothing)
10. **Systemd hardening consolidation** — Replaced inline hardening fields in `file-and-image-renamer.nix` with `harden {}` from `lib/systemd.nix`
11. **Shared types library** — Created `lib/types.nix` with reusable service option constructors (`systemdServiceIdentity`, `servicePort`, `restartDelay`, `stopTimeout`); adopted in `hermes.nix`
12. **Systemd StartLimitBurst fix** — Moved `StartLimitBurst`/`StartLimitIntervalSec` to `[Unit]` section where they belong
13. **Overlay consolidation** — Eliminated 16 lines of duplicated overlay entries in `perSystem` block; now references `sharedOverlays` + `linuxOnlyOverlays` directly
14. **dep-graph platform fix** — Uses `xdg-open` on Linux for graph viewing

### Commits (this session)

```
4a760da refactor(flake): consolidate perSystem overlays to reference shared lists
64604ec feat(lib): add shared types library, adopt harden in file-and-image-renamer
6278caa chore: remove dead scripts/lib/paths.sh
d147edd fix(caddy): use config.networking.local.subnet instead of hardcoded IP
1e28690 fix(justfile): platform-aware file opener in dep-graph, trash for clean
3a4b1cd fix(justfile): replace remaining rm -rf with trash
d9109f1 fix(systemd): move StartLimitBurst/StartLimitIntervalSec to [Unit] section
74fcad9 fix(justfile): replace rm -rf with trash in clean recipes
c523dec feat(pre-commit): add shellcheck for scripts/ directory
552153c fix(justfile): add platform guards to activitywatch, remove dead tmux-save/restore
a0323f5 chore(justfile): remove keychain ghost recipes
c180e17 docs(agents): update niri session and Go overlay docs
405c6cf docs(features): update Go toolchain entry after overlay removal
```

---

## B) Partially Done

| Item                                  | Status                  | Notes                                                                                                                     |
| ------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `harden` adoption across all services | 12/30 modules           | 10 already used it, 2 fixed this session. 18 remain but many are acceptable (services without system-level systemd units) |
| `serviceDefaults` adoption            | Partial                 | Only used in ~6 services. Not all services need it (e.g., docker-based services)                                          |
| `lib/types.nix` adoption              | 1 consumer (hermes.nix) | Pattern proven, can be incrementally adopted                                                                              |

---

## C) Not Started

| Item                                                        | Impact | Effort           | Notes                                                                                 |
| ----------------------------------------------------------- | ------ | ---------------- | ------------------------------------------------------------------------------------- |
| Adopt `serviceTypes` in remaining 20+ service modules       | Medium | Low (mechanical) | Each module replaces repeated user/group/port option definitions                      |
| Justfile split into `import` files or migration to Nix apps | High   | Medium           | 1600 lines / 134 recipes is unwieldy                                                  |
| Audit all service modules for `harden` + `serviceDefaults`  | Medium | Medium           | 18 modules don't use `harden`, but many are Docker/HM services where it doesn't apply |
| NixOS tests for custom modules                              | High   | High             | Zero automated NixOS tests exist                                                      |
| Template validation for niri session scripts                | Low    | Low              | Could add `buildPhase` check that template vars resolve                               |

---

## D) Fucked Up

| Issue                              | Impact                              | Fix                                                                                               |
| ---------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------- |
| Hermes service owns `.git/index`   | Git operations fail for user `lars` | `git read-tree HEAD` rebuilds index. Root cause: Hermes gitea-sync likely runs `git` in this repo |
| Missed `rm -rf` in initial cleanup | Safety violation                    | Found 3 more instances, all fixed now                                                             |

---

## E) Improve

### Architecture improvements made this session

1. **`lib/types.nix`** — First step toward shared type constructors. Follows `lib/systemd.nix` pattern (function + inherit from lib).
2. **Overlay single source of truth** — `sharedOverlays` and `linuxOnlyOverlays` are now the canonical lists, referenced everywhere.
3. **Shellcheck in CI** — `scripts/` directory now has automated shell script linting.

### Patterns to continue

- `lib/` functions: pure Nix functions that return attrsets. Callers use `import ../../../lib/types.nix { inherit lib; }`.
- Template injection for shell scripts: `builtins.readFile` + `builtins.replaceStrings` keeps scripts testable outside Nix.

---

## F) Top 25 Next Steps (by impact × effort)

1. **Investigate Hermes `.git/index` ownership** — Could affect other repos too
2. **Adopt `serviceTypes` in taskchampion, caddy, gitea, immich** — Highest-value service modules
3. **Split justfile into `justfile` + `justfile.services` + `justfile.dev`** — `import` directive
4. **Add `harden {}` to remaining system-level services** — authelia, signoz, monitor365
5. **Create NixOS test for dnsblockd** — Most critical custom service
6. **Audit all `systemd.services` for correct `Type=`** — Wrong type causes silent failures
7. **Centralize all hardcoded ports into module options** — grep for `port =` patterns
8. **Add `lib/types.nix` consumer for monitor365, netwatch, disk-monitor** — Newer modules easiest
9. **Create `docs/adr/` for lib/types.nix pattern** — Document the decision
10. **Verify all service `ExecStart` paths resolve** — `nix eval` spot checks
11. **Add `just validate` to pre-push hook** — Catch issues before push
12. **Migrate remaining inline shell in niri-wrapped.nix** — Session restore has more templates
13. **Audit `perSystem` packages list completeness** — Ensure all overlays have corresponding packages
14. **Add `just switch` dry-run mode** — Build without activating
15. **Centralize port declarations in `networking.local`** — Like subnet IP pattern
16. **Create shared `services.defaults` module** — Common options for all NixOS services
17. **Add `just test-integration` recipe** — Run NixOS VM tests
18. **Audit secret references** — Ensure all sops secrets referenced in services exist in encrypted file
19. **Add dependency graph between service modules** — Ensure ordering is correct
20. **Create `lib/build.nix`** — Shared build helpers (Go, Rust, Python)
21. **Verify BTRFS snapshot timer runs** — Configured but not verified
22. **Add health checks to remaining services** — `ExecStartPost` + curl
23. **Document module option schema in AGENTS.md** — For each service module
24. **Create `just lint-nix` recipe** — Run statix + deadnix + alejandra
25. **Add `flake.lock` auto-update workflow** — Dependabot-equivalent

---

## G) #1 Question for User

**Should the justfile be split into multiple files using `import`, or should recipes be migrated to Nix apps?**

The justfile is ~1600 lines with 134 recipes. `just` supports `import` for splitting. Alternatively, many recipes could be Nix `apps` (like `deploy` and `validate` already are). The mixed approach (just for orchestration, Nix apps for buildable tasks) seems most practical.

---

## Statistics

- **Commits this session:** 13
- **Lines removed:** ~500+ (ghost recipes, dead code, duplicated overlays)
- **Lines added:** ~100 (types library, platform guards, consolidated references)
- **Files modified:** 10
- **New files:** 2 (`lib/types.nix`, status report)
- **Deleted files:** 1 (`scripts/lib/paths.sh`)
- **All pre-commit hooks:** Passing (gitleaks, deadnix, statix, alejandra, nix flake check, shellcheck)
