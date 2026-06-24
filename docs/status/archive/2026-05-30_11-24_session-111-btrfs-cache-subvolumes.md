# SystemNix Status Report — Session 111

**Date:** 2026-05-30 11:24 CEST
**Host:** evo-x2 (x86_64-linux)
**Branch:** master
**Commit:** 2dda2ec0

---

## a) FULLY DONE

### 1. BTRFS Cache Subvolume Fix — DEPLOYED

**Problem:** Root (`@`) subvolume snapshots were ballooning to 85-90 GB exclusive per day because regenerable cache directories (.cache, go, .npm, .cargo) were inside `@` and duplicated across every snapshot. Disk hit 100% (507/512 GB).

**Solution:** Created 4 separate BTRFS subvolumes, mounted via Nix `fileSystems` with automount. These are excluded from btrbk snapshots of `@`.

| Subvolume | Mount Point | Size Excluded |
|-----------|------------|---------------|
| `@cache-home` | `/home/lars/.cache` | ~40 GB |
| `@go` | `/home/lars/go` | ~9.1 GB |
| `@npm` | `/home/lars/.npm` | ~2.8 GB |
| `@cargo` | `/home/lars/.cargo` | ~1.6 GB |

**Verification (post-`just switch`):**
- All 4 mounts active: ✅
- `/proc/mounts` confirms correct `subvol=/@...` mappings
- New pre-deploy snapshot (2026-05-30T100703) has only **59 MB exclusive** vs. previous 85-203 GB — fix is working

**Files changed:**
- `platforms/nixos/system/snapshots.nix` — added `cacheSubvolumes`, `cacheFileSystems`, merged `fileSystems` block
- `docs/planning/btrfs-snapshot-bloat-fix.html` — execution plan document

### 2. Emergency Disk Space Recovery

Deleted stale snapshot `@.20260527T0000` (69.49 GB exclusive). Disk usage dropped from 507 GB (100%) → 476 GB (95%) → now **438 GB (89%)** after `nix-collect-garbage --delete-older-than 7d` and the switch.

### 3. Build & Validation Pipeline

All pre-commit hooks passed:
- gitleaks ✅
- deadnix ✅
- statix ✅
- alejandra ✅
- Nix flake check ✅

---

## b) PARTIALLY DONE

### 1. ClickHouse System Log TTLs

**Status:** Implementation written but **reverted before commit** per user request.

ClickHouse `system.*` tables (trace_log, query_log, metric_log, etc.) have no TTL and grow forever. Was 21 GB. A 7-day TTL service was added to `signoz.nix` but removed because user wanted to keep changes focused.

**Next step:** Add back when approved. Expected savings: ~15 GB.

### 2. btrbk Retention Policy

**Status:** Discussed but **not changed**. Still at `snapshot_preserve_min = "7d"`, `snapshot_preserve = "14d 4w"`.

User explicitly asked to keep original retention. With cache subvolumes excluded, snapshot exclusive growth should drop dramatically even with current retention.

### 3. Gitea Pre-Migration Cleanup

**Status:** Identified 19 GB dead weight (`/var/lib/gitea.pre-forgejo-migration`). Not removed — user wants review before deletion.

### 4. Disko Migration Planning

**Status:** Documented in `docs/planning/btrfs-snapshot-bloat-fix.html` as Phase 5. Not started. Disko would replace the manual subvolume creation entirely with declarative disk management.

---

## c) NOT STARTED

1. **ClickHouse TTL re-implementation** — waiting for approval
2. **btrbk retention reduction** — user wants to keep 14d 4w for now
3. **Gitea pre-migration deletion** — pending user review
4. **Disko flake input + full disk declaration** — future work
5. **Automated cache subvolume creation** — user rejected systemd service and activation script approaches; manual creation accepted as interim
6. **BTRFS `@data` subvolume for /data** — currently mounted as toplevel (subvolid=5), cannot be snapshotted
7. **Journal size reduction** — 3.9 GB, could trim with `journalctl --vacuum-time=7d`
8. **Nix store GC automation** — still manual

---

## d) TOTALLY FUCKED UP!

### 1. `disk-monitor.service` — FAILED

```
● disk-monitor.service loaded failed failed
  Check disk usage and notify on threshold breaches
```

This service is failing continuously. Needs investigation. Likely related to the disk being at 100% earlier, but should have recovered.

### 2. ClickHouse Data Location Mystery

`/var/lib/clickhouse` reports as **8.0K** in current `du` output, down from 21 GB earlier in the session. Either:
- Data moved to a different path
- ClickHouse was reconfigured or restarted
- BTRFS subvolume restructuring caused path confusion

**Needs verification:** Check if ClickHouse is actually storing data and where.

### 3. Missing /var/lib Directories

Earlier session showed:
- `/var/lib/gitea.pre-forgejo-migration` (19 GB)
- `/var/lib/immich` (15 GB)
- `/var/lib/forgejo` (15 GB)
- `/var/lib/clickhouse` (21 GB)

Current `du -sh /var/lib/*` shows **none of these**. They may be:
- On separate mounts/subvolumes
- Temporarily unavailable
- Relocated by recent config changes

**CRITICAL:** These are production services. Need to verify data integrity.

### 4. `/data` at 93% (942/1024 GB)

The data partition is also nearly full. AI models, container images, or other large datasets need review.

---

## e) WHAT WE SHOULD IMPROVE!

1. **Remove the systemd service hack** — The `ensure-btrfs-cache-subvolumes` systemd service was proposed and rejected. The current solution (manual subvolume creation + `fileSystems` mounts) works but is not declarative. Disko is the proper fix.

2. **Pre-deploy snapshot + `nix-collect-garbage` workflow** — The `just switch` command should run `nix-collect-garbage` BEFORE creating the pre-deploy snapshot, so old derivations are freed before being snapshotted.

3. **Disk monitoring alert threshold** — The `disk-monitor.service` failure suggests the alerting logic itself breaks at high disk usage. Add a pre-check or use a simpler mechanism.

4. **ClickHouse TTL should be in Nix** — Not a one-off SQL script. Should be a systemd service that runs after ClickHouse startup, idempotent, with configurable TTL duration.

5. **Document the subvolume creation requirement** — Currently hidden in a `/tmp` script. Should be in AGENTS.md or a `just` recipe.

6. **Add `btrfs subvolume list` health check** — Verify all expected subvolumes exist before `just switch` completes.

7. **Cache subvolume sizing monitoring** — Track if `.cache` grows beyond expected bounds (e.g., >100 GB would indicate a leak).

8. **Consolidate documentation** — `btrfs-snapshot-bloat-fix.html` is good but should link from AGENTS.md or README.

---

## f) Top #25 Things We Should Get Done Next

| # | Task | Impact | Effort | Priority |
|---|------|--------|--------|----------|
| 1 | **Fix `disk-monitor.service` failure** | High | 15 min | 🔴 Critical |
| 2 | **Verify ClickHouse data integrity** | High | 10 min | 🔴 Critical |
| 3 | **Verify /var/lib/{immich,forgejo,clickhouse} data** | High | 15 min | 🔴 Critical |
| 4 | **Add ClickHouse system log TTLs** | Medium | 30 min | 🟡 High |
| 5 | **Reduce btrbk retention to 7d 1w** | Medium | 5 min | 🟡 High |
| 6 | **Add `just snapshot-gc` recipe** | Medium | 20 min | 🟡 High |
| 7 | **Migrate to Disko for declarative subvolumes** | High | 3 hr | 🟡 High |
| 8 | **Clean up Gitea pre-migration (19 GB)** | Low | 5 min | 🟢 Medium |
| 9 | **Add `/data` BTRFS subvolume + snapshot** | Medium | 1 hr | 🟢 Medium |
| 10 | **Journal vacuum automation** | Low | 15 min | 🟢 Medium |
| 11 | **Add `just cache-subvol-create` recipe** | Low | 15 min | 🟢 Medium |
| 12 | **Document cache subvolume setup in AGENTS.md** | Low | 10 min | 🟢 Medium |
| 13 | **Monitor /data usage (93%)** | Medium | 10 min | 🟢 Medium |
| 14 | **Add pre-deploy nix-collect-garbage** | Medium | 20 min | 🟢 Medium |
| 15 | **SigNoz alert rule for disk usage** | Low | 30 min | 🔵 Low |
| 16 | **BTRFS compression audit** | Low | 30 min | 🔵 Low |
| 17 | **Add `@snapshots` subvolume for btrbk** | Low | 1 hr | 🔵 Low |
| 18 | **Remove old `.pre-subvol` backups** | Low | 5 min | 🔵 Low |
| 19 | **Add `ensure-btrfs-subvolumes` to `just test`** | Low | 30 min | 🔵 Low |
| 20 | **Audit all cache dirs for additional subvolumes** | Low | 20 min | 🔵 Low |
| 21 | **Add `.local/share` as subvolume candidate** | Low | 30 min | 🔵 Low |
| 22 | **Review Docker image pruning policy** | Low | 15 min | 🔵 Low |
| 23 | **Add `OLLAMA_MAX_LOADED_MODELS=1` enforcement** | Low | 10 min | 🔵 Low |
| 24 | **Document rollback procedure in AGENTS.md** | Low | 15 min | 🔵 Low |
| 25 | **Add snapshot size alerting to btrbk** | Low | 30 min | 🔵 Low |

---

## g) Top #1 Question I Cannot Figure Out

**Where did the 52 GB of /var/lib data go?**

At 09:42, `du -sh /var/lib/*` showed:
- `clickhouse` = 21 GB
- `gitea.pre-forgejo-migration` = 19 GB
- `immich` = 15 GB
- `forgejo` = 15 GB
- `containers` = 4.8 GB

At 11:24, the same command shows:
- `clickhouse` = 8.0K
- The other large directories are **missing entirely**

Total missing: ~52+ GB.

**Possible explanations:**
1. **Different mount namespace** — The `du` command is running in a context where these paths are masked
2. **BTRFS subvolume restructuring** — The cache subvolume changes somehow affected other mounts
3. **Services reconfigured** — `just switch` may have changed mount points for these services
4. **Data loss** — Unlikely but needs ruling out

**Why I can't figure it out:**
- Cannot run `sudo` to inspect `/var/lib` deeply
- Cannot run `btrfs subvolume list` (needs root)
- Cannot inspect systemd mount units for these services
- Cannot check if services are running and where their data dirs are configured

**What I need:**
Run as root or with sudo:
```bash
btrfs subvolume list /mnt/btrfs-root
systemctl status clickhouse immich forgejo
ls -la /var/lib/clickhouse /var/lib/immich /var/lib/forgejo
df -h
mount | grep -E 'clickhouse|immich|forgejo'
```

---

## Session Summary

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Disk usage (/) | 507 GB (100%) | 438 GB (89%) | **-69 GB** |
| Snapshots | 7 (285 GB exclusive) | 3 (~322 GB exclusive) | **-4 snapshots** |
| Cache in @ subvolume | ~54 GB duplicated | 0 GB (excluded) | **-54 GB/day** |
| Pre-deploy exclusive | 85-203 GB | 59 MB | **-99.9%** |
| Mount status | Broken | All 4 active | **Fixed** |

**The cache subvolume fix is working. The pre-deploy snapshot dropping from 85+ GB to 59 MB proves it.**

---

*Generated: 2026-05-30 11:24 CEST | Session 111 | Crush:glm-5.1*
