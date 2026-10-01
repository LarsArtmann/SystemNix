# Root 100%-full: btrbk prune-behind-send backlog — emergency runbook + structural fix

**Date:** 2026-10-01 ~21:30 CEST
**Trigger:** user alarm — `/mnt/btrfs-root` at 100% (df 701G/723G, 5.5 GiB free), "why do I ONLY have fucking 5GB left".
**State at session:** io storm ongoing (avg60 ~29%), memory healthy (mem PSI ~0.3). Guard wave (catch-up slot) from the 2026-09-29 session still UNDEPLOYED. Two `.rescue/@.rescue-20261001T*` snapshots taken by the user today (out of scope here).

## a) Incident chain (all evidence primary)

1. **Space state:** df `/` 701G/723G (100%, 5.5 GiB); `btrfs_device_unallocated_pct` **0** (metadata 75% — not yet in the metadata-ENOSPC zone, but zero headroom for new chunks = the 2026-06-26 precursor class). 10 GiB emergency reserve still present at `/btrfs-emergency-reserve` (untouched — deletion frees space, not the fix).
2. **Backlog quantified** (`sudo btrfs filesystem du -s`, user-run): `@.20260913T2300` **87.85 GiB exclusive**, `@.20260920T2300` 41.07, 22–26 ≈ 2.48/3.46/0.94/0.66/7.15 → the expired lingerers alone ≈ **102.5 GiB** (+ hermes lingerers, unmeasured, smaller). This is the disk-cleanup proposal's "366 GB btrfs-level" pool's reclaimable-today core.
3. **Root cause** (extends the 09-26..30 kill-streak watch row): btrbk `run` prunes only AFTER its send phase. Zone-6 trips killed every nightly send 09-26..09-30 (4-kill streak verified earlier; pool @ stuck at 09-27, hermes at 09-25 — 3 + 5 nights local-only), so the prune phase never ran either: snapshot phase succeeded each night, retention-expired snapshots lingered, the QLC filled to the cliff.
4. **Why the existing safety net missed it:** `btrbk-pool-clean` (23:50) runs `btrbk clean` — which is ONLY the garbled-receive GC (interrupted-receive targets), never a retention prune (verified: btrbk 0.32.7 dispatch, `clean` → `$action_clean`, `prune` → run-with-skips).

## b) Safety verification (btrbk 0.32.7, in-source, NOT assumed)

- `bin/.btrbk-wrapped` ~7085: **latest-common snapshot per target is FORCE_PRESERVEd** — send parents (`@.20260927T2300`, `@home-hermes.20260925T2300` at fix time) cannot be pruned while the target is reachable.
- ~7127: **if ANY target aborts (pool detached) source cleanup is SKIPPED entirely** ("Skipping cleanup of snapshots … target aborted earlier") — prune is fail-safe both directions.
- `snapshot_preserve_min 2d` keeps the freshest regardless; `backend btrfs-progs-sudo` + the existing sudo allowlist (subvolume list/show/delete) covers everything prune invokes — the same commands the nightly run's own prune phase uses.
- Prune is metadata-only (no full-device read): safe to run mid-storm; the kernel cleaner reclaims asynchronously.

## c) Fix landed (repo; deploy rides the pending wave)

`snapshots.nix` — `btrbk-pool-clean` now runs `btrbk prune` for each config after `btrbk clean` (root/data/pool always; forgejo when its dedicated subvolume exists, mountpoint-guarded so a detached Samsung skips only that leg). Description, comment block, `deploy.sh` enqueue message updated. Verified: evo-x2 toplevel eval green; generated script `bash -n` + shellcheck clean; `util-linux` added to `path` for `mountpoint`.

Docs: `docs/agents/storage.md` backup-tier bullet rewritten (clean+prune semantics + fail-safes); CHANGELOG Added entry; TODO parity in `docs/todo/storage.md` (emergency-prune row [blocked:user], post-deploy verify row [blocked:deploy], 09-26 watch row updated with the 2026-10-01 escalation+closure). NOT in TODO_LIST queue (blocked items are library-only per contract).

## d) Emergency runbook (user-run, sudo; NO deploy needed — works on the live config)

```bash
# outside 23:00–23:50, pool mounted (it is):
sudo btrbk -c /etc/btrbk/root.conf prune --dryrun   # preview: expect @ 13/22/23/24/26 + hermes 16/22/23/24/26 deleted
sudo btrbk -c /etc/btrbk/root.conf prune             # execute
df -h /                                              # climbs as the cleaner reclaims (async)
```

Expected: ~105 GiB freed (root → ~84%); `@.20260920T2300` (41 GiB) follows at normal weekly expiry 2026-10-04. Unalloc recovers as empty data chunks are released → the BTRFS CRITICAL gatus alert clears.

## e) Not done / deliberate

- No changes to retention policy (3d 1w is correct; the backlog was prune-execution, not policy).
- Emergency reserve kept (its job is metadata emergencies; prune frees 10× more without consuming it).
- No manual `btrfs subvolume delete` — everything through btrbk's own prune (parent-aware, doctrine-compliant).
- flake.nix untouched (parallel session).

## f) Follow-ups — self-harvested at authoring time

Both landed in `docs/todo/storage.md` (library-only, blocked tags — NOT queue-harvestable): the [blocked:user] emergency manual prune row and the [blocked:deploy] first-fire verification row. The deploy itself rides the existing user-gated wave (guard catch-up slot + this prune fix together close the whole starvation class: sends re-arm via catch-up, pruning no longer waits on sends).

## g) Session verification log

`nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` green; generated unit script extracted, `bash -n` + shellcheck 0.11.0 clean; unit `path` confirmed to carry btrbk/btrfs-progs/coreutils/util-linux; pool receive anchors live-verified (`ls /mnt/pool/backups/root/`: @ through 09-27, hermes through 09-25); live btrfs metrics read from the textfile collector.
