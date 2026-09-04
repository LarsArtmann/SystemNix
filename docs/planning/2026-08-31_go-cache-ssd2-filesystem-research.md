# SSD 2 as dedicated Go build cache — filesystem research (XFS vs "XFS+VDA" vs current buildcache recipe)

_Date: 2026-08-31. Status: research + recommendation, NOTHING executed. Reformatting SSD 2 is a user-run sudo step._

## The question

> "XFS vs XFS + VDA + whatever we already do on /mnt/buildcache (is /mnt/ssd-ext4 the same?)"
> Goal: repurpose SSD 2 (SanDisk SDSSDA240G, serial `174244451713`, currently btrfs label `ssd-btrfs`, unmounted) as the dedicated Go build cache SSD.

## Naming disambiguation (verified live)

- There is **no `/mnt/ssd-ext4` mount today**. `ssd-ext4` was SSD 1's ORIGINAL label/mount (2026-08-14 session); SSD 1 was relabeled `buildcache` and is today's `/mnt/buildcache` (ext4, `noatime,lazytime,commit=120,data=writeback`, by-id `ata-SanDisk_SDSSDA240G_174444471311-part1`). Same drive, renamed. Stale empty dirs `/mnt/ssd`, `/mnt/ssd-ext4`, `/mnt/ssd-btrfs` still exist.
- SSD 2 today: `/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1`, btrfs `ssd-btrfs`, **unmounted**, watched by smartd (`-d sat`), FROZEN by the 2026-08-14 three-drive decision ("do not touch; yet"). This doc is the "yet".
- Both SanDisks hang off the **same JMicron JMS567 port-multiplier bridge (usb 8-1)** → shared ~5 Gbps link and shared wedge-fate. A second SSD does NOT add bandwidth.

## "VDA" does not exist (verified 2026-08-31)

No filesystem called VDA exists in the kernel tree, nixpkgs (`mkfs.vda` = 0 hits), or the entire Phoronix archive through Aug 2026. `/dev/vda` is just the first **virtio disk** device name (VMs) — the likely source of the term. Citrix "Linux VDA" (Virtual Delivery Agent) is unrelated.

The real neighbor is **VDO (dm-vdo)**, mainlined in kernel 6.9 (Red Hat dedupe+compression DM target, normally under XFS). Verdict for this disk: **NO**.

1. The SandForce SF-2000 controller **already does inline hardware compression** (DuraWrite): compressible writes get write amplification <1.0 — Go object files are exactly the compressible case. Software VDO compression/dedupe on top is redundant with the controller.
2. Overheads are pure loss for a cache disk: ~3 GB disk metadata reservation, UDS dedupe index RAM (250 MB default for a ~256 GB window), a single `journalQ` write-path thread, LZ4 CPU on every 4 KB write — all to save space on a 224 GB disk that has none to save.
3. NixOS support would be hand-rolled LVM-VDO config for zero benefit.

## btrfs (keep as-is)? NO

Could keep the existing btrfs and mount `nodatacow` for the Go cache — but `nodatacow` implies `nodatasum` and disables compression (btrfs(5)), leaving btrfs's worst property for this workload: **CoW metadata churn on millions of small files**. Measured on THIS EXACT DRIVE PAIR (2026-08-14 benchmarking session, `docs/status/archived/2026-08-14_12-30_ssd-recovery-benchmarking-session.md`):

| Metric (incompressible data, direct IO)            | ext4            | btrfs (zstd)    |
| -------------------------------------------------- | --------------- | --------------- |
| 4K random read IOPS / latency                      | 1,756 / 234 µs  | 2,037 / 503 µs  |
| 4K random write IOPS / latency                     | 751 / 112 µs    | 869 / 173 µs    |
| Sequential write (fdatasync)                       | 136 MB/s        | 342 MB/s        |
| Sequential write with ext4 `data=writeback`        | ~2x (est. 280)  | n/a             |

Build caches are small-file, stat-heavy → the 2x random-read latency gap is the number that matters; ext4's seq-write deficit was diagnosed as the ordered-mode journal tax and is already fixed on the recipe via `data=writeback`.

## ext4 (current buildcache recipe) vs XFS — the real decision

**Both are good; the delta for Go-cache workloads is modest.** What the research (xfs(5), kernel docs, LWN 476263, Phoronix Linux 7.0 FS suite, OpenBenchmarking 5.14 SSD suite) establishes:

- **XFS journals metadata only — there is no data-journaling mode at all**, so no `data=writeback`-style tradeoff exists. Crash consistency is unconditional (metadata always recoverable via log replay). ext4+`data=writeback` buys speed by *relinquishing* the data-vs-metadata ordering guarantee; XFS gives metadata-only-journal performance shape without giving up the guarantee. For a content-verified cache both are safe; XFS is simply the cleaner story.
- **XFS enforces the same data-before-metadata-commit flush ordering as ext4 ordered mode** — the win over ext4 is *amortization*: delayed logging (CIL) coalesces hot metadata in RAM and batches log writes (LWN: pre-CIL XFS "almost all I/O traffic was the journal"; post-CIL "metadata performance and scalability can be considered a solved problem"). On a DRAM-less controller behind a USB bridge — where every flush costs real latency — batching matters.
- **Parallelism is XFS's territory**: XFS scales metadata ops linearly to ~8 threads while ext4 degrades (LWN); 4K random writes and sequential writes led by XFS in the Linux 7.0 Phoronix suite; geomean FS-Mark-class suites XFS 185% vs ext4 163%. `go build -p N` is exactly the many-thread metadata case. Single-threaded metadata ops remain slightly ext4-favoring.
- **lazytime works on XFS** (since 4.17) — pairs with `noatime` for the stat-heavy case.
- **Precedent on this box**: the analogous hot-data role (ClickHouse, `/var/lib/clickhouse`) already runs XFS (`noatime,inode64,logbufs=8,logbsize=32k`). Consistency argument.
- XFS caveats, honestly: unshrinkable (irrelevant for a dedicated cache disk); fatal device errors → forced shutdown (filesystem-agnostic pain class on this flaky bridge — ext4 also aborts on journal IO errors); `nobarrier` no longer exists (removed 4.19) so bridge flush honesty is load-bearing; recovery is offline `xfs_repair` (rarely needed).

**Recommendation: XFS, `noatime,lazytime`** — metadata-only journaling (no writeback tradeoff), best parallel-metadata record, matches the box's hot-data precedent, and we must reformat anyway to leave btrfs. The current ext4 recipe is an equal-second (proven on the sibling drive, zero novelty); either beats btrfs decisively. Nobody should carry VDO/VDA.

## What dedicating SSD 2 to Go actually buys (and what it doesn't)

- **Buys**: capacity isolation (go-build is the largest, fastest-growing consumer — 64 GiB in Aug 2026, and gopls defeats Go's LRU trimming by refreshing mtimes, so it is effectively unbounded; the 90%-watermark `go clean -cache` guard currently threatens the WHOLE shared buildcache); blast-radius isolation (reformat / `go clean` without touching npm/cargo/rust/sccache); a second TRIM-less reformat cadence slot.
- **Does NOT buy speed**: same drive model, same USB link — GOCACHE on SSD 2 ≈ GOCACHE on buildcache. If speed is the goal, the honest answer is the **Samsung 970 EVO Plus** (4K QD1 35.3k/79.2k IOPS, fsync 0.78 ms vs this drive's ~1.7k/0.75k IOPS) — but that competes with the decided `/nix` + hot-DB layout; a ~64-80 GB GOCACHE partition there would be the real performance play. User decision, not assumed here.
- **Conflict to resolve**: TODO_LIST P2 earmarks SSD 2 for Docker storage. Recommendation: Go cache wins — Docker layers are content-addressed and already compressed (the btrfs-zstd-Docker plan was the weaker idea anyway: double compression on a DuraWrite controller), Docker's footprint here is small, and Go cache churn is the daily interactive pain. Move the P2 item or mark it superseded if Go cache is chosen.

## ⚠️ Before wiping: SSD 2 likely holds 22 family photos

The 2026-08-14 session copied `~/Pictures/me/` (22 files, 32.5 MiB) to BOTH drives. ext4 copy verified cleaned; the **btrfs copy was never verified/removed** (drive unmounted since). Salvage first, then wipe:

```bash
mkdir -p /tmp/ssd2-rescue
sudo btrfs restore -D /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1 /tmp/ssd2-rescue   # -D = dry-run, lists what would be restored
sudo btrfs restore /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174244451713-part1 /tmp/ssd2-rescue       # real restore
# verify /tmp/ssd2-rescue/me/ (22 files, sha256 vs ~/Pictures/me/), THEN wipe below
```

## Migration plan (user-run; session has no sudo)

1. Salvage photos (above). 2. Wipe + format: `sudo wipefs -a <by-id-part1> && sudo mkfs.xfs -f -L gocache <by-id-part1>` (optional `-m reflink=0` to skip refcount trees a cache never uses). 3. Nix: add a `services.gocache` module (or parameterize `services.buildcache` for multi-disk) with a `fileSystems."/mnt/gocache"` entry mirroring buildcache.nix:168-187 — same `nofail` + `x-systemd.automount` + `x-systemd.device-timeout=2s` + `x-systemd.device-bound` stack (the zombie-mount and PSI lessons), options `noatime lazytime` (NO `data=writeback`/`commit` — ext4-only). Init dirs: `go-build`, `go-mod`, `golangci-lint`, `goimports`, `go`. 4. Repoint `home.nix` sessionVariables: `GOCACHE`, `GOMODCACHE`, `GOLANGCI_LINT_CACHE`, `~/.cache/goimports` symlink → `/mnt/gocache/…` (one-time module re-download on GOMODCACHE move; hash-verified, safe). 5. Extend `buildcache-gc` (or add gocache-gc) to cover the new mount with the same 90% watermark. 6. Add gocache metrics to `buildcache-metrics` and a Gatus check. 7. smartd already covers the drive. 8. Update the freeze note + TODO_LIST P2 to record the decision.

## Quiet-window verification benchmark (PSI io some avg10 < 20% only — box was at ~70% during this research)

```bash
fio --name=rr1 --directory=/mnt/gocache --size=2G --direct=1 --ioengine=io_uring --bs=4k --rw=randread --iodepth=1 --time_based --runtime=12 --output-format=json   # expect ~1.7k IOPS, ~234µs class
fio --name=rw1 --directory=/mnt/gocache --size=2G --direct=1 --ioengine=io_uring --bs=4k --rw=randwrite --iodepth=1 --time_based --runtime=12 --output-format=json  # expect ~750 IOPS
```

Compare against the 2026-08-14 ext4/btrfs table above; XFS should land at-or-better than ext4 on randread latency and clearly ahead on parallel metadata (`go build -p16` wall-time on a cold cache is the end-to-end proof).

## Addendum (same day): "What if SSD 2 = Docker?" — corrected facts + tenant analysis

User asked to weigh Docker as the SSD 2 tenant. **Verified live first — two memory records were stale:**

- `docker info`: **Docker Root Dir = `/data/docker`**, storage driver **overlay2 on btrfs** (the QLC `/data` partition, `compress=zstd:3`). The AGENTS.md line "docker lives in `/var/lib/docker` on root; `/data/docker` EMPTY" was WRONG — fixed in AGENTS.md 2026-08-31. TODO_LIST P2's premise (`/data/docker on QLC NVMe today`) is correct.
- **Footprint: ~20.5 GB total, ~88% garbage.** Images 8.6 GB (6.5 reclaimable — old tags like twenty v2.7.3 alongside v2.32.0), build cache 8.2 GB (8.1 reclaimable, 114 entries, 0 active), volumes 3.7 GB (3.6 reclaimable — **129 volumes, 4 active**: `twenty_db-data`, `manifest_pgdata`, `twenty_server-local-data`, one redis). Live content ≈ 4-5 GB: two postgres DBs, Twenty file storage, running images.
- The ONLY irreplaceable Docker state = the two postgres volumes. Everything else re-pulls/rebuilds.

**What Docker-on-SSD2 buys:** QLC offload — but only ~2% of the crowded `/data` (695 G models/Steam); removes layer-extraction CoW churn from `/data` btrfs; removes 30d/12w pool-receive pinning churn (NOT forever — that argument was an artifact of the stale root-fs belief); pg fsync likely no worse than QLC-under-load (~200 ms measured on this NVMe under load).

**What it costs:** couples Twenty + Manifest + Dozzle + BOTH postgres DBs to the JMS567 bridge — the box's least reliable link (9-day outage this month, 11 re-enumerations in 3.5 h in August); puts the only precious container state on a DRAM-less, no-TRIM drive with 34/35 historical dirty shutdowns (pg_dumps to pool remain the safety net); migration downtime + full wiring.

**The cheaper fix for most of the Docker pain: prune, don't move.** `docker builder prune -a` (~8.1 G) + dangling/old image prune + `docker volume prune` after auditing the 125 orphans → live footprint ~2-4 G, `/data` relief achieved with zero migration risk. If accumulation recurs (the "always latest" image policy does churn tags), wire a guarded monthly `docker-gc` oneshot instead of a disk move.

**If Docker-on-SSD2 is chosen anyway (runbook):** reformat **XFS `-n ftype=1`** — overlay2 REQUIRES d_type (`ftype=1` is mkfs.xfs default with crc, but pass it explicitly); do NOT keep btrfs (CoW on container writable layers + btrfs storage driver is the deprecated path). Mirror the buildcache mount stack (`nofail`, automount, device-timeout=2s, device-bound, `noatime lazytime`). Wire `virtualisation.docker.daemon.settings.data-root = "/mnt/docker"` + explicit `storage-driver = "overlay2"`. Migration: maintenance window → `systemctl stop docker.socket docker containerd` → `rsync -aH /data/docker/ /mnt/docker/` → repoint → restart → smoke (`docker ps`, both pgs answer, twenty/manifest vHosts 200) → keep `/data/docker` as rename-aside for one week → delete. Add `ioTier.background` on docker.service (already true via defaults?) and keep SigNoz/ClickHouse off the disk (unchanged). Photos salvage step still applies first.

## Follow-up: should `/mnt/buildcache` (SSD 1) also convert ext4 → XFS "one day"?

Answered 2026-08-31: **yes at the next natural reformat, but never as a scheduled migration.**

- **No measured problem to fix.** The ext4 `data=writeback` recipe was chosen from benchmarks on THIS drive (234 µs randread, seq-write tax fixed) and has run clean since 2026-08-14. The XFS-vs-ext4 delta for this workload is single-digit percent on a disk whose real ceiling is the USB link + SandForce controller, not the fs.
- **Migration logistics are the real cost.** Converting in place is impossible: ~110-150 GB of caches must transit somewhere — the only staging ground is the QLC NVMe the disk exists to protect (root has its own 90%+ history), or the caches are lost and rebuilt (go-build 64 G ≈ hours of recompilation across every project).
- **The free conversion window already exists.** TRIM does not pass the bridge, so the documented fix for stale-block write degradation is a reformat anyway. A reformat wipes the caches regardless of fs — at that moment `mkfs.xfs -L buildcache` costs nothing extra, drops the `data=writeback` tradeoff (metadata-only journaling, unconditional crash consistency), recovers ~4-5 GB of fixed ext4 overhead (3.5 G pre-allocated inode table + 1 G journal vs XFS dynamic inodes), and keeps every other mount option (`noatime lazytime nofail automount device-bound` are fs-agnostic).
- **Doctrine:** any FUTURE reformat/repurpose of a cache disk (SSD 1 reformat, SSD 2 partitioning, new disks) defaults to **XFS** without re-litigating; existing healthy ext4 caches are left alone until their next reformat.

## Revised open decisions

1. **Recommended overall: SSD 2 = Go cache (XFS); Docker stays on `/data` after a one-time prune** (and optionally a guarded docker-gc). Docker-on-SSD2 trades pg-data durability for ~2% QLC relief — poor exchange.
2. Acceptable split if both wants persist: SSD 2 partitioned — gocache (XFS, ~160 G) + docker (XFS ftype=1, ~64 G). Both tenants fit; one bridge, shared fate.
3. XFS vs ext4 recipe: either correct for either tenant; btrfs rejected.
4. Optional Samsung GOCACHE slice remains the only path that buys real speed.
