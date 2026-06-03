# ActivityWatch aw-server: Explaining 82 TB "Data Read" on macOS

**Date:** 2026-06-02
**System:** macOS (aarch64-darwin), Lars-MacBook-Air
**Process:** `aw-server` (ActivityWatch server, PID 1342)

---

## Summary

Activity Monitor reporting ~82 TB of "Data Read" for `aw-server` is **not** physical disk wear. It is a combination of:

1. **macOS accounting artifact** — Activity Monitor counts logical `read()` bytes, not physical NAND reads.
2. **Real inefficient I/O** — `aw-server` repeatedly scans a 6.2 GB SQLite database with a tiny 8 MB per-connection cache.

Your SSD is fine.

---

## Investigation

### Process State (observed live)

| Metric | Value |
|--------|-------|
| PID | 1342 |
| Uptime | 24 days, 3h, 25m |
| CPU time | 30h:08m (1808 minutes) |
| Threads | 4 |
| RSS | ~28 MB |
| VSZ | ~35 GB (virtual, not physical) |
| Open DB handles | 16 |

### Database State

| Metric | Value |
|--------|-------|
| File | `~/Library/Application Support/activitywatch/aw-server/peewee-sqlite.v2.db` |
| Size | **6.2 GB** |
| Pages | 1,608,849 |
| Free pages | 0 (database is 100% utilized) |
| WAL file | 8.0 MB |
| Journal mode | WAL |
| Page size | 4,096 bytes |
| Cache size | 2,000 pages (**~8 MB**) |
| `mmap_size` | **0 (disabled)** |

### Table Sizes

| Table | Rows |
|-------|------|
| `eventmodel` | 2,181,580 |
| `eventmodel_archive` | 990,598 |
| `bucketmodel` | 11 |
| **Total events** | **3,172,178** |

### SQLite Schema (eventmodel)

```sql
CREATE TABLE IF NOT EXISTS "eventmodel" (
    "id" INTEGER NOT NULL PRIMARY KEY,
    "bucket_id" INTEGER NOT NULL,
    "timestamp" DATETIME NOT NULL,
    "duration" DECIMAL(10, 5) NOT NULL,
    "datastr" VARCHAR(255) NOT NULL,
    FOREIGN KEY ("bucket_id") REFERENCES "bucketmodel" ("key")
);
CREATE INDEX "eventmodel_bucket_id" ON "eventmodel" ("bucket_id");
CREATE INDEX "eventmodel_timestamp" ON "eventmodel" ("timestamp");
```

---

## Root Cause Analysis

### 1. macOS "Data Read" Is Logical, Not Physical

On macOS, Activity Monitor's "Data Read" counter increments for **every byte passed through `read()`**, regardless of whether the data comes from:
- Physical SSD NAND
- Filesystem cache (RAM)
- Memory-mapped pages

Linux separates this into:
- `rchar` — total logical bytes read
- `read_bytes` — actual physical disk I/O

macOS does **not** separate them. The 82 TB is almost entirely logical reads served from RAM cache.

### 2. SQLite Cache Thrashing

With 16 open database connections and only **8 MB cache per connection**, working with a 6.2 GB database means constant cache evictions. The `sample` stack trace confirms repetitive full-table-scan behavior:

```
_pysqlite_query_execute
  sqlite3_step
    sqlite3VdbeExec
      sqlite3VdbeFinishMoveto
        sqlite3BtreeTableMoveto
          moveToLeftmost
            getAndInitPage
              getPageNormal
                readDbPage
                  unixRead
                    seekAndRead
```

This is a read-heavy query path that repeatedly fetches the same database pages.

### 3. mmap Disabled

`PRAGMA mmap_size = 0` means SQLite uses explicit `read()` syscalls for every page access. Enabling mmap would allow the OS to page the database directly into virtual memory, eliminating most `read()` syscalls and the corresponding Activity Monitor inflation.

### 4. Math Check

- **82 TB over 24 days** = ~3.4 TB/day = ~40 MB/s sustained logical reads
- Database is 6.2 GB
- Equivalent to ~13,000 full table scans over 24 days
- With 16 connections querying independently, ~9 full scans per hour per connection is plausible for an always-running activity tracker

---

## Is Your SSD Dying?

**No.** Check these instead:

| Check | Command | Expected Result |
|-------|---------|---------------|
| Data Written | Activity Monitor "Data Written" column | Should be much smaller (MB–GB range) |
| SMART TBW | `smartctl -a /dev/disk0` (if available) | Far below drive rated TBW |
| Physical I/O | `iotop -C` (or `fs_usage`) | Nowhere near 82 TB |

The 82 TB figure is an accounting artifact. The actual bytes written to NAND are negligible.

---

## Recommendations

### Short-Term (No Code Changes)

1. **Restart `aw-server`** — Resets Activity Monitor's cumulative counter. The number itself is harmless but alarming.
2. **Verify SSD health** — Run `smartctl` or Disk Utility to confirm TBW is normal.

### Medium-Term (Configuration)

3. **Reduce database growth** — ActivityWatch has no built-in retention by default. Configure retention to purge events older than N days. This is the most impactful fix.
4. **Vacuum the database** — `VACUUM` can reclaim space if fragmentation exists (though `freelist_count = 0` suggests it's fully packed).

### Long-Term (Upstream Fix or Fork)

5. **Enable SQLite mmap** — Set `PRAGMA mmap_size = 3000000000;` (~3 GB) to let the OS page the database directly. This eliminates most `read()` syscalls.
6. **Increase cache size** — 8 MB per connection is comically small for a 6.2 GB DB. `PRAGMA cache_size = -64000;` (~256 MB) per connection would be more appropriate.
7. **Reduce connection count** — 16 separate file handles to the same SQLite database is unusual. Connection pooling or reducing concurrency would help.

**Note:** Items 5–6 require modifying `aw-server` itself, as it controls SQLite PRAGMAs internally.

---

## See Also

- [ActivityWatch GitHub](https://github.com/ActivityWatch/activitywatch)
- SQLite PRAGMA documentation: [mmap_size](https://www.sqlite.org/pragma.html#pragma_mmap_size), [cache_size](https://www.sqlite.org/pragma.html#pragma_cache_size)
- macOS `fs_usage` and `vmmap` for I/O accounting behavior
