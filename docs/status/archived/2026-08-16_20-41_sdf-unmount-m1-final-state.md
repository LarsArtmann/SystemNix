# sdf (WOOACME W3A894-512GB) — M1 Final-State Snapshot Before Unmount

**Created:** 2026-08-16 20:41 CEST
**Purpose:** M1 of `docs/planning/2026-08-16_20-22_three-drive-repurposing.md` requires a final-state snapshot of the sdf mounts before unmounting. This is the last recorded view before the drive is repurposed as the offsite vault (M5 wipe).

## Pre-unmount safety checks (all pass)

- `sdf3` (33.9G swap partition): **NOT active** — only `zram0` in `/proc/swaps`
- Both mounts **read-only** (`ro,relatime`)
- `lsof +f` on both mounts: **zero open files**
- sdf is on its own USB controller (`c7:00.3`), not behind the shared DAS link (`8-1`) — no buildcache/ZFS-VM interaction

## Device

| Partition | FSType | Size | Mount | Used |
|---|---|---|---|---|
| sdf1 | vfat (systemd-boot ESP) | 511M | `/tmp/sdf1-mount` (ro) | 39M (8%) |
| sdf2 | ext4 | 435G | `/tmp/sdf-mount` (ro) | 83G (21%) |
| sdf3 | swap | 33.9G | — (inactive) | — |

## sdf2 content (old private-cloud NixOS rootfs, dates Apr–Dec 2025)

Top level: standard NixOS root (`bin etc home lib nix opt root usr var …`) plus the private-cloud data dirs:

- `/storage`, `/storage-backup-ssd`, `/storage-backup-ssd2`, `/storage-backup-ssd4` — each with `apps backups cache config databases dev documents logs media` subdirs
- `/home/lars`, `/home/syncthing`, `/home/art`
- `/etc/caddy` etc. (config remnants)

## sdf1 content

`EFI/{systemd,BOOT,Linux,nixos}`, `loader/entries`, SecureBoot keys (`db`, `KEK`, `PK`, `dbx`) — a systemd-boot ESP, nothing unique.

## Unmount commands (require root; run manually)

```bash
sudo umount /tmp/sdf-mount /tmp/sdf1-mount
# optional, after unmount, to power the enclosure down before unplugging:
udisksctl power-off -b /dev/sdf
```

## Reminder (per plan §6, repeat at green-light time)

After the M5 wipe, unallocated-space recovery from sdf2/sdf3 becomes impossible — the /data forensic clones (`/data/backup-2026-08-11-private-cloud-*`, 13 G) are file-level only. The user accepted this by closing the media hunt.

---

**Resolution (2026-08-17):** the unmount above was executed the same evening; sdf was never wiped (M5 offsite-vault role dropped by user decision — drive FROZEN, see AGENTS.md "HDD Backup Pool & DAS Topology"), and the forensic clones were relocated to `/mnt/pool/archive/private-cloud-forensics` (verified). Purpose of this snapshot fulfilled; archived.
