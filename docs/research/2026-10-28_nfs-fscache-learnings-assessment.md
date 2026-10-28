# NFS FS-Cache — Video Learnings & Applicability Assessment

**Date:** 2026-10-28
**Status:** REFERENCE ONLY — no config changed, nothing queued. Captures a technique learned from a video and its applicability to this fleet, so the day NFS enters the picture the recipe is already written down.
**Source:** Techno Tim, "I Didn't Know Linux Could Cache NFS Files Locally" (2026-10-16, 9:10) — https://youtu.be/KVNAp7MAApc · companion write-up with all commands: https://technotim.com/posts/cache-nfs-files-locally-with-linux-fs-cache-and-cachefiles/

---

## Verdict up front

1. **The literal technique does not apply today** — this fleet mounts zero NFS shares (verified by grep across `modules/`, `platforms/`, `systems/`, `docs/agents/`, `docs/services/`; the only `rg -i 'nfs'` hits were substring false positives, see §5). Models are already local NVMe on evo-x2.
2. **We already get the video's headline win through different means** — with 124.3 GiB MemTotal, repeat model loads ride the page cache (the same RAM effect the video flags at 7:25). The residual gap is only the biggest models (~100–200G) whose cold reloads re-hit the QLC root.
3. **The one real future use case:** sharing `/data/models` from evo-x2 to the MacBook Air (256G SSD 90%+ full — cannot hold copies). NFS export + FS-Cache is the video's exact recipe, and NixOS support is verified in the pinned nixpkgs input: `services.cachefilesd.enable` (module `nixos/modules/services/network-filesystems/cachefilesd.nix`, options `enable` + `cacheDir`, cacheDir tmpfiles-managed). That module + the host `tasks/filesystems/nfs.nix` module are all it takes.
4. **Do not expect the 6× number from a QLC→Samsung model move** — his 6× was network→SSD. Local sequential shard reads on the Samsung vs QLC would be a modest ~1.5–2× (Samsung seq 2.4–2.7 GB/s vs a decent QLC seq path); the 2026-08-31 role-assignment decision (models stay on QLC, bandwidth-bound) stands unless load profiling says otherwise.
5. **The most transferable lesson is methodological**: cold-vs-warm benchmarks are meaningless without flushing the RAM page cache (§4). That maps directly onto this repo's benchmark discipline (`scripts/bench-disk.sh` baselines, quote-scrutiny rule).

---

## 1. What the video teaches (mechanics)

Three pieces:

| Piece | Role |
|---|---|
| **FS-Cache** | Kernel framework — generic local caching layer for network filesystems |
| **CacheFiles** | Kernel module that stores cached data on a local block device (SSD) |
| **cachefilesd** | Userspace daemon: registers the cache, culls entries when it fills |

- Mount the NFS share with the `fsc` option → each client caches only what *it* reads; originals stay on the server. Per-machine caches, no full copies.
- Cache backing store: a size-capped loopback file (`fallocate` a fixed-size image, format ext4 inside, mount it) — bounds the cache without repartitioning.
- Culling thresholds (his values): cull (LRU) when free space drops below **10%**, stop culling back above **25%**, stop admitting new data at **3%**. Same letter pattern for **file-count** thresholds (matters for many-small-files workloads). No TTL — entries live until LRU-culled.
- His benchmark (155G DeepSeek, 74 shards): cold over NFS **565 s** (~280 MB/s — nowhere near his 10G, single-stream NFS reality) → warm from SSD cache **93 s** (~1.7 GB/s), ~6×. Single 3.3G shard: 4.5 s → 1.7 s (~2.5×).
- Limitations he calls out: **read cache only** (writes unaffected; no benefit for read-once data); RAM page cache pollutes naive A/B (flush before measuring); taxonomy — app-data caching = Redis/Valkey, block-level = bcache/dm-cache. FS-Cache's niche is "files on NFS, read repeatedly".

## 2. Applicability to this fleet (verified 2026-10-28)

| Question | Finding |
|---|---|
| Do we mount NFS anywhere? | **No.** Grep across module/system/platform/docs trees returns zero real hits. |
| Do we have his "reload big models over and over" pain? | Partially. Models are local on QLC `/data` (~589G AI models: ai 291G + models 210G + llamacpp 92G). With 124.3 GiB RAM, most models fit the page cache warm. The ~100–200G class can be evicted under memory pressure → those reloads hit QLC 4K-class latency (620 IOPS QD1), though shard reads are sequential (bandwidth-bound, QLC seq is adequate). |
| Would a hot-model Samsung `/mnt/hot` subvol (doctrine C) help? | Maybe 1.5–2× on the biggest-model cold load, at the cost of Samsung capacity. Only worth it if profiling shows model reloads are a real bottleneck. NOT the 6× headline. |
| Is NixOS support real? | **Verified in the pinned nixpkgs input** (store path `2g1ydkkflg5kl8hb1f8js0s0p9v4gl53-source`, 2026-10-28): `services/cachefilesd.nix` in `network-filesystems/` + `tasks/filesystems/nfs.nix`. |
| MacBook Air as consumer | 256G SSD 90%+ full — cannot hold model copies at all. NFS + fscache is the only way it touches the model library with warm-read behavior, and its cache image must be tiny (single-digit GB) given disk pressure. |

## 3. The recipe, if NFS ever enters (NixOS-native sketch)

```nix
# evo-x2 (server side, sketch only — NOT deployed):
fileSystems."/export/models" = {
  device = "/data/models";
  fsType = "none";
  options = [ "bind" "ro" ];
};
services.nfs.server.enable = true;
services.nfs.server.exports = ''
  /export/models 192.168.1.0/24(ro,fsid=0,no_subtree_check)
'';

# client (macOS cannot use FS-Cache — Linux only; this is for a future
# Linux client. The Mac story is plain NFS + its own SMB/NFS client cache):
services.cachefilesd.enable = true;   # options: enable, cacheDir
fileSystems."/mnt/models" = {
  device = "evo-x2.home.lan:/models";
  fsType = "nfs";
  options = [ "ro" "fsc" ];           # fsc = FS-Cache for this mount
};
```

Caveats to resolve before anyone builds this for real: cachefiles backing-FS constraints (the video uses a dedicated ext4 image — do the same rather than pointing `cacheDir` at a btrfs subvol untested), cache sizing on a 90%-full Mac SSD, and read-only export so the cache can never mask a write-path change. Treat this block as a starting sketch, not a plan.

## 4. Transferable lessons that apply NOW (no NFS needed)

1. **Benchmark hygiene**: a "cold" read that isn't preceded by a page-cache flush measures RAM, not the disk (`echo 3 | sudo tee /proc/sys/vm/drop_caches` class, or read enough data to blow through the cache). Tim's own first shard test (4.5 s) was partly RAM. Any future model-load or disk A/B here gets the same treatment as the 2026-10-16 post-heatsink Samsung re-bench: state what was flushed, quote the flushed numbers.
2. **Tool taxonomy confirmation**: this fleet already routes by access pattern (his closing point): hot-DBs → Samsung subvols (latency-bound), `/nix` → btrfs zstd 1.89× (immutable read-mostly), journal/caddy-logs → hot tier (churn), AI models → QLC (bandwidth-bound). Nothing to change; the video is an external sanity check of doctrine C's shape.
3. **Size-cap every cache**: the fixed-size loopback-image pattern (bounded resource, explicit failure mode) is the same discipline as MemoryMax/MemoryHigh on services — prefer it over any unbounded cache dir if fscache is ever enabled.

## 5. Search gotcha recorded en passant

`rg -i 'nfs'` false-positives on this repo: `mnfst-postgres-1` (the manifest container name) contains the substring `nfs`. Any future "do we use NFS?" audit must filter `mnfst`/read matches in context — a bare hit list is not evidence.

## Refresh trigger

Revisit if: (a) NFS enters the fleet (model sharing to the MacBook Air, any NAS-class share) — then §3 becomes a real design + `docs/todo/` row; (b) profiling shows big-model cold reloads on evo-x2 are a genuine bottleneck — then evaluate a `+C` hot-model subvol against §2's ~1.5–2× estimate; (c) a nixpkgs bump moves/renames the `cachefilesd` module.
