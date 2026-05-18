# Session 39 — Full Comprehensive Status Update

**Date:** 2026-05-18 18:59 CEST
**Session:** 39
**Host:** evo-x2 (192.168.1.150, x86_64-linux)
**Branch:** master (ahead 1 of origin/master)
**Total Commits:** 2415
**Repo Size:** ~933 MiB

---

## Executive Summary

SystemNix is in **excellent operational shape** with one uncommitted change (tor-browser restored to `base.nix`). All 35 service modules evaluate cleanly, `nix flake check --no-build` passes, and 17/17 upstream overlay packages build successfully. The system has been running stably for 2+ days with ~140 enabled features across NixOS, macOS, and shared infrastructure.

**Key changes since Session 38:**
- `tor-browser` restored to `platforms/common/packages/base.nix` (Linux-only, in `linuxUtilities`)
- All previous Session 38 findings remain valid

---

## a) FULLY DONE ✅

### Core Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| flake.nix architecture | ✅ | flake-parts modular, 35 service modules, 3 system configs (evo-x2, rpi3-dns, Lars-MacBook-Air) |
| NixOS evo-x2 evaluation | ✅ | `nix flake check --no-build` passes cleanly |
| NixOS rpi3-dns build | ✅ | SD image builds (3.38 GiB, aarch64-linux) |
| Darwin evaluation | ✅ | `nix flake check --all-systems --no-build` passes |
| Cross-platform Home Manager | ✅ | 15 shared program modules, ~80% config shared |
| Vendor hash audit | ✅ | All 17 overlay packages: zero stale hashes |
| `just test-upstream-builds` | ✅ | 17/17 packages build successfully |
| `just test-fast` | ✅ | Syntax-only validation passes |
| Code cleanliness | ✅ | Zero TODO/FIXME/HACK/XXX across all 111 .nix files |

### Enabled Services on evo-x2 (40 `enable = true` in configuration.nix)

| Category | Services |
|----------|----------|
| **Infrastructure** | Docker, Caddy, SOPS, Authelia, DNS blocker, DNS failover, Dual-WAN |
| **Self-hosted apps** | Gitea, Immich, Homepage, SigNoz, TaskChampion, Twenty CRM, OpenSEO, Manifest |
| **AI/ML** | Ollama, llama.cpp, AI model storage, Hermes, Voice agents |
| **Desktop** | Niri, SDDM, PipeWire, Niri session manager, Browser policies, Steam |
| **Monitoring** | Gatus, Disk monitor, Node exporter, cAdvisor |
| **System** | Security hardening, File & image renamer, Monitor365, Fstrim |

### Disabled Services (2 `enable = false`)

| Service | Reason |
|---------|--------|
| ComfyUI | User prefers AI models via code directly (Session 38) |
| Minecraft server | Intentionally disabled; client enabled |

### Upstream Overlay Packages (17/17 Building)

All packages build cleanly. No cascade failures since Session 36.

| Package | Type | Status |
|---------|------|--------|
| library-policy | Go | ✅ |
| hierarchical-errors | Go | ✅ |
| golangci-lint-auto-configure | Go | ✅ |
| mr-sync | Go | ✅ |
| buildflow | Go | ✅ |
| go-auto-upgrade | Go | ✅ |
| go-structure-linter | Go | ✅ |
| branching-flow | Go | ✅ |
| art-dupl | Go | ✅ |
| projects-management-automation | Go | ✅ |
| dnsblockd | Go | ✅ |
| file-and-image-renamer | Go | ✅ |
| emeet-pixyd | Go | ✅ |
| monitor365 | Rust | ✅ |
| todo-list-ai | Bun/Node | ✅ |
| jscpd | pnpm/Node | ✅ |
| aw-watcher-utilization | Python | ✅ |

### Libraries & Patterns (lib/)

| Library | Consumers | Status |
|---------|-----------|--------|
| `harden` / `hardenUser` | 20+ service modules | ✅ |
| `serviceDefaults` / `serviceDefaultsUser` | 15+ modules | ✅ |
| `serviceTypes` | 12+ service modules | ✅ |
| `mkDockerServiceFactory` | voice-agents, openseo, twenty, immich | ✅ |
| `mkStateDir` | hermes, ai-models, etc. | ✅ |
| `mkPreparedSource` | Exported (upstream repos consume) | ✅ v2 |

### Documentation

| Document | Status |
|----------|--------|
| AGENTS.md | ✅ Current, 1600+ lines |
| FEATURES.md | ✅ Current, ~500 lines, honest status icons |
| ADRs | ✅ 7 records |
| Status reports | ✅ 56+ reports in docs/status/ |

---

## b) PARTIALLY DONE 🔄

| Item | What's Done | What's Missing |
|------|-------------|----------------|
| **mkPreparedSource v2** | Created with per-dep `subModules`, 4 repos migrated | SystemNix itself doesn't consume it (only exports for upstream) |
| **Darwin build verification** | Evaluates via `nix flake check` | Full `nix build` not run from MacBook since Session 36 changes |
| **netwatch installation** | Built as overlay, exposed as flake package | **NOT in `base.nix`** — not on PATH (Session 38 open question) |
| **photomap** | Module exists, CLIP embedding viz | Disabled due to podman permission issue; dead commented code in configuration.nix |
| **Voice agents** | Module enabled, Docker Compose defined | Whisper ROCm pipeline may need runtime verification |
| **XDG_PROJECTS_DIR deprecation** | Works with current key name | HM warns: `'XDG_PROJECTS_DIR'` deprecated, should use `'PROJECTS'` |
| **Nixpkgs x86_64-darwin** | Evaluates fine | **Nixpkgs 26.05 will be the LAST release to support x86_64-darwin** |
| **Status report archive** | 56 reports in docs/status/ | No automatic archiving; old reports accumulating |
| **Tor-browser placement** | Restored to `base.nix` | Now in `linuxUtilities` block — correct location but was previously removed |

---

## c) NOT STARTED ❌

| Item | Why It Matters |
|------|----------------|
| **Raspberry Pi 3 hardware provisioning** | Entire DNS failover cluster is planned-only; no backup DNS node |
| **Cachix binary cache setup** | Every rebuild compiles from scratch; massive time sink |
| **CI/CD for `nix flake check`** | No automated checks on push/PR; breakage only caught manually |
| **Dependency graph visualization tool** | When go-output changes, manual trial-and-error to find stale vendor hashes |
| **`update-all-vendor-hashes` automation** | Still manual: set `""`, build, grep `got:`, paste |
| **Go.sum transitive merge audit** | Core dep changes (go-output) cascade to all consumers; no early warning |
| **SigNoz per-threshold alert routing** | All alerts go to same Discord channel; no severity-based routing |
| **DNS-over-QUIC overlay** | Disabled — breaks binary cache (40+ min builds) |
| **Benchmark/performance scripts** | Referenced in FEATURES.md but scripts never created |
| **AppArmor enablement** | Disabled (`lib.mkDefault false`) — could be hardened further |
| **Auditd re-enablement** | Blocked by NixOS 26.05 bug #483085; no upstream fix yet |
| **Distributed Darwin builds** | MacBook at 90-95% disk; no remote build to evo-x2 configured |

---

## d) TOTALLY FUCKED UP! 🔥

| Issue | Severity | Details |
|-------|----------|---------|
| **Nixpkgs x86_64-darwin deprecation** | 🔴 HIGH | Nixpkgs 26.05 is the **last** release supporting x86_64-darwin. MacBook Air is aarch64-darwin so this doesn't directly affect us, but it signals ecosystem decline for Intel macOS. |
| **XDG_PROJECTS_DIR deprecation warning** | 🟡 MEDIUM | Home Manager evaluation warning on every build. Fix: rename key to `PROJECTS` in `platforms/common/environment/variables.nix:17`. |
| **Disk space on evo-x2 root** | 🟡 MEDIUM | `/` at **86%** (421G/512G used). Only 75G free. Nix store is 90G. Risk of build failures when disk runs low. |
| **Disk space on evo-x2 /data** | 🟡 MEDIUM | `/data` at **81%** (827G/1T used). AI models, Docker, and Immich consume significant space. |
| **Status report accumulation** | 🟡 MEDIUM | 56+ status reports in docs/status/ (not counting archive/). No cleanup policy. |
| **photomap dead code** | 🟡 MEDIUM | Commented-out `photomap.enable = true` with stale podman issue. Module exists but unmaintained. |
| **Darwin build unverified** | 🟡 MEDIUM | Session 36 changes not actually built on MacBook. Could have latent issues. |
| **rpi3-dns unprovisioned** | 🟡 MEDIUM | DNS failover cluster is theoretical. Single point of failure for DNS. |
| **Load average spiking** | 🟡 MEDIUM | Load avg: 5.24 / 11.74 / 19.55 — system under heavy load (likely AI workloads). Not critical but worth monitoring. |

### Not Fucked Up (Worth Monitoring)

| Observation | Assessment |
|-------------|------------|
| `nix eval .#nixosConfigurations.evo-x2.config.systemd.services` errors on `ModemManager`/`ExecStart` | **Upstream nixpkgs issue** — not SystemNix-specific. `nix flake check` passes; this is a `nix eval` JSON serialization quirk with systemd services that have test runners. |
| `nix eval .#nixosConfigurations.evo-x2.config.services` errors on `SystemdJournal2Gelf`/`graylogServer` | **Upstream nixpkgs module** — missing default value. Not used by SystemNix. `nix flake check` passes. |

---

## e) WHAT WE SHOULD IMPROVE! 📈

### Immediate (This Week)

1. **Fix XDG_PROJECTS_DIR deprecation** — rename to `PROJECTS` (1 line change)
2. **Decide on `netwatch`** — add to `base.nix` or document as overlay-only
3. **Decide on `photomap`** — fix, enable, or remove module + dead comment
4. **Disk cleanup** — `just clean` + `nix-collect-garbage` on evo-x2
5. **Verify Darwin build** — run `nix build .#darwinConfigurations.Lars-MacBook-Air.system` from MacBook

### Short Term (Next 2 Weeks)

6. **Set up Cachix** — binary cache for faster rebuilds
7. **GitHub Actions CI** — `nix flake check --no-build` on every push/PR
8. **Archive old status reports** — move reports older than 2 weeks to `docs/status/archive/`
9. **Create `mk-pnpm-package.nix` reusable helper** — extract jscpd pattern
10. **Write upstream fix playbook** — document Session 35/36 vendor hash cascade learnings

### Medium Term (Next Month)

11. **Dependency graph tool** — "I updated go-output — which packages need vendor hash bumps?"
12. **Automated vendor hash updater** — script that walks dep graph and updates hashes
13. **rpi3-dns hardware provisioning** — buy SD card, flash, deploy
14. **SigNoz alert routing** — critical→Discord DM, warning→channel, info→log only
15. **Distributed Darwin builds** — configure evo-x2 as remote builder for MacBook

### Strategic (Next Quarter)

16. **Explore `fetchGoModules`** for private repos — simplify vendor management
17. **Standardize all Go repos on mkPreparedSource v2** — eliminate _local_deps boilerplate
18. **Migrate from `justfile` to `flake.nix`** per AGENTS.md policy (AGENTS.md says justfile is deprecated)
19. **Contribute jscpd upstream fix** — wrapped-src pattern for Nixpkgs
20. **Security audit** — move `dns-failover.nix` plaintext `authPassword` to sops

---

## f) Top #25 Things We Should Get Done Next! 🎯

| # | Task | Why | Effort | Impact |
|---|------|-----|--------|--------|
| 1 | **Fix XDG_PROJECTS_DIR deprecation** | Eliminates HM warning on every build | 2 min | Low |
| 2 | **Decide on `netwatch`** | Built but not installed — confusing | 5 min | Low |
| 3 | **Decide on `photomap`** | Dead commented code + stale module | 10 min | Medium |
| 4 | **Run `just clean` on evo-x2** | Disk at 86% — prevent build failures | 10 min | High |
| 5 | **Verify Darwin build from MacBook** | Latent issues possible since Session 36 | 30 min | High |
| 6 | **Archive status reports >2 weeks old** | 56+ reports, no cleanup policy | 10 min | Low |
| 7 | **Set up Cachix binary cache** | Massive rebuild time savings | 2 hours | Very High |
| 8 | **GitHub Actions `nix flake check` CI** | Prevent breakage on push | 1 hour | Very High |
| 9 | **Create `mk-pnpm-package.nix` helper** | Reuse jscpd pattern | 1 hour | Medium |
| 10 | **Write upstream fix playbook** | Prevent repeated cascade debugging | 30 min | Medium |
| 11 | **Go.sum transitive merge audit** | Prevent future cascade failures | 1 hour | High |
| 12 | **Dependency graph visualization** | "What breaks when go-output updates?" | 2 hours | High |
| 13 | **Automated vendor hash updater** | Set `""`, build, grep, paste → one command | 3 hours | Very High |
| 14 | **rpi3-dns hardware provisioning** | Eliminate DNS single point of failure | Hardware | High |
| 15 | **SigNoz per-threshold routing** | Critical→DM, warning→channel | 1 hour | Medium |
| 16 | **Distributed Darwin builds** | MacBook disk at 90-95% | 2 hours | High |
| 17 | **Migrate justfile → flake.nix** | AGENTS.md policy: justfile deprecated | 4 hours | Low |
| 18 | **Standardize ADR numbering** | Some `ADR-NNN`, some `NNN-` | 15 min | Low |
| 19 | **DNS-over-QUIC re-evaluation** | Currently disabled for build time | 1 hour | Low |
| 20 | **AppArmor enablement** | Currently `mkDefault false` | 2 hours | Medium |
| 21 | **Auditd re-enablement** | Blocked by nixpkgs #483085; track upstream | Ongoing | Medium |
| 22 | **Consolidate voice-agents Caddy vHost** | Inconsistency with other services | 30 min | Low |
| 23 | **Move dns-failover authPassword to sops** | Plaintext password in module | 30 min | Medium |
| 24 | **Add per-service health check endpoints** | Beyond Gatus — self-reporting | 3 hours | Medium |
| 25 | **Contribute jscpd upstream fix** | Give back to nixpkgs | 2 hours | Low |

---

## g) Top #1 Question I Cannot Figure Out Myself ❓

**Is `netwatch` intentionally kept as an overlay-only package (buildable but not on PATH), or should it be added to `platforms/common/packages/base.nix` like `govalid`?**

- `netwatch` is a Rust TUI for real-time network diagnostics — seems useful on NixOS (evo-x2)
- It is exposed as a flake package (`packages.x86_64-linux.netwatch`)
- It is **NOT** in `base.nix` or any `environment.systemPackages`
- The AGENTS.md rule states: "All overlay tools that are meant to be user-facing are listed in `base.nix`"
- `govalid` was correctly identified as user-facing and IS in `base.nix`
- Session 38 asked this question; no answer was given

This suggests `netwatch` should either be added to `base.nix` (if user-facing) or documented as intentionally overlay-only (if only meant as a buildable derivation for other flakes to consume). **I cannot determine the intent without asking.**

---

## System Metrics

| Metric | Value | Δ from Session 38 |
|--------|-------|-------------------|
| `.nix` files | 111 | — |
| Service modules | 35 | — |
| Overlay packages (building) | 17 | — |
| Enabled services on evo-x2 | ~29 | — |
| Disabled services | 2 | — |
| Flake inputs (direct) | 30 | — |
| Flake inputs (transitive) | 137 | — |
| Total commits | 2415 | +4 |
| Status reports | 56+ | +1 (this one) |
| Root disk usage | 86% | — |
| /data disk usage | 81% | — |
| Nix store size | 90G | — |
| Memory used | 43Gi / 62Gi | — |
| Uptime | 2 days 4:15 | — |
| Load average | 5.24 / 11.74 / 19.55 | — |

## Key Verification Commands

```bash
nix flake check --all-systems --no-build   # ✅ passes (warnings only)
just hash-check                             # ✅ all packages OK
just test-upstream-builds                   # ✅ 17/17 OK
just test-fast                              # ✅ syntax OK
nix build .#nixosConfigurations.rpi3-dns.config.system.build.sdImage  # ✅ builds
```

## Changes This Session

| Commit/File | Change |
|-------------|--------|
| `e64057c4` | `chore(deps): update flake.lock — version fix for 5 repos` |
| **Uncommitted** | `tor-browser` restored to `platforms/common/packages/base.nix:261` |

## Uncommitted Changes Detail

```diff
diff --git a/platforms/common/packages/base.nix b/platforms/common/packages/base.nix
index e45753e1..c65cf4c6 100644
--- a/platforms/common/packages/base.nix
+++ b/platforms/common/packages/base.nix
@@ -257,6 +257,9 @@
       nethogs # Per-process network bandwidth
       iftop # Network interface bandwidth

+      # Privacy & anonymity
+      tor-browser # Anonymous browsing bundle
+
       # Additional ricing tools discovered from community configs
       wl-color-picker # Color picker for Wayland
       swappy # Screenshot annotation tool
```

- **Why:** User requested to keep tor-browser but place it in a better location (not in `security-hardening.nix` with offensive tools)
- **Where:** `linuxUtilities` block in `base.nix` — user-facing GUI app, available on PATH for Linux
- **Eval status:** Passes (`nix flake check --no-build` clean)

---

_**Status: EXCELLENT** — One uncommitted change (tor-browser), all builds green, zero critical issues._
