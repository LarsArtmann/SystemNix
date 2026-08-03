# Status Report: 2026-08-03 nodiscard False Alarm & Corruption Follow-Up

**Generated:** 2026-08-03 08:14 CEST
**Session:** Continuation of the 06:51 corruption discovery session
**Hardware:** evo-x2 (AMD Strix Halo), Lexar NQ790 2TB QLC NVMe, kernel 7.1.5
**Severity:** P0-HIGH — Two corrupted files confirmed and deleted; `nodiscard` IS working; async discard ran for ~6h during a pre-config window

---

## Executive Summary

The prior session concluded that `nodiscard` was being "silently ignored by kernel 7.1.5 BTRFS" based on the boot log showing `"turning on async discard"`. **This conclusion was wrong.** This session proved that:

1. The "turning on async discard" boot message was from **Aug 01 21:05** — the initial boot, BEFORE `nodiscard` was added to the NixOS config (commit `87477dbb` at Aug 03 02:50)
2. The deploy at 03:07 successfully remounted both filesystems with `nodiscard` — the async discard worker IS stopped (verified: `discardable_extents` counter is static)
3. The cumulative sysfs discard counters (1.3 TiB on `/`, 252 GiB on `/data`) accumulated during the ~6 hour window between boot and deploy, NOT ongoing
4. I made two dangerous config changes based on the false conclusion, then reverted both after research

**Corruption status:** Scrub running on `/data` (72.89 MiB/s, ETA ~09:37 CEST). At 26.27% (185.78 GiB), **zero errors found**. Both corrupted files identified and deleted by the user.

---

## A) Fully Done

### 1. Identified second corrupted file

`sudo btrfs inspect-internal inode-resolve 1331118 /data` resolved to `/data/llamacpp-models/BAGEL-7B-MoT/ae.safetensors`. User deleted it. Both corrupted inodes now accounted for:

| Inode | Path | Status |
|-------|------|--------|
| 1331118 | `/data/llamacpp-models/BAGEL-7B-MoT/ae.safetensors` | Deleted by user |
| 2608092 | `/data/ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors` | Deleted by user (prior session) |

### 2. Verified `nodiscard` IS working (not being ignored)

Three independent verification methods:
- **sysfs counter test:** `discardable_extents` on both `/` (238,259) and `/data` (56) did NOT change over a 10-second window → async discard worker is stopped
- **Timeline reconstruction:** Boot log timestamp is Aug 01 21:05; `nodiscard` commit is Aug 03 02:50; deploy is Aug 03 03:07. The boot message predates the config change
- **fstab vs mountinfo:** `/run/current-system/etc/fstab` has `nodiscard`; `/proc/self/mountinfo` shows neither `nodiscard` nor `discard=async` (BTRFS doesn't show `nodiscard` in mountinfo — it's the default-off state, only `discard=async`/`discard=sync` would appear)

### 3. Researched BTRFS discard options from primary sources

Researched the actual kernel source code and BTRFS documentation:
- `nodiscard` IS a valid option, registered via `fsparam_flag_no("discard", Opt_discard)`, sets `BTRFS_MOUNT_NODISCARD` flag
- The auto-enable logic explicitly checks `NODISCARD` before enabling `DISCARD_ASYNC` — no known regression in kernels 6.2 through 7.1
- `discard=none` is **NOT a valid BTRFS option** — only `discard=sync`, `discard=async`, and `nodiscard` are valid. `discard=none` returns `-EINVAL` → mount failure → emergency shell
- No BTRFS discard-related changes in Linux 7.0 or 7.1 changelogs

### 4. Reverted dangerous config changes

Both changes from earlier in this session were reverted (auto-committed as `c2615d09`):
- `discard=none` removed from hardware-configuration.nix (would have caused boot failure)
- `disable-nvme-discard` systemd service removed from boot.nix (unnecessary, would have killed fstrim)

### 5. Scrub started on /data

User started foreground scrub: `sudo btrfs scrub start -B /data`. Running at 72.89 MiB/s, ETA ~09:37 CEST. At last check: 26.27% complete, **no errors found**.

---

## B) Partially Done

### 1. Scrub on /data

Running but incomplete (~26% at time of report). No errors so far is encouraging but not conclusive.

### 2. Drive health assessment

We know:
- Two corrupted files (both `.safetensors` ML model files — large sequential writes)
- Balance fails on data block groups at `-dusage=70+` with EIO
- Scrub is clean so far at 26%
- `/data` is 92% full
- The drive experienced ~6 hours of async discard + a 330 GiB fstrim event 4.5 hours before corruption appeared
- No SMART data yet (smartmontools not run)

Missing: SMART health, full scrub results, `/` scrub results.

---

## C) Not Started

1. **SMART data** — `smartmontools` not installed; `nvme-cli` available via nix shell but never run
2. **Scrub on `/`** — Same physical NVMe, never checked for corruption
3. **Monthly autoScrub fix** — Still only runs 15 minutes before being interrupted (corruption blind spot)
4. **Check if deleted models are needed** — Both are HuggingFace models, re-downloadable, but no check done for active services referencing them
5. **Reduce `/data` fill below 80%** — Still at 92%, severe write amplification on QLC NAND
6. **Journald watchdog failure investigation** — Aug 02 23:19 event still uninvestigated
7. **Drive replacement decision** — No data to decide yet
8. **Offsite backup** — All snapshots remain LOCAL-ONLY (AGENTS.md: "#1 data loss risk")
9. **`/data` compression removal** — Blocked on corruption scope being known first
10. **AGENTS.md update** — Needs correction: the prior session's claim that `nodiscard` is a no-op was wrong

---

## D) Totally Fucked Up

### 1. Made config changes WITHOUT RESEARCH

**This is the single biggest failure of this session.** When the user showed that `mount | grep btrfs` lacked `nodiscard`, I immediately concluded the kernel was ignoring it and started editing config files. I did not:
- Check when the system was last booted
- Check when `nodiscard` was added to the config
- Research whether `discard=none` is a valid BTRFS option
- Research whether `nodiscard` has any known regressions
- Consider that the boot log timestamp might predate the config change

The user had to explicitly say **"How about you do some fucking research and stop guessing shit?"** before I did any research at all.

### 2. Added `discard=none` — an INVALID BTRFS mount option

`discard=none` does not exist for BTRFS. The kernel's constant table only defines `sync` and `async`:
```c
static const struct constant_table btrfs_parameter_discard[] = {
    { "sync", Opt_discard_sync },
    { "async", Opt_discard_async },
    {}  // no "none"
};
```
If deployed, this would have caused **mount failure → `local-fs.target` failure → emergency shell** — exactly the class of bug documented in AGENTS.md ("ext4 `discard=async`" gotcha). I would have bricked the next boot.

### 3. Added `disable-nvme-discard` service — unnecessary AND harmful

The service set `discard_max_bytes=0` at the block layer. This is the nuclear option that:
- Was unnecessary (nodiscard already works)
- Would have killed `fstrim.timer` (fstrim uses the same block-layer path) — fstrim is a SEPARATE, legitimate operation from async discard
- Would have prevented any future legitimate use of discard

### 4. Trusted the prior session's conclusion without verification

The prior session concluded `nodiscard` was a no-op based on the boot log showing "turning on async discard". I carried this conclusion forward without questioning it. The prior session never checked:
- Whether the boot log timestamp predated the config change
- Whether the discard worker was actually running (the sysfs counter test I did this session takes 10 seconds)

### 5. Didn't notice the boot log timestamps

The boot log clearly shows `Aug 01 21:05:46` — two days before `nodiscard` was added to the config. This was in the user's original paste data from the prior session. I should have caught this immediately.

### 6. Over-explained instead of acting

When I should have been checking boot timestamps and running `discardable_extents` verification, I was writing multi-paragraph explanations about block-layer architecture and BTRFS internals. The user wants action and verification, not lectures.

---

## E) What We Should Improve

### Process Improvements

1. **RESEARCH BEFORE EDITING** — Never make config changes based on assumptions. Read the docs, check the source, verify the hypothesis. This is rule #1 in AGENTS.md: "READ before you WRITE."

2. **Check timestamps before drawing conclusions** — "X is in the boot log" is meaningless without checking whether the boot predates the config change that added X.

3. **Verify runtime state before changing config** — The `discardable_extents` counter test takes 10 seconds and definitively answers "is the discard worker running right now?" This should have been the FIRST thing I did, not something I did after making changes.

4. **Don't trust prior session conclusions blindly** — The prior session's "nodiscard is silently ignored" conclusion was wrong. I should have verified it independently before building on it.

5. **Stop over-explaining** — The user is a senior engineer who knows what BTRFS, FTL, IOPS, and block layers are. They want test results and actions, not tutorials. Keep responses to data + action.

### Technical Improvements

6. **Add a boot-time assertion that `nodiscard` is active** — A simple oneshot that checks `cat /sys/fs/btrfs/*/discard/discardable_extents` is static over a 5-second window, and logs a warning if it changes. Would catch any future regression immediately.

7. **Fix the monthly scrub** — `autoScrub` ran only 15 minutes and was interrupted. At 72.89 MiB/s, a full `/data` scan takes ~2.5 hours. The monthly scrub needs to actually complete, or we're flying blind on corruption.

8. **Add SMART monitoring** — `nvme-health-monitor.nix` exists but `smartmontools` was never run manually this session. The automated monitoring may not cover all SMART attributes.

9. **Reduce `/data` fill level** — 92% full on QLC NAND is severe. Write amplification at this fill level degrades the drive faster. Need to delete unused models and old Docker images.

10. **Consider removing `compress=zstd:3` from `/data`** — Compression adds CPU overhead and write amplification on a drive that's already stressed. But only after corruption scope is fully known.

---

## F) Next Actions (up to 50)

### Immediate (today, while scrub runs)

1. ~~Verify async discard is actually running~~ → **DONE: Worker IS stopped, `nodiscard` works**
2. ~~Identify second corrupted file~~ → **DONE: `/data/llamacpp-models/BAGEL-7B-MoT/ae.safetensors`**
3. ~~Revert dangerous `discard=none` and `disable-nvme-discard` changes~~ → **DONE: Committed as `c2615d09`**
4. **Wait for `/data` scrub to complete** — Currently running, ETA ~09:37 CEST. Check for errors.
5. **Run `nix shell nixpkgs#smartmontools -c smartctl -a /dev/nvme0n1`** — Get SMART data (media errors, power-on hours, thermal throttling, unsafe shutdowns)
6. **Run `nix shell nixpkgs#nvme-cli -c nvme error-log /dev/nvme0n1`** — Get NVMe error log
7. **Run `nix shell nixpkgs#nvme-cli -c nvme smart-log /dev/nvme0n1`** — Alternative SMART view

### Short-term (after scrub completes)

8. **Run foreground scrub on `/`** — `sudo btrfs scrub start -B /` — same physical NVMe, never checked
9. **Review scrub results** — If `/data` scrub finds more errors, the drive may need replacement
10. **Check `btrfs device stats / /data`** — Re-check after scrub for new corruption counters
11. **Verify balance now succeeds on /data** — After deleting both corrupted files, retry `btrfs balance start -dusage=70 /data`
12. **Check if deleted models are used by any service** — `grep -r 'BAGEL\|illustrij' /etc /home/lars/.config /data/*/config*`
13. **Fix the monthly autoScrub** — Investigate why it only ran 15 minutes. Likely a timeout or service ordering issue in `btrfs-health.nix`

### Configuration correctness

14. **Verify `nodiscard` survives the next reboot** — The boot log message "turning on async discard" should NOT appear for the next boot now that `nodiscard` is in the deployed config
15. **Update the prior status report** (`docs/status/2026-08-03_06-51_*.md`) — Correct the "P0-CRITICAL: nodiscard is a no-op" claim to "RESOLVED: nodiscard works, async discard ran ~6h between boot and deploy"
16. **Update AGENTS.md** — The BTRFS section claims `nodiscard` was verified working. This is true NOW but the prior session's investigation was wrong. Document the correct verification method (sysfs counter test).
17. **Remove misleading comment in hardware-configuration.nix** — The comment says "Verified on kernel 7.1.5 via /proc/mounts + sysfs discard counters" but `/proc/mounts` does NOT show `nodiscard` (BTRFS doesn't display it). The sysfs counter test is the correct verification.

### Drive health & data safety

18. **Reduce `/data` fill below 80%** — Delete unused AI models, old Docker images (`docker image prune -a`), old monitor365 data
19. **Check backup status of `/data/ai/`, `/data/immich/`, `/data/monitor365/`** — Are any of these backed up offsite?
20. **Investigate the Aug 02 23:19 journald watchdog failure** — `systemd-journald.service: Failed with result 'watchdog'`
21. **Investigate the Aug 01 WDT reset** — `Previous system reset reason [0x02000800]: hardware watchdog timer expired`
22. **Decide on drive: replace, RAID1, or monitor** — Based on SMART + scrub results. QLC NAND with confirmed corruption is a risk.
23. **Set up offsite backup** — AGENTS.md: "All snapshots are LOCAL-ONLY. If the NVMe fails, everything is lost."
24. **Consider BTRFS read-only snapshot of `/data`** — Before any further modifications, snapshot the current state for comparison

### Monitoring improvements

25. **Add a discard-worker health check** — Timer that samples `discardable_extents` twice (5s apart), alerts if the counter decreases (worker is active) when `nodiscard` should be stopping it
26. **Add SMART alerting to Gatus** — If `nvme-health-monitor.nix` doesn't already alert on media errors, add it
27. **Fix the compression metrics timer** — `btrfs-compression.prom` was empty (header only). The timer is broken.
28. **Add `/data` fill-level monitoring** — Gatus alert when `/data` exceeds 85% fill
29. **Review `btrfs-health.nix` scrub monitoring** — The `btrfs_scrub_error_free=1` metric was stale (scrub was interrupted, not completed). Need to track scrub completion, not just error-free status.

### Process & documentation

30. **Write a post-mortem of the `discard=none` incident** — Document how close we came to bricking the next boot, and the lesson: RESEARCH BEFORE EDITING
31. **Audit all BTRFS mount options against kernel docs** — Verify every option in hardware-configuration.nix is valid for the current kernel version
32. **Consider adding `nodiscard` verification to pre-deploy-check** — A check that samples `discardable_extents` and warns if the worker appears active
33. **Review whether `fstrim.timer` should run on this drive at all** — The 330 GiB fstrim event at 01:17 preceded the first corruption at 05:47. On QLC NAND with 253ms discard latency, even periodic fstrim may be harmful.
34. **Check `btrfs filesystem df /data` after scrub** — See if the balance failure data blocks have been reallocated
35. **Run `btrfs device stats /data` after scrub** — Compare corruption counters with pre-scrub values

### Long-term

36. **Plan drive replacement** — If SMART shows media errors or scrub finds more corruption, replace with TLC/MLC NVMe (Samsung 990 Pro, WD SN850X, or enterprise-grade)
37. **Consider RAID1 for /data** — BTRFS RAID1 or mdadm mirror for the data partition
38. **Evaluate ext4 vs BTRFS for /data** — BTRFS CoW + compression adds overhead on a stressed drive. ext4 with `nodiscard` may be simpler for the Docker/AI workload partition.
39. **Set up remote BTRFS send/receive** — For actual offsite backup of critical data
40. **Review all AI model storage** — Many models on `/data` may be stale/unused. Clean up.
41. **Consider separating Docker volumes from AI models** — Different partitions with different backup/reliability profiles
42. **Evaluate whether the Strix Halo unified memory architecture is contributing** — GPUActive consuming 50+ GiB may cause memory pressure that cascades into I/O stalls
43. **Review kernel 7.2 when released** — May contain BTRFS fixes relevant to this issue
44. **Document the QLC NAND risk in AGENTS.md** — Make it clear that this drive type requires special handling (no async discard, limited fstrim, keep below 80% fill)
45. **Consider `commit=600` mount option** — Longer BTRFS commit interval to reduce metadata write frequency on the stressed drive
46. **Review whether `compress=zstd:3` on `/data` is helping or hurting** — Compression reduces write volume but adds CPU overhead and may increase random I/O patterns
47. **Check Docker storage driver** — If using `overlay2` on BTRFS, there may be CoW amplification. Consider disabling CoW for Docker volumes (`chattr +C`).
48. **Audit all services writing to `/data`** — Identify which services are the heaviest writers and whether they can be tuned
49. **Set up automated model cleanup** — Script to delete unused/old AI models from `/data/ai/models/`
50. **Review the entire BTRFS health monitoring stack** — Ensure all metrics (scrub, balance, compression, device stats, fill level, discard worker) are collected, alerted, and actionable

---

## G) Questions (3 — cannot figure out myself)

### 1. Does `fstrim.timer` run on this drive, and should it?

The prior session's evidence shows `fstrim.service` trimmed 330.1 GiB on `/data` at 01:17:55 on Aug 03, ~4.5 hours before the first corruption appeared. `services.fstrim.enable = true` is set in `configuration.nix`. On QLC NAND with 253ms discard latency, even periodic fstrim may cause the same I/O stalls as async discard.

**Should we disable `fstrim` entirely on this drive?** The tradeoff: without fstrim, the drive's FTL has no knowledge of freed blocks → write amplification increases over time → faster wear. With fstrim, each trim command causes a 253ms latency spike → BTRFS commit stalls → potential corruption. This is a hardware-level tradeoff I cannot resolve without knowing your priorities (drive lifespan vs I/O stability).

### 2. Is the Lexar NQ790 still under warranty?

If the drive is failing (SMART media errors, confirmed data corruption), a warranty replacement may be possible. I cannot check purchase records or warranty status.

### 3. What is your risk tolerance for `/data`?

`/data` holds: Docker volumes (Immich, monitor365, Twenty CRM), AI models, Steam games, and DiscordSync attachments. The criticality of each differs:
- **Immich** — photos, irreplaceable, needs backup
- **monitor365** — monitoring data, loss is inconvenient but not catastrophic
- **AI models** — re-downloadable from HuggingFace, zero data loss risk
- **Steam games** — re-downloadable
- **Twenty CRM** — business data, needs backup
- **DiscordSync** — message archive, has GCS backup configured

**Which of these do you consider irreplaceable?** This determines whether we need urgent offsite backup before drive replacement, or whether we can treat this as a "monitor and replace when convenient" situation.
