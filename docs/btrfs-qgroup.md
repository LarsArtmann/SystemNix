# Btrfs `btrfs_use_qgroup` in Timeshift

- **Setting location:** `platforms/nixos/system/snapshots.nix:17`
- **Current value:** `true`
- **Reviewed:** 2026-05-08

## What It Does

`btrfs_use_qgroup` tells Timeshift to use Btrfs **quota groups** (qgroups) to track the **exclusive space** consumed by each snapshot.

## How Btrfs Snapshots Work

Snapshots are CoW — they share data blocks with the source subvolume. Initially a snapshot costs ~0 bytes. As the live system changes, the snapshot "diverges" and accumulates its own exclusive blocks.

## What Qgroups Do

Btrfs qgroups calculate how much space is _exclusively_ owned by a given snapshot vs shared. Timeshift uses this to display snapshot sizes in its UI and enforce retention by size.

## The Problem

Qgroups have a known performance cost — Btrfs must walk the extent tree to calculate exclusive sizes, which gets expensive on large filesystems. Snapshot creation and deletion slow down noticeably as the filesystem grows. The Btrfs wiki and mailing list have long-standing warnings about this.

## Impact on This System

All schedule flags are `false` and retention is count-based (`count_daily`, `count_weekly`), not size-based. Timeshift only runs via the daily timer. Qgroups provide snapshot size info in `timeshift --list` output, but nothing actually _depends_ on that size data.

## Recommendation

Setting `"btrfs_use_qgroup": false` would not break anything — you'd just lose the per-snapshot size display. Consider testing with it disabled if snapshot creation/deletion feels slow.
