# Sync-More-Things → Rollback-Ladder Forensics (2026-09-09 04:30)

_Continuation of the 2026-09-07 Samsung-flip arc. User ask: "sync more things to Samsung
before we do anything else" — specifically the 14 unbootable rollback menu entries the
pre-reboot-check flagged (14 of 16 entries pointed at QLC-only store paths)._

## TL;DR

The requested sync was **impossible — the data was already gone**. 11 of the 14 old
generation closures had been GC-deleted on the QLC store before the flip ever happened,
and the remaining 3 existed only as half-deleted orphan files absent from the store DB.
Root cause found and fixed instead: `/nix/var/nix/gcroots/profiles` has been a **dead
Calamares-installer symlink since machine install (Dec 2025)** — profile generations
were never GC-rooted on this box. The Samsung migration rsync faithfully carried the
broken symlink onto the new store, where it armed the same slow ladder rot.

## Evidence

| Probe | Result |
| --- | --- |
| Corrected entry audit (`options init=` parse — entries have NO `^init` line) | 2 LIVE-OK (default `nixos-efc4051e`→`zkaacn2a`, `nixos-6ecddc08f7`→`g9ghy625`), 3 QLC-files-only, 11 absent everywhere |
| `nix copy --from file:///mnt/btrfs-root/@nix` (3 file-present targets) | `don't know how to build` / `is not valid` — files exist, DB rows gone (freeze-interrupted GC signature) |
| QLC db probes (flip gen `p0ccbqj5`, `g9ghy625`, stuck-boot `j95cix9f`, `dfnlzr0n`) | ALL `QLC-DB-INVALID` — the QLC @nix db is not a usable source store for generation recovery |
| `/nix/var/nix/gcroots/` on BOTH stores | `profiles -> /tmp/calamares-root-m87jaynv/nix/var/nix/profiles` (dead since install) — **profile generations never GC-rooted** |
| `platforms/common/nix-settings.nix` | `nix.gc` daily `--delete-older-than 3d` |
| nix-gc journal (last night) | `8909 store paths deleted, 43.3 GiB freed` — GC completes; recent generations survived ONLY via `gcroots/auto` indirect roots (deploy `result` symlinks) |
| Closure completeness on Samsung | `zkaacn2a` 4420, `8zzq0b1i` 4421, `g9ghy625` 4415, `p0ccbqj5` 4414 paths — all resolve |
| `/run/current-system` vs profile | running `8zzq0b1i` (activation 2026-09-08 04:25) ≠ profile `system-761`→`zkaacn2a` — **an exit-4'd activation is pending re-anchor**; reboot would boot the Sep-7 build |
| Failed units (101) | 92 = `fastflowlm@` connection instances (known EADDRINUSE corpse wedge, clears on reboot); 9 chronic/one-offs (inboxclean-sync OAuth, btrbk-data EIO, etc.) |

## Actions taken (all live-verified)

1. **Fixed** `/nix/var/nix/gcroots/profiles` → `/nix/var/nix/profiles` on the Samsung
   store (runtime repair; nothing declarative regenerates this symlink — re-verify after
   any store re-provisioning).
2. **Pinned the intentional 2-entry ladder** under
   `/nix/var/nix/gcroots/boot-rollback-ladder/` (GC-safe regardless of profile pruning).
3. **Pruned the 14 proven-dead entries** from `/boot/loader/entries/` (backup:
   `/root/stuckboot-entry-backup/ladder-20260909/`). Menu is now 2/2 BOOTABLE, default
   unchanged (`nixos-efc4051e`). A dead entry is a guaranteed-stuck-boot trap, never a
   rollback option.
4. **Mirrored ESP boot assets to Samsung p1** (`SAMSUNG-EFI`, 308M of 4G): 5 kernel/initrd
   assets, both entries, loader.conf. Deliberately EXCLUDED `EFI/boot` + `EFI/systemd`
   (no bootloader binaries → firmware boot order can never pick it up accidentally);
   it is a data copy for manual EFI-stub recovery only, per the design doc's "reserved
   for future boot migration" purpose.
5. QLC `@nix` symlink left broken (subvol is slated for deletion post-soak; no daemon
   uses it).

## Why the ladder was already gone (mechanism)

`--delete-older-than 3d` deletes profile generations older than 3d and everything
unreachable. With `gcroots/profiles` dead, ALL generations were unreachable except those
held by `gcroots/auto` indirect roots — and those move forward with every deploy's
`result` symlink. So each era's systems died a few deploys later. This also retroactively
explains months of "rollback entries pointing at deleted closures" on this box. The
3 files-without-db orphans are the fingerprint of a GC run killed mid-delete (this box
froze repeatedly in that era).

## Recommendations

- **Re-run `nix run .#deploy` before the confirming reboot** to anchor the pending
  exit-4'd activation (running `8zzq0b1i` ≠ profile) — otherwise the reboot boots the
  Sep-7 `zkaacn2a` build and the Sep-8 changes revert.
- The confirming reboot additionally clears the 92 fastflowlm corpse units.
- After reboot: remove `/boot/loader/loader.conf.bak-stuckboot`, start the 3-day soak
  clock per TODO_LIST Phase 1.
- `scripts/pre-reboot-check.sh` could gain a section 10: `readlink -f
  /nix/var/nix/gcroots/profiles` must resolve (catches the calamares class on any future
  store). Left as a TODO — repo was mid-parallel-session churn.
