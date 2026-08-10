# 2026-08-10 05:49 — ZFS-on-7.1 Investigation & VM Strategy Status

---

## Executive Summary

Connected a 2×16TB external HDD enclosure (ZFS-formatted) via USB to evo-x2.
The host runs **kernel 7.1** which nixpkgs claims is incompatible with ZFS.
Investigated 4 approaches to access the ZFS pool. Built declarative NixOS configs
for two VM approaches (NixOS + FreeBSD) with USB passthrough. Both are untested.

**Bottom line:** The "kernel incompatibility" may be overstated — ZFS 2.4.3
officially supports up to **kernel 7.0**, only ONE minor version behind our 7.1.
The simplest fix (native ZFS on host) was NOT attempted.

---

## a) FULLY DONE

1. **Drive detection & identification**
   - JMicron JMS567 USB 3.0 bridge (152d:0567), bus 8 port 1
   - Two LUNs: `/dev/sda` and `/dev/sdb`, both 16.0 TB (14.6 TiB), 4096-byte physical blocks
   - Partition layout: `sda1 + sda9` / `sdb1 + sdb9` — classic ZFS whole-disk vdev with GPT
   - dmesg shows: "Very big device. Trying to use READ CAPACITY(16)." — READ CAPACITY(16) needed for >2TB
   - Drive cache: "write through" (no write cache — USB bridge limitation)

2. **Host kernel/ZFS compatibility analysis**
   - Host kernel: 7.1.6 (runtime) / 7.1.7 (NixOS config target)
   - nixpkgs ZFS version: 2.4.3
   - nixpkgs `zfs.latestCompatibleLinuxPackages` → kernel **6.18.43** (STALE/overly conservative)
   - **Actual OpenZFS 2.4.3 support: kernels 4.18 – 7.0** (verified via GitHub releases)
   - ZFS 2.4.3 source contains explicit Linux 7.1 forward-compat patches ("access dentry d_alias directly")
   - Gap is **ONE minor version** (7.0 → 7.1), not the huge gap nixpkgs implies
   - `zfs.latestCompatibleLinuxPackages` is **DEPRECATED** per eval warning — nixpkgs is changing this API
   - ZFS is NOT broken/unsupported in nixpkgs: `meta.broken = false`, `meta.unsupported = false`

3. **Architecture research (containers, BSDs, VMs)**
   - **Containers (OCI/Docker/Podman):** Cannot help — containers share host kernel, fundamentally. Docker Desktop on macOS/Windows works by hiding a Linux VM underneath. A "container with its own kernel" IS a VM.
   - **OpenBSD:** Confirmed NO ZFS support — CDDL license incompatible with OpenBSD's ISC/BSD-only policy. Verified via Wikipedia + OpenBSD FAQ + mount(8) man page.
   - **FreeBSD:** First-class ZFS support since 7.0 (2008). The gold standard after Solaris.
   - **NetBSD:** Has OpenZFS port (read/write).
   - **DragonFly BSD:** No ZFS — uses HAMMER2 instead.
   - **systemd-nspawn, LXC/LXD:** Share host kernel — same limitation as containers.
   - **Firecracker:** Real microVM (KVM-based, own kernel, ~125ms boot) — could work but overkill.

4. **VM configs written and wired into flake**
   - `systems/zfs-vm.nix` — NixOS VM with ZFS on kernel 6.18, USB passthrough, SSH forwarding
   - `pkgs/freebsd-zfs-vm.nix` — FreeBSD 14.2 cloud image QEMU launcher with USB passthrough
   - Both wired into `flake.nix` (nixosConfigurations.zfs-vm + packages.freebsd-zfs-vm)
   - NixOS VM **evaluates successfully** — kernel resolves to 6.18.43
   - FreeBSD VM package **build is in progress** (background)

---

## b) PARTIALLY DONE

1. **NixOS VM (kernel 6.18 + ZFS)** — `systems/zfs-vm.nix`
   - Config written, git-tracked, flake-wired, **eval passes** (kernel = 6.18.43)
   - NOT built (`nix build` not attempted — would compile ZFS kernel module, ~5-10 min)
   - NOT run — VM boot, USB passthrough, ZFS import all UNTESTED
   - **USB passthrough unverified** — QEMU `-device usb-host` config is written but:
     - Host kernel may have already grabbed the device
     - Device may need detaching from host drivers first
     - IOMMU/vfio not configured (using USB passthrough, not PCIe — should be OK)
   - **No data access tested** — no `zpool import`, no dataset listing, no file read

2. **FreeBSD VM** — `pkgs/freebsd-zfs-vm.nix`
   - Script written, git-tracked, flake-wired
   - Build in progress (background, may still be running)
   - FreeBSD image URL NOT verified (assumed standard mirror path)
   - NOT run — same untested concerns as above
   - FreeBSD cloud image may need initial setup (root password, SSH key) before SSH access works
   - ZFS pool import on FreeBSD NOT tested

3. **Flake integration**
   - Files created, git-added, flake.nix edited
   - `nix flake check --no-build` NOT run — may surface issues
   - Formatting (alejandra) NOT run

---

## c) NOT STARTED

1. **Native ZFS on host kernel 7.1** — the simplest option, never attempted
   - Would require: `boot.zfs.enabled = true`, `boot.supportedFilesystems = [ "zfs" ]`
   - ZFS 2.4.3 has 7.1 patches in source — may compile and load fine
   - If it works, entire VM strategy is unnecessary
2. **Reformatting drives to BTRFS** — mentioned as option, never pursued
3. **Actual ZFS pool import on any platform** — no pool has been imported anywhere
4. **ZFS pool inspection** — `zpool status`, `zfs list`, pool name, dataset layout — all unknown
5. **Data assessment** — what's actually ON the ZFS pool (photos? backups? VMs?) — unknown
6. **Backup strategy implementation** — no backup configured regardless of access method
7. **Monitoring** — no Gatus check, no SMART monitoring for the external drives
8. **`nix fmt`** on the new files

---

## d) TOTALLY FUCKED UP

1. **Blindly trusted stale nixpkgs data** — I said "ZFS max kernel: 6.18" based solely on `nix eval nixpkgs#zfs.latestCompatibleLinuxPackages`. This was WRONG. OpenZFS 2.4.3 officially supports up to 7.0. I didn't verify against upstream until the user pushed me. I presented a conservative nixpkgs attribute as ground truth.

2. **Didn't explain container architecture proactively** — When the user suggested containers, I said "No, fundamental limitation" without explaining WHY. The user had to ask "How do people run Linux Containers on MacOS?" before I explained the Docker Desktop VM architecture. A good engineer explains the WHY, not just the WHAT.

3. **Made the OpenBSD claim without sources** — I said "OpenBSD has no ZFS support. At all." with zero citations. The user rightly called BS. It turned out correct (CDDL license), but I should have verified BEFORE claiming.

4. **Forgot `git add` before `nix build`** — Classic Nix flake mistake. Created files, tried to build, got "not tracked by Git" error. Wasted a round trip.

5. **Left background builds running unmanaged** — Started two background jobs, didn't properly track or clean them up before switching context.

6. **Wrote "kernel 7.0" in prose but the VM actually boots 6.18** — Inconsistent. `zfs.latestCompatibleLinuxPackages` resolves to 6.18.43, not 7.0. The VM config uses this deprecated attribute, so it boots 6.18 — a MUCH older kernel than the host's 7.1. This is a bigger downgrade than communicated.

7. **Didn't consider host USB device conflicts** — The host kernel already enumerated the JMicron bridge and created `/dev/sda` + `/dev/sdb`. QEMU USB passthrough needs exclusive access. May need `echo > /sys/bus/usb/devices/8-1/driver/unbind` or similar before VM launch. Not handled.

---

## e) WHAT WE SHOULD IMPROVE

1. **Always verify external claims against primary sources before stating them as fact** — I trusted a nixpkgs convenience attribute over OpenZFS's own release notes. The `latestCompatibleLinuxPackages` is a conservative fallback, not authoritative truth.

2. **Try the simple thing first** — Native ZFS on 7.1 was never attempted. It's a 3-line config change + one rebuild. If it compiles, ALL the VM complexity is unnecessary. We jumped to VMs before trying the direct path.

3. **Explain the "why" when rejecting an idea** — "Containers don't work" is useless. "Containers share the host kernel via syscalls; Docker Desktop hides a VM; here's the architecture diagram" is useful.

4. **Manage background processes properly** — Start, monitor, report results, clean up. Don't leave jobs dangling.

5. **Test USB passthrough before writing elaborate configs** — A quick `qemu-system-x86_64 -device usb-host,...` smoke test would reveal whether passthrough even works before investing in full VM configs.

6. **Verify FreeBSD image availability** — Hardcode a verified URL or use `fetchurl` with a hash, not a runtime `curl` download.

7. **The `latestCompatibleLinuxPackages` deprecation is a ticking bomb** — nixpkgs warns it "is now pointing at the default kernel." If nixpkgs changes this, the VM config may silently break. Pin explicitly: `pkgs.linuxPackages_6_18` or similar.

8. **Consider that `write through` cache on the USB bridge means no write caching** — ZFS on USB with write-through cache is slow and risky for writes. Reads are fine for data recovery.

9. **Don't know what's on the pool yet** — Before investing in access infrastructure, find out if the data is even worth recovering. Could be empty, could be 30TB of irreplaceable data.

---

## f) NEXT STEPS (up to 50)

### Immediate — Access Strategy (highest impact first)

1. **Try native ZFS on host kernel 7.1** — `boot.zfs.enabled = true` + rebuild. If it compiles, done.
2. **If native fails, check the exact error** — `journalctl -k | grep zfs` or `modprobe zfs`
3. **If native ZFS loads, `zpool import` directly on host** — no VM needed
4. **Inspect pool** — `zpool status`, `zfs list -r <pool>` to see datasets
5. **Assess data** — `du -sh /<pool>/*`, identify what's worth keeping
6. **Run `nix flake check --no-build`** on current changes
7. **Run `nix fmt`** on new files
8. **Kill leftover background builds** if still running

### NixOS VM Path (if native fails)

9. **Fix `latestCompatibleLinuxPackages` deprecation** — pin to `pkgs.linuxPackages_6_18` explicitly
10. **Build the VM** — `nix build .#nixosConfigurations.zfs-vm.config.system.build.vm`
11. **Handle host USB device conflict** — unbind from host or use vfio
12. **Boot the VM** — `sudo ./result/bin/run-nixos-vm`
13. **Verify USB device visible inside VM** — `lsusb` or `ls /dev/sd*`
14. **Import pool in VM** — `zpool import`
15. **Test SSH forwarding** — `ssh root@localhost -p 2222`
16. **Expose data to host** — NFS export from VM, or virtiofs/9p share

### FreeBSD VM Path (comparison)

17. **Verify FreeBSD 14.2 image URL is valid**
18. **Build the FreeBSD launcher** — confirm `nix build .#freebsd-zfs-vm` succeeds
19. **Boot FreeBSD VM** — test image downloads and boots
20. **Configure FreeBSD SSH access** — cloud-init or manual console setup
21. **Verify USB passthrough in FreeBSD** — `camcontrol devlist`
22. **Import pool in FreeBSD** — `zpool import`
23. **Compare FreeBSD vs NixOS VM** — boot time, import reliability, performance, ergonomics

### Comparison & Decision

24. **Document boot times** for both VMs
25. **Document ZFS import reliability** for both
26. **Benchmark read performance** through the VM vs native
27. **Assess USB bridge overhead** — UAS vs USB Mass Storage, latency impact
28. **Evaluate long-term viability** — is VM-for-ZFS sustainable, or should we reformat?
29. **Consider BTRFS reformat** — if data is recoverable and non-critical format type
30. **Consider keeping ZFS and accessing via NFS permanently** — VM always-on

### Data & Backup Strategy

31. **Catalog all datasets on the pool**
32. **Identify critical vs disposable data**
33. **Copy critical data to host NVMe** — `/data` partition has 1TB
34. **Design backup workflow** — if pool stays ZFS, how to back up to BTRFS host
35. **Set up rsync/syncoid from ZFS to BTRFS** for important datasets
36. **Consider BorgBackup to the external drives** (if reformatted to BTRFS)

### Monitoring & Safety

37. **SMART monitoring for external drives** — `smartctl -a /dev/sda` and `/dev/sdb`
38. **Check drive health** — reallocated sectors, pending sectors, temperature
39. **Run `badblocks` if drive history is unknown** — especially after power surge
40. **Gatus health check** — if VM becomes permanent, monitor it
41. **Temperature monitoring** — 16TB HDDs in USB enclosures run hot

### Code Quality & Cleanup

42. **Run `nix fmt`** on `systems/zfs-vm.nix` and `pkgs/freebsd-zfs-vm.nix`
43. **Add assertions to zfs-vm.nix** — verify kernel is ZFS-compatible at eval time
44. **Use `fetchurl` with hash for FreeBSD image** instead of runtime `curl`
45. **Clean up flake.nix** — ensure the VM configs follow existing patterns (import style, etc.)
46. **Add devShell for ZFS** — `nix develop .#zfs` with zfs tools
47. **Document the VM approach in AGENTS.md** if it becomes permanent

### Architecture Decisions

48. **Decide: Native ZFS vs VM vs BTRFS reformat** — pick ONE and commit
49. **If VM: decide always-on vs on-demand** — backup target needs reliability
50. **Plan for ZFS 7.1 native support timeline** — when OpenZFS adds 7.1, drop the VM

---

## g) QUESTIONS (cannot figure out myself)

### Q1: What data is on the ZFS pool?

I have NO IDEA what's on those drives. Could be irreplaceable family photos, could be
an empty pool from a test setup, could be 20TB of Docker images. This determines whether
we need careful recovery (VM approach) or can just reformat to BTRFS (simplest path).
**Where did these drives come from? What was their purpose?**

### Q2: Should I attempt native ZFS on kernel 7.1 before investing more in VMs?

The VMs are untested and may have USB passthrough issues. Native ZFS is a 3-line config
change. ZFS 2.4.3 has 7.1 patches in the source tree. It might just work. If it does,
this entire VM effort is wasted. **Do you want me to try the direct approach first?**

### Q3: Is this a permanent setup or one-time data recovery?

If you just need to read data off the pool once, a temporary VM is fine — boot, import,
copy data, shut down. If this becomes a permanent 32TB backup target, we need reliability:
always-on VM, monitoring, automated backups, drive health checks. **What's the long-term plan for these drives?**

---

## Files Changed This Session

| File | Status | Purpose |
|------|--------|---------|
| `systems/zfs-vm.nix` | Created, git-staged | NixOS VM config (kernel 6.18 + ZFS + USB passthrough) |
| `pkgs/freebsd-zfs-vm.nix` | Created, git-staged | FreeBSD 14.2 QEMU launcher script with USB passthrough |
| `flake.nix` | Modified | Wired `nixosConfigurations.zfs-vm` + `packages.freebsd-zfs-vm` |

---

## Resolution Status (2026-08-10)

**PARTIALLY DONE — DO NOT ARCHIVE.** Analysis work is complete. VM configs are written but UNTESTED. Key open items:
- ~~Drive detection & identification~~ done (2x16TB, JMicron JMS567 USB bridge)
- ~~Host kernel/ZFS compatibility analysis~~ done (ZFS 2.4.3 supports 7.0, host is 7.1 — ONE minor behind)
- ~~Architecture research~~ done (containers share kernel, FreeBSD has first-class ZFS, OpenBSD has none)
- ~~VM configs written and wired into flake~~ done (NixOS VM evaluates, FreeBSD VM package built)
- **NOT DONE:** Native ZFS on host kernel 7.1 (simplest option, never attempted) — in TODO_LIST Priority 8
- **NOT DONE:** ZFS pool import, data assessment, backup strategy — in TODO_LIST Priority 8
- **NOT DONE:** SMART monitoring for external drives — in TODO_LIST Priority 8
- **NOT DONE:** `nix flake check --no-build`, `nix fmt` on new files

> **UPDATE 2026-08-10 06:44:** VFIO PCIe passthrough SUCCEEDED. See `docs/status/2026-08-10_06-44_zfs-vfio-passthrough-success.md`. NixOS VM (kernel 6.18.43) imported `datapool` mirror. Pool is 99.86% empty (21GB of 14.5TB, mostly disposable Docker images). Native ZFS on 7.1 still untested.
