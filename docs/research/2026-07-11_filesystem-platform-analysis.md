# Filesystem & Platform Analysis: ZFS, BCacheFS, BTRFS, BSD, and NixOS

**Date:** 2026-07-11
**Context:** Exploring filesystem and OS platform options for evo-x2 (Strix Halo / Ryzen AI Max+ 395)

---

## Motivation

The core tension driving this analysis:

1. **Love for ZFS** — checksums, snapshots, send/receive, proven reliability
2. **Love for NixOS** — declarative, reproducible, years of investment in SystemNix
3. **Dislike of BTRFS** — extensive documented pain (metadata ENOSPC, `discard=async` I/O death, CoW reclaim issues)
4. **ZFS on Linux is problematic** — out-of-tree DKMS, kernel version lag
5. **Considering BSD** — native ZFS, but fear of losing NixOS declarative power
6. **NixOS BSD is dead** — why?

---

## Why NixOS BSD Failed

The one serious effort was **NixBSD** (~2015, Robert Helgesson). It died for concrete technical reasons:

### 1. systemd is load-bearing in NixOS

Every NixOS module defines services as `systemd.services.*`. The entire service lifecycle, activation, boot sequencing, and dependency graph are systemd-specific. FreeBSD uses `rc.d` / `service(8)`. Porting would require rewriting the **entire module system's runtime layer** — not just porting, but forking it. Every module would need a parallel implementation:

```nix
# NixOS module - systemd-native
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

### 2. The boot/bootstrap stack is Linux-specific

NixOS's initrd, udev, kernel module loading, `/run` structure, stage-1/stage-2 boot, `switch-to-configuration` — all Linux-internal.

### 3. nixpkgs Darwin took years with a large community

Darwin support required sustained multi-year effort by dozens of contributors. FreeBSD has a much smaller interested community and more kernel divergence.

### 4. Bus factor

One person carried NixBSD. When they moved on, it died.

**Key insight:** Nix (the package manager) runs fine on FreeBSD today. It's NixOS (the declarative OS) that's hard to port.

---

## Why No BSD Uses systemd (Ever)

systemd is not "an init system." It's tightly coupled to **Linux-kernel-specific APIs**:

| systemd dependency | Linux-only? |
|---|---|
| cgroups v1/v2 (unit lifecycle, resource control) | Yes — no BSD equivalent |
| namespaces (PrivateNetwork, PrivateTmp, etc.) | Yes — BSD has `jail` but different API |
| fanotify (file tracking) | Yes |
| netlink / udev / kobject (device hotplug) | Yes — BSD uses devd/devfs |
| seccomp-bpf (SystemCallFilter) | Yes |
| /sys/fs/cgroup (resource accounting) | Yes |
| epoll (event loop core) | Yes — BSD has kqueue |

At minimum, porting systemd to BSD requires:
1. Rewriting the cgroup manager (the heart of unit tracking)
2. Replacing namespace isolation with `jail`/`vnet`
3. Swapping udev for devd
4. Rewriting the event loop (epoll -> kqueue)

This is effectively writing a new init system that resembles systemd. It will never happen.

### What Each BSD Uses Instead

| BSD | Init System |
|-----|-------------|
| FreeBSD | `rc.d` (BSD-style, parallel startup) |
| OpenBSD | `rc.d` + `rcscripts`, heavily simplified |
| NetBSD | `rc.d` |
| DragonFly BSD | `rc.d` |

---

## OpenRC: Who Ships It

OpenRC was created by **Roy Marples**, a **NetBSD developer**. Designed for portability — one of the only modern init systems with cross-platform DNA.

| Distro | Default? | Notes |
|--------|----------|-------|
| **Gentoo** | Yes (origin) | OpenRC was born here |
| **Alpine Linux** | Yes | Musl-based, container/embedded |
| **Artix Linux** | Yes | Arch without systemd |
| **Funtoo** | Yes | Gentoo derivative (winding down) |
| **Void Linux** | Optional | Default is runit |
| **FreeBSD** | Optional (ports) | Not default |

Irrelevant to the NixOS/ZFS/Strix Halo tension — NixOS's 1000+ modules only speak systemd.

---

## BCacheFS: The Hidden Option

### Why Nobody Has Heard of It

1. **Terrible brand name** — sounds like a block cache layer, not a filesystem
2. **BTRFS ate mindshare for 15 years** — no vacant mental slot for "another next-gen FS"
3. **Kent Overstreet is polarizing** — kernel mailing list drama overshadowed technical work
4. **No marketing push** — no Red Hat/Ubuntu/corporate backing
5. **Nobody ships it by default** — no major distro uses it as default root FS
6. **Came "out of nowhere"** — largely solo project, skepticism persisted even after merge

### The Bombshell: BCacheFS Was EJECTED from the Linux Kernel (6.18)

| Version | Event |
|---------|-------|
| 6.7 (Jan 2024) | BCacheFS merged into mainline kernel |
| 6.13 (Nov 2024) | Zero patches accepted — Overstreet **banned by CoC Committee** for abuse |
| 6.16 (May 2025) | Torvalds refused pull request, vowed to "part ways" |
| 6.17 (Jul 2025) | Marked **"externally maintained"** |
| **6.18 (Sep 2025)** | **All 117,000 lines removed from kernel. Now DKMS-only.** |
| June 2026 | Dropped "experimental" label. Now v1.38.6 |

The bcachefs.org website now states: *"We're shipping as a DKMS module now. (Like ZFS!)."*

**This destroys BCacheFS's key advantage over ZFS.** The in-tree guarantee that solved the kernel lag problem is gone. BCacheFS is now in the exact same out-of-tree DKMS situation as ZFS — with less maturity.

---

## Full Feature Comparison: BCacheFS vs ZFS vs BTRFS

| Feature | **BCacheFS** | **ZFS (OpenZFS)** | **BTRFS** |
|---------|-------------|-------------------|-----------|
| **In mainline kernel** | No (removed 6.18) | No (CDDL license) | Yes |
| **DKMS required** | Yes (since 6.18) | Yes (always) | No |
| **Kernel version lag risk** | Moderate (just became DKMS) | High (well-documented) | None |
| **Maturity** | ~4 years, non-experimental since Jun 2026 | 20 years | 17 years |
| **Production battle-tested** | Limited | Extensive (enterprise) | Moderate |
| **License** | GPL2 | CDDL (GPL-incompatible) | GPL2 |
| **COW (copy-on-write)** | Yes | Yes | Yes |
| **Checksumming** | CRC-32C, CRC-64 | Fletcher-2/4, SHA-256 | CRC-32C |
| **Compression** | LZ4, gzip, zstd | LZ4, gzip, zstd, ZLE | zstd, lzo, zlib |
| **Native encryption** | Yes (ChaCha20 + Poly1305) | Yes (AES-256-GCM, ChaCha20) | No (needs LUKS) |
| **Snapshots** | Yes | Yes | Yes |
| **Snapshots type** | Version-number based | Tree cloning | Subvolume-based |
| **Multi-device / pools** | Yes | Yes (vdevs) | Yes (limited) |
| **RAID-Z / parity** | Erasure coding (Reed-Solomon) | RAIDZ1/2/3 | No parity RAID |
| **RAID write hole** | No (replicates first, stripes later) | No (RAIDZ avoids it) | Yes (dangerous with RAID 5/6) |
| **Tiering / caching** | Yes (native, configurationless soon) | Yes (L2ARC, SLOG, special vdevs) | Limited |
| **Deduplication** | No (on roadmap) | Yes (memory-heavy) | No (never shipped reliably) |
| **Send / receive** | No (on roadmap) | Yes (incremental, efficient) | Yes |
| **Scrub / self-healing** | Yes (autoScrub in NixOS) | Yes (mature) | Yes |
| **Quotas** | Yes | Yes | Yes |
| **Subvolumes** | Yes (snapshots) | No (datasets instead) | Yes (native concept) |
| **Reflinks** | Yes | No | Yes |
| **fsck performance** | 10 PB in 1.5 hours (offline) | Not needed (always consistent) | Slow on large FS |
| **Online fsck** | In progress | N/A (transactional) | In progress |
| **Swap file support** | No | Yes (on zvol) | Yes |
| **Max filesystem size** | Petabyte-scale (tested) | 256 ZiB (theoretical) | 16 EiB |

### SystemNix-specific BTRFS pain points that alternatives solve

| Issue | BCacheFS | ZFS | BTRFS |
|-------|----------|-----|-------|
| Metadata ENOSPC crash | No (different allocator) | No | **Yes** (documented crash) |
| `discard=async` I/O death | No | Configurable | **Yes** (documented crash) |
| CoW space reclamation | Direct freeing | Direct freeing | **Broken** (snapshots hold refs) |
| Toplevel subvolume corruption | N/A | N/A | **Yes** (`/data` issue) |

---

## What is DKMS?

**DKMS = Dynamic Kernel Module Support.** Linux kernel modules are compiled against a specific kernel version/config. A module for 6.12 won't load on 6.14.

### In-tree vs Out-of-tree

**In-tree:** Module source lives in the kernel tree. Compiled automatically when kernel is built/updated. Always matches. Zero friction. (BTRFS, ext4, XFS)

**Out-of-tree / DKMS:** Module source lives outside the kernel. When you update your kernel, DKMS automatically recompiles the module against new kernel headers.

```
IN-TREE (BTRFS):
  Kernel 7.2 released -> BTRFS already works -> done

OUT-OF-TREE / DKMS (ZFS, BCacheFS):
  Kernel 7.2 released
    -> DKMS tries to compile zfs.ko
      -> API changed -> compilation fails
        -> wait days/weeks for patch
          -> patch released -> DKMS recompiles
            -> now you can upgrade kernel
```

### Why this hurts Strix Halo specifically

The Strix Halo (Ryzen AI Max+ 395) needs the **latest kernel possible** — GFX1151, DCN 3.5.1, NPU, power management patches are still actively landing. Every kernel version matters. Out-of-tree modules create a gap between what the hardware needs and what the filesystem supports.

---

## Reed-Solomon Erasure Coding

Reed-Solomon is a **math trick for surviving data loss without full redundancy.**

Simple mirroring stores everything 2x or 3x — 50% overhead for 2-way mirror. Reed-Solomon splits data into data chunks + parity chunks, surviving disk failures with much less overhead:

```
RAID 1 (mirror):    [A][A]              -> 2 disks store 1 disk of data (50% efficient)
RAID 5 (1 parity):  [A1][A2][P]         -> 3 disks store 2 disks of data (67% efficient)
RAID 6 (2 parity):  [A1][A2][P1][P2]    -> 4 disks store 2 disks of data (50% efficient)

Reed-Solomon:       [A1][A2][A3][A4][P1][P2]
                    -> 6 disks store 4 disks of data (67% efficient)
                    -> survives ANY 2 disk failures
```

The math: data points are fit to a polynomial curve. Extra "parity" points are computed along the same curve. Lose any points (data OR parity), and you still have enough to reconstruct the original curve — and from that, all lost data. RS(n, k) = n total chunks, k data chunks, survive losing any (n-k) chunks.

**Same math behind:** QR codes (survive smudging), CDs (survive scratches), deep-space communication (survive noise). Battle-tested since 1960.

### BCacheFS's approach vs traditional RAID

| | Traditional RAID 5/6 | BCacheFS erasure coding | ZFS RAIDZ |
|---|---|---|---|
| Write hole | Yes (dangerous) | **No** — replicates first, stripes in background | No |
| Per-file granularity | No (whole disk) | **Yes** — can mix replicated and erasure coded files | No (whole vdev) |

---

## OpenZFS Current State (July 2026)

| | Value |
|---|---|
| **Latest OpenZFS** | **2.4.3** (released 12 June 2026) |
| **Linux kernel range** | **4.18 -- 7.0** |
| **FreeBSD** | 13.3+, 14.0+ |

### On NixOS / nixpkgs unstable

| Package | Version | Notes |
|---------|---------|-------|
| `zfs` / `zfs_2_4` | 2.4.3 | Default/stable, includes dedup corruption patch (#18366) |
| `zfs_unstable` | 2.4.3 | Currently identical to stable |
| `zfs_2_3` | 2.3.5 | **Deprecated** — snapshot bugs (#484627) |

### Known issues on NixOS

1. **Dedup data corruption (#18366)** — silent zeroed blocks with `dedup=on`. Fixed in nixpkgs via patch.
2. **ZFS 2.3.x snapshot bug** — can "brick the box." Use 2.4.x.
3. **No swapfile support** — hibernation disabled by default.
4. **systemd Stage 1 boot changes** — NixOS 26.05 adopted systemd initrd; affects ZFS encrypted pool boot.
5. **`/nix` dataset normalization** — setting `normalization`/`utf8only`/`acltype` on `/nix` can cause build failures.

---

## Corrected Linux Kernel Landscape (from kernel.org, 2026-07-11)

| Channel | Version | Date |
|---------|---------|------|
| **mainline** | **7.2-rc2** | 2026-07-06 |
| **stable** | **7.1.3** | 2026-07-04 |
| stable (EOL) | 7.0.14 | 2026-06-27 |
| longterm | 6.18.38 | 2026-07-04 |
| longterm | 6.12.95 | 2026-07-04 |
| longterm | 6.6.144 | 2026-07-04 |
| longterm | 6.1.177 | 2026-07-04 |
| longterm | 5.15.211 | 2026-07-04 |
| longterm | 5.10.260 | 2026-07-04 |

**Linux is at 7.x.** This is critical for the ZFS compatibility analysis.

### The Real ZFS Compatibility Gap

| Kernel | ZFS 2.4.3 support? | Status |
|--------|-------------------|--------|
| 6.18 (LTS) | Yes (4.18-7.0) | Safe zone |
| 7.0 | Yes | **Already EOL** (2026-06-27) |
| **7.1.3 (current stable)** | **No** | One major version behind |
| **7.2-rc2 (mainline)** | **No** | Two versions behind |

ZFS supports up to 7.0, which is **already EOL.** The DKMS lag problem is real. ZFS is exactly one major kernel version behind current stable.

---

## Gentoo vs NixOS

| | **Gentoo** | **NixOS** |
|---|---|---|
| **Core philosophy** | Compile everything from source, tune to hardware | Declarative reproducible systems from single config |
| **Config model** | Imperative — `make.conf`, USE flags, `eselect` | Declarative — `configuration.nix`, pure functions |
| **State** | Mutable. System drifts. | Immutable. Generations. |
| **Source vs binary** | Source-first | Binary-first (cache), source fallback |
| **Rollback** | No native rollback | Generations — instant rollback |
| **Reproducibility** | "I think I can rebuild this" | Identical from same flake |
| **Init system** | OpenRC (default) or systemd (optional) | systemd (hard requirement) |

### Where Gentoo wins for Strix Halo

1. **OpenRC natively** (if that's desired)
2. **Hardware-optimized compilation** — `-march=native`, custom USE flags for GFX1151
3. **Total kernel flexibility** — fine-grained kernel config, experimental patches
4. **No filesystem opinion** — ZFS, BCacheFS, ext4, whatever

### Where Gentoo loses badly

1. **No declarative config** — SystemNix is impossible on Gentoo
2. **No reproducibility** — disaster recovery is manual
3. **Compilation time** — painful on Darwin machine (24GB RAM, full SSD)
4. **SystemNix is years of work** — porting is a ground-up rewrite

---

## NixOS BCacheFS Support Status

| Aspect | Status |
|--------|--------|
| **Root filesystem** | Supported (initrd, encrypted root, Clevis/TPM) |
| **Module** | `nixos/modules/tasks/filesystems/bcachefs.nix` (~400 lines) |
| **autoScrub** | `services.bcachefs.autoScrub` (kernel 6.14+) |
| **Encrypted boot** | Interactive passphrase + Clevis |
| **Multi-device boot** | **Broken** — race conditions ([#451418](https://github.com/NixOS/nixpkgs/issues/451418), [#316396](https://github.com/NixOS/nixpkgs/issues/316396)) |
| **Default installer** | No — need custom ISO |
| **Out-of-tree module** | Wired up via [PR #451474](https://github.com/NixOS/nixpkgs/pull/451474) |
| **BCacheFS project rating** | Lists NixOS as "first-tier" support |

---

## Final Options Matrix

| Option | Kernel tracking | Declarative | ZFS-class FS | Trade-off |
|--------|----------------|-------------|--------------|-----------|
| **NixOS + BTRFS** (current) | In-tree (latest) | Yes | Yes | All documented BTRFS pain |
| **NixOS + ZFS** | DKMS (max 7.0, EOL'd) | Yes | Yes | Strix Halo kernel compromise; stuck on 6.18 LTS |
| **NixOS + BCacheFS** | DKMS (min 6.16) | Yes | Yes | DKMS lag + youth + multi-device bugs |
| **NixOS + ext4** | In-tree (latest) | Yes | No | Reliable but no snapshots/checksums |
| **Gentoo + ZFS** | DKMS | No | Yes | Lose all SystemNix declarative work |
| **BSD + ZFS** | Native | No | Yes | No Strix Halo support, no declarative config |
| **Gentoo + OpenRC** | N/A | No | Variable | Lose everything SystemNix represents |

### The cruel reality

- **In-tree filesystems** (BTRFS, ext4) track the latest kernel perfectly but either have BTRFS pain or lack ZFS-class features
- **Out-of-tree filesystems** (ZFS, BCacheFS) have ZFS-class features but can't track the latest kernel
- **BSD** has native ZFS but no Strix Halo support and no declarative config
- **Nobody has successfully combined native ZFS with full declarative OS config**

The current BTRFS setup — for all its documented pain — is the only option that gives **both** the latest kernel **and** CoW/checksum/snapshots **and** NixOS declarative config.

---

## Conclusion

The fundamental conflict: **Strix Halo demands the latest Linux kernel; ZFS and BCacheFS (both DKMS-only now) demand kernel stability.** These are opposed.

The non-negotiable question: **What are you unwilling to give up?**

- If **declarative config** is non-negotiable (SystemNix investment suggests yes) -> stay on NixOS
- If **latest kernel for Strix Halo** is non-negotiable -> in-tree filesystems only (BTRFS or ext4)
- If **ZFS-class reliability** is non-negotiable -> accept DKMS kernel lag (ZFS on 6.18 LTS, or BCacheFS)
- If **native ZFS** is non-negotiable -> BSD, but lose Strix Halo support and declarative config

**No option satisfies all constraints simultaneously.** The choice is which constraint to relax.
