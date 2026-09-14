# Session 25 — Unsloth Disable, Harden Fix, Full Status

**Date:** 2026-05-05 00:57
**Session:** 25 (following Session 24 full audit)
**Status:** Ready for user instructions
**Flake:** `all checks passed!`

---

## A. FULLY DONE ✓

### This Session (25)

| # | Change                                                                                                                                                            | Files                                                                     |
| - | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| 1 | **Disable Unsloth Studio** — removed stale references from caddy, homepage, DNS blocker (evo-x2 + rpi3)                                                           | `caddy.nix`, `homepage.nix`, `dns-blocker-config.nix`, `rpi3/default.nix` |
| 2 | **Fix `lib/systemd.nix` curried signature** — made it `{lib, ...}: { overrides... }: { ... }` so `harden {}` call pattern works with `lib.mkDefault`              | `lib/systemd.nix`                                                         |
| 3 | **Fix `hermes.nix` scoping** — moved `harden` import from outer `let` (no `lib`) into module function scope                                                       | `modules/nixos/services/hermes.nix`                                       |
| 4 | **Fix `file-and-image-renamer.nix`** — reverted incorrect `harden/serviceDefaults` usage (it's a `systemd.user.services` module, `harden` is for system services) | `modules/nixos/services/file-and-image-renamer.nix`                       |
| 5 | **Updated all 16 service modules** — changed `import ../../../lib/systemd.nix` → `import ../../../lib/systemd.nix {inherit lib;}` to match curried signature      | 16 files                                                                  |
| 6 | **Updated `lib/default.nix`** — pass `{inherit lib;}` to curried harden function                                                                                  | `lib/default.nix`                                                         |

### Session 24 (Previous — Committed, Had Bugs)

| #  | Change                                                                  | Status                                    |
| -- | ----------------------------------------------------------------------- | ----------------------------------------- |
| 1  | Created `lib/default.nix` entry point                                   | ✓ Done                                    |
| 2  | Added `harden {}` to authelia, caddy, monitor365, gitea-repos, photomap | ✓ Done                                    |
| 3  | Added `serviceDefaults {}` to homepage, file-and-image-renamer          | ⚠️ Partial (renamer reverted this session) |
| 4  | Removed `__GLX_VENDOR_LIBRARY_NAME` from amd-gpu.nix                    | ✓ Done                                    |
| 5  | Fixed dns-blocker.nix `\n` newline bug                                  | ✓ Done                                    |
| 6  | Fixed `modernize.nix` sha256→hash                                       | ✓ Done                                    |
| 7  | Removed dead code in `netwatch.nix`, `darwin/home.nix`                  | ✓ Done                                    |
| 8  | Merged 3 separate `services.*` blocks in `boot.nix`                     | ✓ Done                                    |
| 9  | Removed unused niri wallpaper binding                                   | ✓ Done                                    |
| 10 | Updated AGENTS.md                                                       | ✓ Done                                    |

### Evergreen (Across All Sessions)

- 104 `.nix` files, 31 service modules, 5,511 lines of service code
- 16/31 modules using `harden` (52% adoption)
- 6/31 modules using `serviceDefaults` (19% adoption)
- Catppuccin Mocha theme everywhere
- SigNoz observability pipeline operational
- DNS failover cluster designed (Pi 3 not yet provisioned)
- GPU hang defense-in-depth (6-layer: sysrq, watchdog, amdgpu recovery, pstore, systemd, kernel panic)
- Niri session save/restore with crash recovery
- Centralized AI model storage at `/data/ai/`
- All private repos use `git+ssh://` URLs (no `path:` inputs)
- Pre-commit hook: gitleaks + deadnix + statix + alejandra + nix flake check

---

## B. PARTIALLY DONE

| Item                                                                   | Progress                                                                                                       | Blocker                                                                                           |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `harden {}` adoption across all services                               | 16/31 (52%)                                                                                                    | Remaining 15 modules need individual review — some are oneshots, some use `systemd.user.services` |
| `serviceDefaults {}` adoption                                          | 6/31 (19%)                                                                                                     | Low priority — many services have custom restart values                                           |
| `lib/types.nix` helpers (`servicePort`, `restartDelay`, `stopTimeout`) | Only used by `hermes.nix`                                                                                      | Other modules hardcode port/delay values directly                                                 |
| `lib/default.nix` central import                                       | Created but not used by any module — all modules import directly                                               | Would need to refactor all import paths                                                           |
| Catppuccin color adoption via `colorScheme.palette`                    | `zellij.nix` uses it correctly; `waybar.nix`, `rofi.nix`, `swaylock.nix`, `yazi.nix` still hardcode hex colors | Medium effort, low risk                                                                           |
| Status report archiving                                                | `docs/status/` has 80+ files, `archive/` exists but most old reports not moved                                 | Low priority cleanup                                                                              |

---

## C. NOT STARTED

| #  | Item                                                                           | Priority | Effort   | Impact                     |
| -- | ------------------------------------------------------------------------------ | -------- | -------- | -------------------------- |
| 1  | Shared `primaryUser` option (replace 14 hardcoded `"lars"` references)         | P1       | Medium   | High — DRY, portability    |
| 2  | Split `signoz.nix` (741 lines) into sub-modules                                | P2       | High     | Medium — readability       |
| 3  | Fix `taskwarrior.nix` — uses `systemd.user` unguarded on Darwin                | P2       | Low      | High — Darwin breakage     |
| 4  | Fix `nix-settings.nix` — `sandbox = true` may break Darwin                     | P2       | Low      | Medium — Darwin breakage   |
| 5  | Adopt `colorScheme.palette` in 4 desktop modules                               | P3       | Medium   | Low — aesthetics           |
| 6  | Fix starship disabled-but-enabled modules                                      | P3       | Low      | Low                        |
| 7  | `lib/default.nix` adoption — refactor all modules to import from central entry | P3       | Medium   | Low — consistency          |
| 8  | DNS failover Pi 3 provisioning                                                 | P3       | External | High — when hardware ready |
| 9  | Status report archiving (keep last 5, archive rest)                            | P3       | Low      | Low                        |
| 10 | Add `harden {}` to remaining 15 service modules (where applicable)             | P3       | Medium   | Medium                     |

---

## D. TOTALLY FUCKED UP ✗

### Session 24 Bugs Fixed This Session

| Bug                                                     | Root Cause                                                                                                                                                                                                                                         | Fix                                                                                                  |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **`lib/systemd.nix` broke all `harden {}` calls**       | Session 24 added `lib` as a flat parameter alongside overrides. Callers did `import ... {inherit lib;}` which returned an attrset, then `harden {}` tried to call it as a function → `attempt to call something which is not a function but a set` | Curried: `{lib, ...}: { overrides }: { ... }`. First call injects lib, second call applies overrides |
| **`hermes.nix` undefined `lib`**                        | `harden` import was in outer `let` block where `lib` wasn't in scope (only available inside `flake.nixosModules.hermes` function)                                                                                                                  | Moved import into module function's `let` block                                                      |
| **`file-and-image-renamer.nix` harden on user service** | Session 24 applied `harden {}` to `systemd.user.services` which uses different `Service` format (attrset, not `serviceConfig`). Hardening fields like `PrivateTmp`, `ProtectSystem` are system-level only                                          | Reverted to plain inline `Service = { ... }` attrset                                                 |

### Remaining Concerns

| Concern                                    | Severity | Notes                                                                                                                                                                                                                                                                                                       |
| ------------------------------------------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Session 24 committed broken code**       | High     | 3 separate bugs were committed and pushed. Pre-commit hook passes `nix flake check` but the `harden {}` change in `lib/systemd.nix` itself didn't get caught because the old callers were already committed before the signature changed. Fix: always run `nix flake check` AFTER all changes, not between. |
| **Pre-commit hook auto-rewrites messages** | Medium   | The `.githooks/pre-commit` rewrites commit messages. This creates confusion about what was actually committed.                                                                                                                                                                                              |
| **`just switch` would have failed**        | High     | If someone had run `just switch` between Session 24 commits and this fix, the system would have failed to build due to the `harden` signature mismatch affecting 16 services.                                                                                                                               |

---

## E. WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Atomic commits** — The `lib/systemd.nix` signature change + all 16 caller updates should have been ONE commit, not separate. Changing a shared library's API and updating callers in different commits creates a broken intermediate state.
2. **Post-change validation** — Always run `nix flake check --all-systems` AFTER the final change in a batch, not just after each individual change.
3. **Test the actual call pattern** — When changing a function signature, verify the call pattern still works before committing.
4. **Beware `mkDefault` scope** — `lib.mkDefault` is useful for module options but overkill for `serviceConfig` attrsets merged with `//`. The `//` operator already handles overrides. Consider whether `mkDefault` is needed here or if plain values + `//` suffice.

### Codebase Improvements

1. **`primaryUser` option** — 14 hardcoded `"lars"` across 12 files is the #1 DRY violation
2. **`systemd.user.services` vs `systemd.services` distinction** — `harden {}` only works for system services. Need a separate (lighter) hardening function for user services, or just don't harden them.
3. **Signoz 741-line monolith** — Should split into `signoz/` directory with sub-modules
4. **Dead status reports** — 80+ files in `docs/status/`, most are historical. Archive everything older than 7 days.

---

## F. TOP 25 THINGS TO DO NEXT

### P1 — High Impact, Low Effort (Do First)

| # | Task                                                                                                                         | Effort | Impact | Files     |
| - | ---------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | --------- |
| 1 | **Create shared `primaryUser` option** — Add `options.users.primaryUser` module, replace 14 hardcoded `"lars"`               | Medium | High   | 12+ files |
| 2 | **Fix `taskwarrior.nix` Darwin guard** — Wrap `systemd.user` in `pkgs.stdenv.isLinux`                                        | Low    | High   | 1 file    |
| 3 | **Fix `nix-settings.nix` Darwin sandbox** — Guard `sandbox = true` with `isLinux`                                            | Low    | Medium | 1 file    |
| 4 | **Add `harden {}` to remaining applicable services** — gitea, immich, signoz, minecraft, comfyui, twenty, voice-agents, sops | Medium | Medium | 8 files   |
| 5 | **Archive old status reports** — Move 75+ old reports to `docs/archive/status/`                                              | Low    | Low    | Cleanup   |

### P2 — Medium Impact, Medium Effort

| #  | Task                                                                                             | Effort | Impact | Files     |
| -- | ------------------------------------------------------------------------------------------------ | ------ | ------ | --------- |
| 6  | **Adopt `colorScheme.palette`** in waybar, rofi, swaylock, yazi                                  | Medium | Low    | 4 files   |
| 7  | **Fix starship disabled-but-enabled modules**                                                    | Low    | Low    | 1 file    |
| 8  | **Adopt `lib/types.nix` helpers** (`servicePort`, `restartDelay`) in service modules             | Medium | Medium | 10+ files |
| 9  | **Add `MemoryMax` bounds to all services** — Prevent any single service from consuming all 128GB | Medium | High   | 15 files  |
| 10 | **Split `signoz.nix` into sub-modules**                                                          | High   | Medium | 1→4 files |
| 11 | **Refactor `lib/default.nix` adoption** — Change all modules to import from central entry        | Medium | Low    | 16 files  |
| 12 | **Add `serviceDefaults {}` to more services** — Standardize restart behavior                     | Low    | Medium | 15 files  |
| 13 | **Audit all `ExecStart` for hardcoded paths** — Should use `${pkgs.*}/bin/` consistently         | Medium | Medium | 20+ files |
| 14 | **Consolidate DNS service lists** — evo-x2 and rpi3 have duplicate `local-data` lists            | Low    | Medium | 2 files   |

### P3 — Lower Priority, Worth Doing Eventually

| #  | Task                                                                                                   | Effort   | Impact |
| -- | ------------------------------------------------------------------------------------------------------ | -------- | ------ |
| 15 | **DNS failover Pi 3 provisioning** — Hardware-dependent                                                | External | High   |
| 16 | **Test Darwin build** — `nix build .#darwinConfigurations.Lars-MacBook-Air.system`                     | Low      | High   |
| 17 | **Extract common Caddy vhost pattern** into a helper function                                          | Low      | Low    |
| 18 | **Add health check endpoints** to custom services (photomap, voice-agents, comfyui)                    | Medium   | Medium |
| 19 | **Centralize firewall port management** — Ports scattered across modules                               | Medium   | Medium |
| 20 | **Audit all `tmpfiles.rules` for consistency** — Some use `primaryUser`, some hardcode                 | Low      | Low    |
| 21 | **Add `ReadWritePaths` to hardened services** — Some may need explicit write paths                     | Medium   | Medium |
| 22 | **Create NixOS test harness** — `nixosTests` for critical services                                     | High     | High   |
| 23 | **Migrate remaining `imports` to use `lib/default.nix`** central entry                                 | Medium   | Low    |
| 24 | **Review all `wantedBy = ["multi-user.target"]`** — Some services should be `graphical-session.target` | Low      | Medium |
| 25 | **Add structured logging** to custom services — Standardize on `slog` (Go) and `structlog` (Python)    | Medium   | Medium |

---

## G. TOP #1 QUESTION

**Should `harden {}` use `lib.mkDefault` or plain values?**

Currently, `harden {}` wraps every field in `lib.mkDefault`. This means callers can override with plain `//` merge:

```nix
serviceConfig = harden {MemoryMax = "1G";} // { NoNewPrivileges = false; };
```

The `NoNewPrivileges = false` wins because it's not wrapped in `mkDefault`. But `mkDefault` has a priority of 1000 (lower than `mkOptionDefault` at 100). This is fine for `serviceConfig` attrsets but adds complexity.

**Question:** Is the `mkDefault` wrapping actually necessary here? Since all callers use `//` merge (not module option merging), plain values would work identically:

```nix
# Without mkDefault — simpler, same behavior with // merge
harden = import ../../../lib/systemd.nix {inherit lib;};
serviceConfig = harden {MemoryMax = "1G";} // { NoNewPrivileges = false; };
```

The `//` operator always takes the right side. `mkDefault` only matters for NixOS module option merging (`lib.mkMerge`), which we don't use for `serviceConfig`. Should we simplify to plain values?

---

## System Health

| Check                                      | Status                                    |
| ------------------------------------------ | ----------------------------------------- |
| `nix flake check --all-systems --no-build` | ✅ Passed                                 |
| Platform                                   | NixOS x86_64-linux (evo-x2)               |
| Kernel                                     | AMD Ryzen AI Max+ 395, 128GB              |
| Branch                                     | `master`, up to date with `origin/master` |
| Uncommitted changes                        | 22 modified files (this session's fixes)  |

---

_Arte in Aeternum_
