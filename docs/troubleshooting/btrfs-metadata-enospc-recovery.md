# Recovery: BTRFS Metadata ENOSPC (Activation Hang / WDT Reset)

> **Symptom:** System hangs at "Starting NixOS Activation" after a hard reset.
> Rollback to previous generation doesn't help. No TTY available. `df` showed
> free space before the crash, so it doesn't look like a disk-full issue.
>
> **Root cause:** BTRFS chunk allocation deadlock. Device is 100% allocated,
> metadata pool is >90% full, and device-unallocated is ~0. BTRFS cannot create
> new metadata chunks → every write (including activation's symlink storm) blocks.

## Quick Diagnosis

If the system won't boot normally, boot from USB installer (needs `nomodeset` for
Strix Halo GPU), mount root, and check:

```bash
mount -t btrfs -o subvol=@,compress=zstd:3,ssd /dev/nvme0n1p6 /mnt
btrfs filesystem usage /mnt
```

**Metadata ENOSPC confirmed if ALL true:**
- `Device unallocated:` < 1 GiB (critical)
- `Metadata,DUP:` utilization > 85%
- `df /mnt` still shows GiB of free space (this is the trap — `df` reports
  Data-pool free space, not chunk-level allocation)

## Why df Lies

`df` uses the `statfs` syscall, which for BTRFS returns estimated free space
**inside existing Data chunks**. It cannot see:
- Device-unallocated (the metric that hits 0 and kills the system)
- Metadata utilization (the metric that hits 90%+)
- Chunk allocation state (the metric that hits 100%)

The entire monitoring stack (`df`, node_exporter filesystem collector, the DMS
disk widget) was green while device-unallocated was at 0.01%.

## Recovery: Grow the Partition

The ONLY fix is adding **device-unallocated** space. You cannot reclaim your way
out — BTRFS needs raw space to allocate new metadata chunks. The circular
deadlock is: need metadata space → need to free a data chunk → need metadata
transactions to free it → need metadata space.

### Step 0: Boot USB Installer

```
# In GRUB, press 'e' and add nomodeset to the linux line (required for Strix Halo)
nomodeset
```

### Step 1: Mount and Enter the System

```bash
mount -t btrfs -o subvol=@,compress=zstd:3,ssd /dev/nvme0n1p6 /mnt
nixos-enter --root /mnt
```

### Step 2: Check for Free Space After the Partition

```bash
sfdisk -F /dev/nvme0n1
# Look for unpartitioned space immediately after p6
```

### Step 3: Grow the Partition (Three Layers)

**3a. GPT (sfdisk):**

```bash
sfdisk -d /dev/nvme0n1 > /tmp/nvme-parts.bak
cp /tmp/nvme-parts.bak /tmp/nvme-parts.new
# Edit /tmp/nvme-parts.new: change ONLY p6's size to fill the free gap
# new_size = (next_partition_start - p6_start) in sectors
sfdisk --no-reread /dev/nvme0n1 < /tmp/nvme-parts.new
```

**3b. Kernel (partx — sfdisk re-read fails on mounted partitions):**

```bash
partx -u --nr 6:6 /dev/nvme0n1
cat /sys/block/nvme0n1/nvme0n1p6/size  # verify kernel sees new size
```

**3c. BTRFS:**

```bash
btrfs filesystem resize max /
btrfs filesystem usage /  # Device unallocated should now show tens of GiB
```

### Step 4: Reboot

```bash
exit           # exit nixos-enter
umount /mnt
reboot
```

Activation now succeeds because BTRFS has device-unallocated space for new
metadata chunks.

## What NOT to Do

| Command | Why It Fails |
|---------|-------------|
| `btrfs balance start /` | Needs device-unallocated to relocate blocks. On a full device, it can't progress and may wedge the system. |
| `nix-collect-garbage` | Each deletion is a metadata transaction. On a metadata-starved FS, GC makes it worse. |
| `rm -rf` large trees | Same — metadata storm. Every file removal is a metadata write. |
| Rollback to previous gen | The problem is the filesystem, not the generation. All generations require the same metadata operations to activate. |
| `btrfs balance start -musage=50` | Safer than full balance but still needs unallocated space. Only AFTER growing the partition. |

## Why Rollback Doesn't Fix It

Rolling back changes the generation (which system closure to activate), but the
filesystem is the same. The activation script for ANY generation is equally
metadata-intensive (rebuilds the symlink tree, recreates /etc symlinks, touches
state directories). The problem is filesystem-level ENOSPC, not a bad generation.

## Why Standard Recovery Methods Fail

| Method | Result | Why |
|--------|--------|-----|
| Ctrl+Alt+F2/F3/F4 | No TTY | systemd never reaches `getty.target` — stuck at activation |
| `systemd.unit=emergency.target` | Still hangs | NixOS activation runs before any target |
| `init=/bin/sh` | "root account locked" | NixOS `sulogin` intercept for passwordless root |
| Wait for activation | Hangs 10+ min | Activation is a metadata storm on a deadlocked FS |

The ONLY escape is an external boot medium (USB installer) that bypasses the
frozen filesystem entirely.

## Prevention

This system now has automated prevention (see `btrfs-health.nix`):
1. **GC guard** — `nix-gc` and `nix-build-cleanup` refuse to run when
   device-unallocated < 10% (ExecStartPre exits 1)
2. **Metrics** — `btrfs-health.service` collects Prometheus metrics every 5 min
3. **Alerting** — Gatus sends Discord alerts when chunk allocation is critical
4. **Widget** — DMS BTRFS widget shows device-unallocated percentage

If GC is blocked by the guard, free space by:
1. Growing the partition (if unpartitioned space exists)
2. Deleting old snapshots: `btrfs subvolume delete /mnt/btrfs-root/.snapshots/@.OLD`
3. Running metadata balance (ONLY after growing): `btrfs balance start -musage=50 /`

## Reference

- Full forensic analysis: `docs/crash-analysis-2026-06-26.md`
- Previous incident (manual trigger): `docs/crash-analysis-2026-06-15.md`
