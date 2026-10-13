# DiscordSync backup: 11th failure root-cause update, restore drill, catch-up windows

**Date:** 2026-10-13 ~20:45
**Trigger:** queue item "Verify the RESCHEDULED `discordsync-db-backup` dump after tonight's 03:45 run" (TODO_LIST, storage.md row 45) + a same-day deep-dive report on SQLite backup practice (`~/projects/reports/sqlite-continuous-backup-deep-dive-2026.md`, recipes executed on this host by its author) that made the never-restored-dump gap actionable.

## §a Verdict (one line)

The 2026-10-13 03:45 dump FAILED (11th consecutive night) for a NEW reason — the GCS quiet-gate passed on reconcile silence, so a different silent writer held the lock; the last good dump (2026-10-01) was restore-drilled HEALTHY; hardening landed eval-only, rides the next deploy.

## §b Findings

1. **No dump since 2026-10-01.** `/mnt/pool/backups/discordsync` holds exactly two good dumps (09-30, 10-01, 80 MB gz each) + ten 0-byte `.discordsync-db-*.raw` corpses (10-02..10-11, old script) + nothing for 10-12/13 (new script cleans up on failure).
2. **The 03:45 run executed with the gate GREEN and still lost.** Journal 03:45:00→03:47:01: quiet-gate found 3 min of reconcile silence (`grep -c "refreshing GCS signed URLs"` in the window = 0), then all 3 `.timeout 30000` attempts failed `database is locked` (03:45:31 / 03:46:16 / 03:47:01). Server journal in the same window shows only dashboard GETs + one turso push BLOCKED error (03:47:46). **The GCS reconcile pass is NOT the (only) lock holder** — the holder writes silently.
3. **Holder hypothesis (unconfirmed):** the post-shadow-split re-backfill. The 2026-10-12 15:55 wave-5 incident left a FRESH DB; the server restarted 21:52 that night (and 14:31/15:46 before) — a fresh-DB re-backfill replays message history for many hours with continuous writes, which matches a continuous lock at 03:45. The freeze-20 class "discordsync 12.3 GB catch-up per cold boot" quantifies the same shape.
4. **The "~11 GB event store" claim in hot-db.md was wrong** — the bit-wise `.backup` of 10-01 restores to **381 MB**. Corrected in hot-db.md.

## §c Restore drill (report §8.4, executed)

`discordsync-db-2026-10-01.sql.gz` → tmpfs → sqlite 3.53.3:
- `PRAGMA quick_check` → **ok**
- counts: **messages 43,617 / events 68,020 / attachments 5,474**
- freshness: newest message `2026-10-01 02:26` (dump-window consistent)
- scratch file trashed after. The only backup in hand is REAL — but 12+ days stale on an UNSNAPSHOTTED tier.

## §d Changes (modules/nixos/services/discordsync.nix, eval-verified, NOT deployed)

1. **Timer catch-up windows**: `OnCalendar = [03:45, 05:15, 06:45]` — `Persistent` re-runs MISSED activations, never FAILED runs; catch-up windows give a failed primary two same-day retries. The script's new already-today guard makes post-success catch-ups no-ops.
2. **Pre-visibility `quick_check` gate** on the raw dump before gzip+mv (report §8.1's bug-2 lesson: a torn snapshot must never become archivable).
3. **Upfront stale-intermediate cleanup** (`.discordsync-db-*` / `*.part` older than 2d) — failure streaks can no longer litter the dir.
4. Stale comment fix (03:45 rationale now records the 10-13 gate-passed-yet-locked evidence).

Eval: `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` green (only the known catalog-integration-subdomains warning).

## §e Why NOT deployed today

IO PSI `some avg60` was 53-60% all session (Zone storm). A switch mid-storm is the freeze-amplifier class, and the deploy-concurrency guard exists precisely because a storm-window switch also ships parallel sessions' in-flight tree. The hardening rides the next quiescent deploy window.

## §f Follow-ups (harvested at authoring)

1. Verify the dump on the next deploy's windows (03:45, then 05:15 if missed) — UPDATED in TODO_LIST + storage.md row 45 (was: tonight-only).
2. Identify the silent lock holder once the backfill hypothesis is testable (post-deploy or post-drain journal correlation) — folded into row 45's verify item.
3. Automate a weekly restore-drill — NEW [ready] row in docs/todo/storage.md + queue one-liner.
4. Litestream v0.5 for near-zero RPO on the hot-tier event store — NEW [decision] row in docs/todo/storage.md (owner call).
5. Failure catch-up for OTHER dump legs (bank-sync, browser-history, paperless, miniflux, forgejo) — storage.md row 189 annotated; discordsync leg closed by §d.1.
