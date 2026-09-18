# Samsung 2nd Boot Disk — Pareto Plan (2026-09-18)

User ask: **"Make the Samsung a 2nd boot disk and switch ASAP."**

## Situation (researched, live-verified 2026-09-18)

| Piece | State |
| --- | --- |
| `/boot` (NixOS ESP, systemd-boot 261.2) | QLC Lexar p7, 4G, by-uuid `80A3-73A9`, 248M used |
| Samsung p1 `SAMSUNG-EFI` | 4G vfat, PARTUUID `023f66c0-…`, UUID `4F53-C156`, UNMOUNTED — holds a stale partial asset copy from 2026-09-09 (kernels/entries, **no bootloader binaries**) |
| `/nix` store | ALREADY on Samsung (`tlc` subvol `nix`, neededForBoot) |
| Firmware entries | `Linux Boot Manager` 0x0001 on QLC ESP (current boot path); auto `UEFI OS` 0x000B points at Samsung p1 `\EFI\BOOT\BOOTX64.EFI` which does NOT exist yet |
| nixpkgs support | `boot.loader.efi.mirroredBoots` is **grub/extlinux-only** in the locked nixpkgs — no declarative sd-boot mirror ⇒ SystemNix-native mirror unit |

After the switch the Samsung carries: ESP (loader + kernels + initrds) + `/nix` (init + store).
The only QLC dependency left in the boot chain is the root `@` subvolume (out of scope today).

## Pareto tiers

| Tier | Deliverable | Impact |
| --- | --- | --- |
| **1% → 51%** | `fileSystems."/boot-mirror"` + `boot-mirror-sync.service` (bootctl install `--variables=no` + rsync `--delete` + `diff -r` verify gate) | Samsung ESP becomes byte-bootable and stays current |
| **4% → 64%** | deploy.sh provisioner restart + `nix run .#boot-mirror-activate` (idempotent EFI entry + BootOrder Samsung-first) | One command performs the switch, safely |
| **20% → 80%** | `pre-reboot-check` §11 mirror audit (FAIL-grade once the mirror is first in BootOrder) + reboot + post-boot verification | Proves the new chain live; QLC stays fallback |
| Rest | AGENTS.md + monitoring (`system-health`), docs | Durability |

## Execution checklist

1. [x] Research (this document's Situation table)
2. [x] `platforms/nixos/system/boot-mirror.nix` (mount + sync unit)
3. [x] configuration.nix import, deploy.sh restart list, flake app
4. [x] `scripts/boot-mirror-activate.sh` + `pre-reboot-check.sh` §11
5. [x] `nix flake check --no-build` + evo-x2 eval (both green)
6. [ ] Deploy → verify mirror (journal, `bootctl is-installed`, `diff`, df)
7. [ ] Activate (Samsung first in BootOrder) → `nix run .#pre-reboot-check` green
8. [ ] Reboot → verify `BootCurrent` = Samsung entry, chain green
9. [ ] Docs + AGENTS.md

## Design decisions

- **Mirror, not ESP swap**: NixOS keeps managing the QLC `/boot` (single
  `efiSysMountPoint` contract); the Samsung ESP is a verified byte-mirror.
  Both disks stay CURRENT — a QLC ESP failure no longer strands boot.
- **`bootctl --esp-path=/boot-mirror --variables=no install`**: installs the
  loader binary (+ `EFI/BOOT` fallback) and the per-ESP random seed without
  touching EFI variables — NVRAM changes are owned by the activate script.
- **rsync `--delete --exclude=/loader/random-seed`** with FAT flags
  (`--no-owner --no-group --no-perms --modify-window=2`): random-seed stays
  per-ESP (never copied, never deleted; receiver-side exclude protects from
  `--delete`).
- **Verification gate in the unit**: `diff -r -x random-seed` between `/boot`
  and the mirror must be empty or the unit FAILS (no silent drift).
- **BootOrder flip is explicit** (`boot-mirror-activate`), not automatic: the
  box's reboots are deliberate events; NVRAM order should not fight the
  operator. The entry itself is created by the same script, once.
- **Boot-path lag is safe**: between a switch and the post-switch sync
  restart (seconds), the mirror would boot the PREVIOUS generation — its
  store paths still exist (`/nix` is GC'd with 3d profile retention).

## Rollback

Firmware boot menu (F8/F11/F12) or `efibootmgr -o 0001,…` (QLC `Linux Boot
Manager` first). The QLC chain remains fully managed and current at all
times; the mirror is purely additive until the BootOrder flip.

## Hazards honored (from AGENTS history)

- Stuck-boot class (2026-09-07): every mirror entry's `init=` lives on the
  LIVE `/nix` (Samsung) — audited by §11 + the whole-menu §3.
- nvme0/nvme1 enumeration FLIPS: activate script derives disk/partition from
  `findmnt`, never kernel names.
- `switch-to-configuration` never restarts oneshot+RemainAfterExit: the unit
  rides deploy.sh's provisioner loop + boot-time `wantedBy`.
- ESP permissions: fmask/dmask 0077 like `/boot`; sync runs as root.
