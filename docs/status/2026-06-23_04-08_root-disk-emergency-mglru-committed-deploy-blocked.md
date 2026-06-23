# Session 145 — Root Disk Emergency, MGLRU Committed, Deploy Still Blocked

**Date:** 2026-06-23 04:08 CEST
**System:** NixOS unstable 26.11.20260614.9eac87a | Linux 7.0.12 | evo-x2 (AMD Ryzen AI Max+ 395, 128 GB unified)
**Uptime:** 16h52m
**Booted Generation:** `jfrcl3169…` (June 14 — **9 days old**, all OOM/MGLRU work NOT deployed)
**Session Scope:** MGLRU implementation, go-nix-helpers flake fix, comprehensive status + commit

---

## ⚡ WHAT CHANGED SINCE SESSION 144

| Item | Session 144 (03:25) | Session 145 (04:08) | Trend |
|------|---------------------|---------------------|-------|
| **Root disk free** | 13 GB (98%) | **5.8 GB (99%)** | 🔴 EMERGENCY — deploy now impossible |
| MGLRU `min_ttl_ms` | Researched only | **Committed** (`a5376242`) | ✅ Code done |
| go-nix-helpers flake fix | Uncommitted | **Committed** (`a8b95de8`) | ✅ |
| Working tree | 11 modified files | **Clean** | ✅ |
| Swap free | 68 MiB | 632 KiB | 🔴 Swap exhausted |
| Deployed? | No | **No** | 🔴 Unchanged |
| Failed services | 11 | 11 | 🔴 Unchanged |
| /data BTRFS corruption | 37 csum errors | 37 csum errors | — (same boot) |

---

## A) FULLY DONE ✅

### 1. MGLRU Thrashing Prevention — Committed (`a5376242`)

Implemented `mglru-thrash-protection.service` in `boot.nix` — a systemd oneshot that writes `1000` to `/sys/kernel/mm/lru_gen/min_ttl_ms` at boot. This protects the youngest page generation from eviction for 1 second under memory pressure, preventing the thrash spiral that starves journald and freezes the desktop.

**Why a systemd service, not a sysctl?** `min_ttl_ms` is sysfs-only (`/sys/kernel/mm/lru_gen/`), not accessible via `/proc/sys/`, so `boot.kernel.sysctl` cannot be used.

MGLRU is compiled into kernel 7.0.12 (`CONFIG_LRU_GEN=y`, `enabled=0x0007`) but `min_ttl_ms` defaults to `0` (disabled).

Documented in AGENTS.md gotchas table.

### 2. go-nix-helpers Flake Fix — Committed (`a8b95de8`)

Wired `go-nix-helpers` as a new flake input and added `follows` clauses to 6 Go repos: library-policy, crush-daily, mr-sync, BuildFlow, go-structure-linter, branching-flow. Also fixed statix warning in `snapshots.nix` (duplicate `systemd` attr blocks merged).

### 3. Session 144 Status Report — Committed (`381574c8`)

Full forensic analysis of the 2026-06-19 crash, 7-layer OOM defense architecture, MGLRU + DAMON research, and Top 25 prioritized actions.

### 4. All Pre-Existing Session Work (Sessions 143–144)

| Commit | Description | Status |
|--------|-------------|--------|
| `5b10e09c` | OOM hardening: user-slice limits, PSI metrics, early-warning alert | ✅ Committed |
| `f5ffd424` | AGENTS.md OOM hardening + build commands + gotchas | ✅ Committed |
| `d71e8561` | ssh-suspend-guard (prevent idle suspend during SSH) | ✅ Committed |
| `3f0f706d` | Disk recovery scripts, corruption assessment | ✅ Committed |
| `5e3a71ae` | Rust-cache partition, drop disk swap, build cleanup | ✅ Committed |

### 5. Build Validation — Passing

```
nix flake check --no-build  →  ✅ all checks passed
Pre-commit hooks: gitleaks ✅, statix ✅, deadnix ✅, alejandra ✅, nix flake check ✅
Working tree: CLEAN (0 modified, 0 untracked)
```

---

## B) PARTIALLY DONE ⚠️

### 1. OOM + MGLRU Hardening — Committed but NOT Deployed 🔴

**This remains the single most critical gap.** Four commits of OOM defense work exist in git but the running generation is 9 days old:

| Fix | Commit | Running? |
|-----|--------|----------|
| user-1000.slice MemoryHigh=56G / MemoryMax=64G | `5b10e09c` | ❌ `memory.max = max` |
| systemd-oomd thresholds (50%/20s, per-slice 50%) | `5b10e09c` | ❌ defaults (60%/30s, 80%) |
| niri-health-metrics MemoryMax=1G | `5b10e09c` | ❌ |
| PSI metrics collector + Gatus alert | `5b10e09c` | ❌ |
| MGLRU min_ttl_ms=1000 | `a5376242` | ❌ `min_ttl_ms = 0` |

**Blocker:** Root disk at 99% (5.8 GB free). `nix run .#deploy` requires building a new generation (~5-10 GB). **Deploy is physically impossible without prior cleanup.**

### 2. /data BTRFS Corruption — Assessed, Not Repaired

37 checksum failures this boot (23.5M total historical). Recovery scripts committed but actual repair not started. `/data` is 63% full (638 GB used).

---

## C) NOT STARTED ⏳

1. **Root disk cleanup** — `nix-collect-garbage -d`, Docker prune, clear caches. BLOCKING EVERYTHING.
2. **Deploy** — `nix run .#deploy` (blocked by disk space)
3. **DAMON_RECLAIM** — deliberately deferred per user decision
4. **Fix /data BTRFS corruption** — scrub or repartition
5. **Fix 11 failed services** — Docker cascade
6. **BIOS: AC Power Recovery → Power On** — manual
7. **Consolidate AI model directories** — 828 GB deduplication
8. **Docker log limits** — prevent unbounded growth
9. **SigNoz/ClickHouse TTL** — grows unbounded
10. **Reduce OLLAMA_GPU_OVERHEAD** — 8 GB → 4 GB

---

## D) TOTALLY FUCKED UP 💥

### 1. Root Disk at 99% — 5.8 GB Free and Dropping 🔴🔴🔴

This went from 13 GB free (Session 144, 40 minutes ago) to **5.8 GB free now**. Something is actively consuming disk. At this rate, the system will run out of space within the hour. This is the **third time disk space has blocked operations**. No automated cleanup exists.

**Immediate risk:** If the disk fills completely, journald stops writing, Docker containers crash, and nix operations fail — potentially causing another ungraceful shutdown.

### 2. Swap Exhausted — 632 KiB Free out of 9.4 GB

ZRAM swap is effectively full. While PSI pressure is currently zero (no active thrashing), there is zero swap headroom remaining. The first significant memory allocation event will hit the wall immediately with no buffer.

### 3. Docker Down — 6+ Services Cascaded

Docker failed to start, taking down Twenty CRM, Monitor365 (server + agent), manifest backup, twenty-db-backup, DiscordSync. Half the homelab is dark. Likely caused by /data corruption or disk space.

### 4. 9-Day-Old Booted Generation

The system is running configuration from June 14. All OOM hardening, MGLRU, PSI metrics, ssh-suspend-guard — none of it is active. The machine is identically vulnerable to the crash that killed it on June 19.

### 5. /data Has 23.5 Million Historical Checksum Failures

Active data corruption on `/data` (nvme0n1p8). Not yet assessed for data loss.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### The OOM Defense Architecture (Committed, Not Deployed)

```
Layer 0: MGLRU min_ttl_ms=1000       → COMMITTED, not deployed
Layer 1: DAMON_RECLAIM               → DEFERRED by user
Layer 2: user-1000.slice 56G/64G     → COMMITTED, not deployed
Layer 3: Per-service MemoryMax        → DEPLOYED (part of June 14 gen)
Layer 4: systemd-oomd (50%/20s)      → COMMITTED, not deployed
Layer 5: watchdogd (98%)              → DEPLOYED
Layer 6: sp5100-tco WDT (60s)         → DEPLOYED (hardware)
```

### Critical Improvements Needed

1. **Automated disk cleanup** — `nix.gc` + Docker prune timer. Stop the recurring disk-full crisis. This has now blocked operations 3+ times.
2. **Deploy the OOM hardening** — unblock with disk cleanup first. This is urgent.
3. **Root-cause the disk consumption** — 7 GB consumed in 40 minutes. What's writing?
4. **Fix Docker cascade** — root-cause the startup failure.
5. **Fix /data corruption** — scrub or repartition.

---

## F) TOP 25 THINGS TO DO NEXT

Sorted by impact × urgency:

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **FREE ROOT DISK NOW** — `nix-collect-garbage -d`, Docker prune, clear caches | 🔴 EMERGENCY | 10min | Ops |
| 2 | **Deploy OOM + MGLRU hardening** — `nix run .#deploy` | 🔴 Critical | 10min | Deploy |
| 3 | **Root-cause active disk consumption** — 7 GB in 40 min, what's writing? | 🔴 High | 15min | Investigate |
| 4 | **Fix Docker startup failure** — half the homelab is dark | 🔴 High | 30min | Bug |
| 5 | **Assess /data BTRFS corruption** — `btrfs scrub`, determine data loss | 🔴 High | 1-4h | Ops |
| 6 | **Add automated nix.gc** — prevent recurring disk-full | 🟡 High | 10min | Config |
| 7 | **BIOS: AC Power Recovery → Power On** — auto-recover after WDT | 🟡 High | Manual | Firmware |
| 8 | **Fix disk-growth-check service** — `/var/lib/disk-growth` missing | 🟡 Medium | 10min | Bug |
| 9 | **Fix btrfs-verify-snapshots** — failing at boot | 🟡 Medium | 10min | Bug |
| 10 | **Fix oauth2-proxy** — intermittent startup failure | 🟡 Medium | 30min | Bug |
| 11 | **Fix monitor365-server + agent** — exit-code failures | 🟡 Medium | 1h | Bug |
| 12 | **Fix dnsblockd-cert-import** — NSS cert import fails | 🟡 Medium | 15min | Bug |
| 13 | **Fix DiscordSync** — backup service down | 🟡 Medium | 30min | Bug |
| 14 | **Add Docker log limits** — `log-driver=json-file` with max-size | 🟡 Medium | 10min | Config |
| 15 | **Add disk space alerting** — Gatus endpoint for root + /data thresholds | 🟡 Medium | 20min | Config |
| 16 | **Consolidate AI model directories** — deduplicate 828 GB | 🟡 Medium | 2h | Ops |
| 17 | **Add SigNoz/ClickHouse TTL** — retention on all tables | 🔵 Low | 1h | Config |
| 18 | **Reduce OLLAMA_GPU_OVERHEAD** — 8 GB → 4 GB | 🔵 Low | 5min | Config |
| 19 | **Clean caches** — pip (6.3G), goimports (4G), etc. | 🔵 Low | 5min | Ops |
| 20 | **PSI Grafana dashboard** — visualize pressure trends | 🔵 Low | 30min | Monitoring |
| 21 | **Redis `vm.overcommit_memory=1`** — boot warning | 🔵 Low | 2min | Config |
| 22 | **Redis authentication** — no password set | 🔵 Low | 15min | Security |
| 23 | **Bluetooth `hci0: wmt func ctrl (-22)`** — every boot | 🔵 Low | 15min | Bug |
| 24 | **docs/status/ cleanup** — archive old status reports | 🔵 Low | 15min | Hygiene |
| 25 | **Enable DAMON_RECLAIM** — proactive cold-page reclaim (deferred) | 🔵 Low | 30min | Config |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**What is consuming 7 GB of root disk in 40 minutes?**

Between Session 144 (03:25, 13 GB free) and Session 145 (04:08, 5.8 GB free), ~7 GB disappeared from the root partition. This is not gradual accumulation — something is actively writing large amounts of data. Candidates:

1. **Container rebuild attempts** — Docker/services trying to write layers/logs despite failing to start
2. **nix build artifacts** — something triggering builds (scheduled tasks?)
3. **journald** — error spam from 11 failed services could be filling `/var/log/journal`
4. **BTRFS COW overhead** — the 37 checksum-failed reads could be triggering metadata writes

I cannot run `sudo btrfs filesystem du` or `sudo du` to investigate (sudo is blocked by Crush security policy). **Lars needs to run `sudo du -sh /var/lib/docker /nix/store /var/log/journal /tmp` to identify the consumer, or the disk will fill completely and the system may crash again.**

---

## System Health Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| RAM used | 46G / 93G (49%) | 🟢 Healthy |
| Swap (ZRAM) | 9.4G / 9.4G (100%) | 🔴 Exhausted |
| PSI some avg10 | 0.00% | 🟢 No pressure |
| Root disk | 495G / 512G (99%) | 🔴 EMERGENCY — 5.8 GB free |
| /data disk | 638G / 1.0T (63%) | 🟡 OK but corrupting |
| Failed services | 11 | 🔴 Docker cascade |
| BTRFS csum errors (this boot) | 37 | 🔴 Active corruption |
| Booted generation age | 9 days | 🔴 All fixes undeployed |
| Load average | 6.91, 11.03, 12.22 | 🟡 Moderate (18 users) |
| Working tree | Clean | ✅ |

---

## Git Status

### Committed This Session Chain (Sessions 143–145)

| Commit | Description |
|--------|-------------|
| `aa89f3ad` | chore: update flake.lock and format HTML docs |
| `381574c8` | docs(status): session 144 — OOM forensics, memory strategy |
| `a5376242` | **feat(oom): enable MGLRU thrashing prevention (min_ttl_ms=1000)** |
| `a8b95de8` | fix(flake): wire go-nix-helpers across Go dependency tree |
| `3f0f706d` | disk recovery: repartitioning scripts, corruption assessment |
| `5e3a71ae` | feat(evo-x2): rust-cache partition, drop disk swap, build cleanup |
| `5b10e09c` | **feat(oom): user-slice memory limits, PSI metrics, early-warning alert** |

### Working Tree

**CLEAN** — 0 modified files, 0 untracked files. All work committed.

### Build Validation

```
nix flake check --no-build  →  ✅ all checks passed
Pre-commit hooks            →  ✅ all passed (gitleaks, statix, deadnix, alejandra)
```
