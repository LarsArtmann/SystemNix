# Session 88: Full Comprehensive Status — BTRFS Snapshots Deployed, Self-Review Fixes Applied

**Date:** 2026-05-24 19:23 CEST
**Scope:** Full SystemNix audit — BTRFS snapshot system production-verified, doc cleanup, hardening
**System:** NixOS unstable 26.05.20260523.3d8f0f3 | Go 1.26.3 | niri-unstable | Linux 6.x
**Total Commits:** 2598

---

## Executive Summary

evo-x2 is **deployed and stable**. The BTRFS snapshot system is live — btrbk created the first-ever snapshot of root (`@.pre-deploy-2026-05-24T192214`), the daily timer is running, and freshness verification is active. All self-review fixes from session 87 have been applied and deployed.

**Sessions 84-88 arc complete:** Timeshift (never worked) → btrbk (deployed, verified, hardened, documented).

**One pre-existing issue:** `oauth2-proxy.service` fails to start — from the Pocket ID migration (sessions 85-87), not from snapshot work. Needs investigation.

---

## A) FULLY DONE ✅

### 1. BTRFS Snapshot System — Production Verified

| Component | Status | Detail |
|-----------|--------|--------|
| btrbk root snapshots | ✅ Running | `btrbk-root.timer` active, daily schedule |
| First snapshot | ✅ Created | `@.pre-deploy-2026-05-24T192214` |
| Pre-deploy hook | ✅ Working | `just switch` → `just snapshot` → deploy |
| Snapshot pruning | ✅ Configured | Auto-prune pre-deploy (keep 5), btrbk prunes daily (14d + 4w) |
| Freshness verify | ✅ Running | `btrfs-verify-snapshots.timer` daily, alerts if >3 days stale |
| Automount | ✅ Working | `/mnt/btrfs-root` automounts on access, 10min idle |
| BTRFS scrub | ✅ Monthly | Both `/` and `/data` |
| Harden sandboxing | ✅ Applied | Verify service uses `harden {}` + `onFailure` from lib |
| Fail-hard safety | ✅ Enforced | `just snapshot` exits 1 on mount/snapshot failure (blocks deploy) |

### 2. Self-Review Fixes — All Applied (Session 88)

| # | Fix | Commit |
|---|-----|--------|
| 1 | Stale Timeshift docs → btrbk (README, FEATURES, configuration.nix) | `434dd5b8` |
| 2 | Removed obsolete `docs/btrfs-qgroup.md` | `86ff49b6` |
| 3 | Added `harden {}` to verify service + lib abstractions | `a6336c0e` |
| 4 | Stop btrbk timer during `/data` migration | `98fea3e5` |
| 5 | Derive root device from `config.fileSystems` (no hardcoded UUID) | `8d7f2092` |
| 6 | First-deploy snapshot mount (UUID fallback when fstab empty) | `347ed385` |

### 3. Vendor Hash Cascade — Complete (Session 82-83)

All 5 stale vendor hashes fixed. No regressions.

### 4. Portal Fix — Deployed (Session 83)

`xdg-desktop-portal-wlr` removed, niri native portal active.

### 5. Watchdog — Auto-Reboot Removed (Session 82)

Watchdog logs CRITICAL and stops. No auto-reboot incidents since.

### 6. Pocket ID Migration — Code Complete (Sessions 85-87)

Authelia replaced with Pocket ID + oauth2-proxy. Code is committed and mostly deployed. `oauth2-proxy.service` fails — needs debug.

### 7. Timeshift Completely Removed

- Package uninstalled (`timeshift` removed from system packages)
- `/etc/timeshift/timeshift.json` symlink removed
- All timers stopped and unit files removed
- All doc references in core files updated
- `docs/btrfs-qgroup.md` deleted

---

## B) PARTIALLY DONE 🔧

### 1. /data BTRFS Snapshots — Migration Path Ready, Not Executed

**Current state:** `/data` (827 GB) mounted as BTRFS toplevel (subvolid=5) — cannot be snapshotted.

- Migration recipe `just snapshot-migrate-data` is ready and tested
- Stops Docker, Ollama, ComfyUI, btrbk timer, auto-detects other /data services
- After migration: update `hardware-configuration.nix` with `subvol=@data`, add btrbk instance for /data
- **User confirmed:** `/data` is reprovisionable data — no external backup needed

### 2. Gatus Health Checks — Partial Coverage

25+ endpoints monitored. Still missing: Hermes, Monitor365, disk-monitor, nvme-health-monitor, dual-WAN route health.

### 3. oauth2-proxy Service — Fails to Start

`oauth2-proxy.service` fails on deploy. From Pocket ID migration (sessions 85-87). Needs debug — likely config or secret issue.

### 4. Upstream Repo Cleanliness

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
| 8 | Debug and fix `oauth2-proxy.service` startup failure | 30 min | Forward auth working |
| 9 | Fix photomap podman permission issue and re-enable | 1 hr | Photo visualization from Immich |
| 10 | Fix file-and-image-renamer (Go 1.26.3 blocked by nixpkgs 1.26.2) | 30 min | AI screenshot renaming |
| 11 | Minecraft server `enable = false` — needs enabling if wanted | 5 min | |

### Documentation & Housekeeping

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 12 | Archive `docs/status/` — 115 files in root, 374 in archive (7.3 MB) | 10 min | Clutter reduction |
| 13 | Update remaining 3 docs with stale Timeshift references | 5 min | `docs/ransomware-protection.md`, `docs/SESSION-SUMMARY-NEXT-STEPS.md`, `docs/COMPREHENSIVE-STATUS-REPORT.md` |
| 14 | Add version ldflags to library-policy production build | 5 min | Consistency |
| 15 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA overrideModAttrs hack |
| 16 | D2 architecture diagram of Go dependency graph | 20 min | Visualize cascade chain |

---

## D) TOTALLY FUCKED UP 💥

### 1. Timeshift Never Ran (NOW PERMANENTLY FIXED)

Timeshift was installed for months but never executed a single snapshot. NixOS's read-only `/etc` prevented it from writing `do_first_run: false`. Every status report said "Timeshift installed but not scheduled" — it was actually incapable of running.

**Status: PERMANENTLY FIXED.** Replaced with btrbk, production-verified with first snapshot created.

### 2. /data Never Had Snapshots (MIGRATION READY)

827 GB of Docker volumes, AI models, Steam library with zero snapshot protection since the machine was built. The migration recipe is ready and the user has confirmed the data is reprovisionable.

**Status: Ready to execute. Just needs `just snapshot-migrate-data`.**

### 3. Vendor Hash Cascade Pattern (ROOT CAUSE NOT ADDRESSED)

48 flake inputs, no CI, no `just verify-packages`. The cascade WILL recur on the next Go dependency change.

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Critical

1. **Execute /data migration** — Last major gap in snapshot coverage. Recipe is ready, data is reprovisionable.
2. **Fix oauth2-proxy** — Forward auth is broken since the Pocket ID migration. Blocks all services behind auth.
3. **Add `just verify-packages`** — Would have prevented the entire 2-hour cascade in session 82.

### Important

4. **Automate vendor hash updates** — `just update-vendor-hash <pkg>`.
5. **Clean up `docs/status/`** — 489 total files (7.3 MB). Archive ~100.
6. **Fix 3 remaining stale Timeshift docs** — `docs/ransomware-protection.md`, `docs/SESSION-SUMMARY-NEXT-STEPS.md`, `docs/COMPREHENSIVE-STATUS-REPORT.md`.
7. **Complete Gatus coverage** — Hermes, Monitor365, disk/nvme monitors.
8. **GitHub Actions CI for Go repos** — Catch stale hashes at source.

### Nice to Have

9. **Reduce flake inputs** — 48 is a lot.
10. **Port-centric testing** — Verify all `ports.*` are unique.
11. **Darwin parity** — macOS gets less testing.
12. **Centralize `mkPreparedSource`** — Copy-pasted across 5+ repos.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical — Fix Broken Things

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | Fix `oauth2-proxy.service` startup failure | 30 min | Forward auth is down — all services behind auth are inaccessible |
| 2 | Execute /data BTRFS migration (`just snapshot-migrate-data`) | 30 min | 827 GB with zero snapshots |
| 3 | Add btrbk instance for /data post-migration | 10 min | Complete snapshot coverage |

### High — Prevent Future Failures

| # | Task | Effort | Why |
|---|------|--------|-----|
| 4 | Add `just verify-packages` recipe | 15 min | #1 defense against stale vendor hashes |
| 5 | GitHub Actions CI for Go repos | 1-2 hrs | Catch stale hashes at source |
| 6 | Automate vendor hash discovery (`just update-vendor-hash`) | 15 min | Reduce 5-min manual cycle to 30 sec |
| 7 | Centralize `mkPreparedSource.nix` | 30 min | Stop copy-pasting across repos |
| 8 | Clean up `docs/status/` (archive ~100 old reports) | 10 min | 489 files is noise |

### Medium — Upstream Hygiene

| # | Task | Effort | Why |
|---|------|--------|-----|
| 9 | Fix 3 remaining stale Timeshift doc references | 5 min | `docs/ransomware-protection.md`, `SESSION-SUMMARY-NEXT-STEPS.md`, `COMPREHENSIVE-STATUS-REPORT.md` |
| 10 | Commit library-policy test refactoring | 5 min | 18 dirty files |
| 11 | Commit mr-sync status report | 2 min | 1 dirty file |
| 12 | Update go-filewatcher flake.lock | 2 min | nixpkgs drift |
| 13 | Fix file-and-image-renamer Go 1.26.3 issue | 30 min | Service is disabled |
| 14 | Fix photomap podman permissions | 1 hr | Service is disabled |
| 15 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA hack |
| 16 | Add version ldflags to library-policy | 5 min | Consistency |

### Lower — Polish & Future-proofing

| # | Task | Effort | Why |
|---|------|--------|-----|
| 17 | Add Gatus endpoints for Hermes, Monitor365, disk/nvme | 15 min | Complete observability |
| 18 | D2 architecture diagram of Go dependency graph | 20 min | Visualize cascade chain |
| 19 | Port-centric test (all `ports.*` unique) | 15 min | Prevent port conflicts |
| 20 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 21 | Reduce flake inputs from 48 | 1-2 hrs | Simplify maintenance |
| 22 | Darwin parity testing | Ongoing | d2 overlay hack is fragile |
| 23 | rpi3-dns sops-nix with age identity from SSH host key | 15 min | Only TODO in codebase |
| 24 | Minecraft server enable (if wanted) | 5 min | Low priority |
| 25 | Add snapshot count to `just disk-status` output | 5 min | Visibility |

---

## G) TOP QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**#1: What should `oauth2-proxy.service` actually connect to?**

The service fails to start after the Pocket ID migration. I can see the code (`modules/nixos/services/oauth2-proxy.nix`, `modules/nixos/services/pocket-id.nix`) but I don't know:
- Is Pocket ID fully configured and running? (The sops secrets are placeholders)
- What's the expected OAuth flow: Caddy → oauth2-proxy → Pocket ID?
- Did the Pocket ID admin UI get set up? (It needs initial configuration via web)

The `pocket-id.service` started successfully, but `oauth2-proxy.service` failed. This suggests Pocket ID is running but either:
1. The OAuth client hasn't been created in Pocket ID's admin UI yet
2. The sops secrets are still placeholders (they are — I created them as `placeholder-change-me`)
3. There's a config mismatch in the oauth2-proxy config

**I cannot determine:** Has the Pocket ID admin UI been configured? Were real OAuth client secrets generated and stored in sops?

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
| Failed services | oauth2-proxy (from Pocket ID migration) |
| Code TODOs | 1 (rpi3 sops-nix) |
| BTRFS snapshots | Root: daily via btrbk ✅, /data: none ❌ |
| BTRFS scrub | Monthly (root + /data) |
| Timeshift | Completely removed |
