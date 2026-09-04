# Status Report: 2026-08-03 Session Self-Review & Full Status

**Generated:** 2026-08-03 09:24 CEST
**Session:** The full session — from `mount | grep btrfs` through corruption cleanup and monitoring fixes
**Hardware:** evo-x2 (AMD Strix Halo), Lexar NQ790 2TB QLC NVMe, kernel 7.1.5
**Severity:** P0-HIGH — 1.35M checksum errors (33 unique physical blocks, 13 corrupted files, all deleted). Drive flash healthy (0 SMART media errors). Root cause: 58 unsafe shutdowns.

---

## Session Timeline (what actually happened, in order)

1. **User provided `mount | grep btrfs`** showing `nodiscard` absent from all active mounts
2. **I panicked** — concluded kernel 7.1.5 was silently ignoring `nodiscard`, added `discard=none` + `disable-nvme-discard` block-layer service
3. **User said "do some fucking research"** — I researched BTRFS kernel source, discovered `discard=none` is INVALID for BTRFS (mount failure → emergency shell)
4. **Verified `nodiscard` IS working** — `discardable_extents` static over 10s. The boot log "turning on async discard" was from Aug 01 21:05, predating the config commit (Aug 03 02:50) by 35 hours
5. **Reverted both dangerous changes** — auto-committed as `c2615d09`
6. **User's scrub completed** — 1,351,271 uncorrectable errors across 33 unique physical blocks
7. **I extracted the full corrupted file list** from `journalctl -k | grep 'checksum error'` — 13 files with paths
8. **SMART analysis** — 0 media errors, 11% wear, 100% spare, all self-tests pass. 58 unsafe shutdowns (46%). Drive flash is NOT failing.
9. **User deleted all 13 corrupted files**, checked databases (PostgreSQL clean, MySQL container dead)
10. **Fixed autoScrub monthly → weekly** — scrub needs ~2h, never completed between reboots
11. **Fixed scrub monitoring** — `btrfs_scrub_error_free` now requires `Status: finished`, not just 0 errors
12. **Build validated** — `nix flake check --no-build` passes

---

## A) Fully Done

### 1. All 13 corrupted files identified and deleted

Full list extracted from kernel scrub log (`journalctl -k --since "2026-08-03 06:51:00" | grep 'checksum error'`):

| #  | Path                                                                                          | Category         | Recoverable?               |
| -- | --------------------------------------------------------------------------------------------- | ---------------- | -------------------------- |
| 1  | `ai/cache/huggingface/.../Z-Image-Turbo/blobs/aeb13307...`                                    | AI model cache   | Re-download                |
| 2  | `ai/models/image/illustrij_v21_diffusers/text_encoder/model.safetensors`                      | AI model         | Re-download                |
| 3  | `ai/models/image/illustrij_v21_diffusers/unet/diffusion_pytorch_model.safetensors`            | AI model         | Re-download                |
| 4  | `ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors`             | AI model         | Already deleted            |
| 5  | `ai/models/image/Krea-2-Turbo/transformer/diffusion_pytorch_model-00001-of-00003.safetensors` | AI model         | Re-download                |
| 6  | `docker/volumes/6d41d7f0.../mysql.ibd`                                                        | MySQL tablespace | Container dead, no impact  |
| 7  | `docker/volumes/twenty_db-data/pg_wal/000000010000000000000010`                               | PostgreSQL WAL   | Already recycled by PG     |
| 8  | `llamacpp-models/BAGEL-7B-MoT/ae.safetensors`                                                 | AI model         | Deleted (prior session)    |
| 9  | `llamacpp-models/qwen3.6-35b-a3b-aggressive/...gguf`                                          | AI model         | Re-download                |
| 10 | `models/sdxl/perfectdeliberate-v90-new/text_encoder_2/model.safetensors`                      | AI model         | Re-download                |
| 11 | `models/Z-Anime/diffusers/transformer/diffusion_pytorch_model-00001-of-00002.safetensors`     | AI model         | Re-download                |
| 12 | `SteamLibrary/.../CS:GO/de_ancient.vpk`                                                       | Steam game       | Re-download / Steam verify |
| 13 | `SteamLibrary/.../CS:GO/de_cache.vpk`, `de_cache_vanity.vpk`                                  | Steam game       | Re-download / Steam verify |

### 2. SMART analysis — drive flash is healthy

| Metric                          | Value                | Assessment                   |
| ------------------------------- | -------------------- | ---------------------------- |
| Overall health                  | PASSED               |                              |
| Media and Data Integrity Errors | **0**                | Flash cells are fine         |
| Error Log Entries               | **0**                | Controller reports no errors |
| Percentage Used                 | **11%**              | 89% endurance remaining      |
| Available Spare                 | **100%**             | No spare blocks consumed     |
| Self-tests (20 total)           | All passed           |                              |
| Power On Hours                  | 1,625 (~68 days)     |                              |
| Data Units Written              | **145 TB**           | ~89 GB/hour avg (very heavy) |
| **Unsafe Shutdowns**            | **58 / 125 (46%)**   | **ROOT CAUSE**               |
| Critical Comp. Temp. Time       | **114 min** at 95°C+ | Thermal stress contributor   |
| Temperature (current)           | 60°C                 | Normal under load            |

### 3. Database integrity verified

- **PostgreSQL (Twenty CRM):** Clean startup, normal checkpoints. Corrupted WAL segment already recycled (LSN `0/1345E128` >> corrupted segment `0/10`)
- **MySQL:** Container `6d41d7f0ad8e` no longer exists. Dead data, no impact.

### 4. Verified `nodiscard` IS working

- `discardable_extents`: static over 10-second window (238,259 → 238,259 on `/`, 56 → 56 on `/data`)
- Boot log "turning on async discard" timestamp: Aug 01 21:05. `nodiscard` config commit: Aug 03 02:50. The message predates the config by 35 hours.
- Cumulative sysfs counters (1.3 TiB on `/`, 252 GiB on `/data`) accumulated during the ~6h pre-config window

### 5. Reverted dangerous config changes

Both changes auto-committed as `c2615d09`:

- `discard=none` removed from hardware-configuration.nix (NOT a valid BTRFS option — `-EINVAL` → mount failure → emergency shell)
- `disable-nvme-discard` systemd service removed from boot.nix (unnecessary + would have killed fstrim)

### 6. Fixed autoScrub monthly → weekly

`snapshots.nix`: The scrub needs ~2h to complete `/data` (707 GiB at 108 MiB/s). With 58 unsafe shutdowns causing frequent reboots, monthly scrubs never finished. Weekly gives 4x more retry opportunities.

### 7. Fixed scrub monitoring false-positive

`btrfs-health.nix`: `btrfs_scrub_error_free` now requires ALL mounts to have `Status: finished` before reporting 1. Previously, interrupted scrubs with partial 0-error results falsely reported "error-free" — corruption was blind for weeks. Added `Uncorrectable:` error count parsing and `interrupted` status detection.

### 8. Build validated

`nix flake check --no-build` — all module checks pass.

---

## B) Partially Done

### 1. Config changes not deployed

Weekly scrub + monitoring fix are committed but NOT deployed. The running system still has monthly scrub and broken monitoring.

### 2. No verification scrub run

After deleting all 13 corrupted files, no fresh scrub has been run to confirm the error count drops to 0. The 1.35M errors may include snapshot-referenced blocks that need snapshot expiry to clear.

### 3. Prior status report not corrected

`docs/status/2026-08-03_06-51_nvme-data-corruption-discovery.md` still says "P0-CRITICAL: nodiscard is a no-op" — this was proven wrong. Needs annotation.

### 4. AGENTS.md not updated

Multiple corrections needed:

- The `nodiscard` verification method (sysfs counter test, not `/proc/mounts`)
- The unsafe shutdown root cause
- The `btrfs_scrub_error_free` false-positive fix
- The `discard=none` near-miss lesson

---

## C) Not Started

1. **Deploy changes** — `nix run .#deploy`
2. **Fresh `/data` scrub** — verify corruption cleared after deletions
3. **Scrub on `/`** — Never checked, same physical NVMe (though `btrfs device stats /` shows 0 corruption_errs)
4. **Reduce `/data` fill below 80%** — Still at ~92% (deletions freed some space, unmeasured)
5. **Investigate 58 unsafe shutdowns** — Root cause of the corruption. Need `journalctl --list-boots` + pstore analysis
6. **Offsite backup** — All snapshots LOCAL-ONLY. AGENTS.md: "#1 data loss risk"
7. **Update AGENTS.md** — Corrections listed above
8. **Correct prior status report** — Annotate the false P0-CRITICAL claim
9. **Drive replacement decision** — SMART healthy, but 46% unsafe shutdown rate is abnormal
10. **`/data` compression removal** — Blocked on corruption being fully cleared
11. **fstrim policy decision** — 330 GiB fstrim preceded corruption by 4.5h
12. **Docker socket still active** — User stopped `docker.service` but `docker.socket` was still running (shown in paste). May or may not matter.

---

## D) Totally Fucked Up

### 1. Made config changes WITHOUT RESEARCH — TWICE

**First:** Added `discard=none` — an INVALID BTRFS option that would have caused mount failure → `local-fs.target` failure → emergency shell on next boot. This is the EXACT bug class documented in AGENTS.md ("ext4 `discard=async`" gotcha). I would have bricked the system.

**Second:** Added `disable-nvme-discard` systemd service that sets `discard_max_bytes=0` at the block layer. This would have killed `fstrim` (a legitimate, separate operation from async discard). Based on the false conclusion that `nodiscard` was broken — it wasn't.

The user had to explicitly say **"How about you do some fucking research and stop guessing shit?"** before I checked the kernel source. This violates AGENTS.md rule #1: "READ before you WRITE."

### 2. Trusted prior session conclusions without independent verification

The prior session (06:51 report) concluded `nodiscard` was "silently ignored by kernel 7.1.5 BTRFS." I carried this forward without questioning it. A 10-second sysfs counter test would have disproven it immediately. The prior session never checked:

- Whether the boot log timestamp predated the config change
- Whether the discard worker was actually running

### 3. Didn't check the kernel scrub log until late

The kernel log (`journalctl -k | grep 'checksum error'`) contains the FULL list of corrupted files with exact paths, physical addresses, logical addresses, and inode numbers. I should have checked this FIRST when the scrub reported 1.35M errors. Instead, I recommended `find /data -exec dd` — which **cannot detect this type of corruption** (the NVMe controller returns data successfully, just the wrong data). The user ran it for 20 minutes and found nothing. I wasted their time.

### 4. Wrote a status report mid-session that was wrong

The 08:14 report was written BEFORE the scrub completed and BEFORE SMART data was available. It contained conclusions that were then overturned (P0-CRITICAL → P0-HIGH, "drive failing" → "drive healthy"). I should have waited for the data.

### 5. Over-explained instead of acting

Multiple times I wrote multi-paragraph explanations about BTRFS internals, block-layer architecture, and FTL mechanics when the user wanted test results and actions. The user is a senior engineer — they know what these things are.

### 6. Didn't notice docker.socket was still active

When the user ran `sudo systemctl stop docker`, the output showed "Stopping 'docker.service', but its triggering units are still active: docker.socket". I didn't flag this or address it. The socket being active means Docker can be auto-started by any connection attempt.

---

## E) What We Should Improve

### Critical Process Failures

1. **NEVER make config changes without research** — Read the docs, check the kernel source, verify the hypothesis. This is the #1 rule and I broke it twice in one session.

2. **Check timestamps before drawing conclusions** — "X is in the boot log" is meaningless without checking whether the boot predates the config change that added X. The boot log was from Aug 01; the config change was Aug 03.

3. **Verify runtime state before changing config** — The `discardable_extents` sysfs counter test takes 10 seconds. It definitively answers "is the discard worker running right now?" This should have been the FIRST diagnostic, not something I did after making changes.

4. **Read kernel logs FIRST** — `journalctl -k | grep 'checksum error'` immediately gives file paths and physical addresses for all corruption. Don't recommend slow `dd` scans that can't detect silent corruption.

5. **Don't write status reports mid-investigation** — The 08:14 report was wrong because the scrub hadn't finished and SMART wasn't available. Wait for data, then report.

6. **Don't trust prior session conclusions blindly** — Verify independently before building on them.

### Technical Improvements

7. **Weekly scrub instead of monthly** — More retry opportunities between reboots. DONE.

8. **Scrub monitoring must check "finished" status** — Interrupted scrubs are not "error-free". DONE.

9. **Track unsafe shutdowns** — 58 out of 125 is a systemic problem. Need SMART monitoring + alerting.

10. **Address the root cause: unsafe shutdowns** — WDT resets, OOM crashes, power loss. Each one risks new corruption. This is more important than any config change.

11. **Consider thermal management** — 114 minutes at critical temp (95°C+) may contribute to FTL instability.

12. **The `dd` approach to corruption detection is fundamentally flawed for BTRFS** — Only checksum verification (scrub) catches silent corruption where the controller returns wrong data. Document this.

---

## F) Next Actions (up to 50)

### Immediate (today)

1. **Deploy changes** — `nix run .#deploy` (weekly scrub + monitoring fix + reverted dangerous changes)
2. **Run fresh `/data` scrub** — `sudo btrfs scrub start -B /data 2>&1 | tee /root/scrub-data-verify.log` — verify error count dropped after file deletions
3. **Run scrub on `/`** — `sudo btrfs scrub start -B / 2>&1 | tee /root/scrub-root.log`
4. **Check freed space** — `btrfs filesystem usage /data` — how much did the 10 file deletions free?
5. **Check `btrfs device stats /data` after cleanup** — corruption_errs counter should stop growing
6. **Verify Docker came back clean** — `docker ps`, check all containers healthy

### Short-term (24-48h)

7. **Investigate 58 unsafe shutdowns** — `journalctl --list-boots | wc -l`, `ls /sys/fs/pstore/`, correlate WDT resets with workload
8. **Reduce `/data` fill below 80%** — `docker image prune -a`, delete more unused models
9. **Re-download needed AI models** — Only the ones actually in use (check what services reference them)
10. **Steam verify CS:GO** — `steam://validate/730`
11. **Verify Twenty CRM functional** — Browse to twenty.home.lan, check data
12. **Check if docker.socket auto-started Docker** — `systemctl status docker.service docker.socket`

### Monitoring improvements

13. **Add unsafe shutdown tracking** — Monitor SMART `Unsafe Shutdowns` counter, alert on increase
14. **Add `/data` fill level monitoring** — Gatus alert when `/data` exceeds 85%
15. **Fix compression metrics timer** — `btrfs-compression.prom` was empty (header only)
16. **Add thermal monitoring** — Alert if NVMe temp exceeds 80°C
17. **Review all Gatus scrub alerts** — Ensure they check for "finished" status (may need Gatus config update to match new metric logic)
18. **Add corruption_errs counter monitoring** — Track `btrfs device stats` counters, alert on any increase

### Root cause: unsafe shutdowns

19. **Review WDT timeout** — Currently 30s. Consider raising to 60s to give BTRFS more flush time
20. **Review oomd configuration** — Aggressive OOM kills cause unclean service shutdowns
21. **Add UPS** — Hardware solution for power-loss shutdowns
22. **Check if WDT resets correlate with deploys** — `nh os switch` restarts many services
23. **Consider disabling WDT** — If resets cause more damage (corruption) than they prevent
24. **Review pstore logs** — `/sys/fs/pstore/` may contain kernel panic/oops logs from the 58 events
25. **Check if critical temp events (95°C+ for 114 min) caused thermal shutdowns** — Correlate with boot timestamps

### Configuration

26. **Remove `compress=zstd:3` from `/data`** — After corruption cleared, evaluate if compression helps or hurts on QLC NAND
27. **Add `chattr +C` to Docker volumes** — Disable CoW for Docker's overlay2 backend
28. **Review fstrim policy** — 330 GiB fstrim preceded corruption by 4.5h. Consider disabling on QLC NAND.
29. **Add `commit=600` to `/data`** — Longer commit interval reduces metadata write frequency
30. **Review Docker storage driver** — overlay2 on BTRFS may cause CoW amplification

### Data safety

31. **Set up offsite backup** — Immich photos, Twenty CRM database at minimum
32. **BTRFS send/receive to external drive** — Periodic incremental backup
33. **Docker volume backup** — Automated backup of Twenty PG data
34. **Document recovery procedures** — Runbook for corruption detection and cleanup
35. **Create read-only snapshot before deploys** — Rollback point

### Documentation

36. **Update AGENTS.md** — Correct nodiscard analysis, document unsafe shutdown root cause, document the scrub monitoring fix, document the `discard=none` near-miss
37. **Correct prior status report** (`06-51_*.md`) — Annotate the false P0-CRITICAL claim
38. **Write post-mortem** — Full timeline of corruption discovery and remediation
39. **Document the `dd` vs scrub distinction** — `dd` can't detect silent corruption; only BTRFS checksums can
40. **Create runbook for corruption detection** — `journalctl -k | grep 'checksum error'` → extract paths → delete → scrub

### AI model management

41. **Audit all models on `/data/ai/`** — Delete unused/stale models
42. **Symlink models to central location** — Avoid duplicates
43. **Automated cleanup script** — Find and delete orphaned model files
44. **Separate AI cache from production models** — Different backup profiles
45. **Consider NAS for model storage** — More reliable than consumer QLC NVMe

### Long-term

46. **Evaluate RAID1 for `/data`** — BTRFS RAID1 or mdadm mirror
47. **Plan drive replacement** — TLC/MLC NVMe with power-loss protection (Samsung 990 Pro, WD SN850X)
48. **Evaluate ext4 vs BTRFS for `/data`** — Simpler for Docker/AI workloads
49. **Review kernel 7.2** — BTRFS fixes
50. **Consider enterprise NVMe** — PLP, better sustained write endurance

---

## G) Questions (3 — cannot figure out myself)

### 1. Deploy now, or wait for the fresh scrub?

The deploy includes weekly scrub + monitoring fix + reverted dangerous changes. Deploying triggers service restarts (I/O load). If you're running a fresh scrub, the deploy will restart services mid-scrub. **Deploy now, or after the verification scrub completes?**

### 2. How many of the 58 unsafe shutdowns were power-loss vs WDT resets?

This determines whether we need a UPS (power-loss) or WDT/oomd tuning (system hangs). I can't check pstore or boot history without sudo. **Can you run `journalctl --list-boots | wc -l` and `ls -la /sys/fs/pstore/`?**

### 3. Should fstrim.timer be disabled on this drive?

The 330 GiB fstrim event at 01:17 preceded the first corruption at 05:47 by 4.5 hours. On QLC NAND with 253ms discard latency, fstrim sends TRIM commands that cause I/O stalls. Without fstrim, the FTL loses knowledge of freed blocks → write amplification → faster wear. **Do you want fstrim disabled, or is the write amplification tradeoff worse?**

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
