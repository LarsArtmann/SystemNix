# SystemNix — Comprehensive Status Report

**Date:** 2026-06-08 02:44 CEST
**Session:** 123 (continuation of 120-122 execution sprint)
**HEAD:** `199b4e71` — docs(status): comprehensive session 122 status report
**Build:** `just test-fast` **GREEN** — all NixOS modules pass, Darwin eval passes
**Deployed:** NixOS 26.11.20260606.cbb5cf3 (Zokor) — **39 commits behind HEAD**
**Branch:** `master` @ `origin/master` (clean working tree except staged doc moves)

---

## System Health (evo-x2)

| Metric | Value | Status |
|--------|-------|--------|
| RAM | 59Gi / 93Gi used | OK |
| Swap | **19Gi / 19Gi (99.96% full)** | CRITICAL |
| Root disk `/` | 389G / 512G (78%) | OK |
| Data disk `/data` | 946G / 1.0T **(93%)** | WARNING |
| BTRFS snapshots | Daily via btrbk | Active |
| Undeployed commits | **~39 commits** | RISK |

**Swap exhaustion is the #1 system risk.** 19Gi swap nearly full. Stale LSP processes (gopls/vtsls) previously identified as cause — daily `stale-lsp-cleanup` timer mitigates but swap is still saturated. Memory pressure could cascade into OOM kills at any time.

---

## Repository Stats

| Metric | Value |
|--------|-------|
| Total `.nix` files | 106+ |
| Total Nix LOC | 16,022 |
| Total commits (2025-2026) | 2,684 |
| Commits June 2026 | 89 |
| Flake inputs | 45+ |
| Service modules | 47 files (39 active, `_` prefix = helper) |
| Registered ports | 29 (in `lib/ports.nix`) |
| Custom packages | 5 |
| Operational scripts | 26 |
| Sops secret files | 9 |
| Status reports | 150+ |

---

## A) FULLY DONE

### Infrastructure Foundation
- **Cross-platform Nix flake** (Darwin + NixOS) using flake-parts — fully modular, auto-discovered services
- **Port centralization** — `lib/ports.nix` as single source of truth with 29 registered ports, zero tolerance for hardcoded ports in NixOS service configs
- **Theme system** — `platforms/common/theme.nix` with expanded Catppuccin palette (164 colors), `theme.font.mono` as single font reference
- **Lib facade** — `lib/default.nix` as single import point: `harden`, `hardenUser`, `serviceDefaults`, `onFailure`, `mkDockerServiceFactory`, `rocm`, `ports`, `images`, `serviceTypes`
- **Systemd hardening** — `harden` (system) / `hardenUser` (user services) with sensible defaults
- **Docker service factory** — `mkDockerServiceFactory` for Docker Compose services with auto-wired defaults
- **Overlay system** — `mkPackageOverlay` for all flake-input overlays (platform-safe, returns empty on unsupported systems)

### Deduplication & Centralization (Sessions 120-122)
- **10+ duplications eliminated** — font names, HaGeZi commit hashes, spring animations, screenshot commands, Go private patterns, GPU kernel params, boot params
- **29 hardcoded ports centralized** to `lib/ports.nix`
- **164 hardcoded colors migrated** to Catppuccin extended palette
- **`onFailure` centralized** — single source in `lib/systemd/service-defaults.nix`, used everywhere
- **Dead code removed** — `colorSchemeName`, dead `lib.optionals`, redundant `tmpfiles.rules`, misplaced `auto-optimise-store`

### Services Running on evo-x2
- **Caddy** — reverse proxy with oauth2-proxy + Pocket ID forward-auth
- **Forgejo** — self-hosted Git with runner
- **SigNoz** — observability (18 alert rules, 4 dashboards, per-threshold routing)
- **Hermes** — AI gateway (GLM-5.1, OpenRouter fallback configured but not activated)
- **Homepage** — dashboard
- **Immich** — photo management
- **Ollama** — local LLM with ROCm GPU acceleration
- **Gatus** — endpoint monitoring (15+ checks)
- **Voice agents** — LiveKit + Whisper pipeline
- **DNS blocker** — HaGeZi blocklists with stats
- **Monitor365** — activity monitoring
- **Photomap** — photo geolocation
- **OpenSEO** — SEO tool
- **Twenty** — CRM
- **Manifest** — project management
- **Pocket ID** — OIDC auth provider
- **oauth2-proxy** — forward auth
- **Dozzle** — Docker log viewer

### Operational Tooling
- **BTRFS snapshots** — daily via btrbk, auto-pruning (14d + 4w), verification timer
- **Boot performance** — 56% reduction via `boot.tmp.useTmpfs`, systemd analysis
- **Post-deploy verification** — `scripts/verify-deployment.sh` (Hermes, boot, SigNoz, Gatus, system health)
- **Disk monitoring** — NVMe health + disk space alerts
- **Display watchdog** — niri DRM health check
- **Stale LSP cleanup** — daily timer killing processes >24h
- **Git hooks** — gitleaks, deadnix, statix, alejandra, nix flake check

---

## B) PARTIALLY DONE

### Hermes AI Gateway (70%)
- Core service running with GLM-5.1
- OpenRouter fallback LLM: sops placeholder created + env var wired, **but not activated** (needs sops secret populated + runtime config)
- SSH deploy key generated but **not installed on target machine**
- Rate limiting will hit without fallback active

### SigNoz Observability (75%)
- Core running with 18 alert rules, 4 dashboards
- Per-threshold routing configured (12 critical → Discord)
- **Discord webhook delivery untested** — needs runtime verification
- Some container-internal ports still hardcoded (9000, 5432, 6379)

### Darwin/macOS (60%)
- Package parity at ~90% with NixOS
- Disk at 90-95% full — severely constrained
- No desktop config parity (terminal, editor, theme)
- Home Manager has minimal config (~7 lines of desktop config)

### Gatus Monitoring (80%)
- 15+ endpoint checks, TLS cert monitoring
- **Endpoint health unverified** post-migration
- Some hardcoded ports remain in gatus config

### Theme System (80%)
- Expanded Catppuccin palette with 164 colors migrated
- `theme.font.mono` adopted everywhere
- **Still raw import** (not module system) — bypasses NixOS/HM module system, can't be overridden via config
- 2 colors (`#6c7086`, `#a6adc8`) previously had no base16 equivalent — resolved in session 122

---

## C) NOT STARTED

### Critical
1. **Deploy 39 undeployed commits** — `just switch` not run since session 122
2. **RPi3 DNS failover** — hardware not acquired, `dns-failover.nix` module exists but unprovisioned
3. **`/data` BTRFS snapshot** — toplevel subvolid=5, not snapshotted, needs conversion to proper subvolume

### Architecture
4. **`theme.nix` → module system** — currently raw import in 6+ places, can't be overridden via config
5. **`servicePort` defaults → `ports.*` lookup** — 16 modules still hardcode default port numbers in option definitions
6. **`disableTests` overlay** — uses `python313Packages` literally, will break on Python 3.14 bump
7. **Container-internal port centralization** — Postgres (5432), Redis (6379), internal service ports not in registry

### Documentation
8. **TODO_LIST.md** — does not exist. Needs creation.
9. **FEATURES.md** — does not exist. Needs creation.
10. **ROADMAP.md** — does not exist. Desktop improvement roadmap exists but is domain-specific.

### Monitoring
11. **SigNoz Discord webhook verification** — configured but untested at runtime
12. **Gatus endpoint health verification** — post-migration health unknown
13. **Hermes fallback activation** — OpenRouter secret needs population

---

## D) TOTALLY FUCKED UP

### Swap Exhaustion — CRITICAL
- **19Gi swap at 99.96% utilization** — essentially zero headroom
- Root cause: stale LSP processes (gopls/vtsls) consuming ~7.4Gi RSS
- Daily `stale-lsp-cleanup` timer mitigates but swap stays saturated
- Any memory spike risks OOM cascade (previously killed journald → system instability)
- **This is a ticking time bomb**

### `/data` at 93% — WARNING
- 946G / 1.0T used on data disk
- NOT snapshotted (BTRFS toplevel subvolid=5)
- No automated cleanup or alerting for data disk
- Risk of disk full → service failures

### 39 Undeployed Commits — RISK
- Blast radius includes: port changes across 12 services, nix settings changes, theme changes, systemd hardening changes
- No staging environment — production is the only target
- If `just switch` fails, rollback via BTRFS snapshots

### Staged But Uncommitted Changes
- 4 `.mmd` architecture diagrams deleted (staged)
- `MIGRATION_TO_NIX_FLAKES_PROPOSAL.md` moved to `docs/planning/` (staged)
- These are sitting in the index, not committed

### Stash Not Clean
- `stash@{0}` — WIP on master with PMA excludePaths changes

---

## E) WHAT WE SHOULD IMPROVE

### High Priority
1. **Swap management** — Investigate root cause of persistent swap saturation. Add swap-based alerting via Gatus/SigNoz. Consider increasing swap or adding memory limits to high-consumption services.
2. **Deploy cadence** — 39 commits undeployed is too many. Establish deploy-every-session discipline or at minimum deploy after every 5-10 commits.
3. **`/data` monitoring** — Add disk usage alerting for the 93% full data disk before it hits 95%+.
4. **Missing project docs** — TODO_LIST.md, FEATURES.md, ROADMAP.md all missing. Status reports pile up without a consolidated action tracking file.

### Architecture
5. **`theme.nix` → module system** — Raw imports bypass the module system, preventing config-level overrides and making the theme non-discoverable via `nixos-option`.
6. **`servicePort` defaults** — 16 modules hardcode port numbers in their option defaults. These should reference `ports.*` but would require module eval restructuring.
7. **`disableTests` overlay** — `python313Packages` is a time bomb. Should use `python3Packages` or a configurable Python version.
8. **`security-hardening.nix`** — hardcoded `onFailure = ["notify-failure@%n.service"]` instead of using the centralized `onFailure` from lib.
9. **Container-internal ports** — Postgres (5432), Redis (6379), and other internal service ports are not in `lib/ports.nix`. Not strictly necessary but would improve discoverability.

### Code Quality
10. **Staged doc cleanup** — Commit or discard the staged `.mmd` deletions and migration proposal move.
11. **Old stash** — `stash@{0}` from a previous PMA feature should be addressed.
12. **Status report bloat** — 150+ status reports in `docs/status/`. Consider archiving older reports (archive/ dir exists but may need more aggressive pruning).
13. **`dns-blocker-stats` port** — Port 9090 in module default AND `dns-blocker-config.nix` — should reference `ports.dns-blocker-stats` in one place only.

---

## F) Top 25 Things We Should Get Done Next

| # | Priority | Item | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | P0 | **Deploy all 39 undeployed commits** (`just switch`) | Critical — unblocks verification | 10 min |
| 2 | P0 | **Run post-deploy verification** (`scripts/verify-deployment.sh`) | Confirms everything works | 5 min |
| 3 | P0 | **Investigate swap saturation** — root cause analysis + fix | Prevents OOM cascade | 30 min |
| 4 | P0 | **Add `/data` disk usage alerting** to SigNoz/Gatus | Prevents silent disk full | 15 min |
| 5 | P1 | **Activate Hermes fallback LLM** — populate OpenRouter sops secret | Prevents rate limit lockout | 20 min |
| 6 | P1 | **Commit staged doc cleanup** — .mmd deletions + migration move | Clean working tree | 2 min |
| 7 | P1 | **Create TODO_LIST.md** — comprehensive action tracking from status reports | Project management hygiene | 30 min |
| 8 | P1 | **Create FEATURES.md** — honest feature inventory by status | Project documentation | 30 min |
| 9 | P1 | **Fix `security-hardening.nix`** — use centralized `onFailure` | Deduplication completeness | 5 min |
| 10 | P1 | **Fix `disableTests` overlay** — use `python3Packages` not `python313Packages` | Prevents future breakage | 15 min |
| 11 | P1 | **`theme.nix` → module system migration** — proper HM/NixOS option | Architecture improvement | 1-2 hr |
| 12 | P1 | **Resolve stash@{0}** — address or discard PMA excludePaths WIP | Clean repo state | 10 min |
| 13 | P2 | **`servicePort` defaults → `ports.*`** (16 modules) | Centralization completeness | 2-3 hr |
| 14 | P2 | **SigNoz Discord webhook delivery test** — verify runtime delivery | Monitoring confidence | 15 min |
| 15 | P2 | **Gatus endpoint health verification** — post-migration check | Monitoring confidence | 15 min |
| 16 | P2 | **Convert `/data` to BTRFS subvolume** — enable snapshotting | Data protection | 30 min |
| 17 | P2 | **RPi3 DNS failover provisioning** — acquire hardware + deploy | Infrastructure resilience | 2-4 hr |
| 18 | P2 | **Hermes SSH deploy key installation** — complete git access | Hermes git integration | 10 min |
| 19 | P2 | **Container-internal port documentation** — add to ports.nix or document separately | Discoverability | 1 hr |
| 20 | P2 | **Archive old status reports** — move 100+ old reports to archive/ | Repo cleanliness | 5 min |
| 21 | P3 | **Darwin disk cleanup** — reclaim space on 90%+ full SSD | Darwin usability | 30 min |
| 22 | P3 | **Darwin desktop config parity** — terminal, editor, theme | Cross-platform consistency | 2-4 hr |
| 23 | P3 | **Create ROADMAP.md** — long-term direction and raw ideas | Project planning | 30 min |
| 24 | P3 | **`dns-blocker-config.nix` port dedup** — single source for statsPort | Deduplication | 10 min |
| 25 | P3 | **Swap-based alerting** — Gatus/SigNoz check for swap > 90% | Proactive monitoring | 15 min |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Why is swap still at 99.96% despite the `stale-lsp-cleanup` timer?**

The daily timer kills processes older than 24h, yet swap remains saturated. This suggests either:
- The cleanup timer isn't running or isn't effective (processes respawn faster than they're killed)
- There's a different major swap consumer beyond LSP processes
- Memory is being allocated but never freed back to swap (fragmentation)

**I need runtime access to evo-x2 to diagnose:** `smem -t -k` and `cat /proc/swaps` and `systemctl status stale-lsp-cleanup.timer` to identify the actual swap consumers and verify the timer is working. This is a blocking risk for system stability.

---

## Staged Changes (Not Yet Committed)

```
D docs/architecture-understanding/2025-07-15_12-59-events-commands-session.mmd
D docs/architecture-understanding/2025-07-15_12-59-terminal-performance-session.mmd
D docs/architecture-understanding/2025-07-21_02_33-network-monitoring.mmd
D docs/architecture-understanding/2025-11-15_07_49-events-commands-current.mmd
R MIGRATION_TO_NIX_FLAKES_PROPOSAL.md → docs/planning/MIGRATION_TO_NIX_FLAKES_PROPOSAL.md
```

## Stash

```
stash@{0}: WIP on master: 38974be2 feat(pma): wire excludePaths for forks/archived, update flake lock
```
