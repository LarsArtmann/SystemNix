# RAM Optimization Research — evo-x2 (2026-08-16)

> Session research into memory optimizations: measured baseline, ranked
> optimization candidates, deep-dives into Transparent Huge Pages and KSM
> (including a new VM test), and why common assumptions about both features
> don't apply to this machine's workload.

---

## 1. Measured Baseline (2026-08-16)

```
Mem:    93 GiB total, 24 GiB used, 41 GiB buff/cache, 69 GiB available
Swap:   28 GiB zram-only (zstd level=1), 14.8 GiB used, 3.1x compression live
PSI:    memory some/full avg10 = 0.00 — zero memory pressure
```

Top consumers (RSS): golangci-lint 1.3G (transient), iotop 720M (root),
clickhouse 649M, dnsblockd 581M, queue-worker 405M, helium 389M, hermes 275M,
immich 218M+196M. No resident ballooners; the PMA-class incidents are
page-cache, handled by `MemoryHigh=12G`.

Kernel tuning already in place post-incident (see `boot.nix`, `docs/gotchas-archive.md`):

| Setting | Value | Why |
|---|---|---|
| `vm.swappiness` | 150 | zram-only: prefer in-RAM swap over QLC-NAND page-cache reclaim |
| `vm.watermark_scale_factor` | 100 | gradual reclaim, no panic-reclaim bursts |
| `vm.vfs_cache_pressure` | 150 | prefer cheap dentry/inode reclaim |
| `vm.dirty_ratio` / `dirty_background_ratio` | 5 / 1 | spread writeback on QLC NAND |
| zramSwap | 30% (~28 GiB), `zstd(level=1)` | L1 vs L3: 1.7% worse ratio, 11.5% faster compress |
| MGLRU | enabled (`0x0007`) | multi-gen LRU, better under pressure |
| THP | `madvise` | see §3 |

---

## 2. Optimization Candidates (ranked)

| # | Optimization | Impact | Tradeoff | Verdict |
|---|---|---|---|---|
| 1 | **BIOS GPU carveout** — MemTotal 93.9 GiB of ~119 GiB nominal → ~25 GiB sits in iGPU UMA carveout. Lower `UMA Frame Buffer Size` to 8-16G if ollama rarely runs 20G+ models | **Up to +16-24 GiB — biggest single win** | Large local LLMs need it; BIOS reboot | Worth doing |
| 2 | **zram 30% → 50%** (~28 → 47 GiB) | Cheap insurance — the zram-full cliff is page-cache eviction = BTRFS I/O storms. Empty zram costs nothing (in-kernel metadata only) | None real | Worth doing |
| 3 | **MemoryMax audit module** (eval-time, like `timeout-audit.nix`) — flag enabled services missing `MemoryMax` | Prevents future balloons | Occasional oneshot false positives | Good hygiene |
| 4 | **KSM** (`hardware.ksm.enable`) | Only QEMU VM tests have mergeable memory (see §4) | ksmd CPU + side-channel class | Skip |
| 5 | **zram disk writeback** | Offload idle pages to disk | Writes to QLC NAND — the exact thing we avoid | **No** |

---

## 3. Transparent Huge Pages (THP)

### Mechanism

Every memory access needs a virtual→physical translation, cached in the
**TLB** (~1-2k entries). With 4 KiB pages the TLB covers only a few MB —
beyond that, the CPU stalls walking 4-5 levels of page tables in RAM. A 2 MiB
huge page covers 512x more memory per TLB entry, so large working sets get
dramatically fewer page-table walks.

Classical huge pages required boot-time reservation + app changes
(`hugetlbfs`). THP instead does it **transparently**: the kernel
opportunistically assigns 2 MiB pages to anonymous memory, and `khugepaged`
collapses adjacent 4 KiB pages in the background. Apps need zero changes.

### Modes (evo-x2: `[madvise]` — verified in `/sys/kernel/mm/transparent_hugepage/enabled`)

| Mode | Behavior |
|---|---|
| `always` | Kernel tries to hugepage *all* anonymous memory |
| `madvise` | Only regions where the app opts in via `madvise(MADV_HUGEPAGE)` |
| `never` | Disabled |

### Why `always` is not the win it looks like

- **Memory waste** — a 2 MiB page is indivisible; touching one byte pins
  2 MiB physical RAM. Sparse allocations balloon RSS.
- **Latency spikes** — khugepaged collapses trigger memory compaction, which
  can stall allocations for milliseconds. Redis, MongoDB, and Oracle all
  document THP-`always` as a performance *hazard* and recommend `never`/`madvise`.
- Go runtimes (most services here) use their own arena allocator and rarely benefit.

`madvise` is the sweet spot: opted-in workloads (JVM, HPC) get the TLB win;
everything else stays on 4 KiB pages with predictable latency. **No change
recommended.**

---

## 4. Kernel Same-page Merging (KSM)

### Mechanism

Memory deduplication via the `ksmd` kernel daemon:

1. Apps explicitly mark anonymous memory `madvise(MADV_MERGEABLE)` — unlike
   THP, nothing is merged by default
2. `ksmd` wakes every `sleep_millisecs`, scans up to `pages_to_scan` pages of
   *only mergeable regions*
3. Pages with identical checksums are compared; exact matches are replaced by
   **one shared read-only physical page** + copy-on-write
4. Any write triggers a COW fault — kernel copies the page back and unmerges

Key stats (`/sys/kernel/mm/ksm/`): `pages_shared` (unique deduped pages) vs
`pages_sharing` (pages mapped onto them). Ratio = effectiveness.

**Host state (evo-x2): `run=0`, zero sharing — OFF**, and nothing on this box
marks memory mergeable (see §6).

### VM Test — `tests/test-ksm.nix`

Since enabling host KSM needs root, the mechanism was verified end-to-end
inside a NixOS VM test (`checks.x86_64-linux.ksm`, ~23 s). The probe
allocates anonymous memory, fills every 4 KiB page with a pattern, madvises
it `MERGEABLE`, and sleeps — exactly what QEMU does for guest RAM.

**Verified results:**

```
baseline:                          pages_shared=0     pages_sharing=0
two identical 256MiB probes:       pages_shared=512   pages_sharing=130560  (~510 MiB deduped)
+ third probe, DIFFERENT pattern:  pages_shared=768   pages_sharing=195840
ksmd CPU for scanning 768 MiB:     00:00:00 (negligible)
after probe exit + run=2:          unmerged to zero
```

What this proves:

1. **Cross-process dedup works** — two processes' identical 256 MiB regions
   collapsed; only ~510 MiB of physical RAM backs 512 MiB of "unique" pages
2. **`max_page_sharing` fanout** — `pages_shared` was **512, not 1**. KSM caps
   one physical page at `max_page_sharing` (default 256) mappings to bound
   reverse-map walk cost on COW faults, so 131072 identical pages spread over
   ~512 duplicate tree nodes. First test draft asserted `== 1` and failed on
   exactly this; the corrected range assertion (100-1000 nodes) passes.
3. **Negative control** — different content forms a *separate* dedup set
   (768 = 512 + 256); KSM merges only exact page matches
4. **Teardown** — exiting probes unmerge; `run=2` force-unmerges everything

### Tradeoffs

- **Win:** N processes with identical pages pay once. Born for KVM — 10 VMs
  running the same guest OS share most RAM; QEMU marks guest RAM mergeable
  **by default** (`memory-merge=on`; QEMU ≥8.0 uses `prctl(PR_SET_MEMORY_MERGE)`).
  Verified in the local qemu-11.0.3 binary (`"Mark memory as mergeable"`).
- **Cost:** ksmd CPU for scanning + COW-fault latency when pages diverge
- **Security:** timing side-channels — a hostile process can detect page
  co-residency via COW fault timing. Some distros disable KSM over this.

### Verdict for evo-x2

Go/node services never madvise mergeable, so host-level KSM only helps QEMU
VM-test runs. Not worth enabling.

---

## 5. Why SQLite does NOT use `MADV_HUGEPAGE`

Verified against the sqlite/sqlite mirror: zero `MADV_*` references.

1. **Portability policy** — SQLite is an embedded C library shipping in every
   OS and phone; `madvise` hints are Linux-only. Its VFS layer keeps
   OS-specific syscalls to a bare minimum.
2. **Access-pattern mismatch** — THP rewards large, dense, sequential working
   sets (JVM heaps, DPDK buffers, HPC arrays). SQLite's hot memory is a page
   cache of **4 KiB B-tree pages** — scattered tree-walk touches. 4 KiB DB
   pages on 4 KiB kernel pages is already natural alignment; TLB win marginal.
3. **Risk asymmetry** — 2 MiB granularity means a few hundred bytes touched
   pins 2 MiB RSS, and khugepaged collapse/compaction adds multi-ms stalls.
   For a DB embedded in phones and browsers, unpredictability is unacceptable.
4. **Its data isn't anonymous anyway** — DB pages flow through the OS page
   cache via `pread`/`pwrite`. `MADV_HUGEPAGE` only affects anonymous memory;
   even SQLite's optional `mmap_size` is file-backed (different THP mechanism).

---

## 6. Who actually uses `MADV_MERGEABLE`

| Consumer | How | Verified |
|---|---|---|
| **QEMU** — the reason KSM exists | Marks guest RAM mergeable (`memory-merge=on`, default on; ≥8.0 via `prctl(PR_SET_MEMORY_MERGE)`) | strings in local qemu-11.0.3 |
| **systemd ≥254** | `MemoryKSM=` unit directive wraps `prctl(PR_SET_MEMORY_MERGE)` — any service can opt in without code changes | directive in systemd 261 |
| **NixOS** | `hardware.ksm.enable` (+ `hardware.ksm.sleep`) — oneshot writes `/sys/kernel/mm/ksm/run` | `nixos/modules/hardware/ksm.nix` in our nixpkgs pin |
| **Basically nobody else** | Apps avoid it: marginal wins for diverse heaps, ksmd scan CPU, COW-fault cost, demonstrated co-residency side-channels (browsers explicitly stay away) | — |

---

## 7. Actionable Outcomes

1. **Do:** check BIOS `UMA Frame Buffer Size` (potential +16-24 GiB) — needs reboot
2. **Do:** zram 30% → 50% in `boot.nix` (`memoryPercent = 50`)
3. **Consider:** eval-time `MemoryMax` audit module
4. **Skip:** KSM (only VM tests would dedup), zram writeback (QLC NAND)
5. **Keep:** THP `madvise`, swappiness=150, current zstd(level=1)
6. **Added:** `tests/test-ksm.nix` — permanent regression test proving the KSM
   mechanism (incl. `max_page_sharing` semantics) inside a VM; wired into
   `checks.x86_64-linux.ksm`
