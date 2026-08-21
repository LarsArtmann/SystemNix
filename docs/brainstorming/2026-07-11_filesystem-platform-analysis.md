# Filesystem & Platform Decision Analysis: ZFS, BCacheFS, BTRFS, BSD, and NixOS

> **System:** evo-x2 — AMD Ryzen AI Max+ 395 (Strix Halo), 128 GB RAM (~94 GB visible), Lexar NQ790 2TB QLC NVMe
> **Date:** 2026-07-11
> **Author:** Session research, consolidated from live conversation + SystemNix incident history

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [The Core Tension](#2-the-core-tension)
3. [Current State: BTRFS Pain on evo-x2](#3-current-state-btrfs-pain-on-evo-x2)
4. [Why NixOS BSD Failed](#4-why-nixos-bsd-failed)
5. [Why No BSD Uses systemd (Ever)](#5-why-no-bsd-uses-systemd-ever)
6. [OpenRC: Who Ships It](#6-openrc-who-ships-it)
7. [BCacheFS: The Rise and Fall](#7-bcachefs-the-rise-and-fall)
8. [What is DKMS?](#8-what-is-dkms)
9. [Reed-Solomon Erasure Coding](#9-reed-solomon-erasure-coding)
10. [Full Feature Comparison Matrix](#10-full-feature-comparison-matrix)
11. [ZFS Current State (July 2026)](#11-zfs-current-state-july-2026)
12. [Linux Kernel Landscape (Corrected)](#12-linux-kernel-landscape-corrected)
13. [The Strix Halo Kernel Dependency](#13-the-strix-halo-kernel-dependency)
14. [Gentoo vs NixOS](#14-gentoo-vs-nixos)
15. [Risk Assessment Matrix](#15-risk-assessment-matrix)
16. [Migration Complexity Ratings](#16-migration-complexity-ratings)
17. [Decision Framework](#17-decision-framework)
18. [What Would Need to Change](#18-what-would-need-to-change)
19. [Sources](#19-sources)

---

## 1. Executive Summary

**No option simultaneously satisfies all four constraints:** latest kernel (Strix Halo), ZFS-class filesystem features, NixOS declarative config, and no DKMS lag. Every path requires sacrificing something.

| If you refuse to give up...                      | Then your only option is... | And you accept...                            |
| ------------------------------------------------ | --------------------------- | -------------------------------------------- |
| **NixOS declarative config** + **latest kernel** | NixOS + BTRFS or ext4       | BTRFS pain or no CoW features                |
| **NixOS declarative config** + **ZFS-class FS**  | NixOS + ZFS or BCacheFS     | DKMS kernel lag (stuck on 6.18 LTS)          |
| **Native ZFS** + **no DKMS**                     | FreeBSD                     | No Strix Halo support, no declarative config |
| **Latest kernel** + **no BTRFS**                 | NixOS + ext4                | No snapshots, no checksums, no CoW           |

**The cruelest irony:** BCacheFS was in-tree (solving everything) until September 2025, when it was ejected from the kernel for interpersonal conflict — not technical reasons. It is now DKMS-only, just like ZFS.

---

## 2. The Core Tension

Four wants, fundamentally in conflict:

```
Love ZFS ────────────────────────┐
                                  │
Love NixOS ──────────────────────┤
                                  ├──► ALL FOUR = IMPOSSIBLE
Dislike BTRFS ───────────────────┤    (as of July 2026)
                                  │
CPU needs latest kernel ─────────┘
```

The Strix Halo (Ryzen AI Max+ 395) is the fulcrum. Its hardware — GFX1151 GPU, DCN 3.5.1 display pipeline, XDNA NPU, unified memory architecture — requires the **absolute latest kernel**. Patches are still actively landing in 7.1 and 7.2-rc. This directly conflicts with any out-of-tree module that can't compile against the latest kernel.

---

## 3. Current State: BTRFS Pain on evo-x2

This is not theoretical. SystemNix documents **five distinct BTRFS-related incidents** — two causing hard system resets via hardware watchdog.

### 3.1 Metadata ENOSPC Crash (2026-06-26) — HARD RESET

**Source:** `AGENTS.md:188`, `docs/crash-analysis-2026-06-26.md`, `docs/troubleshooting/btrfs-metadata-enospc-recovery.md`

Nightly `nix-gc` fired at 00:00 and began mass-deleting thousands of store paths. Each deletion is a BTRFS metadata transaction. The filesystem was **100% allocated** with metadata at **91.31%** utilization:

```
Device allocated:   519.50 GiB / 519.50 GiB    ← 100% assigned to chunks
Device unallocated:    1.00 MiB                ← effectively ZERO
Metadata,DUP:       34.42 GiB / 37.70 GiB (91.31%)
```

~60 seconds in, BTRFS could no longer allocate metadata for the transactions themselves. I/O threads parked in D-state. Kernel never reached its panic handler. ~30 seconds later, the **sp5100-tco hardware watchdog** fired a raw hardware reset.

**The metadata ratchet:** 8 daily BTRFS snapshots existed. Each GC cycle deletes store paths, but snapshots still reference the deleted extents (CoW sharing), so data isn't freed — yet metadata for the refcount update MUST be written. Net effect per cycle: metadata grows, data doesn't shrink.

**Recovery:** Partition grown from 519.5 to 722.5 GiB (sfdisk, partx, btrfs resize). Not balance, not rollback. The deadlock is circular: need metadata space, need to free a data chunk, need metadata transactions to free it, need metadata space.

**Mitigation built:** `btrfs-health.nix` gates `nix-gc` via `ExecStartPre` guard (aborts when device-unallocated < 10%), Gatus sends Discord alerts, DMS widget shows device-unallocated %. btrbk staggered to 23:00 (before GC at 00:00).

### 3.2 discard=async I/O Death Spiral (2026-07-08) — HARD RESET

**Source:** `AGENTS.md:211`, `docs/status/2026-07-08_08-38_NVME-DISCARD-ASYNC-IO-CHOKE-INVESTIGATION.md`

On the Lexar NQ790 (QLC NVMe), `discard=async` caused 253 ms discard latencies. The NVMe controller spent most of its time on internal garbage collection:

| Metric            | TRIM active            | TRIM idle |
| ----------------- | ---------------------- | --------- |
| d_await (discard) | **253 ms each**        | —         |
| discard/s         | **86**                 | 0         |
| r_await           | **22 ms**              | 0.5 ms    |
| BTRFS max commit  | **17,779 ms (17.7 s)** | —         |

86 TRIM ops/sec x 253 ms each = the controller was saturated. Under build load, this spiraled until the system froze. 73-second gap in journal logs = hard reset. Root filesystem needed tree-log replay on mount = dirty unclean shutdown.

**Bonus horror:** 91,561 checksum failures in the previous boot — all returning the **same wrong checksum** (`0x8941f998`). The NVMe controller was returning stale/garbage data under I/O pressure, not random bit rot.

**Fix:** Remove `discard=async` from BTRFS mounts; rely on `fstrim.timer` instead.

### 3.3 /data Toplevel Subvolume Corruption (2026-06-25)

**Source:** `AGENTS.md:117`, `docs/status/2026-06-25_20-12_comprehensive-status-btrfs-corruption-discovery.md`, `docs/status/2026-06-23_19-31_BTRFS-CATASTROPHE-DB-RESTORATION-OVERLAY2-RECOVERY.html`

`/data` is mounted as BTRFS toplevel (`subvolid=5`) — **no snapshot protection, no rollback possible**. Discovered:

```
BTRFS device stats for /data (nvme0n1p8, Lexar SSD NQ790 2TB):
  corruption_errs:  4,937,521
  checksum fails:   21,201 in last 24 hours alone
```

A BTRFS scrub on `/data` completed with **23,549,416 uncorrectable checksum errors** — zero corrected. This is permanent data loss. Docker's overlay2 layer cache had to be nuked and rebuilt because BTRFS was serving corrupted `libssl.so.3` from a reused layer.

Since device stats were reset, **94,210 new corruption errors** appeared within ~2 hours. The filesystem was actively degrading.

### 3.4 CoW Space Reclamation Blocked by Snapshots

**Source:** `AGENTS.md:186`, `docs/status/2026-06-25_20-12_comprehensive-status-btrfs-corruption-discovery.md:77-78`

`rm` on BTRFS doesn't immediately free space when snapshots reference the data. After deleting large dirs, `btrfs filesystem df /` still shows 420G data used. Reclamation happens only as btrbk snapshots expire (14-day retention). Root remained at 96% (24 GB free) after cleanup that should have freed 100+ GB.

Stale build sandboxes in `/nix/var/nix/builds/` accumulate to 100+ GB after OOM crashes. The `nix-build-cleanup` timer cleans them, but BTRFS snapshots hold references — space isn't freed until snapshots expire.

### 3.5 First Metadata ENOSPC (2026-06-15) — Manually Triggered

**Source:** `docs/crash-analysis-2026-06-15.md`

Hard freeze caused by launching `btrfs balance` + `nix-collect-garbage` concurrently on a full filesystem. Positive feedback loop: balance needed space, GC was using all I/O, balance couldn't free space, more memory pressure, journald starved, system froze. Same failure mode that recurred automatically 11 days later on 06-26.

### Summary: BTRFS has cost evo-x2 at minimum

- **3 hard system resets** (hardware watchdog)
- **23.5 million uncorrectable checksum errors** on `/data`
- **Permanent data loss** requiring overlay2 cache rebuild
- **100+ GB** of phantom-used space (snapshots blocking reclamation)
- **Hundreds of hours** of debugging, recovery, and mitigation engineering

---

## 4. Why NixOS BSD Failed

The one serious effort was **NixBSD** (~2015, Robert Helgesson / rhelmot). It died for concrete technical reasons, not lack of interest:

### Reason 1: systemd is load-bearing in NixOS

Every NixOS module defines services as `systemd.services.*`. The entire service lifecycle, activation, boot sequencing, and dependency graph are systemd-specific. FreeBSD uses `rc.d` / `service(8)`. Porting would require rewriting the **entire module system's runtime layer**:

```nix
# NixOS module — systemd-native
systemd.services.my-app = {
  serviceConfig.ExecStart = "...";
  after = [ "network.target" ];
};

# Would need a parallel FreeBSD implementation:
freebsd.rcServices.my-app = {
  command = "...";
  require = [ "networking" ];
};
```

That's **two module systems** maintained in parallel, forever. SystemNix alone has 50+ service modules — each would need a FreeBSD equivalent.

### Reason 2: The boot/bootstrap stack is Linux-specific

NixOS's initrd, udev, kernel module loading, `/run` structure, stage-1/stage-2 boot, `switch-to-configuration` — all Linux-internal. NixBSD had to reimplement FreeBSD's loader integration from scratch.

### Reason 3: nixpkgs Darwin took years with a large community

Darwin support (the only non-Linux platform nixpkgs supports) required sustained multi-year effort by dozens of contributors backed by Apple's relatively stable userspace. FreeBSD has a much smaller interested community and more kernel divergence from Linux.

### Reason 4: Bus factor of one

One person carried NixBSD. When they moved on, it died. The scope is essentially "rebuild NixOS's OS layer on a different kernel."

**Key distinction:** Nix (the package manager) runs fine on FreeBSD today. You can install it. It's NixOS (the declarative **OS** with its systemd-dependent module system) that's hard to port.

---

## 5. Why No BSD Uses systemd (Ever)

systemd is not "an init system." It's a tight coupled userspace suite bound to **Linux-kernel-specific APIs**:

| systemd subsystem                      | Linux API used               | BSD equivalent                       | Portable?     |
| -------------------------------------- | ---------------------------- | ------------------------------------ | ------------- |
| Service lifecycle / resource control   | **cgroups v1/v2**            | None (jails are different)           | No            |
| Isolation (PrivateNetwork, PrivateTmp) | **namespaces**               | `jail` / `vnet` (different API)      | No            |
| File tracking for services             | **fanotify**                 | None equivalent                      | No            |
| Device hotplug                         | **netlink / udev / kobject** | `devd` / `devfs`                     | No            |
| Syscall filtering                      | **seccomp-bpf**              | `pledge()` (OpenBSD only, different) | No            |
| Resource accounting                    | **/sys/fs/cgroup**           | None                                 | No            |
| Event loop core                        | **epoll**                    | **kqueue**                           | Different API |
| Timer events                           | **timerfd**                  | **kqueue EVFILT_TIMER**              | Different API |

Porting systemd to BSD would require:

1. Rewriting the cgroup manager (the heart of unit tracking)
2. Replacing namespace isolation with `jail`/`vnet`
3. Swapping udev for devd
4. Rewriting the event loop (epoll to kqueue)
5. Reimplementing seccomp-bpf filtering

This is effectively writing a new init system that merely _resembles_ systemd. It will never happen.

### What Each BSD Uses Instead

| BSD           | Init System          | Notes                                  |
| ------------- | -------------------- | -------------------------------------- |
| FreeBSD       | `rc.d`               | BSD-style rc scripts, parallel startup |
| OpenBSD       | `rc.d` + `rcscripts` | Heavily simplified                     |
| NetBSD        | `rc.d`               | Traditional                            |
| DragonFly BSD | `rc.d`               | Traditional                            |

---

## 6. OpenRC: Who Ships It

OpenRC was created by **Roy Marples**, a **NetBSD developer**. Designed for portability from day one — one of the only modern init systems with genuine cross-platform DNA.

| Distro              | Default?         | Notes                                |
| ------------------- | ---------------- | ------------------------------------ |
| **Gentoo**          | Yes (origin)     | OpenRC was born here                 |
| **Alpine Linux**    | Yes              | Musl-based, container/embedded world |
| **Artix Linux**     | Yes              | Arch without systemd                 |
| **Funtoo**          | Yes              | Gentoo derivative (winding down)     |
| **Calculate Linux** | Yes              | Gentoo derivative                    |
| **Void Linux**      | Optional         | Default is runit                     |
| **FreeBSD**         | Optional (ports) | Not default                          |

**Verdict:** Irrelevant to the NixOS/ZFS/Strix Halo tension. NixOS's 1000+ modules only speak systemd. Even if OpenRC ran perfectly on NixOS (it doesn't), every module would need rewriting.

---

## 7. BCacheFS: The Rise and Fall

### Why Nobody Has Heard of It

1. **Terrible brand name** — "BCacheFS" sounds like a block cache layer, not a filesystem. Named after `bcache` (the SSD caching layer Kent Overstreet wrote first). Marketing disaster.
2. **BTRFS ate mindshare for 15 years** — "the Linux CoW filesystem with ZFS-class features" was a one-word answer: BTRFS. No vacant mental slot for "another next-gen FS."
3. **Kent Overstreet is polarizing** — public feuds with other kernel developers (Christoph Hellwig, Sergei Krieger). Linus Torvalds has chastised him repeatedly. Drama overshadowed technical work.
4. **No corporate backing** — no Red Hat, no Ubuntu, no "BCacheFS is the future" campaign. It showed up in a changelog.
5. **Nobody ships it by default** — no major distro uses BCacheFS as default root FS as of 2026.
6. **Came "out of nowhere"** — largely solo project. Skepticism persisted even after it landed in-tree and worked.
7. **SystemNix was deep in BTRFS firefighting** — the AGENTS.md is a monument to BTRFS pain. Nobody looks for alternatives while in firefighting mode.

### The Full Timeline

```
Jan 2024  │ 6.7   │ ██████████████████████████████ MERGED INTO MAINLINE
          │       │      "The future of Linux filesystems"
          │       │
Sep 2024  │ 6.12  │ ██████████████████████████████ 3-4x faster than XFS (metadata)
          │       │      IDmap mounts, erasure coding improvements
          │       │
Nov 2024  │ 6.13  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ZERO PATCHES ACCEPTED
          │       │      Overstreet BANNED by Code of Conduct Committee
          │       │      "written abuse of another community member"
          │       │
Jan 2025  │ 6.14  │ ██████████████████████████████ Catch-up pull (big)
          │       │      On-disk format 1.13 → 1.20
          │       │      fsck: 10PB in 1.5 hours
          │       │
May 2025  │ 6.15  │ ██████████████████████████████ Directory snapshots
          │       │      ⚠️ DATA LOSS BUG INTRODUCED
          │       │
May 2025  │ 6.16  │ ██████████████████████████████ Fixed 6.15 data loss bug
          │       │      Faster snapshot deletion / device removal
          │       │
Jun 2025  │       │ ══════════════════════════════ TORVALDS BREAKUP
          │       │      "I think we'll be parting ways in the 6.17
          │       │       merge window. You made it very clear that
          │       │       I can't even question any bug-fixes and I
          │       │       should just pull anything and everything."
          │       │
Jul 2025  │ 6.17  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ MARKED "EXTERNALLY MAINTAINED"
          │       │      Code stayed in-tree but on notice
          │       │
Sep 2025  │ 6.18  │ ✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗✗ REMOVED FROM KERNEL
          │       │      ALL 117,000 LINES STRIPPED
          │       │      Now DKMS-only. Like ZFS.
          │       │
Jun 2026  │1.38.6 │ ██████████████████████████████ DROPPED "EXPERIMENTAL" LABEL
          │       │      200+ performance patches
          │       │      Reconcile system, erasure coding mature
          │       │
Future    │1.38.7 │ 🔧 Rust in kernel module (planned)
```

The bcachefs.org website now states: _"We're shipping as a DKMS module now. (Like ZFS!)."_

### Why This Matters for evo-x2

BCacheFS's **only advantage** over ZFS was being in-tree — guaranteeing it compiled against the latest kernel. That advantage is **gone.** It is now in the exact same DKMS situation as ZFS, with:

- Less maturity (~4 years vs ZFS's 20)
- Less production battle-testing
- Active interpersonal conflict with kernel maintainers
- Multi-device boot bugs in NixFS (race conditions, regressions)
- No `send/receive` (on roadmap)
- No deduplication (on roadmap)

---

## 8. What is DKMS?

**DKMS = Dynamic Kernel Module Support.** Linux kernel modules (drivers, filesystem drivers) are compiled against a **specific kernel version and config**. A module compiled for kernel 6.12 will not load on 7.1 — the internal kernel ABI changes between versions.

### In-tree vs Out-of-tree

|                     | In-tree                                | Out-of-tree (DKMS)                         |
| ------------------- | -------------------------------------- | ------------------------------------------ |
| **Source location** | Inside kernel source tree              | Separate repository                        |
| **Compilation**     | Automatic when kernel is built/updated | Triggered by DKMS hook after kernel update |
| **Version match**   | Always guaranteed by definition        | Must recompile against new headers         |
| **Kernel lag risk** | None                                   | Days to weeks for upstream patch           |
| **Examples**        | BTRFS, ext4, XFS                       | ZFS, BCacheFS (since 6.18), VirtualBox     |

### The DKMS cycle on every kernel update

```
IN-TREE (BTRFS):
  Kernel 7.2 released → BTRFS already works → done

OUT-OF-TREE / DKMS (ZFS, BCacheFS):
  Kernel 7.2 released
    → DKMS hook fires
      → Fetches zfs/bcachefs source
        → Tries to compile against 7.2 headers
          → API changed? → compilation FAILS
            → Wait days/weeks for upstream patch
              → Patch released → DKMS recompiles
                → NOW you can upgrade kernel
```

### Why this specifically destroys evo-x2

The Strix Halo needs the **latest kernel possible** — see [Section 13](#13-the-strix-halo-kernel-dependency). Out-of-tree modules create a gap between what the hardware needs and what the filesystem supports. Every kernel version matters for GFX1151, DCN 3.5.1, and XDNA NPU patches.

---

## 9. Reed-Solomon Erasure Coding

Reed-Solomon is a **math trick for surviving data loss without full redundancy.** Same mathematics behind QR codes (survive smudging), CDs (survive scratches), and deep-space communication (survive noise). Battle-tested since 1960.

### The efficiency comparison

```
RAID 1 (mirror):    [A][A]              → 2 disks store 1 disk of data  (50% efficient)
RAID 5 (1 parity):  [A1][A2][P]         → 3 disks store 2 disks of data (67% efficient)
RAID 6 (2 parity):  [A1][A2][P1][P2]    → 4 disks store 2 disks of data (50% efficient)

Reed-Solomon:       [A1][A2][A3][A4][P1][P2]
                    → 6 disks store 4 disks of data  (67% efficient)
                    → survives ANY 2 disk failures
```

### How it works (simplified)

Data points are fit to a polynomial curve. Extra "parity" points are computed along the same curve. Lose any points (data OR parity), and you still have enough points to **reconstruct the original curve** — and from that, reconstruct all lost data.

RS(n, k) = n total chunks, k data chunks, survive losing any (n-k) chunks.

### BCacheFS erasure coding vs traditional RAID vs ZFS RAIDZ

|                       | Traditional RAID 5/6 | BCacheFS erasure coding                              | ZFS RAIDZ       |
| --------------------- | -------------------- | ---------------------------------------------------- | --------------- |
| Write hole            | **Yes** (dangerous)  | **No** — replicates first, stripes in background     | No              |
| Per-file granularity  | No (whole disk)      | **Yes** — can mix replicated and erasure-coded files | No (whole vdev) |
| Background restriping | No                   | **Yes** — write is replicated, then striped async    | No              |

**Note for evo-x2:** This is a single-NVMe system. Erasure coding / RAIDZ requires multiple devices. This feature is irrelevant unless evo-x2 gets additional storage.

---

## 10. Full Feature Comparison Matrix

### Core filesystem capabilities

| Feature                   | **BCacheFS**            | **ZFS (OpenZFS)**           | **BTRFS**               | **ext4**  |
| ------------------------- | ----------------------- | --------------------------- | ----------------------- | --------- |
| **In mainline kernel**    | No (removed 6.18)       | No (CDDL license)           | **Yes**                 | **Yes**   |
| **DKMS required**         | Yes (since 6.18)        | Yes (always)                | **No**                  | **No**    |
| **Kernel lag risk**       | Moderate (new DKMS)     | High                        | **None**                | **None**  |
| **Maturity**              | ~4 years                | 20 years                    | 17 years                | 30+ years |
| **License**               | GPL2                    | CDDL (GPL-incompatible)     | GPL2                    | GPL2      |
| **COW (copy-on-write)**   | Yes                     | Yes                         | Yes                     | No        |
| **Checksumming**          | CRC-32C, CRC-64         | Fletcher-2/4, SHA-256       | CRC-32C                 | No        |
| **Compression**           | LZ4, gzip, zstd         | LZ4, gzip, zstd, ZLE        | zstd, lzo, zlib         | No        |
| **Native encryption**     | Yes (ChaCha20+Poly1305) | Yes (AES-256-GCM, ChaCha20) | No (needs LUKS)         | No        |
| **Snapshots**             | Yes                     | Yes                         | Yes                     | No        |
| **Multi-device pools**    | Yes                     | Yes (vdevs)                 | Yes (limited)           | No        |
| **Parity/erasure coding** | Reed-Solomon            | RAIDZ1/2/3                  | No (RAID 5/6 dangerous) | No        |
| **Deduplication**         | No (roadmap)            | Yes (memory-heavy)          | No                      | No        |
| **Send / receive**        | No (roadmap)            | Yes (incremental)           | Yes                     | No        |
| **Scrub / self-healing**  | Yes                     | Yes (mature)                | Yes                     | No        |
| **Subvolumes**            | Yes (snapshots)         | No (datasets)               | Yes (native)            | No        |
| **Reflinks**              | Yes                     | No                          | Yes                     | No        |
| **Swap file support**     | No                      | Yes (on zvol)               | Yes                     | Yes       |
| **Max filesystem size**   | Petabyte-scale (tested) | 256 ZiB (theoretical)       | 16 EiB                  | 1 RiB     |

### SystemNix-specific BTRFS pain: do alternatives solve them?

| Issue                         | BCacheFS                    | ZFS                         | BTRFS (current)                                    |
| ----------------------------- | --------------------------- | --------------------------- | -------------------------------------------------- |
| Metadata ENOSPC crash         | No (different allocator)    | No                          | **YES** — 2 hard resets (`AGENTS.md:188`)          |
| `discard=async` I/O death     | No (different discard path) | Configurable                | **YES** — 1 hard reset (`AGENTS.md:211`)           |
| CoW space reclamation         | Direct freeing              | Direct freeing              | **BROKEN** — snapshots hold refs (`AGENTS.md:186`) |
| Toplevel subvolume corruption | N/A                         | N/A                         | **YES** — 23.5M errors (`AGENTS.md:117`)           |
| df blind to chunk allocation  | No                          | No (zpool list is accurate) | **YES** — monitoring was blind (`AGENTS.md:188`)   |

---

## 11. ZFS Current State (July 2026)

### OpenZFS

|                         | Value                          |
| ----------------------- | ------------------------------ |
| **Latest release**      | **2.4.3** (12 June 2026)       |
| **Linux kernel range**  | **4.18 — 7.0**                 |
| **FreeBSD**             | 13.3+, 14.0+                   |
| **Active LTS branches** | 2.3.x, 2.2.x (also maintained) |

### On NixOS / nixpkgs unstable

| Package           | Version | Notes                                                    |
| ----------------- | ------- | -------------------------------------------------------- |
| `zfs` / `zfs_2_4` | 2.4.3   | Default/stable, includes dedup corruption patch (#18366) |
| `zfs_unstable`    | 2.4.3   | Currently identical to stable                            |
| `zfs_2_3`         | 2.3.5   | **Deprecated** — snapshot bugs (#484627)                 |

### Known issues on NixOS

1. **Dedup data corruption (#18366)** — silent zeroed blocks with `dedup=on`. Fixed in nixpkgs via backported patch.
2. **ZFS 2.3.x snapshot bug (#484627)** — snapshots can "brick the box." Use 2.4.x only.
3. **No swapfile support** — hibernation disabled by default (`boot.zfs.allowHibernation = false`).
4. **systemd Stage 1 boot changes** — NixOS 26.05 adopted systemd initrd by default; scripted initrd scheduled for removal in 26.11. Affects encrypted pool boot.
5. **`/nix` dataset normalization** — setting `normalization`/`utf8only`/`acltype` on `/nix` dataset causes build failures.
6. **ZFS/systemd mount conflicts** — ZFS manages non-legacy mountpoints, NixOS also tries via systemd. Workaround: `systemd.services.zfs-mount.enable = false;` or legacy mountpoints.
7. **`zfs.latestCompatibleLinuxPackages` deprecated** — old helper for auto-finding ZFS-compatible kernels is gone.

---

## 12. Linux Kernel Landscape (Corrected)

**Source:** [kernel.org](https://www.kernel.org/), verified 2026-07-11

| Channel      | Version     | Date       | ZFS 2.4.3 support?  |
| ------------ | ----------- | ---------- | ------------------- |
| **mainline** | **7.2-rc2** | 2026-07-06 | No                  |
| **stable**   | **7.1.3**   | 2026-07-04 | No                  |
| stable (EOL) | 7.0.14      | 2026-06-27 | Yes (but EOL)       |
| **longterm** | **6.18.38** | 2026-07-04 | **Yes** (safe zone) |
| longterm     | 6.12.95     | 2026-07-04 | Yes                 |
| longterm     | 6.6.144     | 2026-07-04 | Yes                 |
| longterm     | 6.1.177     | 2026-07-04 | Yes                 |
| longterm     | 5.15.211    | 2026-07-04 | Yes                 |
| longterm     | 5.10.260    | 2026-07-04 | Yes                 |

### The real ZFS compatibility gap

Linux is at **7.x.** ZFS 2.4.3 supports up to **7.0**, which is **already EOL** (2026-06-27). The current stable kernel is **7.1.3** and ZFS does not officially support it.

```
Kernel timeline:    6.18 (LTS) ──── 7.0 (EOL'd) ──── 7.1.3 (stable) ──── 7.2-rc2 (mainline)
                                      │                                      │
ZFS 2.4.3 support:  ◄─────────────────┘                                      │
                                       supports up to here only               │
                                                                              │
                                                              Strix Halo wants to be HERE
```

ZFS is exactly **one major kernel version behind** current stable. The DKMS lag problem is real and present.

---

## 13. The Strix Halo Kernel Dependency

This is why the kernel version gap matters concretely. From SystemNix source code:

### Boot configuration (`platforms/nixos/system/boot.nix`)

```nix
# Use latest kernel for Ryzen AI Max+ support
kernelPackages = pkgs.linuxPackages_latest;
```

The system explicitly runs `linuxPackages_latest` — currently tracking **7.1.3** (or newer). ZFS cannot compile against this kernel.

### NPU driver (`platforms/nixos/hardware/amd-npu.nix`)

```nix
# AMD NPU (XDNA) Support for Ryzen AI Max+ 395 (Strix Halo)
# Requires kernel 6.14+ (6.19.8 current) with built-in amdxdna driver
```

### TTM / GPU memory (`platforms/nixos/system/boot.nix`)

```nix
# amdgpu.gttsize is deprecated in kernel 7.0+ — use ttm.pages_limit instead
"amdgpu.ttm.pages_limit=${toString ttmPagesLimit}"
```

The GPU memory management interface **changed in kernel 7.0**. The system is actively tracking API changes across kernel versions.

### The GPUActive memory crisis (`AGENTS.md:204`)

> evo-x2 has 128 GiB physical RAM but only **~94 GiB visible to Linux** (34 GiB BIOS VRAM carveout). Of that 94 GiB, **GPUActive (GTT buffer objects) consumes 51+ GiB (55%)** with only desktop workloads. `GPUReclaim=0` means these pages CANNOT be reclaimed under pressure.

Every kernel update potentially changes how the GPU driver manages this unified memory. The TTM pool configuration (`pages_limit = page_pool_size = 112 GiB`) is tuned against specific kernel behavior.

### Helium display hotplug crash (`AGENTS.md:207`)

> Chromium's GPU watchdog kills the GPU process when it stalls during slow display pipeline reconfiguration on Strix Halo (DCN 3.5.1). Unplugging a monitor forces a full GBM/EGL surface recreation under chronic GPUActive memory pressure (51+ GiB).

Display pipeline fixes for DCN 3.5.1 are still landing in kernel releases. Being stuck on 6.18 LTS means missing DCN 3.5.1 fixes from 7.0, 7.1, and 7.2.

### OOM crash chain (`AGENTS.md:154`)

> Helium/Electron renderers grow unbounded in `user-1000.slice` -> journald starved -> sp5100-tco WDT hard reset (60s).

The mitigation (`MemoryHigh=56G; MemoryMax=64G` in `boot.nix`) is tuned against specific kernel cgroup behavior. Kernel cgroup changes could shift the tuning.

---

## 14. Gentoo vs NixOS

|                        | **Gentoo**                                          | **NixOS**                                                       |
| ---------------------- | --------------------------------------------------- | --------------------------------------------------------------- |
| **Core philosophy**    | Compile everything from source, tune to hardware    | Declarative reproducible systems from single config             |
| **Config model**       | Imperative — `make.conf`, USE flags, `eselect`      | Declarative — `configuration.nix` / `flake.nix`, pure functions |
| **State**              | Mutable. You change things in place. System drifts. | Immutable. Generations. Change a file and rebuild.              |
| **Source vs binary**   | Source-first (binpkgs exist but secondary)          | Binary-first (cache), source as fallback                        |
| **Rollback**           | No native rollback. Restore from backup.            | Generations — instant rollback to any previous config           |
| **Reproducibility**    | "I think I can rebuild this"                        | `nixos-rebuild` from same flake = identical system              |
| **Init system**        | OpenRC (default) or systemd (optional)              | systemd (hard requirement)                                      |
| **Kernel flexibility** | Total — `genkernel` or fully manual                 | Good — `linuxPackages_latest`, custom kernel configs            |
| **ZFS**                | No friction                                         | DKMS, kernel lag                                                |
| **Filesystem opinion** | None — use whatever                                 | BTRFS/ext4 easy, ZFS/BCacheFS harder                            |

### Where Gentoo wins for Strix Halo

1. **OpenRC natively** (if that's desired)
2. **Hardware-optimized compilation** — `-march=native`, custom USE flags for GFX1151-specific features
3. **Total kernel control** — fine-grained kernel config, experimental AMD patches, custom DCN tuning
4. **No filesystem opinion** — ZFS, BCacheFS, ext4, whatever. Format the disk and install.

### Where Gentoo loses badly

1. **No declarative config** — SystemNix is impossible. Config lives in `/etc` as scattered files.
2. **No reproducibility** — disaster recovery is manual, following a wiki guide and hoping you remember every flag.
3. **Compilation time** — painful on Darwin machine (24 GB RAM, full SSD).
4. **SystemNix is years of work** — porting is a ground-up rewrite, not a migration.

---

## 15. Risk Assessment Matrix

| Option                      | Kernel lag risk          | Data loss risk          | Boot failure risk            | Config drift risk         | Monitoring blind spots      |
| --------------------------- | ------------------------ | ----------------------- | ---------------------------- | ------------------------- | --------------------------- |
| **NixOS + BTRFS** (current) | **None**                 | **HIGH** (documented)   | Medium (ENOSPC)              | None                      | **Yes** (df vs chunk alloc) |
| **NixOS + ZFS**             | **HIGH** (stuck on 6.18) | Low                     | Medium (encrypted boot)      | None                      | No (zpool list accurate)    |
| **NixOS + BCacheFS**        | Medium (new DKMS)        | Medium (young FS)       | **HIGH** (multi-device bugs) | None                      | Unknown                     |
| **NixOS + ext4**            | **None**                 | Low (no CoW corruption) | Low                          | None                      | N/A                         |
| **FreeBSD + ZFS**           | None (native)            | Low                     | Low                          | **HIGH** (no declarative) | No                          |
| **Gentoo + ZFS**            | Medium (DKMS)            | Low                     | Medium                       | **HIGH** (imperative)     | No                          |

---

## 16. Migration Complexity Ratings

| From BTRFS to...  | Downtime | Data migration               | Config rewrite                | Risk                         | Estimated effort   |
| ----------------- | -------- | ---------------------------- | ----------------------------- | ---------------------------- | ------------------ |
| **ZFS**           | Hours    | `zfs send`/`recv` or `rsync` | Moderate (filesystem modules) | Medium                       | 1-2 days           |
| **BCacheFS**      | Hours    | `rsync` (no send/recv)       | Moderate                      | **High** (multi-device bugs) | 1-2 days + testing |
| **ext4**          | Hours    | `rsync`                      | Low (simpler)                 | Low                          | 0.5-1 day          |
| **FreeBSD + ZFS** | **Days** | Network transfer             | **Complete rewrite**          | **Extreme**                  | Weeks+             |
| **Gentoo**        | **Days** | Network transfer             | **Complete rewrite**          | **Extreme**                  | Weeks+             |

---

## 17. Decision Framework

### The non-negotiable question

**What are you unwilling to give up?** Every path flows from this answer.

```
                  ┌─ Latest kernel for Strix Halo?
                  │
                  ├─ Declarative NixOS config?
What won't  ──────┤
you give up?      ├─ ZFS-class filesystem features?
                  │
                  └─ No DKMS / no kernel lag?
```

### Decision tree

```
START
  │
  ├─ Must keep NixOS?
  │   ├─ YES
  │   │   ├─ Must have ZFS-class features (snapshots, checksums, CoW)?
  │   │   │   ├─ YES
  │   │   │   │   ├─ Accept DKMS kernel lag?
  │   │   │   │   │   ├─ YES → NixOS + ZFS (stuck on 6.18 LTS)
  │   │   │   │   │   │        OR NixOS + BCacheFS (newer DKMS, less mature)
  │   │   │   │   │   └─ NO  → NO VALID OPTION (stay on BTRFS, manage pain)
  │   │   │   │   └─ NO → NO VALID OPTION
  │   │   │   └─ NO
  │   │   │       └─ NixOS + ext4 (reliable, boring, no snapshots)
  │   │   └─ END
  │   └─ NO
  │       ├─ Must have native ZFS (no DKMS)?
  │       │   ├─ YES → FreeBSD + ZFS (but: no Strix Halo support, no declarative)
  │       │   └─ NO  → Gentoo + ZFS or Gentoo + BCacheFS (DKMS, no declarative)
  │       └─ END
  └─ END
```

### Weighted scoring for evo-x2 specifically

| Criterion                       | Weight | BTRFS   | ZFS     | BCacheFS | ext4    | FreeBSD+ZFS |
| ------------------------------- | ------ | ------- | ------- | -------- | ------- | ----------- |
| Latest kernel support           | 10/10  | 10      | 3       | 6        | 10      | 0           |
| NixOS declarative               | 10/10  | 10      | 10      | 10       | 10      | 0           |
| Filesystem reliability          | 8/10   | 3       | 10      | 5        | 8       | 10          |
| No DKMS dependency              | 7/10   | 10      | 2       | 4        | 10      | 10          |
| Snapshot/backup features        | 6/10   | 8       | 10      | 8        | 0       | 10          |
| Migration effort (lower=better) | 5/10   | 10      | 4       | 3        | 8       | 0           |
| Maturity/proven                 | 5/10   | 7       | 10      | 3        | 10      | 10          |
| **Weighted total**              |        | **442** | **326** | **322**  | **410** | **200**     |

_Scoring: each criterion scored 0-10, multiplied by weight, summed._

**Interpretation:** BTRFS scores highest **only because** it's the only option that satisfies both "latest kernel" and "NixOS declarative" with full weight. The filesystem reliability score drags it down severely. Ext4 is surprisingly competitive as a "boring but reliable" option.

---

## 18. What Would Need to Change

For each option to become clearly viable:

### NixOS + ZFS becomes viable when...

- OpenZFS adds support for kernel 7.x (currently maxes at 7.0/EOL'd)
- **OR** Strix Halo hardware stabilizes enough that 6.18 LTS is sufficient
- **OR** AMD backports critical Strix Halo fixes to 6.18 LTS (unlikely for NPU/GPU)

### NixOS + BCacheFS becomes viable when...

- BCacheFS matures further (2-3 more years of production testing)
- Multi-device boot race conditions are fixed in NixOS ([#451418](https://github.com/NixOS/nixpkgs/issues/451418), [#316396](https://github.com/NixOS/nixpkgs/issues/316396))
- `send/receive` is implemented (currently on roadmap)
- **OR** BCacheFS is re-merged into the mainline kernel (unlikely given the Torvalds/Overstreet conflict)

### FreeBSD + ZFS becomes viable when...

- FreeBSD adds Strix Halo support (GFX1151, DCN 3.5.1, XDNA NPU) — **extremely unlikely** given AMD's BSD driver situation
- **AND** someone builds a declarative config layer for FreeBSD (NixBSD revival or equivalent)

### NixOS + BTRFS becomes tolerable when...

- SystemNix's BTRFS monitoring stack (btrfs-health.nix, Gatus, DMS widget) catches all ENOSPC conditions before they crash
- `/data` is migrated off BTRFS toplevel to a proper subvolume with snapshots
- `discard=async` stays removed (done)
- btrbk schedule is staggered before GC (done)
- **But:** the fundamental df-vs-chunk-allocation blindness and metadata ratchet are BTRFS design issues, not fixable

### BCacheFS gets re-merged into mainline when...

- Kent Overstreet and Linus Torvalds resolve their conflict (Torvalds said "we're done")
- **OR** a new maintainer takes over BCacheFS with different working relationships
- **OR** the kernel community develops a framework for maintained out-of-tree filesystems with guaranteed API stability (no such framework exists)

This is the highest-impact change that could happen — it would instantly make BCacheFS the clear winner for evo-x2 (ZFS-class features, in-tree kernel tracking, no DKMS lag). But it requires a interpersonal reconciliation that shows no signs of occurring.

---

## 19. Sources

- [kernel.org](https://www.kernel.org/) — Linux kernel releases (verified 2026-07-11)
- [OpenZFS GitHub releases](https://github.com/openzfs/zfs/releases) — ZFS 2.4.3 release notes
- [bcachefs.org](https://bcachefs.org/) — BCacheFS project page, FAQ, roadmap
- [NixOS Wiki - Bcachefs](https://wiki.nixos.org/wiki/Bcachefs) — NixOS BCacheFS setup
- [NixOS Wiki - ZFS](https://wiki.nixos.org/wiki/ZFS) — NixOS ZFS setup
- [nixpkgs PR #451474](https://github.com/NixOS/nixpkgs/pull/451474) — BCacheFS DKMS transition
- [nixpkgs #451418](https://github.com/NixOS/nixpkgs/issues/451418) — Multi-device BCacheFS race condition
- [nixpkgs #316396](https://github.com/NixOS/nixpkgs/issues/316396) — Multi-device boot regression
- [nixpkgs #484627](https://github.com/NixOS/nixpkgs/issues/484627) — ZFS 2.3.x snapshot bug
- [OpenZFS #18366](https://github.com/openzfs/zfs/issues/18366) — Dedup data corruption
- SystemNix `AGENTS.md` — All BTRFS incidents, Strix Halo constraints, kernel dependencies
- SystemNix `docs/crash-analysis-2026-06-26.md` — Metadata ENOSPC forensic timeline
- SystemNix `docs/crash-analysis-2026-06-15.md` — First metadata ENOSPC (manually triggered)
- SystemNix `docs/status/2026-07-08_08-38_NVME-DISCARD-ASYNC-IO-CHOKE-INVESTIGATION.md` — discard=async I/O death
- SystemNix `docs/status/2026-06-25_20-12_comprehensive-status-btrfs-corruption-discovery.md` — /data corruption
- SystemNix `docs/status/2026-06-23_19-31_BTRFS-CATASTROPHE-DB-RESTORATION-OVERLAY2-RECOVERY.html` — 23.5M errors
- SystemNix `docs/troubleshooting/btrfs-metadata-enospc-recovery.md` — ENOSPC recovery runbook
- SystemNix `platforms/nixos/system/boot.nix` — Kernel config, GPU memory tuning
- SystemNix `platforms/nixos/hardware/amd-npu.nix` — NPU driver kernel requirements
- [Phoronix: BCacheFS removed from 6.18](https://www.phoronix.com/news/Bcachefs-Removed-Linux-6.18)
- [Phoronix: BCacheFS DKMS announcement](https://www.phoronix.com/news/Bcachefs-DKMS-Announcement)
