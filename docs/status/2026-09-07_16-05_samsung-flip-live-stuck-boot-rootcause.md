# Samsung /nix flip is LIVE — stuck-boot root cause + recovery (2026-09-07)

## Outcome

- **The migration itself succeeded.** `/nix` has run from the Samsung `tlc` pool
  (`nvme1n1p2[/nix]`, subvol `nix`, zstd) since the 2026-09-07 14:10 boot.
- The 02:11 reboot **hung on a boot entry, not on the migration**: the systemd-boot
  default pointed at a generation whose store paths only exist on the retired QLC store.
- Recovered + re-anchored same day: repo HEAD deployed onto the live Samsung store,
  default entry verified, all dead menu entries pruned, 0 failed units, smoke 95 PASS.

## Timeline (evidence-backed)

| Time (09-07) | Event | Evidence |
| --- | --- | --- |
| 02:10:53-58 | Clean shutdown of the 09-05 boot; `/mnt/samsung-nix` unmounted cleanly | `journalctl -b -1` tail, wtmp `shutdown` |
| ~02:11 | Reboot auto-boots loader default = **Generation 775** (`nixos-c34bb5b2`, built 09-06, `init=/nix/store/j95cix9f…`) → initrd mounts `/nix` from the Samsung → **init path does not exist there** → frozen before journald | zero journal boots between 02:10:58 and 14:10:11; pstore empty (hard power cut leaves no dump) |
| 02:1x | User crashes the box, later power-off (~12 h gap) | wtmp |
| 14:10:11 | User hand-picks "an older derivation" = gen 761 entry (`nixos-2b80b1bb`) → boots **`p0ccbqj5`, the flip generation itself**, store on the Samsung | `/proc/cmdline`, `findmnt -T /nix`, `LoaderEntrySelected` EFI var |
| ~15:4x | Diagnosis; loader default hand-set to the known-good gen-761 entry (reboot-safe) | `loader.conf` |
| ~15:5x | Deploy run 1: eval blocked by the known nix-daemon stale-fetch cache (`…storage-collector-prepared-source.drv is not valid`) → daemon restart heals; rebuild passes | dep logs |
| ~16:1x | Deploy run 1 activation **exit-4** (`inboxclean-sync.service` failed during activation; nh skipped profile/bootloader — deploy.sh caught: "No new profile generation … REBOOT WILL REVERT") | dep2.log |
| ~16:2x | Deploy run 2 (cached, nothing to restart): clean activation — profile `system-761` → `zkaacn2a` (26.11.20260905.c043004), new default entry `nixos-efc4051e…` init verified on the live store, **stc boot pruned all 14 dead QLC-only entries** (762-775), 0 failed units, post-deploy smoke 95 PASS / 0 FAIL | dep3.log, verify run |

## Root cause

The handoff's own predicted failure mode, verbatim: *"If any deploy/build happens
BEFORE the reboot instead, re-run `samsung-nix-sync.sh --final` first (newer
generations' paths would be missing on tlc and unbootable from it)."*

- Final Samsung sync: 2026-09-05 15:39 (covers everything through QLC gen 761).
- **Parallel session deployed ~14 generations on 09-06** (762-775) against the
  still-live QLC store; the loader default advanced to gen 775. Nobody re-synced.
- The flip fstab mounts `/nix` **exclusively** from the Samsung, so every
  post-sync generation is unbootable: kernel+initrd load from the Lexar ESP fine,
  stage-1 mounts `tlc` fine, then `exec init` targets a path that only exists on
  the QLC `@nix` subvol → frozen before journald starts (why the hung boot left
  zero journal/wtmp artifacts).
- Every entry ≤ 761 was Samsung-present and bootable — which is why the user's
  manual pick worked, and why it *looked* like "booting an older derivation":
  gen 761 (`p0ccbqj5`) IS the flip generation. The machine was already migrated.

## Why the follow-up deploys were needed (two known classes, both documented)

1. **nix-daemon stale-fetch cache** (`path … .drv is not valid` during eval):
   healed with `systemctl restart nix-daemon` (no parallel builds running).
2. **nh exit-4 profile-skip** (the 09-05 near-miss mechanism): `inboxclean-sync`
   failed during test-activation → nh skipped profile/bootloader write. Re-running
   the deploy with everything cached gave stc nothing to restart → clean exit →
   profile + bootloader written. deploy.sh's anchoring warning
   (`system_current_system_profiled` doctrine) caught both occurrences.

## State after recovery

- `/nix` = Samsung `tlc`; `/run/current-system` == profile `system-761`
  (`zkaacn2a`, 26.11.20260905.c043004, Linux 7.2.3) == loader default — boot chain
  consistent end-to-end, init path verified on the live store.
- Boot menu: gens 746-761 only; 746-760 are pre-flip QLC-`@nix` rollback entries
  (the soak-period fallback ladder). **Generation numbers now collide across
  stores**: Samsung-store gen 761 (`zkaacn2a`) ≠ QLC-store gen 761 (`p0ccbqj5`).
- 0 failed units after the deploy (all six pre-existing failures cleared:
  blocklist-auto-update, btrfs-balance-data, cv-scan, inboxclean-sync,
  nix-build-cleanup, service-health-check).
- All future builds/deploys land directly on the Samsung store — the
  sync-drift failure class is structurally gone.

## Follow-ups (tracked in TODO_LIST)

- 3-day soak (~09-10) → verify attic store-rebuild story → delete QLC `@nix`
  (its unique content is now only superseded gens 762-775 + the pre-flip store).
- Samsung monitoring wiring (btrfs-health metrics, smartd, Gatus mount/space).
- exec-latency-under-buildstorm acceptance + fio sanity vs the 620-IOPS QLC baseline.
- Phase 2 hot DBs per the plan doc.
- `checks.mail-relay` VM-test regression still blocks pre-commit for docs commits
  (`--no-verify` with reason, pre-existing).

## Process lessons

- A store migration's reboot gate is only valid at the moment of verification —
  any deploy in the window between final sync and reboot silently invalidates it.
  During such a window the deploy pipeline should hard-fail or auto-re-run the
  final sync (candidate TODO: deploy.sh migration-window guard).
- "Stuck in boot" with **zero journal + zero wtmp artifacts** = the hang is
  pre-journald: initrd device-wait or failed `exec init`. Check
  `journalctl --list-boots` + `last -x` FIRST before touching the running system.
- `LoaderEntrySelected`/`loader.conf` + per-entry `init=` existence against the
  live store is the authoritative boot-chain audit — entry titles/generation
  numbers lie across a store swap.
