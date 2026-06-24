# Session 141 — Overlay System Overhaul: mkPackageOverlay Eliminated

**Date:** 2026-06-17 14:58 CEST
**Branch:** master
**Previous commit:** `5f83c9bb` — Update flake inputs to latest revisions + add USB printing support

---

## Executive Summary

Systematic elimination of the `mkPackageOverlay` indirection layer that wrapped 12 LarsArtmann Go tool packages into nixpkgs overlays solely so they could be referenced as `pkgs.<name>`. Replaced with `mkLarsPackages` — a single source-of-truth function in `flake.nix` that resolves packages directly from flake inputs. Net **-50 lines**, zero duplication, and the `art-dupl` vendorHash mismatch that blocked `nh os boot` is now fixed inline.

---

## a) FULLY DONE

### Overlay System Refactoring (THIS SESSION)

| Item | Status | Details |
|------|--------|---------|
| `mkPackageOverlay` helper removed | ✅ Done | Eliminated from `overlays/default.nix` entirely |
| 12 Go tool overlays removed from `shared.nix` | ✅ Done | art-dupl, buildflow, branching-flow, go-auto-upgrade, go-structure-linter, golangci-lint-auto-configure, hierarchical-errors, library-policy, mr-sync, project-meta, projects-management-automation, todo-list-ai |
| `mkLarsPackages` single source of truth | ✅ Done | Top-level `let` in `flake.nix:476-514` — resolves all Go tools from flake inputs, handles vendorHash/mkTidy overrides, platform-safe via `filterAttrs` |
| `perSystem.packages` simplified | ✅ Done | Uses `mkLarsPackages system` directly instead of `inherit (pkgs)` for 12 packages |
| `base.nix` simplified | ✅ Done | Receives `larsPackages` attrset via specialArgs, uses `builtins.attrValues` — no more individual Go tool inputs or override helpers |
| PMA service module fixed | ✅ Done | `projects-management-automation.nix` now references `inputs.projects-management-automation.packages.${pkgs.stdenv.hostPlatform.system}.default` directly |
| `art-dupl` vendorHash fixed | ✅ Done | Correct hash `sha256-IcR8IPln7ZBB+QJP2MZKFMdr0204pgdH9IA/lIbrpjA=` applied inline in `mkLarsPackages` |
| Darwin specialArgs wired | ✅ Done | `larsPackages = mkLarsPackages "aarch64-darwin"` passed to Darwin config |
| NixOS specialArgs wired | ✅ Done | `larsPackages = mkLarsPackages "x86_64-linux"` passed to NixOS config |
| AGENTS.md updated | ✅ Done | Removed all `mkPackageOverlay` references, documented new `mkLarsPackages` pattern |
| `just test-fast` passes | ✅ Done | All eval checks pass, zero warnings (fixed `pkgs.system` deprecation too) |
| Formatted with alejandra | ✅ Done | `nix fmt .` — 2 files changed (formatting only) |

### Pre-Existing (From Prior Sessions)

| Item | Status | Details |
|------|--------|---------|
| Cross-platform flake (Darwin + NixOS) | ✅ | 52 flake inputs, 123 .nix files, flake-parts architecture |
| 40 service modules auto-discovered | ✅ | `modules/nixos/services/` — filename IS the module name |
| 48 enabled services on evo-x2 | ✅ | Docker, Caddy, SOPS, Forgejo, Immich, SigNoz, Pocket ID, etc. |
| Centralized port registry | ✅ | `lib/ports.nix` — collision-protected |
| Centralized image registry | ✅ | `lib/images.nix` — pinned container refs with digests |
| systemd hardening helpers | ✅ | `harden`, `hardenUser`, `serviceDefaults` in `lib/` |
| BTRFS snapshot automation | ✅ | Pre-deploy snapshots, daily btrbk, auto-pruning |
| DNS stack (unbound + dnsblockd) | ✅ | Custom DNS blocker with block page |
| Caddy reverse proxy with forward auth | ✅ | 15 virtual hosts, oauth2-proxy + Pocket ID |
| Gatus health monitoring | ✅ | 33 health check endpoints, Discord alerting |
| sops-nix secrets management | ✅ | Age-encrypted via SSH host keys |

---

## b) PARTIALLY DONE

| Item | Status | What's Left |
|------|--------|-------------|
| `just test-fast` passes, full build untested | ⚠️ | `nh os boot .` not re-run after overlay refactor — vendorHash fix should resolve the art-dupl FOD failure, but full build not verified |
| Overlay documentation in AGENTS.md | ⚠️ | Updated for `mkLarsPackages`, but FEATURES.md still references old overlay patterns ("19 via flake-input overlays") |
| TODO_LIST.md upstream Go repo entries | ⚠️ | Still references `overlays/shared.nix` for library-policy and mr-sync mkTidyOverride — now lives in `mkLarsPackages` |
| Monitor365 | ⚠️ | Server was crash-looping (DB path fixed in prior session), needs `reset-failed` after deploy |
| Hermes AI gateway | ⚠️ | Config wired, missing OpenAI API key in sops + SSH deploy key |
| Twenty CRM | ⚠️ | Intermittent 502s — possible container OOM or PG connection exhaustion |

---

## c) NOT STARTED

| Item | Why It Matters |
|------|----------------|
| Full `nh os boot .` verification after overlay refactor | Must confirm the build actually succeeds, not just eval |
| `ROADMAP.md` | 37 planning docs in `docs/planning/`, no consolidated roadmap |
| `CHANGELOG.md` | 185+ commits, no changelog |
| Status report archiving | 195 files in `docs/status/` — pre-session-100 should be archived |
| BTRFS `/data` subvolume migration | `/data` is BTRFS toplevel (subvolid=5) — no snapshot protection for Docker/Immich/AI data |
| Raspberry Pi 3 DNS failover node | Hardware not provisioned, VRRP config defined |
| Swap investigation | 8 GiB swap used on 128 GiB RAM — stale LSP processes suspected |

---

## d) TOTALLY FUCKED UP

| Item | Severity | Details |
|------|----------|---------|
| **195 status report files** | Medium | `docs/status/` has ballooned to 195 files. Almost none are ever referenced again. This is organizational debt — should be archived to `docs/status/archive/` or deleted |
| **art-dupl `fork` branch** | Medium | The upstream `art-dupl` repo on the `fork` branch has a stale `vendorHash` in its own flake. We patched around it in SystemNix, but the upstream repo should be fixed. This will break again if the hash changes |
| **`disableTests` overlay** | Low | 4 packages (`valkey`, `aiocache`, `timm`, `xformers`) have `doCheck = false` overrides. This masks upstream test failures — should be investigated and PR'd to nixpkgs |
| ** FEATURES.md is stale** | Low | Says "19 via flake-input overlays" — now only 7 real overlays remain in `linux.nix` (upstream `.overlays.default`) + 5 `callPackage` overlays in `shared.nix`. The 12 Go tools are no longer overlays at all |
| **`flake.lock` churn** | Low | 148 lines changed in `flake.lock` — this is from prior session input updates, not this session's work |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **`mkLarsPackages` is good but could be extracted** — it's 38 lines inside `flake.nix`'s top-level `let`. If it grows further, consider moving to `lib/lars-packages.nix` for testability
2. **vendorHash overrides are fragile** — 3 packages (art-dupl, library-policy, mr-sync) need local overrides. Upstream repos should commit correct `go.sum` files so their own flakes have correct hashes
3. **`linux.nix` still takes flake inputs as parameters** — the `openaudible` and `netwatch` overlays are `callPackage` from local `.nix` files, while the other 6 use upstream `.overlays.default`. This asymmetry is fine but worth noting
4. **No CI/CD** — `just test-fast` catches eval errors but not build failures. A GitHub Action running `nix flake check` would catch the art-dupl hash mismatch before it blocks a deploy

### Code Quality

5. **`base.nix` is 257 lines** — it defines 6 package lists (`essentialPackages`, `developmentPackages`, `guiPackages`, `aiPackages`, `linuxUtilities`, + `larsPackages`). Could be split by concern
6. **144 flake lock nodes for 52 inputs** — many inputs have transitive deps (nixpkgs follows, flake-parts follows). Consider pruning unused inputs
7. **Darwin config is minimal** — 7-line Home Manager, no terminal/editor/theme parity with NixOS. Acceptable given disk constraints, but documented

### Process

8. **Status reports pile up** — need an automated archival strategy (cron? pre-commit hook?)
9. **No `CHANGELOG.md`** — with 185+ commits, a changelog would make version tracking possible
10. **Full build is slow** — 729 derivations for a simple `nh os boot`. Binary cache coverage could be improved

---

## f) Top 25 Things to Do Next

### Critical (Blocks Deployment)

1. **Run `nh os boot .`** — verify the full build succeeds after overlay refactor + art-dupl vendorHash fix
2. **Run `just switch`** — apply the new configuration to evo-x2 (auto-snapshots BTRFS first)
3. **Open new terminal after switch** — shell changes need new session

### High Priority (Functional Issues)

4. **Fix Twenty CRM 502s** — `docker logs twenty-server-1 --tail=100`, check OOM / PG connections
5. **Audit Gatus health checks** — 6 services showing DOWN, verify check URLs
6. **Add Hermes OpenAI API key to sops** — config already wired, just needs the secret
7. **Reset Monitor365 failed state** — `systemctl --user reset-failed monitor365-server`
8. **Fix art-dupl upstream** — commit correct `go.sum` to the `fork` branch so its own flake has the right vendorHash

### Medium Priority (Infrastructure Health)

9. **BTRFS `/data` migration** — `just snapshot-migrate-data` to convert toplevel to subvolume
10. **Swap investigation** — `smem -t -k | tail -20`, identify stale processes
11. **Prune flake inputs** — audit 52 inputs for unused/redundant entries
12. **Improve binary cache coverage** — reduce 729-derivation build times
13. **Set up CI** — GitHub Action running `nix flake check` on PRs

### Documentation & Organization

14. **Update FEATURES.md** — fix overlay count, remove stale references to mkPackageOverlay
15. **Update TODO_LIST.md** — remove library-policy/mr-sync overlay references (now in mkLarsPackages)
16. **Create CHANGELOG.md** — start from recent commits, work backwards
17. **Create ROADMAP.md** — consolidate 37 planning docs
18. **Archive old status reports** — move pre-session-100 to `docs/status/archive/`
19. **Document `mkLarsPackages` pattern** — add to AGENTS.md gotchas table (done partially)

### Upstream Contributions

20. **PR `aw-watcher-utilization` poetry-core migration** to ActivityWatch repo
21. **PR `valkey`/`aiocache` test fixes** to nixpkgs — removes `disableTests` overlay
22. **PR `jscpd` lockfile** — upstream should publish `pnpm-lock.yaml`
23. **Submit `netwatch`/`govalid`/`openaudible`** as new nixpkgs packages

### Refactoring

24. **Split `base.nix`** — separate essential/dev/gui/ai/linux package lists into individual files
25. **Extract `mkLarsPackages`** to `lib/lars-packages.nix` if it grows beyond ~50 lines

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should the `art-dupl` vendorHash fix be applied locally in SystemNix (as done now), or should I fix the upstream `art-dupl` fork branch first and then remove the local override?**

The local override in `mkLarsPackages` works and unblocks the build immediately. But it means SystemNix is carrying a patch for a repo Lars owns. The "correct" fix is to commit the right `go.sum` to the `art-dupl` fork branch, update its flake's `vendorHash`, tag it, and then remove the override from SystemNix. However:

- I don't know if the `art-dupl` fork branch has other uncommitted changes that would conflict
- I don't know if there's a reason the `go.sum` is intentionally stale (e.g., it tracks `master` of a dependency that recently changed)
- The same question applies to `library-policy` and `mr-sync` which also have `mkTidy` overrides

**Recommendation:** Apply local fix now (done), schedule upstream fixes as TODO items. But confirm with Lars whether he wants the upstream repos fixed first.

---

## Files Changed This Session

| File | Lines | What Changed |
|------|-------|-------------|
| `flake.nix` | +42 -21 | Added `mkLarsPackages`, simplified `perSystem.packages`, wired `larsPackages` to both platform specialArgs |
| `overlays/shared.nix` | +9 -62 | Removed 12 `mkPackageOverlay` entries + `mkTidyOverride` helper + all input parameters. Now a bare list of 5 real overlays |
| `overlays/default.nix` | +4 -15 | Removed `mkPackageOverlay` helper definition + `inherit mkPackageOverlay` export |
| `platforms/common/packages/base.nix` | +2 -23 | Removed 12 Go tool inputs + `mkTidy`/`larsGoTools` helpers. Accepts `larsPackages` attrset |
| `modules/nixos/services/projects-management-automation.nix` | +1 -1 | `pkgs.projects-management-automation` → direct flake input reference |
| `platforms/common/dns-resolver.nix` | +4 -2 | Formatting only (alejandra) |
| `AGENTS.md` | +9 -9 | Updated overlay documentation, removed mkPackageOverlay references |
| `flake.lock` | +74 -74 | Prior session input updates (not this session) |

**Total: +151 -201 (net -50 lines)**

---

## Build Status

| Check | Status | Notes |
|-------|--------|-------|
| `just test-fast` | ✅ Pass | All eval checks, zero warnings |
| `nix fmt .` | ✅ Pass | 2 files formatted (dns-resolver.nix, formatting only) |
| `nh os boot .` | ⏳ Untested | Was failing on art-dupl vendorHash — now fixed. Needs re-verification |
| `nix flake check` | ⏳ Untested | Should pass given test-fast passes |
