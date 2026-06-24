# Session 83: Full Comprehensive Status — Post-Vendor-Hash Cascade + Portal Fix Deployed

**Date:** 2026-05-24 05:32 CEST
**Scope:** Full SystemNix audit — NixOS evo-x2 + macOS Lars-MacBook-Air + 15 upstream repos
**System:** NixOS unstable 26.05.20260523.3d8f0f3 | Go 1.26.3 | niri-unstable | Linux 6.x

---

## Executive Summary

evo-x2 is **fully deployed and stable**. The vendor hash cascade from session 82 is completely resolved — all 10 Go packages build, `nh os switch` completes cleanly with zero errors, and the portal-wlr crash is gone. The watchdog no longer auto-reboots. All SystemNix commits are pushed.

**One concern:** The user had to hard-crash the PC earlier this session (watchdog auto-reboot). That's now permanently fixed — watchdog logs CRITICAL and stops.

---

## A) FULLY DONE ✅

### 1. Vendor Hash Cascade — Complete (Session 82)

All 5 stale vendor hashes fixed, built, deployed, and pushed:

| Package | Status | Pushed |
|---------|--------|--------|
| buildflow | ✅ `sha256-Jsi00lEl...` | ✅ Upstream + overlay |
| mr-sync | ✅ `sha256-T2IVldw0...` | ✅ Overlay |
| go-structure-linter | ✅ `sha256-nfbz9ZOv...` | ✅ Overlay |
| branching-flow | ✅ `sha256-ORJwNCRS...` | ✅ Upstream + overlay |
| golangci-lint-auto-configure | ✅ `sha256-VeOlYERM...` | ✅ Upstream + overlay |

### 2. go-filewatcher Module Path Fix (Root Cause)

- ✅ Removed `/v2` from module path (was declaring `/v2` but publishing `v0.x.x` tags)
- ✅ All Go imports updated across go-filewatcher
- ✅ PMA updated to consume fixed version
- ✅ Pushed as `f086f14`

### 3. Portal Fix — Deployed

- ✅ `xdg-desktop-portal-wlr` removed from config (crashed because niri lacks `wlr_screencopy`/`ext_image_copy_capture`)
- ✅ Now uses `["niri" "gtk"]` — niri has built-in portal support
- ✅ `nh os switch` completed with **zero errors** (no more exit code 4)
- ✅ Committed as `21ac978f`, pushed to origin

### 4. Watchdog — Auto-Reboot Removed

- ✅ Both `systemctl reboot` calls removed from `scripts/display-watchdog.sh`
- ✅ Now logs `CRITICAL: ... Manual intervention required.` and stops
- ✅ Recovery ladder still works: niri restart → display-manager restart → log critical

### 5. Dead Code Cleanup (Session 81-82)

- ✅ `GOFLAGS = "-mod=mod"` removed from PMA and branching-flow (Go doesn't allow it with `-mod=vendor`)
- ✅ `go_1_26` → `go` standardized in go-structure-linter and branching-flow
- ✅ library-policy `buildTags` → `GOEXPERIMENT` fix committed upstream

### 6. SystemNix — Fully Pushed

- ✅ All 6 commits since session 81 pushed to `origin/master`
- ✅ Working tree is clean
- ✅ 2581 total commits in repo

---

## B) PARTIALLY DONE 🔧

### 1. Upstream Repo Cleanliness

| Repo | Issue | Severity |
|------|-------|----------|
| library-policy | 18 dirty test files + 2 dirty source files (test refactoring) | Medium — uncommitted work |
| mr-sync | 1 dirty status report | Low — housekeeping |
| go-filewatcher | `flake.lock` nixpkgs drift | Low — non-functional |
| file-and-image-renamer | `flake.lock` + `flake.nix` dirty, deleted `jscpd-report.json` | Medium — service is DISABLED anyway |
| go-structure-linter | `internal/rules/.gitignore` | Low — unrelated |

### 2. Gatus Health Checks — Partial Coverage

Gatus monitors 25+ endpoints including: Caddy, Forgejo, Immich, SigNoz, Homepage, TaskChampion, Twenty, Manifest, Ollama, DNS blocker, Whisper, LiveKit, OpenSEO, emeet-pixyd, Authelia, node exporter, cadvisor.
**Missing from monitoring:** Hermes, Monitor365, disk-monitor, nvme-health-monitor, dual-WAN route health.

### 3. BTRFS Snapshots

Timeshift is installed but `schedule_daily` is `false` — no automated snapshots running.

---

## C) NOT STARTED 📋

### Infrastructure

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Centralize `mkPreparedSource.nix` into shared flake input | 30 min | Stop copy-pasting across 5+ Go repos |
| 2 | Add `just verify-packages` recipe to build all Go packages after `flake.lock` updates | 15 min | Prevent cascading vendor hash failures |
| 3 | GitHub Actions CI for all Go repos | 1-2 hrs | Catch build breakage before it hits SystemNix |
| 4 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 5 | `just update-vendor-hash` recipe (set `""`, build, extract `got:`) | 15 min | Automate the tedious hash cycle |

### Services

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | Fix photomap podman permission issue and re-enable | 1 hr | Photo visualization from Immich |
| 7 | Fix file-and-image-renamer (Go 1.26.3 dep blocked by nixpkgs Go 1.26.2) | 30 min | AI screenshot renaming |
| 8 | Minecraft server currently `enable = false` | 5 min | Just needs enabling if wanted |

### Documentation & Housekeeping

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9 | Archive `docs/status/` — 114 files + 374 in archive (7.2 MB total) | 10 min | Housekeeping |
| 10 | Add version ldflags to library-policy production build | 5 min | Consistency with other repos |
| 11 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA overrideModAttrs hack |
| 12 | Add `go-error-family` follows to branching-flow input | 2 min | Dependency dedup |
| 13 | D2 architecture diagram of Go dependency graph | 20 min | Visualize the cascade chain |

---

## D) TOTALLY FUCKED UP 💥

### 1. Session 82 Hard Crash (FIXED)

The watchdog auto-rebooted the workstation **without user consent**. This is the worst possible behavior on a personal dev machine — killing unsaved work, terminal sessions, running builds. Root cause: `display-watchdog.sh` had `systemctl reboot` in two places.

**Status: PERMANENTLY FIXED.** Both reboot calls replaced with CRITICAL log messages. The watchdog will NEVER auto-reboot again.

### 2. The Vendor Hash Cascade Pattern (ROOT CAUSE NOT ADDRESSED)

Session 82 had 5 sequential vendor hash failures discovered one-at-a-time because `just test-fast` only validates syntax, not builds. Each failure required: set hash to `""` → build → extract `got:` → set correct hash → rebuild → discover NEXT failure.

**The underlying problem:** No CI or pre-merge check verifies Go package builds after `flake.lock` updates. A single `nix build .#<pkg>` for each of the 10 Go packages would catch all stale hashes in ~5 minutes.

**Status: NOT FIXED.** Will recur every time Go dependencies change until `just verify-packages` or equivalent is added.

### 3. flake.lock Time Bomb

48 flake inputs means a bulk `nix flake update` touches everything simultaneously. When Go repos update their dependencies, the vendor hashes in SystemNix overlays become stale. There's no automated mechanism to detect this before deployment.

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Critical

1. **Add `just verify-packages`** — Build all Go packages in CI/locally after any `flake.lock` change. This single change would have prevented the entire 2-hour cascade.
2. **Add GitHub Actions CI to Go repos** — Each repo should verify its own vendorHash on push. Catch stale hashes at the source, not in SystemNix.
3. **Centralize `mkPreparedSource`** — Currently copy-pasted across 5+ Go repos. A shared flake input would ensure bug fixes propagate everywhere.

### Important

4. **Automate vendor hash updates** — `just update-vendor-hash <pkg>` that sets `""`, builds, extracts hash, and updates overlay. Reduce 5-minute manual cycle to 30 seconds.
5. **Clean up `docs/status/`** — 114 files in root + 374 in archive = 488 total status reports. Should be 90% archived.
6. **Stale SSH sessions** — 17 stale `pts` sessions from SSH connections. Harmless but messy. `loginctl terminate-session` or reboot cleans them.
7. **BTRFS snapshot scheduling** — Timeshift installed but no automatic snapshots. One bad `nh os switch` could be unrecoverable.

### Nice to Have

8. **Reduce flake inputs** — 48 is a lot. Some could follow `nixpkgs` to reduce closure size.
9. **Port-centric testing** — Verify all `ports.*` are unique and not conflicting (port 3001 was conflicting between monitor365 and openseo in session 80).
10. **Darwin parity** — macOS config works but gets less testing. d2 overlay hack is fragile.

---

## F) TOP 25 THINGS TO DO NEXT

### Critical — Prevent Another Cascade

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | Add `just verify-packages` recipe | 15 min | **#1 defense** against stale vendor hashes |
| 2 | Add GitHub Actions CI to Go repos | 1-2 hrs | Catch stale hashes at source |
| 3 | Automate vendor hash discovery (`just update-vendor-hash`) | 15 min | Reduce 5-min manual cycle to 30 sec |

### High — Stability & Safety

| # | Task | Effort | Why |
|---|------|--------|-----|
| 4 | Enable BTRFS snapshot scheduling | 5 min | Rollback safety net for bad deploys |
| 5 | Centralize `mkPreparedSource.nix` | 30 min | Stop copy-pasting across repos |
| 6 | Clean up `docs/status/` (archive old reports) | 10 min | 488 files is noise |
| 7 | Add Gatus endpoints for Hermes, Monitor365, disk/nvme monitors | 15 min | Complete observability coverage |
| 8 | Clean up 17 stale SSH sessions | 5 min | Housekeeping |

### Medium — Upstream Hygiene

| # | Task | Effort | Why |
|---|------|--------|-----|
| 9 | Commit library-policy test refactoring | 5 min | 18 dirty files in active repo |
| 10 | Commit mr-sync status report | 2 min | 1 dirty file |
| 11 | Update go-filewatcher flake.lock | 2 min | nixpkgs drift |
| 12 | Fix file-and-image-renamer Go 1.26.3 issue | 30 min | Service is disabled |
| 13 | Fix photomap podman permissions | 1 hr | Service is disabled |
| 14 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA hack |
| 15 | Add version ldflags to library-policy | 5 min | Consistency |

### Lower — Polish & Future-proofing

| # | Task | Effort | Why |
|---|------|--------|-----|
| 16 | Run `just test` (full build) on SystemNix | 20 min | More thorough than test-fast |
| 17 | Create D2 architecture diagram of Go dep graph | 20 min | Visualize cascade chain |
| 18 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 19 | Audit all scripts for any remaining reboot/shutdown calls | 10 min | Paranoid check |
| 20 | Add `go-error-family` follows to branching-flow | 2 min | Dependency dedup |
| 21 | Reduce flake input count where possible | 30 min | Faster eval |
| 22 | Add `just smoke-test` to verify all binaries run | 10 min | Post-deploy validation |
| 23 | Update AGENTS.md with portal-niri pattern | 5 min | Documentation |
| 24 | Test Darwin config (`darwin-rebuild build`) | 10 min | Cross-platform parity |
| 25 | Investigate niri session manager stale session cleanup | 20 min | Prevent session accumulation |

---

## G) TOP #1 QUESTION 🤔

**Should we build all 10 Go packages as part of `just test` / `just test-fast`?**

Currently `just test-fast` runs `nix flake check --no-build` which only validates Nix evaluation — it does NOT catch vendor hash mismatches. The cascade in session 82 proved this is dangerous.

Options:
1. **Add `just verify-packages`** — explicit step, runs all Go builds (~5 min), user runs when needed
2. **Add to `just test`** — always builds all packages, but makes `just test` take 5+ minutes longer
3. **Pre-push hook** — automatic, but adds latency to every push
4. **GitHub Actions CI** — runs in background, catches issues after push (too late for the current session)

**My recommendation:** Option 1 (`just verify-packages`) as the immediate fix + Option 4 (CI) as the long-term fix. Option 2 makes the dev loop too slow.

---

## System State

### NixOS evo-x2
| Component | Status | Version/Detail |
|-----------|--------|----------------|
| OS | ✅ Deployed | NixOS 26.05.20260523.3d8f0f3 |
| Kernel | ✅ Running | 6.x (systemd-boot) |
| Go | ✅ 1.26.3 | Updated from 1.26.2 |
| Compositor | ✅ niri | Wayland scrollable-tiling |
| Portal | ✅ Fixed | `["niri" "gtk"]` — no more wlr crashes |
| Watchdog | ✅ Safe | No auto-reboot, CRITICAL log only |
| Firewall | ✅ Active | 22, 53, 80, 443 TCP + 53, 853 UDP |
| DNS | ✅ Running | Unbound + dnsblockd (53/853) |
| Caddy | ✅ Reverse proxy | 12 vhosts behind Authelia |
| GPU | ✅ AMD | Ryzen AI Max+ Strix Halo, ROCm, RADV |
| BTRFS | ⚠️ No auto-snapshots | Timeshift installed but not scheduled |
| Dual-WAN | ✅ Running | MPTCP + route health monitor |
| Smartd | ✅ Enabled | Auto-detect, daily/weekly checks |

### Services (34 modules in serviceModules)

| Service | Enabled | Notes |
|---------|---------|-------|
| Forgejo | ✅ | Port 3000, SOPS secrets, repo mirroring |
| Immich | ✅ | VA-API transcoding, machine-learning |
| Caddy | ✅ | 12 vhosts, Authelia forward-auth |
| Authelia | ✅ | Port 9091, SOPS-managed |
| SigNoz | ✅ | v0.117.1, ClickHouse + OTel (built from source) |
| Twenty CRM | ✅ | Port 3200, Docker Compose |
| Homepage | ✅ | Port 8082 |
| TaskChampion | ✅ | Port 10222 |
| Manifest | ✅ | Port 2099 |
| Gatus | ✅ | Port 9110, 25+ endpoints, Discord alerts |
| OpenSEO | ✅ | Port 3002 |
| Monitor365 | ✅ | Port 3001, server + agent |
| Hermes | ✅ | AI gateway, Discord/Telegram/Anthropic/Firecrawl/edge-tts/fal/exa |
| Voice Agents | ✅ | LiveKit + Whisper (ROCm Docker) |
| Ollama | ✅ | GPU fraction 0.45, max 1 loaded model |
| AI Models | ✅ | Centralized `/data/ai/` storage |
| Disk Monitor | ✅ | Desktop notifications at thresholds |
| NVMe Health | ✅ | SSD health monitoring |
| DNS Blocker | ✅ | dnsblockd, unbound, block page |
| Dual-WAN | ✅ | MPTCP ECMP + route health |
| Browser Policies | ✅ | Chromium managed policies |
| Steam | ✅ | Proton enabled |
| Display Manager | ✅ | SDDM + SilentSDDM theme |
| Niri | ✅ | Session manager + config |
| Audio | ✅ | PipeWire |
| Security Hardening | ✅ | Systemd sandboxing |
| SOPS | ✅ | Age-encrypted secrets |
| Forgejo Repos | ✅ | Auto-sync dnsblockd, BuildFlow |
| **Photomap** | ❌ | podman permission issue |
| **File Renamer** | ❌ | Go 1.26.3 dep vs nixpkgs 1.26.2 |
| **Minecraft** | ❌ | Explicitly disabled |

### Upstream Repos (15 total)

| Repo | Language | Branch | Dirty | Status |
|------|----------|--------|-------|--------|
| buildflow | Go | master | Clean | ✅ Pushed |
| go-filewatcher | Go | master | flake.lock | ✅ /v2 fix deployed |
| go-structure-linter | Go | master | .gitignore | ✅ |
| branching-flow | Go | master | Clean | ✅ vendorHash fixed |
| golangci-lint-auto-configure | Go | master | Clean | ✅ vendorHash fixed |
| projects-management-automation | Go | master | Clean | ✅ |
| library-policy | Go | master | 20 files | ⚠️ Test refactoring uncommitted |
| mr-sync | Go | master | 1 status doc | ✅ |
| go-auto-upgrade | Go | master | Clean | ✅ |
| art-dupl | Go | fork | Clean | ✅ |
| dnsblockd | Go | master | Clean | ✅ |
| file-and-image-renamer | Go | master | 3 files | ⚠️ Disabled in config |
| hierarchical-errors | Go | master | Clean | ✅ |
| monitor365 | Rust | master | Clean | ✅ |
| emeet-pixyd | Go | master | Clean | ✅ |

### macOS Lars-MacBook-Air (aarch64-darwin)
- ✅ nix-darwin + Home Manager
- ✅ Shared packages, fonts, themes with NixOS
- ⚠️ d2 overlay hack (re-instantiates with stubs)
- ⚠️ 229 GB disk, 90-95% full
- ⚠️ Less frequently tested than NixOS

---

## Deployment History (Recent)

| Time | Commit | Action |
|------|--------|--------|
| 05:29 | `21ac978f` | `nh os switch` — portal fix deployed ✅ zero errors |
| 04:57 | `95393fb5` | Status report committed |
| 04:xx | `150ed288` | golangci-lint-auto-configure vendor hash |
| 04:xx | `a65bbdc2` | branching-flow vendor hash |
| 04:xx | `e5ed623f` | All stale vendor hashes + go-filewatcher fix |
| 04:xx | `5f21660f` | buildflow vendor hash |
| 04:xx | `e7b591c5` | Watchdog auto-reboot removed |

---

_Arte in Aeternum_
