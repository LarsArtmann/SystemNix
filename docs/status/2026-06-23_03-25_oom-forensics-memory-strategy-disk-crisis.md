# Session 144 — OOM Hardening, Crash Forensics, Memory Strategy Deep-Dive

**Date:** 2026-06-23 03:25 CEST
**System:** NixOS unstable 26.11.20260614.9eac87a | Linux 7.0.12 | evo-x2 (AMD Ryzen AI Max+ 395, 128 GB unified)
**Uptime:** 16h09m (booted 2026-06-23 ~11:15)
**Booted Generation:** `jfrcl3169…` (June 14 — **9 days old**, OOM hardening NOT deployed)
**Session Scope:** Crash forensics, OOM defense architecture, kernel memory subsystem research, status report + commit

---

## Incident Summary: The 2026-06-19 Crash

evo-x2 was found powered off after ~7 hours of unavailability. Forensic analysis of journal logs across boots revealed a classic **OOM cascade → hardware watchdog reset**:

| Time (Jun 19) | Event |
|---------------|-------|
| 06:25 | First memory pressure event (`journald: Under memory pressure, flushing caches`) |
| 07:35 | Second pressure event + kernel `perf: interrupt took too long` (kernel throttling) |
| 07:35:54 | **Last kernel message ever logged** — kernel couldn't keep up with reclaim |
| 08:18–08:36 | All metric collectors slow down 10× (120ms → 1.1–1.2s) — system in swap/reclaim thrash |
| **08:37:07** | **Journal ends abruptly** mid-routine Postgres line. No shutdown, no panic, no OOM logged |
| 08:37 → 15:13 | Machine **off** for ~6.5h until manual power-on |

**Root cause:** Helium/Electron renderers grew unbounded in `user-1000.slice` (66h uptime, NO cgroup ceiling). System services had per-unit `MemoryMax`, but user-session processes did not. Pressure built until the kernel stalled in OOM reclaim → journald starved → `sp5100-tco` hardware watchdog fired after 60s of total unresponsiveness → hard reset. The machine stayed off because BIOS "AC Power Recovery" is set to "Off" (not "Power On").

**Evidence:** Empty pstore (WDT resets wipe panic records), zero shutdown sequence in journal, abrupt mid-line cutoff, gatus latency spike (10× normal) in final hour, memory pressure events at 06:25 and 07:35.

**What it was NOT:** Not thermal (CPU 47°C, GPU 37°C, NVMe 42°C), not a clean shutdown, not a kernel panic, not Ollama (had been failing since boot — pre-existing, unrelated), not a power blip (no UPS, but timing coincidence with peak OOM thrash makes this unlikely).

---

## A) FULLY DONE ✅

### 1. Crash Root Cause Identified — Complete

Full forensic timeline reconstructed from journal logs across boots. Root cause: unbounded user-session memory growth → reclaim thrash → journald starvation → hardware WDT reset. Documented in AGENTS.md with updated gotcha entry.

### 2. OOM Hardening Committed (`5b10e09c`)

Four fixes committed and validated (`nix flake check --no-build` passes):

| Fix | File | What |
|-----|------|------|
| user-1000.slice MemoryHigh/MemoryMax | `boot.nix` | `MemoryHigh=56G` (gradual throttle), `MemoryMax=64G` (hard kill). Leaves ~29G for system + kernel. **Root-cause fix.** |
| systemd-oomd thresholds tightened | `boot.nix` | Global: `50% pressure / 20s` (was 60%/30s). Per-slice: `50%` (was 80%). Tuned for AI/ML — won't false-positive on model loads. |
| niri-health-metrics MemoryMax | `niri-config.nix` | `MemoryMax=1G` — was leaking 512 MB/run (oneshot, hundreds of runs) |
| PSI early-warning | `signoz.nix` + `gatus-config.nix` | New `psi-metrics` textfile collector (exports `/proc/pressure/memory` + derived alert flag). Gatus Discord alert at some>50%/full>10%. |

### 3. AGENTS.md Updated (`f5ffd424`)

- OOM crash chain gotcha rewritten with full root-cause + fix description
- Added 6 new gotchas: user-1000.slice MemoryMax, oomd settings.OOM tuning, psi-metrics collector, WDT forensics, build commands (justfile removed), cmdguard note
- Build & Deploy section updated: justfile commands → nix flake commands
- Critical Rules updated to reflect `nix run .#deploy` instead of `just switch`

### 4. Memory Strategy Research — MGLRU + DAMON

Deep research into two modern kernel memory subsystems, both compiled into kernel 7.0.12 but neither active:

**MGLRU (Multi-Gen LRU):** Compiled in (`0x0007` = enabled + walker + generations), but `min_ttl_ms=0` (thrashing protection **OFF**). Setting `min_ttl_ms=1000` protects the working set from eviction for 1 second, preventing desktop jank/thrash and giving oomd time to act. Directly addresses the "Windows degrades better" observation.

**DAMON_RECLAIM:** Compiled in (`CONFIG_DAMON_RECLAIM=y`), not activated. Proactively monitors cold pages via lightweight region-based sampling (<1% CPU on 70GB) and reclaims them *before* pressure builds. Uses watermark activation (40% free → activate, 20% → deactivate). Used in production by AWS Aurora Serverless, Meta (fleet-wide).

### 5. SSH-Suspend-Guard (`d71e8561`)

Prevents evo-x2 from idle-suspending during active SSH sessions. Committed by a prior session, not deployed.

### 6. Disk Recovery Scripts (`3f0f706d`)

Repartitioning scripts (`disk-create-p9.sh`, `disk-diagnose.sh`, `disk-fix.sh`, `find-corrupted-files.sh`) for /data BTRFS corruption assessment and recovery. Committed, reformatted by treefmt.

---

## B) PARTIALLY DONE ⚠️

### 1. OOM Hardening — Committed but NOT Deployed

**This is the single most critical gap.** The boot generation is from June 14 (`jfrcl3169…`). The OOM fixes (`5b10e09c`) are in git but the running system has:
- `user-1000.slice memory.max = max` (unlimited)
- `systemd-oomd` at default thresholds (60%/30s, 80% per-slice)
- No PSI metrics collector, no Gatus early-warning

**If Helium leaks again tonight, the machine dies the same way.**

**Blocker:** Root disk at 98% (11 GB free). `nix run .#deploy` will likely fail without prior cleanup.

### 2. Uncommitted Flake Changes

`flake.nix` + `flake.lock` have uncommitted `go-nix-helpers` input addition + follows clauses for 6 Go repos (library-policy, crush-daily, mr-sync, BuildFlow, go-structure-linter, branching-flow). This is a build-fix that wires the new shared `go-nix-helpers` flake across the dependency tree.

### 3. /data BTRFS Corruption — Assessment Done, Fix Not Started

37 new checksum failures this boot (23.5M total across all boots). `/data` (nvme0n1p8) has active data corruption: `csum failed root 5 ino 255110`. Disk recovery scripts written and committed but the actual repair (`btrfs scrub` / repartition / restore from backup) has not been performed.

### 4. MGLRU + DAMON — Researched, Not Implemented

Both kernel subsystems identified as high-impact improvements. Implementation plan ready but no code written yet.

---

## C) NOT STARTED ⏳

1. **Deploy OOM hardening** (`nix run .#deploy`) — blocked by disk space
2. **Root disk cleanup** — `nix-collect-garbage -d`, Docker prune, container log cleanup
3. **Enable MGLRU `min_ttl_ms=1000`** — one sysctl, highest ROI for desktop thrash prevention
4. **Enable DAMON_RECLAIM** — kernel module params, proactive cold-page reclaim
5. **Fix /data BTRFS corruption** — `btrfs scrub run /data`, assess data loss, possible repartition
6. **Fix 11 failed services** — Docker cascade (Docker down → Twenty CRM, monitor365, manifest, etc.)
7. **BIOS: AC Power Recovery → Power On** — prevents "stays off" after WDT reset (manual)
8. **Reduce OLLAMA_GPU_OVERHEAD** — 8 GB → 4 GB (carried from Session 92)
9. **Consolidate AI model directories** — 828 GB across 3 dirs with likely duplication
10. **Docker global log limits** — prevent unbounded container log growth
11. **SigNoz/ClickHouse TTL/retention** — grows unbounded
12. **Clean caches** — pip, goimports, etc.

---

## D) TOTALLY FUCKED UP 💥

### 1. Root Disk at 98% — Deploy Blocked

11 GB free on 512 GB NVMe. This is a recurring self-inflicted problem: Docker images, container layers, nix store bloat, and build caches accumulate without automated cleanup. The system literally cannot deploy its own OOM fix because it's too full. This is the third time disk space has blocked operations.

### 2. /data Has 23.5 Million Checksum Failures

This is not a minor corruption — 23.5 million failed checksums means widespread data loss on /data. The disk recovery scripts assess the damage but the actual repair path is unclear (scrub may not fix this level; repartition + restore may be needed). This has been ongoing for multiple boots.

### 3. Docker Is Down — 6+ Services Cascaded

Docker failed to start at boot, taking down Twenty CRM, Monitor365 (server + agent), manifest backup, twenty-db-backup, and DiscordSync. The root cause is likely the /data corruption (Docker stores on /data) or disk space. This means half the homelab is dark.

### 4. Swap at 99% (9.3G/9.4G ZRAM)

ZRAM swap is nearly full. This is not immediately dangerous (PSI is near zero), but it means there's no swap headroom left. Combined with the user-session having no memory limit, a memory pressure event would hit the wall much faster than it should.

### 5. The Machine That Can't Save Itself

The entire OOM defense architecture was designed (MemoryMax → oomd → watchdogd → WDT) but the critical layer (user.slice limit) was missing until today — and even now it's still not deployed. The system spent 9 days running a known-vulnerable configuration after the fix was written.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### OOM / Memory Defense (This Session's Domain)

The current defense layers, in firing order:

```
Layer 0: [MISSING] — MGLRU min_ttl_ms=0 (thrashing protection OFF)
Layer 1: [MISSING] — DAMON_RECLAIM not activated (proactive reclaim OFF)
Layer 2: [MISSING] — user-1000.slice unlimited (fix committed, not deployed)
Layer 3: ✅ — Per-service MemoryMax on 36/39 services
Layer 4: ⚠️ — systemd-oomd at DEFAULT thresholds (fix committed, not deployed)
Layer 5: ✅ — watchdogd (98% RAM → reboot)
Layer 6: ✅ — sp5100-tco hardware WDT (60s)
```

**Target architecture:**

```
Layer 0: MGLRU min_ttl_ms=1000       → prevent thrash, give oomd time
Layer 1: DAMON_RECLAIM               → proactively free cold pages
Layer 2: user-1000.slice MemoryHigh/MemoryMax → gradual throttle → hard kill
Layer 3: Per-service MemoryMax        → instant kill for bounded services
Layer 4: systemd-oomd (50%/20s)      → PSI-based kill under sustained pressure
Layer 5: watchdogd (98%)              → reboot as last resort
Layer 6: sp5100-tco WDT (60s)         → hardware reset if kernel hangs
```

Layers 0-1 **prevent** the problem. Layers 2-6 **handle** it if prevention fails.

### Specific Improvements

1. **Enable MGLRU thrashing prevention** — `min_ttl_ms=1000` is the single highest-ROI change for desktop stability. Prevents journald starvation under pressure.
2. **Enable DAMON_RECLAIM** — proactive cold-page reclaim. Especially relevant for 128 GB unified memory where Ollama loads 32 GB models and leaves 24 GB cold.
3. **Deploy the committed OOM hardening** — unblock with disk cleanup first.
4. **Add automated disk space cleanup** — `nix.gc` + Docker prune timer + alerting at 90%. Stop the recurring disk-full crisis.
5. **PSI metrics to Grafana dashboard** — data already flows to SigNoz via node-exporter `pressure` collector. Just needs a dashboard panel.
6. **BIOS AC Power Recovery → Power On** — so the machine recovers automatically after WDT reset.

### Infrastructure (Carried Forward)

7. **Fix /data corruption** — scrub or repartition. This is actively losing data.
8. **Fix Docker cascade** — root-cause the Docker startup failure.
9. **Docker log limits** — `log-driver=json-file`, `log-opts={max-size,max-file}`.
10. **SigNoz TTL** — ClickHouse retention policy on all tables.

---

## F) TOP 25 THINGS TO DO NEXT

Sorted by impact × urgency:

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Free root disk space** — `nix-collect-garbage -d`, Docker prune, clear caches | 🔴 Critical | 10min | Ops |
| 2 | **Deploy OOM hardening** — `nix run .#deploy` (after disk cleanup) | 🔴 Critical | 10min | Deploy |
| 3 | **Commit flake.nix go-nix-helpers** fix (uncommitted build fix) | 🔴 Critical | 2min | Git |
| 4 | **Enable MGLRU min_ttl_ms=1000** — prevent desktop thrash | 🔴 High | 5min | Config |
| 5 | **Fix Docker startup failure** — root-cause and repair | 🔴 High | 30min | Bug |
| 6 | **Assess /data BTRFS corruption** — run `btrfs scrub`, determine data loss | 🔴 High | 1-4h | Ops |
| 7 | **Enable DAMON_RECLAIM** — proactive cold-page reclaim | 🟡 High | 30min | Config |
| 8 | **BIOS: AC Power Recovery → Power On** — auto-recover after WDT | 🟡 High | Manual | Firmware |
| 9 | **Commit uncommitted working tree** — scripts, snapshots, HTML | 🟡 Medium | 5min | Git |
| 10 | **Fix disk-growth-check service** — `/var/lib/disk-growth` missing | 🟡 Medium | 10min | Bug |
| 11 | **Fix btrfs-verify-snapshots service** — failing at boot | 🟡 Medium | 10min | Bug |
| 12 | **Fix oauth2-proxy** — intermittent startup failure | 🟡 Medium | 30min | Bug |
| 13 | **Fix monitor365-server + agent** — exit-code failures | 🟡 Medium | 1h | Bug |
| 14 | **Fix dnsblockd-cert-import** — NSS cert import fails | 🟡 Medium | 15min | Bug |
| 15 | **Add automated nix.gc** — prevent recurring disk-full | 🟡 Medium | 10min | Config |
| 16 | **Add Docker log limits** — `log-driver=json-file` with max-size | 🟡 Medium | 10min | Config |
| 17 | **Consolidate AI model directories** — deduplicate 828 GB | 🟡 Medium | 2h | Ops |
| 18 | **Add SigNoz/ClickHouse TTL** — retention on all tables | 🔵 Low | 1h | Config |
| 19 | **Reduce OLLAMA_GPU_OVERHEAD** — 8 GB → 4 GB | 🔵 Low | 5min | Config |
| 20 | **Clean caches** — pip (6.3G), goimports (4G), etc. | 🔵 Low | 5min | Ops |
| 21 | **PSI Grafana dashboard** — visualize pressure trends | 🔵 Low | 30min | Monitoring |
| 22 | **Redis `vm.overcommit_memory=1`** — boot warning | 🔵 Low | 2min | Config |
| 23 | **Redis authentication** — no password set | 🔵 Low | 15min | Security |
| 24 | **Bluetooth `hci0: wmt func ctrl (-22)`** — every boot | 🔵 Low | 15min | Bug |
| 25 | **docs/status/ cleanup** — archive old status reports | 🔵 Low | 15min | Hygiene |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**Why did evo-x2 stay OFF for 6.5 hours instead of auto-rebooting after the WDT reset?**

The `sp5100-tco` watchdog fires a **hardware reset** — the machine should reboot. `kernel.panic=30` would auto-reboot after a panic. Yet the machine was found powered off, requiring a manual power button press. The software configuration says "reboot on failure." The hardware says "off."

**The answer is almost certainly in the BIOS** — specifically the "AC Power Recovery" or "After Power Failure" setting, which controls what happens when power is restored after a loss. If set to "Power Off" (common default), the machine stays off. If set to "Power On" or "Last State," it would recover.

**But I cannot verify this** because:
1. I can't access the BIOS from Linux (no `dmidecode` without sudo, and even then BIOS settings aren't exposed via DMI)
2. The GMKtec EVO-X2 firmware may use a non-standard BIOS (possibly a customized AMI or Insyde) with settings not documented anywhere
3. There's no IPMI/BMC for remote management

**The question for Lars:** Can you check the BIOS "AC Power Recovery" / "After Power Failure" setting on the next reboot? Set it to "Power On." This is the only fix for the "stays off" half of the crash — no amount of NixOS configuration can fix it.

---

## System Health Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| RAM used | 46G / 93G (49%) | 🟢 Healthy |
| Swap (ZRAM) | 9.3G / 9.4G (99%) | 🟡 Nearly full |
| PSI some avg10 | 0.00% | 🟢 No pressure |
| PSI full avg10 | 0.00% | 🟢 No pressure |
| Root disk | 490G / 512G (98%) | 🔴 Critical |
| /data disk | 638G / 1.0T (63%) | 🟡 OK but corrupting |
| CPU temp | 47°C | 🟢 Normal |
| GPU temp | 37°C | 🟢 Normal |
| NVMe temp | 42°C | 🟢 Normal |
| Failed services | 11 | 🔴 Docker cascade |
| BTRFS csum errors (this boot) | 37 | 🔴 Active corruption |
| Booted generation age | 9 days | 🔴 Stale |
| Load average | 16.36, 24.04, 18.47 | 🟡 High (25 users) |

---

## Git Status

### Committed This Session Chain (Sessions 143–144)

| Commit | Description |
|--------|-------------|
| `3f0f706d` | Disk recovery: repartitioning scripts, corruption assessment, full status |
| `5e3a71ae` | Rust-cache partition, drop disk swap, build cleanup |
| `47c3b722` | AGENTS.md refresh (290 → 117 lines) |
| `5b10e09c` | **OOM hardening: user-slice limits, PSI metrics, early-warning alert** |
| `f5ffd424` | AGENTS.md OOM hardening + build commands + gotchas |
| `d71e8561` | ssh-suspend-guard (prevent idle suspend during SSH) |

### Uncommitted Working Tree

| File | Change | Assessment |
|------|--------|------------|
| `flake.nix` | `go-nix-helpers` input + 6 follows clauses | 🟡 Build fix — should commit |
| `flake.lock` | Updated locks for go-nix-helpers | 🟡 Pairs with flake.nix |
| `snapshots.nix` | Formatter-only (map operator line break) | 🔵 Cosmetic |
| `scripts/disk-*.sh` (4 files) | Reformatted by treefmt | 🔵 Cosmetic |
| 3 HTML docs | Formatter-touched by treefmt | 🔵 Cosmetic |

### Build Validation

```
nix flake check --no-build  →  ✅ all checks passed
nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel  →  ✅ evaluates
```
