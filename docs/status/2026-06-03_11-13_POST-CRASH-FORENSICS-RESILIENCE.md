# SystemNix — Comprehensive Status Report

**Date:** 2026-06-03 11:13 CEST
**Host:** evo-x2 (x86_64-linux, NixOS, kernel 7.0.10)
**Session:** 116 — Post-Crash Forensics & Resilience
**Build:** ✅ `just test-fast` passes

---

## Table of Contents

1. [Incident Report: May 30–June 3 Disk-Full Crash](#1-incident-report)
2. [Current System Health](#2-current-system-health)
3. [A) Fully Done](#3-fully-done)
4. [B) Partially Done](#4-partially-done)
5. [C) Not Started](#5-not-started)
6. [D) Totally Fucked Up](#6-totally-fucked-up)
7. [E) What We Should Improve](#7-what-we-should-improve)
8. [F) Top 25 Things to Do Next](#8-top-25-next)
9. [G) Unanswered Question](#9-unanswered-question)

---

## 1. Incident Report: May 30–June 3 Disk-Full Crash

### Timeline

| Time | Event |
|------|-------|
| May 29+ | `disk-monitor.service` broken — `df --output` field `pct` unknown (should be `pcent`). Every 5min check fails silently. |
| May 30 ~07:18 | `/data` hits 100% full. ClickHouse: `Cannot reserve 1.00 MiB, not enough space`. Redis: `MISCONF unable to persist to disk`. Forgejo: `database or disk is full`. Gatus: `panic: disk I/O error (4874)`. |
| May 30 07:18–07:22 | Full cascade — every service on `/data` fails. Pocket ID, metrics collectors, Forgejo, Immich all down. Journal floods with thousands of error lines/minute. |
| Jun 3 02:43 | System crashes hard (all `last` sessions end in `crash`). Exact cause unknown — journal for that boot was rotated away. |
| Jun 3 03:00 | System reboots. Services recover. `/data` now 93% (74G free). |
| Jun 3 11:00 | Forensics session: root cause identified, two fixes applied. |

### Root Causes (Two)

1. **`disk-monitor` typo** — `pct` → `pcent` in `df --output` field name. Service broken since at least May 29. Zero disk alerts sent before or during the crisis.
2. **Journal too small (4G)** — Error flood consumed entire 4G journal budget, rotating away the crash boot logs. Cannot diagnose what actually caused the June 3 reboot.

### Fixes Applied (This Session)

| Fix | File | Before | After |
|-----|------|--------|-------|
| `df` field name | `modules/nixos/services/disk-monitor.nix` | `pct` | `pcent` |
| Journal size limit | `platforms/nixos/system/boot.nix` | `SystemMaxUse=4G` | `SystemMaxUse=16G` |
| Journal runtime limit | `platforms/nixos/system/boot.nix` | `RuntimeMaxUse=1G` | `RuntimeMaxUse=2G` |
| Journal retention | `platforms/nixos/system/boot.nix` | `MaxRetentionSec=2week` | `MaxRetentionSec=1month` |

### What Freed the 74GB

Unknown — no journal survived from the boot that freed space. Likely candidates:
- Weekly Docker prune timer ran after services recovered
- `nix-gc` timer cleaned old generations
- Some service wrote temporary data that was cleaned on reboot

### `/data` Breakdown (950G used)

| Path | Size | Notes |
|------|------|-------|
| `/data/models/` | 481G | AI model storage (Ollama 107G, video models 84G+45G+36G, anime 48G, HiDream 66G, LLM 37G) |
| `/data/llamacpp-models/` | 207G | llama.cpp model files (UniGenDet 55G, BAGEL 28G, Gemma 38G, Qwen 41G) |
| `/data/ai/` | 174G | AI models 124G + cache 51G |
| `/data/SteamLibrary/` | 107G | Steam games |
| `/data/unsloth/` | 28G | venv 24G (pip install leak) |
| `/data/testfile` | 4G | Orphaned test file from Apr 22 |

---

## 2. Current System Health

### Resources

| Metric | Value | Status |
|--------|-------|--------|
| Root (`/`) | 403G/512G (81%) | ⚠️ Trending up |
| `/data` | 950G/1.0T (93%) | 🔴 Critical — 74G free on 1TB |
| `/boot` | 238M/2.0G (12%) | ✅ Fine |
| RAM | 25G/93G used (27%) | ✅ Healthy |
| Swap | 5M/19G used | ✅ Healthy (was 13G/13G on May 30!) |
| Load | 2.17 / 1.76 / 1.57 | ✅ Normal |
| Nix store | 83G | ⚠️ Should GC |
| Journal | 3.9G/4G (becoming 16G) | ⚠️ Near limit, fix pending deploy |

### Services — This Boot (June 3, 03:00)

| Service | Status | Notes |
|---------|--------|-------|
| Caddy | ✅ | Running, all vHosts up |
| Forgejo | ✅ | Running, SQLite recovered |
| Immich | ✅ | Running, Redis recovered |
| SigNoz (ClickHouse + OTel) | ✅ | Running, metrics flowing |
| Gatus | ✅ | 26 endpoints monitored |
| oauth2-proxy | ✅ | Running (initial start failed, auto-recovered) |
| Pocket ID | ✅ | Running |
| Homepage | ✅ | Running |
| Ollama | ⚠️ | Gatus reports `success=false` — may be down or misconfigured |
| Monitor365 | ❌ | Failing repeatedly (user service) |
| disk-monitor | 🔧 | Fix committed, NOT deployed yet |
| DNS blocker CA import | ⚠️ | NSS cert import failing (user service) |

### Build & Tests

- `just test-fast`: ✅ All checks passed
- `git status`: 1 modified file (`boot.nix` — journald config)
- Uncommitted changes: journald size increase + disk-monitor fix already committed in `f0039e76`

---

## 3. A) Fully Done

### Infrastructure & Architecture

| Item | Details |
|------|---------|
| Cross-platform flake | Darwin + NixOS, 80% shared via `platforms/common/` |
| flake-parts modular services | 29 service modules, auto-discovered |
| Overlay system | `overlays/` directory, `mkPackageOverlay` platform-safe helper |
| Custom packages | 13 packages in `pkgs/` (6 Go, 2 Rust, 1 Python, 1 Node, 3 via inputs) |
| Shared Home Manager | `sharedHomeManagerConfig` across both platforms |
| BTRFS snapshot system | Daily root snapshots via `btrbk`, auto-pruning 14d+4w |
| Boot performance | `useTmpfs=true` → 56% reduction (2m13s → 58s) |
| Formatter | treefmt + alejandra, committed |
| SOPS + Age secrets | 4 sops files, age via SSH host key, auto-restart per secret |
| Auth stack | Pocket ID → oauth2-proxy → Caddy forward-auth, fully wired |

### Services — Production

| Service | Module | Key Details |
|---------|--------|-------------|
| Caddy | `caddy.nix` | 10 vHosts, TLS, forward-auth, metrics |
| Forgejo | `forgejo.nix` | SQLite, LFS, Actions runner, federation, push mirrors |
| Immich | `immich.nix` | PostgreSQL+Redis+ML, OAuth, VA-API transcoding |
| SigNoz | `signoz.nix` | ClickHouse+OTel+node_exporter+cadvisor, 7 alert rules, 4 dashboards |
| Gatus | `gatus-config.nix` | 26 endpoints, Discord alerts, TLS cert monitoring |
| Twenty CRM | `twenty.nix` | Docker Compose, daily DB backup |
| Hermes AI | `hermes.nix` | Discord bot, cron, 4G memory limit |
| Homepage | `homepage.nix` | Catppuccin Mocha, 5 categories, resource widgets |
| TaskChampion | `taskchampion.nix` | TLS via Caddy, 100 snapshots/14d |
| Minecraft | `minecraft.nix` | JDK 25, ZGC, LAN-only |

### Desktop

| Item | Details |
|------|---------|
| Niri compositor | Wayland, XWayland, OOMScoreAdjust=-900 |
| SDDM | SilentSDDM, Catppuccin Mocha |
| Ghostty | Primary terminal (promoted this week) |
| PipeWire | ALSA+Pulse+JACK, rtkit realtime |
| Catppuccin Mocha | Universal theme (GTK, icons, cursor, all apps) |
| Steam | Proton, gamemode, gamescope, mangohud |

### Session 115–116 Fixes (This Week)

- [x] Fix duplicate ghostty/swappy package declarations
- [x] Fix justfile bugs (4 recipes: port, syntax, filename, stale reference)
- [x] Delete stale artifacts (authelia secrets, ports.nix.bak, CHANGELOG.md)
- [x] Add Gatus memory/swap metric collection + Discord alerts
- [x] Fix `disk-monitor` `df --output` field (`pct` → `pcent`)
- [x] Increase journald `SystemMaxUse` 4G → 16G, retention 2wk → 1mo

---

## 4. B) Partially Done

| Item | Status | Gap |
|------|--------|-----|
| Darwin home-manager | ⚠️ 7 lines | No terminal, editor, theme parity with NixOS — 4h work, deprioritized |
| Ollama monitoring | ⚠️ Gatus check exists | `success=false` — service may be down or endpoint misconfigured |
| Voice agents | ⚠️ Module exists | Docker ROCm Whisper — enabled but unverified since last deploy |
| DNS failover | ⚠️ Module exists | Pi 3 not provisioned, only code complete |
| SigNoz alert routing | ⚠️ 7 rules exist | No per-severity routing (critical→Discord, warning→log) |
| Flake inputs audit | ⚠️ 47+ inputs | Some may be stale/unused — never audited |
| `/data` BTRFS subvolume | ⚠️ | Still toplevel (subvolid=5), cannot be snapshotted. `just snapshot-migrate-data` exists but not run |

---

## 5. C) Not Started

| Item | Effort | Impact |
|------|--------|--------|
| Deploy Dozzle (Docker log viewer) | 30min | Medium — replaces `docker logs -f` SSH workflow |
| Create `just status` command | 1h | Medium — automated status report generation |
| Wire Pi 3 as secondary DNS | 2h | Low — redundancy nice-to-have |
| Bring Darwin to parity | 4h | Low — if Darwin actively used |
| nix-colors integration | 6h | Low — 17+ hardcoded colors to migrate |
| External repo flake standardization | 4h | Medium — shared template for Go repos |
| Convert `path:` inputs to SSH URLs | 2h | Medium — reproducibility |
| Delete `/data/testfile` (4G orphan) | 1min | Low — trivial space recovery |
| Clean `/data/unsloth/venv` (24G) | 5min | Medium — pip install leak |

---

## 6. D) Totally Fucked Up

### 🔴 disk-monitor Was Silently Broken for 4+ Days

The `pct` → `pcent` typo meant disk-monitor was failing **every 5 minutes** with exit code 1 since at least May 29. When `/data` hit 100% on May 30, there was zero early warning. This directly caused the full cascade crash.

**Why it was missed:**
- The `onFailure` handler fired but `notify-failure@disk-monitor.service` uses desktop notifications — which nobody sees if not at the desktop
- No Gatus endpoint for disk-monitor health
- No external alerting (Discord/email) for service failures — only desktop notifications
- The service `Type=oneshot` exits after each run, so `systemctl is-active` shows `inactive` (not `failed`) between timer runs

### 🔴 Journal Rotation Destroyed Crash Forensics

The 4G journal limit was consumed by the ClickHouse/Redis/Forgejo error flood. The boot that actually crashed (June 3 ~02:43) has **no surviving journal**. We will never know what caused the final crash with certainty.

### 🔴 Monitor365 Failing Repeatedly

User service `monitor365.service` is crash-looping this boot. Not investigated yet.

### 🔴 `/data` at 93% — Headed for Another Crash

74G free on 1TB. At current growth rate (mostly AI models), another disk-full event is weeks away. No automated cleanup exists.

---

## 7. E) What We Should Improve

### Critical (Do Next)

1. **External alerting for infrastructure failures** — Desktop notifications are useless when you're not at the machine. disk-monitor, Gatus service failures, and critical service crashes should alert via Discord/email.
2. **Gatus health endpoint for disk-monitor** — Track whether the last disk check succeeded. If it fails N times, alert.
3. **Automated `/data` cleanup** — At minimum: auto GC Docker images, clean old model downloads, delete `/data/testfile`, clean `/data/unsloth/venv`. 32G recoverable in 5 minutes.
4. **`/data` BTRFS subvolume migration** — Still toplevel (subvolid=5), can't be snapshotted. `just snapshot-migrate-data` exists but never run.

### Important

5. **Journal rate limiting** — Even at 16G, a ClickHouse error flood can consume it. Add `RateLimitIntervalSec=30s` and `RateLimitBurst=1000` to journald config.
6. **SigNoz disk space alerting** — Should have caught `/data` filling before it hit 100%. Alert at 85% and 90%.
7. **Service health monitoring** — Monitor365 crash-looping unnoticed. Add all user services to Gatus or SigNoz checks.
8. **Ollama endpoint** — Gatus reports `success=false`. Investigate and fix.

### Nice to Have

9. **Flake inputs audit** — 47 inputs, likely some stale/unused. Reduces `nix flake update` time and attack surface.
10. **`/data/ai/cache` cleanup** (51G) — Likely contains stale HuggingFace downloads. Periodic cleanup.
11. **Dozzle deployment** — Docker log tailing via web UI, no SSH needed.
12. **Darwin parity** — Only matters if actively used.

---

## 8. F) Top 25 Things to Do Next

| # | Task | Priority | Effort | Impact |
|---|------|----------|--------|--------|
| 1 | **Deploy current fixes** (`just switch`) — disk-monitor + journald | P0 | 5min | Critical — disk alerts dead, journal too small |
| 2 | **Delete `/data/testfile`** (4G orphan from Apr 22) | P0 | 1min | Trivial space recovery |
| 3 | **Clean `/data/unsloth/venv`** (24G pip install leak) | P0 | 5min | 24G recovered |
| 4 | **Add external alerting for disk-monitor failure** (Discord webhook on N consecutive failures) | P0 | 30min | Prevents repeat of silent failure |
| 5 | **Add SigNoz/journald rate limiting** (`RateLimitIntervalSec`, `RateLimitBurst`) | P1 | 10min | Prevents journal consumption by error floods |
| 6 | **Add disk-space SigNoz alert rule** (85% and 90% thresholds) | P1 | 20min | Early warning before next disk-full |
| 7 | **Fix Ollama Gatus endpoint** (`success=false`) | P1 | 15min | Monitoring gap |
| 8 | **Investigate Monitor365 crash-loop** | P1 | 30min | User service broken since boot |
| 9 | **Investigate `/data` model deduplication** — 688G in models, possible duplicates across `/data/models` and `/data/llamacpp-models` and `/data/ai/models` | P1 | 1h | Could recover 50-100G+ |
| 10 | **Run `/data` BTRFS subvolume migration** (`just snapshot-migrate-data`) | P2 | 30min | Enables `/data` snapshots for disaster recovery |
| 11 | **Add Gatus endpoint for disk-monitor health** | P2 | 20min | Monitoring the monitor |
| 12 | **Deploy Dozzle** at `logs.home.lan` | P2 | 30min | Better Docker log debugging |
| 13 | **Hermes: configure secondary LLM provider** as GLM-5.1 fallback | P2 | 30min | Resilience |
| 14 | **Hermes: SSH deploy key for sandbox** (`origin` unreachable) | P2 | 15min | Unblock git operations |
| 15 | **Flake inputs audit** — remove stale/unused inputs from 47 total | P2 | 2h | Faster updates, smaller closure |
| 16 | **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) | P2 | 30min | Noise reduction |
| 17 | **Verify voice-agents service** — Docker ROCm Whisper | P2 | 30min | Unknown state |
| 18 | **Investigate swap exhaustion history** — was 13Gi/13Gi on May 30 | P2 | 1h | Root cause analysis |
| 19 | **Create `just status` command** for automated status generation | P3 | 1h | DX improvement |
| 20 | **Clean `/data/ai/cache`** (51G HuggingFace downloads) | P3 | 15min | Space recovery |
| 21 | **Add `nix-collect-garbage` automation** — weekly timer | P3 | 20min | Prevents nix store growth (83G) |
| 22 | **Provision Pi 3** for DNS failover cluster | P3 | 2h | DNS redundancy |
| 23 | **nix-colors integration** — migrate 17+ hardcoded colors | P3 | 6h | Theme consistency |
| 24 | **Bring Darwin home.nix to parity** with NixOS | P3 | 4h | Cross-platform consistency |
| 25 | **Investigate DNS blocker CA cert NSS import failure** | P3 | 15min | User service error on boot |

---

## 9. G) Unanswered Question

**What actually caused the June 3 ~02:43 crash?**

The journal was rotated away. All `last` sessions from that period end in `crash`. Possibilities:
- OOM kill (swap was 13Gi/13Gi on May 30, but that was 4 days earlier)
- BTRFS ENOSPC panic
- Kernel panic from AMD GPU driver (known `amdgpu.lockup_timeout=30000` workaround in cmdline)
- systemd watchdog timeout on a critical service

**Recommendation:** Next crash, check `/sys/fs/pstore/*` immediately — `pstore.backend=efi` is configured and may capture the panic message even without journal.
