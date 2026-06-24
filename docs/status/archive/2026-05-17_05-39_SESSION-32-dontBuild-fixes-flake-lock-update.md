# Session 32 — `dontBuild` PreparedSrc Fix Across 6 Go Repos + Flake Lock Update

**Date:** 2026-05-17 05:39
**Session type:** Upstream build fix + flake lock update
**Trigger:** User pasted 13-error build failure from `just switch` on evo-x2

---

## Executive Summary

Fixed the NixOS build failure by committing uncommitted code fixes in `mr-sync`, adding `dontBuild = true` to `preparedSrc` derivations across **6 Go repos**, and updating all flake inputs. 5 of 6 repos are now fixed. The build still fails on `projects-management-automation` due to an **upstream blocker**: `project-discovery-sdk` imports a deleted subpackage (`go-composable-business-types/programminglanguage`).

**Build:** 🔴 `just test-fast` passes (syntax), `nix build` fails on PMA | **Deploy:** 🔴 10+ sessions undeployed, Caddy down

---

## A) FULLY DONE

### This Session — Upstream Repo Fixes (6 repos, 6 commits, all pushed)

| # | Repo | Commit | Change |
|---|------|--------|--------|
| 1 | **mr-sync** | `135299e` | Committed uncommitted code fixes (context propagation to FetchAll, diffContent refactor) + `dontBuild = true` in preparedSrc |
| 2 | **projects-management-automation** | `9894b10` | `dontBuild = true` in preparedSrc + flake.lock update (cmdguard, go-output, go-commit, go-composable-business-types bumped) |
| 3 | **go-structure-linter** | `f826589` | `dontBuild = true` in preparedSrc |
| 4 | **go-auto-upgrade** | `50b9cd2` | `dontBuild = true` in preparedSrc |
| 5 | **branching-flow** | `0cf97f2` | `dontBuild = true` in preparedSrc |
| 6 | **hierarchical-errors** | `78faf43` | `dontBuild = true` in preparedSrc |

### SystemNix — Flake Lock Update

Updated 6 inputs in `flake.lock` to point to the latest commits with fixes:
- `mr-sync`: `22b7793` → `135299e` (code fixes + dontBuild)
- `projects-management-automation`: `bb11c25` → `9894b10` (dontBuild + lock update)
- `go-structure-linter`: `2962a75` → `f826589` (dontBuild)
- `go-auto-upgrade`: unchanged (`50b9cd2` — already latest)
- `branching-flow`: `20192b4` → `0cf97f2` (dontBuild)
- `hierarchical-errors`: `424f413` → `78faf43` (dontBuild)

### Validation

- `just test-fast` passes clean (all Nix evaluation checks pass)
- All 6 upstream repos pushed to GitHub master

### Sessions 23–31 Cumulative — Still Done

All items from previous status reports remain done:
- Abstraction sprint complete (mkDockerService, mkHttpCheck, consecutive-failure lib.sh)
- Deduplication sprint (-290 net lines across 40 files)
- GPU OOM defense, DRM healthcheck, dual-WAN, DNS blocker
- EMEET PIXY webcam, centralized AI storage, wallpaper self-healing
- Taskwarrior sync, lib/ shared helpers, pre-commit hooks
- SigNoz observability pipeline, Gatus health checks, OpenSEO

---

## B) PARTIALLY DONE

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **Full build** | 5 of 6 Go repo overlays fixed, `just test-fast` passes | `projects-management-automation` blocked by upstream `project-discovery-sdk` importing deleted `programminglanguage` subpackage (105 references in 14 files) |
| 2 | **Deploy** | All local changes validated, flake lock updated | **10+ sessions of undeployed changes**. Caddy down since session 20 |
| 3 | **SigNoz alert rules** | `signoz-alerts.nix` defines rules with mkRule helper | Not loaded into SigNoz API |
| 4 | **TODO_LIST.md** | Exists | Stale since session 21 (May 11) |

---

## C) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | **Fix `project-discovery-sdk` broken import** | 🔴 BLOCKING | 105 refs to deleted `programminglanguage` subpackage across 14 files. Needs migration to go-enry or inline type. |
| 2 | **Full deploy** (`just switch`) | 🔴 CRITICAL | 10+ sessions undeployed. Caddy down. |
| 3 | **`nix-collect-garbage`** (~15G reclaim) | 🔴 CRITICAL | Disk at 91%, /nix/store at 88G |
| 4 | **Automated backups** | 🔴 CRITICAL | No scheduled backups for Immich, Gitea, Taskwarrior |
| 5 | **nix GC timer** (weekly) | 🟡 HIGH | Prevent disk exhaustion |
| 6 | **Caddy health check in Gatus** | 🟡 HIGH | Only checks /metrics, not proxy pipeline |
| 7 | **Fix Timeshift snapshots** | 🟡 HIGH | Both backup + verify services failed |
| 8 | **Caddy log rotation** | 🟡 HIGH | No logrotate configured |
| 9 | **Disk space alerting** (85%+) | 🟡 MEDIUM | No early warning |
| 10 | **TLS cert auto-renewal** | 🟡 MEDIUM | Static cert, no renewal |
| 11 | **CI/CD pipeline** | 🟡 MEDIUM | Gitea Actions runner not configured |
| 12 | **Deploy SigNoz alert rules** | 🟡 MEDIUM | Rules defined, not loaded |
| 13 | **Go-output bump automation** | 🟡 MEDIUM | Script to update all downstream repos |
| 14 | **Service self-registration** | 🟢 LOW | Deferred — architecture change |
| 15 | **Provision Pi 3** for DNS failover | 🟢 LOW | Module written, no hardware |
| 16 | **docs/ cleanup** (80+ files) | 🟢 LOW | Many stale reports |

---

## D) TOTALLY FUCKED UP

| # | Item | Severity | Details |
|---|------|----------|---------|
| 1 | **🔴 PMA BUILD BLOCKED** | CRITICAL | `project-discovery-sdk` imports `go-composable-business-types/programminglanguage` which was deleted in commit `c9bda50`. 105 references across 14 files need migration to `go-enry`. |
| 2 | **🔴 Caddy STILL DOWN** | CRITICAL | 10+ sessions undeployed. All `*.home.lan` services unreachable since ~session 20. |
| 3 | **🔴 Root disk 91%** | CRITICAL | /nix/store at 88G. Each failed build adds ~5G. No auto-GC. |
| 4 | **🔴 No backups** | CRITICAL | Zero automated backup for any service data. |
| 5 | **🔴 10+ sessions without deploy** | CRITICAL | ~20 commits of validated but undeployed changes. |
| 6 | **🟡 Upstream dep chain fragility** | HIGH | Same `go-output` → `go-branded-id` transitive dep pattern broke 4 repos again this session. `mr-sync` needed `cmdguard`/`go-output`/`go-branded-id` as local deps. |
| 7 | **🟡 `preparedSrc` dontBuild missing in 6 repos** | HIGH | Fixed this session, but the pattern of forgetting `dontBuild` in source-preparation derivations caused silent build failures. |

---

## E) WHAT WE SHOULD IMPROVE

### 1. Systemic: Private Go Dep Chain Fragility (recurs every session)

The `go-output` → `go-branded-id` transitive dep pattern broke 4 repos **again** this session. This is the 4th time this exact class of failure has occurred. Root cause: any private LarsArtmann Go repo that transitively depends on `go-output` breaks when `go-output` bumps.

**Status:** Documented in AGENTS.md but NOT fixed. Each time we play whack-a-mole across repos.

**Possible solutions:**
- **GOPROXY + vendoring**: Pre-vendor all deps before Nix builds
- **Monorepo**: Put all private Go packages in one repo (eliminates the problem)
- **CI build check**: Every Go repo CI runs `nix build` before merge

### 2. `preparedSrc` Pattern Should Be a Template

Every Go repo that has private deps duplicates the same `preparedSrc` boilerplate. Should extract into a shared Nix library function:
```nix
mkPreparedSrc = { src, privateDeps, replacements ? {} }:
```

### 3. Deploy Cadence

10+ sessions without a deploy is critical. The build keeps breaking on upstream issues, creating a chicken-and-egg problem where we can't deploy because the build fails, and the build keeps failing because upstream deps are fragile.

**Recommendation:** Consider temporarily disabling PMA overlay to unblock deploys of other critical fixes (Caddy, display watchdog, GC).

### 4. `dontBuild = true` Should Be Default for Source Prep

The Nix `stdenv.mkDerivation` defaults to running `make` in `buildPhase`. Source preparation derivations (that only copy files and patch go.mod) should always set `dontBuild = true`. 6 repos forgot this.

---

## F) Top 25 Things To Get Done Next

### P0 — BLOCKING (must fix before any deploy)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Fix `project-discovery-sdk`** — migrate 105 refs from `programminglanguage` to `go-enry` | Unblocks full build | 2–4h |
| 2 | **Update `projects-management-automation`** after PDS fix | Build passes | 5 min |
| 3 | **`just switch`** — deploy 10+ sessions of changes | Caddy restored, all fixes live | 10 min |
| 4 | **Verify critical services** after deploy (Caddy, niri, DNS, watchdog) | Confirm deployment | 2 min |

### P1 — CRITICAL (same day)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 5 | **`nix-collect-garbage --delete-older-than 3d`** | Reclaim ~15G (91% → ~80%) | 10 min |
| 6 | **Add nix GC timer** (weekly, 3d threshold) | Prevent disk exhaustion permanently | 30 min |
| 7 | **Set up backup automation** (Immich, Gitea, Taskwarrior) | Data loss prevention | 2h |

### P2 — HIGH (this week)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 8 | **Fix Caddy health check in Gatus** — test actual proxy pipeline | Prevents silent outages | 30 min |
| 9 | **Fix Timeshift snapshot service** | BTRFS backups running | 30 min |
| 10 | **Add disk space alert** (85%+ in Gatus/SigNoz) | Early warning | 30 min |
| 11 | **Add Caddy log rotation** | Prevent disk fill | 30 min |
| 12 | **Create `go-output` bump automation** | Eliminate whack-a-mole across repos | 2h |
| 13 | **Extract `mkPreparedSrc` shared Nix function** | DRY across 6 Go repos | 1h |

### P3 — MEDIUM (next 2 weeks)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 14 | **Deploy SigNoz alert rules** from signoz-alerts.nix | Active monitoring | 1h |
| 15 | **Add CI build check** to all upstream Go repos | Catch stale hashes before SystemNix | 2h/repo |
| 16 | **Refresh TODO_LIST.md** against codebase | Accurate planning | 1h |
| 17 | **Implement TLS cert auto-renewal** | Prevent cert expiry | 3h |
| 18 | **Clean up docs/ directory** — archive stale files | Reduce clutter (80+ files) | 1h |
| 19 | **Restructure AGENTS.md** — extract reference sections | Maintainability (927 lines) | 2h |
| 20 | **Add deploy verification** (`just switch` + health check) | Deploy confidence | 1h |

### P4 — BACKLOG

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 21 | **Service self-registration** (caddy + gatus auto-wiring) | New service = fewer steps | 3h |
| 22 | **Set up Gitea Actions CI** for SystemNix | Automated build testing | 3h |
| 23 | **Provision Pi 3** for DNS failover cluster | HA DNS | 4h |
| 24 | **Configure Twenty CRM** production setup | Business tool | 2h |
| 25 | **Evaluate Go monorepo** for all private LarsArtmann packages | Eliminate transitive dep fragility | 8h |

---

## G) Top #1 Question I Cannot Answer

**Should I temporarily disable the `projects-management-automation` overlay in SystemNix to unblock the deploy of all other fixes (Caddy, display watchdog, GC timer, disk space alert)?**

The PMA build is blocked by `project-discovery-sdk` which has 105 references to a deleted `programminglanguage` subpackage. Fixing PDS is a 2–4 hour task. Meanwhile, Caddy has been down for 10+ sessions and the disk is at 91%.

Options:
1. **Fix PDS first** (2–4h), then deploy everything at once — cleanest but delays critical fixes
2. **Disable PMA overlay temporarily** (`// lib.optionalAttrs false { projects-management-automation = ...; }`), deploy all other fixes NOW, re-enable after PDS fix — gets Caddy back online immediately but removes PMA from PATH temporarily
3. **Use `--option allow-broken true`** for just this build — hacky, not recommended

I recommend option 1 if you can wait, or option 2 if Caddy being down is causing immediate pain.

---

## Build Error Root Cause Analysis

### Error chain from `just switch` (13 errors, 1 root cause)

```
mr-sync-0.1.0-go-modules (buildPhase)
  → go mod vendor tries to fetch github.com/larsartmann/cmdguard v1.0.0
  → HTTPS fetch fails: "could not read Username for 'https://github.com': terminal prompts disabled"
  → mr-sync-0.1.0 FAILS
    → system-path FAILS
      → man-paths FAILS
      → system_fish-completions FAILS
      → etc FAILS
      → dbus-1 FAILS
      → unit-accounts-daemon.service FAILS
      → unit-script-mandb-start FAILS
      → X-Restart-Triggers-polkit FAILS
      → system-units FAILS
    → nixos-system-evo-x2 FAILS
```

### Why it happened

1. `mr-sync` added `cmdguard` as a dependency (new private dep)
2. The flake.lock pinned revision `22b7793` had a `preparedSrc` with `replace` directives, BUT:
   - The local repo had **uncommitted code fixes** (context propagation, diffContent refactor) that fixed compile errors
   - The `preparedSrc` was missing `dontBuild = true`
3. When `go mod vendor` ran, the `replace` directives in go.mod redirected to `_local_deps/cmdguard`, BUT the go.sum still referenced `v1.0.0` (old version before preparedSrc was fully baked)
4. The Nix sandbox has no SSH access, so `go mod vendor` couldn't fetch `cmdguard` via HTTPS

### Fix chain

1. Committed code fixes in `mr-sync` (context propagation, diffContent)
2. Added `dontBuild = true` to `preparedSrc` in `mr-sync`
3. Pushed `mr-sync` → `135299e`
4. Added `dontBuild = true` to 5 more repos (proactive fix)
5. Updated `flake.lock` in SystemNix

---

## Commits This Session

| Repo | Commit | Message |
|------|--------|---------|
| `mr-sync` | `135299e` | fix: wire context through call chain, add dontBuild to preparedSrc |
| `projects-management-automation` | `9894b10` | fix(nix): add dontBuild to preparedSrc, update flake.lock |
| `go-structure-linter` | `f826589` | fix(nix): add dontBuild to preparedSrc |
| `go-auto-upgrade` | `50b9cd2` | fix(nix): add dontBuild to preparedSrc |
| `branching-flow` | `0cf97f2` | fix(nix): add dontBuild to preparedSrc |
| `hierarchical-errors` | `78faf43` | fix(nix): add dontBuild to preparedSrc |
| `SystemNix` (pending) | — | flake.lock: update 6 LarsArtmann inputs to latest |

---

## System State Snapshot

| Metric | Value | Trend |
|--------|-------|-------|
| **Hostname** | evo-x2 | — |
| **Niri** | Running, display active | ✅ Stable |
| **Root disk** | **91%** (46G free) | 🔴 Same as session 30 |
| **/nix/store** | 88G | 🔴 Stable (no new builds) |
| **Data disk** | 80% (206G free) | ✅ Stable |
| **Memory** | 48G/62G (77%) | ✅ Better than session 30 (was 79%) |
| **Failed services** | Caddy, niri-health-metrics, service-health-check, timeshift-backup, timeshift-verify | 🔴 Same as session 30 |
| **Undeployed commits** | ~20 (sessions 23–32) | 🔴 Growing |
| **AGENTS.md** | 927 lines | ⚠️ Growing |

## Codebase Stats

| Metric | Count |
|--------|-------|
| Total .nix files | 110 |
| Total .sh files | 22 |
| NixOS service modules | ~40 |
| Docker-based services | 5 (manifest, openseo, photomap, twenty, voice-agents) |
| Common program modules | 15 |
| Scripts | 17 |
| lib/ helpers | 6 |
| Flake inputs | 39 |
| Shared overlays (mkPackageOverlay) | 11 |
| Linux-only overlays | 6 |
| Gatus endpoints | 26+ |
