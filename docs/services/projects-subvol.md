# ~/projects Samsung Subvolume (Set B)

`/home/lars/projects` — 342 repos, ~55 GiB payload — on the Samsung 970 EVO
Plus (`tlc` fs, by-label; nvme enumeration flips across boots) as subvolume
`users/lars/projects`, mounted at the SAME path (path-invariant: every
consumer path, symlink, unit WorkingDirectory, and flake `git+file://` input
resolves unchanged). Plan of record:
`docs/planning/2026-10-28_projects-samsung-subvol-migration.md`.

- **Mount**: `platforms/nixos/system/snapshots.nix` (`projectsHomeMount`),
  plain fstab mount (NOT automount — activation writes under an unmounted
  mountpoint are the shadow-dir class), `subvol=users/lars/projects
  compress=zstd noatime nodiscard space_cache=v2 nofail`. Per-mount
  compress (btrfs compression is per-mount, NOT fs-wide) and DEFAULT commit
  (commit=300 is a QLC measure; the Samsung keeps 30s).
- **Host gate**: `projectsSubvolArmed = hostName == "evo-x2"` — the btrbk
  instance, collector, gate legs, and registry entry all key off it.
- **Backup**: `btrbk.instances."projects"` — local snapshots
  `/mnt/hot/.snapshots` (2d/3d), pool sends to
  `/mnt/pool/backups/projects-subvol` (`7d 14d 8w` bounded — ends the @-leg
  FOREVER-hoarding of projects churn), nightly 23:10 (root 23:00, data
  23:30, clean 23:50). First seed ~55 GiB over the DAS (24h
  TimeoutStartSec, ioTier.background, MemoryHigh 4G).
- **Provisioning parity**: declared in `disko/samsung-tlc.nix`
  (`/users/lars/projects`, `mountpoint = null`); created LIVE only by
  `scripts/migrate-projects-subvol.sh` (no runtime bootstrap units — banned
  class). Eval assertion cross-guards module↔disko drift.
- **Monitoring**: `projects_subvol_backup_fresh` (12h→**36h** threshold =
  nightly cadence + one missed slot; forgejo's 12h was 8h-cadence-scaled)
  via the `projects-subvol-backup-metrics` collector (5min timer,
  fail-closed), Gatus check on the `services.integration.projects-subvol`
  entry, per-prefix verify legs in `btrfs-verify-pool-backups` +
  `btrfs-verify-snapshots` (mount-unit gated, hermes pattern).
- **Writer gating**: every unit touching `~/projects` carries
  `RequiresMountsFor=/home/lars/projects` (fail loud, never shadow-write):
  projects-management-automation, pma-daemon-watchdog,
  project-discovery-daemon, tq-agent-pool, cv-server, nsfw-classifier,
  git-lag-metrics, bank-sync-qonto-stage, rust-cache-projects-links
  (symlink converger, deploy.sh provisioner list), hermes (self-gated on
  its `projectsDir`). Pinned by the `projectsWriters` eval assertion.

## btrbk receive/snapshot NAMING (verify at first seed)

Receive and snapshot names are btrbk basename-form `projects.<YYYYMMDDTHHMM>`
(nested-subvol precedent: `hot/forgejo` → `forgejo.<date>`). The collector
greps `^projects\..` and both verify legs match `projects.*`. **After the
first live seed, confirm the actual prefix** (`ls /mnt/pool/backups/projects-subvol`
+ `ls /mnt/hot/.snapshots`) and update the three greps if btrbk chose
differently — the plan deferred exactly this to first-seed observation.

## Migration runbook (owner windows)

```bash
# Phase C — prepare (no downtime, 2-4h throttled background, sudo):
sudo bash scripts/migrate-projects-subvol.sh prepare
#   gates: maintenance lock + PSI, refuses in the 22:50-00:15 btrbk window,
#   space asserts (Samsung+pool ≥ payload×1.5, QLC unalloc > 10G);
#   creates users/lars/projects via /mnt/hot, double-pass rsync -aHAXS
#   (sparse-aware; .gocache-disk/.golangci-disk/.gotmp ALWAYS excluded),
#   banded parity verify + git fsck spot-check on the subvol copy.
#   Re-runnable: subsequent runs do delta passes.

# Phase D — cutover (~30-60 min, all writers quiesced, owner present):
#   close interactive sessions/editors; agent stops writer units (explicit
#   PIDs via pgrep -af + scripts/redact-argv.sh; absolute
#   /run/current-system/sw/bin/kill — the mvdan/sh kill-builtin trap;
#   NEVER kill -0 liveness probes);
#   final delta rsync (writers stopped — converges to equality);
nix run .#deploy
#   §18 shadow-split-gate PASSES (subvol populated); fstab mounts OVER the
#   live old dir (QLC shadow intact beneath = rollback insurance); gated
#   units restart against the mount. NOTE: any deploy BEFORE prepare §18-
#   FAILs by design (exit 1) — that FAIL is the protection working.
#   Then: nix run .#pre-reboot-check + one controlled reboot (boot-time
#   mount + gating proof; verify mount + writers green within 2 min).

# Phase E — finalize (same day):
sudo bash scripts/migrate-projects-subvol.sh finalize
#   mount + write-probe verified, first btrbk-projects seed kicked
#   (--no-block; receipt = journalctl -u btrbk-projects exit summary).

# Phase F — after ≥7d burn-in + ≥5 green nightly sends:
sudo bash scripts/migrate-projects-subvol.sh shadow-cleanup
#   refuses unless mount live + Samsung-served + ≥5 pool receives;
#   archives the QLC shadow to
#   /mnt/pool/backups/home-lars-projects/projects-shadow-final-<date>.tar.zst
#   (exact-count verified), deletes shadow contents through a /run
#   subvol=@ bind view, re-verifies empty via a fresh view.
```

## Rollback ladder

- **Before shadow-cleanup**: `sudo umount /home/lars/projects` + reboot =
  back on the QLC shadow (pre-cutover state; post-cutover writes live only
  on the subvol — reverse-delta rsync them or accept their loss).
- **After shadow-cleanup**: the pool archive (`projects-shadow-final-*.tar.zst`)
  is the last full pre-migration copy; btrbk receives cover post-migration
  state only.

## Operational semantics that changed

- `trash` inside `~/projects` → the Samsung subvol's `.Trash-1000`; big
  deletes pin subvol snapshots (2d/3d) + pool receives (14d/8w), not QLC `@`.
- `df /` no longer sees projects growth — the Samsung is the growth surface
  (btrfs-health composites cover it; weekly scrub now includes `/mnt/hot`
  — the whole tlc fs, ~400 GiB idle-priority read, storm-deferred).
- Space freed by the final shadow deletion lands as the `@` 3d pin +
  `.rescue` (~1-2d) windows expire — never instantly; never size success
  from post-run `df`.

## Traps encoded in the script (do not "fix" away)

- NO rsync `--reflink` (no such flag — twice-burned); `-S` sparse-aware.
- Subvol provisioning through `/mnt/hot` only — never a runtime unit
  (2026-09-20..29 bootstrap saga).
- Shadow deletes through an aux `subvol=@` bind view with a wrong-universe
  mountpoint refusal + verified archive BEFORE delete + fresh-view
  empty re-verify (family precedent: the verified archive IS the safety
  net — trashing 126G into root's `.Trash` would re-pin the freed extents).
- Root-partition derived via `findmnt` at runtime (nvme enumeration flips).
- State records under `~/.cache/projects-migration/` — never `/tmp`.
