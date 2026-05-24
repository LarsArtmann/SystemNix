# Session 84: Full Comprehensive Status — BTRFS Snapshot Overhaul + Deploy Safety Net

**Date:** 2026-05-24 08:16 CEST
**Scope:** Full SystemNix audit — BTRFS snapshot fix, deploy safety, system health
**System:** NixOS unstable 26.05.20260523.3d8f0f3 | Go 1.26.3 | niri-unstable | Linux 6.x
**Total Commits:** 2582

---

## Executive Summary

evo-x2 is **stable and fully deployed**. The vendor hash cascade from session 82 remains fully resolved. Session 83's portal fix and watchdog reboot removal are deployed and working.

**This session's work:** Replaced the broken Timeshift snapshot system with btrbk — a proper BTRFS-native solution. Discovered that Timeshift's scheduled snapshots never actually ran because NixOS's read-only `/etc` prevented Timeshift from writing its `do_first_run: false` config. Also discovered that `/data` is mounted as BTRFS toplevel (subvolid=5) and **cannot be snapshotted at all** — a latent data safety issue. Provided a migration path.

**New deploy safety net:** `just switch` now auto-snapshots root before every deploy.

---

## A) FULLY DONE ✅

### 1. BTRFS Snapshot Overhaul — Complete

Replaced Timeshift with btrbk for root (`@`) subvolume:

| Aspect | Before (Timeshift) | After (btrbk) |
|--------|-------------------|---------------|
| Tool | Timeshift (GUI tool, `--scripted` hack) | btrbk (native BTRFS, NixOS module) |
| Config | `environment.etc` JSON — but NixOS makes `/etc` read-only | NixOS `services.btrbk` module — declarative |
| Schedule | `schedule_daily = false` — never ran | Daily via systemd timer |
| Pruning | Configured but never executed | 7d minimum, 14d + 4w policy |
| Pre-deploy | None | `just switch` auto-snapshots root |
| Freshness check | Custom `timeshift-verify` | Custom `btrfs-verify-snapshots` |

**Files changed:**
- `platforms/nixos/system/snapshots.nix` — complete rewrite (122 → 86 lines)
- `justfile` — added `snapshot`, `snapshot-list`, `snapshot-migrate-data`; `switch` now auto-snapshots
- `AGENTS.md` — added BTRFS Snapshots section, `/data` toplevel gotcha, rollback procedure

**Root cause analysis — why Timeshift never worked:**
1. NixOS makes `/etc` read-only via `environment.etc` — config is generated at build time
2. Timeshift writes to `/etc/timeshift/timeshift.json` at runtime to set `do_first_run: false`
3. On NixOS, this write silently fails → `do_first_run` stays `true` → Timeshift waits for interactive GUI setup → never runs scheduled snapshots
4. Additionally: Timeshift is a GUI-first tool; `--scripted` mode was a workaround, not a design choice

### 2. Vendor Hash Cascade — Complete (Session 82-83)

All 5 stale vendor hashes fixed, built, deployed, and pushed. No regressions.

### 3. Portal Fix — Deployed (Session 83)

`xdg-desktop-portal-wlr` removed, using niri native portal. Zero errors on `nh os switch`.

### 4. Watchdog — Auto-Reboot Removed (Session 82)

Both `systemctl reboot` calls removed. Watchdog logs CRITICAL and stops. No incidents since.

### 5. Dead Code Cleanup (Session 81-82)

All completed and pushed.

### 6. Pre-commit Hooks — 9 Active

| Hook | Tool | Status |
|------|------|--------|
| gitleaks | Secret detection | ✅ |
| trailing-whitespace | sed | ✅ |
| deadnix | Dead Nix code | ✅ |
| statix | Nix linter | ✅ |
| alejandra | Nix formatter | ✅ |
| nix-check | Flake validation | ✅ |
| flake-lock-validate | JSON + merge conflict check | ✅ |
| shellcheck | Shell script linting | ✅ |
| check-merge-conflicts | Merge markers | ✅ |

---

## B) PARTIALLY DONE 🔧

### 1. /data BTRFS Snapshots — Migration Path Provided

**Problem:** `/data` is mounted as BTRFS toplevel (subvolid=5, no `subvol=` in `hardware-configuration.nix`). `btrfs subvolume snapshot` **cannot snapshot the toplevel** — this is a fundamental BTRFS limitation.

**Current state:**
- Root (`@`) has btrbk daily snapshots ✅
- `/data` has NO snapshots ❌
- Migration recipe `just snapshot-migrate-data` is ready but not yet executed
- After migration: add second btrbk instance for `/data` in snapshots.nix

**What `just snapshot-migrate-data` does:**
1. Stops Docker and services using `/data`
2. Mounts toplevel at `/mnt/btrfs-data-migrate`
3. Creates `@data` subvolume
4. Moves all content into `@data`
5. Instructs user to update `hardware-configuration.nix` with `subvol=@data`

**Risk:** 827 GB of data on `/data` (Docker, AI models, Steam). Must verify backup before migrating.

### 2. Gatus Health Checks — Partial Coverage

Gatus monitors 25+ endpoints. Still missing: Hermes, Monitor365, disk-monitor, nvme-health-monitor, dual-WAN route health.

### 3. Upstream Repo Cleanliness

| Repo | Issue | Severity |
|------|-------|----------|
| library-policy | 18 dirty test files + 2 dirty source files | Medium |
| mr-sync | 1 dirty status report | Low |
| go-filewatcher | `flake.lock` nixpkgs drift | Low |
| file-and-image-renamer | `flake.lock` + `flake.nix` dirty, service DISABLED | Medium |

---

## C) NOT STARTED 📋

### Infrastructure

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Centralize `mkPreparedSource.nix` into shared flake input | 30 min | Stop copy-pasting across 5+ Go repos |
| 2 | Add `just verify-packages` recipe to build all Go packages after `flake.lock` updates | 15 min | **#1 defense** against stale vendor hashes |
| 3 | GitHub Actions CI for all Go repos | 1-2 hrs | Catch build breakage before SystemNix |
| 4 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 5 | `just update-vendor-hash` recipe (set `""`, build, extract `got:`) | 15 min | Automate tedious hash cycle |

### Services

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | Execute `just snapshot-migrate-data` — convert /data to @data subvolume | 30 min | Enable /data snapshots |
| 7 | Add btrbk instance for /data after migration | 10 min | Complete snapshot coverage |
| 8 | Fix photomap podman permission issue and re-enable | 1 hr | Photo visualization from Immich |
| 9 | Fix file-and-image-renamer (Go 1.26.3 blocked by nixpkgs 1.26.2) | 30 min | AI screenshot renaming |
| 10 | Minecraft server `enable = false` — needs enabling if wanted | 5 min | |

### Documentation & Housekeeping

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | Archive `docs/status/` — 115 files in root, 374 in archive (7.3 MB total) | 10 min | Clutter reduction |
| 12 | Add version ldflags to library-policy production build | 5 min | Consistency |
| 13 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA overrideModAttrs hack |
| 14 | Add `go-error-family` follows to branching-flow input | 2 min | Dependency dedup |
| 15 | D2 architecture diagram of Go dependency graph | 20 min | Visualize cascade chain |

---

## D) TOTALLY FUCKED UP 💥

### 1. Timeshift Never Actually Ran (NOW FIXED)

Timeshift was installed and "configured" but its scheduled snapshots **never executed once**. The `do_first_run: true` config meant it was waiting for GUI interactive setup that never happened because NixOS makes `/etc` read-only. Every status report since installation said "Timeshift installed but not scheduled" — it was actually worse than that: Timeshift was installed and **physically incapable of running** on NixOS.

**Status: PERMANENTLY FIXED.** Replaced with btrbk, which uses the NixOS module system (declarative config, no runtime writes).

### 2. /data Has NEVER Had Snapshots (PARTIALLY FIXED)

The entire `/data` filesystem (827 GB — Docker volumes, AI models, Steam library, all service data) has never had a single snapshot. It's mounted as BTRFS toplevel (subvolid=5) which is fundamentally unsnapshottable. This means:
- No rollback capability for Docker volumes
- No rollback for AI model changes
- No protection against accidental deletion
- A bad `just switch` could be recovered for root but NOT for /data

**Status: MIGRATION PATH PROVIDED.** `just snapshot-migrate-data` is ready. Requires manual execution and ~30 minutes of downtime. **This should be the next priority.**

### 3. The Vendor Hash Cascade Pattern (ROOT CAUSE NOT ADDRESSED)

48 flake inputs, no CI, no `just verify-packages`. The cascade WILL recur.

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Critical

1. **Execute /data migration** — 827 GB with zero snapshots is the single biggest risk to data safety. Run `just snapshot-migrate-data`, update hardware-configuration.nix, add btrbk for /data.
2. **Add `just verify-packages`** — Build all Go packages after `flake.lock` updates. Would have prevented the entire 2-hour cascade in session 82.
3. **GitHub Actions CI for Go repos** — Catch stale vendor hashes at the source.

### Important

4. **Automate vendor hash updates** — `just update-vendor-hash <pkg>` that sets `""`, builds, extracts hash.
5. **Clean up `docs/status/`** — 115 files in root + 374 in archive = 489 total (7.3 MB). Should archive ~100 of the root files.
6. **Stale SSH sessions** — 17 stale `pts` sessions from SSH connections.
7. **Complete Gatus coverage** — Add endpoints for Hermes, Monitor365, disk/nvme monitors.

### Nice to Have

8. **Reduce flake inputs** — 48 is a lot. Some could follow `nixpkgs` to reduce closure.
9. **Port-centric testing** — Verify all `ports.*` are unique (port 3001 conflicted in session 80).
10. **Darwin parity** — macOS config gets less testing. d2 overlay hack is fragile.
11. **Centralize `mkPreparedSource`** — Copy-pasted across 5+ Go repos.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical — Prevent Disaster

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | Execute /data BTRFS migration (`just snapshot-migrate-data`) | 30 min | **827 GB with zero snapshots** |
| 2 | Add btrbk instance for /data post-migration | 10 min | Complete snapshot coverage |
| 3 | Add `just verify-packages` recipe | 15 min | **#1 defense** against stale vendor hashes |
| 4 | GitHub Actions CI for Go repos | 1-2 hrs | Catch stale hashes at source |
| 5 | Automate vendor hash discovery (`just update-vendor-hash`) | 15 min | Reduce 5-min manual cycle to 30 sec |

### High — Stability & Safety

| # | Task | Effort | Why |
|---|------|--------|-----|
| 6 | Centralize `mkPreparedSource.nix` | 30 min | Stop copy-pasting across repos |
| 7 | Clean up `docs/status/` (archive ~100 old reports) | 10 min | 489 files is noise |
| 8 | Add Gatus endpoints for Hermes, Monitor365, disk/nvme monitors | 15 min | Complete observability |
| 9 | Clean up 17 stale SSH sessions | 5 min | Housekeeping |
| 10 | Add snapshot count to `just disk-status` | 5 min | Visibility |

### Medium — Upstream Hygiene

| # | Task | Effort | Why |
|---|------|--------|-----|
| 11 | Commit library-policy test refactoring | 5 min | 18 dirty files in active repo |
| 12 | Commit mr-sync status report | 2 min | 1 dirty file |
| 13 | Update go-filewatcher flake.lock | 2 min | nixpkgs drift |
| 14 | Fix file-and-image-renamer Go 1.26.3 issue | 30 min | Service is disabled |
| 15 | Fix photomap podman permissions | 1 hr | Service is disabled |
| 16 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA hack |
| 17 | Add version ldflags to library-policy | 5 min | Consistency |

### Lower — Polish & Future-proofing

| # | Task | Effort | Why |
|---|------|--------|-----|
| 18 | D2 architecture diagram of Go dependency graph | 20 min | Visualize cascade chain |
| 19 | Add `go-error-family` follows to branching-flow input | 2 min | Dependency dedup |
| 20 | Port-centric test (all `ports.*` unique) | 15 min | Prevent port conflicts |
| 21 | Reduce flake inputs from 48 | 1-2 hrs | Simplify maintenance |
| 22 | Darwin parity testing | Ongoing | d2 overlay hack is fragile |
| 23 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 24 | rpi3-dns sops-nix with age identity from SSH host key | 15 min | Only TODO in codebase |
| 25 | Minecraft server enable (if wanted) | 5 min | Low priority |

---

## G) TOP QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**#1: When should we execute `/data` migration?**

The migration requires:
- ~30 minutes of downtime (Docker stopped, all /data services offline)
- No external backup exists for the 827 GB on /data
- The migration itself is safe (just `mv` within same filesystem — instant, no copy) but has risk if interrupted (power loss during move)
- The disk is 81-88% full — BTRFS snapshots will consume additional space

**I cannot determine:** Does the user have an external backup of /data? If not, should we create one before migrating? The migration is just reorganizing subvolumes (instant BTRFS operations), but without any backup at all, any mistake is catastrophic. The root filesystem now has snapshots, but /data has never had a single one.

---

## System Configuration Summary

| Aspect | Value |
|--------|-------|
| Flake inputs | 48 |
| Go package overlays | 21 (15 shared + 6 Linux-only) |
| Service modules | 30 in `serviceModules` |
| Pre-commit hooks | 9 |
| Scripts | 23 |
| Status reports | 489 total (115 root + 374 archive, 7.3 MB) |
| Disabled services | photomap, file-and-image-renamer, minecraft |
| Code TODOs | 1 (rpi3 sops-nix) |
| BTRFS scrub | Monthly (root + /data) |
| BTRFS snapshots | Root only (daily via btrbk), /data: none |
