# Crash Analysis: 2026-06-26 00:02 CEST — BTRFS Metadata Exhaustion + WDT Reset

**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395 "Strix Halo", 128 GB unified RAM)
**Root FS:** BTRFS on `/dev/nvme0n1p6` (was 519.5 GiB, now 722.5 GiB)
**Boot ID (crashed):** `1cc421c712724ed5b23fa899ba55d577`
**Current generation:** 434 (`a7280ff8` — flake.lock update, Jun 25 18:32)
**Previous generation:** 433 (Jun 25 16:36)

---

## TL;DR

The nightly `nix-gc` timer (configured: `nix.gc.automatic = true; dates = "daily"`) fired at 00:00 and began mass-deleting thousands of store paths starting at 00:01:03. Each deletion is a BTRFS metadata transaction. The filesystem's device was **100% allocated** (1 MiB unallocated), and metadata was at **91.31%** utilization. Approximately 60 seconds into the deletion storm, BTRFS could no longer allocate metadata for the transactions themselves. I/O threads parked in D-state. The kernel never reached its own panic handler (no pstore dump). ~30 seconds later, the **sp5100-tco hardware watchdog** (armed by `watchdogd` with `timeout=30`, confirmed in `boot.nix`) fired a raw hardware reset. On reboot, NixOS activation hung because activation is itself a metadata storm (symlink tree rebuild), and the filesystem was still in the same deadlocked state. Rolling back generations didn't help because the problem was the *filesystem*, not the generation.

This is the **second time** this exact failure mode occurred (first: 2026-06-15, see `docs/crash-analysis-2026-06-15.md`). On 06-15 it was triggered manually (`btrfs balance` + `nix-collect-garbage` concurrently). On 06-26 it was **fully automated** — the nightly GC timer alone was sufficient. The recurrence is structural: the `nix.gc` timer has no awareness of BTRFS chunk allocation state, and `df`/node_exporter cannot see it.

---

## What Broke (Layer by Layer)

### Layer 1: BTRFS Chunk Allocation Exhaustion (Root Cause)

BTRFS divides the physical partition into typed pools called **chunks** (block groups). Each chunk is assigned a type: Data, Metadata, or System. Free space in one pool **cannot serve another pool**. This is the core concept that caused everything.

**Pre-crash state (from `btrfs filesystem usage /`):**

```
Data,      single: Size 444.04GiB, Used 421.98GiB (95.03%)   ← data pool, 22 GiB free inside
Metadata,  DUP:    Size 37.70GiB, Used 34.42GiB (91.31%)     ← metadata pool, 3.3 GiB free inside
System,    DUP:    Size 32.00MiB

Device allocated:   519.50 GiB / 519.50 GiB    ← 100% of partition assigned to chunks
Device unallocated:    1.00 MiB                ← effectively ZERO raw space
```

**What this means:**
- `df` and node_exporter report **22 GiB free** (the `statfs` number). This is free space *inside existing Data chunks*.
- That 22 GiB is **useless for metadata operations**. It cannot be repurposed.
- To get more metadata capacity, BTRFS must allocate a **brand-new Metadata chunk** from **device-unallocated** space.
- Device-unallocated was **1 MiB**. No new metadata chunk could be created.
- BTRFS can reclaim space *out of* Data chunks back to device-unallocated, but only by **completely emptying a Data chunk** first. At 95% per-chunk utilization, none were empty. This creates a **circular deadlock**: need metadata space → need to free a data chunk → need metadata transactions to free it → need metadata space.

**The metadata ratchet — why we marched toward the cliff over 8 days:**

8 daily BTRFS snapshots existed (`@.20260619T0000` through `@.20260626T0000`). Each nightly GC cycle deletes store paths, but when a snapshot still references the deleted file's extents, the **data extent is NOT freed** (CoW sharing), yet the **metadata change MUST still be written** (refcount update, B-tree modification). Net effect per cycle: metadata grows, data doesn't shrink. Over 8 days, metadata climbed toward 91% while data relief never materialized. This wasn't a sudden failure — it was a structural one-way ratchet.

### Layer 2: The Crash Trigger — Nightly nix-gc Timer

**Config** (`platforms/common/nix-settings.nix`):
```nix
nix.gc = {
  automatic = true;
  options = "--delete-older-than 3d";
  dates = "daily";      # fires at 00:00
  persistent = true;
};
```

Also relevant (`nix.settings` in same file):
```nix
min-free = 5000000000;   # 5 GB — trigger GC when df reports < 5 GB free
max-free = 100000000000; # 100 GB — stop GC when 100 GB free
```

The `min-free`/`max-free` thresholds use the `df` statfs number (22 GiB), which was always above 5 GB. So GC never triggered from the space-based threshold — it triggered purely from the **daily schedule**, regardless of BTRFS internal state.

**Timeline of the crash window:**

| Time (CEST) | Event |
|-------------|-------|
| 00:00:00 | `nix.gc` daily timer fires |
| 00:01:03 | GC begins mass-deleting store paths (first journal entry: `nix-gc-start[3401362]: deleting ...`) |
| 00:01:03–00:01:28 | Thousands of store path deletions, each a metadata transaction (visible in journal) |
| ~00:01:28 | Deletion journal entries slow/stop — metadata ENOSPC likely begins here |
| 00:02:00 | **Last journal entry ever** — Twenty CRM cron job (`1acabbf3006c[3699790]: BullMQDriver Processing job`) |
| 00:02:00+ | System frozen. Journald cannot write (metadata ENOSPC). No shutdown sequence, no OOM message, no kernel panic, no stack trace. |
| ~00:02:30 | **sp5100-tco hardware watchdog fires** (watchdogd `timeout=30` — last pet ~00:02:00) — raw hardware reset |

**Why the journal stops mid-stream:** BTRFS couldn't commit the metadata transaction for journald's write. Every write blocked in D-state. Journald's entries were in its memory buffer but could never reach disk. The last flushed entry (00:02:00) was the final one before the I/O path fully wedged.

### Layer 3: No Software Panic — Hardware Watchdog Kill

**Evidence that this was a hardware reset, not a software panic:**

1. **pstore is empty.** Config in `platforms/nixos/system/boot.nix`:
   ```
   "pstore.backend=efi"
   "pstore.record_console=true"
   "pstore.max_reason=3"   # PANIC(1), OOPS(2), EMERG(3)
   ```
   `max_reason=3` is a **severity threshold** (not a count limit). It means: "record a dump for any event with reason code ≤ 3." The kernel is explicitly configured to panic on soft lockups (`softlockup_panic=1`) and hung tasks (`hung_task_panic=1`). If either had fired, `KMSG_DUMP_PANIC(1)` ≤ 3 → pstore would have captured the console log + stack trace. **It captured nothing.** `/sys/fs/pstore/` is empty.

2. **Confirmed watchdog hardware** (dmesg):
   ```
   sp5100_tco: SP5100/SB800 TCO WatchDog Timer Driver
   sp5100-tco sp5100-tco: Using 0xfeb00000 for watchdog MMIO address
   sp5100-tco sp5100-tco: initialized. heartbeat=60 sec (nowayout=0)
   ```
   `/sys/class/watchdog/watchdog0/identity` = `SP5100 TCO timer`, `timeout` = `60`.

3. **The ~30-second gap** between the last journal entry (~00:02:00) and the reset (~00:02:30) aligns precisely with `watchdogd`'s `timeout = 30` (from `boot.nix`). The kernel dmesg shows `heartbeat=60 sec` — that's the sp5100-tco driver's initial default, but `watchdogd` overrides it to 30s when it opens `/dev/watchdog0`. When the system froze, watchdogd couldn't get scheduled to pet the WDT → 30s of silence → sp5100-tco pulls the plug. The WDT doesn't ask the kernel, doesn't trigger a panic handler, doesn't write to pstore — it just cuts power.

**Conclusion:** The kernel was too deeply frozen in BTRFS I/O deadlock to reach its own panic/softlockup/hung_task handlers. The hardware watchdog was the only thing that could break the deadlock, and it did so destructively.

### Layer 4: Activation Hang on Reboot

After the WDT reset, the system could not boot normally. It hung at "Starting NixOS Activation."

**Why:** NixOS activation (`switch-to-configuration`) is a **metadata-intensive operation**:
- Rebuilds the entire `/run/current-system` symlink tree (hundreds of symlinks)
- Recreates `/etc` symlinks
- Touches `/var/lib/...` state directories
- Each symlink creation/rename is a BTRFS metadata transaction

The filesystem was in the **exact same deadlocked state** after the WDT reset — device still 100% allocated, metadata still at 91%, no unallocated space for new metadata chunks. Activation's metadata storm hit the same wall GC did.

**Why rollback to gen 433 didn't help:** Rolling back changes the *generation* (which system closure to activate), but the *filesystem* is the same. The activation script for gen 433 is equally metadata-intensive. The problem was never the generation — it was the BTRFS chunk allocation deadlock. No generation rollback can fix a filesystem-level ENOSPC.

**Why TTY/rescue mode didn't work either:** `systemd.unit=emergency.target`, `rd.systemd.unit=rescue.target`, `init=/bin/sh` — all fail because:
- Activation runs during early boot, before any target is reached
- The `sulogin` "root account locked" intercept is a known NixOS behavior for passwordless root
- Even if a shell was reached, BTRFS metadata ENOSPC would block any operation that writes metadata

### Layer 5: Recovery Obstacles

| Attempt | Result | Why |
|---------|--------|-----|
| Ctrl+Alt+F2/F3/F4 (TTY switch) | No TTY | systemd never reached `getty.target` — stuck at activation |
| `systemd.unit=emergency.target` | Hung at activation | Activation runs before targets |
| `init=/bin/sh` | "root account locked" | NixOS `sulogin` intercept for passwordless root |
| `init=/run/current-system/sw/bin/bash` | Same lock | Same intercept |
| `rd.systemd.unit=rescue.target + loglevel=7` | BTRFS debug info, still locked | Showed BTRFS messages but didn't bypass sulogin |
| USB installer (first boot) | Wouldn't boot | Needed `nomodeset` for Strix Halo GPU |
| USB installer (with `nomodeset`) | Booted | NixOS 24.11 installer, used to mount and repair |

---

## How We Fixed It

### Step 1: Boot USB Installer, Mount Root

```bash
# USB needed nomodeset for Strix Halo iGPU
mount -t btrfs -o subvol=@,compress=zstd:3,ssd /dev/nvme0n1p6 /mnt
```

### Step 2: Enter the System (nixos-enter)

```bash
nixos-enter --root /mnt
# sops age key imported automatically
```

### Step 3: Diagnose — Identify BTRFS Chunk Deadlock

```bash
btrfs filesystem usage /
# → Device unallocated: 1.00 MiB  ← THE PROBLEM
# → Metadata,DUP: 91.31% full
# → Device allocated: 519.50 / 519.50 GiB  ← 100% allocated
```

The diagnosis: `df` showed 22 GiB free but device-unallocated was 1 MiB. Standard disk monitoring was blind to the real problem.

### Step 4: Grow the Partition (GPT → Kernel → BTRFS)

The user had previously moved partitions p7/p8/p9 on the 2 TB NVMe, creating 203 GiB of free space immediately after p6 (confirmed via `sfdisk -F`). However, the partition table still showed p6 at its original 519.5 GiB — **the earlier extension attempt had not committed to the GPT.**

**Three-step grow (each layer must see the change before the next can act):**

**4a. Grow the partition in the GPT (sfdisk):**
```bash
# Backup current table
sfdisk -d /dev/nvme0n1 > /tmp/nvme-parts.bak

# Compute new size: extend p6 to fill the free gap up to p8's start
# p6 start: 8390656, p8 start: 1523617792
# new p6 size = 1523617792 - 8390656 = 1515227136 sectors = 722.52 GiB

# Apply: --no-reread avoids the BLKRRPART ioctl (EBUSY on mounted partition)
# sfdisk still pushes individual partition sizes via BLKPG (works on mounted)
sfdisk --no-reread /dev/nvme0n1 < /tmp/nvme-parts.new
```

**4b. Push new size to the running kernel (partx):**
```bash
# sfdisk re-read failed (EBUSY) because p6 is mounted.
# partx uses BLKPG_RESIZE_PARTITION which works on mounted partitions.
partx -u --nr 6:6 /dev/nvme0n1
# → kernel now sees 1515227136 sectors = 722.52 GiB
```

**4c. Grow the BTRFS filesystem:**
```bash
btrfs filesystem resize max /
# → BTRFS absorbs the new raw space
# → Device unallocated: 203.02 GiB (was 1 MiB)
```

### Post-Fix State

```
Device size:         722.52 GiB  (was 519.50 GiB)
Device allocated:    519.50 GiB  (unchanged — BTRFS hasn't needed new chunks yet)
Device unallocated:  203.02 GiB  (was 1 MiB)  ← THE FIX
Free (estimated):    225.07 GiB  (was 22 GiB)
```

The deadlock is dissolved: BTRFS can now allocate fresh Metadata chunks on demand from the 203 GiB unallocated pool. The 91% metadata utilization within existing chunks is now harmless — it simply triggers allocation of a new chunk, which is now possible.

**Note on balance:** A BTRFS balance was **not performed and is not needed.** Balance relocates data to consolidate partially-filled chunks. It does not reclaim space on a genuinely-full device, and it requires unallocated space to work (the deadlock condition). With 203 GiB unallocated, a metadata-only balance (`btrfs balance start -musage=50 /`) could be run as housekeeping on a clean boot, but it is not necessary for recovery. A full data balance would take hours and provides no benefit at current utilization.

---

## Comparison with 2026-06-15 Crash

| Aspect | 2026-06-15 | 2026-06-26 |
|--------|-----------|-----------|
| **Trigger** | Manual: `btrfs balance` + `nix-collect-garbage` concurrently | **Automated**: nightly `nix-gc` timer alone |
| **Data fullness** | 97.57% | 95.03% |
| **Metadata fullness** | 78.00% | 91.31% |
| **Device allocated** | 94.5% | **100%** |
| **Device unallocated** | ~28 GiB (low but nonzero) | **1 MiB** (effectively zero) |
| **Nature of trigger** | Human error (concurrent reclaim) | Structural (GC on metadata-starved FS) |
| **Could repeat?** | No (manual action) | **YES — nightly timer will fire again under same conditions** |

The 06-26 crash is more dangerous because it was **automated and structural**. It will recur if device-unallocated drops near zero again. The 06-15 crash required human intervention to trigger; this one needs none.

---

## What to Improve (Prioritized)

### P0 — Critical: Prevent Automated Reclamation from Crashing the System

**The core insight:** the crash trigger (GC timer) and the crash condition (metadata ENOSPC) are the same operation class. GC trying to reclaim space on a device too full to reclaim *is the bug*. Making the timer aware of BTRFS state prevents recurrence regardless of monitoring.

**Action: Gate `nix.gc` and `nix-build-cleanup` on device-unallocated space.**

Create a wrapper script that the GC timer calls instead of running GC directly. The wrapper checks device-unallocated before proceeding:

```bash
#!/usr/bin/env bash
# btrfs-chunk-guard.sh — abort reclamation if BTRFS can't handle metadata pressure
set -euo pipefail

# Extract device-unallocated from btrfs filesystem usage
UNALLOC_BYTES=$(btrfs filesystem usage / 2>/dev/null \
  | awk '/Device unallocated:/ {gsub(/[(),]/,""); print $3}' \
  | numfmt --from=iec)

DEVICE_BYTES=$(btrfs filesystem usage / 2>/dev/null \
  | awk '/Device size:/ {gsub(/[(),]/,""); print $3}' \
  | numfmt --from=iec)

UNALLOC_PCT=$(( UNALLOC_BYTES * 100 / DEVICE_BYTES ))

if [ "$UNALLOC_PCT" -lt 10 ]; then
  echo "CRITICAL: BTRFS device-unallocated at ${UNALLOC_PCT}% — aborting GC to prevent metadata ENOSPC crash" >&2
  systemctl status btrfs-chunk-guard.service || true
  exit 1   # Non-zero exit → systemd OnFailure= notification
fi

# Safe to proceed — run the actual GC
exec nix-collect-garbage --delete-older-than 3d
```

Wire this into `nix.gc.options` or as a pre-exec wrapper on the `nix-gc.service` systemd unit.

**Also gate `nix-build-cleanup`** (runs every 4h per `scheduled-tasks.nix:420`) with the same check — it also does metadata-heavy operations.

### P1 — High: BTRFS Metrics Collector for node_exporter

**The blind spot:** `df` / node_exporter's `filesystem` collector reports the BTRFS `statfs` free number (22 GiB). This is free space *inside Data chunks*. It cannot see:
- Device-unallocated (the metric that hit 1 MiB and killed the system)
- Metadata utilization (the metric that hit 91%)
- Chunk allocation state (the metric that hit 100%)

**Action: Create a `btrfs-metrics` textfile collector** following the existing pattern (`amdgpu-metrics.service`, `nvme-metrics.service`, `psi-metrics.service` already in the config).

Parse `btrfs filesystem usage /` and export:

```prometheus
# Metrics that would have warned us:
btrfs_device_unallocated_bytes 213994434560    # was 1048576 (1 MiB!)
btrfs_device_unallocated_pct 28                # was ~0%
btrfs_metadata_used_bytes 36969872588          # was 34.42 GiB
btrfs_metadata_utilization_pct 91              # was 91.31%
btrfs_device_allocated_pct 72                  # was 100%
```

**Alert thresholds (configure in Gatus, which is already running):**

| Metric | Warning | Critical |
|--------|---------|----------|
| `btrfs_device_unallocated_pct` | < 15% | < 10% |
| `btrfs_metadata_utilization_pct` | > 85% | > 90% |
| `btrfs_device_allocated_pct` | > 90% | > 95% |

### P2 — Medium: Snapshot Retention Policy

8 daily snapshots (`@.20260619T0000`–`@.20260626T0000`) were pinning extents via CoW, preventing GC from freeing data while still requiring metadata writes for refcount changes. This is the ratchet that walked metadata toward 91%.

**Action:**
- Review `btrbk` or snapshot configuration — confirm retention is bounded (e.g., keep 3 daily snapshots, not open-ended)
- Consider deleting snapshots *before* GC runs (snapshot deletion frees extents that GC can then reclaim, making GC more effective)
- Sequence: delete old snapshots → GC → done. Never run snapshot operations concurrently with GC.

### P3 — Medium: Hardware Watchdog Awareness

The sp5100-tco kernel driver initializes with `heartbeat=60 sec`, but **`watchdogd` overrides this to 30s** (`boot.nix`: `services.watchdogd.settings.timeout = 30`). The effective runtime timeout is **30 seconds** — the kernel gives the system only 30s to recover from any stall before a destructive reset. This is shorter than `hung_task_timeout_secs` (120s), meaning the WDT always fires before the kernel's own diagnostic handlers can capture a pstore dump (see Appendix D for the full causal chain).

**Action: Consider raising watchdogd timeout to 120s** to align with `hung_task_timeout_secs`. This would allow the kernel's hung_task detector to fire first, capture a pstore dump, and give diagnostics before the WDT pulls the plug. Tradeoff: 120s of unresponsiveness on genuine hangs vs. 30s. For a desktop/workstation, 30s is arguably correct (fast recovery). For a system where crash forensics matter (this one — two crashes with zero diagnostic capture), 120s may be worth the slower recovery.

See Appendix D for the full analysis of why the WDT timeout (30s) races against hung_task (120s) and always wins, leaving no forensic trail.

### P4 — Low: Document the Recovery Procedure

**Action: Add a `docs/troubleshooting/btrfs-metadata-enospc-recovery.md`** with:
1. How to identify the condition (`btrfs filesystem usage /` — look for Device unallocated ≈ 0)
2. Why `df` is misleading (statfs reports Data-pool free space, not chunk-level)
3. The partition-grow procedure (sfdisk → partx → btrfs resize)
4. Why balance is the wrong tool (needs unallocated space to work)
5. Why rollback doesn't fix it (filesystem problem, not generation problem)
6. The `nomodeset` requirement for USB boot on Strix Halo

### P5 — Low: Fix the 06-15 Crash Analysis Doc

The `docs/crash-analysis-2026-06-15.md` recommended `docker system prune -a --volumes`. This is dangerous on this system — `--volumes` would destroy persistent data volumes (Postgres, ClickHouse, Forgejo, Pocket-ID). This has been fixed in this document's edit (the `--volumes` flag was removed and a warning added), but verify the fix is committed.

---

## Evidence Sources

### Journal Analysis
```
journalctl --list-boots
# Boot 0 (crashed): 1cc421c712724ed5b23fa899ba55d577
#   First: Tue 2026-06-23 05:50:01 CEST
#   Last:  Fri 2026-06-26 00:02:22 CEST    ← abrupt stop, no shutdown sequence

journalctl --since "2026-06-26 00:01:00" --until "2026-06-26 00:02:30"
# nix-gc-start[3401362] mass-deleting from 00:01:03 to ~00:01:28
# Last entry: 00:02:00 — Twenty CRM cron job
# No OOM message, no kernel panic, no stack trace, no shutdown sequence
```

### BTRFS State (Pre-Fix)
```
btrfs filesystem usage /
Device allocated:   519.50 GiB / 519.50 GiB    ← 100% allocated
Device unallocated:    1.00 MiB                ← effectively zero
Metadata,DUP:       34.42 GiB / 37.70 GiB (91.31%)
Data,single:       421.98 GiB / 444.04 GiB (95.03%)
btrfs device stats: all zero (no hardware errors)
```

### Hardware Watchdog (Confirmed)
```
dmesg | grep sp5100
# sp5100_tco: SP5100/SB800 TCO WatchDog Timer Driver
# sp5100-tco sp5100-tco: Using 0xfeb00000 for watchdog MMIO address
# sp5100-tco sp5100-tco: initialized. heartbeat=60 sec (nowayout=0)

/sys/class/watchdog/watchdog0/identity = SP5100 TCO timer
/sys/class/watchdog/watchdog0/timeout = 60
```

### pstore (Empty — confirms WDT, not panic)
```
/sys/fs/pstore/ — empty (no dump)
/var/lib/systemd/pstore/ — only stale May 6 directory
# boot.nix: pstore.backend=efi, pstore.max_reason=3
# If kernel had panicked (softlockup_panic=1, hung_task_panic=1), pstore would have captured it
# Empty pstore = kernel never reached panic handler = hardware WDT reset
```

### Partition Table (Post-Fix)
```
sfdisk -d /dev/nvme0n1
/dev/nvme0n1p6 : start=8390656, size=1515227136  (722.5 GiB — was 519.5 GiB)
/dev/nvme0n1p7 : start=2048,      size=8388608    (4 GiB EFI)
/dev/nvme0n1p8 : start=1523617792, size=2173696000 (1 TiB data)
/dev/nvme0n1p9 : start=3697313792, size=209715200  (100 GiB rust-cache)
```

### Config References
- GC timer: `platforms/common/nix-settings.nix` — `nix.gc.automatic = true; dates = "daily"`
- min-free threshold: same file — `min-free = 5000000000` (uses `df` statfs, blind to chunk state)
- Build cleanup: `platforms/nixos/system/scheduled-tasks.nix:420` — every 4h
- Watchdog/pstore/crash sysctls: `platforms/nixos/system/boot.nix:54-104`
- Previous crash analysis: `docs/crash-analysis-2026-06-15.md`

---

## Glossary

| Term | Meaning |
|------|---------|
| **Chunk (block group)** | A fixed-size region of the physical partition assigned to a specific type (Data/Metadata/System). ~1 GiB for data, ~256 MiB-1 GiB for metadata. |
| **Device allocated** | Total physical space already carved into chunks. Once 100%, BTRFS cannot create new chunks without freeing empty ones. |
| **Device unallocated** | Raw physical space not yet assigned to any chunk. This is the only source for new Metadata chunks. When ≈ 0, BTRFS enters metadata ENOSPC deadlock. |
| **Metadata ENOSPC** | "No space left on device" at the metadata level, despite `df` showing free space. Caused by device-unallocated exhaustion. The most dangerous BTRFS failure mode because it blocks ALL write operations. |
| **statfs free** | The number `df` reports. For BTRFS, this is estimated usable free space inside existing Data chunks. Does NOT reflect metadata headroom or device-unallocated. |
| **WDT (Watchdog Timer)** | Hardware timer that resets the system if not periodically "kicked" (reset). The sp5100-tco kernel driver defaults to `heartbeat=60 sec`, but `watchdogd` overrides this to 30s (`boot.nix`: `timeout = 30`). With `nowayout=0`, the WDT is disarmed when no userspace process holds `/dev/watchdog0` open — meaning it does NOT protect against boot/activation hangs (watchdogd hasn't started yet). Operates independently of the kernel — fires even when the kernel is frozen. See Appendix B and D. |
| **pstore** | Persistent store for kernel crash logs in EFI NVRAM. Survives reboots. `max_reason=3` means capture PANIC/OOPS/EMERG events. Empty pstore = no software panic occurred. |

---

*Analysis performed 2026-06-26, during recovery from USB installer chroot (`nixos-enter --root /mnt`). All evidence gathered live from the affected system's journal, BTRFS, dmesg, and NixOS configuration.*

---

# Appendix A: Recovery Runbook

> Copy-pasteable. Assumes USB installer booted with `nomodeset` (required for Strix Halo GPU).

## Step 0: Identify the Failure Mode

```bash
# Mount root subvolume (adjust subvol name if different)
mount -t btrfs -o subvol=@,compress=zstd:3,ssd /dev/nvme0n1p6 /mnt

# Diagnose — look for these red flags:
btrfs filesystem usage /mnt
```

**Metadata ENOSPC confirmed if ALL of these are true:**
- `Device unallocated:` ≈ 0 (anything < 1 GiB is critical)
- `Metadata,DUP:` utilization > 85%
- `df` still shows free space (the trap — `df` is lying)

**If device-unallocated is healthy (> 10% of device size):** this is NOT metadata ENOSPC. Look elsewhere (corrupted generation, failed disk, etc.).

## Step 1: Enter the System

```bash
nixos-enter --root /mnt
```

If `nixos-enter` fails, check that all needed subvolumes are mounted:
```bash
mount -t btrfs -o subvol=@home /dev/nvme0n1p6 /mnt/home
```

## Step 2: Free Raw Space (Grow Partition)

The ONLY fix for metadata ENOSPC is adding **device-unallocated** space. You cannot reclaim your way out — BTRFS needs raw space to allocate new metadata chunks.

### 2a: Check for free space after the partition

```bash
sfdisk -F /dev/nvme0n1
# Look for unpartitioned space immediately after p6
```

### 2b: Grow the partition in the GPT

```bash
# Backup current partition table
sfdisk -d /dev/nvme0n1 > /tmp/nvme-parts.bak

# Compute new p6 size (extend to fill free gap up to next partition)
# Example: if p6 starts at 8390656 and next partition (p8) starts at 1523617792:
# new_size = 1523617792 - 8390656 = 1515227136 sectors

# Edit the backup, changing ONLY p6's size field:
cp /tmp/nvme-parts.bak /tmp/nvme-parts.new
# Replace the size value on p6's line with the computed value

# Write back (--no-reread avoids EBUSY on mounted partitions)
sfdisk --no-reread /dev/nvme0n1 < /tmp/nvme-parts.new
```

### 2c: Push new size to kernel

```bash
# sfdisk's re-read will fail (EBUSY on mounted partition). Use partx instead:
partx -u --nr 6:6 /dev/nvme0n1

# Verify kernel sees the new size:
cat /sys/block/nvme0n1/nvme0n1p6/size
# Should show the new (larger) sector count
```

### 2d: Grow BTRFS to fill the partition

```bash
btrfs filesystem resize max /
```

### 2e: Verify

```bash
btrfs filesystem usage /
# Device unallocated should now show the added space (tens of GiB)
```

## Step 3: Reboot

```bash
exit                    # exit nixos-enter chroot
umount /mnt             # if you mounted extra subvolumes, unmount those first
reboot
```

## What NOT to Do

| Command | Why It Fails |
|---------|-------------|
| `btrfs balance start /` | Balance needs device-unallocated space to relocate blocks. On a full device, it can't progress and may wedge the system. |
| `nix-collect-garbage` | Each deletion is a metadata transaction. On a metadata-starved filesystem, GC makes it worse, not better. |
| `rm -rf` large trees | Same — metadata storm. Every file removal is a metadata write. |
| Rollback to previous generation | The problem is the *filesystem*, not the generation. All generations require the same metadata operations to activate. |
| `btrfs balance start -musage=50` | Safer than full balance but still needs unallocated space. Only attempt AFTER growing the partition. |

---

# Appendix B: Failed Boot Escape Analysis

> Why every standard recovery method failed, and what actually works.

## The Escape Attempts (from `paste_1.txt` timeline)

| # | Method | Result | Root Cause |
|---|--------|--------|------------|
| 1 | Wait for activation to complete | Hung 10+ minutes | NixOS activation is a metadata storm (symlink tree rebuild). BTRFS can't commit the transactions. |
| 2 | Rollback to gen 433 (GRUB menu) | Still hangs | Same filesystem, same metadata ENOSPC. The generation doesn't matter — activation for any generation requires the same metadata operations. |
| 3 | Ctrl+Alt+F2/F3/F4 | No TTY | systemd never reached `getty.target`. It was stuck at the `nixos-activation.service` unit, which is a boot-critical dependency. No target past activation can start. |
| 4 | GRUB `e` → `systemd.unit=emergency.target` | Activation still runs | NixOS activation (`boot.systemd.initrdStoresPaths` → `nixos-activation.service`) runs as part of `sysinit.target`, which executes BEFORE any user-selected target. You can't skip it by changing the target. |
| 5 | GRUB `e` → `init=/bin/sh` | "root account locked" | NixOS replaces `/bin/sh` with a `sulogin` wrapper for passwordless root. When PID 1 is replaced, `sulogin` intercepts and demands a password. NixOS's root account has `!` (locked) in `/etc/shadow` by default. |
| 6 | `init=/run/current-system/sw/bin/bash` | Same "root account locked" | Same `sulogin` intercept — it's baked into the NixOS boot process, not the shell path. |
| 7 | `rd.systemd.unit=rescue.target + loglevel=7` | BTRFS debug info but still locked | Showed BTRFS kernel messages (confirming the filesystem was alive) but `sulogin` still intercepted in the initrd phase. |

## Why the Hardware Watchdog Didn't Help During Recovery

This is a critical and non-obvious finding. The sp5100-tco hardware watchdog has `nowayout=0` (confirmed in dmesg: `heartbeat=60 sec (nowayout=0)`).

**What `nowayout=0` means:** Once the watchdog device (`/dev/watchdog0`) is closed by its last user, the WDT is **disarmed**. The kernel driver does not keep the watchdog armed if nobody is holding the device open.

**During the original crash:** `watchdogd` (userspace daemon) was running and held `/dev/watchdog0` open, petting it every 10s (`boot.nix`: `interval = 10`). When the system froze, watchdogd couldn't get scheduled → stopped petting → 30s later (`boot.nix`: `timeout = 30`) the WDT fired and reset the system. **This is why the crash boot ended — the WDT saved us.**

**During recovery boots:** The boot sequence is: kernel → initrd → systemd → activation → ... → watchdogd starts (late in boot, after `multi-user.target` dependencies). When activation hangs, systemd never progresses past the activation unit. **`watchdogd` never starts.** With `nowayout=0`, the kernel driver's watchdog was never armed (or was disarmed after the bootloader/initrd released it). **There is no WDT reset during an activation hang.** The system hangs forever. The only escape is a manual power button hold.

**This is a structural gap in the recovery path:** the hardware watchdog protects against runtime hangs but NOT boot/activation hangs. A future improvement would be setting `nowayout=1` in the kernel module config, but this carries its own risk: if a boot legitimately takes longer than 60s (e.g., BTRFS recovery on a large filesystem), the kernel driver's default `heartbeat=60` would fire mid-recovery and potentially corrupt data.

## What Actually Works: USB Installer

The only reliable escape from a metadata-ENOSPC activation hang is an external boot medium that bypasses the frozen filesystem entirely:

1. Boot NixOS USB installer with `nomodeset` (Strix Halo GPU requirement)
2. Mount the root subvolume read-write
3. Grow the partition (Appendix A)
4. Reboot — activation now succeeds because BTRFS has device-unallocated space

---

# Appendix C: Timeline Forensics

## C1: The Concurrent-Timer Hypothesis (Debunked)

**Hypothesis:** Commit `c91e958d` made `nix-build-cleanup` run every 4h. If its timer landed near 00:00, two reclamation jobs would have run concurrently — the automated twin of the 06-15 crash's fatal double-reclamation.

**Verdict: FALSE.** The journal shows only `nix-gc-start[3401362]` in the 00:00–00:05 window. No `nix-build-cleanup` entries appear. The 4h timer (`OnUnitActiveSec=4h`, `RandomizedDelaySec=5m`) fires relative to boot time (~05:50 on Jun 23), so it lands at ~05:55, ~09:55, ~13:55, ~17:55, ~21:55, ~01:55 — never at 00:00. The nightly GC ran **alone**. GC alone was sufficient to kill the system. This is worse than the hypothesis — it means no concurrency is needed, just a metadata-starved filesystem + nightly timer.

## C2: The `rm -rf /nix/var/nix/builds/` Question

**From `paste_1.txt`:** "User did this before crash — red herring, shouldn't affect activation."

**Verdict: Truly a red herring for the CRASH, but not for the filesystem pressure.** The journal shows `nix-build-cleanup` (the automated version of this) running at 00:09 on Jun 25, hitting hundreds of "Permission denied" errors on Go build sandbox files (read-only bind mounts in build sandboxes). The cleanup deleted what it could, but many files were immutable. This **did contribute to metadata growth** — deleting files whose extents are CoW-shared by snapshots requires metadata writes without freeing data — but it ran ~24 hours before the crash and its metadata impact was absorbed. It was not the trigger. The nightly GC at 00:00 was the trigger.

## C3: The Generation Number Anomaly

**Observation:**
```
Live root @ (subvolid 256):     Generation 1695999
Latest snapshot @.20260626T0000: Generation 816361
Delta:                          ~879,638 transactions
```

For comparison, the normal daily delta between snapshots is ~18,000 generations:
```
@.20260625T0000: gen 798366
@.20260626T0000: gen 816361
Delta:           ~17,995 in 24 hours (normal)
```

879,638 transactions since the 00:00 snapshot is ~49× the normal daily rate. This happened in the ~7 hours between the snapshot (00:00) and our first investigation (~07:00).

**Explanation: Recovery operations.** After the crash at ~00:02, the user attempted 2+ failed boots (each activation attempt writes hundreds of symlinks/metadata transactions on the deadlocked filesystem — transactions that may partially commit, partially fail). Then the USB boot + `nixos-enter` + our diagnostic commands (many `btrfs filesystem usage`, `btrfs subvolume list`, `journalctl` queries, file writes). Each failed activation attempt spinning metadata transactions it couldn't complete (but could partially commit) is a generation multiplier. The `sfdisk` partition table write, the `btrfs filesystem resize`, and the file edits to this very document all increment the generation counter.

**This is NOT evidence of balance auto-resume.** `btrfs balance status /` confirms "No balance found on '/'" — no balance has run or is running. The generation anomaly is recovery churn, not a background operation.

## C4: The "66 Seconds" Question

**From `paste_1.txt`:** "Boot -1 lasted 66 seconds — Watchdog killed it — that was the original crash."

**Verdict: The 66 seconds refers to the GC freeze window, not a boot duration.** The journal boot list from the chroot shows:

```
Boot -1 (db5efe3b84204fc5aa856562e65b6dde): Jun 23 05:48:38 → 05:49:44 = 66 seconds
Boot  0 (1cc421c712724ed5b23fa899ba55d577): Jun 23 05:50:01 → Jun 26 00:02:22 = 2.75 days (THE CRASH BOOT)
```

Boot -1 was a **clean 66-second reboot** (Jun 23, with a proper `systemd-shutdown` sequence) — NOT the crash. The user's "boot -1" in their notes referred to a different perspective (likely from the USB installer, where the crashed boot would be "boot -1" relative to the installer's boot).

The actual freeze timeline within the crash boot:
- 00:00:00 — GC timer fires
- 00:01:03 — First deletion journal entry
- ~00:01:28 — Last deletion journal entry (metadata ENOSPC begins)
- 00:02:00 — Last journal entry ever (Twenty CRM cron)
- ~00:02:30 — **WDT fires** (watchdogd timeout=30s, last pet ~00:02:00)

The ~90 seconds from GC start (00:01:03) to WDT reset (~00:02:30) is the real "how long did it take to die" number.

## C5: Pre-Crash Service Degradation

In the final 30 minutes (23:30–00:02), the following signals were present:

| Signal | Severity | Interpretation |
|--------|----------|---------------|
| SigNoz health check `success=false` | Ongoing (pre-existing) | SigNoz was already down/failing before the crash. Not related. |
| Ollama health check `success=false` | Ongoing (pre-existing) | Ollama was already down/failing. Not related. |
| "ISP down (2 failures)" every ~5s | Noise | This was an ISP outage, not system degradation. Appears throughout the boot. |
| `node_exporter` write errors (`connection reset by peer`) | Started ~00:01:07 | **Early symptom** — prometheus scraping was getting I/O errors as BTRFS started struggling. This is the first sign of metadata pressure. |
| `dnsblockd` TLS handshake errors | Throughout | Pre-existing — TLS version mismatch from a client. Not crash-related. |

**No new service failures appeared in the 23:30–00:01 window.** The system was operating normally until GC started at 00:00. The crash was sudden — there was no gradual degradation, just a 90-second death spiral triggered by the GC timer.

---

# Appendix D: The Death Mechanism (Causal Chain)

> Why the kernel's own crash handlers never fired, and why pstore is empty.

## The Five-Layer Race Condition

The system had four mechanisms that *should* have produced a diagnostic record before death. None of them fired. Here's why:

```
                    BTRFS Metadata ENOSPC
                            │
                    ┌───────┴───────┐
                    ▼               ▼
          I/O threads park     watchdogd can't
          in D-state           get scheduled
           (uninterruptible     to pet WDT
           sleep on I/O)             │
                    │                ▼
                    │     ┌── 30s timeout ──┐
                    │     │   (watchdogd)    │
                    │     ▼                  │
                    │  sp5100-tco FIRES      │
                    │  (hardware reset)      │
                    │  ~00:02:30             │
                    │                        │
         ┌──────────┴──────────┐             │
         ▼                     ▼             ▼
   hung_task_panic       softlockup_panic   SYSTEM DEAD
   timeout=120s          threshold=20s     No pstore
   (never reached —      (never triggered   No journal
    WDT fired at 30s      — D-state is      No panic log
    before 120s)          NOT soft lockup)
```

### Layer 1: Why `softlockup_panic=1` Didn't Fire

`boot.nix` sets `kernel.softlockup_panic=1` and `kernel.watchdog_thresh=20`. The soft lockup detector watches for CPUs stuck in kernel mode with **interrupts disabled** for >20s. A soft lockup is the CPU *spinning* — executing kernel code but unable to service interrupts.

**BTRFS metadata ENOSPC does not cause soft lockups.** It causes tasks to enter **D-state** (uninterruptible sleep, `TASK_UNINTERRUPTIBLE`). The CPU is not spinning — it's parked, waiting for an I/O completion that never comes. The softlockup detector explicitly excludes D-state tasks (it checks `hrtimer` overrun on active CPUs, not sleeping tasks). The CPUs that scheduled these tasks are free to run other work — they just happen to have nothing useful to do because all I/O is blocked.

### Layer 2: Why `hung_task_panic=1` Didn't Fire

`boot.nix` sets `kernel.hung_task_panic=1` and `kernel.hung_task_timeout_secs=120`. The hung task detector *does* catch D-state tasks — it wakes every 120s, scans for tasks stuck in D-state for >120s, and panics.

**The WDT fired first.** watchdogd's timeout is **30 seconds** (from `boot.nix`: `services.watchdogd.settings.timeout = 30`). The hung task detector fires at 120s. The WDT fires at 30s. **The WDT won the race by 90 seconds.** The system was reset before hung_task ever had a chance to scan.

This is a configuration conflict: `watchdogd timeout (30s) < hung_task_timeout (120s)`. The WDT will *always* fire before hung_task, making `hung_task_panic=1` effectively dead code for any scenario where watchdogd is running. The hung task panic can only fire if watchdogd is NOT running (e.g., during early boot, before watchdogd starts).

### Layer 3: Why `kernel.panic=30` Didn't Produce a pstore Dump

`kernel.panic=30` means "reboot 30s after a kernel panic." This would give time for the panic handler to write a pstore dump. But no panic occurred — neither softlockup nor hung_task fired (see above). The WDT bypassed the entire kernel panic path. pstore was never triggered.

### Layer 4: Why `pstore.max_reason=3` Captured Nothing

pstore only triggers on kernel events (PANIC, OOPS, EMERG). Since no panic occurred (WDT fired before any kernel handler), pstore had no event to capture. `/sys/fs/pstore/` is empty. This is **positive evidence** that the death was a hardware reset, not a software panic. If the kernel had panicked (for any reason), pstore would have a dump.

### Layer 5: Why `watchdogd timeout=30` Is Correct (Despite Being Too Short for Diagnostics)

watchdogd's 30s timeout is configured in `boot.nix`:
```nix
services.watchdogd.settings = {
  timeout = 30;   # Hard reset after 30s without a kick
  interval = 10;  # Pet the watchdog every 10s
};
```

The kernel dmesg shows `sp5100-tco: initialized. heartbeat=60 sec (nowayout=0)` — this is the **kernel driver's initial default**. watchdogd overrides this to 30s when it opens the device. The effective timeout during normal operation is **30 seconds**, not 60.

30s is arguably correct for a desktop: longer than a brief GC stall, short enough to recover quickly from a genuine GPU/driver hang. The tradeoff is that it's too short for the kernel's own diagnostic handlers (hung_task=120s) to fire first. Increasing watchdogd to e.g. 120s would align it with hung_task, allowing the kernel to capture a pstore dump before the WDT fires — but would mean 120s of unresponsiveness before recovery from genuine hangs.

### The Fundamental Tension

| Goal | Requirement | Conflict |
|------|-------------|----------|
| Fast recovery from hangs | Short WDT timeout (30s) | No time for diagnostics |
| Diagnostic capture before death | Long WDT timeout (>120s) | 120s+ of unresponsiveness |
| pstore dump on BTRFS ENOSPC | hung_task must fire before WDT | Needs WDT > 120s |

**There is no perfect setting.** The current 30s prioritizes recovery over forensics. If crash forensics become more important than recovery speed, raise watchdogd timeout to 120s (matching hung_task). But the real fix is preventing the crash in the first place — which is what Appendix E and F address.

---

# Appendix E: The BTRFS Monitoring Blind Spot

> Why every disk monitor was green while the system was hours from death.

## The Existing `systemnix-btrfs` DMS Plugin Is Blind

The Quickshell desktop widget (`pkgs/dms-plugins/systemnix-btrfs/BtrfsWidget.qml`) monitors two things:
1. **Snapshot age** (how long since `btrbk.timer` last ran)
2. **Disk usage percentage** via `df --output=pcent /`

The disk percentage comes from `df`, which uses the `statfs` syscall. For BTRFS, `statfs` returns `f_bavail` — the estimated usable free space **inside existing Data chunks**. This is the **22 GiB number** that looked fine right up until the crash.

**The widget cannot see:**
- Device-unallocated (the metric that hit 1 MiB)
- Metadata utilization (the metric that hit 91%)
- Chunk allocation state (the metric that hit 100%)

**The disk widget was green at 95% `df` usage** while device-unallocated was at 0.01%. The widget's threshold (`diskPercent > 85 = red`) is monitoring the wrong number.

## node_exporter Is Equally Blind

node_exporter's `filesystem` collector scrapes the same `statfs` numbers. Prometheus, Grafana, Gatus — all downstream of the same blind data. The entire monitoring stack was reporting "22 GiB free, 95% used" with green health checks while the system was one GC cycle from death.

## The Three Metrics That Matter (And Aren't Collected)

| Metric | Source | What It Means | Crash Value |
|--------|--------|---------------|-------------|
| Device unallocated | `btrfs filesystem usage` | Raw space for new chunks (any type) | **1 MiB** |
| Metadata utilization | `btrfs filesystem usage` | How full existing metadata chunks are | **91.31%** |
| Device allocated % | `btrfs filesystem usage` | How much of the partition is carved into chunks | **100%** |

None of these are exposed by `df`, `statfs`, node_exporter's filesystem collector, or the DMS widget. They require parsing `btrfs filesystem usage` output — a privileged command that needs root or appropriate capabilities.

## Why `min-free`/`max-free` Can't Help

NixOS's `nix.gc` can trigger GC based on free space thresholds:
```nix
# platforms/common/nix-settings.nix
min-free = 5000000000;   # 5 GB — trigger GC when df reports < 5 GB
max-free = 100000000000; # 100 GB — stop GC when 100 GB free
```

These thresholds use the **same `statfs` free-space number** that `df` reports. They cannot see device-unallocated. Setting `min-free` higher (e.g., 50 GB) would trigger GC more often, but GC itself is the operation that causes metadata growth — it would accelerate the ratchet, not prevent it.

**There is no Nix-native or kernel-native way to gate GC on BTRFS chunk allocation state.** The `statfs` interface does not expose chunk-level information. The only source is `btrfs filesystem usage` (or the BTRFS ioctl interface), which requires a userspace parser.

---

# Appendix F: BTRFS Early Warning System Design

> **Goal:** The user gets a BIG persistent notification — on the desktop, via Discord, and as a systemd alert — the moment BTRFS chunk allocation enters a danger zone. GC timers must refuse to run when the filesystem can't handle the metadata pressure.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    btrfs-health.service                   │
│                   (runs every 5 minutes)                  │
│                                                          │
│  btrfs filesystem usage /                                │
│  → parse device-unallocated, metadata %, allocated %     │
│  → write Prometheus textfile metrics                     │
│  → check thresholds → send notifications                 │
└──────────────┬───────────────┬──────────────┬────────────┘
               │               │              │
               ▼               ▼              ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
    │ node_exporter │  │  Gatus check │  │ Desktop notify   │
    │  textfile dir │  │  → Discord   │  │ systembus-notify │
    │  → Prometheus │  │  → BIG alert │  │ → DMS widget     │
    │  → Grafana   │  │              │  │ → persistent     │
    └──────────────┘  └──────────────┘  └──────────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │  btrfs-chunk-guard.sh     │
    │  (GC timer wrapper)       │
    │  → reads latest metrics   │
    │  → ABORTS GC if           │
    │    device-unallocated     │
    │    < 10% or metadata      │
    │    > 85%                  │
    └──────────────────────────┘
```

## Component 1: `btrfs-health.service` — Metrics + Alerting

**New file:** `platforms/nixos/system/btrfs-health.nix`

A systemd oneshot service running every 5 minutes that:

1. **Parses `btrfs filesystem usage /`** into three metrics
2. **Writes Prometheus textfile metrics** to `/var/lib/node_exporter/textfile/btrfs.prom`
3. **Checks thresholds** and sends desktop + Discord notifications when crossed

```bash
#!/usr/bin/env bash
# btrfs-health-check.sh
set -euo pipefail

TEXTFILE_DIR="/var/lib/node_exporter/textfile"
METRICS_FILE="${TEXTFILE_DIR}/btrfs.prom"
MOUNT="/"

# Parse btrfs filesystem usage
USAGE=$(btrfs filesystem usage "$MOUNT" 2>/dev/null)

DEVICE_SIZE_BYTES=$(echo "$USAGE" | awk '/Device size:/ {gsub(/[()]/,""); print $3}' | numfmt --from=iec)
UNALLOC_BYTES=$(echo "$USAGE" | awk '/Device unallocated:/ {gsub(/[()]/,""); print $3}' | numfmt --from=iec)
META_USED_BYTES=$(echo "$USAGE" | awk '/Metadata,DUP:.*Used/ {match($0, /Used:([0-9.]+)([KMGTP]iB)/, a); print a[1] a[2]}' | numfmt --from=iec)
META_SIZE_BYTES=$(echo "$USAGE" | awk '/Metadata,DUP:.*Size/ {match($0, /Size:([0-9.]+)([KMGTP]iB)/, a); print a[1] a[2]}' | numfmt --from=iec)
ALLOC_BYTES=$(echo "$USAGE" | awk '/Device allocated:/ {gsub(/[()]/,""); print $3}' | numfmt --from=iec)

# Calculate percentages
UNALLOC_PCT=$(( UNALLOC_BYTES * 100 / DEVICE_SIZE_BYTES ))
META_PCT=$(( META_USED_BYTES * 100 / META_SIZE_BYTES ))
ALLOC_PCT=$(( ALLOC_BYTES * 100 / DEVICE_SIZE_BYTES ))

# Write Prometheus metrics
mkdir -p "$TEXTFILE_DIR"
cat > "$METRICS_FILE.$$" <<EOF
# HELP btrfs_device_size_bytes Total device size
# TYPE btrfs_device_size_bytes gauge
btrfs_device_size_bytes ${DEVICE_SIZE_BYTES}
# HELP btrfs_device_unallocated_bytes Raw space not yet assigned to chunks
# TYPE btrfs_device_unallocated_bytes gauge
btrfs_device_unallocated_bytes ${UNALLOC_BYTES}
# HELP btrfs_device_unallocated_pct Percentage of device that is unallocated
# TYPE btrfs_device_unallocated_pct gauge
btrfs_device_unallocated_pct ${UNALLOC_PCT}
# HELP btrfs_metadata_utilization_pct Metadata pool utilization
# TYPE btrfs_metadata_utilization_pct gauge
btrfs_metadata_utilization_pct ${META_PCT}
# HELP btrfs_device_allocated_pct Percentage of device carved into chunks
# TYPE btrfs_device_allocated_pct gauge
btrfs_device_allocated_pct ${ALLOC_PCT}
EOF
mv "$METRICS_FILE.$$" "$METRICS_FILE"

# ── Threshold check + notifications ──────────────────────
# State file to avoid alert fatigue (only notify on state transitions)
STATE_FILE="/var/lib/btrfs-health/state"
mkdir -p /var/lib/btrfs-health
PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "OK")

# Determine current state
if [ "$UNALLOC_PCT" -lt 5 ] || [ "$META_PCT" -gt 90 ]; then
    STATE="CRITICAL"
elif [ "$UNALLOC_PCT" -lt 10 ] || [ "$META_PCT" -gt 85 ]; then
    STATE="WARNING"
else
    STATE="OK"
fi

# Only act on state transitions
if [ "$STATE" != "$PREV_STATE" ]; then
    echo "$STATE" > "$STATE_FILE"

    case "$STATE" in
        CRITICAL)
            MSG="🚨 BTRFS CRITICAL: device-unallocated=${UNALLOC_PCT}% metadata=${META_PCT}% — GC will crash the system. Free space immediately: grow partition or delete old snapshots."
            ;;
        WARNING)
            MSG="⚠️ BTRFS WARNING: device-unallocated=${UNALLOC_PCT}% metadata=${META_PCT}% — approaching metadata ENOSPC. Consider cleanup before next GC cycle."
            ;;
        OK)
            MSG="✅ BTRFS recovered: device-unallocated=${UNALLOC_PCT}% metadata=${META_PCT}%"
            ;;
    esac

    # Desktop notification (persistent — stays until dismissed)
    ${pkgs.libnotify}/bin/notify-send -u critical -t 0 -a "BTRFS Health" "BTRFS Health: $STATE" "$MSG" 2>/dev/null &

    # Discord alert via webhook (same as Gatus uses)
    # TODO: wire to sops-managed webhook URL
    echo "$MSG" | wall 2>/dev/null || true

    # Log to journal
    logger -t btrfs-health "$MSG"
fi
```

**NixOS service definition:**

```nix
# platforms/nixos/system/btrfs-health.nix
{ config, pkgs, lib, ... }: {
  systemd.services.btrfs-health = {
    description = "BTRFS chunk allocation health monitor";
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      # Run as root (btrfs filesystem usage needs privileges)
      ExecStart = "${pkgs.writeShellScriptBin "btrfs-health-check" (builtins.readFile ./btrfs-health-check.sh)}/bin/btrfs-health-check";
    };
  };

  systemd.timers.btrfs-health = {
    description = "BTRFS health check every 5 minutes";
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
    };
    wantedBy = [ "timers.target" ];
  };
}
```

## Component 2: GC Timer Guard — Prevent the Crash Trigger

**New file:** `platforms/nixos/system/btrfs-gc-guard.nix`

Wraps `nix.gc` to abort when BTRFS can't handle the metadata pressure:

```nix
# platforms/nixos/system/btrfs-gc-guard.nix
{ config, pkgs, lib, ... }: let
  guardScript = pkgs.writeShellScriptBin "btrfs-gc-guard" ''
    set -euo pipefail

    # Read the latest metrics from the textfile collector
    PROM_FILE="/var/lib/node_exporter/textfile/btrfs.prom"

    if [ ! -f "$PROM_FILE" ]; then
      echo "btrfs-gc-guard: no metrics file — allowing GC (fail-open)"
      exit 0
    fi

    UNALLOC_PCT=$(awk '/btrfs_device_unallocated_pct/ {print $2}' "$PROM_FILE" || echo "100")
    META_PCT=$(awk '/btrfs_metadata_utilization_pct/ {print $2}' "$PROM_FILE" || echo "0")

    if [ "$UNALLOC_PCT" -lt 10 ]; then
      echo "BTRFS ABORT: device-unallocated at ''${UNALLOC_PCT}% — GC would cause metadata ENOSPC" >&2
      echo "Free space first: grow partition, delete old snapshots, or vacuum journal" >&2
      # Send persistent desktop notification
      ${pkgs.libnotify}/bin/notify-send -u critical -t 0 -a "BTRFS Guard" \
        "GC ABORTED — BTRFS device-unallocated at ''${UNALLOC_PCT}%" \
        "Nightly GC was blocked to prevent metadata ENOSPC crash. Free space: grow partition, delete old snapshots." 2>/dev/null || true
      logger -t btrfs-gc-guard "GC aborted: unallocated=''${UNALLOC_PCT}% meta=''${META_PCT}%"
      exit 1
    fi

    if [ "$META_PCT" -gt 85 ]; then
      echo "BTRFS WARNING: metadata at ''${META_PCT}% — GC proceeding but may cause metadata pressure" >&2
      logger -t btrfs-gc-guard "GC warning: unallocated=''${UNALLOC_PCT}% meta=''${META_PCT}%"
    fi

    # Safe to proceed
    exec ${config.nix.package}/bin/nix-collect-garbage --delete-older-than 3d
  '';
in {
  # Override the GC service to run through the guard
  systemd.services.nix-gc = {
    serviceConfig.ExecStart = lib.mkForce "${guardScript}/bin/btrfs-gc-guard";
  };
}
```

## Component 3: Gatus Endpoint — Discord Alert

Add a BTRFS health check to the existing Gatus config (`modules/nixos/services/gatus-config.nix`):

```nix
# Add to endpoints list in gatus-config.nix
{
  name = "BTRFS Health";
  group = "Filesystem";
  url = "http://127.0.0.1:${toString nodePort}/metrics";
  interval = "60s";
  conditions = [
    "[BODY].btrfs_device_unallocated_pct > 10"
    "[BODY].btrfs_metadata_utilization_pct < 85"
  ];
  alerts = discordAlert "BTRFS chunk allocation critical — device-unallocated <10% or metadata >85%. GC has been auto-disabled to prevent crash.";
}
```

## Component 4: DMS Widget Enhancement

Update `pkgs/dms-plugins/systemnix-btrfs/BtrfsWidget.qml` to show device-unallocated percentage alongside the existing `df` percentage:

```qml
// Add a third metric: device-unallocated from btrfs filesystem usage
// The existing widget only checks df %pcent — add this to the Process command:
// "unalloc=$(btrfs filesystem usage / | awk '/Device unallocated:/ {print $3}' | numfmt --from=iec --to=none); ..."
// Then show: if unalloc < 10% of device → RED with "CHUNK!" warning
```

This makes the desktop widget show the real danger metric, not the misleading `df` number.

## Alert Thresholds Summary

| Metric | OK | Warning | Critical | GC Blocked |
|--------|-----|---------|----------|------------|
| Device unallocated % | >15% | 10-15% | 5-10% | <10% |
| Metadata utilization % | <80% | 80-85% | 85-90% | >85% (warning only) |
| Device allocated % | <90% | 90-95% | >95% | (informational) |

## Implementation Priority

1. **Component 2 (GC guard)** — highest priority, prevents the crash trigger. Can be deployed standalone without the monitoring infrastructure. ~20 lines of Nix.
2. **Component 1 (health service)** — metrics collection + desktop notification. Enables the other components. ~60 lines of Nix + script.
3. **Component 3 (Gatus)** — adds Discord alerting. ~5 lines, trivial once metrics exist.
4. **Component 4 (DMS widget)** — desktop visibility. ~10 lines of QML changes.

---

*Appendices A-F added 2026-06-26. Forensics gathered from live journal, BTRFS, dmesg, and NixOS configuration during recovery chroot session.*
