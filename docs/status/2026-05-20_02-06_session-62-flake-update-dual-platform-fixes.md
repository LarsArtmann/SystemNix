# SystemNix Status Report — Session 62

**Date:** 2026-05-20 02:06 | **Session:** 62 | **Trigger:** `nix flake update` broke both Darwin and NixOS builds

---

## Executive Summary

`nix flake update` pulled a home-manager update that introduced a git LFS config conflict (NixOS) and a `nix.gc.persistent` removal (Darwin). Both builds were broken. Both are now fixed. Evaluation passes on all 3 targets. Full build not yet verified (370 derivations need compilation).

---

## a) FULLY DONE ✅

| # | Item | Details |
|---|------|---------|
| 1 | **Git LFS conflict fix** | Removed duplicate `filter."lfs"` block from `platforms/common/programs/git.nix` (lines 56-63). `lfs.enable = true` already sets all LFS filter config with proper nix store paths. Manual block used bare `git-lfs` commands → conflicting `iniContent.filter.lfs.clean` values after home-manager update. |
| 2 | **Darwin `nix.gc.persistent` fix** | Moved `persistent = true` into the `lib.optionalAttrs (!pkgs.stdenv.isDarwin)` block in `platforms/common/nix-settings.nix`. nix-darwin removed this option (no launchd equivalent). Was set unconditionally, breaking Darwin evaluation. |
| 3 | **NixOS evaluation verified** | `nix eval .#nixosConfigurations.evo-x2` passes ✅ |
| 4 | **Darwin evaluation verified** | `nix eval .#darwinConfigurations.Lars-MacBook-Air` passes ✅ |
| 5 | **rpi3-dns evaluation verified** | `nix eval .#nixosConfigurations.rpi3-dns` passes ✅ |
| 6 | **Flake check passes** | `nix flake check --no-build` — all checks passed |

---

## b) PARTIALLY DONE ⚠️

| # | Item | Status | Blocker |
|---|------|--------|---------|
| 1 | **Full NixOS build** | Evaluation passes, but 370 derivations need compilation. `nix build` failed during dependency chain (polkit/dbus/fish-completions) — likely cache miss, not eval error. Needs `nh os boot .` with network access. |
| 2 | **Darwin full build** | Evaluation passes, but haven't run `nh darwin build .` from MacBook. Need to `just switch` from Darwin to verify. |
| 3 | **flake.lock update committed** | Lockfile has 20+ input updates (branching-flow, BuildFlow, cmdguard, dnsblockd, emeet-pixyd, file-and-image-renamer, go-branded-id, go-filewatcher, go-finding, go-output, go-structure-linter, gogenfilter, golangci-lint-auto-configure, hierarchical-errors, home-manager, homebrew-cask, monitor365, mr-sync, niri, nixpkgs-stable, NUR, projects-management-automation, rust-overlay). Needs commit. |

---

## c) NOT STARTED 📋

| # | Item | Priority |
|---|------|----------|
| 1 | **Deploy to evo-x2**: Run `nh os boot .` to verify full build succeeds with 370 derivations | Critical |
| 2 | **Deploy to MacBook Air**: Run `just switch` from Darwin to verify full build | Critical |
| 3 | **Check vendorHash drift**: 20+ Go/Rust repos updated — any `vendorHash` mismatches? Build will reveal them. | High |
| 4 | **Test git LFS on evo-x2**: Verify `git lfs install` and `git lfs pull` still work after removing manual filter config | Medium |
| 5 | **Verify home-manager git LFS behavior**: Confirm HM's `lfs.enable = true` produces working `.gitconfig` with nix store paths | Medium |

---

## d) TOTALLY FUCKED UP ❌

| # | Item | What Happened | Root Cause | Resolution |
|---|------|---------------|------------|------------|
| 1 | **NixOS build broken** | `iniContent.filter.lfs.clean` conflicting definition values | home-manager update changed how `lfs.enable = true` sets filter values — now uses `/nix/store/...-git-lfs-3.7.1/bin/git-lfs clean -- %f` instead of bare `git-lfs clean -- %f`. Our manual `filter."lfs"` block still used bare commands. | Removed manual block. `lfs.enable = true` handles everything. |
| 2 | **Darwin build broken** | `nix.gc.persistent` option no longer has any effect | nix-darwin removed `nix.gc.persistent` (no launchd equivalent). Our `nix-settings.nix` set it unconditionally in the common gc block. | Moved `persistent = true` into the `!isDarwin` conditional block. |
| 3 | **Both platforms broken simultaneously** | `nix flake update` updated both home-manager AND nix-darwin lock inputs, causing cascading failures on both platforms | Running `nix flake update` without `--test` first. The `just test-fast` command exists but wasn't used. | Fixed both. **Lesson: always run `just test-fast` after `nix flake update` before committing.** |

---

## e) WHAT WE SHOULD IMPROVE 🔧

| # | Improvement | Why | How |
|---|------------|-----|-----|
| 1 | **Never duplicate HM module config** | `lfs.enable = true` AND manual `filter."lfs"` = split brain. If HM provides an enable flag, don't also set the underlying options manually. | Audit all `programs.*` modules for duplicate enable+manual-config patterns. |
| 2 | **Gate NixOS-only options in shared config** | `persistent = true` was set in common config but only works on NixOS. Darwin silently accepted it until it didn't. | Audit `nix-settings.nix` for other NixOS-only options. Pattern: `lib.optionalAttrs (!pkgs.stdenv.isDarwin) { ... }`. |
| 3 | **CI should build both platforms** | `nix flake check --no-build` only evaluates, doesn't catch runtime option conflicts that manifest as assertion failures. | GitHub Actions `nix-check` workflow should eval both `nixosConfigurations` and `darwinConfigurations`. |
| 4 | **Pre-commit hook for option conflicts** | The `nix.gc.persistent` removal could have been caught by a simple eval check in CI. | Add `nix eval .#darwinConfigurations.Lars-MacBook-Air.config.system.build.toplevel.drvPath` to CI. |
| 5 | **Test after `nix flake update`** | Running `nix flake update && nh os boot .` in one shot means you can't separate "update broke eval" from "build failed". | Always run `just test-fast` (or `nix flake check --no-build`) after `nix flake update` before building. |
| 6 | **`hostPlatform` deprecation warning** | NixOS eval warns `'hostPlatform' has been renamed to/replaced by 'stdenv.hostPlatform'`. Not blocking but should be fixed. | Search for `hostPlatform` usage and update. |

---

## f) TOP 25 THINGS TO DO NEXT

| # | Task | Impact | Effort | Priority |
|---|------|--------|--------|----------|
| 1 | Deploy to evo-x2 (`nh os boot .`) — verify 370 derivations build | Critical | 10min | P0 |
| 2 | Deploy to MacBook Air (`just switch`) — verify Darwin build | Critical | 10min | P0 |
| 3 | Fix `vendorHash` drift from 20+ updated Go/Rust inputs | High | 30min | P0 |
| 4 | Provision Pi 3 hardware for DNS failover cluster | High | 2h | P1 |
| 5 | Wire Pi 3 as secondary DNS in dns-failover.nix | High | 1h | P1 |
| 6 | Fix `hostPlatform` → `stdenv.hostPlatform` deprecation warning | Medium | 15min | P1 |
| 7 | Add Darwin eval to GitHub Actions CI | High | 30min | P1 |
| 8 | Audit all `programs.*` for duplicate enable+manual-config patterns | Medium | 1h | P2 |
| 9 | Audit `nix-settings.nix` for other NixOS-only options leaking to Darwin | Medium | 15min | P2 |
| 10 | Wire `nix-colors` to Home Manager — migrate 17+ hardcoded colors | Medium | 6h | P2 |
| 11 | Deploy Dozzle at `logs.home.lan` for Docker container log tailing | Medium | 2h | P2 |
| 12 | Add per-threshold SigNoz channel routing (critical→Discord, warning→log) | Medium | 1h | P2 |
| 13 | Consolidate voice-agents Caddy vHost into caddy.nix pattern | Medium | 30min | P2 |
| 14 | Convert go-auto-upgrade `path:` inputs to SSH URLs | Low | 30min | P3 |
| 15 | Create shared flake-parts template (mkGoPackage, checks, devshells) | Medium | 4h | P3 |
| 16 | Test voice-agents (Whisper Docker + ROCm) end-to-end | Medium | 1h | P3 |
| 17 | Re-enable auditd after NixOS 26.05 bug #483085 is fixed | Low | 15min | P3 |
| 18 | Consider AppArmor profile for Forgejo runner containers | Low | 2h | P3 |
| 19 | Extract monitor365.nix (709 lines) into sub-modules | Low | 2h | P3 |
| 20 | Extract forgejo.nix (565 lines) into sub-modules | Low | 2h | P3 |
| 21 | Extract signoz.nix (679 lines) into sub-modules | Low | 2h | P3 |
| 22 | Add dnsblockd temp-allow persistence (SQLite/file) | Low | 4h | P4 |
| 23 | Investigate DNS-over-QUIC without breaking binary cache | Low | 4h | P4 |
| 24 | Replace benchmark/performance-monitor/shell-context scripts or remove from FEATURES.md | Low | 30min | P4 |
| 25 | PhotoMap AI: update pinned SHA256 or remove | Low | 15min | P4 |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT 🤔

**Will any of the 20+ updated Go/Rust input repos have stale `vendorHash` values that break the build?**

Multiple Go repos were updated (branching-flow, BuildFlow, go-output, go-structure-linter, mr-sync, file-and-image-renamer, golangci-lint-auto-configure, hierarchical-errors, projects-management-automation). Since these use `_local_deps` pattern with `replace` directives and `overrideModAttrs`, any upstream `go.mod`/`go.sum` changes will invalidate existing `vendorHash` values. The only way to know is to attempt a full build and check for hash mismatch errors. The AGENTS.md documents the fix pattern: set `vendorHash = ""`, build, grep for `got:` hash, paste back.

---

## Build Status Matrix

| Target | Eval | Build | Deploy |
|--------|------|-------|--------|
| evo-x2 (NixOS) | ✅ | ⚠️ 370 derivations pending | ❌ |
| Lars-MacBook-Air (Darwin) | ✅ | ❌ Not tested | ❌ |
| rpi3-dns (NixOS) | ✅ | N/A (SD image) | N/A |

## Changes This Session

| File | Change | Type |
|------|--------|------|
| `flake.lock` | 20+ input updates from `nix flake update` | chore |
| `platforms/common/programs/git.nix` | Removed duplicate `filter."lfs"` block (lines 56-63) | fix |
| `platforms/common/nix-settings.nix` | Moved `persistent = true` into `!isDarwin` conditional block | fix |

## Flake Input Updates (20+ inputs)

| Input | Old Rev (short) | New Rev (short) |
|-------|-----------------|-----------------|
| branching-flow | 8fe5f1a | 7876949 |
| buildflow | 03596a4 | 43f219a |
| cmdguard | ff51ce4 | 942c30a |
| dnsblockd | 281ee20 | 9477537 |
| emeet-pixyd | 71ba01b | 85aaa0d |
| file-and-image-renamer | 7bced23 | 002b66c |
| go-branded-id | 908b1a1 | 5d02ae6 |
| go-filewatcher | fa89918 | 963f457 |
| go-finding | ddf6e06 | 957e233 |
| go-output | a2b153e | 6d55648 |
| go-structure-linter | 4411267 | 12a9879 |
| gogenfilter | a518808 | 2a0e0ec |
| golangci-lint-auto-configure | 0d1731b | 1f2417f |
| hierarchical-errors | 7357522 | 3f25153 |
| home-manager | 736c208 | bd868f7 |
| homebrew-cask | 33f8672 | 56e49af |
| monitor365 | 09f8dbe | 67a4469 |
| mr-sync | 8dcd56c | 3b3213c |
| niri | daefca3 | f402770 |
| nixpkgs-stable | d7a713c | 687f05a |
| NUR | f429145 | 3331b7b |
| projects-management-automation | 2731cfa | 26299194 |
| rust-overlay | 2a77b5b | 8cd5926 |

---

_Session 62 — fixes for home-manager git LFS conflict + nix-darwin gc.persistent removal_
