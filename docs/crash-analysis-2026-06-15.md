# Crash Analysis: 2026-06-15 11:49 CEST

**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395, 128GB RAM)
**Root FS:** BTRFS on `/dev/nvme0n1p6` (512GB NVMe)
**Boot ID (crashed):** `612eaeb1c0724fbd9ac8f66ce71d1435`
**Boot ID (recovery):** `76ec527fc31d4b19bb3469bfe43da654`

---

## Summary

The system experienced a **hard freeze** caused by a **disk exhaustion + concurrent reclamation death spiral**. The root BTRFS filesystem was critically full (97.57% data usage). Two concurrent space-reclamation operations (`btrfs balance` + `nix-collect-garbage`) were launched on the already-full filesystem, creating an I/O and memory thrash spiral that wedged the system too deeply for even the kernel OOM killer or journal to record anything.

---

## Timeline

| Time (CEST) | Event |
|-------------|-------|
| 08:04:01 | First Docker ENOSPC error (early warning sign) |
| 11:21:16 | `session-318.scope` exits — peaked at **5 GB** RAM |
| 11:20:49 | `session-308.scope` exits — peaked at **5.1 GB** RAM |
| 11:31:35 | Docker ENOSPC errors go persistent — root FS is full |
| 11:39:48 | Memory pressure begins — journald flushing caches every few seconds |
| 11:40:08 | `session-224.scope` exits — had peaked at **18.8 GB** RAM (largest consumer) |
| 11:43:02 | **Manual: `sudo btrfs balance start -dusage=70 -musage=50 /`** |
| 11:43:09 | BTRFS balance kernel thread starts relocating block groups |
| 11:44:26 | **Manual: `sudo nix-collect-garbage --delete-older-than 6d`** (concurrent!) |
| 11:44:29 | Memory metrics check taking **3.163s** (normally <200ms) — system thrashing |
| 11:44:48 | `amdgpu-metrics.service` taking **6.694s** wall clock (normally <3s) |
| ~11:45:49 | **Last journal entry** — hard freeze, no OOM logged, no panic logged |
| 11:47:02 | System reboots (balance auto-resumes) |
| 11:50:26 | BTRFS balance completes with status 0 |

---

## Root Cause Chain

### 1. Disk Was Critically Full

```
BTRFS Data,single:   409.91 GiB / 420.10 GiB  (97.57% full)
BTRFS Metadata,DUP:   24.87 GiB /  31.89 GiB  (78.00% full)
Device allocated:    483.94 GiB / 512.00 GiB  (94.5%)
```

With only ~10 GiB free on a 420 GiB data partition, Docker containers could not write to `/tmp` inside their namespaces. Health checks began failing with `OCI runtime exec failed: write /tmp/runc-process*: no space left on device` starting at 08:04 and becoming persistent by 11:31:35.

### 2. Memory Pressure Compounded the Problem

At 11:39:48, `systemd-journald` began reporting "Under memory pressure, flushing caches" every 2–5 seconds. A session (`session-224.scope`) had peaked at **18.8 GB** of RAM. Combined with Docker containers, ClickHouse, SigNoz, Hermes, and other services, the system was under severe memory pressure with swap thrashing.

No `systemd-oomd` kill was recorded — the OOM killer never successfully intervened.

### 3. Fatal Trigger: Two Concurrent Reclamation Operations

At **11:43:02**, `btrfs balance` was started manually:

```bash
sudo btrfs balance start -dusage=70 -musage=50 /
```

At **11:44:26**, `nix-collect-garbage` was started concurrently:

```bash
sudo nix-collect-garbage --delete-older-than 6d
```

**Why this was fatal:**

- **`btrfs balance` needs free space to relocate data blocks.** On a near-100% full filesystem, it cannot make progress — it allocates new blocks to copy data into, but there's nowhere to put them. It still consumes kernel memory and I/O bandwidth while stuck.
- **`nix-collect-garbage` hammers the disk** with thousands of store path reads, deletions, and metadata updates.
- **Together**, they created a positive feedback loop: balance needed space → GC was using all I/O → balance couldn't free space → more memory pressure → journald couldn't flush → services timed out → swap thrashing → every operation took seconds instead of milliseconds → system froze.

### 4. Service Cascade

In the final 5 minutes, multiple services showed signs of failure:

- **ClickHouse Keeper**: "Cannot receive session id within session timeout" (repeated)
- **Hermes**: "heartbeat blocked for more than 50 seconds" + `os.fsync()` stuck in asyncio loop
- **Ollama**: Gatus health checks failing consistently (`success=false`)
- **dnsblockd**: "context canceled" dispatch errors, TLS handshake failures
- **SigNoz**: Gatus health check failing (`success=false`)
- **PostgreSQL** (Docker): Repeated "database has no actual collation version" warnings (symptom of I/O starvation)

### 5. Hard Freeze — No Logging Possible

The journal ends abruptly at 11:45:49 with no shutdown sequence, no OOM kill message, no kernel panic, and no pstore dump. The system was too thoroughly frozen to write anything to disk. This is consistent with:

- **Hard lockup** (CPU stuck in kernel I/O path)
- **Hardware watchdog timeout** (WDT reset — already documented in AGENTS.md as emptying pstore)

The 2-minute gap between last journal entry (11:45:49) and reboot (11:47:02) aligns with a hardware watchdog reset.

---

## Post-Reboot State

The balance auto-resumed on boot and completed successfully at 11:50:26. However, **the disk is still critically full:**

```
/dev/nvme0n1p6  512G  461G  39G  93%  /
BTRFS Data:  409.91 GiB / 420.10 GiB  (97.57%)
```

The balance freed almost nothing — it rearranged blocks but couldn't reclaim meaningful space because the data is genuinely occupied, not fragmented.

---

## Recommended Actions

### Immediate (prevent recurrence)

1. **Docker cleanup** — remove unused images, stopped containers, build cache:
   ```bash
   docker system prune -a          # images + stopped containers + build cache (NOT volumes)
   docker builder prune -a         # build cache only (often the biggest hidden hog)
   ```
   **Do NOT pass `--volumes`** — named volumes hold persistent state (Postgres/ClickHouse/Forgejo/Pocket-ID). `--volumes` would destroy data, not reclaim junk.

2. **Nix garbage collection** — run ALONE, never concurrent with balance or other heavy I/O:
   ```bash
   nix-collect-garbage --delete-older-than 7d
   ```

3. **Journal vacuum** — reduce persistent journal size:
   ```bash
   journalctl --vacuum-size=2G
   ```

4. **BTRFS snapshot cleanup** — check for old btrbk snapshots consuming space:
   ```bash
   btrfs subvolume list /
   btrbk clean
   ```

### Process Discipline

| Rule | Why |
|------|-----|
| **Never run `btrfs balance` on a full filesystem** | Balance needs free space to relocate blocks. On a 97%+ full FS, it cannot progress and may wedge the system. Free space first (GC, prune, vacuum), THEN balance if needed. |
| **Never run two reclamation operations concurrently** | Each operation is I/O-intensive. Running them simultaneously causes thrashing, especially under memory pressure. |
| **Monitor disk usage proactively** | At 90%+, stop and reclaim before hitting ENOSPC. The `disk-monitor.service` was running but not alerting aggressively enough. |

### Systemic Fixes to Consider

- **Enable `systemd-oomd`** if not already active — it should have killed memory hogs before the freeze
- **Add disk usage alerting** in Gatus (alert at 85%, critical at 90%)
- **Docker `dm.basesize` / storage driver limits** — prevent containers from consuming all disk
- **Automated periodic cleanup** — scheduled `docker system prune` and `nix-collect-garbage` before the disk fills
- **BTRFS quota groups** — set limits on subvolumes like `/var/lib/docker` and `/nix/store`

---

## Evidence Sources

- `journalctl -b -1 -n 80` — last journal entries before freeze
- `journalctl -b -1 -k --since "2026-06-15 11:00:00"` — kernel messages (no OOM, no panic, no GPU errors)
- `journalctl -b -1 --since "2026-06-15 11:00:00" | grep "no space"` — Docker ENOSPC timeline
- `journalctl -b -1 | grep "memory pressure"` — journald cache flush timeline
- `journalctl -b -1 | grep "Consumed.*memory peak"` — per-session memory consumption
- `journalctl -b -1 | grep "sudo"` — manual commands (balance + nix-collect-garbage)
- `journalctl -b 0 -k | grep balance` — balance auto-resume on reboot
- `btrfs filesystem usage /` — current BTRFS allocation (still 97.57% data full)
- `/sys/fs/pstore/` — empty (WDT reset confirmed by absence of dump)
- `/var/lib/systemd/coredump/` — no crash dumps from the freeze session itself

---

*Analysis performed 2026-06-15 17:20 CEST, ~5.5 hours after the crash.*
