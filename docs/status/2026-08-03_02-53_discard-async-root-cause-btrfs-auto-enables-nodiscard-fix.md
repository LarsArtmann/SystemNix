# `discard=async` Root Cause: BTRFS Auto-Enables It — `nodiscard` Fix Applied

**Date:** 2026-08-03 02:53
**Session type:** Root cause analysis → permanent fix
**Drive:** Lexar SSD NQ790 2TB (QLC NVMe, PCIe Gen4)
**Status:** Root cause found and fixed in config. `/` still needs remount. Deploy + reboot required for permanent fix.

---

## Timeline of the Discovery

1. User requested SSD speed test
2. I benchmarked `/tmp` (tmpfs/RAM) — got bogus 21.6 GiB/s numbers
3. User caught the error: *"Did you test via BTRFS?"*
4. Benchmarked `/data` (BTRFS) with `direct=1` — got **14.4 MiB/s** read (500x below spec)
5. User pointed out `discard=async` from AGENTS.md
6. I found `discard=async` still in all 9 live BTRFS mounts despite being removed from config on 2026-07-08
7. User manually remounted `/data` with `nodiscard`
8. Re-benchmarked `/data` — **89x faster read, 15-33x better IOPS**
9. User pointed out they HAD rebooted since 2026-07-08
10. I investigated: booted generation fstab was clean, but live mounts still had `discard=async`
11. **Root cause discovered:** Root (`/`) NEVER had `discard=async` in any config ever, yet it appeared in `/proc/mounts` on every boot
12. **BTRFS on this kernel auto-enables `discard=async` on SSDs** — removing it from config is a no-op
13. Fixed config: added explicit `nodiscard` to `/`, `/data`, and `/rust-cache`
14. `nix flake check --no-build` passes

---

## The Root Cause (The Real One This Time)

### What Everyone Thought Happened (Wrong)

> The 2026-07-08 fix removed `discard=async` from the Nix config. After a reboot, the clean fstab should have been used. But nobody rebooted, so the stale mount persisted.

### What Actually Happened (Right)

> **BTRFS on Linux kernel 7.1.5 auto-enables `discard=async` when mounted on an SSD.** The kernel detects the NVMe device as non-rotational and silently applies `discard=async` as a default mount option. Removing `discard=async` from fstab does nothing — the kernel applies it anyway. The ONLY way to disable it is to explicitly mount with `nodiscard`.

### Proof

```
Root ("/") NEVER had discard=async in any git commit ever:
  git log -p -S 'discard=async' -- hardware-configuration.nix
  → Only /data and /rust-cache ever had it. Root was always clean.

Yet /proc/mounts showed discard=async on EVERY BTRFS mount after every reboot:
  /dev/nvme0n1p6 / btrfs rw,...,discard=async,...
  /dev/nvme0n1p6 /nix/store btrfs ro,...,discard=async,...
  /dev/nvme0n1p8 /data btrfs rw,...,discard=async,...
  (+ 6 more subvolume mounts)
```

The booted generation's fstab was clean — no `discard` anywhere. But the live mounts had it. This means the kernel is applying it as a default, NOT reading it from fstab.

### Why the 2026-07-08 Fix Failed

The 2026-07-08 commit (`7b7b20f3`) removed `discard=async` from `/data` options and `discard` from `/rust-cache`. It also added a comment saying *"Root filesystem has never had discard=async and has been fine"* — **this was a false assumption**. Root was NOT fine. It had `discard=async` from kernel auto-detection the entire time.

The fix was incomplete because:
1. Removing `discard=async` from config is a **no-op** — the kernel adds it back
2. Nobody verified `/proc/mounts` AFTER a reboot to confirm the fix took effect
3. The comment on line 55 ("Root filesystem has never had discard=async and has been fine") was factually wrong — it WAS getting `discard=async`, just not from fstab
4. No monitoring or check existed to catch the drift between config and live state

---

## Benchmark Evidence

### Before `discard=async` removal (all 9 BTRFS mounts had it)

| Test | `/data` (discard=async) | `/data` (nodiscard, remounted) | Improvement |
|------|------------------------|-------------------------------|-------------|
| **Seq Read** (1M, QD32) | 14.4 MiB/s | **1,276 MiB/s** | **89x** |
| **Seq Write** (1M, QD32) | 2.9 MiB/s | 29.6 MiB/s | 10x |
| **Rand Read** (4K×4, QD32) | 496 IOPS | **7,603 IOPS** | **15x** |
| **Rand Write** (4K×4, QD32) | 183 IOPS | **5,989 IOPS** | **33x** |
| Seq Read p99 latency | 8.2 seconds | 129 ms | 64x |
| Rand Read p99 latency | 6.5 seconds | 284 ms | 23x |

### Lexar NQ790 Rated Spec vs Measured (after fix)

| Metric | Rated | Measured (post-fix) | Gap |
|--------|-------|---------------------|-----|
| Sequential Read | 7,000 MB/s | 1,276 MiB/s (~18%) | Still 5.5x below spec |
| Sequential Write | 6,000 MB/s | 29.6 MiB/s (~0.5%) | Still 200x below spec |

**Remaining gap explanation:** Background I/O from 30+ services (60-84% disk utilization during tests) + QLC SLC cache exhaustion (`/data` is 69% full). A clean benchmark with services stopped would show higher numbers. The random IOPS numbers (7.6K read, 6K write) are in the right ballpark for a QLC drive under load.

### The First Benchmark (Bogus — `/tmp` is tmpfs)

| Test | Throughput | Verdict |
|------|-----------|---------|
| Sequential Read (1M) | 21.6 GiB/s | **INVALID** — measured RAM, not SSD |
| Sequential Write (1M) | 10.0 GiB/s | **INVALID** — measured RAM, not SSD |

---

## Current State

### What's Fixed Right Now (Live)

| Filesystem | `discard=async` | How |
|------------|-----------------|-----|
| `/data` (nvme0n1p8) | ❌ Gone | User manually remounted with `nodiscard` |
| `/` + 7 subvolumes (nvme0n1p6) | ✅ **STILL PRESENT** | Not yet remounted |

### What's Fixed in Config

| Filesystem | `nodiscard` added? | Status |
|------------|-------------------|--------|
| `/` | ✅ Yes | Ready to deploy |
| `/data` | ✅ Yes | Ready to deploy |
| `/rust-cache` | ✅ Yes | Ready to deploy (ext4, also auto-applies) |

### Config Verification

```
nix flake check --no-build → all checks passed
```

---

## What I Did (Self-Assessment)

### a) FULLY DONE (Correctly)

1. ✅ Identified the REAL root cause: BTRFS auto-enables `discard=async` on SSDs, removing it from config is a no-op, `nodiscard` is required
2. ✅ Proved it by showing root (`/`) never had `discard=async` in any git commit yet it appeared in every live mount
3. ✅ Applied the permanent fix: added `nodiscard` to all three filesystem configs (`/`, `/data`, `/rust-cache`)
4. ✅ Validated with `nix flake check --no-build` — all checks pass
5. ✅ Provided concrete benchmark before/after data proving `discard=async` was the killer (89x improvement)
6. ✅ Updated comments in config to explain WHY `nodiscard` is needed (not just what it does)
7. ✅ Cleaned up all fio test files after each benchmark run
8. ✅ Identified that the 2026-07-08 comment "Root filesystem has never had discard=async and has been fine" was factually wrong

### b) PARTIALLY DONE

1. ⚠️ Confirmed `/data` is fixed live (user remounted), but `/` + 7 subvolume mounts still have `discard=async` in production
2. **Not deployed yet** — the config fix is ready but not deployed. After deploy, a reboot is still required for the `nodiscard` to apply to root
3. ⚠️ Identified remaining benchmark gap (seq write still 200x below spec) but did NOT isolate background I/O vs QLC cache exhaustion as the cause
4. ⚠️ Identified that `/` needs a remount right now but did NOT execute it (requires sudo)

### c) NOT STARTED

1. ❌ Did not remount `/` with `nodiscard` (user needs to run `sudo mount -o remount,nodiscard /`)
2. ❌ Did not run `fstrim` manually to clear the TRIM backlog that accumulated during the 26 days of choke
3. `igned how the system survived 26 days of `discard=async` without a WDT hard reset (the documented crash mode)
4. ❌ Did not verify whether SMART data shows elevated media errors from 26 days of TRIM abuse
5. ❌ Did not write a monitoring check / pre-deploy-check to catch this class of bug
6. ❌ Did not update AGENTS.md with the `nodiscard` finding (BTRFS auto-enables discard on SSDs)
7. ❌ Did not benchmark `/` after remount to confirm improvement
8. `d update the previous status report (2026-08-03_00-52) with the corrected root cause

### d) TOTALLY FUCKED UP

1. **Ran the first benchmark on `/tmp` (tmpfs/RAM)** without checking the filesystem first. The most basic possible mistake. A `df -Th /tmp` before writing the fio config would have caught this instantly. The 21.6 GiB/s "result" was pure memory bandwidth and completely meaningless.

2. **Used invalid fio options TWICE** (`refresh_workloads=1`, then `new_workload`) — wasted two full benchmark cycles on syntax errors I should have caught by checking the fio manpage or doing a `--parse-only` dry run first.

3. **Initially tried to DISMISS the terrible BTRFS numbers as a "testing artifact."** When the O_DIRECT test showed 14 MiB/s seq read (500x below spec), my first instinct was to explain it away as O_DIRECT + background I/O. I said *"the drive itself is almost certainly fine"* — I was WRONG. The drive WAS genuinely choking, and the root cause was documented in AGENTS.md. I should have immediately checked mount options.

4. **Did NOT read the AGENTS.md before starting.** The `discard=async` issue is documented RIGHT THERE as a known critical problem. The AGENTS.md even has a table row: *"discard=async on QLC NAND = I/O latency death spiral."* The user had to point it out to me.

5. **Ran a second buffered-IO test that was ALSO bad** — and STILL tried to frame it as recoverable. The buffered seq read was 3.4 MiB/s. That's not a "testing artifact." That's a sick drive. I should have stopped benchmarking and started diagnosing.

6. **Diagnosed the wrong root cause initially.** When I first found `discard=async` in live mounts, I said *"the fix was never deployed" / "you need a reboot"*. When the user pointed out they HAD rebooted, I had to rethink. I then investigated booted-vs-current generation fstabs, initrds, kernel cmdlines — all dead ends until the key insight: root NEVER had `discard` in config, yet it appeared live. That was the clue that the kernel was auto-applying it.

### e) WHAT WE SHOULD IMPROVE

#### Process / Methodology

1. **Always check `/proc/mounts` or `findmnt` before any disk benchmark** — know what filesystem and mount options you're testing against. This is step zero.
2. **Read the project's documented known issues BEFORE running diagnostics** — the `discard=async` problem was fully documented in AGENTS.md
3. **When results are 500x below spec, investigate immediately** — don't dismiss as "artifact". Catastrophic numbers = catastrophic problem.
4. **`fio` configs should be validated** (`fio --parse-only`) before a full 2-minute run
5. **Verify fixes after deploy** — the 2026-07-08 fix was "deployed" but nobody checked `/proc/mounts` after the next reboot. A 30-second check would have caught it.
6. **"Not in config" does NOT mean "not applied"** — for mount options, the kernel has defaults that apply regardless of fstab. This is a fundamental BTRFS/Linux I/O management lesson.

#### Technical / Infrastructure

7. **Add a mount-option drift monitor** — a check that compares `/proc/mounts` against configured `fileSystems.*.options` and alerts when they drift. This would have caught the 26-day drift immediately.
8. **Add `nodiscard` to the `mkFilesystem` helper** as a recommended option for BTRFS on QLC drives
9. **The `mkFilesystem` helper in `lib/filesystems.nix` should warn when BTRFS is used WITHOUT `nodiscard`** on systems known to have QLC NAND
10. **Post-deploy smoke test should check `/proc/mounts`** for known-bad options like `discard=async`
11. **Document the BTRFS auto-discard behavior in AGENTS.md** — this is a non-obvious kernel behavior that cost 26 days of performance

#### Benchmarking

12. **Write a reusable `scripts/ssd-benchmark.sh`** that: (a) checks filesystem first, (b) refuses to run on tmpfs, (c) validates fio config, (d) reports results in a clean table
13. **Run benchmarks with services stopped or on a clean partition** to isolate drive performance from background I/O
14. **Run sustained-write tests** to measure the QLC SLC cache fall-off curve
15. **Benchmark root filesystem separately** from `/data`

---

## Config Changes Made

**File:** `platforms/nixos/hardware/hardware-configuration.nix`

1. Added `nodiscard` to `/` mount options
2. Added `nodiscard` to `/data` mount options
3. Added `nodiscard` to `/rust-cache` mount options (ext4)
4. Updated comments to explain the BTRFS auto-discard behavior and why `nodiscard` is required (not just "removed")
5. Removed the false comment "Root filesystem has never had discard=async and has been fine"

---

## Next Actions (Up to 50)

### Priority 0 — Immediate (Blocking)

1. **Remount `/` NOW** to stop the active I/O choke: `sudo mount -o remount,nodiscard /`
2. **Verify remount**: `cat /proc/mounts | grep discard` returns nothing
3. **Deploy the config fix**: `nix run .#deploy` so the next reboot is permanent
4. **Run `sudo fstrim -v /` and `sudo fstrim -v /data`** to clear the 26-day TRIM backlog safely (one-shot, not continuous)
5. **Reboot** after deploy to confirm `nodiscard` survives reboot (BTRFS may still try to re-add `discard=async`)
6. **Verify after reboot**: `cat /proc/mounts | grep discard` returns nothing
7. **Re-run fio benchmark on both `/` and `/data`** post-reboot to confirm performance
8. **Check SMART data** (`sudo smartctl -a /dev/nvme0n1`) for media errors, percentage used, available spare — 26 days of TRIM abuse on QLC NAND
9. **Check BTRFS scrub status** (`sudo btrfs scrub status /` and `/data`) — I/O choke may have caused undetected corruption
10. **Check dmesg for WDT resets** (`dmesg | grep -i watchdog`) — verify no hardware watchdog events during the 26-day window

### Priority 1 — High Impact (Monitoring & Prevention)

11. **Write a mount-option drift checker** — compare `/proc/mounts` vs configured options, alert on drift. This is the systemic fix that prevents this entire class of bug.
12. **Add it to `pre-deploy-check`** — fail deploy if known-bad options (`discard=async`) are detected in live mounts
13. **Add it as a Prometheus textfile collector** + Gatus alert for runtime monitoring
14. **Update AGENTS.md** with the `nodiscard` finding — specifically the non-obvious fact that BTRFS auto-enables `discard=async` on SSDs
15. **Update the existing `discard=async` gotcha entry** to reflect the REAL fix (`nodiscard`, not "removal")
16. **Update the false comment** in any other docs that says "root has never had discard=async"
17. **Review the 2026-07-08 status reports** — they document the wrong fix. Add a correction note.
18. **Add `nodiscard` to the `mkFilesystem` helper** documentation/validation as recommended for QLC drives

### Priority 2 — Benchmarking & Validation

19. **Benchmark `/` after remount** to confirm it also improves (we only benchmarked `/data`)
20. **Run a clean benchmark** with background services stopped to get true drive speed
21. **Run a sustained-write test** (100GB+) to measure QLC SLC cache exhaustion curve
22. **Compare buffered vs O_DIRECT** on BTRFS for this drive to establish baseline
23. **Test different queue depths** (1, 4, 16, 32, 64) to find optimal IO depth
24. **Test mixed read/write workload** (70/30) to simulate real usage
25. **Benchmark the ext4 `/rust-cache` partition** separately
26. **Compare BTRFS compression overhead** (zstd vs none) on this drive
27. **Write `scripts/ssd-benchmark.sh`** — reusable, tmpfs-checking, self-validating

### Priority 3 — Configuration Hardening

28. **Consider making `nodiscard` the default in `mkFilesystem`** for BTRFS, requiring explicit opt-in for `discard`
29. **Review all other mount options for kernel-auto-applied defaults** that might be silently harmful (similar to `discard=async`)
30. **Check if `compress=zstd` vs `compress=zstd:3`** difference between config and live matters (config says `zstd`, live shows `zstd:3`)
31. **Verify `ssd` mount option is still beneficial** for NVMe (was designed for SATA SSDs)
32. **Review if `space_cache=v2` performance** is optimal
33. **Document the "deploy ≠ active for mount options" gotcha** more prominently
35. **Consider a post-deploy warning** when mount options changed since last boot: "mount options changed — reboot to apply"
36. **Add a generation comparison tool** that shows what changed between booted and current generation
37. **Review the deploy.sh flow** — does it warn about pending mount option changes?
38. **Check if `nh os switch` has any mount-option-awareness** that we're missing

### Priority 4 — System Health Verification

39. **Check all services for I/O-timeout crash loops** that may resolve once `/` is unchoked
40. **Review nix build times** — they may have been significantly slower due to `/nix/store` being on the choked filesystem
41. **Check Docker storage driver performance** (overlay2 on BTRFS with discard=async)
42. **Review Immich/ClickHouse/Docker volume I/O patterns** — were they hitting the choked NVMe?
43. **Check zram swap performance** — zram backing I/O may have been affected
44. **Check if the OOM crash chain** (documented in AGENTS.md) was exacerbated by I/O stalls during memory pressure
45. **Review btrbk snapshot freshness** — I/O choke may have caused snapshot failures
46. **Check `btrfs filesystem df /` and `/data`** for allocation pathologies
47. **Review BTRFS balance status** — weekly balance may have been failing or slow
48. **Check `systemctl status btrfs-scrub@*`** — monthly scrub may have been failing silently
49. **Monitor BTRFS commit times** going forward (alert if > 5 seconds)
50. **Document this full session** in the BTRFS section of AGENTS.md as an updated gotcha

---

## Questions (That I Cannot Answer Myself)

1. **When can we deploy + reboot?** The config fix (`nodiscard`) is ready and validated, but it requires a deploy + reboot to become permanent. `/` is still running with `discard=async` right now. When is a safe maintenance window? (The `/data` remount you did manually is live but won't survive reboot without the deploy.)

2. **Has the system been noticeably slower over the last 26 days?** Slow nix builds, sluggish Docker containers, service timeouts, unresponsive periods? This would help assess whether the I/O choke has been causing user-visible degradation beyond the benchmark numbers. The drive was running at 1-14 MiB/s instead of 7000 MiB/s — that's a massive real-world impact on every I/O operation.

3. **Should the mount-option drift monitor** (item #11 in next actions) be a pre-deploy-check assertion, a Gatus/Prometheus runtime alert, or both? The pre-deploy check catches it at deploy time; the runtime alert catches kernel-default changes (like this one) that happen without a deploy. I recommend both but want your call on priority.
