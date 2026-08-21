# BTRFS Proactive Maintenance — Status Report

**Date:** 2026-08-01 02:48 CEST
**Session scope:** Adding automated BTRFS balance + emergency reserve to `btrfs-health.nix`
**Files changed:** `platforms/nixos/system/btrfs-health.nix`, `modules/nixos/services/gatus-config.nix`, `AGENTS.md`

---

## Context

User asked to set up BTRFS balance automation and a configurable reserve in Nix, after a conversation about device-unallocated space on their 722 GiB BTRFS filesystem (currently at ~5 GiB unallocated after a manual data balance).

The existing `btrfs-health.nix` module had:

- Prometheus metrics (5-min interval)
- GC guard (blocks nix-gc when device-unallocated < 10%)
- Scrub metrics
- Compsize metrics

It was **reactive only** — no proactive maintenance to reclaim underused chunks.

---

## a) FULLY DONE

1. **Metadata balance script + timer** (`btrfs-balance-metadata`)
   - `btrfs balance start -musage=50 /` weekly at Mon 04:00
   - Guarded: skips if balance already running, skips if device-unallocated < 5 GiB
   - `CAP_SYS_ADMIN`, `ProtectSystem = false`, `TimeoutStartSec = 1h`

2. **Data balance script + timer** (`btrfs-balance-data`)
   - `btrfs balance start -dusage=50 -dlimit=10 /` weekly at Mon 05:00
   - Bounded (`-dlimit=10` = max 10 chunks/run)
   - Guarded: skips if balance running, skips if device-unallocated < 10 GiB
   - `TimeoutStartSec = 2h`

3. **Emergency reserve script + service** (`btrfs-emergency-reserve`)
   - 10 GiB `fallocate`d file at `/btrfs-emergency-reserve`
   - Created on boot (`wantedBy = multi-user.target`)
   - Idempotent: skips if file already exists
   - Free-space check: refuses to create if free < reserve + 5 GiB headroom

4. **Prometheus metrics for reserve**
   - `btrfs_emergency_reserve_present` (0/1) and `btrfs_emergency_reserve_bytes`
   - Added to existing `btrfs-health-metrics` 5-min collector

5. **Gatus health check**
   - "BTRFS Emergency Reserve" — alerts on Discord if reserve file is missing

6. **AGENTS.md updated**
   - BTRFS section: added "Balance" and "Emergency reserve" subsections
   - Gotcha table: updated ENOSPC crash entry with 3-layer fix description
   - Module header comment updated (2 → 5 components)

7. **Nix eval verified** — full `toplevel` eval passes for all new services, timers, and Gatus config

---

## b) PARTIALLY DONE

1. **AGENTS.md gotcha table** — The ENOSPC entry was updated but is extremely long. The balance/reserve behavior could use its own dedicated gotcha row for the snapshot interaction issue (see section d).

2. **Observability** — Metrics exist for reserve presence/size, but NOT for balance run status, space reclaimed, or skip reasons. You can see the reserve is there, but not whether last night's balance ran or skipped.

---

## c) NOT STARTED

1. **Post-deploy smoke tests** for the new services (not added to `post-deploy-check.sh`)
2. **Balance result metrics** (last-run time, chunks relocated, space reclaimed)
3. **Pre-deploy validation** (e.g., warn if deploying would change timer schedules)
4. **NixOS module options** — the balance `dusage`/`musage`/`dlimit` thresholds and reserve size are hardcoded, not configurable via module options
5. **Grafana/SigNoz dashboard panels** for balance history
6. **`deploy.sh` explicit start** — The emergency reserve `wantedBy = multi-user.target` only fires at boot; first deploy after adding it won't start it (same class as the monitor365 deploy gap)

---

## d) TOTALLY FUCKED UP (Critical Bugs)

### BUG 1: Emergency reserve + BTRFS snapshots = BROKEN DESIGN

**Severity: CRITICAL — the core feature is compromised**

The reserve file lives at `/btrfs-emergency-reserve`, which is inside the `@` root subvolume. btrbk snapshots `@` daily at 23:00 with 14-day retention. Due to BTRFS CoW:

1. Boot: `fallocate` creates 10 GiB of extents → `df` shows 10 GiB less free
2. 23:00: btrbk snapshots `@` → snapshot's file tree now references the same extents
3. Emergency: user runs `rm /btrfs-emergency-reserve`
4. Live filesystem removes its references to the extents
5. **BUT the snapshot STILL references them** → extents are NOT freed
6. `df` free space does NOT increase → **the reserve provides ZERO emergency space**

The space is only reclaimed when the snapshot expires (14 days later). By then, the emergency is long over.

**The reserve works as a BUFFER** (holding 10 GiB to prevent reaching 100%), but **fails as an EMERGENCY RELEASE** (deleting it for instant space). The latter was the primary design goal.

**Fix options:**

- Put the reserve on a subvolume that is NOT snapshotted (e.g., one of the `@cache-*` subvolumes, or a new `@reserve` subvolume excluded from btrbk)
- Write random data instead of `fallocate` (avoids compression, but doesn't solve the snapshot reference issue)
- Use `chattr +C` (NOCOW) — does NOT help with snapshot references
- Accept the limitation and document it clearly: "delete + wait for snapshot expiry" is the real flow

### BUG 2: `fallocate` on `compress=zstd` BTRFS — may not reserve real space

**Severity: HIGH — the reserve may be phantom space**

BTRFS `fallocate` is supposed to allocate real extents (not subject to compression). But this behavior is kernel-version-dependent and there are historical BTRFS bugs where `fallocate` on compressed volumes creates extents that compress to near-zero. A 10 GiB file of zeros on `compress=zstd` could occupy as little as a few MB of actual block space.

If the reserve is phantom, it provides no buffer at all — the filesystem reaches 100% as if the reserve didn't exist.

**Fix:** Write actual data (e.g., `dd if=/dev/urandom`) or use `chattr +C` before `fallocate` to disable CoW+compression on the file.

### BUG 3: `${""}/` Nix string interpolation in MOUNT variable

**Severity: LOW — works but is cargo-cult code**

Both balance scripts contain `MOUNT="${""}/"` — an empty Nix string interpolation that evaluates to just `/`. This is confusing and unnecessary. Should be `MOUNT="/"`.

---

## e) WHAT WE SHOULD IMPROVE

1. **Fix BUG 1 (snapshots)** — The reserve must live on a non-snapshotted subvolume. Create a `@emergency-reserve` subvolume mounted at `/emergency-reserve` (or reuse an existing `@cache-*`), excluded from btrbk. Move the reserve file there.

2. **Fix BUG 2 (compression)** — Either `chattr +C` the file before `fallocate`, or write random data with `dd if=/dev/urandom of=... bs=1M count=10240`. Verify with `compsize /btrfs-emergency-reserve` that actual space matches allocation.

3. **Add balance observability** — Write a `btrfs_balance_last_run_timestamp` and `btrfs_balance_status` (0=idle, 1=running, 2=completed-ok, 3=skipped, 4=failed) metric after each balance run. Without this, balance failures/skips are invisible until someone checks journalctl.

4. **Add `IODeviceWeight` to balance services** — Balance is IO-heavy. Set `IODeviceWeight = 100` (low priority) and `IOSchedulingClass = "best-effort"` with `IOSchedulingPriority = 7` so balance doesn't compete with user workloads.

5. **Fix the `df` check in emergency reserve** — Use `btrfs-chunk-check` for device-unallocated instead of `df`. The current `df` check reports data-pool free space, not chunk-level unallocated — a service can pass the `df` check but still cause metadata ENOSPC.

6. **Add post-deploy smoke tests** — Verify balance services are loaded and the emergency reserve exists after deploy.

7. **Make thresholds configurable** — Add NixOS module options (`services.btrfs-health.balance.musage`, `.dusage`, `.dlimit`, `.reserveSize`) instead of hardcoding.

8. **Derive `RESERVE_SIZE` from a single variable** — `RESERVE_BYTES` and the display `RESERVE_SIZE` string can diverge if someone edits one but not the other.

9. **Add `ExecStartPost` on emergency reserve** — Write a state file recording creation timestamp + size, for post-mortem analysis.

10. **Stagger balance AFTER btrbk (23:00), not before** — Running balance at 04:00/05:00 is fine, but consider whether balance should run AFTER snapshot expiry to maximize available unallocated space.

---

## f) Up to 50 Things to Get Done Next

### BTRFS (fix the bugs from this session)

1. **Fix BUG 1:** Create `@emergency-reserve` subvolume excluded from btrbk, move reserve file there
2. **Fix BUG 2:** `chattr +C` or `dd if=/dev/urandom` for the reserve file to guarantee real space allocation
3. **Fix BUG 3:** Clean up `${""}/` → `/` in both balance scripts
4. **Fix `df` check:** Replace `df` with `btrfs-chunk-check` in emergency reserve script
5. Add balance status metrics (`btrfs_balance_last_run`, `btrfs_balance_status`, `btrfs_balance_chunks_relocated`)
6. Add `IODeviceWeight` + `IOSchedulingClass` to balance services
7. Add post-deploy-check for emergency reserve existence + balance timer enabled
8. Make balance/reserve thresholds configurable via NixOS module options
9. Verify `fallocate` + `compress=zstd` actually reserves space on this kernel (run `compsize` after first deploy)
10. Consider adding `/data` to balance scope (currently only `/` is balanced; `/data` has its own chunk allocation)

### Deployment

11. Deploy this config to evo-x2 (`nix run .#deploy`)
12. Verify emergency reserve created successfully after first boot
13. Verify balance timers are loaded (`systemctl list-timers btrfs-*`)
14. Manually trigger a metadata balance and verify it works
15. Add `deploy.sh` explicit start for `btrfs-emergency-reserve` on first deploy

### Monitoring

16. Add Gatus alert for balance failure (currently only `onFailure` → desktop notification)
17. Add Gatus check for balance staleness (alert if no successful balance in 8+ days)
18. Add Grafana/SigNoz panel for BTRFS unallocated space history trend
19. Add Grafana/SigNoz panel for balance run history
20. Consider alerting when emergency reserve is consumed (transition from present → absent)

### Existing BTRFS Issues (from AGENTS.md, still open)

21. `/nix` not a separate subvolume — btrbk snapshots include the full nix store (deferred to next reinstall)
22. No remote backup — all snapshots are LOCAL-ONLY (#1 data loss risk)
23. BTRFS metadata ratio is 2.00 (DUP) — consider converting to single on single-device systems for space efficiency
24. QLC NAND `discard=async` still removed — verify `fstrim.timer` is sufficient

### Code Quality

25. Extract the balance scripts into a shared library (both share the "already running" guard + chunk-check pattern)
26. Add integration test that validates balance guard logic (mock `btrfs balance status` output)
27. Consider `btrfs balance filter` with `-v` (verbose) for better logging
28. Document the balance timer schedule in a BTRFS maintenance runbook (`docs/runbooks/btrfs-maintenance.md`)
29. Add the BTRFS balance/reserve gotchas to the AGENTS.md gotcha table as dedicated rows

### Future Hardening

30. Add automated partition growth when device-unallocated consistently < 5% (requires free partition space — currently the disk is fully partitioned)
31. Investigate BTRFS `block-group-tree` feature (newer kernel) for more efficient chunk management
32. Consider converting metadata profile from DUP to single on this single-device system (saves ~50% metadata allocation)
33. Add `btrfs device stats` monitoring (read/write/flush errors per device)
34. Add `btrfs device errors` Prometheus metric + Gatus alert
35. Monitor BTRFS transaction commit latency (`/sys/fs/btrfs/*/allocation/...`)
36. Consider `btrfs-usage-breakdown` service that logs per-subvolume usage monthly

### General SystemNix

37. Verify all existing `onFailure` handlers actually fire (test with `systemctl fail <service>`)
38. Audit all systemd services for `startLimitBurst` consistency
39. Consider adding `systemd-analyze calendar` verification for all custom timers at eval time
40. Add a `btrfs-health summary` CLI command that prints a human-readable status overview
41. Consider whether `/data` needs its own emergency reserve (separate filesystem)
42. Review whether the existing `gcBlockThreshold = 10` should be lowered now that balance is automated
43. Add documentation for manual recovery procedures in `docs/troubleshooting/btrfs-maintenance.md`

### Testing

44. Write a VM test that creates a BTRFS filesystem, fills it, and verifies balance reclaims space
45. Write a test that verifies the emergency reserve provides instant free space (would catch BUG 1)
46. Test balance with `-dusage=90` vs `-dusage=50` to see which reclaims more on a 93% full filesystem
47. Benchmark balance IO impact on running services (Helium, niri responsiveness)
48. Test that `Persistent = true` timers fire after a missed schedule (e.g., system was off on Monday)

### Documentation

49. Update `docs/troubleshooting/btrfs-metadata-enospc-recovery.md` with the new automated balance prevention
50. Write a `docs/runbooks/btrfs-emergency-response.md` for the manual steps when the system hits ENOSPC despite all automation

---

## g) Questions I Cannot Answer Myself

### Q1: Where should the emergency reserve file live to avoid BTRFS snapshot reference issues?

The reserve at `/btrfs-emergency-reserve` (in `@` root subvolume) is snapshotted daily by btrbk, which means deleting it won't free space until the snapshot expires (14 days). Options I see:

- Create a new `@emergency-reserve` subvolume excluded from btrbk
- Put it on one of the existing `@cache-*` subvolumes (e.g., `@cache-home`)
- Put it on `/data` (also snapshotted, same problem)
- Accept the limitation and redesign the reserve as a "preventive buffer" only

Which approach do you prefer? Or do you have a different idea?

### Q2: Is the `fallocate` + `compress=zstd` interaction verified on kernel 6.x?

I assumed `fallocate` allocates real uncompressed extents on BTRFS, but I'm not 100% certain this holds on your kernel version with `compress=zstd` active filesystem-wide. Should I use `dd if=/dev/urandom` instead to guarantee real block allocation, or is `fallocate` known-good on your kernel?

### Q3: Should the balance also cover `/data` (the separate BTRFS filesystem)?

Currently the balance scripts only target `/`. The `/data` partition (Docker volumes, Immich, AI models) has its own chunk allocation and can also fragment. Should I add parallel balance services for `/data`, or is the `/` filesystem the only one that has hit ENOSPC?

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
