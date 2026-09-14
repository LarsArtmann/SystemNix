# Session 26: Build Fix Marathon — Evaluation + Source Build Repairs

**Date:** 2026-05-05 01:45
**Trigger:** `nh os build .` failed with 20 errors
**Status:** Evaluation passes ✅ — 2 upstream build failures remain ⚠️

---

## Summary

Fixed `nh os build .` from 20 errors down to 2 remaining upstream-only failures. The initial error was a NixOS option conflict between nixpkgs' authelia module and our `harden {}` helper. After fixing that, cascading source build failures were addressed.

---

## A) FULLY DONE ✅

| Item                                 | What                                                                                                                                                                                                               | Files                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------- |
| **Harden mkDefault fix**             | `lib/systemd.nix` now uses `lib.mkDefault` on all values so upstream nixpkgs module defaults take priority. Added `mkDefault'` helper that detects `lib.mkForce`/`lib.mkOverride` thunks to avoid double-wrapping. | `lib/systemd.nix`, `lib/default.nix`     |
| **Harden lib param**                 | Converted `systemd.nix` to curried function `{lib}: { ... }:` so callers pass `{ inherit lib; }` and get back a callable function.                                                                                 | `lib/systemd.nix`                        |
| **All 18 callers updated**           | Every file importing `lib/systemd.nix` now passes `{ inherit lib; }` — matches the new curried signature.                                                                                                          | 18 service modules + scheduled-tasks.nix |
| **DNS blocklist hashes**             | Batch-fetched and updated 11 of 25 blocklist hashes that went stale (HaGeZi lists update frequently).                                                                                                              | `platforms/shared/dns-blocklists.nix`    |
| **mr-sync vendor fix**               | Added `proxyVendor = true` and updated `vendorHash` to fix inconsistent vendoring (charmtone version mismatch). Package builds successfully.                                                                       | `pkgs/mr-sync.nix`                       |
| **wallpaper-set.sh lint**            | Fixed SC2034 (unused `i` → `_`) and SC2012 (ls → find with -iname).                                                                                                                                                | `scripts/wallpaper-set.sh`               |
| **file-and-image-renamer postPatch** | Changed `--replace-fail` to `--replace-warn` and added fallback `echo >> go.mod` to inject replace directives when upstream removes them.                                                                          | `pkgs/file-and-image-renamer.nix`        |
| **NixOS evaluation**                 | `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` passes clean.                                                                                                                         | —                                        |

## B) PARTIALLY DONE 🔧

| Item                             | Status                                                                          | Next Step                                           |
| -------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------- |
| **file-and-image-renamer build** | postPatch fixed but upstream has `gogenfilter@v3.0.0+incompatible` go.mod error | Fix upstream go.mod (major version path mismatch)   |
| **hermes-tui npmDepsHash**       | Hash was restored to cached value, builds from cache                            | May need hash update if hermes-agent source changes |

## C) NOT STARTED ⏳

| Item                                        | Priority | Notes                                                                               |
| ------------------------------------------- | -------- | ----------------------------------------------------------------------------------- |
| AGENTS.md update for new `harden` signature | LOW      | Usage pattern changed: `harden = import ../../../lib/systemd.nix { inherit lib; };` |
| Automated blocklist hash updater            | MEDIUM   | 11/25 stale in one session — needs CI or justfile recipe                            |
| NixOS `just switch`                         | HIGH     | Build must pass first (upstream fixes needed)                                       |

## D) TOTALLY FUCKED UP 💥

| Item                             | Root Cause                                                                                           | Impact                                                                          |
| -------------------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **todo-list-ai build**           | Upstream lockfile stale: `bun install` fails with `lockfile had changes, but lockfile is frozen`     | Blocks `system-path`, `man-paths`, `etc` derivations — cascades to 10+ failures |
| **file-and-image-renamer build** | Upstream `go.mod` has `gogenfilter@v3.0.0+incompatible` — Go refuses to resolve (needs `/v3` suffix) | Can't build the package until upstream fixes go.mod                             |

Both are **upstream issues** that require fixes in their respective GitHub repos, not in SystemNix.

## E) WHAT WE SHOULD IMPROVE 📈

1. **Blocklist hash automation** — Create `just update-blocklists` recipe that batch-fetches all 25 hashes and updates `dns-blocklists.nix`
2. **Upstream health checks** — Add `nix build .#<pkg>` for each custom package in CI/justfile to detect upstream breakage early
3. **Harden helper documentation** — Update AGENTS.md with the new `{ inherit lib; }` pattern
4. **Vendor hash monitoring** — When `proxyVendor = true` is used, the hash changes more often; consider `lib.fakeHash` in dev and real hash in prod
5. **Go module replace resilience** — The `postPatch` pattern should be standardized across all Go packages with private dependencies

## F) Top 25 Next Actions

| #  | Action                                                       | Impact  | Effort |
| -- | ------------------------------------------------------------ | ------- | ------ |
| 1  | Fix todo-list-ai upstream lockfile (PR or push)              | 🔴 HIGH | LOW    |
| 2  | Fix file-and-image-renamer upstream go.mod                   | 🔴 HIGH | LOW    |
| 3  | `just switch` after upstream fixes                           | 🔴 HIGH | LOW    |
| 4  | Create `just update-blocklists` recipe                       | 🟡 MED  | LOW    |
| 5  | Update AGENTS.md with new harden signature                   | 🟡 MED  | LOW    |
| 6  | Add `just build-packages` recipe (builds all custom pkgs)    | 🟡 MED  | LOW    |
| 7  | Test `just switch` on darwin (Lars-MacBook-Air)              | 🟡 MED  | MED    |
| 8  | Review harden mkDefault interactions with all NixOS services | 🟢 LOW  | MED    |
| 9  | Audit all Go packages for stale vendorHashes                 | 🟡 MED  | MED    |
| 10 | Add `nix flake check --no-build` to justfile                 | 🟢 LOW  | LOW    |
| 11 | Enable SigNoz build test in CI                               | 🟢 LOW  | HIGH   |
| 12 | Update flake.lock for all upstream fixes                     | 🟡 MED  | LOW    |
| 13 | Test Immich backup restore procedure                         | 🟢 LOW  | MED    |
| 14 | Review GPU hang recovery (Hermes anime pipeline)             | 🟢 LOW  | HIGH   |
| 15 | DNS failover: provision Pi 3 hardware                        | 🟡 MED  | HIGH   |
| 16 | Add Authelia SSO to remaining services                       | 🟡 MED  | MED    |
| 17 | Centralized AI model storage migration verification          | 🟢 LOW  | LOW    |
| 18 | Niri session restore testing after harden changes            | 🟢 LOW  | LOW    |
| 19 | Review wallpaper self-healing with awww 0.12.0               | 🟢 LOW  | LOW    |
| 20 | Update Crush config deployment (just update && just switch)  | 🟢 LOW  | LOW    |
| 21 | Gitea repo sync automation test                              | 🟢 LOW  | MED    |
| 22 | Twenty CRM build status check                                | 🟢 LOW  | MED    |
| 23 | Gatus endpoint monitoring review                             | 🟢 LOW  | LOW    |
| 24 | Library policy package build verification                    | 🟢 LOW  | LOW    |
| 25 | Disk monitoring setup for BTRFS snapshots                    | 🟢 LOW  | MED    |

## G) Top #1 Question

**Can you (Lars) push fixes to `todo-list-ai` and `file-and-image-renamer` upstream repos?** These are the only remaining blockers for a clean `nh os build .`. The fixes needed are:

1. **todo-list-ai**: Run `bun install` locally and commit the updated `bun.lockb` — the lockfile is out of sync with `package.json`
2. **file-and-image-renamer**: Fix `go.mod` — change `github.com/LarsArtmann/gogenfilter v3.0.0+incompatible` to `github.com/LarsArtmann/gogenfilter/v3 v3.0.0` and run `go mod tidy`

Once both are pushed, `just update && nh os build .` should pass clean.

---

## Build Error Root Cause Analysis

```
Initial: 20 errors
  ├── Evaluation: 1 (ProtectHome conflict) → FIXED ✅
  ├── DNS blocklists: 11 stale hashes → FIXED ✅
  ├── mr-sync: vendor inconsistency → FIXED ✅
  ├── wallpaper-set: shellcheck failures → FIXED ✅
  ├── file-and-image-renamer: upstream go.mod → UPSTREAM ⚠️
  ├── todo-list-ai: upstream lockfile → UPSTREAM ⚠️
  └── hermes-tui: npmDepsHash (cached, may need update) → MONITOR ⚠️

Remaining: 2 upstream-only failures + 1 cached dependency
```

---

_Arte in Aeternum_
