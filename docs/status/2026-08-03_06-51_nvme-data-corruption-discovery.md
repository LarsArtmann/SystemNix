# Status Report: 2026-08-03 NVMe Drive Corruption Discovery

**Generated:** 2026-08-03 06:51 CEST (last updated 07:10 CEST — added "Overlooked Findings" section)
**Session:** Single session (resumed from prior `discard=async` investigation)
**Hardware:** evo-x2 (AMD Strix Halo), Lexar NQ790 2TB QLC NVMe, kernel 7.1.5
**Severity:** ~~P0-CRITICAL — Confirmed corruption, `nodiscard` deploy is a no-op, async discard still active~~ **CORRECTED:** Data corruption confirmed (13 files), but `nodiscard` IS working — root cause is 58 unsafe shutdowns, not async discard. See [Resolution](#resolution-2026-08-03) below.

> **Update 2026-08-03 09:24 (commits `c2615d09`, `ff2c2f80`):** The central claim of this report — that `nodiscard` is being ignored by the kernel — was **PROVEN FALSE**. The `BTRFS info: turning on async discard` kernel messages were from a **previous boot** (before the `nodiscard` deploy), visible in `journalctl` because it shows messages from all boots since journal rotation. `mount | grep btrfs` confirms `nodiscard` IS active on all BTRFS mounts. SMART analysis shows the drive is healthy (0 media errors, 11% wear). Root cause is **58 unsafe shutdowns** (46% of 126 power cycles), not async discard. All 13 corrupted files were identified and deleted. `autoScrub` changed from monthly to weekly. Dangerous config changes (`discard=none`, block-layer disable) were reverted. Full investigation in `2026-08-03_08-14` and `2026-08-03_09-24`.

---

## Executive Summary

The session began as a continuation of prior `discard=async` performance investigations and evolved into discovery of **active data corruption on `/data`** (`/dev/nvme0n1p8`).

**Facts established this session:**
1. `/dev/nvme0n1p8` returned corrupted data on at least two distinct inodes (ino 1331118, ino 2608092)
2. The user deleted one corrupted file (`diffusion_pytorch_model.safetensors`, ino 2608092)
3. `btrfs balance` operations on `/data` consistently fail with `Input/output error` (`status: -5`) when targeting data block groups
4. `btrfs balance` on metadata and system block groups succeeds — corruption is data-only
5. The Lexar NQ790 is a consumer QLC drive that has experienced sustained stress: 26+ days of `discard=async` (since removed), WDT resets, heavy write workload

**Facts NOT established this session:**
- Total count of corrupted files
- Whether corruption is localized to one block group or spread across the drive
- Hardware-level drive health (SMART data never checked)
- Whether more corruption is occurring in real time or is from a single past event

**Anchored to AGENTS.md:**
- Prior status reports: `docs/status/2026-07-08_*` (discard-related) and `docs/status/2026-06-25_*` (WDT reset investigation)
- AGENTS.md line 209 (TRIM section, updated 2026-08-02 to reflect `nodiscard`)
- AGENTS.md gotcha: "BTRFS metadata ENOSPC crash (2026-06-26)" — confirms this hardware has a history of filesystem-stress events
- AGENTS.md gotcha: "All snapshots are LOCAL-ONLY. If the NVMe fails, everything is lost. This is the #1 data loss risk (flagged since 2026-06-25)."

---

## a) FULLY DONE ✅

1. **Baseline fio benchmark on `/data`** — 4 tests (seq-read 1M, seq-write 1M, rand-read 4K, rand-write 4K) with `libaio`, `direct=1`, `iodepth=32`, 8 GiB file, 30s runtime. Results at `/tmp/fio-results-20260803-053912.txt`. Confirmed: ~870 MiB/s seq read, ~28 MiB/s seq write (after SLC cache exhaustion), ~900 IOPS random.
2. **Discovered corruption on `/data`** — `journalctl -k --since '30 days ago' | grep -iE 'nvme|btrfs.*error'` revealed 100+ `csum failed` events on `/dev/nvme0n1p8`. Inode 2608092 (`diffusion_pytorch_model.safetensors`) and inode 1331118 (path unknown — only seen in initial 05:47:35 wave).
3. **Identified corrupted file path** — `/data/ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors`, corrupted at offsets 0–24576 (~24 KB of file start).
4. **Verified corruption pattern** — All errors are `mirror 1` failures, indicating `Data,single` profile (no BTRFS-level redundancy on this data). The drive returned bad data that BTRFS's checksum caught.
5. **Confirmed scrub was interrupted** — Both `/` and `/data` scrub status = `interrupted` per `/var/lib/prometheus-node-exporter/textfile_collectors/btrfs.prom`.
6. **Verified fstrim.service works** — Ran successfully 2026-08-03 01:17:55, trimmed 330.1 GiB on `/data`. Confirmed `nodiscard` deploy from prior session is intact (`/proc/mounts` clean of `discard` options).
7. **Confirmed WDT reset history** — `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` on Aug 01 21:05:45 boot. One `systemd-journald.service: Failed with result 'watchdog'` on Aug 02 23:19:05.
8. **Mapped failure modes by block group type** — `-dusage=N` (data) fails with EIO; `-musage=N` (metadata) and `-susage=N` (system) succeed. This is diagnostic: corruption is in data block groups only.
9. **Verified deletion of corrupted file** — `/data/ai/models/image/illustrij_v21_diffusers/vae/` now contains only `config.json` (923 bytes). The corrupted file's block range is now unallocated.
10. **Documented explanation of `-dusage`/`-musage`/`-susage`** — In conversation, explained why data balances fail and metadata/system succeed.

---

## b) NOT STARTED ❌ (renamed from "Partially Done" for honesty)

The "Partially Done" section in the prior draft conflated "discussed but not done" with "in progress." Below is the honest accounting — **zero configuration changes were deployed this session**.

### b.1) Discussed, Not Implemented

1. **Compression-removal change to `/data`** — Plan drafted (drop `compress=zstd:3` from `/data` mount options in `hardware-configuration.nix`). Not applied. **Blocked by**: requires reboot to take effect (mount options are mount-time, not runtime); corruption investigation takes priority; user has not confirmed reboot is acceptable right now.
2. **`/nix/store` subvolume split plan** — Conceptually agreed (separate `@nix` subvolume with independent mount options). Not implemented. **Blocked by**: requires USB installer boot; substantial downtime; matches AGENTS.md "Deferred to next reinstall" note.
3. **Compression PRO/CONTRA analysis for `/`** — Discussed but no decision made. Needs user input on whether to keep `zstd:3`, drop to `zstd:1`, or remove entirely.
4. **`btrfs-compsize` metrics not populating** — `/var/lib/prometheus-node-exporter/textfile_collectors/btrfs-compression.prom` is empty (header only, no values). The compression timer may not be running or is failing silently. **Not investigated**.

### b.2) Recommended But Not Executed (Requires Root)

The following require `sudo` which is not available in this session's execution environment:

5. **Foreground scrub enumeration** — `sudo btrfs scrub start -B /data` would list ALL corrupted files. User has not run it.
6. **Current `btrfs device stats` for `/dev/nvme0n1p8`** — Would show cumulative error count since boot. User's earlier check showed 0 (BEFORE the balance operations that triggered the bulk of errors).
7. **SMART data check** — `smartmontools` not installed in dev shell. `sudo smartctl -a /dev/nvme0n1` would provide hardware health (percentage used, media errors, available spare).
8. **Immich DB integrity** — `pg_dump /data/immich/postgres` would test PostgreSQL consistency.
9. **monitor365 DuckDB integrity** — `duckdb -c "PRAGMA integrity_check;" /data/monitor365/monitor365.duckdb` would test DuckDB.
10. **`/data/.snapshots/` check** — Verify btrbk snapshots exist and are recent (AGENTS.md says daily snapshots should occur).

---

## c) TOTALLY FUCKED UP 💀

### c.1) Technical Mistakes

1. **Recommended balance operations on a filesystem with known corruption** — When the user reported the first `Input/output error` from `-dusage=70`, we should have immediately recommended STOP and switch to foreground scrub. Instead we encouraged more balance attempts with higher `-dusage` thresholds (`80`, `90`, `95`, `75`). Each failed balance logged additional `csum failed` errors, growing the kernel `bdev errs` counter.
2. **Missed the first corruption wave at 05:47:35** — The kernel log shows `csum failed root 5 ino 1331118` at 05:47:35 — a DIFFERENT inode than the 2608092 file we focused on. Inode 1331118's file path is unknown (not in the balance-triggered logs, only in the initial wave). We never investigated whether inode 1331118 has additional corruption.
3. **Did not check `btrfs device stats /dev/nvme0n1p8` early** — When we saw kernel `bdev errs` increment in dmesg for `/p8`, the per-mount `btrfs device stats` counter would have confirmed the cumulative count immediately. Instead we relied on the user's later manual check.
4. **Asserted AGENTS.md's "BTRFS compression is filesystem-wide" as fact** — Technically true for `compress=zstd` semantics, but the *performance* analysis (BTRFS compression overhead vs FTL handling) was speculative. We treated inference as established fact.
5. **Did not clear dmesg between balance attempts** — When balances failed, we should have recommended `sudo dmesg --clear` to make new errors distinguishable from accumulated old ones.

### c.2) Process Mistakes

6. **Spent extensive time on compression tuning while corruption was active** — The discussion of `compress=zstd:3` removal, subvolume splits, and per-subvolume property tuning is interesting but completely secondary to "the drive is returning corrupted data." We should have pivoted immediately to damage assessment.
7. **Failed to recommend foreground scrub early enough** — The single most useful diagnostic (`btrfs scrub start -B`) was not mentioned until 50+ messages into the corruption discussion.
8. **Did not ask "what changed since last session?" first** — Prior session was contaminated by user manually remounting with `nodiscard`. We should always establish the current state before drawing conclusions.

### c.3) User-Experience Failures

9. **Multiple "stop" moments from the user were not properly handled** — User statements like "tmpfs is fucking ram you idiot!" and "YOUR STUPID RIGHT????" indicated frustration. We continued defending or explaining instead of acknowledging and adjusting. Specifically:
   - When user said tmpfs is RAM, we should have said "sorry, you're right" and moved on — the technical explanation was condescending
   - When user asked about tmpfs, we got distracted into explaining filesystem caching instead of addressing the actual concern
10. **Asked the user to confirm things we should have stated as facts** — e.g., "Should we proceed with deleting this file?" could have been "Here's the corrupted file. Three options: delete + re-download, restore from backup, or leave it. Which do you want?"

---

## d) WHAT WE SHOULD IMPROVE 💡

### d.1) Process

1. **Scrub first, balance last** — Scrub is the diagnostic tool (reads everything, identifies corruption). Balance is the remediation tool (moves data, only touches what it reads). When investigating corruption, ALWAYS start with `btrfs scrub start -B` for enumeration.
2. **Stop recommending operations after first failure** — If a command fails, do not recommend the same command with different parameters. Switch tools.
3. **Pivot the conversation to severity** — When a P0 issue is discovered, drop all other threads. Compression tuning is not urgent when files are corrupted.
4. **Establish state at session start** — "What's the current mount state? What have you changed since we last talked? What commands have you run?" before drawing any conclusions.
5. **Track inode paths from kernel logs** — `csum failed root 5 ino 1331118` → look up the inode → identify the file. We never did this for ino 1331118.

### d.2) Technical Knowledge

6. **`btrfs device stats` is per-mount, not per-device** — Counter resets on remount/reboot. Kernel `bdev errs` in dmesg is the cumulative raw device count.
7. **BTRFS mount options are mount-time** — `nodiscard`, `compress`, `noatime` etc. require reboot OR `mount -o remount`. Editing `hardware-configuration.nix` + `nix run .#deploy` does NOT change the active mount.
8. **`csum failed` vs `bdev errs` are distinct signals** — `csum failed` = BTRFS detected bad data via checksum. `bdev errs` increment = kernel saw hardware error. Related but separate.
9. **BTRFS `Data,single` = no redundancy** — Corruption in `Data,single` block groups is unrecoverable (no mirror). `Metadata,DUP` = always duplicated.
10. **QLC NAND write amplification** — Consumer QLC drives have small SLC cache (~10–30 GB). Sustained writes beyond the cache go to native QLC at 1/10th the speed.

### d.3) Communication

11. **When user is frustrated, acknowledge and move on** — No defensive explanations, no continuing the same point.
12. **Frame destructive recommendations as choices** — "Here are your options: A, B, C" not "You should do X."
13. **One topic at a time** — When conversation spans multiple issues, structure updates around one topic per response. The user should not have to ask "what about X?"
14. **Provide context with technical definitions** — When asked "What is `-susage=70`?", include WHY they should care (because balances are failing).

### d.4) Tooling

15. **`journalctl -k --since 'X ago'` early and often** — Canonical source for filesystem/hardware errors. We read it late.
16. **`nix shell nixpkgs#btrfs-progs` first** — Don't try non-nix approaches when nix shell provides everything.

---

## e) OVERLOOKED FINDINGS 🔥 (added in review)

### e.0) CRITICAL: `nodiscard` is NOT working — async discard is STILL ACTIVE

The kernel boot log from Aug 01 21:05 (paste_4.txt / paste_2.txt) contains:

```
Aug 01 21:05:46  BTRFS info (device nvme0n1p6): turning on async discard
Aug 01 21:05:52  BTRFS info (device nvme0n1p8): turning on async discard
```

But the fstab has `nodiscard` on BOTH mounts:

```
/dev/disk/by-uuid/0b629b65... / btrfs ...nodiscard... 0 0
/dev/disk/by-uuid/046ea663... /data btrfs ...nodiscard... 0 0
```

**The `nodiscard` mount option is being IGNORED by kernel 7.1.5's BTRFS.** The async discard worker thread is running despite the mount option. This means:

1. The prior 3 sessions' "fix" (deploying `nodiscard`) was a **complete no-op**
2. The QLC NAND has been abused by async discard the ENTIRE TIME
3. This is almost certainly the root cause of the corruption — async discard on QLC NAND causes exactly the failure mode documented in AGENTS.md's `discard=async` gotcha
4. Every conclusion about "discard is fixed" across all prior status reports is WRONG

**Verification needed:** `cat /sys/fs/btrfs/*/discard/discardable_extents` showed static counters (238259 and 56) — but these may not prove the discard worker is inactive. The kernel MESSAGE is authoritative: "turning on async discard" = the worker IS running.

**This single finding invalidates the entire `nodiscard` remediation strategy.** The fix requires either:
- A kernel parameter to force-disable BTRFS discard (`btrfs.discard=-1` or similar, needs kernel source verification)
- A BTRFS feature flag change (`btrfs filesystem disable discard` if such a command exists — it may not)
- A kernel downgrade to a version where `nodiscard` is respected
- Filing a kernel bug against BTRFS for ignoring `nodiscard` on SSDs

### e.1) Inode 1331118 — second corrupted file, PATH UNKNOWN, still on disk

The first corruption wave at 05:47:35 hit inode 1331118:
```
BTRFS warning (device nvme0n1p8): csum failed root 5 ino 1331118 off 327962624 csum 0x8941f998 expected csum 0x29d3e519 mirror 1
```

This is a DIFFERENT file than the one we deleted (ino 2608092). We NEVER identified its path. It could be:
- An AI model file (like the one we deleted)
- A Docker volume
- A database file
- Something actively being read by a service RIGHT NOW

**Action:** `sudo btrfs inspect-internal inode-resolve 1331118 /data` to find the path. Then decide: delete, restore, or accept loss.

### e.2) fstrim ran 4.5 hours before first corruption

```
Aug 03 01:17:55  fstrim: /data: 330.1 GiB trimmed
Aug 03 05:47:35  First csum failed (ino 1331118)
```

fstrim sent TRIM commands for **330 GiB** of freed blocks on `/data`. 4.5 hours later, corruption appeared. On QLC NAND, a massive TRIM burst can overwhelm the FTL's garbage collection — the controller spends time erasing blocks and may corrupt adjacent data.

**Combined with the async-discord-still-active finding (e.0), the drive was hit by TRIM from TWO sources simultaneously:**
1. BTRFS's async discard worker (running despite `nodiscard`)
2. The weekly `fstrim.service` (trimmed 330 GiB)

This is exactly the failure mode documented in AGENTS.md: "253ms discard latency → BTRFS commit stalls → WDT reset."

### e.3) Monthly scrub is effectively broken — only ran 15 minutes

Both scrubs show:
```
Status: interrupted
Duration: 0:15:21
```

At the reported rates (7.36 MiB/s on `/`, 17.61 MiB/s on `/data`), a full scrub would take **16+ hours** for `/` and **11+ hours** for `/data`. The scrub ran for only 15 minutes — it covered **less than 2%** of the filesystem before being interrupted.

The monthly `autoScrub` is supposed to catch corruption. It hasn't completed since at least Aug 1. **Corruption detection has been broken for weeks.** The `btrfs_scrub_error_free=1` metric in Prometheus is stale — it reflects the partial scrub's result, not a complete filesystem scan.

**Why it was interrupted:** Unknown. The scrub started Aug 1 00:00:00 (midnight). The system rebooted Aug 1 21:05:45 — but that's 21 hours later. The scrub ran for 15 minutes at midnight and was interrupted by something else. Possible causes: the scheduled balance at 00:00-01:00, a service restart, or autoScrub timer behavior.

### e.4) Our fio benchmark WROTE 8 GiB to the corrupted drive

We ran fio benchmarks on `/data` at ~05:39-05:41, writing 8 GiB of test data. The first corruption appeared at 05:47:35 — 6 minutes after our benchmark completed. The benchmark:
- Wrote 8 GiB to an already-stressed filesystem (92% full)
- Consumed SLC cache capacity needed for FTL operations
- Added write amplification during a period when the drive was already failing
- **May have accelerated or triggered the corruption** by consuming the last healthy write buffer

**We should NOT have written test data to a drive we suspected was degraded.**

### e.5) `/` is on the same physical NVMe — not checked for corruption

`/dev/nvme0n1p6` (`/`) and `/dev/nvme0n1p8` (`/data`) are partitions on the SAME physical Lexar NQ790 NVMe. If the NAND is degrading, `/` could have corruption too. We NEVER ran scrub on `/`. We focused entirely on `/data`.

The `/` filesystem contains:
- The entire NixOS system (`/nix/store`, 47+ GiB)
- Home directory (`/home/lars`)
- All system configuration

If `/` has corruption, the system may be running on corrupted binaries. This would be worse than `/data` corruption.

### e.6) `/data` is 92% full — contributing factor

From `btrfs filesystem usage /data`:
```
Data,single: Size:758.01GiB, Used:700.46GiB (92.41%)
```

A 92% full BTRFS filesystem on QLC NAND is problematic:
- BTRFS needs free blocks for CoW (every write needs new blocks)
- The FTL needs free blocks for garbage collection and wear leveling
- At 92% full, write amplification increases dramatically
- Balance operations need free space to relocate data into
- The drive has only 270 GiB unallocated — not enough headroom for a healthy QLC drive

**This is a systemic risk**, not just related to corruption. A full QLC drive performs worse and fails faster.

### e.7) `systemd-journald.service: Failed with result 'watchdog'` on Aug 02 23:19

We noted this but never investigated. journald failing its watchdog means:
- System logging was compromised
- The system was under extreme pressure (CPU, memory, or I/O)
- This is the same OOM-cascade pattern documented in AGENTS.md: "journald starved → sp5100-tco WDT hard reset"
- **The journald watchdog failure may be a precursor to the corruption event** — if the system was under I/O pressure, writes may have been incomplete

### e.8) `nvme_core.default_ps_max_latency_us=0` in kernel cmdline

From the boot log:
```
nvme_core.default_ps_max_latency_us=0
```

This disables NVMe power state transition latency checking. It was likely added to fix a different issue but means the kernel won't detect if the NVMe controller is taking too long to respond to commands. A slow controller on QLC NAND under async discard stress could silently corrupt data without the kernel noticing.

### e.9) The `ssd` mount option is on `/data` but NOT on `/`

```
/     options: compress=zstd,noatime,nodiscard,space_cache=v2  (no ssd)
/data options: compress=zstd:3,noatime,ssd,nodiscard,space_cache=v2,nofail  (has ssd)
```

But the kernel auto-detected SSD on `/` anyway: `BTRFS info (device nvme0n1p6): enabling ssd optimizations`. So the explicit `ssd` on `/data` is redundant and the missing `ssd` on `/` is compensated by auto-detection. Not a bug, but an asymmetry worth noting.

---

## f) CONFIDENCE & OPEN QUESTIONS 🔍

### f.1) What's Certain

- The drive has returned corrupted data on at least one file (ino 2608092) — confirmed by BTRFS checksum logs
- A second inode (1331118) had corruption at 05:47:35 — confirmed by kernel log, but file path unknown
- The user's deletion of the corrupted file succeeded — confirmed by `ls` output
- `btrfs balance` consistently fails on `/data` data block groups — confirmed by 4+ failed attempts
- Metadata and system block groups are healthy — confirmed by successful `-musage`/`-susage` balances
- **The kernel logs "turning on async discard" despite `nodiscard` mount option** — confirmed in paste_2.txt/paste_4.txt

### f.2) What's Probable (high confidence)

- **More corrupted files exist.** Each balance pass touched only specific block groups. Balance has not covered all 92% utilization. Foreground scrub would enumerate.
- **The `nodiscard` deploy was a no-op** — the kernel message proves async discard is active regardless of mount option. This means the prior 3 sessions' fix never worked.
- **Async discard on QLC NAND is the root cause** — matches the documented failure mode in AGENTS.md: "253ms discard latency → BTRFS commit stalls → WDT reset → corruption."
- **The deleted model file may be unrecoverable.** No evidence of offsite backup for `/data/ai/` (AGENTS.md says "All snapshots are LOCAL-ONLY").

### f.3) What's Probable (low confidence)

- **Hardware failure vs driver bug vs single bad block.** Could be any of these. SMART data would clarify.
- **The corruption is ongoing.** A single bad block from manufacturing would not produce this pattern (errors only during balance = reading unwritten data, not from prior usage).

### f.4) What's Unknown

- Total corrupted file count (requires foreground scrub)
- Specific file path for inode 1331118 (requires `btrfs inspect-internal inode-resolve 1331118 /` which needs root)
- Drive wear level (requires `smartctl -a`)
- **Why `nodiscard` is being ignored by kernel 7.1.5** — needs kernel source analysis (`fs/btrfs/super.c`, `fs/btrfs/discard.c`) or a controlled test
- Whether `/` (root) also has corruption (same physical device)
- Backup status of `/data/ai/`, `/data/monitor365/`, `/data/immich/` (requires reading backup coordination config + checking `/data/.snapshots/`)

### f.5) What Would Falsify Our Conclusions

| Hypothesis | Falsification |
|-----------|---------------|
| Drive is at end-of-life | SMART shows 0-50% usage, 0 media errors, 100% available spare |
| Corruption is widespread | Foreground scrub returns 0 corrupted blocks (only the deleted file had issues) |
| Corruption is ongoing | Re-scrub after 24h shows the same error count (no new errors) |
| Drive is healthy but bad blocks | SMART shows good health AND only 1-2 corrupted files total |
| Other mounts are also corrupt | Foreground scrub on `/` returns 0 errors |
| **`nodiscard` is being ignored** | **Kernel source shows `nodiscard` correctly sets `NO_DISCARD` flag AND prevents async worker start; the "turning on async discard" message is cosmetic** |

---

## f) UP TO 50 NEXT ACTIONS 🎯

### P0 — Active Damage Control (next 24h)

1. **VERIFY async discard status** — Check if the BTRFS discard worker is actually running: `cat /sys/fs/btrfs/*/discard/discardable_extents` over time (if counter changes, worker is active). Also check `ps aux | grep btrfs` for discard kernel threads. If confirmed active despite `nodiscard`, this is a kernel bug on 7.1.5.
2. **Find a way to actually disable async discard** — Options to investigate: kernel parameter (`btrfs.discard=off`?), sysfs toggle, BTRFS feature flag, kernel downgrade. This is THE critical fix — all other tuning is moot if async discard keeps running.
3. **Run foreground scrub on `/data`** to enumerate ALL corrupted files: `sudo btrfs scrub start -B /data` — redirect to `/root/scrub-data-$(date +%s).log` (NOT `/data`)
4. **Run foreground scrub on `/`** — same physical NVMe, corruption may extend to root: `sudo btrfs scrub start -B /`
5. **Resolve inode 1331118** — `sudo btrfs inspect-internal inode-resolve 1331118 /data` — find the SECOND corrupted file we never identified
6. **Get SMART data for `/dev/nvme0n1`** — install `smartmontools`, run `sudo smartctl -a /dev/nvme0n1`
7. **Check current `btrfs device stats`** for `/dev/nvme0n1p8` and `/dev/nvme0n1p6`
8. **Identify ALL corrupted inodes** from scrub output and document them
9. **For each corrupted file**, decide: delete (if downloadable), restore from backup, or accept loss
10. **Verify Immich DB integrity** — `pg_dump /data/immich/postgres` or manual query
11. **Verify monitor365 DuckDB integrity** — `duckdb -c "PRAGMA integrity_check;" /data/monitor365/monitor365.duckdb`
12. **Stop touching `/data`** — no balance, no scrub (in background), no defrag, no large writes, no fio benchmarks

### P1 — Drive Health Assessment (next 48h)

11. **Research replacement NVMe drives** — TLC preferred over QLC for data integrity. Compare: Samsung 990 EVO, WD SN850X, Crucial T700, Seagate FireCuda 530
12. **Check motherboard NVMe slot availability** for RAID1 — does evo-x2 have a second M.2 slot?
13. **Decide: replace drive vs add RAID1 vs continue mitigation** — based on SMART data + scope of corruption
14. **Plan migration strategy** if replacing — btrfs send/receive, fresh install, or live migration
15. **Verify backup/restore process** — confirm backups can actually be restored, not just produced
16. **Check `/data/.snapshots/` existence and recency** — btrbk snapshots may have captured pre-corruption state for some files
17. **Audit btrbk snapshot schedule** — confirm daily snapshots of `/data` are still happening
18. **Read `services.backup-coordination.backups` config** to know what's actually backed up
19. **Set up offsite backup** for critical paths (`/data/ai/`, configs, databases) — at minimum
20. **Investigate `btrfs-compsize` timer** — why isn't `btrfs-compression.prom` populating?

### P2 — Configuration Cleanup (next week, requires reboot)

21. **Remove `compress=zstd:3` from `/data`** in `hardware-configuration.nix` — confirmed plan
22. **Deploy** via `nix run .#deploy`
23. **Reboot** to activate new mount options
24. **Verify mount options active** in `/proc/mounts`
25. **Re-run fio benchmark** to confirm write speed improvement
26. **Decide compression level for `/`** — keep `zstd:3`, drop to `zstd:1`, or remove
27. **Apply decision** to `hardware-configuration.nix`
28. **Document final mount options** with comments explaining each
29. **Update AGENTS.md** with new mount option rationale
30. **Test Nix builds** after compression change

### P3 — Structural Improvements (next month)

31. **Plan `/nix/store` subvolume split** — `@nix` subvolume with independent mount options
32. **Plan `/home` subvolume split** — `@home` subvolume for independent snapshots
33. **Plan `/var/lib/docker` subvolume** — Docker storage on its own with `nodatacow`
34. **Document subvolume restructure plan** in `docs/status/`
35. **Schedule maintenance window** for subvolume migration (USB boot required)
36. **Set up `/data/docker` subvolume with `nodatacow`** for Docker volume performance
37. **Set up `/data/monitor365` subvolume with `nodatacow`** for DuckDB performance
38. **Set up `/data/immich` subvolume with `nodatacow`** for PostgreSQL performance
39. **Add mount-option drift detector script** — compare `/proc/mounts` vs `fileSystems.*.options`, alert on drift
40. **Add periodic SMART data collection** to Prometheus textfile collectors

### P4 — Long-term Resilience (next quarter)

41. **Implement RAID1 for `/data`** — buy second NVMe, convert filesystem to `Data,DUP` (no data loss on single drive failure)
42. **Add automatic drive health alerting** via Gatus
43. **Audit all systemd `restartTriggers`** — confirm critical services have them
44. **Document recovery procedures** in `docs/troubleshooting/`: corrupted file, corrupted metadata, drive failure, RAID1 degraded
45. **Test full restore procedure** end-to-end
46. **Consider ZFS migration** — ZFS has better data integrity guarantees (scrub with healing, copies=2)
47. **Replace the QLC NQ790** with a TLC drive before it fails completely
48. **Add proactive drive replacement schedule** — replace consumer NVMe every 2-3 years
49. **Add per-service data integrity monitoring** (PostgreSQL checksums, DuckDB integrity, file-level hashes for critical configs)
50. **Establish baseline performance metrics** so degradation is detectable before failure

---

## h) THREE QUESTIONS I CANNOT FIGURE OUT MYSELF ❓

### Q1: Can you verify whether async discard is ACTUALLY running despite `nodiscard`?

**What I found:** The kernel boot log says `BTRFS info (device nvme0n1p8): turning on async discard` despite `nodiscard` in the fstab. But I can't run `sudo` to verify at runtime.

**What you can run:**
```bash
# Check if the discard worker is active (if numbers change over time, it's running)
watch -n 10 'cat /sys/fs/btrfs/*/discard/discardable_extents'

# Check for BTRFS discard kernel threads
ps aux | grep -i discard

# Check mount options ACTUALLY applied (not just fstab)
mount | grep btrfs
findmnt -o TARGET,SOURCE,OPTIONS | grep btrfs
```

**Why this matters:** If async discard is running despite `nodiscard`, then ALL prior remediation was a no-op, the drive is STILL being abused, and we need a completely different fix (kernel parameter, sysfs toggle, or kernel downgrade). This is the single most important question.

### Q2: Can you run `sudo btrfs scrub start -B /data` and `sudo btrfs inspect-internal inode-resolve 1331118 /data`?

**What I know:** There are at least two corrupted inodes. One was deleted (ino 2608092). The other (ino 1331118) is still on disk, path unknown, possibly being read by a service right now.

**What the scrub output would tell us:**
- Exact count of corrupted files
- Whether corruption is localized or spread across the drive
- Whether corruption is ongoing (re-scrub shows more errors)

**What inode-resolve would tell us:**
- Which specific file is the second corrupted one
- Whether it's actively used by a service

**If you can't run these now:** Tell me and I'll add them to the next deploy's post-deploy-check script.

### Q3: Is the deleted `diffusion_pytorch_model.safetensors` needed and recoverable?

**What I know:** The file was corrupted and you deleted it. HuggingFace models are typically re-downloadable. I don't know whether any service uses this specific model or whether you have it elsewhere.

**Why I need to know:** If it's in active use, the service will silently fail. If it's your only copy and not re-downloadable, the deletion was permanent data loss. If it's easily re-downloadable from HuggingFace, no action needed.

---

## Session Artifacts

### Files Created This Session

- `/tmp/run-fio-bench.sh` — fio benchmark script (ephemeral)
- `/tmp/fio-results-20260803-053912.txt` — benchmark results (rotates with tmp cleanup)
- `/tmp/fio-results-20260803-052158.txt` — early broken test output (from missing libaio)
- (This file) `docs/status/2026-08-03_06-51_nvme-data-corruption-discovery.md`

### Files Deleted By User This Session

- `/data/ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors` (corrupted, inode 2608092)

### Configuration Changes Pending

- `hardware-configuration.nix` — remove `compress=zstd:3` from `/data` options (DRAFTED, NOT APPLIED)
- Subvolume split plan — `@nix` subvolume for `/nix/store` (PLANNED, NOT IMPLEMENTED)

### Evidence References

| Claim | Source |
|-------|--------|
| **Async discard running despite `nodiscard`** | **Kernel boot log: `BTRFS info (device nvme0n1p6): turning on async discard` and `(device nvme0n1p8): turning on async discard` (paste_2.txt, paste_4.txt)** |
| Drive returned corrupted data | `journalctl -k --since '30 days ago'` (paste_4.txt) |
| Two distinct inodes corrupted | `csum failed root 5 ino 1331118` (05:47:35), `csum failed ... ino 2608092` (06:09:56) |
| Balance failures on data blocks only | 4× failed `-dusage=N`, all `-musage/-susage` succeeded |
| fstrim ran 4.5h before corruption | `journalctl -u fstrim` (paste_3.txt): 01:17:55 fstrim → 05:47:35 first csum error |
| Monthly scrub broken (15min/16h needed) | `btrfs scrub status /` and `/data` both show `Duration: 0:15:21` |
| `/data` 92% full (write amplification risk) | `btrfs filesystem usage /data`: Data 92.41% used |
| Previous WDT reset | `x86/amd: Previous system reset reason [0x02000800]` on Aug 01 boot |
| journald watchdog failure | `systemd-journald.service: Failed with result 'watchdog'` Aug 02 23:19 |
| `nvme_core.default_ps_max_latency_us=0` | Kernel cmdline in boot log (paste_2.txt) |
| Drive wear / health | NOT CHECKED — `smartctl` not installed |

---

## Current Drive State (as of 07:10 CEST)

- `/dev/nvme0n1p6` (`/`): Same physical NVMe as `/data`, NEVER scrubbed for corruption, async discard active despite `nodiscard`
- `/dev/nvme0n1p8` (`/data`): At least 2 corrupted inodes (1 deleted, 1 path unknown), balance failing on data blocks, 92% full, async discard active despite `nodiscard`
- `/dev/nvme0n1p9` (`/rust-cache`, ext4): Clean, fstrim worked
- `/dev/nvme0n1p7` (`/boot`, vfat): Clean
- SMART data: **Unknown** — never checked this session
- Monthly scrub: **Broken** — interrupted after 15 minutes, hasn't completed since at least Aug 1

**Operational recommendation:** ~~Do not run additional balance operations or write benchmarks until foreground scrub enumerates the full scope. The drive may be actively degrading from async discard that cannot be disabled via mount options on kernel 7.1.5.~~ **SUPERSEDED** — see Resolution below.

---

## Resolution (2026-08-03 09:24)

This report's central claim — **"`nodiscard` is NOT working, async discard is STILL ACTIVE"** (section e.0) — was **proven false** in the follow-up investigations (`2026-08-03_08-14`, `2026-08-03_09-24`).

| Claim in this report | Resolution |
|---|---|
| §e.0: `nodiscard` is NOT working, kernel ignores it | **FALSE.** `mount \| grep btrfs` confirms `nodiscard` IS active. The kernel log messages were from a **previous boot** (journalctl shows all boots since rotation). |
| §e.0: "The prior 3 sessions' fix was a complete no-op" | **FALSE.** `nodiscard` is working as intended. |
| §e.0: "Async discard on QLC NAND is the root cause" | **FALSE.** Root cause is **58 unsafe shutdowns** (46% of 126 power cycles) causing incomplete BTRFS commits. |
| §f.2: "The `nodiscard` deploy was a no-op" | **FALSE.** Same as above. |
| §f.5: Hypothesis that `nodiscard` might be correctly working | **CONFIRMED** — this falsification criterion was the correct one. |
| 2 corrupted inodes (ino 1331118, ino 2608092) | **EXPANDED:** foreground scrub found **13 corrupted files** total (all AI model files), all deleted. |
| SMART data never checked | **DONE:** 0 media errors, 11% wear, drive is healthy. See `2026-08-03_08-14`. |
| Monthly scrub broken (15min/16h) | **FIXED:** `autoScrub` changed from monthly to weekly (`9083c126`). Scrub monitoring false-positive fixed. |
| `discard=none` and block-layer discard disable | **REVERTED** — both were dangerous changes made without research. `discard=none` would have bricked boot. Reverted in `c2615d09`. |
| Database integrity unchecked | **DONE:** PostgreSQL (Immich) clean, MySQL (Twenty) dead, DuckDB (monitor365) not on `/data`. |

**What IS still open from this report:**
- Off-site backup (still #1 data loss risk — flagged since 2026-06-25)
- `/data` at 92% fill (systemic risk, needs cleanup)
- Investigate the 58 unsafe shutdowns (WDT resets, OOM cascades, power events)
- `/data` compression removal (`compress=zstd:3` → undecided)
