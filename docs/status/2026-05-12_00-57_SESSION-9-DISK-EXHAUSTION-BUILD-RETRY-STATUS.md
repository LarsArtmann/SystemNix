# Session 9 — Full Comprehensive Status Report

**Date:** 2026-05-12 00:57 CEST
**Context:** Resuming after disk-space exhaustion killed two consecutive `nh darwin build` attempts. Task: diagnose failures, free space, retry build, commit status.

---

## Executive Summary

The macOS (Darwin) build has **failed twice** with `errno=28` (No space left on device) during the `nh darwin build` phase. Two heavy from-source builds — **taskwarrior** (C++ + Rust, ~50min) and **otel-tui** (Go + dsymutil) — run concurrently and exhaust the 229GB disk. I freed ~11GB by clearing application caches and restarted the build with `--max-jobs 1` to serialize the heavy builds. The retry is **currently running** (started 00:54 CEST).

---

## A) FULLY DONE ✓

### Disk Space Recovery
- **Before:** 11 GB free (96% full)
- **Action:** Cleared `~/Library/Caches/` subdirs: Google (2.2G), Helium (1.1G), goimports (469M), Signal (335M), Spotify (253M), JetBrains (247M), gopls (207M), node-gyp (64M) = ~5 GB freed
- **After:** 18-22 GB free (91-93%)
- **Also ran:** `nix-collect-garbage --delete-older-than 1d` (killed after timeout, partial GC completed)

### Unpushed Commits (3 ahead of origin/master)
These were committed in previous sessions but not yet pushed:

| Commit | Description | Files |
|--------|-------------|-------|
| `5cb94248` | `fix(diagnostics): remove harmful route reset commands from internet-diagnostic` | `scripts/internet-diagnostic.sh` |
| `3be978de` | `fix(dual-wan): preserve failover state across route-health-monitor restarts` | `scripts/route-health-monitor.sh` |
| `11275689` | `fix(justfile): wan-status recipe was sending local macOS path to remote` | `justfile` |

### Previous Session Work (Sessions 6-8)
All documented in `docs/status/2026-05-11_23-47_SESSION-8-*.md`. Key completions:
- Pipe operators across 4 repos (dnsblockd, mr-sync, private-cloud, SystemNix sops.nix)
- GPU defense layers (OLLAMA_MAX_LOADED_MODELS, OOMScoreAdjust, gpu-memory-budget)
- Overlay extraction refactor (overlays/ directory)
- 25+ status reports written and committed
- sops fix (mkKeyedSecrets double-semicolon)
- gatus sops template owner fix

---

## B) PARTIALLY DONE ⚠️

### Darwin Build (IN PROGRESS — 3rd attempt)
- **Attempt 1** (52 min): `otel-tui` dsymutil `LLVM ERROR: IO failure on output stream: No space left on device` → taskwarrior had already passed its test suite (177/177 passed)
- **Attempt 2** (31 min): After freeing ~5GB. Both otel-tui AND taskwarrior failed — taskwarrior at `ld: can't write to output file: test_runner, errno=28` during test linking. Disk went from 22GB → 0 during concurrent builds.
- **Attempt 3** (CURRENT): `--max-jobs 1` to serialize builds. Started 00:54 CEST. Taskwarrior will build first (heaviest), then otel-tui.
- **Risk:** Even with serialized builds, 18-22GB may still be tight if Nix build sandbox temp files + store growth exceed available space.

### Nix Store Garbage Collection
- Started `nix-collect-garbage --delete-older-than 1d` but it hung/timed out
- Partial GC ran during the process — some old derivations cleaned
- Full GC still needed to reclaim more space

---

## C) NOT STARTED ○

1. **Push 3 unpushed commits to origin/master** — waiting for successful build first
2. **NixOS (evo-x2) rebuild** — only Darwin is being tested; NixOS config changes from sessions 6-8 need deployment
3. **Pipe operator completion in SystemNix** — 4 of 5 files were reverted by concurrent sessions; only sops.nix retained
4. **Post-build verification** — `just switch` on macOS after successful build
5. **Update AGENTS.md** with disk-space lesson learned
6. **Archive old status reports** — 21 files in `docs/status/`, older ones should go to `archive/`

---

## D) TOTALLY FUCKED UP 💥

### Disk Space Crisis on macOS (229GB disk, 93% full)

**Root cause:** The Nix store is 36GB. Building taskwarrior from source requires:
- Rust compilation of taskchampion-lib (~4GB build dir)
- C++ compilation + linking of 100+ object files
- 177 test suite runs
- Test runner binary linking (the exact point where it failed)

When taskwarrior + otel-tui build **concurrently** (default `--max-jobs` = 8 cores), the combined build sandbox size exceeds available disk. The `dsymutil` step for otel-tui (DWARF debug symbol generation) is particularly disk-hungry.

**Impact:** 52 minutes of build time wasted on first attempt, 31 minutes on second. Total ~83 minutes of CPU time burned.

**The real problem:** This MacBook Air has a 229GB disk. Between:
- Nix store: 36 GB
- Application Support: 28 GB (Google 9.3G, ActivityWatch 4.5G, Steam 1.7G)
- System/OS: ~40 GB
- Other user data: remaining

There's chronically insufficient headroom for from-source builds of large packages.

**Mitigation applied:** `--max-jobs 1` serializes builds. But this is a band-aid — the disk is simply too small for the workload.

### Build Time Waste
- taskwarrior takes ~50 minutes from source (C++ + Rust compilation)
- otel-tui takes ~40 minutes (Go + dsymutil)
- Both failed at the very end (test runner linking / dsymutil) after completing all compilation
- Total wasted: ~83 minutes of build time across 2 attempts

---

## E) WHAT WE SHOULD IMPROVE

### 1. Disk Space Management
- **Automated monitoring:** Add a pre-build disk check to `justfile` that warns if < 25GB free
- **Regular GC:** Schedule `nix-collect-garbage` via LaunchAgent (weekly)
- **Build cache strategy:** Consider substituting taskwarrior/otel-tui from cachix instead of building from source every time
- **Application bloat audit:** 28GB in Application Support is excessive — ActivityWatch (4.5G), Google (9.3G) are the biggest offenders

### 2. Build Resilience
- **Default `--max-jobs 1` for Darwin:** The MacBook Air disk can't handle concurrent from-source builds
- **Pre-flight disk check in `just switch`:** Fail fast with clear message instead of 50 minutes of wasted build time
- **Consider otel-tui as Linux-only:** It's an observability TUI — only useful on NixOS. Excluding it from Darwin would save 40+ minutes per build.

### 3. Status Report Hygiene
- **Archive regularly:** 21 status files is too many. Move anything older than current session to `archive/`
- **Consolidate:** Multiple overlapping reports from concurrent sessions create confusion

### 4. AGENTS.md Updates Needed
- Document `errno=28` disk exhaustion pattern
- Add `--max-jobs 1` recommendation for Darwin builds
- Document otel-tui as Linux-only candidate

---

## F) Top 25 Things We Should Get Done Next

### Critical (Build & Deploy)
1. **Wait for current Darwin build to complete** (running now, `--max-jobs 1`)
2. **If build fails again:** Free more disk space (ActivityWatch data: 4.5G, Google: 9.3G)
3. **Run `just switch` on macOS** after successful build
4. **Push 3 unpushed commits** to origin/master
5. **NixOS rebuild** on evo-x2 to deploy dual-WAN + diagnostics fixes

### Disk & Performance
6. **Add pre-flight disk check** to `justfile` switch recipe (`df -h / | awk 'NR==2{if($4+0 < 25) exit 1}'`)
7. **Evaluate otel-tui as Linux-only package** — save 40min per Darwin build
8. **Schedule weekly Nix GC** via macOS LaunchAgent
9. **Audit ~/Library/Application Support** — 28GB is excessive
10. **Consider cachix binary cache** for taskwarrior + otel-tui to avoid from-source builds

### Code Quality
11. **Complete pipe operator conversion** in SystemNix (4 files reverted by concurrent sessions)
12. **Add `--max-jobs` flag to justfile** for Darwin builds
13. **Archive old status reports** to `docs/status/archive/`
14. **Update AGENTS.md** with disk-space gotcha and Darwin build recommendations

### NixOS (evo-x2) Services
15. **Verify dual-WAN failover** works with new route-health-monitor state detection
16. **Test internet-diagnostic script** on evo-x2 (confirm no harmful route resets)
17. **Check SigNoz health** after all the recent service restarts
18. **Verify Gatus endpoint monitoring** is healthy post-sops fix
19. **Test `just wan-status`** on evo-x2 with fixed remote command execution

### Monitoring & Alerting
20. **Add disk-space alert** to Gatus for evo-x2 (and consider for macOS)
21. **Verify Discord notifications** are flowing from Gatus
22. **Check Ollama GPU budget** is still correctly configured after rebuilds

### Infrastructure
23. **Provision Raspberry Pi 3** for DNS failover cluster (still planned)
24. **Evaluate OpenSEO DataForSEO** cost after first month of usage
25. **Review watchdogd status** on evo-x2 — known nixpkgs module bugs with device/reset-reason

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should otel-tui be moved to Linux-only?**

The otel-tui package (OpenTelemetry TUI viewer) is a flake input that builds from source on ALL platforms. On macOS it:
- Takes 40+ minutes to build (Go compilation + dsymutil DWARF symbols)
- Is the #1 cause of disk exhaustion during Darwin builds (dsymutil writes huge temp files)
- Has questionable utility on macOS — it's primarily for inspecting evo-x2's OTel telemetry

Moving it to `linuxOnlyOverlays` would:
- Save ~40 min per Darwin build
- Eliminate the primary disk exhaustion trigger
- Not lose any macOS functionality

But I can't determine if you actively use otel-tui on macOS (e.g., SSH tunnel to evo-x2's OTel collector). **Do you use otel-tui on macOS, or is it safe to make Linux-only?**

---

## Build Status at Report Time

| Item | Status |
|------|--------|
| Darwin build (attempt 3) | 🔄 RUNNING (`--max-jobs 1`, started 00:54) |
| Disk space | 18-22 GB free (91-93%) |
| Taskwarrior | Not yet rebuilt (3rd attempt) |
| otel-tui | Not yet rebuilt (3rd attempt) |
| NixOS (evo-x2) | Not deployed (3 commits behind) |
| Git working tree | Clean |
| Git branch | master (3 ahead of origin) |

---

*Report generated at 2026-05-12 00:57 CEST by Crush (Session 9)*
