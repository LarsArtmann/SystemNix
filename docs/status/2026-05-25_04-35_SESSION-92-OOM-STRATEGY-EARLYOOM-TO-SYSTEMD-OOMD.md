# Session 92: OOM Strategy Deep-Dive — earlyoom → systemd-oomd Migration Complete

**Date:** 2026-05-25 04:34 CEST
**Scope:** Full OOM strategy research, earlyoom removal, systemd-oomd setup, service memory limit audit, nvtop 176 GiB mystery explained
**System:** NixOS unstable 26.05.20260523.3d8f0f3 (Yarara) | Linux 7.0.9 | niri-unstable
**Uptime:** Not checked (research-focused session, no system interaction)
**Total Commits:** ~2605

---

## Executive Summary

This session performed **deep research** into why OOM protection on evo-x2 has been unreliable, produced a comprehensive analysis document, and verified that the systemd-oomd migration (already committed in `059765b6`) is correct and builds cleanly.

Key findings:
1. **earlyoom was slow to respond on this system** — its AND-logic swap threshold (`freeSwapThreshold = 10`) combined with `swappiness = 1` meant the system had to be in extreme distress before earlyoom would fire. With `swappiness = 1`, the kernel delays swapping aggressively, so swap stays ~90% free under normal pressure. Only when memory is critically exhausted does the kernel begin swapping to ZRAM (12.8 GB pool fills fast), at which point earlyoom would eventually trigger — but by then the system is already thrashing and may kill the wrong process (source: `lowmem_sig()` in earlyoom `main.c` uses `&&` for both conditions)
2. **earlyoom is blind to GPU allocations** — GTT-mapped memory consumed by Ollama/hermes via ROCm is invisible to `/proc/meminfo` MemAvailable
3. **systemd-oomd's PSI approach** measures process stalling (the *symptom*) rather than free RAM (the *cause*), making it work on unified memory systems regardless of GTT
4. **nvtop 176 GiB** is VRAM + GTT double-counting — cosmetic, not misconfiguration
5. **3 services had no MemoryMax** — pocket-id, monitor365-agent, monitor365-server — now fixed

---

## System Health Snapshot

| Metric | Session 91 | Session 92 | Notes |
|--------|-----------|-----------|-------|
| OOM defense | earlyoom (slow response) + MemoryMax | systemd-oomd + MemoryMax | ✅ Improved |
| Services w/o MemoryMax | 3 long-running | 0 | ✅ Fixed |
| Build status | Passing | Passing | ✅ Clean |
| Root disk | 53% (235 GB free) | Not re-checked | — |
| /data disk | 89% (118 GB free) | Not re-checked | — |

---

## A) FULLY DONE ✅

### 1. OOM Strategy Deep-Dive Research — Complete

Wrote comprehensive analysis: `docs/status/2026-05-25_OOM-STRATEGY-DEEP-DIVE.md` covering:

- **Why kernel OOM killer is inadequate**: 2–15s latency, heuristics wrong for AI workloads, no rate-of-change awareness
- **Why earlyoom was suboptimal on this system**: AND-logic (`lowmem_sig()` uses `&&`) means both MemAvailable AND SwapFree must be below threshold; with `swappiness = 1`, swap fills late under extreme pressure, delaying earlyoom's response until the system is already thrashing; additionally blind to GTT allocations
- **Why unified memory makes everything harder**: GTT allocations invisible to MemAvailable, TTM page pool shows as reclaimable
- **nvtop 176 GiB explained**: VRAM + GTT heap double-counting on APUs — cosmetic, not a problem
- **Recommended multi-layer defense**: MemoryMax → systemd-oomd → watchdogd

### 2. Verified systemd-oomd Migration (commit 059765b6)

The migration was already committed by a prior session. This session independently arrived at the same changes and confirmed correctness:

| Change | File | Status |
|--------|------|--------|
| Remove earlyoom | `boot.nix` | ✅ Already committed |
| Enable systemd-oomd (3 slices) | `boot.nix` | ✅ Already committed |
| Add MemoryMax to pocket-id (512M) | `pocket-id.nix` | ✅ Already committed |
| Add MemoryMax to monitor365-agent (256M) | `monitor365.nix` | ✅ Already committed |
| Add MemoryMax to monitor365-server (256M) | `monitor365.nix` | ✅ Already committed |
| Update OOM crash chain gotcha in AGENTS.md | `AGENTS.md` | ✅ Changed this session |
| Update `vm.panic_on_oom` comment | `boot.nix` | ✅ Already committed |

### 3. Full Service Memory Limit Audit — Complete

Audited all 39 systemd services across 36 service modules:

| Status | Count | Services |
|--------|-------|----------|
| Has MemoryMax via `harden {}` | 33 | All hardened services |
| Had NO MemoryMax → NOW FIXED | 3 | pocket-id, monitor365-agent, monitor365-server |
| No MemoryMax — acceptable (oneshot) | 3 | signoz-provision, forgejo-generate-token, immich-db-backup |

**Memory budget analysis** (top consumers):

| Service | MemoryMax | % of 128 GB |
|---------|-----------|-------------|
| ollama | 32 GB | 25% |
| hermes | 24 GB | 19% |
| whisper-asr | 8 GB | 6% |
| clickhouse | 4 GB | 3% |
| immich-ml | 4 GB | 3% |
| minecraft | 4 GB | 3% |
| Everything else | ≤ 2 GB each | <2% each |
| **Total if all at max** | **~80 GB** | **63%** |

### 4. Build Validation — Passed ✅

`just test-fast` passes with all changes. `nix fmt` — 0 files changed.

---

## B) PARTIALLY DONE ⚠️

### 1. systemd-oomd Deployed but Not Verified Live

Changes are committed and build passes, but `just switch` has not been run. Need to verify:
- `systemctl status systemd-oomd` — should show active
- `cat /sys/fs/cgroup/-.slice/memory.pressure_level` or PSI files — should be readable
- `systemd-analyze cat-config systemd/oomd.conf.d/` — NixOS should have generated drop-in with slice monitoring

### 2. OOM Strategy Document Written but Recommendations Not Fully Implemented

`docs/status/2026-05-25_OOM-STRATEGY-DEEP-DIVE.md` recommends 6 changes. 5/6 are done. Remaining:
- Reduce `OLLAMA_GPU_OVERHEAD` from 8 GB → 4 GB (optional optimization, not critical)

---

## C) NOT STARTED ⏳

Carried from session 91 (unchanged):

1. **BTRFS /data snapshot migration** — `just snapshot-migrate-data` never run
2. **/data AI model consolidation** — 828 GB across 3 directories, likely duplicated
3. **SigNoz/ClickHouse TTL/retention** — grows unbounded
4. **Redis `vm.overcommit_memory = 1`** — Warning on every boot
5. **monitor365-server user service failing** — exit-code failures
6. **activitywatch-watcher service failing** — exit-code failures
7. **dnsblockd-cert-import user service failing** — NSS cert import fails
8. **oauth2-proxy intermittent startup failure** — exit-code
9. **Bluetooth `hci0: Failed to send wmt func ctrl (-22)`** — Every boot
10. **IPv6 tempaddr errors on Docker veths** — write fails
11. **Firmware 33s optimization** — BIOS investigation needed
12. **SigNoz container DNS timing** — psql "db" host resolution on first start
13. **docs/status/ cleanup** — 125+ status reports, should archive old ones
14. **Pi 3 DNS provisioning** — config exists, hardware not provisioned
15. **Redis authentication** — no password set
16. **Docker global log limits** — no log-driver/log-opts configured
17. **Twenty CRM container logs** — no max-size/max-file limits
18. **fstrim redundancy** — /data already has `discard=async`
19. **Boot time monitoring/alerting** — no automated check
20. **Disk space alerting** — no Gatus endpoint for disk thresholds
21. **Service target assertion** — no NixOS assertion preventing Docker + graphical.target
22. **Auto-gate Caddy vHosts** — still manual `optionalAttrs` per service
23. **Auto-gate Gatus endpoints** — still manual `lib.optionals` per service
24. **Deploy BFQ scheduler** — committed but `just switch` not run
25. **Clean caches** — `~/.cache/pip` (6.3G), goimports (4G), etc.

---

## D) TOTALLY FUCKED UP 💥

### 1. earlyoom Was Running for Months With Delayed Response

earlyoom has been enabled since initial system setup, with `freeSwapThreshold = 10` and `vm.swappiness = 1` + ZRAM at 12.8 GB. The `lowmem_sig()` function in earlyoom's `main.c` requires **both** `MemAvailablePercent <= mem_term_percent && SwapFreePercent <= swap_term_percent` to trigger (confirmed from source code).

With `swappiness = 1`, the kernel aggressively avoids swapping. Under normal-to-moderate memory pressure, swap stays ~90% free, so the AND condition is not met. Only under **extreme** pressure does the kernel begin swapping to ZRAM — and ZRAM's small 12.8 GB pool fills quickly. At that point earlyoom WOULD trigger, but the system is already thrashing.

**Correction:** My initial claim that "earlyoom was effectively disabled" was an oversimplification. earlyoom was not completely inert — it would eventually fire in a true crisis. The real problems were: (1) it fires too late, after the system is already thrashing, (2) it is blind to GPU/GTT allocations which can consume 60+ GB invisibly, and (3) its process selection (`--prefer` regex list) was a static allowlist that didn't cover all AI-related process names.

The OOM crash chain from session 89 (Helium spawned 42 processes, killed journald) may or may not have been preventable by earlyoom — the sequence was rapid enough that earlyoom's 10 Hz polling may not have caught it in time regardless.

### 2. No Unified Memory Awareness in Any Tool

The fundamental problem: **no userspace OOM tool understands AMD Strix Halo's unified memory architecture**. GPU allocations via GTT consume physical RAM but don't appear in `/proc/meminfo` MemAvailable. earlyoom sees "plenty of free RAM" while the GPU has actually eaten 60+ GB. systemd-oomd's PSI approach is the best available mitigation — it detects the *effect* (processes stalling) regardless of the *cause* (RAM invisible to MemAvailable). But even PSI can't prevent the initial allocation burst.

### 3. 828 GB of AI Models With No Deduplication

Three separate model directories exist with likely heavy duplication. No audit has been done. `/data` at 89% will hit 100%.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### OOM / Memory (This Session's Domain)

1. **Verify systemd-oomd is working after deploy** — `systemctl status systemd-oomd`, check PSI files, test with stress
2. **Consider reducing OLLAMA_GPU_OVERHEAD** — 8 GB reserve is generous; 4 GB would free headroom
3. **Add `--sort-by-rss` to earlyoom** — NOT APPLICABLE (removed). systemd-oomd uses PSI, not RSS.
4. **Monitor PSI metrics** — Expose `/proc/pressure/memory` via node-exporter for Grafana dashboards

### Infrastructure (Carried Forward)

5. **Deploy BFQ scheduler** — `just switch` activates both BFQ and systemd-oomd in one shot
6. **Consolidate AI model directories** — Deduplicate `/data/models`, `/data/llamacpp-models`, `/data/ai`
7. **Add Docker global log limits** — Prevent unbounded container log growth
8. **Add SigNoz/ClickHouse retention policy** — TTL on all tables
9. **Add disk space alerting** — Gatus endpoint for root and /data usage

### Code Quality

10. **Service target convention assertion** — NixOS module assertion preventing Docker + graphical.target
11. **Auto-gate Caddy vHosts** — Behind service enable flags
12. **Auto-gate Gatus endpoints** — Behind service enable flags

---

## F) TOP 25 THINGS TO DO NEXT

Sorted by impact × effort (highest first):

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Deploy all pending changes** (`just switch`) — activates BFQ + systemd-oomd | 🔴 Critical | 5min | Deploy |
| 2 | **Verify systemd-oomd is working** — check PSI files, test with stress | 🔴 Critical | 15min | Verify |
| 3 | **Consolidate AI model directories** — deduplicate 828 GB across 3 dirs | 🔴 Critical | 2h | Ops |
| 4 | **Add Docker global log limits** — prevent unbounded container log growth | 🔴 Critical | 15min | Config |
| 5 | **Add SigNoz/ClickHouse retention policy** — TTL on all tables | 🟡 High | 1h | Config |
| 6 | **Clean caches** — `~/.cache/pip` (6.3G), goimports (4G), etc. | 🟡 High | 5min | Ops |
| 7 | **Fix monitor365-server** user service failures | 🟡 High | 1h | Bug |
| 8 | **Fix activitywatch-watcher** service failure | 🟡 High | 30min | Bug |
| 9 | **Fix oauth2-proxy** intermittent startup failure | 🟡 High | 1h | Bug |
| 10 | **Set `vm.overcommit_memory = 1`** for Redis | 🟡 High | 5min | Config |
| 11 | **Run /data BTRFS migration** (`just snapshot-migrate-data`) | 🟡 Medium | 1h | Ops |
| 12 | **Add disk space alerting** to Gatus | 🟡 Medium | 30min | Monitoring |
| 13 | **Add PSI/IO pressure metrics** via node-exporter textfile | 🟡 Medium | 30min | Monitoring |
| 14 | **Add boot time tracking** (systemd-analyze in timer) | 🟡 Medium | 30min | Monitoring |
| 15 | **Fix dnsblockd-cert-import** user service failure | 🟡 Medium | 30min | Bug |
| 16 | **Archive old status reports** (125+ files → keep last 10) | 🟢 Low | 15min | Housekeeping |
| 17 | **Enforce service target convention** via NixOS assertion | 🟢 Low | 30min | Code quality |
| 18 | **Auto-gate Caddy vHosts** behind service enable flags | 🟢 Low | 2h | Refactor |
| 19 | **Auto-gate Gatus endpoints** behind service enable flags | 🟢 Low | 1h | Refactor |
| 20 | **Fix IPv6 tempaddr errors** on Docker veths | 🟢 Low | 30min | Config |
| 21 | **Investigate firmware 33s** — check BIOS fast boot options | 🟢 Low | 15min | Perf |
| 22 | **Redis authentication** — set a password | 🟢 Low | 15min | Security |
| 23 | **fstrim redundancy** — remove fstrim for /data (already has `discard=async`) | 🟢 Low | 5min | Config |
| 24 | **Pi 3 DNS hardware provisioning** | 🟢 Low | 4h+ | Infra |
| 25 | **Bluetooth hci0 wmt error** — investigate RTL driver issue | 🟢 Low | 2h | Bug |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Is the combined MemoryMax budget of ~80 GB (63% of RAM) sustainable?**

Ollama (32 GB) + hermes (24 GB) alone = 56 GB. If both run at peak, that's 44% of total RAM. With OLLAMA_GPU_OVERHEAD at 8 GB and vm.min_free_kbytes at 2 GB, the system has:
- 128 GB total
- −2 GB kernel reserve
- −8 GB GPU overhead
- −56 GB peak AI usage
- = **62 GB for everything else** (desktop, services, OS)

This is tight but workable. But if a third heavy service starts (e.g., ComfyUI at 0.50 GPU fraction, or a second Ollama model via `OLLAMA_NUM_PARALLEL=2`), the math breaks. The question is: **should OLLAMA_MAX_LOADED_MODELS stay at 1, or do you need parallel model loading?** If parallel, the MemoryMax budget needs rebalancing.

---

## Session Timeline

| Time | Action |
|------|--------|
| 04:00 | User asks why earlyoom is hard to configure |
| 04:05 | Deep research: kernel OOM killer, earlyoom, systemd-oomd, unified memory |
| 04:15 | Full service memory limit audit (39 services) |
| 04:20 | nvtop 176 GiB mystery solved (VRAM + GTT double-counting) |
| 04:25 | User asks: can we replace earlyoom with systemd-oomd? |
| 04:30 | User confirms: remove earlyoom, setup systemd-oomd |
| 04:32 | Implement: remove earlyoom, add systemd-oomd, add MemoryMax to 3 services |
| 04:33 | Build fails — `systemd.oomd` in wrong attrset (services vs systemd) |
| 04:34 | Fix and build passes |
| 04:34 | Discover all changes already committed in `059765b6` — only AGENTS.md is new |
| 04:35 | Status report written |
| 04:50 | **Correction**: "earlyoom was effectively disabled" claim was an oversimplification — earlyoom would trigger in true crisis, but late. Updated report with accurate analysis from source code review of `lowmem_sig()`.
